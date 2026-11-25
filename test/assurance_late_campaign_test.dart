import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creatures.dart';

void main() {
  test(
    'switching finale routes preserves exact placements through a reload',
    () {
      var now = DateTime.utc(2026, 11, 25);
      var run = Campaign(now: now);

      void settle() {
        now = now.add(const Duration(seconds: 30));
        run.tick(now, offline: true);
      }

      void solveCurrentBoard() {
        final board = run.board;
        for (var digit = 1; digit <= board.size; digit++) {
          if (run.demand(digit) > 0) run.requestDigit(digit, count: board.size);
        }
        for (var step = 0; step < 15 && !run.cleared; step++) {
          settle();
          for (final index in run.visible) {
            if (run.cells[index] == 0 &&
                run.tray.containsKey(board.solution[index])) {
              expect(
                run.place(index, board.solution[index]),
                isTrue,
                reason: board.id,
              );
            }
          }
        }
        expect(run.cleared, isTrue, reason: board.id);
      }

      void reopen() {
        run = Campaign.fromJson(
          jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
        );
      }

      for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
        expect(run.slide(from, to), isTrue);
      }
      for (final index in [3, 5, 10]) {
        expect(run.placeTutorialToken(index), isTrue);
      }
      expect(run.createAmoeba(), isTrue);
      settle();
      expect(run.place(12, 4), isTrue);
      while (run.board.id != 'arrows') {
        expect(run.advance(), isTrue);
        if (run.board.id == 'renban') {
          expect(run.board.eaten, {2: 1, 4: 2, 7: 1});
          final tray = run.trayTileIds;
          final clues = run.cellTileIds;
          for (var digit = 1; digit <= 9; digit++) {
            final fixed = run.board.givens
                .where((value) => value == digit)
                .length;
            expect(
              tray[digit]?.length ?? 0,
              9 - fixed - (run.board.eaten[digit] ?? 0),
            );
          }
          for (final direction in GravityDirection.values) {
            run.tilt(direction);
            expect(run.gravity, direction);
            expect(run.trayTileIds, tray);
            expect(run.cellTileIds, clues);
          }
        }
        solveCurrentBoard();
      }

      expect(run.setPolicy(SettlementPolicy.sharedReserves), isTrue);
      for (var digit = 1; digit <= 5; digit++) {
        expect(run.setRestock(digit, 1), isTrue);
      }
      expect(run.setRestock(6, 1), isFalse);
      expect(run.setPolicy(SettlementPolicy.sharedCrews), isTrue);
      expect(run.restock, hasLength(3));
      reopen();
      expect(run.policy, SettlementPolicy.sharedCrews);
      expect(run.setPolicy(SettlementPolicy.independent), isTrue);

      final companion = run.hatch(
        'assurance-helper',
        CreatureRecipe.starter(),
      )!;
      companion.name = 'Fern';
      companion.memory.teach('Welcome to the colony');
      expect(run.keepCompanion(companion.id), isTrue);

      expect(run.openBoard('palindrome'), isTrue);
      final lineCell = run.board.givens.indexOf(0);
      expect(run.place(lineCell, run.board.solution[lineCell]), isTrue);
      final lineTile = run.cellTileIds[lineCell];
      expect(lineTile, isNotNull);
      expect(run.openBoard('sandwich'), isTrue);
      final outsideCell = run.board.givens.indexOf(0);
      expect(run.place(outsideCell, run.board.solution[outsideCell]), isTrue);
      final outsideTile = run.cellTileIds[outsideCell];
      expect(outsideTile, isNotNull);
      reopen();
      expect(run.openBoard('palindrome'), isTrue);
      expect(run.cellTileIds[lineCell], lineTile);
      expect(run.openBoard('sandwich'), isTrue);
      expect(run.cellTileIds[outsideCell], outsideTile);
      expect(run.openBoard('palindrome'), isTrue);

      solveCurrentBoard();
      expect(run.advance(), isTrue);
      solveCurrentBoard();
      expect(run.advance(), isTrue);
      solveCurrentBoard();
      final hall = run.projects.singleWhere(
        (project) => project.id == 'meeting-hall',
      );
      for (final requirement in hall.requirements.entries) {
        expect(
          run.requestMaterial(
            hall.id,
            requirement.key,
            count: requirement.value,
          ),
          isTrue,
        );
      }
      settle();
      expect(run.build(hall.id), isTrue);
      expect(run.completed, isTrue);
      expect(run.openBoard('night-market'), isFalse);
      expect(run.openBoard('trail'), isTrue);
      solveCurrentBoard();
      expect(
        run.availableBoards.where((board) => board.expedition),
        hasLength(4),
      );
      expect(run.openBoard('night-market'), isTrue);
      solveCurrentBoard();

      expect(run.prestige(quick: true, charter: Charter.oneHelper), isTrue);
      reopen();
      expect(run.archives, hasLength(1));
      expect(run.companion?.id, companion.id);
      expect(run.companion?.name, 'Fern');
      expect(
        run.companion?.memory.phrases.single.text,
        'Welcome to the colony',
      );
      expect(run.creatures.single.isAmoeba, isTrue);
      expect(run.hatch('disallowed', CreatureRecipe.starter()), isNull);
    },
  );
}
