import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'library_models.dart';

final libraryListing = Uri.https(
  'logic-masters.de',
  '/Raetselportal/Suche/spezial.php',
  {'listname': 'sudokus', 'chlang': 'en'},
);

class LibraryResponse {
  const LibraryResponse(this.status, this.bytes, {this.headers = const {}});
  final int status;
  final Uint8List bytes;
  final Map<String, String> headers;
  String get text => utf8.decode(bytes, allowMalformed: true);
}

typedef LibraryFetch = Future<LibraryResponse> Function(Uri uri);
typedef LibraryTrace = void Function(String stage, String message, Uri? uri);

class LibraryRequestFailure implements Exception {
  const LibraryRequestFailure(
    this.message, {
    this.retry = true,
    this.seconds = 0,
  });
  final String message;
  final bool retry;
  final int seconds;
  @override
  String toString() => message;
}

class LibraryTransport {
  LibraryTransport({this.spacing = const Duration(milliseconds: 750)});
  final Duration spacing;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final _requests = <String, Completer<void>>{};
  final _turns = <Completer<void>>{};
  final _releaseTimers = <Timer>{};
  bool _closed = false;
  static const _closedFailure = LibraryRequestFailure(
    'The Library connection closed.',
    retry: false,
  );

  Future<LibraryResponse> get(Uri uri) async {
    if (_closed) throw _closedFailure;
    if (uri.scheme != 'https')
      throw const LibraryRequestFailure(
        'The source requires a secure link.',
        retry: false,
      );
    final previous = _requests[uri.host];
    final turn = Completer<void>();
    _requests[uri.host] = turn;
    _turns.add(turn);
    try {
      await previous?.future;
      if (_closed) throw _closedFailure;
      return await _read(uri);
    } finally {
      if (!_closed) {
        late final Timer release;
        release = Timer(spacing, () {
          _releaseTimers.remove(release);
          if (_requests[uri.host] == turn) _requests.remove(uri.host);
          _turns.remove(turn);
          turn.complete();
        });
        _releaseTimers.add(release);
      }
    }
  }

  Future<LibraryResponse> _read(Uri uri) async {
    try {
      final request = await _http
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Sodukromental/1.0 (Sudoku Library)',
      );
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > 8 * 1024 * 1024) {
          throw const LibraryRequestFailure(
            'Source file is too large.',
            retry: false,
          );
        }
        bytes.add(chunk);
      }
      return LibraryResponse(
        response.statusCode,
        bytes.takeBytes(),
        headers: {
          for (final name in [
            HttpHeaders.retryAfterHeader,
            HttpHeaders.contentTypeHeader,
            HttpHeaders.locationHeader,
          ])
            if (response.headers.value(name) case final value?) name: value,
        },
      );
    } on SocketException {
      if (_closed) throw _closedFailure;
      throw const LibraryRequestFailure('Waiting for an internet connection.');
    } on TimeoutException {
      if (_closed) throw _closedFailure;
      throw const LibraryRequestFailure('The source timed out.');
    } on HttpException {
      if (_closed) throw _closedFailure;
      throw const LibraryRequestFailure('The source connection ended.');
    } on TlsException {
      if (_closed) throw _closedFailure;
      throw const LibraryRequestFailure(
        'The secure connection to the source failed.',
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final waiter in _turns) {
      waiter.complete();
    }
    _turns.clear();
    for (final timer in _releaseTimers) {
      timer.cancel();
    }
    _releaseTimers.clear();
    _requests.clear();
    _http.close(force: true);
  }
}

LibraryResponse requireLibraryResponse(LibraryResponse response) {
  if (response.status == 200) return response;
  throw LibraryRequestFailure(
    response.status == 429
        ? 'The source asked us to slow down.'
        : 'Source returned HTTP ${response.status}.',
    retry: response.status == 429 || response.status >= 500,
    seconds:
        int.tryParse(response.headers[HttpHeaders.retryAfterHeader] ?? '') ?? 0,
  );
}

class LibraryListingPage {
  const LibraryListingPage(this.entries, this.next);
  final List<LibraryEntry> entries;
  final Uri? next;
}

LibraryListingPage parseLibraryListing(
  String input,
  Uri uri,
  DateTime fetchedAt,
) {
  final document = html.parse(input);
  final table = document.querySelector('.rp_raetselliste');
  if (table == null)
    throw const FormatException('The source listing layout changed.');
  final entries = <LibraryEntry>[];
  for (final row in table.querySelectorAll('tr')) {
    final link = row.querySelector('a[href*="zeigen.php"]');
    if (link == null) continue;
    final id = _puzzleId(uri, link);
    if (id == null) continue;
    final author = row.querySelector('a[href*="Benutzer"]');
    final detail = author?.parent?.text ?? '';
    entries.add(
      LibraryEntry(
        id: id,
        title: _string(link),
        author: _string(author),
        published: _date(detail, fetchedAt),
        difficulty: _difficulty(row)?.$1,
        estimated: _difficulty(row)?.$2 ?? false,
        rating: _rating(row.children.last.text),
      ),
    );
  }
  if (entries.isEmpty)
    throw const FormatException('No puzzle rows found in the source listing.');
  final current = int.tryParse(uri.queryParameters['start'] ?? '') ?? 0;
  final next =
      document
          .querySelectorAll('.rp_navigation a')
          .map((link) {
            final href = link.attributes['href'];
            if (href == null) return null;
            final next = uri.resolve(href);
            return next.host == uri.host &&
                    next.path == uri.path &&
                    next.queryParameters['listname'] == 'sudokus'
                ? next
                : null;
          })
          .nonNulls
          .toList()
        ..sort(
          (a, b) => (int.tryParse(a.queryParameters['start'] ?? '') ?? 0)
              .compareTo(int.tryParse(b.queryParameters['start'] ?? '') ?? 0),
        );
  final following = next
      .where(
        (page) =>
            (int.tryParse(page.queryParameters['start'] ?? '') ?? 0) > current,
      )
      .firstOrNull;
  return LibraryListingPage(
    entries,
    following?.replace(
      queryParameters: {...following.queryParameters, 'chlang': 'en'},
    ),
  );
}

class LibraryDetail {
  const LibraryDetail(this.entry, this.videoIds);
  final LibraryEntry entry;
  final List<String> videoIds;
}

const libraryDiscoveryVersion = 2;

LibraryDetail parseLibraryDetail(
  String input,
  LibraryEntry original,
  Uri uri,
  DateTime fetchedAt, {
  LibraryTrace? trace,
}) {
  final document = html.parse(input);
  final title = document.querySelector('.rp_titel h2');
  final body = document.querySelector('.rp_html');
  if (title == null || body == null) {
    final text =
        document.querySelector('.centercolumn')?.text.toLowerCase() ?? '';
    if (RegExp(
      r'has been (deleted|withdrawn)|wurde (gelöscht|zurückgezogen)',
    ).hasMatch(text)) {
      return LibraryDetail(
        original.withData({
          'withdrawn': true,
          'detailRead': fetchedAt.toIso8601String(),
        }),
        const [],
      );
    }
    throw const FormatException('The source puzzle layout changed.');
  }
  for (final node in body.querySelectorAll(
    'script, style, iframe, object, embed',
  )) {
    node.remove();
  }
  final tags = <String, String>{};
  for (final tag in document.querySelectorAll(
    '.rp_tags a, a[href*="erweitert.php?tag_id="]',
  )) {
    final id = Uri.tryParse(
      tag.attributes['href'] ?? '',
    )?.queryParameters['tag_id'];
    if (id != null)
      tags[id] = _string(tag).isEmpty
          ? tag.querySelector('img')?.attributes['alt'] ?? ''
          : _string(tag);
  }
  final block = _bodyText(body, uri);
  final stats = <String, Element>{};
  for (final row in document.querySelectorAll('tr')) {
    if (row.children.length == 2)
      stats[_string(row.children.first).toLowerCase()] = row.children.last;
  }
  final difficulty = _difficulty(
    stats['difficulty:'] ?? stats['schwierigkeit:'],
  );
  final candidates = _rankPlayerLinks(body, uri, _string(title), trace);
  final diagram = _selectPuzzleDiagram(body, uri, candidates, trace);
  trace?.call(
    'Setter page',
    'Found ${candidates.length} distinct player links and ${diagram == null ? 'no puzzle diagram' : 'a puzzle diagram'}.',
    uri,
  );
  final videoIds = <String>[];
  for (final a in body.querySelectorAll('a[href]')) {
    final label = _string(a).toLowerCase();
    final section = _string(a.parent).toLowerCase();
    final identifiesChannel =
        label.contains('cracking the cryptic') ||
        RegExp(r'\bctc\b').hasMatch(label);
    final identifiesSolve =
        section.contains('solve') ||
        section.contains('featured') ||
        section.contains('ctc-video') ||
        section.contains('lösung');
    final video = libraryYouTubeId(_link(uri, a));
    if (video != null && identifiesChannel && identifiesSolve)
      videoIds.add(video);
  }
  final publication = document.querySelector('.rp_eingestellt');
  final languages = document
      .querySelectorAll('img.langwahl')
      .map((image) => image.attributes['alt'])
      .nonNulls
      .where((code) => code == 'en' || code == 'de')
      .toSet();
  final revision =
      _date(_string(document.querySelector('.rp_aenderdatum')), fetchedAt) ??
      _date(_string(publication), fetchedAt) ??
      original.published;
  final sizeMatch = RegExp(
    r'\b([4-9])\s*(?:x|×)\s*\1\b',
    caseSensitive: false,
  ).firstMatch(block);
  return LibraryDetail(
    original.withData({
      'title': _string(title),
      'author': _string(publication?.querySelector('a')),
      'published':
          (_date(_string(publication), fetchedAt) ?? original.published)
              ?.toIso8601String(),
      'difficulty': difficulty?.$1 ?? original.difficulty,
      'estimated': difficulty?.$2 ?? original.estimated,
      'rating':
          _rating(_string(stats['rating:'] ?? stats['schönheit:'])) ??
          original.rating,
      'rules': block,
      'ruleIds': matchLibraryRules(block, tags).toList(),
      'tags': tags,
      'content': candidates.firstOrNull?.toString(),
      'alternativeContent': candidates
          .skip(1)
          .map((uri) => uri.toString())
          .toList(),
      'discoveryVersion': libraryDiscoveryVersion,
      'diagram': diagram?.toString(),
      'size': original.size ?? int.tryParse(sizeMatch?.group(1) ?? ''),
      'revision': revision?.toIso8601String() ?? original.revision,
      'language': uri.queryParameters['chlang'],
      'languages': {
        ...languages,
        uri.queryParameters['chlang'] ?? 'en',
      }.toList(),
      'detailRead': fetchedAt.toIso8601String(),
      'withdrawn': false,
    }),
    videoIds,
  );
}

String? libraryYouTubeId(Uri? uri) {
  if (uri == null) return null;
  final id = switch (uri.host) {
    'www.youtube.com' ||
    'youtube.com' ||
    'm.youtube.com' when uri.path == '/watch' => uri.queryParameters['v'],
    'youtu.be' when uri.pathSegments.length == 1 => uri.pathSegments.first,
    _ => null,
  };
  return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}

bool isLibraryPayloadLink(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    uri.fragment.isEmpty &&
    !isLibraryDiagramLink(uri) &&
    (isLibrarySetterLanding(uri) ||
        switch (uri.host) {
          'sudokupad.app' ||
          'www.sudokupad.app' ||
          'app.crackingthecryptic.com' ||
          'app.crackingthecryptic.tv' ||
          'sudokupad.svencodes.com' =>
            uri.pathSegments.isNotEmpty ||
                uri.queryParameters.containsKey('puzzleid'),
          'f-puzzles.com' || 'www.f-puzzles.com' =>
            uri.queryParameters.containsKey('load') ||
                uri.queryParameters.containsKey('id'),
          'tinyurl.com' ||
          'www.tinyurl.com' ||
          'shorturl.at' ||
          'www.shorturl.at' =>
            uri.pathSegments.length == 1 && uri.pathSegments.single.isNotEmpty,
          _ => false,
        });

/// Only one puzzle at an identifiable provider route may be inspected for a
/// forward link. Profiles, catalogs, random buttons and general sites are not
/// routes to a particular edition.
bool isLibrarySetterLanding(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment)
    return false;
  final path = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (path.length != 2 || !RegExp(r'^[\w-]+$').hasMatch(path.last))
    return false;
  if (uri.host == 'solvepaths.droste.ai') return path.first == 'play';
  if (path.first != 'puzzles') return false;
  if (uri.host == 'sudokubank.com' || uri.host == 'www.sudokubank.com') {
    return RegExp(
      r'^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$',
    ).hasMatch(path.last);
  }
  return RegExp(r'^[a-z0-9-]+\.github\.io$').hasMatch(uri.host) &&
      !const {
        'random',
        'lucky',
        'all',
        'noscript',
        'archive',
        'index',
        'search',
      }.contains(path.last.toLowerCase());
}

/// Returns one authored share only when the landing page identifies this
/// edition. The resolver still checks metadata in the downloaded board.
Uri? librarySetterPageTarget(
  String input,
  Uri page,
  LibraryEntry entry,
  LibraryTrace? trace,
) {
  if (!isLibrarySetterLanding(page)) return null;
  final document = html.parse(input);
  if (page.host == 'solvepaths.droste.ai') {
    // Solve Paths deliberately uses the same share ID as SudokuPad.
    final slug = page.pathSegments.where((part) => part.isNotEmpty).last;
    final target = document
        .querySelectorAll('a[href]')
        .map((a) => _link(page, a))
        .nonNulls
        .where(
          (uri) =>
              isLibraryPayloadLink(uri) &&
              uri.host == 'sudokupad.app' &&
              uri.pathSegments.length == 1 &&
              uri.pathSegments.first == slug,
        )
        .firstOrNull;
    trace?.call(
      'Setter helper',
      target == null
          ? 'The puzzle page did not link to its corresponding player identifier.'
          : 'Matched the intermediate page and player identifiers.',
      target ?? page,
    );
    return target;
  }
  final article =
      document.querySelector('article') ?? document.querySelector('main');
  if (article == null) {
    trace?.call(
      'Setter helper',
      'The page has no identifiable puzzle article.',
      page,
    );
    return null;
  }
  final ids = article
      .querySelectorAll('a[href]')
      .map((a) => _link(page, a))
      .nonNulls
      .where(
        (uri) =>
            const {
              'logic-masters.de',
              'www.logic-masters.de',
            }.contains(uri.host) &&
            uri.path == '/Raetselportal/Raetsel/zeigen.php',
      )
      .map((uri) => uri.queryParameters['id'])
      .nonNulls
      .toSet();
  final title = _identityText(_string(article.querySelector('h1')));
  if (ids.isNotEmpty
      ? ids.length != 1 || !ids.contains(entry.id)
      : title.isEmpty || title != _identityText(entry.title)) {
    trace?.call(
      'Setter helper',
      'The article does not identify this Logic Masters edition.',
      page,
    );
    return null;
  }
  final links = _rankPlayerLinks(
    article,
    page,
    entry.title,
    trace,
  ).where((uri) => !isLibrarySetterLanding(uri)).toList();
  if (links.length != 1) {
    trace?.call(
      'Setter helper',
      'Found ${links.length} distinct player destinations on the article. A unique share is required.',
      page,
    );
    return null;
  }
  trace?.call(
    'Setter helper',
    'Identified the authored puzzle article and its player destination.',
    links.single,
  );
  return links.single;
}

// Many authors use bare text, line breaks and links directly in .rp_html.
// The parent text in those posts includes every rule, example and older puzzle.
// Use the nearby caption, stopping at other links and unrelated content.
String _captionBefore(Element element, Element body, {bool diagram = false}) {
  var current = element;
  while (current != body && current.parent != null) {
    final parent = current.parent!;
    final siblings = parent.nodes;
    for (var i = siblings.indexOf(current) - 1; i >= 0; i--) {
      final node = siblings[i];
      if (node is Element) {
        if (node.localName == 'br') {
          if (diagram) continue;
          return '';
        }
        if (node.localName == 'a' || node.querySelector('a, img') != null) {
          return '';
        }
        // A list of rules ending ahead of a link is not its caption.
        if (const {'ol', 'ul', 'table'}.contains(node.localName)) return '';
      }
      final content = (node.text ?? '').trim();
      if (content.isNotEmpty) {
        return content.length > 280
            ? content.substring(content.length - 280)
            : content;
      }
    }
    // Only cross formatting wrappers. For diagrams a centered wrapper is
    // commonly preceded by a separate caption outside that wrapper.
    if (!diagram &&
        const {'p', 'div', 'li', 'td', 'figure'}.contains(parent.localName)) {
      return '';
    }
    current = parent;
  }
  return '';
}

final _otherPuzzle = RegExp(
  r'\b(example|examples|beispiel|tutorial|walkthrough|solution|lösung|previous|earlier|vorherige[snmr]?|frühere[snmr]?|another puzzle|last puzzle|older puzzle|random puzzle|other puzzles|more puzzles)\b',
  caseSensitive: false,
);
final _playLabel = RegExp(
  r'\b(play|solve|start|sudoku ?pad|f puzzles?|ctc(?: app)?|spielen|lösen|online)\b',
  caseSensitive: false,
);

String _anchorLabel(Element anchor) {
  final image = anchor.querySelector('img');
  return [
    _string(anchor),
    ?anchor.attributes['title'],
    ?anchor.attributes['aria-label'],
    ?image?.attributes['alt'],
    ?image?.attributes['title'],
  ].join(' ').trim();
}

List<Uri> _rankPlayerLinks(
  Element body,
  Uri base,
  String title,
  LibraryTrace? trace,
) {
  final normalizedTitle = _identityText(title);
  final ranked = <(int, int, Uri)>[];
  var otherLinks = 0;
  for (final (order, anchor) in body.querySelectorAll('a[href]').indexed) {
    final target = _link(base, anchor);
    if (target == null || !isLibraryPayloadLink(target)) {
      otherLinks++;
      continue;
    }
    final image = anchor.querySelector('img') != null;
    final label = _identityText(_anchorLabel(anchor));
    final before = _captionBefore(anchor, body).toLowerCase();
    final matchesTitle =
        normalizedTitle.isNotEmpty && label.contains(normalizedTitle);
    if (!matchesTitle &&
        (_otherPuzzle.hasMatch(label) || _otherPuzzle.hasMatch(before))) {
      trace?.call(
        'Setter page',
        'Skipped a link marked as an example, solution or another puzzle.',
        target,
      );
      continue;
    }
    var score = matchesTitle ? 100 : 0;
    if (_playLabel.hasMatch(label)) score += 30;
    if (_playLabel.hasMatch(before)) score += 5;
    if (image) score += 10;
    // A same-puzzle intermediate is a fallback after the direct share.
    if (isLibrarySetterLanding(target)) score -= 45;
    ranked.add((score, order, target));
  }
  ranked.sort((a, b) {
    final evidence = b.$1.compareTo(a.$1);
    return evidence == 0 ? a.$2.compareTo(b.$2) : evidence;
  });
  if (otherLinks > 0) {
    trace?.call(
      'Setter page',
      'Skipped $otherLinks links outside supported puzzle sources.',
      base,
    );
  }
  return ranked.map((item) => item.$3).toSet().toList();
}

Uri? _selectPuzzleDiagram(
  Element body,
  Uri base,
  List<Uri> candidates,
  LibraryTrace? trace,
) {
  Uri? best;
  var bestScore = -1;
  for (final image in body.querySelectorAll('img[src]')) {
    final source = _link(base, image, 'src');
    var anchor = image.parent;
    while (anchor != null && anchor != body && anchor.localName != 'a') {
      anchor = anchor.parent;
    }
    if (anchor == body) anchor = null;
    final target = anchor == null ? null : _link(base, anchor);
    final fullImage = target != null && isLibraryDiagramLink(target);
    final candidate = fullImage ? target : source;
    if (candidate == null || !isLibraryDiagramLink(candidate)) continue;
    final linkedToBoard = target != null && candidates.contains(target);
    final label = anchor == null
        ? [
            image.attributes['alt'],
            image.attributes['title'],
          ].nonNulls.join(' ')
        : _anchorLabel(anchor);
    if ((anchor != null && !fullImage && !linkedToBoard) ||
        _otherPuzzle.hasMatch(label) ||
        (!linkedToBoard &&
            _otherPuzzle.hasMatch(
              _captionBefore(anchor ?? image, body, diagram: true),
            ))) {
      trace?.call(
        'Setter page',
        'Skipped an illustration or a picture linked to another destination.',
        candidate,
      );
      continue;
    }
    var score = 0;
    if (fullImage) score = 1;
    if (linkedToBoard) score = target == candidates.firstOrNull ? 3 : 2;
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

String _identityText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool isLibraryDiagramLink(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    (((uri.host == 'logic-masters.de' || uri.host == 'www.logic-masters.de') &&
            uri.path.startsWith('/Dateien/')) ||
        ((uri.host == 'sudokupad.app' ||
                uri.host == 'images.ctc-puzzles.com') &&
            RegExp(
              r'\.(png|jpg|jpeg|webp)$',
              caseSensitive: false,
            ).hasMatch(uri.path)));

const reviewedLibraryVideos = <String, LibraryVideo>{
  '000KPF': LibraryVideo(
    'oo2lmGOUOPQ',
    'Logic Masters 000KPF and official Cracking the Cryptic upload',
    '2026-11-25',
  ),
  '000DQ2': LibraryVideo(
    'FXxdeBEKqfc',
    'Logic Masters 000DQ2 and official Cracking the Cryptic upload',
    '2026-11-25',
    note:
        'The author removed a given digit after the video. The portal grid is the revised version.',
  ),
};

List<LibraryEntry> librarySeedEntries() => [
  LibraryEntry(
    id: '000UBK',
    title: 'Classic Sudoku for Beginners',
    author: 'addie',
    published: DateTime(2026, 8, 12, 9, 2),
    difficulty: 1,
    rating: 81,
    size: 9,
    content: 'https://sudokupad.app/9rm19tyycb',
    diagram:
        'https://logic-masters.de/Dateien/bild.php?data=fab0e656-51750-33393239362d31',
  ),

  LibraryEntry(
    id: '000KPF',
    title: 'The Most Beautiful Mathematical Equation',
    author: 'Tobias Brixner',
    published: DateTime(2024, 11, 15, 13, 54),
    difficulty: 1,
    rating: 93,
    size: 9,
    content: 'https://sudokupad.app/6bqix93gqg',
    diagram:
        'https://logic-masters.de/Dateien/bild.php?data=c37b75e5-35656-32363833352d31',
    ruleIds: const {'renban', 'whispers', 'parity'},
    videos: [_datedReviewedVideo('000KPF', DateTime(2024, 11, 22))],
  ),
  LibraryEntry(
    id: '000DQ2',
    title: 'The Magic Column',
    author: 'marty_sears',
    published: DateTime(2023, 4, 26, 10, 26),
    difficulty: 4,
    rating: 96,
    size: 10,
    content: 'https://sudokupad.app/njv2olnw9m',
    diagram:
        'https://logic-masters.de/Dateien/bild.php?data=cfe11a44-52523-31373738362d31',
    ruleIds: const {'diagonal'},
    videos: [_datedReviewedVideo('000DQ2', DateTime(2022, 11, 4))],
  ),
  LibraryEntry(
    id: '000UN9',
    title: 'Whispers of the Zeitgeist',
    author: 'starchacer',
    published: DateTime(2026, 8, 31, 14, 20),
    difficulty: 1,
    rating: 89,
    size: 9,
    content: 'https://sudokupad.app/tcntcvxsyx',
    diagram:
        'https://logic-masters.de/Dateien/bild.php?data=fe5dd63d-52347-33393731372d31',
    ruleIds: const {'diagonal', 'whispers', 'renban', 'killer', 'xv', 'parity'},
  ),
];

LibraryVideo _datedReviewedVideo(String id, DateTime date) {
  final video = reviewedLibraryVideos[id]!;
  return LibraryVideo(
    video.id,
    video.source,
    video.reviewDate,
    date: date,
    note: video.note,
  );
}

String? _puzzleId(Uri uri, Element link) {
  final id = _link(uri, link)?.queryParameters['id'];
  return id != null && RegExp(r'^[0-9A-Z]{6}$').hasMatch(id) ? id : null;
}

Uri? _link(Uri base, Element element, [String attr = 'href']) {
  final raw = element.attributes[attr];
  if (raw == null || raw.isEmpty) return null;
  try {
    var resolved = base.resolve(raw.trim());
    if (resolved.scheme == 'http' &&
        !resolved.hasPort &&
        resolved.userInfo.isEmpty) {
      final https = resolved.replace(scheme: 'https');
      if (isLibraryPayloadLink(https) || isLibraryDiagramLink(https))
        resolved = https;
    }
    return resolved.scheme == 'https' && resolved.userInfo.isEmpty
        ? resolved
        : null;
  } on FormatException {
    return null;
  }
}

String _string(Element? element) =>
    element?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

String _bodyText(Element element, Uri base) {
  final buffer = StringBuffer();
  void visit(Node node) {
    if (node is Text) buffer.write(node.data.replaceAll(RegExp(r'\s+'), ' '));
    if (node is! Element) return;
    if (_link(base, node) case final href? when node.localName == 'a') {
      if (isLibraryPayloadLink(href) || libraryYouTubeId(href) != null) return;
    }
    final block = [
      'p',
      'br',
      'div',
      'ul',
      'ol',
      'li',
      'h2',
      'h3',
      'tr',
    ].contains(node.localName);
    if (block) buffer.write('\n');
    if (node.localName == 'li') buffer.write('• ');
    for (final child in node.nodes) {
      visit(child);
    }
    if (block) buffer.write('\n');
  }

  visit(element);
  return buffer
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n\n');
}

(int, bool)? _difficulty(Element? node) {
  final image = node?.querySelector('img[src*="level"]');
  final level = int.tryParse(image?.attributes['alt'] ?? '');
  if (level == null || level <= 0) return null;
  return (level, image!.attributes['src']?.contains('ulevel') ?? false);
}

int? _rating(String text) =>
    int.tryParse(RegExp(r'(\d+)\s*%').firstMatch(text)?.group(1) ?? '');

DateTime? _date(String text, DateTime now) {
  final lower = text.toLowerCase();
  final relative = RegExp(
    r'(today|yesterday|heute|gestern),?\s+(\d{1,2}):(\d{2})',
  ).firstMatch(lower);
  if (relative != null) {
    final previous = ['yesterday', 'gestern'].contains(relative.group(1));
    return DateTime(
      now.year,
      now.month,
      now.day - (previous ? 1 : 0),
      int.parse(relative.group(2)!),
      int.parse(relative.group(3)!),
    );
  }
  final match = RegExp(
    r'(\d{1,2})[. ]+([a-zä]+)\.?\s+(\d{4})(?:,\s*(\d{1,2}):(\d{2}))?',
  ).firstMatch(lower);
  if (match == null) return null;
  const months = [
    ['january', 'januar', 'jan'],
    ['february', 'februar', 'feb'],
    ['march', 'märz', 'mar'],
    ['april', 'apr'],
    ['may', 'mai'],
    ['june', 'juni', 'jun'],
    ['july', 'juli', 'jul'],
    ['august', 'aug'],
    ['september', 'sep'],
    ['october', 'oktober', 'oct', 'okt'],
    ['november', 'nov'],
    ['december', 'dezember', 'dec', 'dez'],
  ];
  final month = months.indexWhere((month) => month.contains(match.group(2)));
  if (month < 0) return null;
  return DateTime(
    int.parse(match.group(3)!),
    month + 1,
    int.parse(match.group(1)!),
    int.tryParse(match.group(4) ?? '') ?? 0,
    int.tryParse(match.group(5) ?? '') ?? 0,
  );
}
