import 'dart:math' as math;

import 'boards.dart';
import 'creatures.dart';

export 'boards.dart';
export 'creatures.dart' show MaterialRole, TaskKind;

part 'campaign_save.dart';

enum GravityDirection { up, right, down, left }

enum ProducerType { rna, dna }

enum Charter { standard, oneHelper, handOrders, noProducers }

enum LegacyUpgrade { shorterRoutes, warmStart, extraNest }

enum SettlementPolicy { independent, sharedReserves, sharedCrews }

enum Antics { full, reactions, off }

enum ReactionKind { curious, collector, tinkerer, puzzled, flock }

class DigitProducer {
  DigitProducer(this.digit, this.type, this.rank, this.nextAt);
  final int digit;
  final ProducerType type;
  final int rank;
  int nextAt;
  int get interval => type == ProducerType.rna ? 10000 : 40000;
}

class _Tile {
  const _Tile(this.id, [this.origin]);
  final String id;
  final String? origin;
}

class DigitOffer {
  DigitOffer._(
    this.id,
    this.digit,
    this._tiles,
    this.workerId,
    this.expiresAt, {
    this.idle = false,
  });
  final String id;
  final int digit;
  final List<_Tile> _tiles;
  int get count => _tiles.length;
  List<String> get tileIds => List.unmodifiable(_tiles.map((tile) => tile.id));
  final String workerId;
  int expiresAt;
  final bool idle;
}

class ColonyJob {
  ColonyJob({
    required this.id,
    required this.kind,
    required this.workerId,
    required this.dueAt,
    required this.request,
    this.digit,
    this.count = 1,
    this.projectId,
    List<MaterialGlyph> glyphs = const [],
    this.reveal,
  }) : glyphs = List.unmodifiable(glyphs);

  final String id;
  final TaskKind kind;
  final String workerId;
  int dueAt;
  final String request;
  final int? digit;
  final int count;
  final String? projectId;
  final List<MaterialGlyph> glyphs;
  final String? reveal;
  List<String> get tileIds => kind == TaskKind.digit
      ? List.generate(count, (index) => 'delivery:$id:$index', growable: false)
      : const [];
}

class ProjectSpec {
  const ProjectSpec(this.id, this.name, this.requirements);
  final String id;
  final String name;
  final Map<MaterialRole, int> requirements;
}

class CreatureReaction {
  const CreatureReaction(
    this.workerId,
    this.index,
    this.digit,
    this.kind,
    this.dueAt,
  );
  final String workerId;
  final int index;
  final int digit;
  final ReactionKind kind;
  final int dueAt;
}

class _Request {
  _Request(
    this.id,
    this.kind, {
    this.digit,
    this.count = 1,
    this.priority = false,
    this.reveal,
    this.project,
    this.role,
    this.glyphId,
    this.initial = false,
    this.automatic = false,
  });
  final String id;
  final TaskKind kind;
  final int? digit;
  int count;
  final bool priority;
  final String? reveal;
  final String? project;
  final MaterialRole? role;
  final String? glyphId;
  final bool initial;
  final bool automatic;
}

class _Undo {
  _Undo(
    this.index,
    this.oldDigit, {
    this.source,
    this.tile,
    this.notes = const {},
  });
  final int index;
  final int oldDigit;
  final int? source;
  final _Tile? tile;
  final Set<int> notes;
}

class _Progress {
  _Progress(this.board)
    : cells = List.of(board.id == 'opening' ? openingTiles : board.givens),
      visible = board.fog == FogKind.none ? board.indices.toSet() : <int>{},
      fixed = board.id == 'opening'
          ? openingAnchors.toSet()
          : {
              for (final index in board.indices)
                if (board.givens[index] > 0) index,
            } {
    for (final index in board.indices) {
      if (cells[index] != 0) tiles[index] = _Tile('${board.id}:cell:$index');
    }
    if (board.id == 'opening') return;
    final missingDigit = board.id.startsWith('growth-') ? board.size : 0;
    for (var digit = 1; digit <= board.size; digit++) {
      if (digit == missingDigit) continue;
      final loose =
          board.size - board.givens.where((value) => value == digit).length;
      final supply = math.max(0, loose - (board.eaten[digit] ?? 0));
      if (supply > 0) {
        stock[digit] = List.generate(
          supply,
          (index) => _Tile('${board.id}:tray:$digit:$index'),
        );
      }
    }
  }

  final BoardSpec board;
  List<int> cells;
  Set<int> visible;
  Set<int> fixed;
  final notes = <int, Set<int>>{};
  final stock = <int, List<_Tile>>{};
  final tiles = <int, _Tile>{};
  final undo = <_Undo>[];
  final tokens = <int>{};
  final jobs = <ColonyJob>[];
  final queue = <_Request>[];
  final offers = <DigitOffer>[];
  final reveals = <String>{};
  final deliveredReveals = <String>{};
  final contributors = <String, TaskKind>{};
  int? pausedAt;
  int? heldSince;
  String? heldOffer;
  int? stashDue;
  int? stashDigit;
  _Tile? stashTile;
  CreatureReaction? reaction;
  bool openingRequested = false;
  bool cleared = false;
  bool fragmentEarned = false;
  int? idleOfferAfter;
  GravityDirection gravity = GravityDirection.down;
}

class Campaign {
  Campaign({this.seed = 1, DateTime? now})
    : _clock = (now ?? DateTime.now()).millisecondsSinceEpoch {
    _current = _load('opening');
  }

  factory Campaign.fromJson(Map<String, dynamic> json) =>
      _restoreCampaign(json);

  void Function()? onChanged;

  int seed;
  int dna = 0;
  int rna = 0;
  int legacy = 0;
  int _runNumber = 1;
  int _serial = 0;
  int _designed = 0;
  int _clock;
  int _fragments = 0;
  int _noticeSequence = 0;
  int get fragments => _fragments;
  String get runId => 'run-$_runNumber-$seed';
  String? _companionChoice;
  String? get companionChoice => _companionChoice;
  String? lastFeedback;
  String? resumeSummary;
  Charter charter = Charter.standard;
  SettlementPolicy policy = SettlementPolicy.independent;
  Antics? _anticsPreference;
  Antics get antics =>
      _anticsPreference ??
      (_cleared.contains('growth-5') ? Antics.full : Antics.reactions);
  final _progress = <String, _Progress>{};
  final _libraryBoards = <String, BoardSpec>{};
  final _cleared = <String>{};
  final _rewards = <String>{};
  final _creatures = <Creature>[];
  final _hatchIds = <String, String>{};
  final _producerMap = <int, DigitProducer>{};
  final _assignments = <String, TaskKind>{};
  final _restock = <int, int>{};
  final _materials = <MaterialRole, List<MaterialGlyph>>{};
  final _materialQueue = <_Request>[];
  final _materialJobs = <ColonyJob>[];
  final _claimedGlyphs = <String>{};
  final _built = <String, List<MaterialGlyph>>{};
  final _legacyUpgrades = <LegacyUpgrade, int>{};
  final _creditedRoutes = <String>{};
  final _creditedCharters = <Charter>{};
  final _learnedRules = <RuleKind>{};
  final _learnedFog = <FogKind>{};
  final _cosmetics = <String>{};
  final _archives = <Map<String, dynamic>>[];
  Creature? _companion;
  String? _returnBoard;
  late _Progress _current;

  BoardSpec get board => _current.board;
  List<int> get cells => List.unmodifiable(_current.cells);
  Set<int> get fixed =>
      Set.unmodifiable(_current.fixed.where(visible.contains));
  Set<int> get visible => Set.unmodifiable(_current.visible);
  Set<int> get anchors => board.id == 'opening'
      ? openingAnchors
      : board.gravity
      ? fixed
      : const {};
  Map<int, Set<int>> get notes => Map.unmodifiable({
    for (final entry in _current.notes.entries)
      entry.key: Set.unmodifiable(entry.value),
  });
  Set<String> get clearedBoards => Set.unmodifiable(_cleared);
  List<Creature> get creatures => List.unmodifiable(_creatures);
  Creature? get companion => _companion;
  Map<String, TaskKind> get assignments => Map.unmodifiable(_assignments);
  Map<int, int> get restock => Map.unmodifiable(_restock);
  Map<int, DigitProducer> get producers => Map.unmodifiable(_producerMap);
  Map<LegacyUpgrade, int> get legacyUpgrades =>
      Map.unmodifiable(_legacyUpgrades);
  List<Map<String, dynamic>> get archives => List.unmodifiable(_archives);
  Set<String> get cosmetics => Set.unmodifiable(_cosmetics);
  Set<RuleKind> get learnedRules => Set.unmodifiable(_learnedRules);
  Set<FogKind> get learnedFog => Set.unmodifiable(_learnedFog);
  Set<RuleKind> get masteredRules => {
    for (final rule in _learnedRules)
      if (_studyCount(rule) >= 2 &&
          campaignBoards.any(
            (board) =>
                _cleared.contains(board.id) &&
                board.rules.any((item) => item.kind == rule) &&
                (board.rules.map((item) => item.kind).toSet().length >= 2 ||
                    board.fog != FogKind.none),
          ))
        rule,
  };
  int _studyCount(RuleKind rule) => campaignBoards
      .where(
        (board) =>
            _cleared.contains(board.id) &&
            board.rules.any((item) => item.kind == rule),
      )
      .length;

  Map<int, int> get tray => Map.unmodifiable({
    for (var digit = 1; digit <= board.size; digit++)
      if (_trayCount(digit) > 0) digit: _trayCount(digit),
  });
  int _trayCount(int digit) =>
      (_current.stock[digit]?.length ?? 0) +
      _current.offers
          .where((offer) => offer.idle && offer.digit == digit)
          .fold<int>(0, (count, offer) => count + offer.count);

  Map<int, String> get cellTileIds => Map.unmodifiable({
    for (final entry in _current.tiles.entries)
      if (_current.visible.contains(entry.key)) entry.key: entry.value.id,
  });

  Map<int, List<String>> get trayTileIds => Map.unmodifiable({
    for (final digit in tray.keys)
      digit: List.unmodifiable([
        ...?_current.stock[digit]?.map((tile) => tile.id),
        for (final offer in _current.offers.where(
          (offer) => offer.idle && offer.digit == digit,
        ))
          ...offer.tileIds,
      ]),
  });

  List<DigitOffer> get offers => List.unmodifiable(_current.offers);
  List<ColonyJob> get jobs =>
      List.unmodifiable([..._current.jobs, ..._materialJobs]);
  CreatureReaction? get reaction => _current.reaction;
  int? get stashedDigit => _current.stashDigit;
  GravityDirection get gravity => _current.gravity;
  bool get cleared => _current.cleared;
  bool get completed =>
      _built.containsKey('meeting-hall') &&
      campaignBoards.any(
        (board) => board.finale && _cleared.contains(board.id),
      );
  bool get sliding =>
      board.id == 'opening' && !cleared && _current.tokens.isEmpty;
  bool get tutorialReady => sliding && _validSlide();
  int get tutorialTokens =>
      board.id == 'opening' ? 3 - _current.tokens.length : 0;
  Set<int> get usedTutorialTokens => Set.unmodifiable(_current.tokens);
  bool get canCreateAmoeba =>
      board.id == 'opening' &&
      !cleared &&
      tutorialTokens == 0 &&
      !_current.openingRequested &&
      (_creatures.any((worker) => worker.isAmoeba) || dna >= 3);
  bool get libraryChallenge => _libraryBoards.containsKey(board.id);
  bool get canUseLibraryChallenge => _cleared.contains('growth-5');
  int get unlockedSize => campaignBoards
      .where(_isAvailable)
      .map((item) => item.size)
      .fold(4, math.max);
  bool canOpenLibrarySize(int size) =>
      canUseLibraryChallenge && size >= 4 && size <= unlockedSize;
  bool get mapUnlocked => _cleared.contains('renban');
  int get producerLimit => _cleared.contains('growth-5')
      ? 2
      : _cleared.contains('opening')
      ? 1
      : 0;
  int get producerRankLimit => _cleared.contains('growth-8')
      ? 3
      : _cleared.contains('growth-6')
      ? 2
      : 1;
  Set<String> get buildings => Set.unmodifiable(_built.keys);
  Map<MaterialRole, int> get materials => Map.unmodifiable({
    for (final item in _materials.entries) item.key: item.value.length,
  });
  Map<String, List<MaterialGlyph>> get buildingGlyphs => Map.unmodifiable({
    for (final item in _built.entries)
      item.key: List<MaterialGlyph>.unmodifiable(item.value),
  });
  Set<String> get claimedGlyphs => Set.unmodifiable(_claimedGlyphs);
  int get housing =>
      2 +
      (_built.containsKey('nest') ? 1 : 0) +
      (_built.containsKey('house') ? 2 : 0) +
      (_cleared.contains('growth-5')
          ? _legacyUpgrades[LegacyUpgrade.extraNest] ?? 0
          : 0);

  GrowthMilestone get growthMilestone {
    if (_cleared.contains('arrows')) return GrowthMilestone.arrows;
    if (_cleared.contains('halo')) return GrowthMilestone.halo;
    if (_cleared.contains('growth-8')) return GrowthMilestone.eight;
    if (_cleared.contains('growth-7')) return GrowthMilestone.seven;
    if (_cleared.contains('growth-6')) return GrowthMilestone.six;
    if (_cleared.contains('growth-5')) return GrowthMilestone.five;
    return GrowthMilestone.opening;
  }

  List<BoardSpec> get availableBoards =>
      campaignBoards.where(_isAvailable).toList();
  static const _sharedCount = 13;

  bool _isAvailable(BoardSpec candidate) {
    final index = campaignBoards.indexOf(candidate);
    if (index == 0) return true;
    if (index < _sharedCount)
      return _cleared.contains(campaignBoards[index - 1].id);
    switch (candidate.id) {
      case 'trail':
        return _cleared.contains('halo');
      case 'linked-torches':
        return _cleared.contains('trail');
    }
    if (candidate.route != null) {
      final stages = campaignBoards
          .where((item) => item.route == candidate.route)
          .toList();
      final stage = stages.indexOf(candidate);
      return stage == 0
          ? _cleared.contains('arrows')
          : _cleared.contains(stages[stage - 1].id);
    }
    if (candidate.expedition) {
      return _built.containsKey('meeting-hall') &&
          candidate.rules.every((rule) => _learnedRules.contains(rule.kind)) &&
          (candidate.fog == FogKind.none ||
              _learnedFog.contains(candidate.fog));
    }
    return false;
  }

  String get objective {
    if (libraryChallenge && cleared)
      return 'Challenge cleared. Return to the campaign when ready.';
    if (completed && cleared)
      return 'Colony complete. Explore other routes or start a new colony.';
    if (cleared && board.id == 'arrows')
      return 'Choose a finale route and construct the Meeting Hall.';
    if (cleared && board.finale)
      return 'Finish the Meeting Hall to record the colony’s ending.';
    if (cleared) return 'Board cleared. Continue when ready.';
    if (sliding && !tutorialReady)
      return 'Slide the loose digits to make four valid spaces for 4.';
    if (board.id == 'opening' && tutorialTokens > 0)
      return 'Place the $tutorialTokens missing 4s from the sentence.';
    if (canCreateAmoeba) return 'Create an amoeba to find the last 4.';
    if (board.id == 'opening')
      return 'Collect the amoeba’s 4 and finish the grid.';
    if (board.fog != FogKind.none && visible.isEmpty)
      return 'Wait for the starter torch to reveal the puzzle.';
    if (_current.queue.any((item) => item.kind == TaskKind.torch) ||
        _current.jobs.any((item) => item.kind == TaskKind.torch))
      return 'Continue solving while a torchbearer reveals the next patch.';
    if (board.id.startsWith('growth-') && demand(board.size) > 0) {
      return 'Request the missing ${board.size}s and solve the grid.';
    }
    if (board.gravity && board.eaten.keys.any((digit) => demand(digit) > 0)) {
      return 'Recover the digits the worm ate and use the marked rules.';
    }
    return 'Use the visible clues to complete the grid.';
  }

  void _changed([String? feedback]) {
    if (feedback != null) lastFeedback = feedback;
    onChanged?.call();
  }

  bool _fails(String feedback) {
    _changed(feedback);
    return false;
  }

  int _nextSerial() => ++_serial;
  String _id(String prefix) => '$prefix-${_nextSerial()}';
  bool _inside(int index) => index >= 0 && index < board.size * board.size;
  bool _knownDigit(int digit) => digit >= 1 && digit <= board.size;
  Creature? _worker(String id) =>
      _creatures.where((worker) => worker.id == id).firstOrNull;
  List<Creature> get _workingCreatures => [
    for (final worker in _creatures)
      if (charter != Charter.oneHelper || worker.isAmoeba) worker,
  ];
  bool _perk(Creature worker, WorkPerk perk) =>
      worker.perks.contains(perk) &&
      growthMilestone.index >= perk.milestone.index;

  _Progress _load(String id) => _progress.putIfAbsent(id, () {
    final definition = _libraryBoards[id] ?? boardsById[id]!;
    final state = _Progress(definition);
    if (definition.id.startsWith('growth-')) {
      final previousId = definition.size == 5
          ? 'opening'
          : 'growth-${definition.size - 1}';
      final previous = _progress[previousId];
      if (previous != null && previous.cleared) _carryForward(previous, state);
    }
    if (definition.id == 'growth-5') {
      state.queue.add(
        _Request(_id('digit'), TaskKind.digit, digit: 5, count: 1),
      );
    }
    if (definition.fog != FogKind.none) {
      state.reveals.add('starter');
      state.queue.add(
        _Request(
          _id('torch'),
          TaskKind.torch,
          priority: true,
          reveal: 'starter',
        ),
      );
    }
    return state;
  });

  void _carryForward(_Progress previous, _Progress next) {
    final oldSize = previous.board.size;
    final nextSize = next.board.size;
    final kept = <int>{};
    next.tiles.clear();
    next.stock.clear();
    for (final index in next.fixed) {
      final row = index ~/ nextSize;
      final column = index % nextSize;
      final old = row * oldSize + column;
      if (row >= oldSize ||
          column >= oldSize ||
          previous.cells[old] != next.cells[index])
        continue;
      next.tiles[index] = _Tile(previous.tiles[old]!.id);
      kept.add(old);
    }
    for (var digit = 1; digit <= oldSize; digit++) {
      final available = [
        for (final entry in previous.tiles.entries)
          if (!kept.contains(entry.key) && previous.cells[entry.key] == digit)
            _Tile(entry.value.id),
        _Tile('${next.board.id}:station:$digit'),
      ];
      for (final index in next.fixed) {
        if (next.cells[index] == digit && !next.tiles.containsKey(index)) {
          next.tiles[index] = available.removeAt(0);
        }
      }
      if (available.isNotEmpty) next.stock[digit] = available;
    }
  }

  bool _validSlide() {
    final full = [for (final digit in _current.cells) digit == 0 ? 4 : digit];
    return board.conflicts(full).isEmpty;
  }

  bool slide(int from, int to) {
    if (!sliding ||
        !_inside(from) ||
        !_inside(to) ||
        openingAnchors.contains(from) ||
        _current.cells[from] == 0 ||
        _current.cells[to] != 0 ||
        !board.adjacent(from).contains(to))
      return false;
    _current
      ..undo.add(_Undo(to, _current.cells[from], source: from))
      ..cells[to] = _current.cells[from]
      ..cells[from] = 0
      ..tiles[to] = _current.tiles.remove(from)!;
    _changed();
    return true;
  }

  bool placeTutorialToken(int index, {int? token}) {
    if (board.id != 'opening' ||
        cleared ||
        tutorialTokens == 0 ||
        !_inside(index) ||
        _current.cells[index] != 0)
      return false;
    token ??= [0, 1, 2].firstWhere((item) => !_current.tokens.contains(item));
    if (token < 0 || token > 2 || _current.tokens.contains(token)) return false;
    if (sliding && !_validSlide())
      return _fails('Keep sliding until every gap can hold a 4.');
    _current
      ..tokens.add(token)
      ..fixed.addAll(
        board.indices.where((position) => _current.cells[position] != 0),
      )
      ..fixed.add(index)
      ..cells[index] = 4
      ..tiles[index] = _Tile('opening:token:$token')
      ..undo.clear();
    if (_rewards.add('opening-token-$token')) dna++;
    _changed();
    return true;
  }

  bool createAmoeba() {
    if (!canCreateAmoeba) return false;
    if (!_creatures.any((worker) => worker.isAmoeba)) {
      dna -= 3;
      _creatures.insert(
        0,
        _companion?.isAmoeba == true ? _companion! : Creature.amoeba(seed),
      );
    }
    _current.openingRequested = true;
    _current.queue.add(
      _Request(
        _id('opening'),
        TaskKind.digit,
        digit: 4,
        priority: true,
        initial: true,
      ),
    );
    _dispatch();
    _changed();
    return true;
  }

  void toggleNote(int index, int digit) {
    if (!_inside(index) ||
        !_knownDigit(digit) ||
        !visible.contains(index) ||
        _current.fixed.contains(index) ||
        _current.cells[index] != 0 ||
        cleared)
      return;
    final set = _current.notes.putIfAbsent(index, () => <int>{});
    if (!set.remove(digit)) set.add(digit);
    if (set.isEmpty) _current.notes.remove(index);
    _changed();
  }

  void _putStock(int digit, Iterable<_Tile> tiles) {
    _current.stock.putIfAbsent(digit, () => []).addAll(tiles);
  }

  bool place(int index, int digit) {
    if (!_validPlacement(index, digit)) return false;
    final stock = _current.stock[digit];
    if (stock != null && stock.isNotEmpty) {
      _place(index, digit, stock.removeAt(0));
      return true;
    }
    final idle = _current.offers
        .where((offer) => offer.idle && offer.digit == digit)
        .firstOrNull;
    return idle != null && claimOffer(idle.id, index);
  }

  bool _validPlacement(int index, int digit) {
    if (!_inside(index) ||
        !_knownDigit(digit) ||
        cleared ||
        _current.fixed.contains(index) ||
        !_current.visible.contains(index) ||
        (board.id == 'opening' && tutorialTokens > 0))
      return false;
    if (_current.cells[index] == digit) return false;
    if (board.fog != FogKind.none && board.solution[index] != digit) {
      return _fails('That digit returns to the tray. The fog stays as it was.');
    }
    return true;
  }

  bool claimOffer(String id, int index) {
    final offer = _current.offers.where((item) => item.id == id).firstOrNull;
    if (offer == null || !_validPlacement(index, offer.digit)) return false;
    final tile = offer._tiles.removeAt(0);
    if (offer.count == 0) {
      _current.offers.remove(offer);
      if (_current.heldOffer == id)
        _current
          ..heldOffer = null
          ..heldSince = null;
    }
    _place(index, offer.digit, _Tile(tile.id, offer.workerId));
    return true;
  }

  void holdOffer(String? id) {
    if (_current.heldOffer == id) return;
    final previous = _current.offers
        .where((item) => item.id == _current.heldOffer)
        .firstOrNull;
    if (previous != null && _current.heldSince != null) {
      previous.expiresAt += _clock - _current.heldSince!;
    }
    final next = _current.offers.any((item) => item.id == id);
    _current
      ..heldOffer = next ? id : null
      ..heldSince = next ? _clock : null;
    _changed();
  }

  void _place(int index, int digit, _Tile tile) {
    final old = _current.cells[index];
    final oldTile = _current.tiles.remove(index);
    final notes = _current.notes.remove(index) ?? <int>{};
    if (oldTile != null) _putStock(old, [oldTile]);
    _current.reaction = null;
    _current.cells[index] = digit;
    _current.tiles[index] = tile;
    if (board.fog != FogKind.none) {
      _current.fixed.add(index);
      _checkReveals();
    } else if (board.id != 'opening') {
      _current.undo.add(_Undo(index, old, tile: oldTile, notes: notes));
      _planReaction(index);
    }
    _checkClear();
    _dispatch();
    _changed();
  }

  bool erase(int index) {
    if (!_inside(index) ||
        cleared ||
        board.id == 'opening' ||
        !_current.visible.contains(index) ||
        _current.fixed.contains(index) ||
        _current.cells[index] == 0)
      return false;
    final digit = _current.cells[index];
    final tile = _current.tiles.remove(index)!;
    _current.undo.add(_Undo(index, digit, tile: tile));
    _putStock(digit, [tile]);
    _current.reaction = null;
    _current.cells[index] = 0;
    _changed();
    return true;
  }

  bool undo() {
    if (cleared || _current.undo.isEmpty || board.fog != FogKind.none)
      return false;
    final move = _current.undo.last;
    if (move.source != null) {
      _current.cells[move.source!] = move.oldDigit;
      _current.cells[move.index] = 0;
      _current.tiles[move.source!] = _current.tiles.remove(move.index)!;
    } else {
      _recallStash();
      final tile =
          move.tile ??
          (move.oldDigit == 0
              ? null
              : _current.stock[move.oldDigit]?.firstOrNull ??
                    _current.offers
                        .where((item) => item.digit == move.oldDigit)
                        .firstOrNull
                        ?._tiles
                        .firstOrNull);
      if (move.oldDigit != 0 &&
          (tile == null || !_withdrawTile(move.oldDigit, tile.id)))
        return false;
      final digit = _current.cells[move.index];
      final placed = _current.tiles.remove(move.index);
      if (placed != null) _putStock(digit, [placed]);
      _current.cells[move.index] = move.oldDigit;
      if (tile != null) _current.tiles[move.index] = tile;
      if (move.notes.isNotEmpty)
        _current.notes[move.index] = move.notes.toSet();
    }
    _current.undo.removeLast();
    _current.reaction = null;
    _changed();
    return true;
  }

  bool _withdrawTile(int digit, String id) {
    final stock = _current.stock[digit];
    final index = stock?.indexWhere((tile) => tile.id == id) ?? -1;
    if (index >= 0) {
      stock!.removeAt(index);
      return true;
    }
    for (final offer
        in _current.offers.where((offer) => offer.digit == digit).toList()) {
      final offered = offer._tiles.indexWhere((tile) => tile.id == id);
      if (offered < 0) continue;
      offer._tiles.removeAt(offered);
      if (offer.count == 0) _releaseOffer(offer);
      return true;
    }
    return false;
  }

  List<int> checkBoard() {
    if (sliding) return [];
    return board.conflicts(_current.cells, visible: _current.visible);
  }

  String? hint({bool explain = false}) {
    if (cleared) return null;
    if (board.id == 'opening' && sliding) {
      if (tutorialReady) return 'Each gap can now hold a 4.';
      return explain
          ? _slideHint()
          : 'Look for a movable digit beside an empty square.';
    }
    if (board.id == 'opening') return objective;
    final conflicts = checkBoard();
    if (conflicts.isNotEmpty) {
      return 'Check ${_cellName(conflicts.first)} for a conflict among the visible clues.';
    }
    final values = [
      for (final index in board.indices)
        _current.visible.contains(index) ? _current.cells[index] : 0,
    ];
    final rules = board.visibleRules(_current.visible);
    for (final index in _current.visible) {
      if (values[index] != 0) continue;
      final choices = board.candidates(values, index, constraints: rules);
      if (choices.length == 1) {
        return explain
            ? 'Only ${choices.single} fits ${_cellName(index)} with its visible peers and rules.'
            : 'Look at ${_cellName(index)}.';
      }
    }
    return board.fog == FogKind.none
        ? 'Compare the remaining candidates in a row, column, or region.'
        : 'Wait for the next torch or revisit the visible clues.';
  }

  String _slideHint() {
    final start = _current.cells;
    final frontier = [(start, -1, -1)];
    final seen = {start.join()};
    for (var at = 0; at < frontier.length; at++) {
      final (grid, firstFrom, firstTo) = frontier[at];
      for (final to in board.indices.where((index) => grid[index] == 0)) {
        for (final from in board.adjacent(to)) {
          if (grid[from] == 0 || openingAnchors.contains(from)) continue;
          final next = List<int>.of(grid)
            ..[to] = grid[from]
            ..[from] = 0;
          if (!seen.add(next.join())) continue;
          final pathFrom = firstFrom < 0 ? from : firstFrom;
          final pathTo = firstTo < 0 ? to : firstTo;
          if (board.conflicts([
            for (final value in next) value == 0 ? 4 : value,
          ]).isEmpty) {
            return 'Slide ${_cellName(pathFrom)} into ${_cellName(pathTo)}.';
          }
          frontier.add((next, pathFrom, pathTo));
        }
      }
    }
    return 'Undo a slide or restart to try another route.';
  }

  String _cellName(int index) =>
      'row ${index ~/ board.size + 1}, column ${index % board.size + 1}';

  bool tilt(GravityDirection direction) {
    if (!board.gravity || _current.gravity == direction) return false;
    _current.gravity = direction;
    _changed();
    return true;
  }

  List<int> get settledDigitOrder => switch (gravity) {
    GravityDirection.up ||
    GravityDirection.left => tray.keys.toList().reversed.toList(),
    GravityDirection.right || GravityDirection.down => tray.keys.toList(),
  };

  Map<String, dynamic> toJson() => _saveCampaign(this);

  int _reservedDigits(int digit) =>
      _current.jobs
          .where((job) => job.kind == TaskKind.digit && job.digit == digit)
          .fold<int>(0, (sum, job) => sum + job.count) +
      _current.offers
          .where((offer) => offer.digit == digit && !offer.idle)
          .fold<int>(0, (sum, offer) => sum + offer.count) +
      (_current.stashDigit == digit ? 1 : 0);

  int demand(int digit) {
    if (!_knownDigit(digit) || cleared) return 0;
    final placed = _current.cells.where((value) => value == digit).length;
    final queued = _current.queue
        .where((request) => request.digit == digit)
        .fold<int>(0, (sum, request) => sum + request.count);
    return math.max(
      0,
      board.size - placed - _trayCount(digit) - _reservedDigits(digit) - queued,
    );
  }

  bool requestDigit(int digit, {int count = 1, bool priority = false}) {
    if (board.id == 'opening' ||
        cleared ||
        count <= 0 ||
        _workingCreatures.isEmpty)
      return false;
    final needed = math.min(count, demand(digit));
    if (needed == 0) return false;
    if (board.gravity && (board.eaten[digit] ?? 0) > 0 && priority) {
      lastFeedback =
          'A worker will recover the requested digit as soon as it is free.';
    }
    for (final worker in _workingCreatures) {
      worker.memory.lastRequest = digit;
    }
    _current.queue.add(
      _Request(
        _id('digit'),
        TaskKind.digit,
        digit: digit,
        count: needed,
        priority: priority,
      ),
    );
    _dispatch();
    _changed();
    return true;
  }

  bool requestTorch(int index) {
    if (!_inside(index) ||
        board.fog == FogKind.none ||
        _current.visible.contains(index))
      return false;
    final requested = _current.queue.any(
      (item) =>
          item.kind == TaskKind.torch && _patch(item.reveal!).contains(index),
    );
    final traveling = _current.jobs.any(
      (item) =>
          item.kind == TaskKind.torch && _patch(item.reveal!).contains(index),
    );
    if (!requested && !traveling)
      return _fails('Solve the visible trigger cells to earn the next torch.');
    _dispatch();
    _changed();
    return true;
  }

  List<int> _patch(String reveal) {
    if (reveal == 'starter') return board.starterPatch;
    return board.reveals.firstWhere((item) => item.id == reveal).patch;
  }

  void _checkReveals() {
    for (final reveal in board.reveals) {
      if (_current.reveals.contains(reveal.id) ||
          !reveal.requires.every(
            (index) =>
                _current.visible.contains(index) &&
                _current.fixed.contains(index) &&
                _current.cells[index] == board.solution[index],
          ))
        continue;
      _current.reveals.add(reveal.id);
      if (reveal.patch.every(_current.visible.contains)) {
        _current.deliveredReveals.add(reveal.id);
        continue;
      }
      _current.queue.add(
        _Request(
          _id('torch'),
          TaskKind.torch,
          priority: true,
          reveal: reveal.id,
        ),
      );
    }
  }

  int _requestScore(_Request request, Creature worker) {
    if (request.kind == TaskKind.torch) return 1000;
    var score = request.priority
        ? 100
        : request.automatic
        ? 0
        : 10;
    if (_assignments[worker.id] == request.kind) score += 5;
    if (policy == SettlementPolicy.sharedCrews &&
        request.kind == TaskKind.building)
      score += 4;
    if (worker.memory.preferredTask == request.kind) score += 2;
    if (request.kind == TaskKind.digit && request.digit == worker.favorite)
      score++;
    return score;
  }

  int _tripMs(Creature worker, _Request request) {
    if (request.initial) return 2000;
    final base = request.kind == TaskKind.torch ? 2000 : 3000;
    var multiplier = 1.0;
    switch (request.kind) {
      case TaskKind.digit:
        multiplier *=
            1 - (_legacyUpgrades[LegacyUpgrade.shorterRoutes] ?? 0) / 10;
        if (_perk(worker, WorkPerk.quickSteps)) multiplier *= 0.75;
        if (board.gravity && _perk(worker, WorkPerk.stableFooting))
          multiplier *= 0.65;
        break;
      case TaskKind.torch:
        if (_perk(worker, WorkPerk.fastTorchTrip)) multiplier *= 0.75;
        break;
      case TaskKind.building:
        if (_perk(worker, WorkPerk.fastBuilder)) multiplier *= 0.8;
        break;
    }
    return (base * math.max(0.5, multiplier)).round();
  }

  int _offerMs(Creature worker) =>
      _perk(worker, WorkPerk.longerOffer) ? 6000 : 4000;

  void _dispatch() {
    if (_current.queue.isEmpty && _materialQueue.isEmpty) return;
    final inUse = jobs.map((job) => job.workerId).toSet();
    for (final worker in _workingCreatures) {
      if (inUse.contains(worker.id)) continue;
      final available = [..._current.queue, ..._materialQueue];
      if (available.isEmpty) break;
      var best = available.first;
      var bestScore = _requestScore(best, worker);
      for (final request in available.skip(1)) {
        final score = _requestScore(request, worker);
        if (score > bestScore) {
          best = request;
          bestScore = score;
        }
      }
      // Give an idle role specialist the first chance, but no assignment may block a job.
      final preferred = _workingCreatures.any(
        (other) =>
            other.id != worker.id &&
            !inUse.contains(other.id) &&
            _assignments[other.id] == best.kind,
      );
      if (preferred && _assignments[worker.id] != best.kind) {
        final backup = available
            .where((item) => item.kind == _assignments[worker.id])
            .firstOrNull;
        if (backup != null && best.kind != TaskKind.torch) {
          best = backup;
        } else {
          continue;
        }
      }
      final idleOffer = _current.offers
          .where((offer) => offer.idle && offer.workerId == worker.id)
          .firstOrNull;
      if (idleOffer != null) _releaseOffer(idleOffer);
      final task = best.kind;
      final count = switch (task) {
        TaskKind.digit => math.min(
          best.count,
          1 +
              (_perk(worker, WorkPerk.extraDigitGrip) ? 1 : 0) +
              (_built.containsKey('workshop') && !best.initial ? 1 : 0),
        ),
        TaskKind.torch => 1,
        TaskKind.building => math.min(
          best.count,
          _perk(worker, WorkPerk.letterCarrier) ? 2 : 1,
        ),
      };
      final glyphs = task == TaskKind.building
          ? [
              for (var i = 0; i < count; i++)
                _reserveGlyph(
                  best.role!,
                  preferredId: i == 0 ? best.glyphId : null,
                ),
            ]
          : <MaterialGlyph>[];
      final job = ColonyJob(
        id: _id('trip'),
        kind: task,
        workerId: worker.id,
        dueAt: _clock + _tripMs(worker, best),
        request: best.id,
        digit: best.digit,
        count: count,
        projectId: best.project,
        glyphs: glyphs,
        reveal: best.reveal,
      );
      if (task == TaskKind.building) {
        _materialJobs.add(job);
      } else {
        _current.jobs.add(job);
      }
      inUse.add(worker.id);
      best.count -= count;
      if (best.count == 0) {
        _current.queue.remove(best);
        _materialQueue.remove(best);
      }
    }
  }

  void _releaseOffer(DigitOffer offer) {
    _current.offers.remove(offer);
    _putStock(offer.digit, offer._tiles);
    _current.idleOfferAfter = _clock + 12000;
    if (_current.heldOffer == offer.id)
      _current
        ..heldOffer = null
        ..heldSince = null;
  }

  void _settle(ColonyJob job, {required bool offline}) {
    _materialJobs.remove(job);
    _current.jobs.remove(job);
    switch (job.kind) {
      case TaskKind.digit:
        final tiles = job.tileIds.map((id) => _Tile(id, job.workerId)).toList();
        if (offline) {
          _putStock(job.digit!, tiles);
        } else {
          final worker = _worker(job.workerId);
          final duration = worker == null ? 4000 : _offerMs(worker);
          _current.offers.add(
            DigitOffer._(
              job.id,
              job.digit!,
              tiles,
              job.workerId,
              _clock + duration,
            ),
          );
        }
        break;
      case TaskKind.torch:
        _current.deliveredReveals.add(job.reveal!);
        _current.visible.addAll(_patch(job.reveal!));
        _current.contributors[job.workerId] = TaskKind.torch;
        _worker(
          job.workerId,
        )?.memory.recordContribution(runId, board.id, TaskKind.torch);
        _checkReveals();
        _checkClear();
        break;
      case TaskKind.building:
        for (final glyph in job.glyphs) {
          _materials.putIfAbsent(glyph.role, () => []).add(glyph);
        }
        _current.contributors[job.workerId] = TaskKind.building;
        _worker(
          job.workerId,
        )?.memory.recordContribution(runId, board.id, TaskKind.building);
        if (job.projectId == 'meeting-hall') {
          _hallWorkers.add(job.workerId);
          if (buildings.contains('meeting-hall'))
            _recordHallContribution(job.workerId);
        }
        break;
    }
  }

  final _hallWorkers = <String>{};

  void _recordHallContribution(String workerId) {
    final worker = _worker(workerId);
    if (worker == null) return;
    for (final stage in campaignBoards.where(
      (board) => board.finale && _cleared.contains(board.id),
    )) {
      worker.memory.recordContribution(runId, stage.id, TaskKind.building);
      worker.memory.recordClear(runId, stage.id);
    }
  }

  void _offerFavorite() {
    if (!_cleared.contains('growth-5') ||
        cleared ||
        libraryChallenge && board.fog != FogKind.none ||
        _current.jobs.isNotEmpty ||
        _materialJobs.isNotEmpty ||
        _current.queue.isNotEmpty ||
        _materialQueue.isNotEmpty ||
        _current.offers.isNotEmpty ||
        _clock < (_current.idleOfferAfter ?? 0))
      return;
    for (final worker in _workingCreatures) {
      final stock = _current.stock[worker.favorite];
      if (stock == null || stock.isEmpty) continue;
      final tile = stock.removeAt(0);
      _current.offers.add(
        DigitOffer._(
          _id('favorite'),
          worker.favorite,
          [tile],
          worker.id,
          _clock + _offerMs(worker),
          idle: true,
        ),
      );
      _current.idleOfferAfter = _clock + 12000;
      if (antics != Antics.off && _current.reaction == null) {
        _current.reaction = CreatureReaction(
          worker.id,
          -1,
          worker.favorite,
          ReactionKind.flock,
          _clock + 1000,
        );
      }
      break;
    }
  }

  void _restockNow() {
    if (charter == Charter.handOrders ||
        !_cleared.contains('growth-6') ||
        cleared ||
        board.id == 'opening')
      return;
    for (final entry in _restock.entries) {
      final digit = entry.key;
      var target = entry.value;
      if (_workingCreatures.any(
        (worker) =>
            worker.favorite == digit && _perk(worker, WorkPerk.favoriteStock),
      ))
        target++;
      final inFlight = _reservedDigits(digit) + _trayCount(digit);
      final alreadyQueued = _current.queue
          .where((item) => item.digit == digit)
          .fold<int>(0, (sum, item) => sum + item.count);
      final count = math.min(target - inFlight - alreadyQueued, demand(digit));
      if (count <= 0) continue;
      _current.queue.add(
        _Request(
          _id('restock'),
          TaskKind.digit,
          digit: digit,
          count: count,
          automatic: true,
        ),
      );
    }
  }

  bool setRestock(int digit, int target) {
    if (charter == Charter.handOrders ||
        !_cleared.contains('growth-6') ||
        digit < 1 ||
        digit > 9 ||
        target < 0 ||
        target > (buildings.contains('storehouse') ? 3 : 2))
      return false;
    final slots = 3 + (policy == SettlementPolicy.sharedReserves ? 2 : 0);
    if (target > 0 && !_restock.containsKey(digit) && _restock.length >= slots)
      return false;
    if (target == 0) {
      _restock.remove(digit);
      _current.queue.removeWhere(
        (item) => item.automatic && item.digit == digit,
      );
    } else {
      _restock[digit] = target;
      _restockNow();
    }
    _dispatch();
    _changed();
    return true;
  }

  bool assign(String workerId, TaskKind? task) {
    if (_worker(workerId) == null ||
        !_cleared.contains('growth-7') ||
        (task == TaskKind.torch && !_cleared.contains('halo')) ||
        (task == TaskKind.building && !_cleared.contains('growth-8')))
      return false;
    if (task == null) {
      _assignments.remove(workerId);
    } else {
      _assignments[workerId] = task;
    }
    _dispatch();
    _changed();
    return true;
  }

  bool setPolicy(SettlementPolicy next) {
    if (!_cleared.contains('arrows') || next == policy) return false;
    policy = next;
    if (next != SettlementPolicy.sharedReserves) {
      final removed = _restock.keys.skip(3).toList();
      _restock.removeWhere((digit, _) => removed.contains(digit));
      _current.queue.removeWhere(
        (item) => item.automatic && removed.contains(item.digit),
      );
    }
    _dispatch();
    _changed();
    return true;
  }

  void tick(DateTime now, {bool offline = false}) {
    final target = now.millisecondsSinceEpoch;
    if (target < _clock) return;
    final serial = _serial;
    final heldChanged = offline && _current.heldOffer != null;
    var trips = 0;
    var producedDna = 0;
    var producedRna = 0;
    if (heldChanged) {
      final held = _current.offers
          .where((item) => item.id == _current.heldOffer)
          .firstOrNull;
      if (held != null)
        held.expiresAt += _clock - (_current.heldSince ?? _clock);
      _current
        ..heldOffer = null
        ..heldSince = null;
    }
    final productiveEnd = offline ? math.min(target, _clock + 120000) : target;
    for (final producer in _producerMap.values) {
      if (producer.nextAt <= productiveEnd && charter != Charter.noProducers) {
        final units =
            (1 + (productiveEnd - producer.nextAt) ~/ producer.interval) *
            producer.rank;
        producer.nextAt += units ~/ producer.rank * producer.interval;
        switch (producer.type) {
          case ProducerType.rna:
            rna += units;
            producedRna += units;
            break;
          case ProducerType.dna:
            dna += units;
            producedDna += units;
            break;
        }
      }
      if (offline) producer.nextAt += target - productiveEnd;
    }
    _dispatch();
    var expired = 0;
    while (true) {
      final dueJobs = jobs.where((job) => job.dueAt <= target).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      final dueOffers =
          _current.offers
              .where(
                (offer) =>
                    offer.expiresAt <= target && _current.heldOffer != offer.id,
              )
              .toList()
            ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      final job = dueJobs.firstOrNull;
      final offer = dueOffers.firstOrNull;
      if (job == null && offer == null) break;
      if (offer != null && (job == null || offer.expiresAt <= job.dueAt)) {
        _clock = math.max(_clock, offer.expiresAt);
        _releaseOffer(offer);
        expired++;
      } else if (job != null) {
        _clock = math.max(_clock, job.dueAt);
        _settle(job, offline: offline);
        trips++;
      }
      _dispatch();
    }
    _clock = target;
    final recalled =
        _current.stashDue != null &&
        _current.stashDue! <= target &&
        _recallStash();
    final acted = _settleReaction();
    if (!offline) {
      _restockNow();
      _dispatch();
      _offerFavorite();
    } else {
      resumeSummary = trips + producedDna + producedRna == 0
          ? null
          : 'While away: $trips trips, +$producedDna DNA, +$producedRna RNA.';
    }
    if (_serial != serial ||
        trips + expired + producedDna + producedRna > 0 ||
        recalled ||
        acted ||
        heldChanged ||
        (offline && target > productiveEnd))
      _changed();
  }

  static const _nest = ProjectSpec('nest', 'Nest', {
    MaterialRole.roof: 1,
    MaterialRole.support: 2,
    MaterialRole.ring: 1,
  });
  static const _house = ProjectSpec('house', 'House', {
    MaterialRole.roof: 1,
    MaterialRole.support: 3,
    MaterialRole.ring: 1,
    MaterialRole.beam: 1,
  });
  static const _storehouse = ProjectSpec('storehouse', 'Storehouse', {
    MaterialRole.roof: 1,
    MaterialRole.support: 2,
    MaterialRole.beam: 2,
  });
  static const _workshop = ProjectSpec('workshop', 'Workshop', {
    MaterialRole.roof: 1,
    MaterialRole.support: 3,
    MaterialRole.beam: 2,
  });
  static const _hall = ProjectSpec('meeting-hall', 'Meeting Hall', {
    MaterialRole.roof: 2,
    MaterialRole.support: 4,
    MaterialRole.beam: 2,
  });

  List<ProjectSpec> get projects => [
    if (_cleared.contains('growth-5')) _nest,
    if (_cleared.contains('growth-7')) ...[_house, _storehouse],
    if (_cleared.contains('growth-8')) _workshop,
    if (_cleared.contains('arrows')) _hall,
    for (final item in campaignBoards.where(
      (board) => board.expedition && _cleared.contains(board.id),
    ))
      ProjectSpec('cosmetic-${item.id}', '${item.title} ornament', {
        MaterialRole.support: 1,
        MaterialRole.ring: 1,
      }),
  ];

  MaterialGlyph _reserveGlyph(MaterialRole role, {String? preferredId}) {
    final available = starterGlyphs.where(
      (item) =>
          item.role == role &&
          !_claimedGlyphs.contains(item.id) &&
          !_materialQueue.any(
            (request) =>
                request.glyphId == item.id && request.glyphId != preferredId,
          ),
    );
    final starter =
        (preferredId == null
            ? null
            : available.where((item) => item.id == preferredId).firstOrNull) ??
        available.firstOrNull;
    final letters = {
      MaterialRole.roof: 'A',
      MaterialRole.support: 'i',
      MaterialRole.ring: 'o',
      MaterialRole.beam: 'H',
    };
    final glyph =
        starter ??
        MaterialGlyph('settlement-${++_noticeSequence}', letters[role]!, role);
    _claimedGlyphs.add(glyph.id);
    return glyph;
  }

  int materialDemand(String projectId, MaterialRole role) {
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null || _built.containsKey(projectId)) return 0;
    final reserved = _materialJobs
        .expand((job) => job.glyphs)
        .where((glyph) => glyph.role == role)
        .length;
    final queued = _materialQueue
        .where((request) => request.role == role)
        .fold<int>(0, (sum, request) => sum + request.count);
    return math.max(
      0,
      (project.requirements[role] ?? 0) -
          (_materials[role]?.length ?? 0) -
          reserved -
          queued -
          (role == MaterialRole.support ? math.min(1, _fragments) : 0),
    );
  }

  bool requestMaterial(
    String projectId,
    MaterialRole role, {
    int count = 1,
    String? glyphId,
  }) {
    if (glyphId != null &&
        (_claimedGlyphs.contains(glyphId) ||
            _materialQueue.any((request) => request.glyphId == glyphId) ||
            !starterGlyphs.any(
              (item) => item.id == glyphId && item.role == role,
            )))
      return false;
    final needed = math.min(count, materialDemand(projectId, role));
    if (needed <= 0 || _workingCreatures.isEmpty) return false;
    _materialQueue.add(
      _Request(
        _id('letter'),
        TaskKind.building,
        project: projectId,
        role: role,
        count: needed,
        glyphId: glyphId,
        priority: projectId == 'meeting-hall',
      ),
    );
    _dispatch();
    _changed();
    return true;
  }

  bool cancelJob(String id) {
    final job = jobs.where((item) => item.id == id).firstOrNull;
    if (job == null || job.kind != TaskKind.building) return false;
    _materialJobs.remove(job);
    _claimedGlyphs.removeAll(job.glyphs.map((glyph) => glyph.id));
    _dispatch();
    _changed();
    return true;
  }

  bool canBuild(String projectId) {
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    if (project == null || _built.containsKey(projectId)) return false;
    return project.requirements.entries.every(
      (item) =>
          (_materials[item.key]?.length ?? 0) +
              (item.key == MaterialRole.support
                  ? math.min(1, _fragments)
                  : 0) >=
          item.value,
    );
  }

  bool build(String projectId) {
    if (!canBuild(projectId)) return false;
    final project = projects.firstWhere((item) => item.id == projectId);
    final glyphs = <MaterialGlyph>[];
    for (final requirement in project.requirements.entries) {
      final available = _materials.putIfAbsent(requirement.key, () => []);
      for (var count = 0; count < requirement.value; count++) {
        if (available.isNotEmpty) {
          glyphs.add(available.removeAt(0));
        } else {
          _fragments--;
          glyphs.add(MaterialGlyph(_id('fragment'), '✧', MaterialRole.support));
        }
      }
    }
    _built[projectId] = glyphs;
    if (projectId == 'meeting-hall') {
      for (final workerId in _hallWorkers) {
        _recordHallContribution(workerId);
      }
    }
    if (projectId.startsWith('cosmetic-')) _cosmetics.add(projectId);
    _changed();
    return true;
  }

  void setAntics(Antics level) {
    _anticsPreference = level;
    _current.reaction = null;
    if (level != Antics.full) _recallStash();
    _changed();
  }

  bool _fixedConflict(int index, int digit) {
    if (!_current.visible.contains(index) || _current.cells[index] != digit)
      return false;
    final evidence = [
      for (final cell in board.indices)
        if (cell == index ||
            (_current.fixed.contains(cell) && _current.visible.contains(cell)))
          _current.cells[cell]
        else
          0,
    ];
    return board.conflicts(evidence, visible: _current.visible).contains(index);
  }

  void _planReaction(int index) {
    if (antics == Antics.off || !_cleared.contains('growth-5')) return;
    final digit = _current.cells[index];
    final workers = _workingCreatures
        .where((worker) => jobs.every((job) => job.workerId != worker.id))
        .toList();
    if (workers.isEmpty) return;
    final conflicts = checkBoard();
    if (!conflicts.contains(index)) {
      final fan = workers
          .where((worker) => worker.favorite == digit)
          .firstOrNull;
      if (fan != null)
        _current.reaction = CreatureReaction(
          fan.id,
          index,
          digit,
          ReactionKind.flock,
          _clock + 1000,
        );
      return;
    }
    final worker = workers.first;
    final fixed = _fixedConflict(index, digit);
    final kind = !fixed
        ? ReactionKind.puzzled
        : antics != Antics.full
        ? ReactionKind.curious
        : ReactionKind.values.byName(worker.personality.name);
    _current.reaction = CreatureReaction(
      worker.id,
      index,
      digit,
      kind,
      _clock + 750,
    );
  }

  bool _settleReaction() {
    final incident = _current.reaction;
    if (incident == null || incident.dueAt > _clock) return false;
    _current.reaction = null;
    if (antics != Antics.full ||
        incident.index < 0 ||
        _current.fixed.contains(incident.index) ||
        !_fixedConflict(incident.index, incident.digit) ||
        jobs.any((job) => job.workerId == incident.workerId))
      return true;
    switch (incident.kind) {
      case ReactionKind.collector:
        if (_current.stashDigit != null) return true;
        _current
          ..stashDigit = incident.digit
          ..stashTile = _current.tiles.remove(incident.index)
          ..stashDue = _clock + 2000
          ..cells[incident.index] = 0;
        lastFeedback =
            'Collector moved the conflicting digit to its shelf. Bring it back whenever you need it.';
        break;
      case ReactionKind.tinkerer:
        if (_current.fragmentEarned || !_rewards.add('fragment-${board.id}'))
          return true;
        _current.fragmentEarned = true;
        _fragments++;
        final tile = _current.tiles.remove(incident.index)!;
        final replacement = _Tile(_id('replacement'), tile.origin);
        for (var index = 0; index < _current.undo.length; index++) {
          final move = _current.undo[index];
          if (move.tile?.id == tile.id) {
            _current.undo[index] = _Undo(
              move.index,
              move.oldDigit,
              source: move.source,
              tile: replacement,
              notes: move.notes,
            );
          }
        }
        _current.cells[incident.index] = 0;
        _putStock(incident.digit, [replacement]);
        lastFeedback =
            'Tinkerer salvaged a fragment and replaced the digit in the tray.';
        break;
      default:
        break;
    }
    return true;
  }

  bool _recallStash() {
    final digit = _current.stashDigit;
    if (digit == null) return false;
    _putStock(digit, [_current.stashTile!]);
    _current
      ..stashDigit = null
      ..stashTile = null
      ..stashDue = null;
    return true;
  }

  bool recallStash() {
    if (!_recallStash()) return false;
    _changed();
    return true;
  }

  HatchPrice producerCost(ProducerType type, int rank) =>
      type == ProducerType.rna
      ? HatchPrice(0, 4 * rank)
      : HatchPrice(rank, 6 * rank);

  bool upgradeDigit(int digit, ProducerType type) {
    if (charter == Charter.noProducers ||
        !_knownDigit(digit) ||
        (type == ProducerType.dna && !_cleared.contains('growth-5')) ||
        !board.indices.any(
          (index) =>
              _current.visible.contains(index) &&
              _current.cells[index] == digit &&
              (cleared || _current.fixed.contains(index)),
        ))
      return false;
    final previous = _producerMap[digit];
    if (previous == null && _producerMap.length >= producerLimit) return false;
    if (previous != null && previous.type != type) return false;
    final rank = (previous?.rank ?? 0) + 1;
    if (rank > producerRankLimit) return false;
    final cost = producerCost(type, rank);
    if (dna < cost.dna || rna < cost.rna) return false;
    dna -= cost.dna;
    rna -= cost.rna;
    _installProducer(digit, type, rank, previous?.nextAt);
    _changed();
    return true;
  }

  void _installProducer(int digit, ProducerType type, int rank, [int? nextAt]) {
    _producerMap[digit] = DigitProducer(
      digit,
      type,
      rank,
      nextAt ?? _clock + (type == ProducerType.rna ? 10000 : 40000),
    );
  }

  HatchPrice hatchPrice(int perkCount) =>
      HatchPrice.quote(_designed + 1, perkCount);

  Creature? hatch(
    String commandId,
    CreatureRecipe recipe, {
    HatchPrice? quote,
  }) {
    final saved = _hatchIds[commandId];
    if (saved != null) return _worker(saved);
    final chosen =
        _companion?.isAmoeba == false && _creatures.contains(_companion)
        ? 1
        : 0;
    if (commandId.isEmpty ||
        !_cleared.contains('growth-5') ||
        charter == Charter.oneHelper ||
        _creatures.length - chosen >= housing ||
        recipe.validate(growthMilestone).isNotEmpty)
      return null;
    final price = hatchPrice(recipe.perks.length);
    if ((quote != null && quote != price) || dna < price.dna || rna < price.rna)
      return null;
    final creature = Creature.generate(
      runSeed: seed,
      sequence: _designed + 1,
      unlockedDigits: unlockedSize,
      recipe: recipe,
    );
    _designed++;
    dna -= price.dna;
    rna -= price.rna;
    _hatchIds[commandId] = creature.id;
    _creatures.add(creature);
    _dispatch();
    _changed();
    return creature;
  }

  bool keepCompanion(String? id) {
    if (id != null && _worker(id) == null && _companion?.id != id) return false;
    _companionChoice = id;
    _changed();
    return true;
  }

  bool encourage(String creatureId) {
    final worker =
        _worker(creatureId) ??
        (_companion?.id == creatureId ? _companion : null);
    if (worker == null || !worker.memory.encourage(runId, board.id))
      return false;
    _changed();
    return true;
  }

  void saveCompanionChanges() => _changed();

  void _checkClear() {
    if (cleared ||
        _current.cells.contains(0) ||
        _current.visible.length != board.size * board.size)
      return;
    if (board.id == 'opening'
        ? board.conflicts(_current.cells).isNotEmpty
        : !board.accepts(_current.cells))
      return;
    _current.cleared = true;
    _current.undo.clear();
    _current.reaction = null;
    _current.queue.removeWhere((request) => request.kind == TaskKind.digit);
    _current.jobs.removeWhere((job) => job.kind == TaskKind.digit);
    for (final offer in List<DigitOffer>.of(_current.offers)) {
      _releaseOffer(offer);
    }
    if (!libraryChallenge) _cleared.add(board.id);
    if (_rewards.add('clear-${board.id}')) {
      final reward = switch (board.id) {
        'opening' => const HatchPrice(0, 6),
        'growth-5' => const HatchPrice(5, 12),
        _ when board.id.startsWith('growth-') => HatchPrice(
          board.size,
          board.size * 2 + 4,
        ),
        _ when board.finale => const HatchPrice(8, 20),
        _ when board.expedition => const HatchPrice(0, 0),
        _ => const HatchPrice(3, 10),
      };
      dna += reward.dna;
      rna += reward.rna;
      if (!libraryChallenge) {
        _learnedRules.addAll(board.rules.map((rule) => rule.kind));
        if (board.fog != FogKind.none) _learnedFog.add(board.fog);
      }
    }
    for (final workerId
        in _current.tiles.values.map((tile) => tile.origin).nonNulls.toSet()) {
      _worker(
        workerId,
      )?.memory.recordContribution(runId, board.id, TaskKind.digit);
    }
    for (final workerId in _current.contributors.keys) {
      final task = _current.contributors[workerId]!;
      _worker(workerId)?.memory.recordContribution(runId, board.id, task);
    }
    for (final worker in _workingCreatures) {
      worker.memory.recordClear(runId, board.id);
    }
    if (board.id == 'opening' &&
        charter != Charter.noProducers &&
        (_legacyUpgrades[LegacyUpgrade.warmStart] ?? 0) > 0 &&
        _producerMap.isEmpty) {
      _installProducer(4, ProducerType.rna, 1);
    }
    final companion = _companion;
    if (board.id == 'growth-5' &&
        companion != null &&
        !companion.isAmoeba &&
        charter != Charter.oneHelper &&
        !_creatures.contains(companion))
      _creatures.add(companion);
    if (board.finale && _built.containsKey('meeting-hall')) {
      for (final workerId in _hallWorkers) {
        _recordHallContribution(workerId);
      }
    }
  }

  bool advance() {
    if (!cleared || libraryChallenge || board.finale || board.expedition)
      return false;
    final index = campaignBoards.indexOf(board);
    if (index >= 0 && index < _sharedCount - 1)
      return openBoard(campaignBoards[index + 1].id);
    if (board.route != null) {
      final stages = campaignBoards
          .where((item) => item.route == board.route)
          .toList();
      final next = stages.indexOf(board) + 1;
      if (next < stages.length) return openBoard(stages[next].id);
    }
    if (board.id == 'trail') return openBoard('linked-torches');
    return false;
  }

  bool openBoard(String id) {
    final candidate = boardsById[id];
    if (candidate == null || !_isAvailable(candidate) || board.id == id)
      return false;
    _returnBoard = null;
    _show(_load(id));
    return true;
  }

  bool openLibraryChallenge(BoardSpec candidate) {
    if (!canOpenLibrarySize(candidate.size) ||
        candidate.id.isEmpty ||
        candidate.id.length > 200 ||
        !candidate.accepts(candidate.solution) ||
        candidate.countSolutions() != 1)
      return false;
    final id = 'library:${candidate.id}';
    if (board.id == id) return true;
    if (!libraryChallenge) _returnBoard = board.id;
    _libraryBoards.putIfAbsent(
      id,
      () => BoardSpec.fromJson({
        ...candidate.toJson(),
        'id': id,
        'route': null,
        'finale': false,
        'expedition': false,
      }),
    );
    _show(_load(id));
    return true;
  }

  bool returnToCampaign() {
    final previous = _returnBoard;
    if (previous == null || !libraryChallenge) return false;
    _returnBoard = null;
    _show(_load(previous));
    return true;
  }

  void _show(_Progress next) {
    _recallStash();
    _current.reaction = null;
    for (final offer in List<DigitOffer>.of(_current.offers)) {
      _releaseOffer(offer);
    }
    _current.pausedAt = _clock;
    _current = next;
    final paused = next.pausedAt;
    if (paused != null) {
      for (final job in next.jobs) {
        job.dueAt += _clock - paused;
        final other = _materialJobs
            .where((active) => active.workerId == job.workerId)
            .firstOrNull;
        if (other != null) job.dueAt += math.max(0, other.dueAt - _clock);
      }
    }
    next.pausedAt = null;
    _restockNow();
    _dispatch();
    _changed();
  }

  void retry() {
    final id = board.id;
    _progress.remove(id);
    _current = _load(id);
    _restockNow();
    _dispatch();
    _changed();
  }

  bool get canPrestige => completed;
  int get prestigePayout => completed
      ? 2 +
            campaignBoards
                .where(
                  (board) =>
                      board.finale &&
                      _cleared.contains(board.id) &&
                      !_creditedRoutes.contains(board.route),
                )
                .length +
            ((charter != Charter.standard &&
                    !_creditedCharters.contains(charter))
                ? 1
                : 0)
      : 0;

  List<int> legacyUpgradeCosts(LegacyUpgrade upgrade) => switch (upgrade) {
    LegacyUpgrade.shorterRoutes => const [2, 3, 4],
    LegacyUpgrade.warmStart => const [2],
    LegacyUpgrade.extraNest => const [3],
  };

  bool prestige({
    bool quick = false,
    Charter charter = Charter.standard,
    String? companionId,
    bool keepSelectedCompanion = true,
    Map<LegacyUpgrade, int> upgrades = const {},
  }) {
    if (!completed) return false;
    final payout = prestigePayout;
    final selected =
        companionId ?? (keepSelectedCompanion ? _companionChoice : null);
    final retained = selected == null
        ? null
        : _worker(selected) ?? (_companion?.id == selected ? _companion : null);
    if (selected != null && retained == null) return false;
    var spent = 0;
    for (final option in upgrades.entries) {
      final current = _legacyUpgrades[option.key] ?? 0;
      final prices = legacyUpgradeCosts(option.key);
      if (option.value < current || option.value > prices.length) return false;
      spent += prices
          .skip(current)
          .take(option.value - current)
          .fold<int>(0, (sum, price) => sum + price);
    }
    if (spent > legacy + payout) return false;
    final routeIds = campaignBoards
        .where((board) => board.finale && _cleared.contains(board.id))
        .map((board) => board.route!)
        .toList();
    _archives.add({
      'id': runId,
      'seed': seed,
      'charter': this.charter.name,
      'routes': routeIds,
      'legacy': payout,
      'creatures': [
        for (final worker in _creatures) {...worker.toJson()}..remove('memory'),
      ],
      'buildings': {
        for (final item in _built.entries)
          item.key: item.value.map(_glyphJson).toList(),
      },
      'clears': _cleared.toList(),
      'companion': retained?.id,
    });
    if (this.charter != Charter.standard) _creditedCharters.add(this.charter);
    _creditedRoutes.addAll(routeIds);
    _legacyUpgrades.addAll(upgrades);
    legacy += payout - spent;
    seed = ((seed * 1664525 + 1013904223 + _runNumber) & 0x7fffffff);
    _runNumber++;
    _serial = 0;
    _noticeSequence = 0;
    _designed = 0;
    _fragments = 0;
    dna = 0;
    rna = 0;
    _progress.clear();
    _libraryBoards.clear();
    _cleared.clear();
    _rewards.clear();
    _creatures.clear();
    _hatchIds.clear();
    _producerMap.clear();
    _assignments.clear();
    _restock.clear();
    _materials.clear();
    _materialQueue.clear();
    _materialJobs.clear();
    _claimedGlyphs.clear();
    _built.clear();
    _hallWorkers.clear();
    _returnBoard = null;
    _companion = retained;
    _companionChoice = retained?.id;
    retained?.memory.retained = true;
    this.charter = charter;
    policy = SettlementPolicy.independent;
    lastFeedback = null;
    resumeSummary = null;
    _current = _load('opening');
    if (quick) {
      _creatures.add(
        retained?.isAmoeba == true ? retained! : Creature.amoeba(seed),
      );
      final opening = _current;
      final carried = <int, List<_Tile>>{};
      for (final entry in opening.tiles.entries) {
        carried
            .putIfAbsent(opening.cells[entry.key], () => [])
            .add(entry.value);
      }
      opening.cells = List.of(board.solution);
      var token = 0;
      for (final index in board.indices) {
        final digit = opening.cells[index];
        opening.tiles[index] = digit == 4
            ? (token < 3
                  ? _Tile('opening:token:${token++}')
                  : _Tile('opening:quick-delivery'))
            : carried[digit]!.removeAt(0);
      }
      opening.fixed.addAll(board.indices);
      opening.tokens.addAll([0, 1, 2]);
      opening.openingRequested = true;
      _rewards.addAll([
        'opening-token-0',
        'opening-token-1',
        'opening-token-2',
      ]);
      _checkClear();
      _current = _load('growth-5');
      _dispatch();
    }
    _changed();
    return true;
  }
}
