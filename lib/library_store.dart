import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException;

import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:html/parser.dart' as html;

import 'boards.dart';
import 'library_import.dart';
import 'library_models.dart';
import 'library_source.dart';

class _LibraryDatabase extends GeneratedDatabase {
  _LibraryDatabase(QueryExecutor executor) : super(executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  static const tables = [
    'catalog',
    'downloads',
    'progress',
    'jobs',
    'preferences',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final table in tables) {
        await customStatement(
          'CREATE TABLE $table (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
      }
    },
  );

  Future<Map<String, Map<String, dynamic>>> read(String table) async => {
    for (final row in await customSelect('SELECT id, body FROM $table').get())
      row.read<String>('id'): (jsonDecode(row.read<String>('body')) as Map)
          .cast<String, dynamic>(),
  };

  Future<void> write(
    String table,
    String key,
    Map<String, dynamic> value,
  ) => customStatement(
    'INSERT INTO $table (id, body) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET body=excluded.body',
    [key, jsonEncode(value)],
  );

  Future<void> erase(String table, String key) =>
      customStatement('DELETE FROM $table WHERE id = ?', [key]);
}

class LibraryStore extends ChangeNotifier {
  LibraryStore._(
    this._db,
    this._fetch,
    this._transport,
    this._now,
    this._decodeImage,
    this._includeAuthored,
  );

  final _LibraryDatabase _db;
  final LibraryFetch _fetch;
  final LibraryTransport? _transport;
  final DateTime Function() _now;
  final Future<bool> Function(Uint8List) _decodeImage;
  final bool _includeAuthored;
  final _entries = <String, LibraryEntry>{};
  final _downloads = <String, LibraryDownload>{};
  final _saves = <String, LibrarySave>{};
  final _latest = <String, LibrarySave>{};
  final _jobs = <String, LibraryJob>{};
  final _dismissed = <String>{};
  final _inFlightDetails = <String, Future<LibraryEntry>>{};
  final _blockedDetails = <String>{};
  final _settled = <String, String>{};
  final _prefs = <String, dynamic>{};
  Timer? _syncRetry;
  Timer? _jobRetry;
  bool _draining = false;
  bool _disposed = false;
  bool syncing = false;
  bool get automatic => _prefs['automatic'] as bool? ?? false;
  bool get complete => _prefs['listed'] == true;
  int get pages => _prefs['pages'] as int? ?? 0;
  int get indexed => _entries.values.where((entry) => !entry.authored).length;
  int get detailed => _entries.values
      .where((entry) => !entry.authored && entry.detailRead != null)
      .length;
  String? syncMessage;
  String? _queuedLanguage;
  Future<void>? _synchronizing;

  static Future<LibraryStore> open({
    QueryExecutor? executor,
    LibraryFetch? fetch,
    DateTime Function()? now,
    Future<bool> Function(Uint8List)? decodeImage,
    Iterable<LibraryEntry>? records,
    bool includeAuthored = true,
  }) async {
    final transport = fetch == null ? LibraryTransport() : null;
    final store = LibraryStore._(
      _LibraryDatabase(
        executor ?? driftDatabase(name: 'sodukromental_library'),
      ),
      fetch ?? transport!.get,
      transport,
      now ?? DateTime.now,
      decodeImage ?? _imageValid,
      includeAuthored,
    );
    await store._load(records);
    return store;
  }

  static Future<bool> _imageValid(Uint8List bytes) async {
    try {
      final image = await decodeImageFromList(bytes);
      final valid = image.width >= 50 && image.height >= 50;
      image.dispose();
      return valid;
    } on Exception {
      return false;
    }
  }

  Future<void> _load(Iterable<LibraryEntry>? records) async {
    final results = await Future.wait(_LibraryDatabase.tables.map(_db.read));
    _entries.addAll(
      results[0].map(
        (key, value) => MapEntry(key, LibraryEntry.fromJson(value)),
      ),
    );
    _downloads.addAll(
      results[1].map(
        (key, value) => MapEntry(key, LibraryDownload.fromJson(value)),
      ),
    );
    _saves.addAll(
      results[2].map(
        (key, value) => MapEntry(key, LibrarySave.fromJson(value)),
      ),
    );
    for (final item in _saves.entries) {
      _rememberSave(item.key.split('|').first, item.value);
    }
    for (final entry in results[3].entries) {
      final old = LibraryJob.fromJson(entry.value);
      final job = old.state == LibraryJobState.downloading
          ? LibraryJob(old.id, old.revision, old.manual, LibraryJobState.queued)
          : old;
      _jobs[entry.key] = job;
    }
    _prefs.addAll(results[4]['source'] ?? {});
    _dismissed.addAll((_prefs['dismissed'] as List? ?? []).cast<String>());
    _settled.addAll((_prefs['settled'] as Map? ?? {}).cast<String, String>());
    final seeds = records ?? await _catalogSeed();
    for (final entry in seeds) {
      _entries.putIfAbsent(entry.id, () => entry);
    }
    for (final download in _downloads.values) {
      _entries.putIfAbsent(download.entry.id, () => download.entry);
    }
    _jobs.removeWhere((id, _) => !_entries.containsKey(id));
    if (_includeAuthored) {
      for (final board in campaignBoards) {
        final rules = [
          board.description,
          for (final rule in board.rules.map((rule) => rule.kind).toSet())
            '${rule.label}. ${rule.explanation}',
          if (board.fog != FogKind.none)
            'Place correct digits in the lit area to reveal the rest of the puzzle.',
        ].where((line) => line.isNotEmpty).join('\n\n');
        _entries[board.id] = LibraryEntry(
          id: board.id,
          title: board.title,
          author: 'Sodukromental',
          size: board.size,
          rules: rules,
          authored: true,
          completeRules: true,
          revision: 'authored-1',
          ruleIds: {
            ...board.rules.map((rule) => libraryRuleFor(rule.kind)),
            if (board.fog != FogKind.none) 'fog',
            if (board.size == 5 || board.size == 7) 'jigsaw',
          },
        );
      }
    }
  }

  Future<List<LibraryEntry>> _catalogSeed() async {
    final curated = {for (final entry in librarySeedEntries()) entry.id: entry};
    try {
      final data = await rootBundle.loadString('assets/library/catalog.json');
      return [
        ...curated.values,
        for (final entry
            in (jsonDecode(data) as List).cast<Map<String, dynamic>>())
          if (!curated.containsKey(entry['id'])) LibraryEntry.fromJson(entry),
      ];
    } on FlutterError {
      return curated.values.toList();
    }
  }

  Iterable<LibraryEntry> get entries => _entries.values;
  Iterable<LibraryJob> get jobs => _jobs.values;
  LibraryEntry? entry(String id) => _entries[id];
  LibraryDownload? download(String id) =>
      _downloads[id] ??
      (_includeAuthored && _entries[id]?.authored == true
          ? LibraryDownload(
              _entries[id]!,
              board: campaignBoards.firstWhere((board) => board.id == id),
            )
          : null);

  List<BoardSpec> get challenges => _downloads.values
      .where(
        (download) =>
            download.board != null &&
            download.entry.completeRules &&
            !download.manual &&
            download.refs.isEmpty &&
            !download.board!.solution.contains(0),
      )
      .map((download) => download.board!)
      .toList();

  bool saved(String id) => _downloads[id] != null;
  LibraryAvailability availability(String id) => _entries[id]?.authored == true
      ? LibraryAvailability.play
      : _downloads[id]?.availability ?? LibraryAvailability.original;

  LibrarySave? getSave(String id, [String? revision]) =>
      revision == null ? _latest[id] : _saves['$id|$revision'];

  Future<void> save(String id, String revision, LibrarySave value) async {
    final key = '$id|$revision';
    await _db.write('progress', key, value.toJson());
    if (_disposed) return;
    _saves[key] = value;
    _rememberSave(id, value);
    _changed();
  }

  void _rememberSave(String id, LibrarySave value) {
    final previous = _latest[id];
    if (previous == null || !previous.lastPlayed.isAfter(value.lastPlayed))
      _latest[id] = value;
  }

  List<LibraryEntry> browse({
    String search = '',
    Set<String> requireRules = const {},
    Set<String> excludeRules = const {},
    bool all = false,
    bool classic = false,
    bool onlySaved = false,
    bool featured = false,
    bool? authored,
    int? size,
    int? difficulty,
    bool unknownDifficulty = false,
    LibraryProgress? progress,
    LibrarySort sort = LibrarySort.publication,
  }) {
    final query = search.trim().toLowerCase();
    final rows = _entries.values.where((entry) {
      final active = _downloads[entry.id]?.entry ?? entry;
      final status = _latest[entry.id]?.progress ?? LibraryProgress.unplayed;
      return (!entry.withdrawn || saved(entry.id)) &&
          (authored == null || entry.authored == authored) &&
          (query.isEmpty ||
              '${entry.title} ${entry.author} ${entry.id}'
                  .toLowerCase()
                  .contains(query)) &&
          (!onlySaved || saved(entry.id)) &&
          (!featured || entry.videos.isNotEmpty) &&
          (size == null || active.size == size) &&
          (difficulty == null || entry.difficulty == difficulty) &&
          (!unknownDifficulty || entry.difficulty == null) &&
          (progress == null || status == progress) &&
          (!classic || (active.completeRules && active.ruleIds.isEmpty)) &&
          (excludeRules.isEmpty ||
              (active.completeRules &&
                  !active.ruleIds.any(excludeRules.contains))) &&
          (requireRules.isEmpty ||
              (all
                  ? active.ruleIds.containsAll(requireRules)
                  : active.ruleIds.any(requireRules.contains)));
    }).toList();
    int byDate(DateTime? a, DateTime? b) =>
        _nullable(a, b, (a, b) => b.compareTo(a));
    int byPublication(LibraryEntry a, LibraryEntry b) {
      final result = byDate(a.published, b.published);
      return result != 0 ? result : b.id.compareTo(a.id);
    }

    rows.sort((a, b) {
      final result = switch (sort) {
        LibrarySort.publication => 0,
        LibrarySort.difficulty => _nullable(
          a.difficulty,
          b.difficulty,
          (a, b) => a.compareTo(b),
        ),
        LibrarySort.rating => _nullable(
          a.rating,
          b.rating,
          (a, b) => b.compareTo(a),
        ),
        LibrarySort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        LibrarySort.played => byDate(
          _latest[a.id]?.lastPlayed,
          _latest[b.id]?.lastPlayed,
        ),
        LibrarySort.featured =>
          a.videos.isEmpty != b.videos.isEmpty
              ? (a.videos.isEmpty ? 1 : -1)
              : byDate(a.featuredDate, b.featuredDate),
      };
      if (result != 0) return result;
      if (sort == LibrarySort.publication &&
          !onlySaved &&
          a.authored != b.authored) {
        return a.authored ? -1 : 1;
      }
      return byPublication(a, b);
    });
    return rows;
  }

  Future<void> synchronize({bool refresh = false, String language = 'en'}) {
    if (_disposed) return Future.value();
    if (_synchronizing case final current?) return current;
    _syncRetry?.cancel();
    _queuedLanguage = language;
    final future = _sync(refresh, language);
    _synchronizing = future;
    unawaited(future.whenComplete(() => _synchronizing = null));
    return future;
  }

  Future<void> _sync(bool refresh, String language) async {
    syncing = true;
    syncMessage = null;
    _changed();
    var failed = false;
    try {
      if (refresh) {
        _prefs['next'] = libraryListing.toString();
        _prefs['listed'] = false;
        _prefs['pages'] = 0;
        _blockedDetails.clear();
        await _persistPreferences();
      }
      var head = _prefs['next'] as String? ?? libraryListing.toString();
      final seen = <String>{};
      final knownIds = <String>{};
      while (!complete && !_disposed) {
        if (!seen.add(head))
          throw const FormatException('The source repeated a catalog page.');
        final url = Uri.parse(head);
        final response = await _fetch(url);
        if (_disposed) return;
        final page = parseLibraryListing(
          requireLibraryResponse(response).text,
          url,
          _now(),
        );
        final committed = <LibraryEntry>[];
        for (final listing in page.entries) {
          if (!knownIds.add(listing.id)) continue;
          final old = _entries[listing.id];
          committed.add(
            old == null
                ? listing
                : old.withData({
                    'title': old.detailRead == null ? listing.title : old.title,
                    'author': old.detailRead == null
                        ? listing.author
                        : old.author,
                    'published': (listing.published ?? old.published)
                        ?.toIso8601String(),
                    'difficulty': listing.difficulty,
                    'estimated': listing.estimated,
                    'rating': listing.rating,
                  }),
          );
        }
        final next = page.next;
        final nextPrefs = {
          'next': next?.toString(),
          'listed': next == null,
          'pages': pages + 1,
        };
        await _db.transaction(() async {
          for (final entry in committed) {
            await _db.write('catalog', entry.id, entry.toJson());
          }
          await _db.write('preferences', 'source', {
            ..._prefs,
            ...nextPrefs,
            'dismissed': _dismissed.toList(),
            'settled': _settled,
          });
        });
        _prefs.addAll(nextPrefs);
        for (final entry in committed) {
          _entries[entry.id] = entry;
        }
        _changed();
        unawaited(_drain());
        if (next == null) break;
        head = next.toString();
      }
      final seedIds = librarySeedEntries().map((entry) => entry.id).toSet();
      final detailRows =
          _entries.values
              .where(
                (entry) =>
                    !entry.authored && !_blockedDetails.contains(entry.id),
              )
              .where(
                (entry) =>
                    entry.detailRead == null ||
                    (refresh &&
                        _now().difference(entry.detailRead!) >=
                            const Duration(days: 7)),
              )
              .toList()
            ..sort((a, b) {
              if (seedIds.contains(a.id) != seedIds.contains(b.id))
                return seedIds.contains(a.id) ? -1 : 1;
              return _newest(a, b);
            });
      for (final entry in detailRows) {
        if (_disposed) break;
        try {
          await details(entry.id, language: language);
        } on FormatException {
          _blockedDetails.add(entry.id);
        } on LibraryRequestFailure catch (error) {
          if (error.retry) rethrow;
          _blockedDetails.add(entry.id);
        }
      }
      _prefs['resumeSeconds'] = 0;
      await _persistPreferences();
    } on LibraryRequestFailure catch (error) {
      syncMessage = error.message;
      failed = true;
      if (error.retry) _scheduleSync(error.seconds);
    } on FormatException catch (error) {
      syncMessage = error.message;
      failed = true;
    } finally {
      syncing = false;
      if (!failed) syncMessage = null;
      _changed();
    }
  }

  void _scheduleSync(int sourceDelay) {
    if (_disposed) return;
    final oldDelay = _prefs['resumeSeconds'] as int? ?? 0;
    final delay = [
      10,
      sourceDelay,
      (oldDelay * 2).clamp(0, 600),
    ].reduce((a, b) => a > b ? a : b);
    _prefs['resumeSeconds'] = delay;
    _syncRetry = Timer(
      Duration(seconds: delay),
      () => unawaited(synchronize(language: _queuedLanguage ?? 'en')),
    );
  }

  Future<LibraryEntry> details(String id, {String language = 'en'}) {
    final old = _entries[id]!;
    if (old.authored ||
        (old.detailRead != null &&
            old.language == language &&
            _now().difference(old.detailRead!) <= const Duration(days: 7))) {
      return Future.value(old);
    }
    final key = '$id|$language';
    return _inFlightDetails.putIfAbsent(
      key,
      () => _fetchDetails(old, language).whenComplete(() {
        _inFlightDetails.remove(key);
      }),
    );
  }

  Future<LibraryEntry> _fetchDetails(LibraryEntry old, String selected) async {
    final languages = {selected, ...old.languages, 'en', 'de'};
    LibraryDetail? detail;
    for (final language in languages) {
      final url = old.portal.replace(
        queryParameters: {'chlang': language, 'id': old.id},
      );
      final response = await _fetch(url);
      if (_disposed) return old;
      if ([404, 410].contains(response.status)) {
        if (response.status == 410) {
          final retired = old.withData({
            'withdrawn': true,
            'detailRead': _now().toIso8601String(),
          });
          await _setEntry(retired);
          return retired;
        }
        continue;
      }
      try {
        final candidate = parseLibraryDetail(
          requireLibraryResponse(response).text,
          old,
          url,
          _now(),
        );
        if (candidate.entry.rules.isEmpty && !candidate.entry.withdrawn)
          continue;
        detail = candidate;
        break;
      } on FormatException {
        if (language == languages.last) rethrow;
      }
    }
    if (detail == null)
      throw const FormatException('Source puzzle text could not be read.');
    final videos = await _verifyVideos(detail, old.videos);
    final entry = detail.entry.withData({
      'videos': videos.map((video) => video.toJson()).toList(),
    });
    if (!_disposed) await _setEntry(entry);
    return entry;
  }

  Future<List<LibraryVideo>> _verifyVideos(
    LibraryDetail detail,
    List<LibraryVideo> previous,
  ) async {
    final known = {for (final video in previous) video.id: video};
    final curated = librarySeedEntries()
        .where((entry) => entry.id == detail.entry.id)
        .firstOrNull;
    for (final video in curated?.videos ?? const <LibraryVideo>[]) {
      known.putIfAbsent(video.id, () => video);
    }
    for (final id in {...detail.videoIds, ...known.keys}) {
      final watch = Uri.https('www.youtube.com', '/watch', {'v': id});
      final existing = known[id];
      try {
        final response = await _fetch(watch);
        if (response.status == 404 || response.status == 410) {
          if (existing != null)
            known[id] = LibraryVideo(
              id,
              existing.source,
              existing.reviewDate,
              date: existing.date,
              note: existing.note,
              available: false,
            );
          continue;
        }
        if (response.status != 200) continue;
        final document = html.parse(response.text);
        final urls = document
            .querySelectorAll(
              'link[itemprop="channelId"], meta[itemprop="channelId"], link[itemprop="url"]',
            )
            .map(
              (node) =>
                  node.attributes['content'] ?? node.attributes['href'] ?? '',
            );
        final official = urls.any(
          (value) =>
              value == 'UCC-UOdK8-mIjxBQm_ot1T-Q' ||
              value ==
                  'https://www.youtube.com/channel/UCC-UOdK8-mIjxBQm_ot1T-Q',
        );
        final unavailable = RegExp(
          r'"status"\s*:\s*"(?:UNPLAYABLE|ERROR)"[^}]{0,300}"reason"\s*:\s*"[^"]*(?:private|removed)',
          caseSensitive: false,
        ).hasMatch(response.text);
        if (unavailable && existing != null) {
          known[id] = LibraryVideo(
            id,
            existing.source,
            existing.reviewDate,
            date: existing.date,
            note: existing.note,
            available: false,
          );
        } else if (official &&
            (detail.videoIds.contains(id) || existing != null)) {
          final date = document
              .querySelector('meta[itemprop="datePublished"]')
              ?.attributes['content'];
          known[id] = LibraryVideo(
            id,
            'Author solve section and official Cracking the Cryptic upload',
            _now().toIso8601String(),
            date: DateTime.tryParse(date ?? '') ?? existing?.date,
            note: existing?.note,
          );
        }
      } on LibraryRequestFailure {
        // A transient failure never removes editorial credit.
      }
    }
    return known.values.toList()
      ..sort((a, b) => _nullable(a.date, b.date, (a, b) => b.compareTo(a)));
  }

  Future<void> _setEntry(LibraryEntry entry) async {
    await _db.write('catalog', entry.id, entry.toJson());
    _entries[entry.id] = entry;
    _changed();
  }

  Future<void> setAutomatic(bool enabled) async {
    _prefs['automatic'] = enabled;
    await _persistPreferences();
    _changed();
    if (enabled) {
      unawaited(resumeDownloads());
    } else {
      for (final job in _jobs.values.toList()) {
        if (!job.manual && job.state != LibraryJobState.failed) {
          await _putJob(
            LibraryJob(job.id, job.revision, false, LibraryJobState.paused),
          );
        }
      }
      _changed();
    }
  }

  Future<void> requestDownload(String id, {bool replace = false}) async {
    final entry = _entries[id];
    if (entry == null || entry.authored || entry.withdrawn) return;
    if (!replace && _downloads.containsKey(id)) return;
    _dismissed.remove(id);
    _settled.remove(id);
    await _persistPreferences();
    final existing = _jobs[id];
    await _putJob(
      LibraryJob(
        id,
        entry.revision,
        true,
        existing?.state == LibraryJobState.downloading
            ? LibraryJobState.downloading
            : LibraryJobState.queued,
      ),
    );
    _changed();
    unawaited(_drain());
  }

  Future<void> cancelDownload(String id) async {
    _dismissed.add(id);
    await _forgetJob(id);
    await _persistPreferences();
    _changed();
  }

  Future<void> removeDownload(String id) async {
    if (_entries[id]?.authored == true) return;
    _downloads.remove(id);
    await _db.erase('downloads', id);
    await cancelDownload(id);
  }

  Future<void> retryDownload(String id) async {
    final job = _jobs[id];
    if (job == null) return;
    await _putJob(LibraryJob(id, job.revision, true, LibraryJobState.queued));
    _changed();
    unawaited(_drain());
  }

  Future<void> resumeDownloads() async {
    for (final job in _jobs.values.toList()) {
      if (job.state == LibraryJobState.paused && (job.manual || automatic)) {
        await _putJob(
          LibraryJob(job.id, job.revision, job.manual, LibraryJobState.queued),
        );
      }
    }
    await _drain();
  }

  Future<void> _enqueueAutomatic() async {
    if (!automatic || _disposed) return;
    final active = _jobs.values
        .where((job) => job.state != LibraryJobState.failed)
        .length;
    if (active >= 10) return;
    final missing =
        _entries.values
            .where(
              (entry) =>
                  !entry.authored &&
                  !entry.withdrawn &&
                  !_downloads.containsKey(entry.id) &&
                  !_jobs.containsKey(entry.id) &&
                  !_dismissed.contains(entry.id) &&
                  _settled[entry.id] != entry.revision,
            )
            .toList()
          ..sort(_newest);
    for (final entry in missing.take(10 - active)) {
      await _putJob(
        LibraryJob(entry.id, entry.revision, false, LibraryJobState.queued),
      );
    }
  }

  Future<void> _drain() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      while (!_disposed) {
        await _enqueueAutomatic();
        final candidates =
            _jobs.values
                .where(
                  (job) =>
                      (job.manual || automatic) &&
                      (job.state == LibraryJobState.queued),
                )
                .toList()
              ..sort(
                (a, b) => a.manual == b.manual
                    ? _newest(_entries[a.id]!, _entries[b.id]!)
                    : a.manual
                    ? -1
                    : 1,
              );
        if (candidates.isEmpty) break;
        final selected = candidates.first;
        await _putJob(
          LibraryJob(
            selected.id,
            selected.revision,
            selected.manual,
            LibraryJobState.downloading,
          ),
        );
        _changed();
        try {
          await _runJob(selected.id);
        } on LibraryRequestFailure catch (error) {
          final active = _jobs[selected.id];
          if (active == null) continue;
          await _putJob(
            LibraryJob(
              active.id,
              active.revision,
              active.manual,
              error.retry ? LibraryJobState.paused : LibraryJobState.failed,
              reason: error.message,
            ),
          );
          if (error.retry) {
            _jobRetry?.cancel();
            _jobRetry = Timer(
              Duration(seconds: error.seconds > 30 ? error.seconds : 30),
              () => unawaited(resumeDownloads()),
            );
            break;
          }
        } on FileSystemException {
          await _pauseForStorage(selected.id);
          break;
        } on SqliteException catch (error) {
          if (error.resultCode != 13) rethrow; // SQLITE_FULL.
          await _pauseForStorage(selected.id);
          break;
        } on FormatException catch (error) {
          final active = _jobs[selected.id];
          if (active != null)
            await _putJob(
              LibraryJob(
                active.id,
                active.revision,
                active.manual,
                LibraryJobState.failed,
                reason: error.message,
              ),
            );
        } finally {
          _changed();
        }
      }
    } finally {
      _draining = false;
      _changed();
    }
  }

  Future<void> _runJob(String id) async {
    final entry = await details(id);
    if (_disposed || !_jobAllowed(id)) return;
    if (entry.withdrawn) {
      await _forgetJob(id);
      return;
    }
    LibraryDownload? result;
    try {
      result = await LibraryImport.read(entry, _fetch);
    } on LibraryRequestFailure catch (error) {
      if (error.retry) rethrow;
    }
    if (_disposed || !_jobAllowed(id)) return;
    if (result == null && entry.diagram != null && entry.rules.isNotEmpty) {
      final link = Uri.tryParse(entry.diagram!);
      if (link != null && isLibraryDiagramLink(link)) {
        final response = await _fetch(link);
        if (response.status == 200 && await _decodeImage(response.bytes)) {
          result = LibraryDownload(
            entry,
            diagram: base64Encode(response.bytes),
          );
        } else if (response.status == 429 || response.status >= 500) {
          requireLibraryResponse(response);
        }
      }
    }
    if (_disposed || !_jobAllowed(id)) return;
    final active = _jobs[id]!;
    if (result == null && active.manual) {
      await _putJob(
        LibraryJob(
          id,
          entry.revision,
          true,
          LibraryJobState.failed,
          reason: 'The original link has the available puzzle content.',
        ),
      );
      return;
    }
    final logged = await _db.transaction(() async {
      if (!_jobAllowed(id)) return false;
      if (result != null) await _db.write('downloads', id, result.toJson());
      await _db.write('preferences', 'source', {
        ..._prefs,
        'dismissed': _dismissed.toList(),
        'settled': {..._settled, id: entry.revision},
      });
      await _db.erase('jobs', id);
      return true;
    });
    if (!logged) return;
    _settled[id] = entry.revision;
    if (result != null) _downloads[id] = result;
    _jobs.remove(id);
  }

  Future<void> _pauseForStorage(String id) async {
    final active = _jobs[id];
    if (active == null) return;
    try {
      await _putJob(
        LibraryJob(
          id,
          active.revision,
          active.manual,
          LibraryJobState.paused,
          reason: 'Waiting for room on the device.',
        ),
      );
    } on SqliteException catch (error) {
      if (error.resultCode != 13) rethrow;
    } on FileSystemException {
      // The paused state remains visible even if the disk cannot store it yet.
    }
  }

  bool _jobAllowed(String id) {
    final job = _jobs[id];
    return job != null && !_dismissed.contains(id) && (job.manual || automatic);
  }

  Future<void> _putJob(LibraryJob job) async {
    _jobs[job.id] = job;
    await _db.write('jobs', job.id, job.toJson());
  }

  Future<void> _forgetJob(String id) async {
    _jobs.remove(id);
    await _db.erase('jobs', id);
  }

  Future<void> _persistPreferences() => _db.write('preferences', 'source', {
    ..._prefs,
    'dismissed': _dismissed.toList(),
    'settled': _settled,
  });

  int _newest(LibraryEntry a, LibraryEntry b) {
    final date = _nullable(a.published, b.published, (a, b) => b.compareTo(a));
    return date == 0 ? b.id.compareTo(a.id) : date;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> close() async {
    _disposed = true;
    _syncRetry?.cancel();
    _jobRetry?.cancel();
    _transport?.close();
    await _db.close();
    super.dispose();
  }
}

int _nullable<T>(T? a, T? b, int Function(T, T) compare) => a == null
    ? (b == null ? 0 : 1)
    : b == null
    ? -1
    : compare(a, b);

List<LibraryEntry> _parseLibrarySeed(String data) => (jsonDecode(data) as List)
    .cast<Map<String, dynamic>>()
    .map(LibraryEntry.fromJson)
    .toList();
