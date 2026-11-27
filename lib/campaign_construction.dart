part of 'campaign.dart';

const _constructionLegMs = 1200;

extension CampaignConstruction on Campaign {
  Map<String, ConstructionProjectWork> get constructionProjects =>
      Map.unmodifiable(_construction);

  ConstructionProjectWork? constructionFor(String projectId) =>
      _construction[projectId];

  List<ColonyJob> get constructionJobs => [
    for (final work in _construction.values)
      if (!work.paused)
        for (final load in work.loads)
          if ((load.stage == ConstructionLoadStage.cutting ||
                  load.stage == ConstructionLoadStage.installing) &&
              load.workerId != null &&
              load.dueAt != null)
            ColonyJob(
              id: 'construction:${load.id}',
              kind: TaskKind.building,
              workerId: load.workerId!,
              dueAt: load.dueAt!,
              request: 'construction:${load.stage.name}',
              projectId: work.projectId,
              glyphs: [load.glyph],
            ),
  ];

  bool startConstruction(String projectId) {
    if (projectId == 'memorial' && _memorialRecipientId == null) return false;
    if (_built.containsKey(projectId) || _construction.containsKey(projectId)) {
      return false;
    }
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null || !_rawMaterialsCover(project)) return false;
    final loads = <ConstructionLoad>[];
    var sequence = 0;
    for (final requirement in project.requirements.entries) {
      final available = projectId == 'practice-site'
          ? _practiceMaterials
                .where((glyph) => glyph.role == requirement.key)
                .toList()
          : _materials.putIfAbsent(requirement.key, () => []);
      for (var count = 0; count < requirement.value; count++) {
        final fromFragment = available.isEmpty;
        final glyph = fromFragment
            ? MaterialGlyph(_id('fragment'), '✧', MaterialRole.support)
            : available.removeAt(0);
        if (projectId == 'practice-site' && !fromFragment) {
          _practiceMaterials.remove(glyph);
        }
        if (fromFragment) _fragments--;
        loads.add(
          ConstructionLoad(
            id: 'load:$projectId:${sequence++}:${glyph.id}',
            glyph: glyph,
            stage: ConstructionLoadStage.reserved,
            fromFragment: fromFragment,
          ),
        );
      }
    }
    final work = ConstructionProjectWork(projectId: projectId, loads: loads);
    _construction[projectId] = work;
    _scheduleNextConstruction(work, _clock);
    _changed();
    return true;
  }

  bool pauseConstruction(String projectId) {
    final work = _construction[projectId];
    if (work == null || work.paused || work.rewardApplied) return false;
    work
      ..paused = true
      ..pausedAt = _clock;
    _changed();
    return true;
  }

  bool resumeConstruction(String projectId) {
    final work = _construction[projectId];
    if (work == null || !work.paused || work.rewardApplied) return false;
    final pausedAt = work.pausedAt ?? _clock;
    final shift = math.max(0, _clock - pausedAt);
    for (final load in work.loads) {
      if (load.dueAt != null) load.dueAt = load.dueAt! + shift;
    }
    work
      ..paused = false
      ..pausedAt = null;
    _scheduleNextConstruction(work, _clock);
    _changed();
    return true;
  }

  /// Cancelling is safe only before a socket is occupied. Exact glyph IDs are
  /// released; consumed shatter fragments return to the fragment balance.
  bool cancelConstruction(String projectId) {
    final work = _construction[projectId];
    if (work == null || work.installedCount > 0 || work.rewardApplied) {
      return false;
    }
    for (final load in work.loads) {
      if (load.fromFragment) {
        _fragments++;
      } else if (projectId == 'practice-site') {
        _practiceMaterials.add(load.glyph);
      } else {
        _materials.putIfAbsent(load.glyph.role, () => []).add(load.glyph);
      }
    }
    _construction.remove(projectId);
    _changed();
    return true;
  }

  bool _rawMaterialsCover(ProjectSpec project) =>
      project.requirements.entries.every(
        (requirement) =>
            (project.id == 'practice-site'
                    ? _practiceMaterials
                          .where((glyph) => glyph.role == requirement.key)
                          .length
                    : (_materials[requirement.key]?.length ?? 0)) +
                (requirement.key == MaterialRole.support
                    ? math.min(1, _fragments)
                    : 0) >=
            requirement.value,
      );

  String? _constructionWorker(String projectId) =>
      _projectWorkers[projectId]?.firstOrNull ??
      _workingCreatures.firstOrNull?.id;

  void _scheduleNextConstruction(ConstructionProjectWork work, int baseTime) {
    if (work.paused || work.rewardApplied) return;
    if (work.loads.any((load) => load.dueAt != null)) return;
    final cut = work.loads
        .where((load) => load.stage == ConstructionLoadStage.cut)
        .firstOrNull;
    final next =
        cut ??
        work.loads
            .where((load) => load.stage == ConstructionLoadStage.reserved)
            .firstOrNull;
    if (next == null) {
      if (work.complete) _finishConstruction(work);
      return;
    }
    next
      ..stage = cut == null
          ? ConstructionLoadStage.cutting
          : ConstructionLoadStage.cut
      ..workerId = cut == null ? _constructionWorker(work.projectId) : null
      ..dueAt = baseTime + _constructionLegMs;
  }

  bool _advanceConstruction(int target) {
    var changed = false;
    for (final work in _construction.values.toList()) {
      if (work.paused || work.rewardApplied) continue;
      while (true) {
        final active = work.loads
            .where((load) => load.dueAt != null && load.dueAt! <= target)
            .firstOrNull;
        if (active == null) break;
        final completedAt = active.dueAt!;
        final previous = active.stage;
        final wasInstalling = previous == ConstructionLoadStage.installing;
        if (wasInstalling && active.workerId != null) {
          final workerId = active.workerId!;
          _projectWorkers
              .putIfAbsent(work.projectId, () => <String>{})
              .add(workerId);
        }
        switch (previous) {
          case ConstructionLoadStage.cutting:
            active
              ..stage = ConstructionLoadStage.cut
              ..workerId = null
              ..dueAt = null;
            _scheduleNextConstruction(work, completedAt);
          case ConstructionLoadStage.cut:
            active
              ..stage = ConstructionLoadStage.installing
              ..workerId = _constructionWorker(work.projectId)
              ..dueAt = completedAt + _constructionLegMs;
          case ConstructionLoadStage.installing:
            active
              ..stage = ConstructionLoadStage.installed
              ..dueAt = null;
            _scheduleNextConstruction(work, completedAt);
          case ConstructionLoadStage.reserved ||
              ConstructionLoadStage.installed:
            active.dueAt = null;
        }
        changed = true;
        if (work.rewardApplied) break;
      }
    }
    return changed;
  }

  void _finishConstruction(ConstructionProjectWork work) {
    if (work.rewardApplied) return;
    work.rewardApplied = true;
    _applyBuiltProject(work.projectId, [
      for (final load in work.loads) load.glyph,
    ]);
    if (work.projectId == 'practice-site') {
      _construction.remove(work.projectId);
    }
  }

  void _applyBuiltProject(String projectId, List<MaterialGlyph> glyphs) {
    if (_built.containsKey(projectId)) return;
    final project = projects.firstWhere((item) => item.id == projectId);
    _built[projectId] = List.unmodifiable(glyphs);
    final participants = _projectWorkers[projectId] ?? const <String>{};
    if ((project.requirements[MaterialRole.roof] ?? 0) > 0) {
      _witnessEcology('roof-raised', participantIds: participants);
    }
    if ((project.requirements[MaterialRole.beam] ?? 0) > 0 &&
        participants.length >= 2) {
      _witnessEcology('neighbor-finished-beam', participantIds: participants);
    }
    if ((project.requirements[MaterialRole.beam] ?? 0) > 0) {
      final workerId = _projectWorkers[projectId]?.firstOrNull;
      if (workerId != null) {
        _recordOrderStep(SettlementOrder.build, 'beam', workerId);
      }
    }
    if (projectId == 'practice-site') _built.remove(projectId);
    if (projectId == 'memorial') {
      final recipient = _worker(_memorialRecipientId!);
      if (recipient != null) {
        _memorial = MemorialRecord(
          runId: runId,
          recipientId: recipient.id,
          recipientName: recipient.name,
          fitterIds: Set.unmodifiable(
            _projectWorkers[projectId] ?? const <String>{},
          ),
          glyphIds: List.unmodifiable(glyphs.map((glyph) => glyph.id)),
        );
      }
    }
    if (projectId == 'meeting-hall') {
      for (final workerId in _hallWorkers) {
        _recordHallContribution(workerId);
      }
      if (campaignBoards.any(
        (item) => item.finale && _cleared.contains(item.id),
      )) {
        _settleProductionBatch();
      }
    }
    if (projectId.startsWith('cosmetic-')) _cosmetics.add(projectId);
  }
}
