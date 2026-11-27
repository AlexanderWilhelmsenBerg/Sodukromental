import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creatures.dart';

final _epoch = DateTime.utc(2026, 11, 27);

Campaign _projectRun() {
  final saved = Campaign(now: _epoch).toJson();
  saved['clears'] = ['growth-5'];
  saved['creatures'] = [
    Creature.generate(
      runSeed: 91,
      sequence: 1,
      unlockedDigits: 5,
      recipe: CreatureRecipe.starter(),
    ).toJson(),
  ];
  Map<String, dynamic> glyph(String id, String value, String role) => {
    'id': id,
    'glyph': value,
    'role': role,
    'index': null,
  };
  saved['materials'] = {
    'roof': [glyph('roof-a', 'A', 'roof')],
    'support': [
      glyph('support-same-a', 'i', 'support'),
      glyph('support-same-b', 'i', 'support'),
    ],
    'ring': [glyph('ring-o', 'o', 'ring')],
  };
  return Campaign.fromJson(saved);
}

Campaign _reload(Campaign run) => Campaign.fromJson(
  jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
);

void main() {
  test(
    'distinct identical glyph loads pause before and after cutting and install once',
    () {
      var run = _projectRun();
      expect(run.startConstruction('nest'), isTrue);
      var work = run.constructionFor('nest')!;
      final ids = work.loads.map((load) => load.id).toSet();
      expect(ids, hasLength(4));
      expect(
        work.loads
            .where((load) => load.glyph.glyph == 'i')
            .map((load) => load.glyph.id)
            .toSet(),
        {'support-same-a', 'support-same-b'},
      );

      expect(run.pauseConstruction('nest'), isTrue);
      run.tick(_epoch.add(const Duration(seconds: 10)));
      expect(
        run.constructionFor('nest')!.loads.first.stage,
        ConstructionLoadStage.cutting,
      );

      run = _reload(run);
      expect(
        run.constructionFor('nest')!.loads.map((load) => load.id).toSet(),
        ids,
      );
      expect(run.resumeConstruction('nest'), isTrue);
      run.tick(_epoch.add(const Duration(milliseconds: 11200)));
      expect(run.pauseConstruction('nest'), isTrue);
      var progress = run.projectProgress('nest');
      expect(progress.cutStock.values.fold<int>(0, (a, b) => a + b), 1);
      expect(progress.installed.values.fold<int>(0, (a, b) => a + b), 0);

      run = _reload(run);
      work = run.constructionFor('nest')!;
      expect(work.paused, isTrue);
      expect(work.loads.map((load) => load.id).toSet(), ids);
      expect(run.resumeConstruction('nest'), isTrue);
      run.tick(_epoch.add(const Duration(seconds: 30)));
      progress = run.projectProgress('nest');
      expect(progress.complete, isTrue);
      expect(progress.installed.values.fold<int>(0, (a, b) => a + b), 4);
      expect(run.buildingGlyphs['nest']!.map((glyph) => glyph.id).toSet(), {
        'roof-a',
        'support-same-a',
        'support-same-b',
        'ring-o',
      });
      final housing = run.housing;

      run = _reload(run);
      run.tick(_epoch.add(const Duration(seconds: 60)));
      expect(run.housing, housing);
      expect(run.build('nest'), isFalse);
      expect(run.buildingGlyphs['nest'], hasLength(4));
    },
  );

  test('release before installation returns exact reserved glyph IDs', () {
    final run = _projectRun();
    expect(run.startConstruction('nest'), isTrue);
    final reserved = run
        .constructionFor('nest')!
        .loads
        .map((load) => load.glyph.id)
        .toSet();
    expect(run.cancelConstruction('nest'), isTrue);
    expect(run.stockedGlyphs.map((glyph) => glyph.id).toSet(), reserved);
    expect(run.constructionFor('nest'), isNull);
  });
}
