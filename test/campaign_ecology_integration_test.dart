import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';

final _epoch = DateTime.utc(2026, 11, 27);

Campaign _reload(Campaign campaign) => Campaign.fromJson(
  jsonDecode(jsonEncode(campaign.toJson())) as Map<String, dynamic>,
);

void _opening(Campaign campaign) {
  for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
    expect(campaign.slide(from, to), isTrue);
  }
  for (final index in [3, 5, 10]) {
    expect(campaign.placeTutorialToken(index), isTrue);
  }
  expect(campaign.createAmoeba(), isTrue);
  campaign.tick(_epoch.add(const Duration(seconds: 2)), offline: true);
  expect(campaign.place(12, 4), isTrue);
}

void _solve(Campaign campaign, DateTime time) {
  final board = campaign.board;
  for (var digit = 1; digit <= board.size; digit++) {
    if (campaign.demand(digit) > 0)
      campaign.requestDigit(digit, count: board.size);
  }
  for (var step = 1; step <= 20 && !campaign.cleared; step++) {
    campaign.tick(time.add(Duration(seconds: step * 30)), offline: true);
    for (final index in campaign.visible.toList()) {
      if (campaign.cells[index] == 0)
        campaign.place(index, board.solution[index]);
    }
  }
  expect(campaign.cleared, isTrue, reason: board.id);
}

void _advanceThrough(Campaign campaign, String target, DateTime time) {
  var cursor = time;
  while (campaign.board.id != target) {
    expect(campaign.advance(), isTrue, reason: campaign.board.id);
    _solve(campaign, cursor);
    cursor = cursor.add(const Duration(minutes: 15));
  }
}

EcologyPath _path(String niche, Map<DecisionFamily, EcologyChoice> decisions) =>
    EcologyPath(
      founder: ecologyNicheById(niche)!.founder,
      nicheId: niche,
      decisions: decisions,
    );

void main() {
  test('Campaign nurture charges once and hatch debit uses response count', () {
    var campaign = Campaign(now: _epoch);
    _opening(campaign);
    _advanceThrough(
      campaign,
      'growth-7',
      _epoch.add(const Duration(seconds: 2)),
    );

    final oneResponse = CreatureRecipe.ecology(
      founder: CreatureFounder.plant,
      nicheId: 'plant.brace',
      firstDecision: EcologyChoice.chase,
    );
    final firstQuote = campaign.hatchPrice(1);
    final helper = campaign.hatch(
      'ecology-one',
      oneResponse,
      quote: firstQuote,
    )!;
    final beforeDna = campaign.dna;
    final beforeRna = campaign.rna;
    expect(
      campaign.nurture('nurture-roof', helper.id, EcologyChoice.collectBundles),
      isTrue,
    );
    expect(campaign.dna, beforeDna - 1);
    expect(campaign.rna, beforeRna - 2);
    expect(
      campaign.nurture('nurture-roof', helper.id, EcologyChoice.collectBundles),
      isTrue,
    );
    expect(campaign.dna, beforeDna - 1);
    expect(campaign.rna, beforeRna - 2);
    expect(
      helper.appearance.parts,
      contains(
        ecologyExpression('plant.brace', EcologyChoice.collectBundles).rigPart,
      ),
    );

    final nest = campaign.projects.firstWhere(
      (project) => project.id == 'nest',
    );
    for (final requirement in nest.requirements.entries) {
      campaign.requestMaterial(
        nest.id,
        requirement.key,
        count: requirement.value,
      );
    }
    campaign.tick(_epoch.add(const Duration(hours: 2)), offline: true);
    expect(campaign.build(nest.id), isTrue);
    final twoResponses = CreatureRecipe(
      ecologyPath: _path('mammal.trails', {
        DecisionFamily.digit: EcologyChoice.gatherPair,
        DecisionFamily.roof: EcologyChoice.hurryLoads,
      }),
    );
    final secondQuote = campaign.hatchPrice(2);
    final dna = campaign.dna;
    final rna = campaign.rna;
    expect(
      campaign.hatch('ecology-two', twoResponses, quote: secondQuote),
      isNotNull,
    );
    expect(campaign.dna, dna - secondQuote.dna);
    expect(campaign.rna, rna - secondQuote.rna);
    campaign = _reload(campaign);
    final restored = campaign.creatures.firstWhere(
      (item) => item.id == helper.id,
    );
    expect(restored.recipe.ecologyPath!.responseCount, 2);
    final projected = campaign.toJson();
    final creatures = (projected['creatures'] as List)
        .cast<Map<String, dynamic>>();
    projected['creatures'] = [
      creatures.firstWhere((item) => item['id'] == helper.id),
      ...creatures.where((item) => item['id'] != helper.id),
    ];
    campaign = Campaign.fromJson(projected);
    expect(
      campaign.requestMaterial('house', MaterialRole.support, count: 2),
      isTrue,
    );
    final projectedJob = campaign.jobs.firstWhere(
      (job) => job.workerId == helper.id,
    );
    expect(projectedJob.count, 2);
  });

  testWidgets('profile recomputes nurture and discovery after callbacks', (
    tester,
  ) async {
    final creature = Creature.generate(
      runSeed: 9,
      sequence: 1,
      unlockedDigits: 9,
      recipe: CreatureRecipe(
        ecologyPath: EcologyPath(
          founder: CreatureFounder.fungal,
          nicheId: 'fungus.lantern',
          decisions: {DecisionFamily.light: EcologyChoice.scoutEntrance},
          witnessedEvents: const {'starter-torch-delivered'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreatureProfileScreen(
          creature: creature,
          selectedToKeep: false,
          onKeep: (_) {},
          onChanged: () {},
          ecologyMilestone: GrowthMilestone.arrows,
          onNurture: (choice) =>
              creature.nurture(choice, GrowthMilestone.arrows),
          onDiscover: (secretId) {
            final path = creature.recipe.ecologyPath!.discover(secretId);
            if (path.secretId != secretId) return false;
            creature.recipe = creature.recipe.withEcologyPath(path);
            return true;
          },
        ),
      ),
    );
    expect(find.textContaining('Nurture · 1 DNA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Relay a load'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final relay = find.ancestor(
      of: find.textContaining('Relay a load'),
      matching: find.byType(OutlinedButton),
    );
    expect(relay, findsOneWidget);
    await tester.tap(relay);
    await tester.pump();
    expect(
      creature.recipe.ecologyPath!.decisions[DecisionFamily.coordination],
      EcologyChoice.relayLoad,
    );
    expect(
      find.ancestor(
        of: find.textContaining('Relay a load'),
        matching: find.byType(OutlinedButton),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('Discover Lantern cap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Discover Lantern cap'));
    await tester.pump();
    expect(creature.recipe.ecologyPath!.secretId, 'lantern-cap');
    expect(find.text('Discover Lantern cap'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Discovered identity'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Discovered identity'), findsOneWidget);
  });

  test('owned construction and torch events unlock all four discoveries', () {
    var campaign = Campaign(now: _epoch);
    _opening(campaign);
    _advanceThrough(campaign, 'arrows', _epoch.add(const Duration(seconds: 2)));
    final specialists = <Creature>[
      Creature.generate(
        runSeed: 90,
        sequence: 3001,
        unlockedDigits: 9,
        recipe: CreatureRecipe(
          ecologyPath: _path('mammal.shelter', {
            DecisionFamily.digit: EcologyChoice.gatherPair,
            DecisionFamily.roof: EcologyChoice.fitSupports,
            DecisionFamily.coordination: EcologyChoice.relayLoad,
          }),
        ),
      ),
      Creature.generate(
        runSeed: 90,
        sequence: 3002,
        unlockedDigits: 9,
        recipe: CreatureRecipe(
          ecologyPath: _path('plant.brace', {
            DecisionFamily.roof: EcologyChoice.fitSupports,
            DecisionFamily.coordination: EcologyChoice.coverUrgent,
          }),
        ),
      ),
      Creature.generate(
        runSeed: 90,
        sequence: 3003,
        unlockedDigits: 9,
        recipe: CreatureRecipe(
          ecologyPath: _path('fungus.lantern', {
            DecisionFamily.light: EcologyChoice.scoutEntrance,
            DecisionFamily.coordination: EcologyChoice.relayLoad,
          }),
        ),
      ),
      Creature.generate(
        runSeed: 90,
        sequence: 3004,
        unlockedDigits: 9,
        recipe: CreatureRecipe(
          ecologyPath: _path('gel.divide', {
            DecisionFamily.digit: EcologyChoice.braceSlope,
            DecisionFamily.roof: EcologyChoice.collectBundles,
            DecisionFamily.light: EcologyChoice.carryTwoLights,
          }),
        ),
      ),
    ];
    final saved = campaign.toJson();
    saved['creatures'] = [
      ...specialists.map((creature) => creature.toJson()),
      ...(saved['creatures'] as List),
    ];
    campaign = Campaign.fromJson(saved);

    final hall = campaign.projects.firstWhere(
      (project) => project.id == 'meeting-hall',
    );
    for (final requirement in hall.requirements.entries) {
      expect(
        campaign.requestMaterial(
          hall.id,
          requirement.key,
          count: requirement.value,
        ),
        isTrue,
      );
    }
    campaign.tick(_epoch.add(const Duration(days: 1)), offline: true);
    expect(campaign.build(hall.id), isTrue);
    expect(
      campaign.discoverCreature('tool', specialists[0].id, 'tool-user'),
      isTrue,
    );
    expect(
      campaign.discoverCreature('tree', specialists[1].id, 'walking-tree'),
      isTrue,
    );

    expect(campaign.openBoard('halo'), isTrue);
    campaign.retry();
    campaign.tick(_epoch.add(const Duration(days: 2)), offline: true);
    expect(
      campaign.discoverCreature('cap', specialists[2].id, 'lantern-cap'),
      isTrue,
    );

    expect(campaign.openBoard('trail'), isTrue);
    campaign.retry();
    campaign.tick(_epoch.add(const Duration(days: 3)), offline: true);
    expect(
      campaign.discoverCreature('gel', specialists[3].id, 'backward-gel'),
      isTrue,
    );
    campaign = _reload(campaign);
    for (final secret in ecologySecrets) {
      final creature = campaign.creatures.firstWhere(
        (item) => item.recipe.ecologyPath?.secretId == secret.id,
      );
      expect(creature.appearance.parts, containsAll(secret.rigParts));
    }
  });
}
