import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_digest.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_source.dart';

LibraryResponse response(String value, {int status = 200, String? location}) =>
    LibraryResponse(
      status,
      Uint8List.fromList(utf8.encode(value)),
      headers: {if (location != null) 'location': location},
    );

Map<String, dynamic> cells(int size) => {
  'cells': List.generate(size, (_) => List.generate(size, (_) => {})),
  'regions': const [],
};

void main() {
  test('SHA-256 binds retained payload bytes', () {
    expect(
      librarySha256('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('000S4K identity evidence outranks an earlier valid board', () {
    const entry = LibraryEntry(
      id: '000S4K',
      title: 'Ringing the Changes',
      author: 'Fool on Hill',
    );
    final detail = parseLibraryDetail(
      '''
      <div class="rp_titel"><h2>Ringing the Changes</h2></div>
      <div class="rp_html">
        <p>My previous puzzle <a href="https://sudokupad.app/5tqg4ino2g">Whisper, who dares?</a></p>
        <p><a href="https://sudokupad.app/zhsltyic9o">Solve Ringing the Changes on SudokuPad</a></p>
      </div>
      ''',
      entry,
      entry.portal,
      DateTime.utc(2026, 11, 26),
    );
    expect(detail.entry.content, 'https://sudokupad.app/zhsltyic9o');
  });

  test(
    '000VSG alias extracts inline data and rejects cycles and HTML shells',
    () async {
      const classic =
          'classic530070000600195000098000060800060003400803001700020006060000280000419005000080079';
      const entry = LibraryEntry(
        id: '000VSG',
        title: 'The Graveyard Of Totality',
        author: 'fjam',
        content: 'https://tinyurl.com/graveyardoftotality',
      );
      final resolved = await LibraryImport.resolve(
        entry,
        (_) async => response(
          '',
          status: 301,
          location: 'https://sudokupad.app/$classic',
        ),
      );
      expect(resolved?.payload, classic);
      final cycle = await LibraryImport.resolve(
        entry,
        (_) async => response(
          '',
          status: 302,
          location: 'https://tinyurl.com/graveyardoftotality',
        ),
      );
      expect(cycle, isNull);
      final shell = await LibraryImport.resolve(
        entry.withData({'content': 'https://sudokupad.app/not-a-package'}),
        (_) async => response('<!doctype html><html>player</html>'),
      );
      expect(shell, isNull);
    },
  );

  test('nonstandard and fog definitions retain B4b semantics', () {
    const magic = LibraryEntry(
      id: '000DQ2',
      title: 'The Magic Column',
      author: 'marty_sears',
    );
    final magicJson = cells(10)
      ..['metadata'] = {
        'rules':
            'Each column contains the digits 1-9 once, plus one empty cell. Digits may be repeated within a row.',
        'solution': '${'123456789.'.padRight(100, '.')}',
      };
    final magicDownload = LibraryImport.decode(
      magic,
      'scl${jsonEncode(magicJson)}',
    )!;
    expect(magicDownload.definition?.symbols, [
      for (var i = 1; i <= 9; i++) '$i',
    ]);
    expect(magicDownload.definition?.allowRowRepeats, isTrue);
    expect(magicDownload.definition?.deliberateBlanks, isNotEmpty);

    const balanced = LibraryEntry(
      id: '000W3T',
      title: 'Balanced X-Sums',
      author: 'Ambrose',
    );
    final balancedJson = cells(7)
      ..['metadata'] = {
        'rules':
            'Place an integer from {−3,−2,−1,0,1,2,3} in each cell so each appears once in every row and column.',
      };
    final balancedDownload = LibraryImport.decode(
      balanced,
      'scl${jsonEncode(balancedJson)}',
    )!;
    expect(balancedDownload.definition?.symbols, [
      '-3',
      '-2',
      '-1',
      '0',
      '1',
      '2',
      '3',
    ]);
    expect(
      balancedDownload.definition?.regions.every((value) => value == null),
      isTrue,
    );

    final fogJson = cells(4)
      ..['regions'] = List.generate(
        4,
        (region) => [
          for (var i = 0; i < 4; i++)
            [(region ~/ 2) * 2 + i ~/ 2, (region % 2) * 2 + i % 2],
        ],
      )
      ..['metadata'] = {
        'rules': 'Normal Sudoku rules apply.',
        'solution': '1234341221434321',
      }
      ..['fog'] = {
        'initiallyVisible': [0],
        'triggers': [
          {
            'requires': {'5': '7'},
            'reveals': [5, 6, 9, 10],
          },
        ],
      };
    final fog = LibraryImport.decode(balanced, 'scl${jsonEncode(fogJson)}')!;
    expect(fog.definition?.initiallyVisible, {0});
    expect(fog.definition?.fogTriggers.single.requires, {5: '7'});
    expect(fog.definition?.fogTriggers.single.reveals, {5, 6, 9, 10});
  });

  test('SudokuPad standard and linked fog normalize exact reveal masks', () {
    const entry = LibraryEntry(
      id: '000FOG',
      title: 'Fog fixture',
      author: 'Author',
    );
    Map<String, dynamic> fixture() => {
      'cells': List.generate(4, (_) => List.generate(4, (_) => {})),
      'regions': List.generate(
        4,
        (region) => [
          for (var i = 0; i < 4; i++)
            [(region ~/ 2) * 2 + i ~/ 2, (region % 2) * 2 + i % 2],
        ],
      ),
      'metadata': {
        'title': 'Fog fixture',
        'rules': 'Normal Sudoku rules apply.',
        'solution': '1234341221434321',
      },
      'foglight': [
        [0, 0],
      ],
    };
    final standard = LibraryImport.decode(
      entry,
      'scl${jsonEncode(fixture())}',
    )!;
    final standardTrigger = standard.definition!.fogTriggers.firstWhere(
      (trigger) => trigger.requires.keys.single == 5,
    );
    expect(standard.definition?.initiallyVisible, {0});
    expect(standardTrigger.requires, {5: '4'});
    expect(standardTrigger.reveals, {0, 1, 2, 4, 5, 6, 8, 9, 10});

    final legacyJson = fixture()
      ..remove('foglight')
      ..['cages'] = [
        {
          'value': 'FOGLIGHT: r1c2',
          'cells': [
            [0, 0],
          ],
        },
      ];
    final legacy = LibraryImport.decode(entry, 'scl${jsonEncode(legacyJson)}')!;
    expect(legacy.definition?.initiallyVisible, {0, 1});
    expect(legacy.refs, isEmpty);

    final linkedJson = fixture()
      ..['triggereffect'] = [
        {
          'trigger': {'type': 'cellvalue', 'cell': 'r2c2'},
          'effect': {'type': 'foglight', 'cells': 'r1c4,r4c1'},
        },
      ];
    final linked = LibraryImport.decode(entry, 'scl${jsonEncode(linkedJson)}')!;
    expect(linked.definition?.initiallyVisible, {0});
    expect(linked.definition?.fogTriggers.single.requires, {5: '4'});
    expect(linked.definition?.fogTriggers.single.reveals, {3, 12});
  });

  test('namespaced slugs preserve path segments', () async {
    final requested = <Uri>[];
    const namespaced = LibraryEntry(
      id: '000VY5',
      title: 'Azul',
      author: 'Blobz',
      content: 'https://sudokupad.app/blobz/azul',
    );
    await LibraryImport.resolve(namespaced, (uri) async {
      requested.add(uri);
      return response('not puzzle data');
    });
    expect(requested.single.path, '/api/puzzle/blobz/azul');
  });

  test(
    'recognized future packages are retained for offline re-evaluation',
    () async {
      const future = LibraryEntry(
        id: '000T6J',
        title: 'Linked grids',
        author: 'Author',
        content: 'https://sudokupad.app/scfopaque-package',
      );
      final download = await LibraryImport.read(
        future,
        (_) async => throw StateError('inline packages need no request'),
      );
      expect(download?.board, isNull);
      expect(download?.supportReasons.single, contains('not yet supported'));
      expect(download?.provenance['sourcePayload'], 'scfopaque-package');
      expect(download?.provenance['fingerprint'], hasLength(64));
    },
  );

  test('required artwork is embedded and referenced locally', () async {
    final puzzle = <String, dynamic>{
      'cells': List.generate(4, (_) => List.generate(4, (_) => {})),
      'regions': List.generate(
        4,
        (region) => [
          for (var i = 0; i < 4; i++)
            [(region ~/ 2) * 2 + i ~/ 2, (region % 2) * 2 + i % 2],
        ],
      ),
      'metadata': {
        'title': 'Artwork fixture',
        'rules': 'Normal Sudoku rules apply.',
      },
      'underlays': [
        {
          'center': [2, 2],
          'width': 1,
          'height': 1,
          'image': 'https://images.ctc-puzzles.com/clue.png',
        },
      ],
    };
    const entry = LibraryEntry(
      id: '000ART',
      title: 'Artwork fixture',
      author: 'Author',
      content: 'https://sudokupad.app/artwork-fixture',
    );
    final download = await LibraryImport.read(entry, (uri) async {
      if (uri.host == 'images.ctc-puzzles.com') {
        return LibraryResponse(
          200,
          Uint8List.fromList([1, 2, 3, 4]),
          headers: const {'content-type': 'image/png'},
        );
      }
      return response('scl${jsonEncode(puzzle)}');
    });
    expect(download?.assetManifest.single['data'], 'AQIDBA==');
    expect(download?.refs.single['image'], startsWith('asset:'));
    expect(download?.definition?.layers.single['image'], startsWith('asset:'));
  });
}
