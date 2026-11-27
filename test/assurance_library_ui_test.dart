import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/boards.dart';
import 'package:sodukromental/library.dart';

void main() {
  testWidgets(
    'the saved shelf reopens with normal sync enabled and zero fetches',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('sodu-saved-shelf');
      final db = File('${dir.path}/library.sqlite');
      var requests = 0;
      Future<LibraryStore> open() => LibraryStore.open(
        executor: NativeDatabase(db),
        records: const [],
        fetch: (uri) async {
          requests++;
          throw StateError('The saved shelf attempted a fetch');
        },
      );
      var store = await open();
      await store.rememberShelf(true);
      await store.close();
      store = await open();
      addTearDown(() async {
        await store.close();
        dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(store: store, active: false)),
      );
      await tester.pumpWidget(MaterialApp(home: LibraryScreen(store: store)));
      await tester.pumpAndSettle();
      final shelf = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Saved'),
      );
      expect(shelf.selected, isTrue);
      expect(requests, 0);
    },
  );

  testWidgets('a fresh offline Library filters, solves and reopens a finale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(540, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final temp = Directory.systemTemp.createTempSync('sodu-assurance-library');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File('${temp.path}/library.sqlite');
    var networkCalls = 0;

    Future<LibraryStore> open() => LibraryStore.open(
      executor: NativeDatabase(file),
      records: const [],
      fetch: (_) async {
        networkCalls++;
        throw const SocketException('Offline');
      },
    );

    var store = (await tester.runAsync(open))!;
    Future<void> showLibrary() async {
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(store: store, startSync: false)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    const keys = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    await showLibrary();
    expect(store.browse(authored: true), hasLength(28));
    expect(store.automatic, isFalse);
    await tap(find.text('Filters'));
    await tap(find.widgetWithText(ChoiceChip, 'All'));
    await tap(find.widgetWithText(FilterChip, 'Palindrome').first);
    await tap(find.widgetWithText(FilterChip, 'Region Sum Line').first);
    await tap(find.text('Show puzzles'));
    expect(find.text('Lines finale'), findsOneWidget);
    expect(find.text('Palindrome'), findsOneWidget);
    expect(find.text('Outside clues finale'), findsNothing);
    await tap(find.widgetWithText(ListTile, 'Lines finale'));
    await tap(find.text('Play puzzle'));

    final board = boardsById['lines-finale']!;
    for (final index in board.indices.where(
      (cell) => board.givens[cell] == 0,
    )) {
      await tap(find.byKey(ValueKey('cell-$index')));
      await tester.sendKeyEvent(keys[board.solution[index]]);
      await tester.pump();
    }
    await tap(find.text('Check board'));
    expect(find.text('Puzzle solved.'), findsOneWidget);
    expect(store.getSave(board.id)?.progress, LibraryProgress.solved);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(store.close);
    store = (await tester.runAsync(open))!;
    expect(store.getSave(board.id)?.progress, LibraryProgress.solved);
    expect(store.getSave(board.id)?.history.last.digits, board.solution);
    await showLibrary();
    await tester.enterText(find.byType(TextField), 'Lines finale');
    await tester.pumpAndSettle();
    await tap(find.widgetWithText(ListTile, 'Lines finale'));
    expect(find.text('Resume puzzle'), findsOneWidget);
    expect(networkCalls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(store.close);
  });
}
