import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';

void main() {
  test('all 3072 adult ecology builds are reachable and distinct', () {
    expect(ecologyExpressions, hasLength(192));
    expect(
      ecologyExpressions.map((expression) => expression.rigPart).toSet(),
      hasLength(192),
    );
    final builds = EcologyPath.enumerateAdultBuilds().toList();
    expect(builds, hasLength(3072));
    expect(
      builds.map((path) => path.canonicalSignature).toSet(),
      hasLength(3072),
    );
    expect(
      builds.every(
        (path) => path.validate(GrowthMilestone.arrows).isEmpty && path.isAdult,
      ),
      isTrue,
    );
    for (final niche in ecologyNiches) {
      expect(
        builds
            .where((path) => path.nicheId == niche.id)
            .map((path) => path.projectedParts.join('|'))
            .toSet(),
        hasLength(256),
      );
    }
  });

  test('nurture only fills an eligible empty family', () {
    final creature = Creature.generate(
      runSeed: 19,
      sequence: 2,
      unlockedDigits: 6,
      recipe: CreatureRecipe.ecology(
        founder: CreatureFounder.plant,
        nicheId: 'plant.brace',
        firstDecision: EcologyChoice.gatherPair,
      ),
    );
    expect(HatchPrice.nurture, const HatchPrice(1, 2));
    expect(
      creature.nurture(EcologyChoice.collectBundles, GrowthMilestone.seven),
      isTrue,
    );
    expect(
      creature.nurture(EcologyChoice.hurryLoads, GrowthMilestone.seven),
      isFalse,
    );
    expect(
      creature.nurture(EcologyChoice.scoutEntrance, GrowthMilestone.seven),
      isFalse,
    );
    expect(creature.recipe.ecologyPath!.responseCount, 2);
  });

  test('work projection keeps responses mechanically observable', () {
    final path = EcologyPath(
      founder: CreatureFounder.gelColony,
      nicheId: 'gel.divide',
      decisions: const {
        DecisionFamily.digit: EcologyChoice.gatherPair,
        DecisionFamily.roof: EcologyChoice.fitSupports,
        DecisionFamily.light: EcologyChoice.carryTwoLights,
        DecisionFamily.coordination: EcologyChoice.relayLoad,
      },
    );
    final profile = CreatureRecipe(ecologyPath: path).workProfile;
    expect(profile.sameDigitCapacity, 2);
    expect(profile.lightBatchCapacity, 2);
    expect(profile.multiplierFor(task: TaskKind.building, support: true), .70);
    expect(profile.multiplierFor(task: TaskKind.building, handoff: true), .85);
  });

  test('four discovery routes require their witnessed clue', () {
    for (final secret in ecologySecrets) {
      var path = EcologyPath(
        founder: ecologyNicheById(secret.nicheId)!.founder,
        nicheId: secret.nicheId,
      );
      for (final choice in secret.requiredChoices) {
        path = path.choose(choice);
      }
      expect(path.discover(secret.id).secretId, isNull);
      path = path.witness(secret.eventId).discover(secret.id);
      expect(path.secretId, secret.id);
      expect(path.projectedParts, containsAll(secret.rigParts));
      expect(path.canonicalSignature, isNot(contains(secret.id)));
    }
  });

  test('disposition, path and bounded pair memory survive save', () {
    final first = Creature.generate(
      runSeed: 71,
      sequence: 1,
      unlockedDigits: 6,
      recipe: CreatureRecipe.communal(CreatureFounder.arthropod, nicheIndex: 1),
    );
    final second = Creature.generate(
      runSeed: 71,
      sequence: 2,
      unlockedDigits: 6,
      recipe: CreatureRecipe.communal(CreatureFounder.fungal),
    );
    final restored = Creature.fromJson(
      jsonDecode(jsonEncode(first.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), first.toJson());
    final a = CreatureBond.initial(first, second);
    final b = CreatureBond.initial(second, first);
    expect(a.score, b.score);
    a.score = -2;
    expect(a.recordDispute(1000), isTrue);
    expect(a.recordDispute(60999), isFalse);
    expect(a.recordDispute(61000), isTrue);
    expect(CreatureBond.fromJson(a.toJson()).toJson(), a.toJson());
  });

  testWidgets('guided creator changes lineage, habitat and response', (
    tester,
  ) async {
    CreatureRecipe? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: EcologyCreatureCreatorScreen(
          milestone: GrowthMilestone.five,
          quote: (count) => HatchPrice.quote(1, count),
          onHatch: (_, recipe, __) {
            chosen = recipe;
            return null;
          },
          dna: 8,
          rna: 16,
          occupied: 0,
          housing: 2,
          reducedMotion: true,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mammalian'));
    await tester.pump();
    await tester.tap(find.text('Shelter what you find'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('A digit gets loose'), 200);
    await tester.pump();
    if (find.text('Catch both').evaluate().isEmpty) {
      await tester.tap(find.text('A digit gets loose'));
      await tester.pump();
    }
    await tester.scrollUntilVisible(find.text('Catch both'), 120);
    await tester.tap(find.text('Catch both'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Review hatch'), 200);
    await tester.tap(find.text('Review hatch'));
    await tester.pump();
    expect(find.text('Founder · Mammalian'), findsOneWidget);
    expect(find.text('Habitat · Shelter what you find'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hatch'), 200);
    await tester.tap(find.text('Hatch'));
    expect(
      chosen!.ecologyPath!.decisions[DecisionFamily.digit],
      EcologyChoice.gatherPair,
    );
  });
}
