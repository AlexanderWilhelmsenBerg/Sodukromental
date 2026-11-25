import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';

void main() {
  test('all 27 starter bodies work with either first perk', () {
    final starters = GrowthGroup.values
        .take(3)
        .map(
          (group) => growthNodes.where(
            (node) =>
                node.group == group && node.milestone == GrowthMilestone.five,
          ),
        )
        .toList();
    final cases = <Map<GrowthGroup, String>>[];
    for (final gait in starters[0]) {
      for (final shape in starters[1]) {
        for (final coat in starters[2]) {
          cases.add({
            gait.group: gait.id,
            shape.group: shape.id,
            coat.group: coat.id,
          });
        }
      }
    }
    expect(cases, hasLength(27));
    for (final choices in cases) {
      for (final perk in [WorkPerk.quickSteps, WorkPerk.extraDigitGrip]) {
        final recipe = CreatureRecipe(choices: choices, perks: [perk]);
        expect(recipe.validate(GrowthMilestone.five), isEmpty);
      }
    }
    expect(HatchPrice.quote(1, 1), const HatchPrice(4, 8));
    expect(HatchPrice.quote(2, 1), const HatchPrice(6, 12));
    expect(HatchPrice.quote(3, 1), const HatchPrice(9, 17));
    expect(HatchPrice.quote(1, 3), const HatchPrice(6, 12));
  });

  test('joined features are previewed once their input and date are valid', () {
    final branches = growthNodes.where((node) => node.requires.isNotEmpty);
    expect(branches, hasLength(4));
    expect(growthNodes.map((node) => node.id).toSet(), hasLength(57));
    for (final group in GrowthGroup.values) {
      expect(
        growthNodes.where((node) => node.group == group).length,
        greaterThanOrEqualTo(6),
      );
    }
    for (final branch in branches) {
      var recipe = CreatureRecipe.starter().withChoice(branch);
      for (final input in branch.requires) {
        recipe = recipe.withChoice(growthById[input]!);
      }
      final locked = GrowthMilestone.values[branch.milestone.index - 1];
      expect(recipe.validate(locked), isNotEmpty);
      expect(recipe.validate(branch.milestone), isEmpty);
      expect(
        Creature.preview(recipe, branch.milestone).appearance.parts,
        contains(branch.id),
      );
      final input = growthById[branch.requires.first]!;
      final withoutInput = recipe.withoutChoice(input.group);
      expect(withoutInput.validate(branch.milestone), isNotEmpty);
      expect(
        Creature.preview(withoutInput, branch.milestone).appearance.parts,
        isNot(contains(branch.id)),
      );
      final resumed = CreatureRecipe.fromJson(
        withoutInput.toJson(),
      ).withChoice(input);
      expect(resumed.validate(branch.milestone), isEmpty);
      expect(resumed.choices[branch.group], branch.id);
    }
  });

  test(
    'appearance, name, number and memory keep their seeded identity after save',
    () {
      final recipe = CreatureRecipe.starter();
      final individuals = List.generate(
        64,
        (index) => Creature.generate(
          runSeed: 457,
          sequence: index + 1,
          unlockedDigits: 6,
          recipe: recipe,
        ),
      );
      expect(individuals.map((creature) => creature.id).toSet(), hasLength(64));
      expect(
        individuals
            .map((creature) => creature.appearance.palette.first)
            .toSet(),
        hasLength(6),
      );
      expect(
        individuals.map((creature) => creature.personality).toSet(),
        hasLength(3),
      );
      expect(
        individuals.map((creature) => creature.favorite).toSet(),
        unorderedEquals([1, 2, 3, 4, 5, 6]),
      );
      expect(Creature.amoeba(457).favorite, 4);
      final creature = individuals[3]..name = 'Letterbug';
      creature.memory.teach('a favorite roof');
      final restored = Creature.fromJson(
        jsonDecode(jsonEncode(creature.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), creature.toJson());
    },
  );

  test('clear learning and encouragement are keyed by run and encounter', () {
    final memory = CompanionMemory()..lastRequest = 5;
    expect(memory.recordClear(1, 'board-a'), isFalse);
    memory.recordContribution(1, 'board-a', TaskKind.digit);
    expect(memory.encourage(1, 'board-a'), isTrue);
    expect(memory.preferredTask, TaskKind.digit);
    expect(memory.encourage(1, 'board-a'), isFalse);
    expect(memory.recordClear(1, 'board-a'), isTrue);
    expect(memory.recordClear(1, 'board-a'), isFalse);
    expect(memory.suggestDigit({5: 0}), isNull);
    memory.recordContribution(2, 'board-a', TaskKind.torch);
    memory.recordClear(2, 'board-a');
    expect(memory.suggestDigit({5: 0}), 5);
    expect(memory.suggestDigit({5: 2}), isNull);
    for (final id in ['board-b', 'board-c', 'board-d', 'board-e']) {
      memory.recordContribution(2, id, TaskKind.building);
      memory.recordClear(2, id);
    }
    expect(memory.canAskOutside, isFalse);
    memory.retained = true;
    expect(memory.waypoint(24000, priorityWork: true), isNull);
    expect(
      memory.waypoint(24000, priorityWork: false),
      CompanionWaypoint.library,
    );
    expect(memory.canAskOutside, isTrue);
    expect(CompanionMemory.fromJson(memory.toJson()).toJson(), memory.toJson());
  });

  test('optional work can be encouraged without granting a shared clear', () {
    final memory = CompanionMemory()
      ..recordTask(7, 'letter-work', TaskKind.building);
    final restored = CompanionMemory.fromJson(memory.toJson());
    expect(restored.recordClear(7, 'letter-work'), isFalse);
    expect(restored.encourage(7, 'letter-work'), isTrue);
    expect(restored.preferredTask, TaskKind.building);
    expect(restored.encourage(7, 'letter-work'), isFalse);
  });

  test(
    'speech throttles on resume and outside phrases require individual consent',
    () {
      final memory = CompanionMemory();
      expect(memory.teach('   '), isNull);
      final phrase = memory.teach('A roof!')!;
      expect(phrase.allowOutside, isFalse);
      expect(memory.approvedOutsidePhrases, isEmpty);
      expect(memory.nextEcho(0), 'A roof!');
      final resumed = CompanionMemory.fromJson(memory.toJson());
      expect(resumed.nextEcho(89999), isNull);
      expect(resumed.nextEcho(90000), 'A roof!');
      resumed.phrases.single.allowOutside = true;
      expect(resumed.approvedOutsidePhrases, ['A roof!']);
      resumed.muted = true;
      expect(resumed.approvedOutsidePhrases, isEmpty);
      expect(resumed.nextEcho(180000), isNull);
      expect(resumed.deletePhrase(phrase.id), isTrue);
      expect(resumed.phrases, isEmpty);
    },
  );

  testWidgets(
    'creator choices update the preview and review the same hatch command',
    (tester) async {
      CreatureRecipe? selected;
      HatchPrice? reviewed;
      final commandIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CreatureCreatorScreen(
            milestone: GrowthMilestone.five,
            quote: (count) => HatchPrice.quote(1, count),
            onHatch: (id, recipe, price) {
              commandIds.add(id);
              selected = recipe;
              reviewed = price;
              return null;
            },
            dna: 5,
            rna: 12,
            occupied: 1,
            housing: 2,
            reducedMotion: true,
          ),
        ),
      );
      await tester.tap(find.text('Grow four legs'));
      await tester.pump();
      final preview = tester.widget<CreatureSprite>(
        find.byType(CreatureSprite),
      );
      expect(preview.creature.appearance.parts, contains('quadrupedal'));
      expect(preview.pose, CreaturePose.travel);
      Future<void> press(String label) async {
        final target = find.text(label);
        await tester.scrollUntilVisible(target, 100);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await press('Extra digit grip');
      await press('Review hatch');
      await press('Hatch');
      await press('Hatch');
      expect(selected?.perks, [WorkPerk.extraDigitGrip]);
      expect(reviewed, const HatchPrice(4, 8));
      expect(commandIds.toSet(), hasLength(1));
      expect(commandIds, hasLength(2));
    },
  );

  testWidgets(
    'a retained companion can visit by invitation with local speech',
    (tester) async {
      final creature = Creature.amoeba(32);
      creature.memory
        ..retained = true
        ..teach('Nest day!');
      var changes = 0;
      var callbacks = 0;
      Future<void> show({required bool priorityWork}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompanionVisit(
                creature: creature,
                waypoint: CompanionWaypoint.library,
                priorityWork: priorityWork,
                invited: true,
                onCallBack: () => callbacks++,
                onChanged: () => changes++,
                reducedMotion: true,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(priorityWork: false);
      expect(find.text('Nest day!'), findsOneWidget);
      expect(changes, 1);
      await tester.tap(find.text('Call back'));
      expect(callbacks, 1);
      await show(priorityWork: true);
      expect(find.byType(CreatureSprite), findsNothing);
    },
  );

  testWidgets('profile teaches, repeats and deletes a local phrase', (
    tester,
  ) async {
    final creature = Creature.amoeba(32);
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreatureProfileScreen(
          creature: creature,
          selectedToKeep: false,
          onKeep: (_) {},
          onChanged: () => saves++,
          reducedMotion: true,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Watch the 4');
    await tester.tap(find.byTooltip('Teach phrase'));
    await tester.pump();
    expect(find.text('Amoeba: Watch the 4'), findsOneWidget);
    expect(creature.memory.approvedOutsidePhrases, isEmpty);
    final delete = find.byTooltip('Delete phrase');
    await tester.scrollUntilVisible(
      delete,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pump();
    expect(creature.memory.phrases, isEmpty);
    expect(find.text('Amoeba: Watch the 4'), findsNothing);
    expect(saves, 2);
  });

  testWidgets('material notice offers authored glyphs at 320 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final choices = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettlementMaterialNotice(
            available: starterGlyphs.where((glyph) => glyph.glyph != 'A'),
            remaining: const {MaterialRole.support: 2, MaterialRole.ring: 1},
            onSelect: (piece) => choices.add(piece.id),
          ),
        ),
      ),
    );
    expect(find.byTooltip('A · roof collected'), findsOneWidget);
    await tester.tap(find.byTooltip('Collect t as support'));
    await tester.tap(find.byTooltip('Collect i as support'));
    expect(choices, ['nest-support-t', 'nest-support-i']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creator restores a reviewed recipe and retries its saved command',
    (tester) async {
      final saved = CreatureDraft(
        commandId: 'hatch-original',
        recipe: CreatureRecipe.starter().withChoice(growthById['quadrupedal']!),
        reviewing: true,
      );
      final restored = CreatureDraft.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
      );
      String? command;
      CreatureDraft? current;
      await tester.pumpWidget(
        MaterialApp(
          home: CreatureCreatorScreen(
            milestone: GrowthMilestone.five,
            quote: (count) => HatchPrice.quote(1, count),
            onHatch: (id, recipe, quoted) {
              command = id;
              expect(recipe.choices[GrowthGroup.locomotion], 'quadrupedal');
              expect(quoted, const HatchPrice(4, 8));
              return null;
            },
            dna: 5,
            rna: 12,
            occupied: 1,
            housing: 2,
            reducedMotion: true,
            initialDraft: restored,
            onDraftChanged: (draft) => current = draft,
          ),
        ),
      );
      expect(find.text('Review hatch'), findsOneWidget);
      expect(current?.toJson(), saved.toJson());
      final hatch = find.text('Hatch');
      await tester.scrollUntilVisible(hatch, 100);
      await tester.ensureVisible(hatch);
      await tester.pumpAndSettle();
      await tester.tap(hatch);
      expect(command, saved.commandId);
    },
  );

  testWidgets(
    'a refused Android overlay grant leaves the companion in the game',
    (tester) async {
      final creature = Creature.amoeba(32);
      creature.memory.retained = true;
      for (var puzzle = 0; puzzle < 6; puzzle++) {
        creature.memory.recordContribution(0, puzzle, TaskKind.digit);
        creature.memory.recordClear(0, puzzle);
      }
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(CreatureRoaming.channel, (call) async {
        calls.add(call.method);
        return call.method == 'requestOverlayPermission';
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(CreatureRoaming.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: CreatureProfileScreen(
            creature: creature,
            selectedToKeep: true,
            onKeep: (_) {},
            onChanged: () {},
            reducedMotion: true,
          ),
        ),
      );
      final allow = find.text('Let it roam');
      await tester.scrollUntilVisible(
        allow,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(allow);
      await tester.pumpAndSettle();
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(creature.memory.outsideOptIn, isTrue);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(creature.memory.outsideOptIn, isFalse);
      expect(calls, contains('requestOverlayPermission'));
      expect(calls, isNot(contains('startRoaming')));
      expect(
        find.text('Your companion will stay in the game.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'overlay payload carries only the phrases allowed for that outing',
    (tester) async {
      final creature = Creature.amoeba(32);
      creature.memory
        ..retained = true
        ..outsideOptIn = true;
      for (var i = 0; i < 6; i++) {
        creature.memory.recordContribution(0, i, TaskKind.digit);
        creature.memory.recordClear(0, i);
      }
      creature.memory.teach('Private');
      creature.memory.teach('Can travel')!.allowOutside = true;

      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(CreatureRoaming.channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(CreatureRoaming.channel, null),
      );
      await tester.runAsync(() async {
        expect(
          await const CreatureRoaming().start(creature, reducedMotion: true),
          isTrue,
        );
      });
      expect(calls.map((call) => call.method), [
        'canDrawOverlays',
        'startRoaming',
      ]);
      final payload = calls.last.arguments as Map;
      expect(payload['id'], creature.id);
      expect(payload['phrases'], ['Can travel']);
      expect((payload['sprite'] as Uint8List).take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
    },
  );
}
