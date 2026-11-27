import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creatures.dart';

final _epoch = DateTime.utc(2026, 11, 27);

Campaign _reload(Campaign run) => Campaign.fromJson(
  jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
);

class _Journey {
  _Journey(this.run) : time = _epoch;

  Campaign run;
  DateTime time;

  void elapse([int seconds = 30]) {
    time = time.add(Duration(seconds: seconds));
    run.tick(time, offline: true);
  }

  void opening() {
    for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
      expect(run.executeBoardCommand(BoardCommand.slide(from, to)), isTrue);
    }
    for (final cell in [3, 5, 10]) {
      expect(run.placeTutorialToken(cell), isTrue);
    }
    expect(run.createAmoeba(), isTrue);
    time = DateTime.fromMillisecondsSinceEpoch(run.jobs.single.dueAt);
    run.tick(time);
    final offer = run.offers.single;
    expect(run.claimOffer(offer.id, 12), isTrue);
    expect(run.cleared, isTrue);
  }

  void solve() {
    if (run.cleared) return;
    final target = run.board;
    for (var digit = 1; digit <= target.size; digit++) {
      if (run.demand(digit) > 0) {
        expect(
          run.requestDigit(digit, count: target.size),
          isTrue,
          reason: '${target.id} needs $digit',
        );
      }
    }
    for (var pass = 0; pass < 20 && !run.cleared; pass++) {
      elapse();
      for (final index in run.visible.toList()) {
        if (run.cells[index] == 0) {
          expect(
            run.executeBoardCommand(
              BoardCommand.place(index, target.solution[index]),
            ),
            isTrue,
            reason:
                '${target.id} R${index ~/ target.size + 1}C${index % target.size + 1}',
          );
        }
      }
    }
    expect(run.cleared, isTrue, reason: target.id);
  }

  void sharedPath() {
    solve();
    while (run.board.id != 'arrows') {
      final previous = run.board.id;
      expect(run.advance(), isTrue, reason: 'advance from $previous');
      solve();
    }
  }

  void buildProject(String id) {
    final project = run.projects.singleWhere((item) => item.id == id);
    for (final requirement in project.requirements.entries) {
      expect(
        run.requestMaterial(
          project.id,
          requirement.key,
          count: requirement.value,
        ),
        isTrue,
        reason: '${project.name} ${requirement.key.name}',
      );
    }
    run = _reload(run);
    elapse();
    expect(run.canBuild(id), isTrue, reason: id);
    expect(run.build(id), isTrue, reason: id);
  }

  void finishRoute(String routeId) {
    final stages = campaignBoards
        .where((board) => board.route == routeId)
        .toList();
    expect(stages, hasLength(3));
    expect(run.openBoard(stages.first.id), isTrue);
    for (var index = 0; index < stages.length; index++) {
      solve();
      if (index + 1 < stages.length) expect(run.advance(), isTrue);
    }
    buildProject('meeting-hall');
    expect(run.completed, isTrue);

    var ceremony = run.finaleCeremony(routeId);
    expect(ceremony.ready, isTrue);
    for (final step in ceremony.steps) {
      expect(run.signOffDeduction(routeId, step.id), isTrue);
    }
    final dedication = switch (routeId) {
      'lines' => 'Open the bridge',
      'outside' => 'Open the provisions counter',
      'positions' => 'Mark the crossing lanes',
      _ => throw StateError('Unknown route $routeId'),
    };
    expect(run.chooseDedication(routeId, dedication), isTrue);
    ceremony = run.finaleCeremony(routeId);
    expect(ceremony.complete, isTrue);
  }

  void finishExpedition(String boardId) {
    var state = run.expeditionState(boardId);
    expect(state.available, isTrue, reason: boardId);
    expect(run.openBoard(boardId), isTrue, reason: boardId);
    solve();
    state = run.expeditionState(boardId);
    expect(state.patternEarned, isTrue);
    buildProject('cosmetic-$boardId');
    state = run.expeditionState(boardId);
    expect(state.ornamentInstalled, isTrue);
    expect(state.installerIds, isNotEmpty);
  }

  void reloadAfterPrestige({
    required int archiveCount,
    required String transactionId,
  }) {
    run = _reload(run);
    expect(run.archives, hasLength(archiveCount));
    final before = run.toJson();
    expect(run.prestige(transactionId: transactionId), isTrue);
    expect(run.archives, hasLength(archiveCount));
    expect(run.toJson(), before, reason: 'prestige retry must be idempotent');
  }
}

void main() {
  test(
    'four archives exercise every charter, expedition, retained helper and permanent upgrade',
    () {
      final journey = _Journey(Campaign(now: _epoch));
      journey.opening();

      // Colony 1 · Standard · Lines · Hilltop workshop.
      journey.sharedPath();
      journey.finishRoute('lines');
      journey.finishExpedition('hilltop');

      final helper = journey.run.hatch(
        'four-archive-helper',
        CreatureRecipe.starter(),
      );
      expect(helper, isNotNull);
      helper!.name = 'Reed';
      helper.memory.teach('Carried the first archive forward');
      expect(journey.run.keepCompanion(helper.id), isTrue);

      var quote = journey.run.prestigeQuote(
        upgrades: {LegacyUpgrade.warmStart: 1},
      );
      expect(quote.payout, 3);
      expect(quote.endingLegacy, 1);
      expect(
        journey.run.prestige(
          quick: true,
          charter: Charter.handOrders,
          companionId: helper.id,
          upgrades: const {LegacyUpgrade.warmStart: 1},
          transactionId: quote.transactionId,
        ),
        isTrue,
      );
      journey.reloadAfterPrestige(
        archiveCount: 1,
        transactionId: quote.transactionId,
      );
      expect(journey.run.charter, Charter.handOrders);
      expect(journey.run.companion?.id, helper.id);
      expect(journey.run.companion?.name, 'Reed');
      expect(journey.run.expeditionState('hilltop').familiarExample, isTrue);

      // Colony 2 · Hand Orders · Outside Clues · Night Market.
      journey.sharedPath();
      journey.finishRoute('outside');
      expect(journey.run.openBoard('trail'), isTrue);
      journey.solve();
      journey.finishExpedition('night-market');
      final marketWitness = journey.run.compareLastVisit('night-market');
      expect(marketWitness, isNull, reason: 'the current run is not history');

      quote = journey.run.prestigeQuote(
        upgrades: const {
          LegacyUpgrade.extraNest: 1,
          LegacyUpgrade.shorterRoutes: 1,
        },
      );
      expect(quote.payout, 4);
      expect(quote.endingLegacy, 0);
      expect(
        journey.run.prestige(
          quick: true,
          charter: Charter.noProducers,
          companionId: helper.id,
          upgrades: const {
            LegacyUpgrade.extraNest: 1,
            LegacyUpgrade.shorterRoutes: 1,
          },
          transactionId: quote.transactionId,
        ),
        isTrue,
      );
      journey.reloadAfterPrestige(
        archiveCount: 2,
        transactionId: quote.transactionId,
      );
      expect(journey.run.charter, Charter.noProducers);
      final archivedMarket = journey.run.compareLastVisit('night-market');
      expect(archivedMarket, isNotNull);
      expect(archivedMarket!.workerId, isNotEmpty);
      expect(archivedMarket.workerName, isNotEmpty);
      expect(archivedMarket.visibleResult, isNotEmpty);

      // Colony 3 · No Producers · Positions · Canal Crossings.
      journey.sharedPath();
      expect(journey.run.producers, isEmpty);
      journey.finishRoute('positions');
      journey.finishExpedition('canal');
      quote = journey.run.prestigeQuote(
        upgrades: const {LegacyUpgrade.shorterRoutes: 2},
      );
      expect(quote.payout, 4);
      expect(quote.endingLegacy, 1);
      expect(
        journey.run.prestige(
          quick: true,
          charter: Charter.oneHelper,
          companionId: helper.id,
          upgrades: const {LegacyUpgrade.shorterRoutes: 2},
          transactionId: quote.transactionId,
        ),
        isTrue,
      );
      journey.reloadAfterPrestige(
        archiveCount: 3,
        transactionId: quote.transactionId,
      );
      expect(journey.run.charter, Charter.oneHelper);
      expect(journey.run.companion?.id, helper.id);
      expect(journey.run.creatures.single.isAmoeba, isTrue);

      // Colony 4 · One Helper · credited Lines · Kiln Quarter.
      journey.sharedPath();
      journey.finishRoute('lines');
      journey.finishExpedition('kiln');
      expect(
        journey.run.expeditionState('kiln').installerIds,
        hasLength(1),
        reason: 'One Helper must not invent a construction worker',
      );
      quote = journey.run.prestigeQuote(
        upgrades: const {LegacyUpgrade.shorterRoutes: 3},
      );
      expect(quote.payout, 3);
      expect(quote.endingLegacy, 0);
      expect(
        journey.run.prestige(
          quick: true,
          charter: Charter.standard,
          companionId: helper.id,
          upgrades: const {LegacyUpgrade.shorterRoutes: 3},
          transactionId: quote.transactionId,
        ),
        isTrue,
      );
      journey.reloadAfterPrestige(
        archiveCount: 4,
        transactionId: quote.transactionId,
      );

      expect(journey.run.archives.map((archive) => archive['charter']), [
        'standard',
        'handOrders',
        'noProducers',
        'oneHelper',
      ]);
      for (final (index, expedition) in [
        'hilltop',
        'night-market',
        'canal',
        'kiln',
      ].indexed) {
        final archive = journey.run.archives[index];
        expect(archive['clears'] as List, contains(expedition));
        expect(
          (archive['buildings'] as Map).keys,
          containsAll(['meeting-hall', 'cosmetic-$expedition']),
        );
      }
      expect(journey.run.legacy, 0);
      expect(journey.run.legacyUpgrades, {
        LegacyUpgrade.warmStart: 1,
        LegacyUpgrade.extraNest: 1,
        LegacyUpgrade.shorterRoutes: 3,
      });
      expect(journey.run.companion?.id, helper.id);
      expect(journey.run.companion?.name, 'Reed');
      expect(
        journey.run.companion?.memory.phrases.single.text,
        'Carried the first archive forward',
      );
    },
  );
}
