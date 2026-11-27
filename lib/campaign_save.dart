part of 'campaign.dart';

const _saveVersion = 3;

Map<String, dynamic> _saveCampaign(Campaign campaign) => {
  'version': _saveVersion,
  'weather': campaign.weather._save(),
  'seed': campaign.seed,
  'run': campaign._runNumber,
  'serial': campaign._serial,
  'designed': campaign._designed,
  'clock': campaign._clock,
  'dna': campaign.dna,
  'rna': campaign.rna,
  'legacy': campaign.legacy,
  'fragments': campaign._fragments,
  'noticeSequence': campaign._noticeSequence,
  'charter': campaign.charter.name,
  'policy': campaign.policy.name,
  'antics': campaign._anticsPreference?.name,
  'active': campaign.board.id,
  'returnBoard': campaign._returnBoard,
  'libraryBoards': campaign._libraryBoards.values
      .map((board) => board.toJson())
      .toList(),
  'progress': {
    for (final item in campaign._progress.entries)
      item.key: _progressJson(item.value),
  },
  'clears': campaign._cleared.toList(),
  'rewards': campaign._rewards.toList(),
  'creatures': campaign._creatures
      .map((creature) => creature.toJson())
      .toList(),
  'hatches': Map.of(campaign._hatchIds),
  'companion': campaign._companion?.toJson(),
  'companionChoice': campaign._companionChoice,
  'bonds': [for (final bond in campaign._bonds.values) bond.toJson()],
  'social': {
    'activeMs': campaign._socialActiveMs,
    'lastOpportunityAt': campaign._lastSocialOpportunityAt,
    'handoffJobs': campaign._socialHandoffJobs.toList(),
    'moments': [for (final moment in campaign._socialMoments) moment.toJson()],
  },
  'producers': [
    for (final item in campaign._producerMap.values)
      {
        'digit': item.digit,
        'type': item.type.name,
        'rank': item.rank,
        'nextAt': item.nextAt,
      },
  ],
  'assignments': {
    for (final item in campaign._assignments.entries) item.key: item.value.name,
  },
  'restock': _numberedMap(campaign._restock),
  'materials': {
    for (final item in campaign._materials.entries)
      item.key.name: item.value.map(_glyphJson).toList(),
  },
  'construction': {
    for (final entry in campaign._construction.entries)
      entry.key: entry.value.toJson(),
  },
  'materialQueue': campaign._materialQueue.map(_requestJson).toList(),
  'materialJobs': campaign._materialJobs.map(_jobJson).toList(),
  'claimedGlyphs': campaign._claimedGlyphs.toList(),
  'buildings': {
    for (final item in campaign._built.entries)
      item.key: item.value.map(_glyphJson).toList(),
  },
  'hallWorkers': campaign._hallWorkers.toList(),
  'legacyUpgrades': {
    for (final item in campaign._legacyUpgrades.entries)
      item.key.name: item.value,
  },
  'creditedRoutes': campaign._creditedRoutes.toList(),
  'creditedCharters': campaign._creditedCharters
      .map((item) => item.name)
      .toList(),
  'learnedRules': campaign._learnedRules.map((item) => item.name).toList(),
  'learnedFog': campaign._learnedFog.map((item) => item.name).toList(),
  'almanacCrews': {
    for (final item in campaign._almanacCrews.entries)
      item.key: Map.of(item.value),
  },
  'cosmetics': campaign._cosmetics.toList(),
  'archives': campaign._archives.toList(),
  'shatter': campaign._shatter == null
      ? null
      : _shatterJson(campaign._shatter!),
  'population': {
    'sequence': campaign._populationSequence,
    'credits': campaign._arrivalCredits,
    'paused': campaign._arrivalsPaused,
    'accountedAt': campaign._populationAccountedAt,
    'remainderMs': campaign._populationRemainderMs,
    'grants': campaign._arrivalGrants.toList(),
    'residents': campaign._communalResidents.toList(),
  },
  'residentAddresses': Map.of(campaign._residentAddresses),
  'pinnedGoal': campaign._pinnedGoal,
  'orders': {
    for (final entry in campaign._orderProgress.entries)
      entry.key.name: {
        'accepted': entry.value.accepted,
        'completed': entry.value.completed,
        'steps': entry.value.steps.toList(),
        'contributors': entry.value.contributors.toList(),
      },
  },
  'presets': [
    for (final preset in campaign._presets.values) _presetJson(preset),
  ],
  'productionBatch': {
    'sequence': campaign._batchSequence,
    'openedBy': campaign._batchOpenedBy,
    'delivered': _numberedMap(campaign._batchDelivered),
    'ranks': _numberedMap(campaign._batchRanks),
    'settled': campaign._settledBatches.toList(),
  },
  'torchCrew': {
    for (final entry in campaign._torchCrew.entries) entry.key: entry.value,
  },
  'seenLessons': campaign._seenLessons.toList(),
  'practicedLessons': campaign._practicedLessons.toList(),
  'directShatterPlacements': campaign._directShatterPlacements.toList(),
  'prestigeTransactions': Map.of(campaign._prestigeTransactions),
  'landmarkWitnesses': [
    for (final witness in campaign._landmarkWitnesses.values)
      _witnessJson(witness),
  ],
  'ceremonySteps': {
    for (final entry in campaign._ceremonySteps.entries)
      entry.key: entry.value.toList(),
  },
  'dedications': Map.of(campaign._dedications),
  'projectWorkers': {
    for (final entry in campaign._projectWorkers.entries)
      entry.key: entry.value.toList(),
  },
  'padReservationTiles': campaign._padReservationTiles.toList(),
  'settledInstallations': campaign._settledInstallations.toList(),
  'practiceMaterials': campaign._practiceMaterials.map(_glyphJson).toList(),
  'memorialRecipient': campaign._memorialRecipientId,
  'memorial': campaign._memorial == null
      ? null
      : _memorialJson(campaign._memorial!),
  'nurtureCommands': Map.of(campaign._nurtureCommands),
  'discoveryCommands': Map.of(campaign._discoveryCommands),
  'lastWorkerTask': {
    for (final entry in campaign._lastWorkerTask.entries)
      entry.key: entry.value.name,
  },
};

Map<String, dynamic> _memorialJson(MemorialRecord record) => {
  'runId': record.runId,
  'recipientId': record.recipientId,
  'recipientName': record.recipientName,
  'fitterIds': record.fitterIds.toList(),
  'glyphIds': record.glyphIds,
};

Map<String, dynamic> _witnessJson(LandmarkWitness witness) => {
  'runId': witness.runId,
  'boardId': witness.boardId,
  'eventId': witness.eventId,
  'workerId': witness.workerId,
  'workerName': witness.workerName,
  'eventKind': witness.eventKind.name,
  'visibleResult': witness.visibleResult,
};

Map<String, dynamic> _shatterJson(ShatterLedger ledger) => {
  'id': ledger.id,
  'source': ledger.sourceBoardId,
  'destination': ledger.destinationBoardId,
  'totalSeams': ledger.totalSeams,
  'openedSeams': ledger.openedSeams,
  'assembled': ledger.assembled,
  'fragments': [
    for (final fragment in ledger.fragments.values)
      {
        'tileId': fragment.tileId,
        'digit': fragment.digit,
        'state': fragment.state.name,
      },
  ],
};

Map<String, dynamic> _presetJson(CrewPreset preset) => {
  'id': preset.id,
  'name': preset.name,
  'assignments': {
    for (final entry in preset.assignments.entries) entry.key: entry.value.name,
  },
  'restock': _numberedMap(preset.restockTargets),
};

Map<String, dynamic> _progressJson(_Progress state) => {
  'cells': state.cells.toList(),
  'visible': state.visible.toList(),
  'fixed': state.fixed.toList(),
  'notes': {
    for (final item in state.notes.entries) '${item.key}': item.value.toList(),
  },
  'stock': {
    for (final item in state.stock.entries)
      '${item.key}': item.value.map(_tileJson).toList(),
  },
  'tiles': {
    for (final item in state.tiles.entries)
      '${item.key}': _tileJson(item.value),
  },
  'undo': [
    for (final item in state.undo)
      {
        'index': item.index,
        'oldDigit': item.oldDigit,
        'source': item.source,
        'tile': item.tile == null ? null : _tileJson(item.tile!),
        'notes': item.notes.toList(),
      },
  ],
  'tokens': state.tokens.toList(),
  'queue': state.queue.map(_requestJson).toList(),
  'jobs': state.jobs.map(_jobJson).toList(),
  'offers': [
    for (final item in state.offers)
      {
        'id': item.id,
        'digit': item.digit,
        'count': item.count,
        'worker': item.workerId,
        'expiresAt': item.expiresAt,
        'idle': item.idle,
        'tiles': item._tiles.map(_tileJson).toList(),
      },
  ],
  'reveals': state.reveals.toList(),
  'deliveredReveals': state.deliveredReveals.toList(),
  'contributors': {
    for (final item in state.contributors.entries) item.key: item.value.name,
  },
  'pausedAt': state.pausedAt,
  'heldOffer': state.heldOffer,
  'heldSince': state.heldSince,
  'stashDue': state.stashDue,
  'stashDigit': state.stashDigit,
  'stashTile': state.stashTile == null ? null : _tileJson(state.stashTile!),
  if (state.reaction case final reaction?)
    'reaction': {
      'worker': reaction.workerId,
      'index': reaction.index,
      'digit': reaction.digit,
      'kind': reaction.kind.name,
      'dueAt': reaction.dueAt,
    },
  'openingRequested': state.openingRequested,
  'cleared': state.cleared,
  'fragmentEarned': state.fragmentEarned,
  'idleOfferAfter': state.idleOfferAfter,
  'gravity': state.gravity.name,
};

Map<String, dynamic> _numberedMap(Map<int, Object?> values) => {
  for (final item in values.entries) '${item.key}': item.value,
};

Map<String, dynamic> _tileJson(_Tile tile) => {
  'id': tile.id,
  'origin': tile.origin,
};

_Tile _tileFrom(Map<String, dynamic> json) =>
    _Tile(json['id'] as String, json['origin'] as String?);

Map<String, dynamic> _glyphJson(MaterialGlyph glyph) => {
  'id': glyph.id,
  'glyph': glyph.glyph,
  'role': glyph.role.name,
  'index': glyph.index,
};

MaterialGlyph _glyphFrom(Map<String, dynamic> json) => MaterialGlyph(
  json['id'] as String,
  json['glyph'] as String,
  MaterialRole.values.byName(json['role'] as String),
  json['index'] as int?,
);

Map<String, dynamic> _requestJson(_Request request) => {
  'id': request.id,
  'kind': request.kind.name,
  'digit': request.digit,
  'count': request.count,
  'priority': request.priority,
  'reveal': request.reveal,
  'project': request.project,
  'role': request.role?.name,
  'glyphId': request.glyphId,
  'initial': request.initial,
  'automatic': request.automatic,
  'tileId': request.tileId,
};

_Request _requestFrom(Map<String, dynamic> json) => _Request(
  json['id'] as String,
  TaskKind.values.byName(json['kind'] as String),
  digit: json['digit'] as int?,
  count: json['count'] as int,
  priority: json['priority'] == true,
  reveal: json['reveal'] as String?,
  project: json['project'] as String?,
  role: MaterialRole.values.asNameMap()[json['role']],
  glyphId: json['glyphId'] as String?,
  initial: json['initial'] == true,
  automatic: json['automatic'] == true,
  tileId: json['tileId'] as String?,
);

Map<String, dynamic> _jobJson(ColonyJob job) => {
  'id': job.id,
  'kind': job.kind.name,
  'worker': job.workerId,
  'dueAt': job.dueAt,
  'request': job.request,
  'digit': job.digit,
  'count': job.count,
  'project': job.projectId,
  'glyphs': job.glyphs.map(_glyphJson).toList(),
  'reveal': job.reveal,
  'tileIds': job._tileIds,
};

ColonyJob _jobFrom(Map<String, dynamic> json) => ColonyJob(
  id: json['id'] as String,
  kind: TaskKind.values.byName(json['kind'] as String),
  workerId: json['worker'] as String,
  dueAt: json['dueAt'] as int,
  request: json['request'] as String,
  digit: json['digit'] as int?,
  count: json['count'] as int,
  projectId: json['project'] as String?,
  glyphs: _maps(json['glyphs']).map(_glyphFrom).toList(),
  reveal: json['reveal'] as String?,
  tileIds: json['tileIds'] == null ? null : _list<String>(json['tileIds']),
);

List<Map<String, dynamic>> _maps(Object? value) =>
    _list<Map<String, dynamic>>(value);
List<T> _list<T>(Object? value) =>
    List<T>.of((value as List? ?? const []).cast<T>());
Map<String, dynamic> _map(Object? value) =>
    value as Map<String, dynamic>? ?? const {};

Campaign _restoreCampaign(Map<String, dynamic> json) {
  if ((json['version'] ?? 0) as int > _saveVersion) {
    throw const FormatException('Unsupported campaign save version');
  }
  final clock = json['clock'] as int? ?? 0;
  final campaign =
      Campaign(
          seed: json['seed'] as int? ?? 1,
          now: DateTime.fromMillisecondsSinceEpoch(clock),
        )
        .._runNumber = json['run'] as int? ?? 1
        .._serial = json['serial'] as int? ?? 0
        .._designed = json['designed'] as int? ?? 0
        ..dna = json['dna'] as int? ?? 0
        ..rna = json['rna'] as int? ?? 0
        ..legacy = json['legacy'] as int? ?? 0
        .._fragments = json['fragments'] as int? ?? 0
        .._noticeSequence = json['noticeSequence'] as int? ?? 0
        ..charter =
            Charter.values.asNameMap()[json['charter']] ?? Charter.standard
        ..policy =
            SettlementPolicy.values.asNameMap()[json['policy']] ??
            SettlementPolicy.independent
        .._anticsPreference = Antics.values.asNameMap()[json['antics']]
        .._returnBoard = json['returnBoard'] as String?
        .._companionChoice = json['companionChoice'] as String?;
  campaign._progress.clear();
  for (final item in _maps(json['libraryBoards'])) {
    final board = BoardSpec.fromJson(item);
    campaign._libraryBoards[board.id] = board;
  }
  for (final item in _map(json['progress']).entries) {
    final board = campaign._libraryBoards[item.key] ?? boardsById[item.key];
    if (board == null) continue;
    campaign._progress[item.key] = _progressFrom(board, _map(item.value));
  }
  final active = json['active'] as String? ?? 'opening';
  campaign._current = campaign._progress[active] ?? campaign._load('opening');
  campaign._cleared.addAll(_list<String>(json['clears']));
  campaign._rewards.addAll(_list<String>(json['rewards']));
  campaign._creatures.addAll(_maps(json['creatures']).map(Creature.fromJson));
  for (final saved in _maps(json['bonds'])) {
    final bond = CreatureBond.fromJson(saved);
    if (campaign._worker(bond.firstId) != null &&
        campaign._worker(bond.secondId) != null) {
      campaign._bonds[campaign._bondKey(bond.firstId, bond.secondId)] = bond;
    }
  }
  final social = _map(json['social']);
  campaign
    .._socialActiveMs = social['activeMs'] as int? ?? 0
    .._lastSocialOpportunityAt = social['lastOpportunityAt'] as int? ?? -8000
    .._socialHandoffJobs.addAll(_list<String>(social['handoffJobs']));
  for (final saved in _maps(social['moments'])) {
    final moment = SocialMoment.fromJson(saved);
    if (campaign._worker(moment.firstId) != null &&
        campaign._worker(moment.secondId) != null &&
        moment.dueActiveMs > campaign._socialActiveMs) {
      campaign._socialMoments.add(moment);
    }
  }
  campaign._hatchIds.addAll(_map(json['hatches']).cast<String, String>());
  if (json['companion'] case final Map<String, dynamic> saved) {
    final creature = Creature.fromJson(saved);
    campaign._companion = campaign._worker(creature.id) ?? creature;
  }
  for (final item in _maps(json['producers'])) {
    final digit = item['digit'] as int;
    campaign._producerMap[digit] = DigitProducer(
      digit,
      ProducerType.values.byName(item['type'] as String),
      item['rank'] as int,
      item['nextAt'] as int,
    );
  }
  for (final item in _map(json['assignments']).entries) {
    campaign._assignments[item.key] = TaskKind.values.byName(
      item.value as String,
    );
  }
  for (final item in _map(json['restock']).entries) {
    campaign._restock[int.parse(item.key)] = item.value as int;
  }
  for (final item in _map(json['materials']).entries) {
    campaign._materials[MaterialRole.values.byName(item.key)] = _maps(
      item.value,
    ).map(_glyphFrom).toList();
  }
  for (final item in _map(json['construction']).entries) {
    final work = ConstructionProjectWork.fromJson(
      Map<String, dynamic>.from(item.value as Map),
    );
    if (work.projectId == item.key) campaign._construction[item.key] = work;
  }
  campaign._materialQueue.addAll(
    _maps(json['materialQueue']).map(_requestFrom),
  );
  campaign._materialJobs.addAll(_maps(json['materialJobs']).map(_jobFrom));
  campaign._claimedGlyphs.addAll(_list<String>(json['claimedGlyphs']));
  for (final item in _map(json['buildings']).entries) {
    campaign._built[item.key] = _maps(item.value).map(_glyphFrom).toList();
  }
  campaign._hallWorkers.addAll(_list<String>(json['hallWorkers']));
  for (final item in _map(json['legacyUpgrades']).entries) {
    campaign._legacyUpgrades[LegacyUpgrade.values.byName(item.key)] =
        item.value as int;
  }
  campaign._creditedRoutes.addAll(_list<String>(json['creditedRoutes']));
  campaign._creditedCharters.addAll(
    _list<String>(json['creditedCharters']).map(Charter.values.byName),
  );
  campaign._learnedRules.addAll(
    _list<String>(json['learnedRules']).map(RuleKind.values.byName),
  );
  campaign._learnedFog.addAll(
    _list<String>(json['learnedFog']).map(FogKind.values.byName),
  );
  campaign._cosmetics.addAll(_list<String>(json['cosmetics']));
  campaign._archives.addAll(_maps(json['archives']));
  if (json['shatter'] case final Map<String, dynamic> saved) {
    final fragments = <String, ShatterFragment>{};
    for (final item in _maps(saved['fragments'])) {
      final fragment = ShatterFragment(
        item['tileId'] as String,
        item['digit'] as int,
        ShatterFragmentState.values.asNameMap()[item['state']] ??
            ShatterFragmentState.locked,
      );
      fragments[fragment.tileId] = fragment;
    }
    campaign._shatter = ShatterLedger(
      id: saved['id'] as String,
      sourceBoardId: saved['source'] as String,
      destinationBoardId: saved['destination'] as String,
      totalSeams: saved['totalSeams'] as int,
      openedSeams: saved['openedSeams'] as int? ?? 0,
      assembled: saved['assembled'] == true,
      fragments: fragments,
    );
  }
  final population = _map(json['population']);
  campaign
    .._populationSequence = population['sequence'] as int? ?? 0
    .._arrivalCredits = population['credits'] as int? ?? 0
    .._arrivalsPaused = population['paused'] == true
    .._populationAccountedAt = population['accountedAt'] as int? ?? 0
    .._populationRemainderMs = population['remainderMs'] as int? ?? 0
    .._arrivalGrants.addAll(_list<String>(population['grants']))
    .._communalResidents.addAll(_list<String>(population['residents']))
    .._pinnedGoal = json['pinnedGoal'] as String?
    .._seenLessons.addAll(_list<String>(json['seenLessons']))
    .._practicedLessons.addAll(_list<String>(json['practicedLessons']))
    .._directShatterPlacements.addAll(
      _list<String>(json['directShatterPlacements']),
    )
    .._prestigeTransactions.addAll(
      _map(json['prestigeTransactions']).cast<String, String>(),
    )
    .._padReservationTiles.addAll(_list<String>(json['padReservationTiles']))
    .._settledInstallations.addAll(_list<String>(json['settledInstallations']))
    .._practiceMaterials.addAll(
      _maps(json['practiceMaterials']).map(_glyphFrom),
    )
    .._memorialRecipientId = json['memorialRecipient'] as String?;
  if (json['memorial'] case final Map<String, dynamic> saved) {
    campaign._memorial = MemorialRecord(
      runId: saved['runId'] as String? ?? campaign.runId,
      recipientId: saved['recipientId'] as String,
      recipientName: saved['recipientName'] as String? ?? '',
      fitterIds: _list<String>(saved['fitterIds']).toSet(),
      glyphIds: _list<String>(saved['glyphIds']),
    );
  }
  campaign
    .._nurtureCommands.addAll(
      _map(json['nurtureCommands']).cast<String, String>(),
    )
    .._discoveryCommands.addAll(
      _map(json['discoveryCommands']).cast<String, String>(),
    );
  for (final entry in _map(json['lastWorkerTask']).entries) {
    final task = TaskKind.values.asNameMap()[entry.value];
    if (task != null) campaign._lastWorkerTask[entry.key] = task;
  }
  for (final entry in _map(json['residentAddresses']).entries) {
    campaign._residentAddresses[entry.key] = entry.value as int;
  }
  for (final entry in _map(json['orders']).entries) {
    final saved = _map(entry.value);
    final ledger =
        _OrderLedger(
            accepted: saved['accepted'] == true,
            completed: saved['completed'] == true,
          )
          ..steps.addAll(_list<String>(saved['steps']))
          ..contributors.addAll(_list<String>(saved['contributors']));
    final order = SettlementOrder.values.asNameMap()[entry.key];
    if (order != null) campaign._orderProgress[order] = ledger;
  }
  for (final saved in _maps(json['presets'])) {
    final assignments = <String, TaskKind>{};
    for (final entry in _map(saved['assignments']).entries) {
      final task = TaskKind.values.asNameMap()[entry.value];
      if (task != null) assignments[entry.key] = task;
    }
    final restock = <int, int>{};
    for (final entry in _map(saved['restock']).entries) {
      restock[int.parse(entry.key)] = entry.value as int;
    }
    final preset = CrewPreset(
      id: saved['id'] as String,
      name: saved['name'] as String,
      assignments: assignments,
      restockTargets: restock,
    );
    campaign._presets[preset.id] = preset;
  }
  final batch = _map(json['productionBatch']);
  campaign
    .._batchSequence = batch['sequence'] as int? ?? 0
    .._batchOpenedBy = batch['openedBy'] as String?
    .._settledBatches.addAll(_list<String>(batch['settled']));
  for (final entry in _map(batch['delivered']).entries) {
    campaign._batchDelivered[int.parse(entry.key)] = entry.value as int;
  }
  for (final entry in _map(batch['ranks']).entries) {
    campaign._batchRanks[int.parse(entry.key)] = entry.value as int;
  }
  for (final entry in _map(json['torchCrew']).entries) {
    campaign._torchCrew[entry.key] = _list<String>(entry.value);
  }
  for (final saved in _maps(json['landmarkWitnesses'])) {
    final witness = LandmarkWitness(
      runId: saved['runId'] as String,
      boardId: saved['boardId'] as String,
      eventId: saved['eventId'] as String,
      workerId: saved['workerId'] as String,
      workerName: saved['workerName'] as String? ?? '',
      eventKind:
          TaskKind.values.asNameMap()[saved['eventKind']] ?? TaskKind.torch,
      visibleResult: saved['visibleResult'] as String? ?? '',
    );
    campaign._landmarkWitnesses['${witness.boardId}:${witness.eventId}'] =
        witness;
  }
  for (final entry in _map(json['ceremonySteps']).entries) {
    campaign._ceremonySteps[entry.key] = _list<String>(entry.value).toSet();
  }
  campaign._dedications.addAll(
    _map(json['dedications']).cast<String, String>(),
  );
  for (final entry in _map(json['projectWorkers']).entries) {
    campaign._projectWorkers[entry.key] = _list<String>(entry.value).toSet();
  }
  for (final item in _map(json['almanacCrews']).entries) {
    campaign._almanacCrews[item.key] = Map.of(
      _map(item.value).cast<String, String>(),
    );
  }
  for (final id in [
    ...campaign._cleared,
    for (final archived in campaign._archives)
      ..._list<String>(archived['clears']),
  ]) {
    if (boardsById.containsKey(id))
      campaign._almanacCrews.putIfAbsent(id, () => {});
  }
  final savedVersion = json['version'] as int? ?? 0;
  if (campaign._cleared.contains('halo') ||
      campaign._archives.any(
        (archive) => _list<String>(archive['clears']).contains('halo'),
      )) {
    campaign._learnedFog.add(FogKind.halo);
  }
  if (savedVersion < 3 && campaign._cleared.contains('growth-6')) {
    campaign._populationAccountedAt = campaign._clock;
    campaign._arrivalCredits = math.min(
      2,
      campaign._cleared
          .where((id) => id != 'opening' && id != 'growth-5')
          .length,
    );
    campaign._spendArrivalCredits();
    if (campaign._batchOpenedBy == null &&
        campaign.charter != Charter.noProducers) {
      campaign._batchSequence = 1;
      campaign._batchOpenedBy = campaign._cleared.lastOrNull ?? 'migration';
      for (final entry in campaign._producerMap.entries) {
        campaign._batchRanks[entry.key] = entry.value.rank;
      }
    }
  }
  campaign.weather._restore(_map(json['weather']));
  return campaign;
}

_Progress _progressFrom(BoardSpec board, Map<String, dynamic> json) {
  final cells = _list<int>(json['cells']);
  if (cells.length != board.size * board.size ||
      cells.any((digit) => digit < 0 || digit > board.size)) {
    throw FormatException('Invalid saved grid for ${board.id}');
  }
  final state = _Progress(board)
    ..cells = cells
    ..visible = _list<int>(json['visible']).toSet()
    ..fixed = _list<int>(json['fixed']).toSet()
    ..pausedAt = json['pausedAt'] as int?
    ..heldOffer = json['heldOffer'] as String?
    ..heldSince = json['heldSince'] as int?
    ..stashDue = json['stashDue'] as int?
    ..stashDigit = json['stashDigit'] as int?
    ..stashTile = _savedStash(board, json)
    ..openingRequested = json['openingRequested'] == true
    ..cleared = json['cleared'] == true
    ..fragmentEarned = json['fragmentEarned'] == true
    ..idleOfferAfter = json['idleOfferAfter'] as int?
    ..gravity =
        GravityDirection.values.asNameMap()[json['gravity']] ??
        GravityDirection.down;
  for (final item in _map(json['notes']).entries) {
    state.notes[int.parse(item.key)] = _list<int>(item.value).toSet();
  }
  state.stock.clear();
  for (final item in _map(json['stock']).entries) {
    final saved = _list<dynamic>(item.value);
    state.stock[int.parse(item.key)] = [
      for (final (index, value) in saved.indexed)
        value is Map<String, dynamic>
            ? _tileFrom(value)
            : _Tile(
                '${board.id}:old-stock:${item.key}:$index',
                value as String?,
              ),
    ];
  }
  state.tiles.clear();
  final savedTiles = _map(json['tiles']);
  final oldOrigins = _map(json['origins']);
  for (final (index, digit) in cells.indexed) {
    if (digit == 0) continue;
    final saved = savedTiles['$index'];
    state.tiles[index] = saved == null
        ? _Tile('${board.id}:old-cell:$index', oldOrigins['$index'] as String?)
        : _tileFrom(_map(saved));
  }
  for (final item in _maps(json['undo'])) {
    final tile = item['tile'];
    state.undo.add(
      _Undo(
        item['index'] as int,
        item['oldDigit'] as int,
        source: item['source'] as int?,
        tile: tile == null ? null : _tileFrom(_map(tile)),
        notes: _list<int>(item['notes']).toSet(),
      ),
    );
  }
  state.tokens.addAll(_list<int>(json['tokens']));
  state.queue.addAll(_maps(json['queue']).map(_requestFrom));
  state.jobs.addAll(_maps(json['jobs']).map(_jobFrom));
  for (final item in _maps(json['offers'])) {
    state.offers.add(
      DigitOffer._(
        item['id'] as String,
        item['digit'] as int,
        item['tiles'] != null
            ? _maps(item['tiles']).map(_tileFrom).toList()
            : List.generate(
                item['count'] as int,
                (index) => _Tile(
                  '${board.id}:old-offer:${item['id']}:$index',
                  item['idle'] == true
                      ? item['origin'] as String?
                      : item['worker'] as String?,
                ),
              ),
        item['worker'] as String,
        item['expiresAt'] as int,
        idle: item['idle'] == true,
      ),
    );
  }
  state.reveals.addAll(_list<String>(json['reveals']));
  state.deliveredReveals.addAll(_list<String>(json['deliveredReveals']));
  for (final item in _map(json['contributors']).entries) {
    state.contributors[item.key] = TaskKind.values.byName(item.value as String);
  }
  if (json['reaction'] case final Map<String, dynamic> saved) {
    state.reaction = CreatureReaction(
      saved['worker'] as String,
      saved['index'] as int,
      saved['digit'] as int,
      ReactionKind.values.byName(saved['kind'] as String),
      saved['dueAt'] as int,
    );
  }
  return state;
}

_Tile? _savedStash(BoardSpec board, Map<String, dynamic> json) {
  if (json['stashTile'] case final Map<String, dynamic> saved)
    return _tileFrom(saved);
  if (json['stashDigit'] == null) return null;
  return _Tile('${board.id}:old-stash', json['stashOrigin'] as String?);
}
