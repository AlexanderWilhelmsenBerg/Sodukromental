import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/boards.dart';
import 'package:sodukromental/library_artwork.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_player_controller.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

final _hi = LibraryEntry(
  id: '000W88',
  title: 'HI (Arrows edition)',
  author: 'DocLogic',
);
const _rules =
    "Normal Sudoku rules apply. Digits along an arrow add up to the digit in that arrow's circle. Digits may repeat on an arrow.";
const _share = 'https://sudokupad.app/dcjp6mdjpv';
String _payload() =>
    File('test/fixtures/000W88.fpuz').readAsStringSync().trim();

void main() {
  testWidgets(
    '000W88 downloads, retains all shaded arrow geometry and checks offline',
    (tester) async {
      final download = (await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('fpuz-arrow');
        final file = File('${dir.path}/library.sqlite');
        final requests = <Uri>[];
        var offline = false;
        final raw = _payload();
        Future<LibraryStore> open() => LibraryStore.open(
          records: [_hi],
          includeAuthored: false,
          executor: NativeDatabase(file),
          fetch: (uri) async {
            if (offline) throw StateError('Unexpected offline fetch: $uri');
            requests.add(uri);
            final value = switch (uri.path) {
              '/Raetselportal/Raetsel/zeigen.php' =>
                '<div class="rp_titel"><h2>HI (Arrows edition)</h2><span class="rp_eingestellt">Published by <a>DocLogic</a></span></div><div class="rp_html"><p>$_rules</p><p><a href="$_share">Link to Sudokupad</a></p><p><a href="?id=000VH7">HI (Killer edition)</a></p></div>',
              '/api/puzzle/dcjp6mdjpv' => raw,
              _ => throw StateError('Unexpected route: $uri'),
            };
            return LibraryResponse(200, utf8.encode(value));
          },
        );
        var store = await open();
        try {
          await store.requestDownload(_hi.id);
          final deadline = Stopwatch()..start();
          while (store.download(_hi.id) == null &&
              deadline.elapsed < const Duration(seconds: 8)) {
            await Future<void>.delayed(const Duration(milliseconds: 15));
          }
          final first = store.download(_hi.id)!;
          final initial = LibraryPlayerController(puzzle: first)
            ..select(0)
            ..apply('7');
          await store.save(
            first.entry.id,
            first.entry.revision,
            initial.snapshot(),
          );
          initial.dispose();
          await store.close();
          offline = true;
          store = await open();
          final restored = store.download(_hi.id)!;
          expect(
            requests.where((r) => r.path.startsWith('/api/puzzle/')),
            hasLength(1),
          );
          expect(
            restored.provenance['fingerprint'],
            '796e494f22c58cc71eb1ff806fe207f4d48405bb1ccc107ad75622203958fca9',
          );
          expect(restored.availability, LibraryAvailability.play);
          final board = restored.board!;
          expect(board.givens, List<int>.filled(81, 0));
          expect(
            board.rules.where((r) => r.kind == RuleKind.arrow),
            hasLength(16),
          );
          expect(board.rules.first.cells, [56, 64, 65, 74, 75, 76]);
          expect(board.accepts(board.solution), isTrue);
          final controller = LibraryPlayerController(
            puzzle: restored,
            save: store.getSave(_hi.id, restored.entry.revision),
          );
          expect(controller.position.values.first, '7');
          for (final i in board.indices) {
            controller.select(i);
            controller.apply('${board.solution[i]}');
          }
          expect(controller.check().solved, isTrue);
          // Exchanging two symbols keeps Sudoku units valid and violates the arrow sums.
          for (final i in board.indices.where((i) => board.solution[i] <= 2)) {
            controller.select(i);
            controller.apply('${3 - board.solution[i]}');
          }
          expect(controller.check().solved, isFalse);
          expect(controller.check().conflicts, isNotEmpty);
          controller.dispose();
          return restored;
        } finally {
          await store.close();
          await dir.delete(recursive: true);
        }
      }))!;
      final refs = download.nativeDefinition!.layers;
      expect(refs.where((r) => r['layer'] == 'underlays'), hasLength(15));
      expect(refs.where((r) => r['layer'] == 'arrows'), hasLength(16));
      expect(refs.where((r) => r['rounded'] == true), hasLength(16));
      const capture = ValueKey('artwork');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: capture,
              child: SizedBox.square(
                dimension: 360,
                child: ColoredBox(
                  color: Colors.white,
                  child: LibraryArtwork(download),
                ),
              ),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final pixels = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data;
      }))!;
      List<int> rgb(int col, int row) => [
        for (var i = 0; i < 3; i++) pixels.getUint8((360 * row + col) * 4 + i),
      ];
      expect(rgb(100, 260), [
        255,
        224,
        96,
      ], reason: 'Tint remains visible inside the R7C3 bulb.');
      expect(
        rgb(114, 260).first,
        lessThan(175),
        reason: 'The outline touches the right rim.',
      );
      expect(
        rgb(80, 300).first,
        lessThan(175),
        reason: 'The first arrow bends through R8C2 and R8C3.',
      );
      expect(
        rgb(180, 340).first,
        lessThan(195),
        reason: 'The shaft ends at R9C5.',
      );
    },
  );

  test(
    'multiple shafts share a bulb, preserve givens, and extra rules require a manual check',
    () {
      final puzzle = {
        'size': 4,
        'title': 'Two shafts',
        'ruleset': '$_rules The four corners also obey a special instruction.',
        'grid': [
          for (var r = 0; r < 4; r++)
            [
              for (var c = 0; c < 4; c++)
                if (r == 0 && c == 0) {'value': 1, 'given': true} else {},
            ],
        ],
        'arrow': [
          {
            'cells': ['R1C3'],
            'lines': [
              ['R1C3', 'R1C2', 'R1C1'],
              ['R1C3', 'R2C3', 'R2C4'],
            ],
          },
        ],
      };
      final parsed = LibraryImport.decode(
        LibraryEntry(id: 'test', title: 'Two shafts', author: 'Setter'),
        jsonEncode(puzzle),
      )!;
      expect(parsed.board!.givens.first, 1);
      expect(parsed.board!.rules.map((r) => r.cells), [
        [2, 1, 0],
        [2, 6, 7],
      ]);
      expect(parsed.refs.where((r) => r['layer'] == 'overlays'), hasLength(1));
      expect(parsed.nativeDefinition!.solution.whereType<String>(), isEmpty);
      expect(parsed.manual, isTrue);
      final player = LibraryPlayerController(puzzle: parsed);
      const digits = '1234341221434321';
      for (var i = 0; i < digits.length; i++) {
        player.select(i);
        player.apply(digits[i]);
      }
      expect(player.check().manual, isTrue);
      expect(player.check().solved, isFalse);
      player.dispose();
      final arrow = (puzzle['arrow'] as List).first as Map;
      arrow['cells'] = ['R1C2', 'R1C3'];
      final wide = LibraryImport.decode(_hi, jsonEncode(puzzle))!;
      expect(wide.availability, LibraryAvailability.original);
      expect(wide.supportReasons.single, contains('multi-cell bulb'));
    },
  );
}
