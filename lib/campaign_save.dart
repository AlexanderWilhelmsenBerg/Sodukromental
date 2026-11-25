part of 'campaign.dart';

const _saveVersion = 2;

Map<String, dynamic> _saveCampaign(Campaign campaign) => {
  'version': _saveVersion,
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
