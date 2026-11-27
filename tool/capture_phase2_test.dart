import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sodukromental/hum.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/colony_screen.dart';
import 'package:sodukromental/creatures.dart';
import 'package:sodukromental/main.dart' show gameTheme;
import 'package:sodukromental/settlement_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the expansion for the debug handoff', (tester) async {
    await tester.runAsync(() async {
      for (final family in [Hum.headingFont, Hum.digitFont, 'MaterialIcons']) {
        final asset = family == 'MaterialIcons'
            ? 'fonts/MaterialIcons-Regular.otf'
            : 'assets/fonts/$family.ttf';
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 800));
      final view = tester.binding.renderViews.first;
      await tester.runAsync(() async {
        final frame = await (view.debugLayer! as OffsetLayer).toImage(
          view.paintBounds,
        );
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
        frame.dispose();
        await File(
          'docs/evidence/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final seed in [23, 91]) {
      final fixture = _village(seed);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: gameTheme(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'City colony · seed $seed',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettlementScene(
                      seed: seed,
                      creatures: fixture.residents,
                      jobs: fixture.jobs,
                      projects: fixture.projects,
                      projectProgresses: fixture.progress,
                      buildings: fixture.buildings,
                      buildingGlyphs: const {},
                      materials: const {MaterialRole.beam: 2},
                      campaign: fixture.campaign,
                      reducedMotion: seed == 91,
                      socialMoments: fixture.campaign.socialMoments,
                      antics: fixture.campaign.antics,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await capture(
        seed == 91 ? 'phase2-village-reduced-seed91' : 'phase2-village-seed23',
      );
    }

    final opening = Campaign(seed: 23);
    await tester.pumpWidget(_campaign(opening, reducedMotion: true));
    await capture('phase2-opening-reduced');

    final fogSave = Campaign(seed: 23).toJson()
      ..['clears'] = campaignBoards
          .takeWhile((board) => board.id != 'halo')
          .map((board) => board.id)
          .toList();
    fogSave['creatures'] = [Creature.amoeba(23).toJson()];
    final fog = Campaign.fromJson(fogSave)..markLesson('halo');
    expect(fog.openBoard('halo'), isTrue);
    fog.tick(DateTime.now().add(const Duration(seconds: 12)));
    expect(fog.visible, isNotEmpty);
    await tester.pumpWidget(_campaign(fog, reducedMotion: true));
    await capture('phase2-halo-fog-reduced');
  });
}

Widget _campaign(Campaign run, {required bool reducedMotion}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: gameTheme(),
  home: Scaffold(
    body: SafeArea(
      child: ColonyScreen(
        campaign: run,
        onChanged: () {},
        reducedMotion: reducedMotion,
        tiltEnabled: false,
      ),
    ),
  ),
);

({
  Campaign campaign,
  List<Creature> residents,
  List<ColonyJob> jobs,
  List<ProjectSpec> projects,
  List<ProjectProgress> progress,
  Set<String> buildings,
})
_village(int seed) {
  final residents = [
    for (var i = 0; i < 6; i++)
      Creature.generate(
        runSeed: seed,
        sequence: i + 1,
        unlockedDigits: 9,
        recipe: CreatureRecipe.communal(
          CreatureFounder.values[i % CreatureFounder.values.length],
          nicheIndex: i,
        ),
      ),
  ];
  final saved = Campaign(seed: seed).toJson()
    ..['clears'] = const [
      'opening',
      'growth-5',
      'growth-6',
      'growth-7',
      'growth-8',
      'growth-9',
      'renban',
      'thermometer',
      'halo',
      'arrows',
    ]
    ..['creatures'] = residents.map((resident) => resident.toJson()).toList()
    ..['weather'] = {
      ...((Campaign(seed: seed).toJson()['weather']) as Map<String, dynamic>),
      'elapsed': 2400,
      'stored': 5,
    };
  final campaign = Campaign.fromJson(saved);
  final jobs = [
    ColonyJob(
      id: 'qa-hall-beam',
      kind: TaskKind.building,
      workerId: residents.first.id,
      dueAt: 9000,
      request: 'qa-beam',
      projectId: 'meeting-hall',
      glyphs: const [MaterialGlyph('qa-H', 'H', MaterialRole.beam)],
    ),
  ];
  const hall = ProjectSpec('meeting-hall', 'Meeting Hall', {
    MaterialRole.roof: 2,
    MaterialRole.support: 4,
    MaterialRole.beam: 2,
  });
  const progress = ProjectProgress(
    projectId: 'meeting-hall',
    name: 'Meeting Hall',
    requirements: {
      MaterialRole.roof: 2,
      MaterialRole.support: 4,
      MaterialRole.beam: 2,
    },
    installed: {MaterialRole.roof: 2, MaterialRole.support: 2},
    reserved: {MaterialRole.support: 2},
    inTransit: {MaterialRole.beam: 1},
    complete: false,
  );
  return (
    campaign: campaign,
    residents: residents,
    jobs: jobs,
    projects: const [hall],
    progress: const [progress],
    buildings: const {'nest', 'house', 'storehouse', 'workshop'},
  );
}
