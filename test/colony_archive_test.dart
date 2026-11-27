import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/colony_archive.dart';

void main() {
  test(
    'a failed prestige write preserves the current colony and permits one retry',
    () async {
      final initial = Campaign(seed: 51).toJson();
      initial['clears'] = ['lines-finale'];
      initial['buildings'] = {'meeting-hall': []};
      final live = Campaign.fromJson(initial);
      final before = jsonEncode(live.toJson());
      final quote = live.prestigeQuote();
      bool apply(Campaign c) =>
          c.prestige(quick: true, transactionId: quote.transactionId);
      await expectLater(
        saveColonyTransition(
          live,
          apply,
          (_) async => throw StateError('disk full'),
        ),
        throwsStateError,
      );
      expect(jsonEncode(live.toJson()), before);
      Map<String, dynamic>? persisted;
      final next = await saveColonyTransition(live, apply, (v) async {
        persisted = v;
      });
      expect(next!.legacy, quote.payout);
      expect(next.archives, hasLength(1));
      expect(Campaign.fromJson(persisted!).runId, next.runId);
      expect(jsonEncode(live.toJson()), before);
    },
  );
}
