import 'dart:io';
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
            ((w.key! as ValueKey<String>).value.startsWith('offer-') ||
                (w.key! as ValueKey<String>).value == 'tray-4'),
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
      await tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Digit 5',
        ),
      );
      await tap(cell(4));
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
        final stock = find.byKey(ValueKey('tray-$digit'));
        final offered = find.text('Take $digit');
        final clock = Stopwatch()..start();
        while (stock.evaluate().isEmpty &&
            offered.evaluate().isEmpty &&
            clock.elapsed < const Duration(seconds: 45)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        if (stock.evaluate().isNotEmpty) {
          final selected = tester
              .widgetList<Semantics>(
                find.descendant(of: stock, matching: find.byType(Semantics)),
              )
              .any((widget) => widget.properties.selected == true);
          if (!selected) await tap(stock);
        } else {
          await tap(offered);
        }
        await tap(cell(index));
      }
      await waitFor(find.text('Grow to 6×6'));
      await tap(find.text('Colony jobs'));
      await tap(find.text('Design a creature'));
      await tap(find.text('Review hatch'));
      await tap(find.text('Hatch'));
      final talk = find.text('Talk to creature');
      if (talk.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          talk,
          300,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
      }
      await waitFor(talk);
    },
  );
}
