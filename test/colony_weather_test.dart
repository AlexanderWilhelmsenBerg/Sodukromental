import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creatures.dart';
import 'package:sodukromental/glyph_rain.dart';
import 'package:sodukromental/hum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled fonts distinguish open and closed 4 and both bowls of an 8',
    () async {
      for (final font in [Hum.headingFont, Hum.digitFont]) {
        await (FontLoader(
          font,
        )..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
      }
      Future<int> counters(String digit, String font) async =>
          (await GlyphHollows.measure(
            digit,
            TextStyle(
              fontFamily: font,
              fontWeight: FontWeight.w600,
              fontSize: 72,
            ),
          )).pools.length;
      expect(await counters('4', Hum.headingFont), 1);
      expect(await counters('4', Hum.digitFont), 0);
      expect(await counters('8', Hum.headingFont), 2);
      expect(await counters('e', Hum.headingFont), 1);
    },
  );
  test(
    'harvest drains a pool; a reserved scoop survives reload and offline time',
    () {
      final epoch = DateTime.utc(2026, 1, 1);
      final data = Campaign(now: epoch).toJson();
      data['clears'] = ['growth-6'];
      final worker = Creature.generate(
        runSeed: 2,
        sequence: 0,
        unlockedDigits: 4,
        recipe: CreatureRecipe.starter(),
      );
      data['creatures'] = [worker.toJson()];
      var run = Campaign.fromJson(data);
      run.weather.observe('nest-ring', 2);
      run.tick(epoch.add(const Duration(milliseconds: 800)));
      expect(run.weather.pool('nest-ring'), 2);
      expect(run.scoopWater('nest-ring'), isTrue);
      expect(run.scoopWater('nest-ring'), isFalse);
      run.weather.drain('nest-ring');
      run = Campaign.fromJson(
        jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
      );
      expect(run.weather.pool('nest-ring'), 0);
      expect(run.weather.carrierId, worker.id);
      run.tick(epoch.add(const Duration(hours: 8)), offline: true);
      expect(run.weather.stored, 0);
      for (var i = 1; i <= 3; i++) {
        run.tick(epoch.add(Duration(hours: 8, seconds: i)));
      }
      expect(run.weather.carrierId, isNull);
      expect(run.weather.stored, 1);
      run.tick(epoch.add(const Duration(hours: 12)), offline: true);
      expect(run.weather.stored, 1);
    },
  );
}
