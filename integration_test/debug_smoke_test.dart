import 'dart:io';

import 'package:drift/native.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/library_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sodukromental/main.dart' as app;
import 'package:sodukromental/boards.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'fresh install solves the opening, hatches a helper and visits the independent library',
    (tester) async {
      app.main();
      Finder cell(int index) => find.byKey(ValueKey('cell-$index'));
      Future<void> waitFor(Finder target) async {
        final clock = Stopwatch()..start();
        while (target.evaluate().isEmpty &&
            clock.elapsed < const Duration(seconds: 90)) {
          await tester.pump(const Duration(milliseconds: 150));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(target, findsAtLeastNWidgets(1));
      }

      Future<void> tap(Finder target) async {
        await waitFor(target);
        await tester.ensureVisible(target.first);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(target.first);
        await tester.pump(const Duration(milliseconds: 200));
      }

      Future<void> revealBelowFold(Finder target) async {
        // Lazy lists mount their lower controls only after the player scrolls.
        // Allow a newly pushed route to finish its entrance animation first.
        await tester.pump(const Duration(milliseconds: 450));
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            280,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
          );
        }
        await tester.ensureVisible(target.first);
      }

      await waitFor(cell(5));
      for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
        await tap(cell(from));
        await tap(cell(to));
      }
      for (final (token, index) in [(0, 3), (1, 5), (2, 10)]) {
        await tap(find.byKey(ValueKey('tutorial-token-$token')));
        await tap(cell(index));
      }
      await tap(find.text('Create amoeba'));
      final held = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('offer-'),
      );
      await tap(held);
      await tap(cell(12));
      await tap(find.text('Grow to 5×5'));
      await waitFor(cell(24));
      await tap(find.text('Sudoku'));
      final search = find.byType(TextField);
      await waitFor(search);
      await tester.enterText(search, 'Uneven ground');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await tap(find.widgetWithText(ListTile, 'Uneven ground'));
      await tap(find.text('Play puzzle'));
      await tap(cell(4));
      await tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith('Digit 5,'),
        ),
      );
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(find.text('Resume puzzle'));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      await tap(find.byTooltip('Settings'));
      await waitFor(find.text('Sudoku Library'));
      if (Platform.isAndroid) expect(find.text('Tilt gravity'), findsOneWidget);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 200));
      await tap(find.text('Colony'));
      expect(cell(24), findsOneWidget);
      await tap(find.text('Request digits'));
      await tap(find.widgetWithText(ChoiceChip, '5'));
      for (var copy = 0; copy < 4; copy++) {
        await tap(find.byTooltip('One more copy'));
      }
      await tap(find.text('Send helper'));
      final next = boardsById['growth-5']!;
      for (final index in next.indices.where((i) => next.givens[i] == 0)) {
        final digit = next.solution[index];
        await tap(cell(index));
        final inStock = RegExp('^Digit $digit, [1-9][0-9]* available');
        final stock = find.byWidgetPredicate(
          (w) => w is Semantics && inStock.hasMatch(w.properties.label ?? ''),
        );
        final offered = find.text('Take $digit');
        final clock = Stopwatch()..start();
        while (stock.evaluate().isEmpty &&
            offered.evaluate().isEmpty &&
            clock.elapsed < const Duration(seconds: 45)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        if (stock.evaluate().isNotEmpty) {
          await tap(stock);
        } else {
          await tap(offered);
        }
      }
      await waitFor(find.text('Grow to 6×6'));
      await tap(find.text('Colony jobs'));
      await tap(find.text('Design a creature'));
      await waitFor(find.text('Choose a lineage'));
      await tap(find.widgetWithText(ChoiceChip, 'Mammalian'));
      await tap(find.text('Shelter what you find'));
      await revealBelowFold(find.text('A digit gets loose'));
      if (find.text('Catch both').evaluate().isEmpty) {
        await tap(find.text('A digit gets loose'));
      }
      await revealBelowFold(find.text('Catch both'));
      await tap(find.text('Catch both'));
      await revealBelowFold(find.text('Review hatch'));
      await tap(find.text('Review hatch'));
      await revealBelowFold(find.text('Hatch'));
      await tap(find.text('Hatch'));
      final talk = find.text('Talk to creature');
      await revealBelowFold(talk);
      await waitFor(talk);
    },
  );
  testWidgets('covered guesses survive an offline database reopen on Android', (
    tester,
  ) async {
    final folder = await Directory.systemTemp.createTemp('sodu-fog-device');
    final file = File('${folder.path}/library.sqlite');
    var requests = 0;
    Future<LibraryStore> open() => LibraryStore.open(
      executor: NativeDatabase(file),
      records: const [],
      fetch: (uri) async {
        requests++;
        throw StateError('Unexpected offline fetch');
      },
    );
    var store = await open();
    addTearDown(() async {
      await store.close();
      await folder.delete(recursive: true);
    });
    final board = boardsById['halo']!;
    final index = board.indices.firstWhere(
      (i) =>
          !board.starterPatch.contains(i) &&
          board.givens[i] == 0 &&
          board.adjacent(i).any((j) => !board.starterPatch.contains(j)),
    );
    final correct = board.solution[index].toString();
    final guess = (board.solution[index] % 9 + 1).toString();
    Future<void> showPlayer() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryPlayer(store: store, puzzle: store.download('halo')!),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> enter(String value) async {
      final cell = find.byKey(ValueKey('cell-$index'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pump();
      final key = find.widgetWithText(FilledButton, value);
      await tester.ensureVisible(key.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(key.first);
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<LibraryPosition> waitForValue(String value) async {
      final timer = Stopwatch()..start();
      while (timer.elapsed < const Duration(seconds: 20)) {
        final save = store.getSave('halo');
        if (save != null && save.history[save.index].values[index] == value)
          return save.history[save.index];
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      throw StateError('The entered value was not saved');
    }

    await showPlayer();
    await enter(guess);
    final covered = await waitForValue(guess);
    expect(covered.revealed, board.starterPatch.toSet());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await store.close();
    store = await open();
    await showPlayer();
    expect((await waitForValue(guess)).revealed, covered.revealed);
    await enter(correct);
    final lit = await waitForValue(correct);
    expect(lit.revealed, containsAll(board.adjacent(index)));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump(const Duration(milliseconds: 250));
    expect((await waitForValue(guess)).revealed, covered.revealed);
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
