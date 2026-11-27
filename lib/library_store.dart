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
    this._readSource,
    this._transport,
    this._now,
    this._decodeImage,
    this._includeAuthored,
  );

  final _LibraryDatabase _db;
  final LibraryFetch _readSource;
  final _activeRequests = <Completer<LibraryResponse>>{};
  static const _closedFailure = LibraryRequestFailure(
    'The Library connection closed.',
    retry: false,
  );
  final LibraryTransport? _transport;
  final DateTime Function() _now;
  final Future<bool> Function(Uint8List) _decodeImage;
  final bool _includeAuthored;
  final _entries = <String, LibraryEntry>{};
  final _downloads = <String, LibraryDownload>{};
  final _archives = <String, LibraryDownload>{};
  final _saves = <String, LibrarySave>{};
  final _diagramSheets = <String, Map<String, dynamic>>{};
  final _latest = <String, LibrarySave>{};
  final _jobs = <String, LibraryJob>{};
  final _dismissed = <String>{};
  final _inFlightDetails = <String, Future<LibraryEntry>>{};
  final _blockedDetails = <String>{};
  final _settled = <String, String>{};
  final _prefs = <String, dynamic>{};
  Timer? _syncRetry;
  Timer? _jobRetry;
  Future<void>? _downloadWork;
  Future<void>? _closing;
  bool _disposed = false;
  bool syncing = false;
  bool get opensSavedShelf => _prefs['savedShelf'] == true;

  Future<void> rememberShelf(bool saved) async {
    if (opensSavedShelf == saved) return;
    _prefs['savedShelf'] = saved;
    await _persistPreferences();
  }

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
    for (final item in results[1].entries) {
      final download = LibraryDownload.fromJson(item.value);
      if (item.key.contains('|archive|')) {
        _archives[item.key] = download;
      } else {
        _downloads[item.key] = download;
      }
    }
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
    for (final row in results[4].entries.where(
      (row) => row.key.startsWith('diagram-sheet:'),
    )) {
      _diagramSheets[row.key] = row.value;
    }
    _dismissed.addAll((_prefs['dismissed'] as List? ?? []).cast<String>());
    _settled.addAll((_prefs['settled'] as Map? ?? {}).cast<String, String>());
    final seeds = records ?? await _catalogSeed();
    for (final seed in seeds) {
      final current = _entries[seed.id];
      if (current == null) {
        _entries[seed.id] = seed;
      } else if (seed.videos.isNotEmpty) {
        final videos = {
          for (final video in seed.videos) video.id: video,
          for (final video in current.videos) video.id: video,
        };
        _entries[seed.id] = current.withData({
          'videos': videos.values.map((video) => video.toJson()).toList(),
        });
      }
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
    await _reEvaluateRetainedPackages();
  }

  Future<void> _reEvaluateRetainedPackages() async {
    for (final item in _downloads.entries.toList()) {
      final old = item.value;
      final provenance = old.provenance;
      final payload = provenance['sourcePayload'] as String?;
      final version = provenance['resolverVersion'] as int? ?? 0;
      if (payload == null || version >= LibraryImport.resolverVersion) continue;
      // Working installations can contain rewritten, device-local image
      // references. Keep them intact when a new import format is added.
      if (old.availability == LibraryAvailability.play &&
          old.definition != null)
        continue;
      final decoded = LibraryImport.decode(old.entry, payload);
      if (decoded == null || decoded.availability != LibraryAvailability.play)
        continue;
      // Newly supported artwork may need an online fetch before it can play.
      // Existing offline copies keep their current status until then.
      if (decoded.refs.any(
        (layer) => RegExp(
          r'https?://',
          caseSensitive: false,
        ).hasMatch(jsonEncode(layer)),
      ))
        continue;
      final refreshed = LibraryDownload(
        decoded.entry,
        board: decoded.board,
        refs: decoded.refs,
        diagram: old.diagram,
        manual: decoded.manual,
        finalCheck: decoded.finalCheck,
        definition: decoded.definition,
        supportReasons: decoded.supportReasons,
        assetManifest: old.assetManifest,
        provenance: {
          ...provenance,
          'resolverVersion': LibraryImport.resolverVersion,
          'reEvaluatedOffline': true,
        },
      );
      await _db.write('downloads', item.key, refreshed.toJson());
      _downloads[item.key] = refreshed;
    }
  }

  Future<List<LibraryEntry>> _catalogSeed() async {
    final index = {for (final entry in librarySeedEntries()) entry.id: entry};
    try {
      final data = await rootBundle.loadString('assets/library/catalog.json');
      for (final entry in await compute(_parseLibrarySeed, data)) {
        index.putIfAbsent(entry.id, () => entry);
      }
    } on FlutterError {
      // Authored puzzles and curated sources remain available without the snapshot.
    }
    try {
      final data = await rootBundle.loadString('assets/library/features.json');
      for (final entry in (jsonDecode(data) as Map<String, dynamic>).entries) {
        final source = index[entry.key];
        if (source == null) continue;
        final known = {
          for (final video in source.videos) video.id: video.toJson(),
        };
        for (final video
            in (entry.value as List).cast<Map<String, dynamic>>()) {
          final id = video['id'] as String;
          known[id] = {...video, ...?known[id]};
        }
        index[entry.key] = source.withData({'videos': known.values.toList()});
      }
    } on FlutterError {
      // A catalog snapshot can be shipped without a feature index.
    }
    return index.values.toList();
  }

  Iterable<LibraryEntry> get entries => _entries.values;
  Iterable<LibraryJob> get jobs => _jobs.values;
  Iterable<LibraryDownload> archivedDownloads(String id) => _archives.entries
      .where((item) => item.key.startsWith('$id|archive|'))
      .map((item) => item.value);
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
  String availabilityLabel(String id) {
    final value = availability(id);
    if (value != LibraryAvailability.original) return value.label;
    if (_downloads.containsKey(id))
      return 'Saved reference · player unavailable';
    if (_settled.containsKey(id) ||
        _jobs[id]?.state == LibraryJobState.failed) {
      return 'No offline puzzle saved';
    }
    return value.label;
  }

  LibraryAvailability availability(String id) => _entries[id]?.authored == true
      ? LibraryAvailability.play
      : _downloads[id]?.availability ?? LibraryAvailability.original;

  LibrarySave? getSave(String id, [String? revision]) =>
      revision == null ? _latest[id] : _saves['$id|$revision'];

  Map<String, dynamic>? getDiagramSheet(String id, String revision) =>
      _diagramSheets['diagram-sheet:$id|$revision'];

  Future<void> saveDiagramSheet(
    String id,
    String revision,
    Map<String, dynamic> sheet,
  ) async {
    if (_disposed) return;
    final key = 'diagram-sheet:$id|$revision';
    await _db.write('preferences', key, sheet);
    if (_disposed) return;
    _diagramSheets[key] = sheet;
    _changed();
  }

  Future<void> save(String id, String revision, LibrarySave value) async {
    if (_disposed) return;
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
    final future = _sync(refresh, language).whenComplete(() {
      _synchronizing = null;
    });
    _synchronizing = future;
    return future;
  }

  Future<LibraryResponse> _fetch(Uri uri) {
    if (_disposed) return Future.error(_closedFailure);
    final result = Completer<LibraryResponse>();
    _activeRequests.add(result);
    Future<LibraryResponse>.sync(() => _readSource(uri)).then(
      (response) {
        if (!result.isCompleted) result.complete(response);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future.whenComplete(() {
      _activeRequests.remove(result);
    });
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
        _prefs.remove('headNext');
        _blockedDetails.clear();
        await _persistPreferences();
      }
      final lastHead = DateTime.tryParse(
        _prefs['headCheckedAt'] as String? ?? '',
      );
      final latestOnly =
          complete &&
          !refresh &&
          (_prefs['headNext'] != null ||
              lastHead == null ||
              _now().difference(lastHead) >= const Duration(hours: 12));
      var head =
          (latestOnly ? _prefs['headNext'] : _prefs['next']) as String? ??
          libraryListing.toString();
      final seen = <String>{};
      final knownIds = <String>{};
      while ((!complete || latestOnly) && !_disposed) {
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
        final discovered = page.entries.any(
          (entry) => !_entries.containsKey(entry.id),
        );
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
        final next = !latestOnly || discovered ? page.next : null;
        final nextPrefs = latestOnly
            ? {
                'headNext': next?.toString(),
                if (next == null) 'headCheckedAt': _now().toIso8601String(),
              }
            : {
                'next': next?.toString(),
                'listed': next == null,
                'pages': pages + 1,
                if (url.queryParameters['start'] == null)
                  'headCheckedAt': _now().toIso8601String(),
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
      if (_disposed) return;
      _prefs['resumeSeconds'] = 0;
      await _persistPreferences();
    } on LibraryRequestFailure catch (error) {
      if (_disposed) return;
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

  Future<LibraryEntry> details(
    String id, {
    String language = 'en',
    bool refresh = false,
  }) {
    final old = _entries[id]!;
    if (_disposed ||
        old.authored ||
        (!refresh &&
            old.discoveryVersion == libraryDiscoveryVersion &&
            old.detailRead != null &&
            (old.language == language || old.requestedLanguage == language) &&
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
        if (candidate.entry.rules.isEmpty &&
            candidate.entry.content == null &&
            candidate.entry.diagram == null &&
            !candidate.entry.withdrawn)
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
      'requestedLanguage': selected,
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
      if (_disposed) break;
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
    if (_disposed) return;
    _prefs['automatic'] = enabled;
    await _persistPreferences();
    _changed();
    if (enabled) {
      unawaited(resumeDownloads());
    } else {
      for (final job in _jobs.values.toList()) {
        if (_disposed) return;
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
    if (_disposed) return;
    final entry = _entries[id];
    if (entry == null || entry.authored || entry.withdrawn) return;
    if (!replace && _downloads[id]?.availability == LibraryAvailability.play)
      return;
    _dismissed.remove(id);
    _settled.remove(id);
    await _persistPreferences();
    if (_disposed) return;
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
    if (_disposed) return;
    _dismissed.add(id);
    await _forgetJob(id);
    if (_disposed) return;
    await _persistPreferences();
    _changed();
  }

  Future<void> removeDownload(String id) async {
    if (_disposed || _entries[id]?.authored == true) return;
    _downloads.remove(id);
    await _db.erase('downloads', id);
    await cancelDownload(id);
  }

  Future<void> retryDownload(String id) async {
    if (_disposed) return;
    final job = _jobs[id];
    if (job == null) return;
    final entry = _entries[id];
    if (job.state == LibraryJobState.failed && entry != null) {
      await _setEntry(entry.withData({'detailRead': null}));
    }
    await _putJob(LibraryJob(id, job.revision, true, LibraryJobState.queued));
    _changed();
    unawaited(_drain());
  }

  Future<void> resumeDownloads() async {
    for (final job in _jobs.values.toList()) {
      if (_disposed) return;
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
                  (_downloads[entry.id]?.availability !=
                          LibraryAvailability.play ||
                      (entry.revision.isNotEmpty &&
                          _downloads[entry.id]!.entry.revision !=
                              entry.revision)) &&
                  !_jobs.containsKey(entry.id) &&
                  !_dismissed.contains(entry.id) &&
                  _settled[entry.id] != _acquisitionKey(entry),
            )
            .toList()
          ..sort(_newest);
    for (final entry in missing.take(10 - active)) {
      if (!automatic || _disposed) break;
      if (_jobs.containsKey(entry.id) || _dismissed.contains(entry.id))
        continue;
      await _putJob(
        LibraryJob(entry.id, entry.revision, false, LibraryJobState.queued),
      );
    }
  }

  String _acquisitionKey(LibraryEntry entry) =>
      '$libraryDiscoveryVersion/${LibraryImport.resolverVersion}/${entry.revision}';

  Future<void> _drain() {
    if (_disposed) return Future.value();
    if (_downloadWork case final current?) return current;
    final work = _runDownloadQueue().whenComplete(() {
      _downloadWork = null;
      _changed();
    });
    _downloadWork = work;
    return work;
  }

  Future<void> _runDownloadQueue() async {
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
          if (_disposed) return;
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
          if (_disposed) return;
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
    } on SqliteException {
      if (!_disposed) rethrow;
    }
  }

  Future<void> _runJob(String id) async {
    final previous = _downloads[id];
    final selected = _entries[id]!;
    final entry = await details(
      id,
      language: selected.requestedLanguage ?? selected.language,
      refresh: previous != null && _jobs[id]?.manual == true,
    );
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
    if (result?.availability != LibraryAvailability.play) {
      for (final language in entry.languages.where(
        (language) =>
            (language == 'en' || language == 'de') &&
            language != entry.language,
      )) {
        if (!_jobAllowed(id) || _disposed) return;
        final uri = entry.portal.replace(
          queryParameters: {'chlang': language, 'id': id},
        );
        final page = await _fetch(uri);
        if (page.status == 404 || page.status == 410) continue;
        LibraryEntry other;
        try {
          other = parseLibraryDetail(
            requireLibraryResponse(page).text,
            entry,
            uri,
            _now(),
          ).entry;
        } on FormatException {
          // A malformed translation must not discard the primary diagram.
          continue;
        }
        if (other.withdrawn) continue;
        final seen = {entry.content, ...entry.alternativeContent};
        final links = [
          other.content,
          ...other.alternativeContent,
        ].nonNulls.where((url) => !seen.contains(url)).toList();
        if (links.isEmpty) continue;
        final translated = await LibraryImport.read(
          entry.withData({
            'content': links.first,
            'alternativeContent': links.skip(1).toList(),
          }),
          _fetch,
        );
        if (translated != null &&
            (result == null ||
                translated.availability == LibraryAvailability.play)) {
          result = translated;
        }
        if (result?.availability == LibraryAvailability.play) break;
      }
    }
    if (_disposed || !_jobAllowed(id)) return;
    if ((result == null ||
            result.availability == LibraryAvailability.original) &&
        entry.diagram != null) {
      final link = Uri.tryParse(entry.diagram!);
      if (link != null && isLibraryDiagramLink(link)) {
        final response = await _fetch(link);
        if (response.status == 200 && await _decodeImage(response.bytes)) {
          result = (result ?? LibraryDownload(entry)).withDiagram(
            base64Encode(response.bytes),
          );
        } else if (response.status == 429 || response.status >= 500) {
          requireLibraryResponse(response);
        }
      }
    }
    if (_disposed || !_jobAllowed(id)) return;
    if (result?.availability == LibraryAvailability.play &&
        previous?.diagram != null &&
        previous!.entry.revision == entry.revision) {
      result = result!.withDiagram(previous.diagram!);
    }
    final active = _jobs[id]!;
    if ((result == null && active.manual) ||
        (previous != null &&
            (result?.availability.index ?? -1) < previous.availability.index)) {
      await _putJob(
        LibraryJob(
          id,
          entry.revision,
          active.manual,
          LibraryJobState.failed,
          reason: previous != null
              ? 'No better offline copy was found. Your saved copy is available.'
              : 'No playable grid or downloadable puzzle diagram was found on the setter’s puzzle page.',
        ),
      );
      return;
    }
    final logged = await _db.transaction(() async {
      if (!_jobAllowed(id)) return false;
      if (result != null) {
        final previous = _downloads[id];
        final oldFingerprint = previous?.provenance['fingerprint'] as String?;
        final newFingerprint = result.provenance['fingerprint'] as String?;
        if (previous != null &&
            oldFingerprint != null &&
            newFingerprint != null &&
            oldFingerprint != newFingerprint) {
          await _db.write(
            'downloads',
            '$id|archive|$oldFingerprint',
            previous.toJson(),
          );
        }
        await _db.write('downloads', id, result.toJson());
      }
      await _db.write('preferences', 'source', {
        ..._prefs,
        'dismissed': _dismissed.toList(),
        'settled': {..._settled, id: _acquisitionKey(entry)},
      });
      await _db.erase('jobs', id);
      return true;
    });
    if (!logged) return;
    _settled[id] = _acquisitionKey(entry);
    if (result != null) {
      final previous = _downloads[id];
      final oldFingerprint = previous?.provenance['fingerprint'] as String?;
      final newFingerprint = result.provenance['fingerprint'] as String?;
      if (previous != null &&
          oldFingerprint != null &&
          newFingerprint != null &&
          oldFingerprint != newFingerprint) {
        _archives['$id|archive|$oldFingerprint'] = previous;
      }
      _downloads[id] = result;
    }
    _jobs.remove(id);
  }

  Future<void> _pauseForStorage(String id) async {
    if (_disposed) return;
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

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _disposed = true;
    _syncRetry?.cancel();
    _jobRetry?.cancel();
    for (final request in _activeRequests.toList()) {
      if (!request.isCompleted) request.completeError(_closedFailure);
    }
    _transport?.close();
    final operations = <Future<dynamic>>[
      if (_synchronizing case final sync?) sync,
      if (_downloadWork case final downloads?) downloads,
      ..._inFlightDetails.values,
    ];
    try {
      await Future.wait(
        operations.map((work) async {
          try {
            await work;
          } on LibraryRequestFailure {
            // Waiting network operations may complete with the requested shutdown.
          }
        }),
      );
    } finally {
      await _db.close();
      super.dispose();
    }
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
