import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';
import 'package:sodukromental/settlement_scene.dart';

void main() {
  test('128 seeds produce distinct structural village plans', () {
    final plans = [
      for (var seed = 1; seed <= 128; seed++) SettlementPlan.seeded(seed),
    ];
    expect(
      plans.map((plan) => plan.structuralSignature).toSet(),
      hasLength(128),
    );
    expect(plans[0].plots['house'], isNot(plans[1].plots['house']));
    expect(plans[0].street, isNot(equals(plans[1].street)));
    expect(
      plans[0].shapes['meeting-hall'],
      isNot(plans[1].shapes['meeting-hall']),
    );
  });

  for (final width in [320.0, 375.0, 414.0, 768.0]) {
    testWidgets('settlement remains legible at $width dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final residents = List.generate(7, Creature.amoeba);
      final job = ColonyJob(
        id: 'letter-trip',
        kind: TaskKind.building,
        workerId: residents.first.id,
        dueAt: 1000,
        request: 'roof-request',
        projectId: 'nest',
        glyphs: const [MaterialGlyph('roof-a', 'A', MaterialRole.roof)],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SettlementScene(
                  seed: 23,
                  creatures: residents,
                  jobs: [job],
                  projects: const [
                    ProjectSpec('nest', 'Nest', {
                      MaterialRole.roof: 1,
                      MaterialRole.support: 2,
                      MaterialRole.ring: 1,
                    }),
                  ],
                  projectProgresses: const [
                    ProjectProgress(
                      projectId: 'nest',
                      name: 'Nest',
                      requirements: {
                        MaterialRole.roof: 1,
                        MaterialRole.support: 2,
                        MaterialRole.ring: 1,
                      },
                      installed: {},
                      reserved: {MaterialRole.support: 1},
                      inTransit: {MaterialRole.roof: 1},
                      complete: false,
                    ),
                  ],
                  buildings: const {},
                  buildingGlyphs: const {},
                  materials: const {MaterialRole.support: 1},
                  reducedMotion: true,
                  onResidentPressed: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('settlement-map')), findsOneWidget);
      expect(find.textContaining('Nest · 2 of 4 pieces'), findsOneWidget);
      expect(find.byType(CreatureSprite), findsNWidgets(5));
      expect(find.byIcon(Icons.motion_photos_off_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
