import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/library_artwork.dart';
import 'package:sodukromental/library_player.dart';
import 'package:sodukromental/library_player_controller.dart';

const _entry = LibraryEntry(
  id: 'fog-fixture',
  title: 'Covered entry fixture',
  author: 'Test setter',
  revision: 'v1',
);

LibraryDownload _fogPuzzle() => LibraryDownload(
  _entry,
  finalCheck: true,
  definition: const LibraryPuzzleDefinition(
    width: 2,
    height: 2,
    symbols: ['1', '2', '3', '7'],
    playable: {0, 1, 2, 3},
    givens: ['1', '7', null, null],
    regions: [0, 0, 1, 1],
    solution: ['1', '7', '2', '3'],
    initiallyVisible: {0},
    fogTriggers: [
      LibraryFogTrigger(requires: {1: '7'}, reveals: {1, 2}),
    ],
    allowRowRepeats: true,
    allowColumnRepeats: true,
    allowRegionRepeats: true,
  ),
);

void main() {
  test('covered wrong entries persist, remain editable, and do not reveal', () {
    final controller = LibraryPlayerController(puzzle: _fogPuzzle());
    controller.select(1);
    controller.apply('3');
    expect(controller.position.values[1], '3');
    expect(controller.covered(1), isTrue);
    expect(controller.editable(1), isTrue);

    final restored = LibraryPlayerController(
      puzzle: _fogPuzzle(),
      save: controller.snapshot(),
    );
    expect(restored.position.values[1], '3');
    expect(restored.covered(1), isTrue);
    restored.select(1);
    restored.apply('7');
    expect(restored.visible, containsAll([0, 1, 2]));
    expect(restored.given(1), isTrue);
    expect(restored.displayedValue(1), '7');
    restored.undo();
    expect(restored.position.values[1], '3');
    expect(restored.visible, {0});
    restored.redo();
    expect(restored.visible, contains(2));
  });

  test(
    'irreversible fog grants never infer earnings from overlapping footprints',
    () {
      final puzzle = LibraryDownload(
        _entry,
        definition: const LibraryPuzzleDefinition(
          width: 3,
          height: 3,
          symbols: ['1', '3', '7', '9'],
          playable: {0, 1, 2, 3, 4, 5, 6, 7, 8},
          givens: [null, null, null, null, null, null, null, null, null],
          regions: [null, null, null, null, null, null, null, null, null],
          initiallyVisible: {0, 1},
          fogTriggers: [
            LibraryFogTrigger(
              requires: {4: '7'},
              reveals: {1, 2, 3},
              reversible: false,
            ),
            LibraryFogTrigger(
              requires: {6: '9'},
              reveals: {3, 5},
              reversible: false,
            ),
          ],
          allowRowRepeats: true,
          allowColumnRepeats: true,
          allowRegionRepeats: true,
        ),
      );
      final controller = LibraryPlayerController(puzzle: puzzle);
      controller.select(4);
      controller.apply('3');
      expect(controller.visible, {0, 1});
      expect(controller.position.grantedFogTriggers, isEmpty);

      controller.apply('7');
      expect(controller.visible, {0, 1, 2, 3});
      expect(controller.visible, isNot(contains(5)));
      expect(controller.position.grantedFogTriggers, hasLength(1));

      controller.apply('3');
      expect(controller.visible, {0, 1, 2, 3});
      expect(controller.visible, isNot(contains(5)));
      final restored = LibraryPlayerController(
        puzzle: puzzle,
        save: LibrarySave.fromJson(controller.snapshot().toJson()),
      );
      expect(restored.visible, {0, 1, 2, 3});
      expect(restored.position.grantedFogTriggers, hasLength(1));

      restored.undo();
      expect(restored.visible, {0, 1, 2, 3});
      restored.undo();
      expect(restored.visible, {0, 1});
      expect(restored.position.grantedFogTriggers, isEmpty);
    },
  );

  test(
    'mixed multi-selection layers toggle independently as one history edit',
    () {
      final controller = LibraryPlayerController(puzzle: _fogPuzzle());
      controller.select(2);
      controller.select(3, extend: true);
      controller.setMode(LibraryInputMode.corner);
      controller.apply('2');
      expect(controller.position.cornerMarks[2], {'2'});
      expect(controller.position.cornerMarks[3], {'2'});
      final afterCorners = controller.cursor;

      controller.setMode(LibraryInputMode.center);
      controller.apply('3');
      controller.setMode(LibraryInputMode.color);
      controller.apply('blue');
      expect(controller.position.centerMarks[2], {'3'});
      expect(controller.position.colors[3], {'blue'});
      controller.undo();
      expect(controller.position.colors, isEmpty);
      expect(controller.position.centerMarks[2], {'3'});
      controller.seekReplay(0); // no-op outside replay
      expect(afterCorners, 1);
    },
  );

  test('custom alphabet and deliberate blank survive JSON persistence', () {
    const definition = LibraryPuzzleDefinition(
      width: 2,
      height: 2,
      symbols: ['-1', '0', 'A'],
      playable: {0, 1, 2, 3},
      givens: [null, null, null, null],
      regions: [null, null, null, null],
      solution: ['-1', '0', 'A', null],
      deliberateBlanks: {3},
      allowRowRepeats: true,
      allowColumnRepeats: true,
      allowRegionRepeats: true,
    );
    final download = LibraryDownload(
      _entry,
      definition: definition,
      finalCheck: true,
    );
    final controller = LibraryPlayerController(puzzle: download);
    for (final item in {0: '-1', 1: '0', 2: 'A'}.entries) {
      controller.select(item.key);
      controller.apply(item.value);
    }
    expect(controller.check().solved, isTrue);
    final save = LibrarySave.fromJson(controller.snapshot().toJson());
    expect(save.history.last.values, ['-1', '0', 'A', null]);
    expect(LibraryDownload.fromJson(download.toJson()).definition!.symbols, [
      '-1',
      '0',
      'A',
    ]);
  });

  test('legacy notes migrate to the corner layer', () {
    final position = LibraryPosition.fromJson({
      'digits': [0, 0, 0, 0],
      'notes': {
        '2': [1, 3],
      },
    });
    expect(position.cornerMarks[2], {'1', '3'});
  });

  test('outside clues reserve a native pan margin', () {
    final definition = LibraryPuzzleDefinition(
      width: 7,
      height: 7,
      symbols: ['-3', '-2', '-1', '0', '1', '2', '3'],
      playable: {0},
      givens: List.filled(49, null),
      regions: List.filled(49, null),
      layers: [
        {
          'layer': 'underlays',
          'center': [-0.5, 3.5],
          'text': '4',
        },
      ],
    );
    final puzzle = LibraryDownload(_entry, definition: definition);
    expect(libraryArtworkMargin(puzzle, definition), greaterThan(0));
  });

  testWidgets('covered guess is visible, overwritable and undoable in UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = Directory.systemTemp.createTempSync('library-player-ui');
    addTearDown(() => folder.deleteSync(recursive: true));
    final store = await LibraryStore.open(
      executor: NativeDatabase(File('${folder.path}/library.sqlite')),
      records: const [],
      includeAuthored: false,
    );
    addTearDown(store.close);
    final puzzle = _fogPuzzle();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPlayer(store: store, puzzle: puzzle),
      ),
    );
    await tester.pumpAndSettle();
    final covered = tester.getRect(find.byKey(const ValueKey('cell-3'))).center;
    final renderView = tester.binding.renderViews.first;
    final capture = (await tester.runAsync(() async {
      final frame = await (renderView.debugLayer! as OffsetLayer).toImage(
        renderView.paintBounds,
        pixelRatio: 1 / renderView.flutterView.devicePixelRatio,
      );
      final pixels = (await frame.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final result = (width: frame.width, pixels: pixels);
      frame.dispose();
      return result;
    }))!;
    final offset =
        ((covered.dy.floor() * capture.width) + covered.dx.floor()) * 4;
    expect(
      [
        capture.pixels.getUint8(offset),
        capture.pixels.getUint8(offset + 1),
        capture.pixels.getUint8(offset + 2),
      ],
      [0xaf, 0xaf, 0xaf],
      reason:
          'A fully covered, unmarked light-theme cell uses Sven’s neutral fog fill.',
    );
    await tester.tap(find.byKey(const ValueKey('cell-1')));
    await tester.tap(find.widgetWithText(FilledButton, '3'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      store.getSave(_entry.id, _entry.revision)!.history.last.values[1],
      '3',
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, '7'));
    await tester.tap(find.widgetWithText(FilledButton, '7'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      store.getSave(_entry.id, _entry.revision)!.history.last.revealed,
      containsAll([1, 2]),
    );
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      store
          .getSave(_entry.id, _entry.revision)!
          .history[store.getSave(_entry.id, _entry.revision)!.index]
          .values[1],
      '3',
    );
  });

  testWidgets('ordinary keypad is 3 by 3 and visible counts never leak fog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = Directory.systemTemp.createTempSync('library-keypad-ui');
    addTearDown(() => folder.deleteSync(recursive: true));
    final store = await LibraryStore.open(
      executor: NativeDatabase(File('${folder.path}/library.sqlite')),
      records: const [],
      includeAuthored: false,
    );
    addTearDown(store.close);
    final givens = List<String?>.filled(81, null)
      ..[0] = '7'
      ..[10] = '7';
    final visible = {for (var cell = 0; cell < 81; cell++) cell}..remove(10);
    final puzzle = LibraryDownload(
      _entry,
      definition: LibraryPuzzleDefinition(
        width: 9,
        height: 9,
        symbols: [for (var value = 1; value <= 9; value++) '$value'],
        playable: {for (var cell = 0; cell < 81; cell++) cell},
        givens: givens,
        regions: [
          for (var cell = 0; cell < 81; cell++)
            (cell ~/ 9 ~/ 3) * 3 + (cell % 9 ~/ 3),
        ],
        initiallyVisible: visible,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPlayer(store: store, puzzle: puzzle),
      ),
    );
    await tester.pumpAndSettle();

    Rect key(String symbol) =>
        tester.getRect(find.byKey(ValueKey('library-key-$symbol')));
    expect(key('1').center.dy, closeTo(key('2').center.dy, .1));
    expect(key('2').center.dy, closeTo(key('3').center.dy, .1));
    expect(key('4').center.dy, greaterThan(key('1').center.dy));
    expect(key('4').center.dx, closeTo(key('1').center.dx, .1));
    expect(key('1').height, greaterThanOrEqualTo(48));
    expect(find.byKey(const ValueKey('symbol-count-7')), findsNothing);

    await tester.tap(find.byTooltip('Player options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show keypad counts'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('symbol-count-7'))).data,
      '1 visible',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('cell-10')));
    await tester.tap(find.byKey(const ValueKey('cell-10')));
    await tester.ensureVisible(find.byKey(const ValueKey('library-key-7')));
    await tester.tap(find.byKey(const ValueKey('library-key-7')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('symbol-count-7'))).data,
      '2 visible',
    );
  });
}
