import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_player.dart';
import 'package:sodukromental/library_player_controller.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

const _entry = LibraryEntry(
  id: '000VJJ',
  title: 'The Greatest Fog',
  author: 'Prof.Dori',
);
const _initial = {
  0,
  1,
  7,
  8,
  9,
  17,
  20,
  21,
  23,
  24,
  29,
  33,
  47,
  51,
  56,
  57,
  59,
  60,
  62,
  63,
  69,
  71,
  72,
  73,
  79,
  80,
};
const _r3c7Reveals = {2, 3, 10, 11, 19};
String _payload() => File('test/fixtures/000VJJ.scl').readAsStringSync();

void main() {
  test(
    '000VJJ installs its authored fog links and plays from disk offline',
    () async {
      final directory = await Directory.systemTemp.createTemp('greatest-fog');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      final requests = <Uri>[];
      var offline = false;
      Future<LibraryStore> open() => LibraryStore.open(
        executor: NativeDatabase(file),
        records: [_entry],
        includeAuthored: false,
        fetch: (uri) async {
          requests.add(uri);
          if (offline) throw StateError('Unexpected offline request: $uri');
          final body = switch (uri.path) {
            '/Raetselportal/Raetsel/zeigen.php' => File(
              'test/fixtures/000VJJ-detail.html',
            ).readAsStringSync(),
            '/api/puzzle/jni23ia3hh' => _payload(),
            _ => throw StateError('Unexpected route: $uri'),
          };
          return LibraryResponse(200, utf8.encode(body));
        },
      );
      var store = await open();
      try {
        await store.requestDownload(_entry.id);
        final timer = Stopwatch()..start();
        while (store.download(_entry.id) == null &&
            timer.elapsed < const Duration(seconds: 8)) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }
        final installed = store.download(_entry.id)!;
        expect(installed.availability, LibraryAvailability.play);
        expect(installed.supportReasons, isEmpty);
        expect(installed.entry.rules, contains('greater than the sum'));
        expect(installed.entry.rules, contains('white dot'));
        expect(
          installed.provenance['fingerprint'],
          'd5c92ec44a2e2d754ec4506fc8ec0ec6b30b44d05abeef710de04ed73d383179',
        );
        expect(installed.provenance['sourcePayload'], _payload());
        final definition = installed.nativeDefinition!;
        expect(definition.initiallyVisible, _initial);
        expect(definition.fogTriggers, hasLength(62));
        expect(
          definition.fogTriggers
              .where((t) => t.requires[19] == '9')
              .map((t) => t.reveals),
          [
            {45, 54},
            {19},
          ],
        );
        expect(definition.givens.whereType<String>(), isEmpty);
        expect(definition.regions.toSet(), hasLength(9));
        final lines = definition.layers
            .where((l) => l['layer'] == 'lines')
            .toList();
        expect(lines, hasLength(14));
        expect(lines.first['wayPoints'], [
          [5.5, 2.5],
          [2.5, 2.5],
          [2.5, 5.5],
        ]);
        final dots = definition.layers.where((l) => l['layer'] == 'overlays');
        expect(dots.map((r) => r['center']), [
          [7, 7.5],
          [1.5, 4],
          [1.5, 2],
          [4.5, 2],
          [3.5, 8],
        ]);

        final first = LibraryPlayerController(puzzle: installed);
        first.select(
          19,
        ); // R3C2 is initially covered. A wrong entry is retained.
        first.apply('1');
        expect(first.visible, _initial);
        first.select(
          24,
        ); // Correct R3C7 activates exactly its five authored cells.
        first.apply('4');
        expect(first.visible, {..._initial, ..._r3c7Reveals});
        expect(first.position.values[19], '1');
        await store.save(_entry.id, installed.entry.revision, first.snapshot());
        first.dispose();
        final onlineCount = requests.length;
        await store.close();
        offline = true;
        store = await open();
        final cached = store.download(_entry.id)!;
        final player = LibraryPlayerController(
          puzzle: cached,
          save: store.getSave(_entry.id, cached.entry.revision),
        );
        addTearDown(player.dispose);
        expect(player.visible, {..._initial, ..._r3c7Reveals});
        expect(player.position.values[19], '1');
        player.undo();
        expect(player.visible, _initial);
        expect(player.covered(19), isTrue);
        player.select(19);
        player.apply('9'); // Both R3C2 links activate even under fog.
        expect(player.visible, {..._initial, 19, 45, 54});
        player.erase();
        expect(player.visible, _initial);
        player.undo();
        expect(player.visible, {..._initial, 19, 45, 54});
        for (final (cell, answer) in definition.solution.indexed) {
          player.select(cell);
          player.apply(answer!);
        }
        expect(player.visible, definition.playable);
        expect(player.check().solved, isTrue);
        expect(requests.length, onlineCount);
      } finally {
        await store.close();
      }
    },
  );

  test('concatenated fog coordinates must be fully parsed and in bounds', () {
    LibraryDownload decode(String trigger, String effect) =>
        LibraryImport.decode(
          _entry,
          jsonEncode({
            'metadata': {
              'rules': 'Normal Sudoku rules apply.',
              'solution': '1234341221434321',
            },
            'cells': List.generate(4, (_) => List.generate(4, (_) => {})),
            'foglight': [
              [0, 0],
            ],
            'triggereffect': [
              {
                'trigger': {'type': 'cellvalue', 'cell': trigger},
                'effect': {'type': 'foglight', 'cells': effect},
              },
            ],
          }),
        )!;
    final puzzle = decode('R1C1r2c2', 'r4c4-r3c3r1c2; r1c3,r2c1');
    expect(puzzle.availability, LibraryAvailability.play);
    final link = puzzle.nativeDefinition!.fogTriggers.single;
    expect(link.requires, {0: '1', 5: '4'});
    expect(link.reveals, {1, 2, 4, 10, 11, 14, 15});
    for (final bad in ['r1c2noiseR2C3', 'r1c2r5c1', 'r1c2-', 'r1c2,']) {
      expect(decode('r1c1', bad).availability, LibraryAvailability.original);
      expect(decode(bad, 'r1c1').availability, LibraryAvailability.original);
    }
  });

  testWidgets(
    '000VJJ renders the green line and reveals a white dot with its cells',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = (await tester.runAsync(
        () => LibraryStore.open(
          executor: NativeDatabase.memory(),
          records: [_entry],
          includeAuthored: false,
        ),
      ))!;
      final puzzle = LibraryImport.decode(_entry, _payload())!;
      const capture = ValueKey('board-screen');
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            home: LibraryPlayer(store: store, puzzle: puzzle),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> colorAt(double row, double column) async {
        final cell = tester.getRect(find.byKey(const ValueKey('cell-0')));
        final px = (cell.left + column * cell.width).floor();
        final py = (cell.top + row * cell.height).floor();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset = (py * image.width + px) * 4;
            return [for (int i = 0; i < 3; i++) bytes.getUint8(offset + i)];
          } finally {
            image.dispose();
          }
        }))!;
      }

      Future<List<String>> inspect() async {
        final button = find.text('Clue inspector');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        final sheet = tester.widget<ListView>(
          find.ancestor(
            of: find.text('Linear clue inspector'),
            matching: find.byType(ListView),
          ),
        );
        final rows =
            (sheet.childrenDelegate as SliverChildListDelegate).children;
        final labels = [
          for (final row in rows.whereType<ListTile>())
            (row.title as Text).data!,
        ];
        Navigator.pop(tester.element(find.text('Linear clue inspector')));
        await tester.pumpAndSettle();
        return labels;
      }

      expect(await colorAt(2.5, 2.7), [154, 185, 115]);
      expect(await colorAt(1.5, 2.07), [175, 175, 175]);
      expect(
        (await inspect()).where((s) => s.startsWith('Artwork clue')),
        isEmpty,
      );
      final source = find.byKey(const ValueKey('cell-24'));
      await tester.ensureVisible(source);
      await tester.tap(source);
      await tester.pump();
      final digit = find.byKey(const ValueKey('library-key-4'));
      await tester.ensureVisible(digit);
      await tester.tap(digit);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('cell-0')));
      await tester.pumpAndSettle();
      expect(await colorAt(1.5, 2.07), [255, 255, 255]);
      expect(
        (await colorAt(1.5, 2.169)).first,
        lessThan(200),
        reason: 'The white consecutive dot retains its dark rim.',
      );
      expect(
        (await inspect()).where((s) => s.startsWith('Artwork clue')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(store.close);
    },
  );
}
