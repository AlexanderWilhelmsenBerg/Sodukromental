import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creature_social_view.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';
import 'package:sodukromental/settlement_scene.dart';

final _epoch = DateTime.utc(2026, 11, 27);

Campaign _socialRun() {
  final original = Campaign(now: _epoch).toJson();
  original['creatures'] = [
    Creature.generate(
      runSeed: 42,
      sequence: 1,
      unlockedDigits: 6,
      recipe: CreatureRecipe.communal(CreatureFounder.plant),
    ).toJson(),
    Creature.generate(
      runSeed: 42,
      sequence: 2,
      unlockedDigits: 6,
      recipe: CreatureRecipe.communal(CreatureFounder.mammalian),
    ).toJson(),
  ];
  return Campaign.fromJson(original);
}

Campaign _reload(Campaign run) => Campaign.fromJson(
  jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
);

void main() {
  test('real resident pair affinity and active-time opportunity persist', () {
    var run = _socialRun();
    run.tick(_epoch.add(const Duration(seconds: 1)));
    expect(run.bonds, hasLength(1));
    expect(run.socialMoments, hasLength(1));
    final moment = run.socialMoments.single;
    expect({
      moment.firstId,
      moment.secondId,
    }, run.creatures.map((creature) => creature.id).toSet());
    expect(run.socialActiveMs, 1000);

    run = _reload(run);
    expect(run.bonds.single.toJson(), isNotEmpty);
    expect(run.socialMoments.single.toJson(), moment.toJson());
    run.tick(_epoch.add(const Duration(hours: 1)), colonyVisible: false);
    expect(
      run.socialActiveMs,
      1000,
      reason: 'background time is not active social time',
    );
  });

  test('prestige archives pair history and clears current-run bonds', () {
    var run = _socialRun();
    run.tick(_epoch.add(const Duration(seconds: 1)));
    final saved = run.toJson();
    saved['clears'] = [campaignBoards.firstWhere((board) => board.finale).id];
    saved['buildings'] = {'meeting-hall': <Object>[]};
    run = Campaign.fromJson(saved);
    expect(run.completed, isTrue);
    expect(run.prestige(keepSelectedCompanion: false), isTrue);
    expect(run.bonds, isEmpty);
    expect(run.socialMoments, isEmpty);
    expect(run.archives.last['bonds'], isNotEmpty);
  });

  test('friendly same-project handoff improves a real saved job once', () {
    final base = _socialRun();
    final saved = base.toJson();
    final residents = base.creatures;
    saved['bonds'] = [
      CreatureBond(
        firstId: residents[0].id,
        secondId: residents[1].id,
        score: 2,
      ).toJson(),
    ];
    Map<String, dynamic> job(String id, String worker) => {
      'id': id,
      'kind': TaskKind.building.name,
      'worker': worker,
      'dueAt': _epoch.add(const Duration(seconds: 20)).millisecondsSinceEpoch,
      'request': 'beam',
      'count': 1,
      'project': 'house',
      'glyphs': <Object>[],
    };
    saved['materialJobs'] = [
      job('beam-a', residents[0].id),
      job('beam-b', residents[1].id),
    ];
    final ordinary = Campaign.fromJson(saved);
    final ordinaryDue = ordinary.jobs.last.dueAt;
    ordinary.tick(_epoch.add(const Duration(seconds: 1)));
    expect(ordinary.socialMoments.single.kind, SocialMomentKind.handoff);
    expect(ordinary.jobs.last.dueAt, ordinaryDue);
    expect(
      residents.first.nurture(EcologyChoice.relayLoad, GrowthMilestone.arrows),
      isTrue,
    );
    saved['creatures'] = [for (final resident in residents) resident.toJson()];
    var run = Campaign.fromJson(saved);
    final originalDue = run.jobs.last.dueAt;
    run.tick(_epoch.add(const Duration(seconds: 1)));
    expect(run.socialMoments.single.kind, SocialMomentKind.handoff);
    expect(run.jobs.last.dueAt, lessThan(originalDue));
    final improvedDue = run.jobs.last.dueAt;
    run = _reload(run);
    run.tick(_epoch.add(const Duration(seconds: 10)));
    expect(
      run.jobs.where((job) => job.id == 'beam-b').firstOrNull?.dueAt,
      anyOf(isNull, improvedDue),
      reason: 'a handoff bonus is not repeatedly applied to the same job',
    );
  });

  testWidgets('scene renders sourced pair endpoints and work-apart control', (
    tester,
  ) async {
    final residents = _socialRun().creatures;
    final moment = SocialMoment(
      id: 'argument',
      firstId: residents[0].id,
      secondId: residents[1].id,
      kind: SocialMomentKind.argument,
      startedActiveMs: 0,
      dueActiveMs: 2000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettlementScene(
            seed: 1,
            creatures: residents,
            jobs: const [],
            projects: const [],
            projectProgresses: const [],
            buildings: const {},
            buildingGlyphs: const {},
            materials: const {},
            socialMoments: [moment],
            reducedMotion: true,
          ),
        ),
      ),
    );
    expect(find.byType(CreatureSprite), findsNWidgets(2));
    expect(find.text('Work apart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board roaming uses owned residents and passes through input', (
    tester,
  ) async {
    final residents = _socialRun().creatures;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 320,
          child: BoardRoamingLayer(
            dimension: 5,
            cells: const [
              1,
              2,
              3,
              4,
              5,
              2,
              3,
              4,
              5,
              1,
              3,
              4,
              5,
              1,
              2,
              4,
              5,
              1,
              2,
              3,
              5,
              1,
              2,
              3,
              4,
            ],
            visible: Set.of(List.generate(25, (index) => index)),
            residents: residents,
            reducedMotion: true,
          ),
        ),
      ),
    );
    expect(find.byType(CreatureSprite), findsNWidgets(2));
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
