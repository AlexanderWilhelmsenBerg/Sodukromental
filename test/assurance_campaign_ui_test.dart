import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/colony_screen.dart';

void main() {
  testWidgets(
    'opening actions and the same amoeba delivery survive reopening',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(414, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      var run = Campaign(now: DateTime.utc(2026, 11, 25));
      Future<void> showColony() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ColonyScreen(
                campaign: run,
                reducedMotion: true,
                tiltEnabled: false,
                onChanged: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder cell(int index) => find.byKey(ValueKey('cell-$index'));
      Finder token(int index) => find.byKey(ValueKey('tutorial-token-$index'));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await showColony();
      expect(run.anchors, {0, 6, 13});
      expect(run.cells, isNot(contains(4)));
      for (var index = 0; index < 3; index++) {
        expect(token(index), findsOneWidget);
      }
      final startingCells = run.cells;
      await tap(cell(0));
      await tap(cell(1));
      expect(run.cells, startingCells);
      await tap(token(0));
      await tap(cell(3));
      expect(run.dna, 0);
      expect(run.usedTutorialTokens, isEmpty);
      await tap(token(0));

      for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
        await tap(cell(from));
        await tap(cell(to));
      }
      expect(run.tutorialReady, isTrue);
      expect(run.cells, [1, 2, 3, 0, 3, 0, 1, 2, 2, 1, 0, 3, 0, 3, 2, 1]);

      final start = tester.getCenter(token(0));
      final end = tester.getCenter(cell(3));
      await tester.dragFrom(start, end - start);
      await tester.pumpAndSettle();
      expect(run.dna, 1);
      await tap(token(1));
      await tap(cell(5));
      await tap(token(2));
      await tap(cell(10));
      expect(run.dna, 3);
      expect(run.usedTutorialTokens, {0, 1, 2});

      await tap(find.text('Create amoeba'));
      expect(run.dna, 0);
      final amoeba = run.creatures.single.id;
      final trip = run.jobs.single.id;
      final deliveredTile = run.jobs.single.tileIds.single;

      await tester.pumpWidget(const SizedBox.shrink());
      run = Campaign.fromJson(
        jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
      );
      expect(run.creatures.single.id, amoeba);
      expect(run.jobs.single.id, trip);
      expect(run.jobs.single.tileIds.single, deliveredTile);
      expect(run.usedTutorialTokens, {0, 1, 2});
      expect(run.dna, 0);
      run.tick(DateTime.fromMillisecondsSinceEpoch(run.jobs.single.dueAt));
      await showColony();

      final offer = run.offers.single;
      expect(offer.workerId, amoeba);
      expect(offer.digit, 4);
      expect(offer.tileIds, [deliveredTile]);
      await tap(find.byKey(ValueKey('offer-${offer.id}')));
      await tap(cell(12));
      expect(run.cleared, isTrue);
      expect(run.rna, 6);
      expect(run.cellTileIds[12], deliveredTile);
      final oldCells = run.cells;
      final oldIds = run.cellTileIds;

      await tap(find.text('Grow to 5×5'));
      expect(run.board.id, 'growth-5');
      expect(run.cells.where((digit) => digit != 0), hasLength(9));
      expect(run.tray.values.fold(0, (sum, count) => sum + count), 11);
      expect(run.tray[5], isNull);
      expect(run.jobs.single.digit, 5);
      final grownIds = [
        ...run.cellTileIds.values,
        ...run.trayTileIds.values.expand((ids) => ids),
      ];
      expect(grownIds, hasLength(20));
      expect(grownIds.toSet(), hasLength(20));
      expect(grownIds, containsAll(oldIds.values));
      for (final entry in oldIds.entries) {
        final newCell = (entry.key ~/ 4) * 5 + entry.key % 4;
        if (run.cells[newCell] == oldCells[entry.key]) {
          expect(run.cellTileIds[newCell], entry.value);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
