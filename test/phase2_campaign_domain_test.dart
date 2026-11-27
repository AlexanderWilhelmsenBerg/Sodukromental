import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';

final _epoch = DateTime.utc(2026, 11, 27);

Campaign _reload(Campaign campaign) => Campaign.fromJson(
  jsonDecode(jsonEncode(campaign.toJson())) as Map<String, dynamic>,
);

void _opening(Campaign campaign) {
  for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
    expect(campaign.executeBoardCommand(BoardCommand.slide(from, to)), isTrue);
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

void main() {
  test('board commands, goals, and lesson profile survive a v3 reload', () {
    var campaign = Campaign(now: _epoch);
    expect(campaign.tileSupply, hasLength(9));
    expect(campaign.markLesson('renban'), isTrue);
    expect(campaign.markLesson('renban', practiced: true), isTrue);
    expect(campaign.setPinnedGoal('project:nest'), isTrue);
    campaign = _reload(campaign);
    expect(campaign.seenLessons, contains('renban'));
    expect(campaign.practicedLessons, contains('renban'));
    expect(campaign.pinnedGoal, 'project:nest');
  });

  test('a producer is bounded by its authored batch and cannot replay it', () {
    var campaign = Campaign(now: _epoch);
    _opening(campaign);
    expect(campaign.upgradeDigit(4, ProducerType.rna), isTrue);
    campaign.tick(_epoch.add(const Duration(minutes: 2)), offline: true);
    expect(campaign.rna, 8);
    expect(campaign.productionBatch!.deliveredCycles[4], 6);
    campaign = _reload(campaign);
    campaign.tick(_epoch.add(const Duration(days: 1)), offline: true);
    expect(campaign.rna, 8);
  });

  test(
    'population and the physical shatter ledger persist without duplication',
    () {
      var campaign = Campaign(now: _epoch);
      _opening(campaign);
      var time = _epoch.add(const Duration(seconds: 2));
      while (campaign.board.id != 'growth-9') {
        expect(campaign.advance(), isTrue);
        _solve(campaign, time);
        time = time.add(const Duration(minutes: 15));
      }
      expect(campaign.population.communalResidents, greaterThanOrEqualTo(1));
      expect(campaign.beginShatter(), isTrue);
      expect(campaign.strikeShatterSeam(), isTrue);
      campaign = _reload(campaign);
      expect(campaign.shatter!.openedSeams, 1);
      expect(campaign.advance(), isFalse);
      expect(campaign.breakRemaining(), isTrue);
      expect(campaign.advance(), isTrue);
      expect(campaign.board.id, 'renban');
      final ledger = campaign.shatter!;
      expect(ledger.fragments, hasLength(81));
      expect(ledger.assembled, isTrue);
      final direct = ledger.fragments.values.firstWhere(
        (fragment) => fragment.state == ShatterFragmentState.unsorted,
      );
      final cell = campaign.board.indices.firstWhere(
        (index) =>
            campaign.cells[index] == 0 &&
            campaign.board.solution[index] == direct.digit,
      );
      expect(campaign.placeTile(cell, direct.tileId), isTrue);
      expect(
        campaign.shatter!.fragments[direct.tileId]!.state,
        ShatterFragmentState.placed,
      );
      expect(campaign.undo(), isTrue);
      expect(
        campaign.shatter!.fragments[direct.tileId]!.state,
        ShatterFragmentState.unsorted,
      );
      expect(campaign.sortShatterFragment(direct.tileId), isTrue);
      campaign.retry();
      expect(
        campaign.shatter!.fragments[direct.tileId]!.state,
        ShatterFragmentState.stock,
      );
      final residents = campaign.population.communalResidents;
      campaign = _reload(campaign);
      expect(campaign.shatter!.fragments, hasLength(81));
      expect(campaign.population.communalResidents, residents);
    },
  );

  test('pad delivery preserves one tile and takeover cannot farm Supply', () {
    final campaign = Campaign(now: _epoch);
    _opening(campaign);
    var time = _epoch.add(const Duration(seconds: 2));
    for (var size = 5; size <= 6; size++) {
      expect(campaign.advance(), isTrue);
      _solve(campaign, time);
      time = time.add(const Duration(minutes: 15));
    }
    expect(campaign.acceptOrder(SettlementOrder.supply), isTrue);
    expect(campaign.advance(), isTrue);
    final cell = campaign.board.indices.firstWhere(
      (index) =>
          campaign.cells[index] == 0 &&
          campaign.tray.containsKey(campaign.board.solution[index]),
    );
    final digit = campaign.board.solution[cell];
    final tileId = campaign.trayTileIds[digit]!.first;
    expect(campaign.requestPadDelivery(digit, tileId: tileId), isTrue);
    final reservation = campaign.digitReservations.single;
    expect(reservation.tileId, tileId);
    expect(campaign.takeOverDigitReservation(reservation.id), isTrue);
    expect(campaign.trayTileIds[digit], contains(tileId));
    expect(campaign.placeTile(cell, tileId), isTrue);
    expect(campaign.orderProgress(SettlementOrder.supply).steps, isEmpty);
    expect(campaign.undo(), isTrue);
    expect(campaign.requestPadDelivery(digit, tileId: tileId), isTrue);
    campaign.tick(time.add(const Duration(seconds: 10)), offline: true);
    expect(campaign.placeTile(cell, tileId), isTrue);
    expect(
      campaign.orderProgress(SettlementOrder.supply).steps,
      contains('value-1'),
    );
  });

  test(
    'optional memorial records real recipient and fitters across prestige',
    () {
      var campaign = Campaign(now: _epoch);
      _opening(campaign);
      var time = _epoch.add(const Duration(seconds: 2));
      while (campaign.board.id != 'arrows') {
        expect(campaign.advance(), isTrue);
        _solve(campaign, time);
        time = time.add(const Duration(minutes: 15));
      }
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
      campaign.tick(time.add(const Duration(seconds: 30)), offline: true);
      expect(campaign.build(hall.id), isTrue);
      final route = campaign.availableBoards.firstWhere(
        (board) => board.route == 'lines',
      );
      expect(campaign.openBoard(route.id), isTrue);
      for (var stage = 0; stage < 3; stage++) {
        _solve(campaign, time);
        time = time.add(const Duration(minutes: 15));
        if (stage < 2) expect(campaign.advance(), isTrue);
      }
      expect(campaign.completed, isTrue);
      final recipient = campaign.eligibleMemorialRecipients.first;
      expect(campaign.chooseMemorialRecipient(recipient.id), isTrue);
      final memorial = campaign.projects.firstWhere(
        (project) => project.id == 'memorial',
      );
      for (final requirement in memorial.requirements.entries) {
        expect(
          campaign.requestMaterial(
            memorial.id,
            requirement.key,
            count: requirement.value,
          ),
          isTrue,
        );
      }
      campaign.tick(time.add(const Duration(seconds: 30)), offline: true);
      expect(campaign.build(memorial.id), isTrue);
      expect(campaign.completed, isTrue);
      expect(campaign.memorial!.recipientId, recipient.id);
      expect(campaign.memorial!.fitterIds, isNotEmpty);
      expect(campaign.memorial!.glyphIds, hasLength(4));
      campaign = _reload(campaign);
      expect(campaign.memorial!.recipientName, recipient.name);
      final transactionId = campaign.prestigeQuote().transactionId;
      expect(campaign.prestige(transactionId: transactionId), isTrue);
      expect(campaign.archivedMemorials.single.recipientId, recipient.id);
      expect(campaign.buildings, isNot(contains('memorial')));
    },
  );
}
