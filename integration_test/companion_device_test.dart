import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';

const _deviceEnabled = bool.fromEnvironment('SODU_RUN_OVERLAY_DEVICE');
const _externalChecks = bool.fromEnvironment('SODU_OVERLAY_EXTERNAL');

Creature _restoreRetainedCompanion() {
  final companion = Creature.amoeba(842607)..name = 'Button';
  companion.memory.retained = true;
  for (var encounter = 0; encounter < 6; encounter++) {
    companion.memory.recordContribution(
      'device-fixture',
      encounter,
      TaskKind.digit,
    );
    companion.memory.recordClear('device-fixture', encounter);
  }
  companion.memory.teach('This phrase stays in the game.');
  companion.memory.teach('A good day for a nest.')!.allowOutside = true;
  final snapshot = Campaign(seed: 842608).toJson()
    ..['creatures'] = [companion.toJson()]
    ..['companion'] = companion.toJson()
    ..['companionChoice'] = companion.id;
  return Campaign.fromJson(snapshot).companion!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'retained companion uses Android permission and starts and stops the actual roaming service',
    skip: !_deviceEnabled || !Platform.isAndroid,
    (tester) async {
      const roaming = CreatureRoaming();
      final companion = _restoreRetainedCompanion();
      expect(companion.memory.canAskOutside, isTrue);
      expect(companion.memory.approvedOutsidePhrases, [
        'A good day for a nest.',
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: CreatureProfileScreen(
            creature: companion,
            selectedToKeep: true,
            onKeep: (_) {},
            onChanged: () {},
            roaming: roaming,
            reducedMotion: true,
          ),
        ),
      );

      Future<void> press(String label) async {
        final target = find.text(label);
        await tester.scrollUntilVisible(
          target,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> waitUntil(
        Future<bool> Function() check, {
        Duration timeout = const Duration(seconds: 15),
      }) async {
        final elapsed = Stopwatch()..start();
        while (!await check()) {
          if (elapsed.elapsed > timeout)
            fail('Android did not reach the expected roaming state.');
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump();
        }
      }

      expect(
        await roaming.canDrawOverlays(),
        isTrue,
        reason:
            'Grant the emulator overlay app op before running this fixture.',
      );
      expect(await roaming.isRoaming(), isFalse);
      // The Android grant alone cannot launch a visit.
      await press('Stay here');
      expect(companion.memory.outsideOptIn, isFalse);
      expect(await roaming.isRoaming(), isFalse);

      await press('Let it roam');
      await waitUntil(roaming.isRoaming);
      expect(companion.memory.outsideOptIn, isTrue);
      await waitUntil(
        () async => find.text('Stop roaming').evaluate().isNotEmpty,
      );
      await press('Stop roaming');
      await waitUntil(() async => !await roaming.isRoaming());
      expect(companion.memory.outsideOptIn, isFalse);

      if (_externalChecks) {
        // Host orchestration sends Home and inspects the actual window before
        // stopping via Android's notification shade. It then tests lock/revoke.
        await press('Let it roam');
        await waitUntil(roaming.isRoaming);
        debugPrint('SODU_COMPANION_READY: launcher-and-notification');
        await waitUntil(
          () async => !await roaming.isRoaming(),
          timeout: const Duration(seconds: 90),
        );
        await waitUntil(
          () async => find.text('Let it roam').evaluate().isNotEmpty,
        );

        await press('Let it roam');
        await waitUntil(roaming.isRoaming);
        debugPrint('SODU_COMPANION_READY: lock');
        await waitUntil(
          () async => !await roaming.isRoaming(),
          timeout: const Duration(seconds: 90),
        );
        await waitUntil(
          () async => find.text('Let it roam').evaluate().isNotEmpty,
        );

        await press('Let it roam');
        await waitUntil(roaming.isRoaming);
        debugPrint('SODU_COMPANION_READY: revoke');
        await waitUntil(
          () async =>
              !await roaming.canDrawOverlays() && !await roaming.isRoaming(),
          timeout: const Duration(seconds: 90),
        );
      }
    },
  );
}
