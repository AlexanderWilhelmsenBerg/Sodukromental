import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/creatures.dart';

final _epoch = DateTime.utc(2026, 11, 25);

Campaign _reload(Campaign run) => Campaign.fromJson(
  jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
);

void _slide(Campaign run) {
  for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
    expect(run.slide(from, to), isTrue);
  }
}

void _opening(Campaign run) {
  _slide(run);
  for (final cell in [3, 5, 10]) {
    expect(run.placeTutorialToken(cell), isTrue);
  }
  expect(run.createAmoeba(), isTrue);
  run.tick(_epoch.add(const Duration(seconds: 2)));
  expect(run.offers.single.digit, 4);
  expect(run.claimOffer(run.offers.single.id, 12), isTrue);
  expect(run.cleared, isTrue);
}

class _Drive {
  _Drive(this.run, {DateTime? time})
    : time = time ?? _epoch.add(const Duration(seconds: 2));
  Campaign run;
  DateTime time;

  void elapse(int seconds) {
    time = time.add(Duration(seconds: seconds));
    run.tick(time, offline: true);
  }

  void solve() {
    if (run.cleared) return;
    final original = run.board;
    for (var digit = 1; digit <= original.size; digit++) {
      if (run.demand(digit) > 0) {
        expect(run.requestDigit(digit, count: original.size), isTrue);
      }
    }
    for (var step = 0; step < 15 && !run.cleared; step++) {
      elapse(30);
      for (final index in run.visible.toList()) {
        if (run.cells[index] == 0) {
          expect(
            run.place(index, original.solution[index]),
            isTrue,
            reason: '${original.id} at index $index',
          );
        }
      }
    }
    expect(run.cleared, isTrue, reason: original.id);
  }

  void hall() {
    final project = run.projects.firstWhere(
      (item) => item.id == 'meeting-hall',
    );
    for (final role in project.requirements.keys) {
      expect(
        run.requestMaterial(
          project.id,
          role,
          count: project.requirements[role]!,
        ),
        isTrue,
      );
    }
    run = _reload(run);
    elapse(30);
    expect(run.canBuild(project.id), isTrue);
    expect(run.build(project.id), isTrue);
  }

  void route(String id, {bool buildFirst = false}) {
    while (run.board.id != 'arrows') {
      expect(run.advance(), isTrue, reason: run.board.id);
      solve();
    }
    if (buildFirst) hall();
    final stages = campaignBoards.where((board) => board.route == id).toList();
    expect(run.openBoard(stages.first.id), isTrue);
    solve();
    expect(run.advance(), isTrue);
    solve();
    expect(run.advance(), isTrue);
    solve();
    if (!buildFirst) hall();
    expect(run.completed, isTrue);
  }
}

void main() {
  test('opening saves the exact token and a reserved fourth digit once', () {
    var run = Campaign(now: _epoch);
    expect(run.tutorialReady, isFalse);
    expect(run.slide(0, 1), isFalse);
    expect(run.placeTutorialToken(1), isFalse);
    _slide(run);
    expect(run.undo(), isTrue);
    expect(run.slide(5, 4), isTrue);
    expect(run.tutorialReady, isTrue);
    expect(run.placeTutorialToken(3, token: 2), isTrue);
    run = _reload(run);
    expect(run.usedTutorialTokens, {2});
    expect(run.placeTutorialToken(5, token: 2), isFalse);
    expect(run.placeTutorialToken(5, token: 0), isTrue);
    expect(run.placeTutorialToken(10, token: 1), isTrue);
    expect(run.dna, 3);
    expect(run.createAmoeba(), isTrue);
    final id = run.creatures.single.id;
    final reservation = run.jobs.single.id;
    run = _reload(run);
    expect(run.createAmoeba(), isFalse);
    expect(run.jobs.single.id, reservation);
    run.tick(_epoch.add(const Duration(milliseconds: 1999)));
    expect(run.offers, isEmpty);
    run.tick(_epoch.add(const Duration(seconds: 2)));
    expect(run.offers.single.workerId, id);
    run.holdOffer(run.offers.single.id);
    run.tick(_epoch.add(const Duration(seconds: 8)));
    expect(run.offers.single.id, reservation);
    expect(run.claimOffer(reservation, 12), isTrue);
    expect(run.claimOffer(reservation, 12), isFalse);
    expect(run.rna, 6);
    expect(run.dna, 0);
    final original = run.cellTileIds;
    expect(original, hasLength(16));
    expect(run.advance(), isTrue);
    final grown = {
      ...run.cellTileIds.values,
      ...run.trayTileIds.values.expand((ids) => ids),
    };
    expect(grown, hasLength(20));
    expect(grown, containsAll(original.values));
    for (final entry in run.cellTileIds.entries) {
      expect(entry.value, original[(entry.key ~/ 5) * 4 + entry.key % 5]);
    }
    expect(_reload(run).trayTileIds, run.trayTileIds);
    expect(run.fixed.length, 9);
    expect(run.tray, {1: 3, 2: 4, 3: 1, 4: 3});
    expect(run.jobs.single.digit, 5);
  });

  test('erasing, undo, and reload keep exact carried copies', () {
    var run = Campaign(now: _epoch);
    _opening(run);
    expect(run.advance(), isTrue);
    final cells = [
      for (final index in run.board.indices)
        if (run.cells[index] == 0) index,
    ];
    final digit = run.tray.keys.first;
    final initial = run.trayTileIds[digit]!.first;
    run.toggleNote(cells.first, digit);
    expect(run.place(cells.first, digit), isTrue);
    expect(run.cellTileIds[cells.first], initial);
    expect(run.erase(cells.first), isTrue);
    run = _reload(run);
    expect(run.trayTileIds[digit], contains(initial));
    expect(run.undo(), isTrue);
    expect(run.cellTileIds[cells.first], initial);
    expect(run.undo(), isTrue);
    expect(run.trayTileIds[digit], contains(initial));
    expect(run.notes[cells.first], {digit});
  });

  test('v1 count and origin saves migrate to distinct, persisted copies', () {
    var run = Campaign(now: _epoch);
    _opening(run);
    expect(run.advance(), isTrue);
    final snapshot = run.toJson()..['version'] = 1;
    final progresses = snapshot['progress'] as Map<String, dynamic>;
    for (final value in progresses.values) {
      final progress = value as Map<String, dynamic>;
      final tiles = progress.remove('tiles') as Map<String, dynamic>;
      final stock = progress['stock'] as Map<String, dynamic>;
      progress['origins'] = {
        for (final entry in tiles.entries)
          if ((entry.value as Map<String, dynamic>)['origin'] != null)
            entry.key: (entry.value as Map<String, dynamic>)['origin'],
      };
      progress['stock'] = {
        for (final entry in stock.entries)
          entry.key: [
            for (final tile in entry.value as List)
              (tile as Map<String, dynamic>)['origin'],
          ],
      };
    }
    run = Campaign.fromJson(snapshot);
    expect(run.tray.values.fold<int>(0, (total, count) => total + count), 11);
    final ids = run.trayTileIds.values.expand((ids) => ids).toSet();
    expect(ids, hasLength(11));
    expect(_reload(run).trayTileIds, run.trayTileIds);
  });

  test('production accrues fractionally and caps a resumed absence', () {
    var run = Campaign(now: _epoch);
    _opening(run);
    expect(run.upgradeDigit(4, ProducerType.rna), isTrue);
    var notifications = 0;
    run.onChanged = () => notifications++;
    run.tick(_epoch.add(const Duration(seconds: 11)));
    expect(run.rna, 2);
    expect(notifications, 0);
    run.tick(_epoch.add(const Duration(seconds: 12)));
    expect(run.rna, 3);
    expect(notifications, 1);
    run = _reload(run);
    final tomorrow = _epoch.add(const Duration(days: 1));
    run.tick(tomorrow, offline: true);
    expect(run.rna, 15);
    run = _reload(run);
    run.tick(tomorrow, offline: true);
    expect(run.rna, 15);
    run.tick(tomorrow.add(const Duration(seconds: 10)));
    expect(run.rna, 16);
  });

  test('starter rewards buy both producers and an idempotent first hatch', () {
    final run = Campaign(now: _epoch);
    _opening(run);
    expect(run.upgradeDigit(4, ProducerType.rna), isTrue);
    expect(run.advance(), isTrue);
    final drive = _Drive(run)..solve();
    expect(run.upgradeDigit(3, ProducerType.dna), isTrue);
    final recipe = CreatureRecipe.starter();
    final quote = run.hatchPrice(recipe.perks.length);
    expect(quote, const HatchPrice(4, 8));
    final hatch = run.hatch('same-command', recipe, quote: quote);
    expect(hatch, isNotNull);
    expect(hatch!.favorite, inInclusiveRange(1, 6));
    expect(_reload(run).hatch('same-command', recipe)?.id, hatch.id);
    expect(run.dna, 0);
    expect(run.creatures, hasLength(2));
    expect(run.housing, 2);
    expect(run.hatch('third-worker', recipe), isNull);
    expect(
      run.requestMaterial('nest', MaterialRole.roof, glyphId: 'nest-roof'),
      isTrue,
    );
    expect(run.requestMaterial('nest', MaterialRole.ring), isTrue);
    expect(run.requestMaterial('nest', MaterialRole.support, count: 2), isTrue);
    drive.run = _reload(run);
    drive.elapse(15);
    expect(drive.run.build('nest'), isTrue);
    expect(drive.run.housing, 3);
    expect(drive.run.build('nest'), isFalse);
  });

  test('all three routes end with the starter alone and keep first clears', () {
    for (final route in ['lines', 'outside', 'positions']) {
      final run = Campaign(now: _epoch);
      _opening(run);
      final drive = _Drive(run)..route(route, buildFirst: route == 'lines');
      expect(drive.run.creatures, hasLength(1));
      expect(drive.run.clearedBoards, hasLength(16));
      expect(drive.run.prestigePayout, 3);
      final dna = drive.run.dna;
      drive.run.retry();
      drive.solve();
      expect(drive.run.dna, dna);
      expect(drive.run.prestigePayout, 3);
    }
  });

  test(
    'retains the founder through quick and tutorial opening after prestige',
    () {
      for (final quick in [true, false]) {
        final run = Campaign(now: _epoch);
        _opening(run);
        final drive = _Drive(run)..route('lines');
        final founder = drive.run.creatures.single;
        expect(drive.run.keepCompanion(founder.id), isTrue);
        expect(
          drive.run.prestige(
            quick: quick,
            charter: Charter.oneHelper,
            upgrades: {LegacyUpgrade.warmStart: 1},
          ),
          isTrue,
        );
        final next = _reload(drive.run);
        expect(next.prestige(), isFalse);
        expect(next.legacy, 1);
        expect(next.archives, hasLength(1));
        expect(next.companion?.id, founder.id);
        if (quick) {
          expect(next.board.id, 'growth-5');
          expect(next.rna, 6);
          expect(next.producers[4]?.rank, 1);
        } else {
          _slide(next);
          for (final cell in [3, 5, 10]) {
            expect(next.placeTutorialToken(cell), isTrue);
          }
          expect(next.createAmoeba(), isTrue);
        }
        expect(identical(next.companion, next.creatures.single), isTrue);
        expect(next.hatch('one-helper', CreatureRecipe.starter()), isNull);
      }
    },
  );

  test('fog jobs survive reload and wrong placements cannot expose cells', () {
    final run = Campaign(now: _epoch);
    _opening(run);
    final drive = _Drive(run);
    while (drive.run.board.id != 'thermometer') {
      expect(drive.run.advance(), isTrue);
      drive.solve();
    }
    expect(drive.run.advance(), isTrue);
    expect(drive.run.visible, isEmpty);
    drive.run.tick(drive.time.add(const Duration(seconds: 1)));
    final trip = drive.run.jobs.single.id;
    drive.run = _reload(drive.run);
    expect(drive.run.jobs.single.id, trip);
    drive.elapse(2);
    final visible = drive.run.visible;
    expect(visible, isNotEmpty);
    expect(visible.length, lessThan(81));
    final cell = visible.firstWhere((index) => drive.run.cells[index] == 0);
    final wrong = drive.run.tray.keys.firstWhere(
      (digit) => digit != drive.run.board.solution[cell],
    );
    expect(drive.run.place(cell, wrong), isFalse);
    expect(drive.run.visible, visible);
    drive.solve();
    expect(drive.run.openBoard('trail'), isTrue);
    drive.solve();
    expect(drive.run.advance(), isTrue);
    drive.solve();
  });

  test(
    'paused library challenge preserves rule setup, run progress and one-time reward',
    () {
      final run = Campaign(now: _epoch);
      _opening(run);
      expect(run.advance(), isTrue);
      final drive = _Drive(run)..solve();
      expect(run.canOpenLibrarySize(6), isTrue);
      expect(run.canOpenLibrarySize(7), isFalse);
      expect(run.openLibraryChallenge(boardsById['growth-7']!), isFalse);
      expect(run.openLibraryChallenge(boardsById['growth-5']!), isTrue);
      expect(run.libraryChallenge, isTrue);
      final dna = run.dna;
      drive.solve();
      expect(run.dna, dna + 3);
      expect(run.returnToCampaign(), isTrue);
      expect(run.board.id, 'growth-5');
      expect(run.cleared, isTrue);
      expect(run.openLibraryChallenge(boardsById['growth-5']!), isTrue);
      expect(run.cleared, isTrue);
      expect(run.dna, dna + 3);
    },
  );

  test('hand orders and no producers remain enforceable in the next run', () {
    for (final charter in [Charter.handOrders, Charter.noProducers]) {
      final run = Campaign(now: _epoch);
      _opening(run);
      final drive = _Drive(run)..route('lines');
      expect(
        drive.run.prestige(
          quick: true,
          charter: charter,
          upgrades: {LegacyUpgrade.warmStart: 1},
        ),
        isTrue,
      );
      drive.solve();
      expect(drive.run.advance(), isTrue);
      drive.solve();
      if (charter == Charter.noProducers) {
        expect(drive.run.producers, isEmpty);
        expect(drive.run.upgradeDigit(4, ProducerType.rna), isFalse);
      } else {
        expect(drive.run.setRestock(7, 2), isFalse);
      }
      drive.route('lines');
      expect(drive.run.prestigePayout, 3);
    }
  });
}
