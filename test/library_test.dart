import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_source.dart';

final _at = DateTime(2026, 11, 25, 12);
const _classic =
    'classic530070000600195000098000060800060003400803001700020006060000280000419005000080079';

LibraryResponse _response(String text, [int status = 200]) =>
    LibraryResponse(status, Uint8List.fromList(utf8.encode(text)));

String _listing(Iterable<String> ids, {int? next}) =>
    '''
<table class="rp_raetselliste"><tr><th>Description</th></tr>
${ids.map((id) => '''
<tr><td></td><td><a href="/Raetselportal/Raetsel/zeigen.php?id=$id">Puzzle $id</a>
<span>by <a href="/Raetselportal/Benutzer/allgemein.php?name=A">Puzzle Author</a> (today, 10:10)</span></td>
<td><img src="/Raetselportal/bilder/ulevel2.png" alt="2"><span>89&nbsp;%</span></td></tr>
''').join()}
</table>
<div class="rp_navigation">${next == null ? 'Last page' : '<a href="spezial.php?start=$next&amp;listname=sudokus">Next page</a>'}</div>
''';

String _detail(
  String id, {
  String? content,
  String? diagram,
  String rules = 'Normal Sudoku rules apply.',
  String links = '',
}) =>
    '''
<div class="rp_titel"><h2>Puzzle $id</h2><span class="rp_eingestellt">Published on 24. November 2026, 11:24 by <a>Puzzle Author</a></span></div>
<div class="rp_html"><p>$rules</p>
${content == null ? '' : '<a href="$content">SudokuPad</a>'}
${diagram == null ? '' : '<img src="$diagram">'}
$links
</div>
<div class="rp_aenderdatum">Last changed on 25. November 2026, 09:00</div>
<div class="rp_tags"><a href="/Raetselportal/Suche/erweitert.php?tag_id=1001">Sudoku</a></div>
<table><tr><td>Difficulty:</td><td><img src="/Raetselportal/bilder/ulevel2.png" alt="2"></td></tr></table>
''';

Future<void> _until(bool Function() ready) async {
  final limit = DateTime.now().add(const Duration(seconds: 10));
  while (!ready() && DateTime.now().isBefore(limit)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  expect(ready(), isTrue);
}

String _testGrid() => jsonEncode({
  'cells': List.generate(
    4,
    (row) => List.generate(
      4,
      (col) => {
        if ((row, col) != (0, 1)) 'value': (row * 2 + row ~/ 2 + col) % 4 + 1,
      },
    ),
  ),
  'regions': List.generate(
    4,
    (region) => [
      for (var i = 0; i < 4; i++)
        [(region ~/ 2) * 2 + i ~/ 2, (region % 2) * 2 + i % 2],
    ],
  ),
  'metadata': {'rules': 'Normal Sudoku rules apply.'},
});

void main() {
  test(
    'source parser sees real navigation shape, estimated level and written evidence',
    () {
      final page = parseLibraryListing(
        _listing(['000ABC'], next: 20),
        libraryListing,
        _at,
      );
      expect(page.entries.single.published, DateTime(2026, 11, 25, 10, 10));
      expect(page.entries.single.estimated, isTrue);
      expect(page.entries.single.difficulty, 2);
      expect(page.entries.single.rating, 89);
      expect(page.next!.queryParameters['start'], '20');
      final detail = parseLibraryDetail(
        _detail(
          '000ABC',
          content: 'https://sudokupad.app/shortlink',
          rules:
              'Renban, Killer cages and gray circles are odd. <script>bad()</script>',
          links: '''
      <p>Featured on <a href="https://www.youtube.com/watch?v=oo2lmGOUOPQ">Cracking the Cryptic</a> and <a href="https://www.youtube.com/watch?v=V2SZu8oLEFs">Sudoku Sleuth</a>.</p>
      <p>Credits <a href="https://youtu.be/FXxdeBEKqfc">CtC</a></p>
      ''',
        ),
        page.entries.single,
        page.entries.single.portal,
        _at,
      );
      expect(detail.entry.content, 'https://sudokupad.app/shortlink');
      expect(detail.entry.rules, isNot(contains('bad()')));
      expect(detail.entry.ruleIds, containsAll(['renban', 'killer', 'parity']));
      expect(detail.entry.completeRules, isFalse);
      expect(detail.videoIds, ['oo2lmGOUOPQ']);
      expect(matchLibraryRules('Deutsches Flüstern', {}), {'whispers'});
    },
  );

  test('self-contained SudokuPad and the independent f-puzzles grid adapter', () {
    final source = const LibraryEntry(
      id: '000ABC',
      title: 'Sourced puzzle',
      author: 'Puzzle Author',
    );
    final scl = LibraryImport.decode(source, 'scl${_testGrid()}')!;
    expect(scl.entry.completeRules, isTrue);
    expect(scl.board!.size, 4);
    expect(scl.board!.solution[1], 2);
    expect(scl.board!.accepts(scl.board!.solution), isTrue);
    final base = jsonDecode(_testGrid()) as Map;
    final cells = base['cells'] as List;
    final fpuz = LibraryImport.decode(
      source,
      'fpuz${jsonEncode({
        'size': 4,
        'ruleset': 'Normal Sudoku rules apply.',
        'grid': [
          for (final row in cells.cast<List>()) [
              for (final cell in row.cast<Map>())
                if (cell['value'] case final int value?) {'given': true, 'value': value} else <String, dynamic>{},
            ],
        ],
        'thermometer': [
          {
            'lines': [
              ['R1C1', 'R1C2', 'R1C3'],
            ],
          },
        ],
      })}',
    )!;
    expect(fpuz.entry.ruleIds, {'thermometer'});
    expect(fpuz.board!.solution[1], 2);
    expect(fpuz.entry.completeRules, isTrue);
    expect(LibraryImport.decode(source, 'scl{"foglight":[[0,0]]}'), isNull);
  });

  test(
    'full paging commits and resumes after a transient failure, with overlap and locale fallback',
    () async {
      final folder = await Directory.systemTemp.createTemp('library-cursor');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/store.db');
      var failSecond = true;
      final visited = <String>[];
      Future<LibraryResponse> fetch(Uri uri) async {
        if (uri.path.endsWith('spezial.php')) {
          final page = uri.queryParameters['start'] ?? '0';
          visited.add(page);
          if (page == '0')
            return _response(_listing(['000ABC', '000DEF'], next: 20));
          if (failSecond) return _response('', 503);
          return _response(_listing(['000DEF', '000000']));
        }
        final id = uri.queryParameters['id']!;
        if (id == '000000' && uri.queryParameters['chlang'] == 'en')
          return _response('', 404);
        return _response(
          _detail(
            id,
            rules: 'Normal Sudoku rules apply. Killer cages show sums.',
          ),
        );
      }

      var store = await LibraryStore.open(
        executor: NativeDatabase(file),
        fetch: fetch,
        records: const [],
        includeAuthored: false,
        now: () => _at,
      );
      await store.synchronize();
      expect(store.pages, 1);
      expect(store.indexed, 2);
      expect(store.complete, isFalse);
      await store.close();
      failSecond = false;
      store = await LibraryStore.open(
        executor: NativeDatabase(file),
        fetch: fetch,
        records: const [],
        includeAuthored: false,
        now: () => _at,
      );
      await store.synchronize();
      expect(visited, ['0', '20', '20']);
      expect(store.indexed, 3);
      expect(store.complete, isTrue);
      expect(store.pages, 2);
      expect(store.entry('000000')!.language, 'de');
      expect(
        store.browse(search: '000000', requireRules: {'killer'}).single.id,
        '000000',
      );
      expect(store.browse(excludeRules: {'thermometer'}), isEmpty);
      await store.close();
    },
  );

  test(
    'manual playable and diagram saves survive offline, with pause and removal',
    () async {
      final folder = await Directory.systemTemp.createTemp('library-download');
      addTearDown(() => folder.delete(recursive: true));
      final database = File('${folder.path}/store.db');
      final records = [
        LibraryEntry(
          id: '000ABC',
          title: 'Playable',
          author: 'Puzzle Author',
          published: _at,
        ),
        const LibraryEntry(
          id: '000DEF',
          title: 'Diagram',
          author: 'Puzzle Author',
        ),
        const LibraryEntry(
          id: '000FGH',
          title: 'Portal',
          author: 'Puzzle Author',
        ),
      ];
      var offline = false;
      var temporaryFailure = true;
      var requests = 0;
      Future<LibraryResponse> fetch(Uri uri) async {
        requests++;
        if (offline) throw const LibraryRequestFailure('No connectivity.');
        if (uri.path.endsWith('zeigen.php')) {
          final id = uri.queryParameters['id']!;
          return _response(switch (id) {
            '000ABC' => _detail(id, content: 'https://sudokupad.app/playable'),
            '000DEF' => _detail(
              id,
              diagram: 'https://logic-masters.de/Dateien/diagram.png',
            ),
            _ => _detail(id),
          });
        }
        if (uri.path == '/api/puzzle/playable') {
          if (temporaryFailure) return _response('', 503);
          return _response(_classic);
        }
        return _response('diagram bytes');
      }

      var store = await LibraryStore.open(
        executor: NativeDatabase(database),
        fetch: fetch,
        records: records,
        includeAuthored: false,
        now: () => _at,
        decodeImage: (_) async => true,
      );
      expect(store.automatic, isFalse);
      expect(requests, 0);
      await store.requestDownload('000ABC');
      await _until(
        () => store.jobs.singleOrNull?.state == LibraryJobState.paused,
      );
      expect(store.availability('000ABC'), LibraryAvailability.original);
      temporaryFailure = false;
      await store.retryDownload('000ABC');
      await _until(
        () => store.availability('000ABC') == LibraryAvailability.play,
      );
      await store.requestDownload('000DEF');
      await _until(
        () => store.availability('000DEF') == LibraryAvailability.view,
      );
      final revision = store.download('000ABC')!.entry.revision;
      final digits = store.download('000ABC')!.board!.givens;
      await store.save(
        '000ABC',
        revision,
        LibrarySave(
          [
            LibraryPosition(digits, {
              2: {1, 4},
            }),
          ],
          0,
          _at,
          LibraryProgress.started,
        ),
      );
      expect(store.challenges.single.id, '000ABC');
      await store.close();

      offline = true;
      store = await LibraryStore.open(
        executor: NativeDatabase(database),
        fetch: fetch,
        records: records,
        includeAuthored: false,
      );
      expect(store.browse(onlySaved: true).map((entry) => entry.id).toSet(), {
        '000ABC',
        '000DEF',
      });
      expect(store.getSave('000ABC', revision)!.history.single.notes[2], {
        1,
        4,
      });
      expect(store.challenges.single.id, '000ABC');
      await store.removeDownload('000ABC');
      expect(store.availability('000ABC'), LibraryAvailability.original);
      expect(store.getSave('000ABC', revision), isNotNull);
      await store.setAutomatic(true);
      await _until(() => store.jobs.any((job) => job.id == '000FGH'));
      expect(store.jobs.any((job) => job.id == '000ABC'), isFalse);
      await store.setAutomatic(false);
      await store.close();
    },
  );

  test(
    'verified videos persist in feature order and open direct URLs offline',
    () async {
      final seeds = librarySeedEntries();
      final store = await LibraryStore.open(
        executor: NativeDatabase.memory(),
        fetch: (_) async => _response('', 503),
        records: seeds,
        includeAuthored: false,
      );
      final results = store.browse(featured: true, sort: LibrarySort.featured);
      expect(results.map((entry) => entry.id), ['000KPF', '000DQ2']);
      expect(
        results.first.videos.single.watch.toString(),
        'https://www.youtube.com/watch?v=oo2lmGOUOPQ',
      );
      expect(
        results.last.videos.single.note,
        contains('removed a given digit'),
      );
      await store.close();
    },
  );
}
