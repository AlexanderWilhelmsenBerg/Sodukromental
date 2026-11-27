part of 'campaign.dart';

extension CampaignSocial on Campaign {
  List<CreatureBond> get bonds => List.unmodifiable(_bonds.values);
  List<SocialMoment> get socialMoments => List.unmodifiable(_socialMoments);
  int get socialActiveMs => _socialActiveMs;
  Set<String> get reservedSocialGlyphIds => {
    for (final moment in _socialMoments)
      if (moment.glyphId case final String id) id,
  };

  String _bondKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a\u0000$b' : '$b\u0000$a';

  CreatureBond? bondBetween(String firstId, String secondId) =>
      _bonds[_bondKey(firstId, secondId)];

  CreatureBond _relationship(Creature first, Creature second) =>
      _bonds.putIfAbsent(
        _bondKey(first.id, second.id),
        () => CreatureBond.initial(first, second),
      );

  /// Separates a rival pair without deleting its memory. Any current argument
  /// ends immediately and the score is brought inside the rivalry threshold.
  bool workApart(String firstId, String secondId) {
    final bond = bondBetween(firstId, secondId);
    if (bond == null) return false;
    _socialMoments.removeWhere(
      (moment) => moment.involves(firstId) && moment.involves(secondId),
    );
    if (bond.score < -1) bond.score = -1;
    _changed();
    return true;
  }

  bool returnSocialGlyph(String glyphId) {
    final before = _socialMoments.length;
    _socialMoments.removeWhere((moment) => moment.glyphId == glyphId);
    if (_socialMoments.length == before) return false;
    _changed();
    return true;
  }

  void recordSocialCooperation(String firstId, String secondId) {
    final first = _worker(firstId);
    final second = _worker(secondId);
    if (first == null || second == null || first == second) return;
    _relationship(first, second).recordCooperation();
    _changed();
  }

  bool _advanceSocial(int activeDelta, {required bool visible}) {
    if (!visible || activeDelta <= 0 || antics == Antics.off) return false;
    _socialActiveMs += activeDelta;
    var changed = false;
    final completedHandoffs = _socialMoments.where(
      (moment) =>
          moment.kind == SocialMomentKind.handoff &&
          moment.dueActiveMs <= _socialActiveMs,
    );
    for (final moment in completedHandoffs) {
      final first = _worker(moment.firstId);
      final second = _worker(moment.secondId);
      if (first != null && second != null) {
        _relationship(first, second).recordCooperation();
      }
    }
    final before = _socialMoments.length;
    _socialMoments.removeWhere(
      (moment) => moment.dueActiveMs <= _socialActiveMs,
    );
    changed |= before != _socialMoments.length;

    // Player work always preempts non-work antics.
    final busy = jobs.map((job) => job.workerId).toSet();
    _socialMoments.removeWhere(
      (moment) =>
          moment.kind != SocialMomentKind.handoff &&
          (busy.contains(moment.firstId) || busy.contains(moment.secondId)),
    );
    if (_socialMoments.isNotEmpty ||
        _socialActiveMs - _lastSocialOpportunityAt < 8000) {
      return changed;
    }
    _lastSocialOpportunityAt = _socialActiveMs;

    final residents = [
      for (final creature in _creatures)
        if (!creature.isAmoeba) creature,
    ];
    if (residents.length < 2) return changed;

    // A real same-project job pair gets first refusal on a friendly handoff.
    for (var i = 0; i < jobs.length; i++) {
      for (var j = i + 1; j < jobs.length; j++) {
        final firstJob = jobs[i];
        final secondJob = jobs[j];
        if (firstJob.projectId == null ||
            firstJob.projectId != secondJob.projectId) {
          continue;
        }
        final first = _worker(firstJob.workerId);
        final second = _worker(secondJob.workerId);
        if (first == null || second == null) continue;
        final bond = _relationship(first, second);
        if (!bond.friends) continue;
        if (!_socialHandoffJobs.add(secondJob.id)) continue;
        final remaining = math.max(0, secondJob.dueAt - _clock);
        final relayBonus =
            first.workProfile.has(EcologyChoice.relayLoad.id) ||
            second.workProfile.has(EcologyChoice.relayLoad.id);
        secondJob.dueAt =
            _clock + (remaining * (relayBonus ? .85 : 1.0)).ceil();
        _socialMoments.add(
          _moment(
            first,
            second,
            SocialMomentKind.handoff,
            duration: 1600,
            jobId: secondJob.id,
          ),
        );
        if ([
          ...firstJob.glyphs,
          ...secondJob.glyphs,
        ].any((glyph) => glyph.role == MaterialRole.beam)) {
          _witnessEcology(
            'neighbor-finished-beam',
            participantIds: [first.id, second.id],
          );
        }
        return true;
      }
    }

    final free = residents
        .where((resident) => !busy.contains(resident.id))
        .toList(growable: false);
    if (free.length < 2) return changed;
    final start = (_socialActiveMs ~/ 8000) % free.length;
    final first = free[start];
    final second = free[(start + 1) % free.length];
    final bond = _relationship(first, second);
    final kind = bond.friends
        ? SocialMomentKind.greeting
        : bond.score <= -3 && antics == Antics.full
        ? SocialMomentKind.tussle
        : bond.rivals
        ? SocialMomentKind.argument
        : antics == Antics.full &&
              first.disposition.tidiness < 25 &&
              starterGlyphs.isNotEmpty
        ? SocialMomentKind.returnGlyph
        : SocialMomentKind.standOff;
    if ((kind == SocialMomentKind.argument ||
            kind == SocialMomentKind.tussle) &&
        !bond.recordDispute(_socialActiveMs)) {
      return changed;
    }
    final glyph = kind == SocialMomentKind.returnGlyph
        ? starterGlyphs
              .where(
                (item) =>
                    !_claimedGlyphs.contains(item.id) &&
                    !_materialQueue.any(
                      (request) => request.glyphId == item.id,
                    ),
              )
              .firstOrNull
              ?.id
        : null;
    final resolvedKind = kind == SocialMomentKind.returnGlyph && glyph == null
        ? SocialMomentKind.standOff
        : kind;
    _socialMoments.add(
      _moment(
        first,
        second,
        resolvedKind,
        duration: resolvedKind == SocialMomentKind.returnGlyph ? 4000 : 2000,
        glyphId: glyph,
      ),
    );
    return true;
  }

  SocialMoment _moment(
    Creature first,
    Creature second,
    SocialMomentKind kind, {
    required int duration,
    String? jobId,
    String? glyphId,
  }) => SocialMoment(
    id: 'social:${first.id}:${second.id}:$_socialActiveMs',
    firstId: first.id,
    secondId: second.id,
    kind: kind,
    startedActiveMs: _socialActiveMs,
    dueActiveMs: _socialActiveMs + duration,
    jobId: jobId,
    glyphId: glyphId,
  );
}
