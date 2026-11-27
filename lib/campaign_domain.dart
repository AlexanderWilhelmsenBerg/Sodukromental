part of 'campaign.dart';

enum BoardCommandKind { slide, place, placeTile, erase, undo, tilt }

class BoardCommand {
  const BoardCommand._(
    this.kind, {
    this.from,
    this.to,
    this.digit,
    this.tileId,
    this.direction,
  });
  const BoardCommand.slide(int from, int to)
    : this._(BoardCommandKind.slide, from: from, to: to);
  const BoardCommand.place(int cell, int digit)
    : this._(BoardCommandKind.place, to: cell, digit: digit);
  const BoardCommand.placeTile(int cell, String tileId)
    : this._(BoardCommandKind.placeTile, to: cell, tileId: tileId);
  const BoardCommand.erase(int cell) : this._(BoardCommandKind.erase, to: cell);
  const BoardCommand.undo() : this._(BoardCommandKind.undo);
  const BoardCommand.tilt(GravityDirection direction)
    : this._(BoardCommandKind.tilt, direction: direction);
  final BoardCommandKind kind;
  final int? from;
  final int? to;
  final int? digit;
  final String? tileId;
  final GravityDirection? direction;
}

class TileSupplySlot {
  const TileSupplySlot(this.digit, this.tileIds, {required this.enabled});
  final int digit;
  final List<String> tileIds;
  final bool enabled;
  int get available => tileIds.length;
}

enum DigitReservationPhase { queued, traveling, offered }

class DigitReservation {
  const DigitReservation({
    required this.id,
    required this.digit,
    required this.tileId,
    required this.workerId,
    required this.phase,
  });
  final String id;
  final int digit;
  final String tileId;
  final String? workerId;
  final DigitReservationPhase phase;
}

enum ShatterFragmentState {
  locked,
  unsorted,
  stock,
  placed,
  captured,
  inTransit,
}

class ShatterFragment {
  const ShatterFragment(this.tileId, this.digit, this.state);
  final String tileId;
  final int digit;
  final ShatterFragmentState state;
}

class ShatterLedger {
  ShatterLedger({
    required this.id,
    required this.sourceBoardId,
    required this.destinationBoardId,
    required this.totalSeams,
    this.openedSeams = 0,
    this.assembled = false,
    Map<String, ShatterFragment> fragments = const {},
  }) : fragments = Map.of(fragments);
  final String id;
  final String sourceBoardId;
  final String destinationBoardId;
  final int totalSeams;
  int openedSeams;
  bool assembled;
  final Map<String, ShatterFragment> fragments;
  int get remainingSeams => math.max(0, totalSeams - openedSeams);
  int get unsortedCount => fragments.values
      .where((f) => f.state == ShatterFragmentState.unsorted)
      .length;
  bool get canStrike => remainingSeams > 0;
  bool get canSort => assembled && unsortedCount > 0;
}

class FogStaffing {
  const FogStaffing({
    required this.required,
    required this.available,
    required this.assignedWorkerIds,
    required this.busyWorkerIds,
    required this.sequential,
  });
  final int required;
  final int available;
  final List<String> assignedWorkerIds;
  final List<String> busyWorkerIds;
  final bool sequential;
  int get shortfall => math.max(0, required - assignedWorkerIds.length);
  bool get ready => shortfall == 0;
}

class PopulationState {
  const PopulationState({
    required this.personalBeds,
    required this.communalCapacity,
    required this.communalResidents,
    required this.arrivalCredits,
    required this.arrivalsPaused,
    required this.postLimit,
  });
  final int personalBeds;
  final int communalCapacity;
  final int communalResidents;
  final int arrivalCredits;
  final bool arrivalsPaused;
  final int postLimit;
  int get communalVacancies =>
      math.max(0, communalCapacity - communalResidents);
  bool get canWelcome => arrivalCredits > 0 && communalVacancies > 0;
}

class ProjectProgress {
  const ProjectProgress({
    required this.projectId,
    required this.name,
    required this.requirements,
    required this.installed,
    required this.reserved,
    required this.inTransit,
    required this.complete,
    this.cutStock = const {},
    this.started = false,
    this.paused = false,
  });
  final String projectId;
  final String name;
  final Map<MaterialRole, int> requirements;
  final Map<MaterialRole, int> installed;
  final Map<MaterialRole, int> reserved;
  final Map<MaterialRole, int> inTransit;
  final bool complete;
  final Map<MaterialRole, int> cutStock;
  final bool started;
  final bool paused;
}

enum SettlementOrder { supply, build, lanterns }

class SettlementOrderProgress {
  const SettlementOrderProgress({
    required this.order,
    required this.accepted,
    required this.completed,
    required this.steps,
    required this.requiredSteps,
    required this.contributorIds,
    required this.rewardPresetId,
  });
  final SettlementOrder order;
  final bool accepted;
  final bool completed;
  final Set<String> steps;
  final Set<String> requiredSteps;
  final Set<String> contributorIds;
  final String rewardPresetId;
  double get fraction => requiredSteps.isEmpty
      ? 1
      : steps.intersection(requiredSteps).length / requiredSteps.length;
}

class _OrderLedger {
  _OrderLedger({this.accepted = false, this.completed = false});
  bool accepted;
  bool completed;
  final steps = <String>{};
  final contributors = <String>{};
}

class CrewPreset {
  CrewPreset({
    required this.id,
    required this.name,
    Map<String, TaskKind> assignments = const {},
    Map<int, int> restockTargets = const {},
  }) : assignments = Map.unmodifiable(assignments),
       restockTargets = Map.unmodifiable(restockTargets);
  final String id;
  final String name;
  final Map<String, TaskKind> assignments;
  final Map<int, int> restockTargets;
}

class ProductionBatchState {
  const ProductionBatchState({
    required this.id,
    required this.openedBy,
    required this.deliveredCycles,
    required this.cycleCaps,
    required this.commissionedRanks,
    required this.settled,
  });
  final String id;
  final String openedBy;
  final Map<int, int> deliveredCycles;
  final Map<int, int> cycleCaps;
  final Map<int, int> commissionedRanks;
  final bool settled;
}

class LandmarkWitness {
  const LandmarkWitness({
    required this.runId,
    required this.boardId,
    required this.eventId,
    required this.workerId,
    required this.workerName,
    required this.eventKind,
    required this.visibleResult,
  });
  final String runId;
  final String boardId;
  final String eventId;
  final String workerId;
  final String workerName;
  final TaskKind eventKind;
  final String visibleResult;
}

class DeductionStep {
  const DeductionStep(this.id, this.summary);
  final String id;
  final String summary;
}

class FinaleCeremony {
  const FinaleCeremony({
    required this.routeId,
    required this.steps,
    required this.signedStepIds,
    required this.dedication,
    required this.ready,
  });
  final String routeId;
  final List<DeductionStep> steps;
  final Set<String> signedStepIds;
  final String? dedication;
  final bool ready;
  bool get deductionComplete =>
      steps.every((step) => signedStepIds.contains(step.id));
  bool get complete => ready && deductionComplete && dedication != null;
}

class ExpeditionState {
  const ExpeditionState({
    required this.boardId,
    required this.available,
    required this.patternEarned,
    required this.ornamentInstalled,
    required this.installerIds,
    required this.familiarExample,
  });
  final String boardId;
  final bool available;
  final bool patternEarned;
  final bool ornamentInstalled;
  final Set<String> installerIds;
  final bool familiarExample;
}

class MemorialRecord {
  const MemorialRecord({
    required this.runId,
    required this.recipientId,
    required this.recipientName,
    required this.fitterIds,
    required this.glyphIds,
  });
  final String runId;
  final String recipientId;
  final String recipientName;
  final Set<String> fitterIds;
  final List<String> glyphIds;
}

class PrestigeQuote {
  const PrestigeQuote({
    required this.transactionId,
    required this.runId,
    required this.payout,
    required this.startingLegacy,
    required this.purchaseCost,
    required this.endingLegacy,
    required this.resetDna,
    required this.resetRna,
    required this.routes,
    required this.charterCredit,
  });
  final String transactionId;
  final String runId;
  final int payout;
  final int startingLegacy;
  final int purchaseCost;
  final int endingLegacy;
  final int resetDna;
  final int resetRna;
  final Set<String> routes;
  final bool charterCredit;
}

extension CampaignDomain on Campaign {
  bool nurture(
    String commandId,
    String creatureId,
    EcologyChoice choice, {
    HatchPrice quote = HatchPrice.nurture,
  }) {
    final receipt = '$creatureId:${choice.id}';
    if (_nurtureCommands[commandId] case final String saved) {
      return saved == receipt;
    }
    final creature = _worker(creatureId);
    if (commandId.isEmpty ||
        creature == null ||
        quote != HatchPrice.nurture ||
        dna < quote.dna ||
        rna < quote.rna ||
        !creature.canNurture(choice, growthMilestone))
      return false;
    if (!creature.nurture(choice, growthMilestone)) return false;
    dna -= quote.dna;
    rna -= quote.rna;
    _nurtureCommands[commandId] = receipt;
    _changed('${creature.name} expressed ${choice.label}.');
    return true;
  }

  bool discoverCreature(String commandId, String creatureId, String secretId) {
    final receipt = '$creatureId:$secretId';
    if (_discoveryCommands[commandId] case final String saved) {
      return saved == receipt;
    }
    final creature = _worker(creatureId);
    final path = creature?.recipe.ecologyPath;
    if (commandId.isEmpty ||
        creature == null ||
        path == null ||
        path.secretId != null)
      return false;
    final discovered = path.discover(secretId);
    if (discovered.secretId != secretId) return false;
    creature.recipe = creature.recipe.withEcologyPath(discovered);
    creature.appearance = CreatureAppearance(
      palette: creature.appearance.palette,
      marking: creature.appearance.marking,
      eyeCount: creature.appearance.eyeCount,
      cheeks: creature.appearance.cheeks,
      parts: {...creature.appearance.parts, ...discovered.projectedParts},
    );
    _discoveryCommands[commandId] = receipt;
    _changed(
      '${creature.name} discovered ${ecologySecretById(secretId)?.label ?? secretId}.',
    );
    return true;
  }

  void _witnessEcology(String eventId, {Iterable<String>? participantIds}) {
    final allowed = participantIds?.toSet();
    var changed = false;
    for (final creature in _creatures) {
      if (allowed != null && !allowed.contains(creature.id)) continue;
      final path = creature.recipe.ecologyPath;
      if (path == null || path.witnessedEvents.contains(eventId)) continue;
      creature.recipe = creature.recipe.withEcologyPath(path.witness(eventId));
      changed = true;
    }
    if (changed) _changed();
  }

  bool executeBoardCommand(BoardCommand command) => switch (command.kind) {
    BoardCommandKind.slide => slide(command.from!, command.to!),
    BoardCommandKind.place => place(command.to!, command.digit!),
    BoardCommandKind.placeTile => placeTile(command.to!, command.tileId!),
    BoardCommandKind.erase => erase(command.to!),
    BoardCommandKind.undo => undo(),
    BoardCommandKind.tilt => tilt(command.direction!),
  };

  List<TileSupplySlot> get tileSupply => List.unmodifiable([
    for (var digit = 1; digit <= 9; digit++)
      TileSupplySlot(
        digit,
        List.unmodifiable(
          (trayTileIds[digit] ?? const <String>[]).where(
            (id) =>
                _shatter?.fragments[id]?.state != ShatterFragmentState.unsorted,
          ),
        ),
        enabled: digit <= board.size,
      ),
  ]);

  ShatterLedger? get shatter => _shatter;
  Map<String, int> get residentAddresses =>
      Map.unmodifiable(_residentAddresses);
  String? get pinnedGoal => _pinnedGoal;
  Map<String, CrewPreset> get presets => Map.unmodifiable(_presets);
  Set<String> get seenLessons => Set.unmodifiable(_seenLessons);
  Set<String> get practicedLessons => Set.unmodifiable(_practicedLessons);
  int get personalBedOccupancy => _creatures
      .where(
        (worker) =>
            !_communalResidents.contains(worker.id) &&
            !(_companion?.id == worker.id && !worker.isAmoeba),
      )
      .length;
  int get personalBedsAvailable => math.max(0, housing - personalBedOccupancy);
  bool get hasEverClearedHalo =>
      _learnedFog.contains(FogKind.halo) ||
      _cleared.contains('halo') ||
      _archives.any(
        (archive) => _list<String>(archive['clears']).contains('halo'),
      );
  MemorialRecord? get memorial => _memorial;
  List<MemorialRecord> get archivedMemorials => List.unmodifiable([
    for (final archive in _archives)
      if (archive['memorial'] case final Map<String, dynamic> saved)
        MemorialRecord(
          runId: saved['runId'] as String? ?? archive['id'] as String,
          recipientId: saved['recipientId'] as String,
          recipientName: saved['recipientName'] as String? ?? '',
          fitterIds: Set.unmodifiable(_list<String>(saved['fitterIds'])),
          glyphIds: List.unmodifiable(_list<String>(saved['glyphIds'])),
        ),
  ]);

  List<Creature> get eligibleMemorialRecipients {
    final contributors = <String>{..._hallWorkers};
    for (final boardId in _cleared) {
      contributors.addAll(_almanacCrews[boardId]?.keys ?? const <String>{});
    }
    return List.unmodifiable(
      _creatures.where((worker) => contributors.contains(worker.id)),
    );
  }

  bool chooseMemorialRecipient(String workerId) {
    if (!_built.containsKey('meeting-hall') ||
        _memorial != null ||
        !eligibleMemorialRecipients.any((worker) => worker.id == workerId))
      return false;
    if (_memorialRecipientId == workerId) return false;
    _memorialRecipientId = workerId;
    _changed();
    return true;
  }

  List<DigitReservation> get digitReservations => List.unmodifiable([
    for (final request in _current.queue)
      if (request.kind == TaskKind.digit && request.tileId != null)
        DigitReservation(
          id: request.id,
          digit: request.digit!,
          tileId: request.tileId!,
          workerId: null,
          phase: DigitReservationPhase.queued,
        ),
    for (final job in _current.jobs)
      if (job.kind == TaskKind.digit && job.tileIds.any(_isPadTile))
        for (final tileId in job.tileIds.where(_isPadTile))
          DigitReservation(
            id: job.id,
            digit: job.digit!,
            tileId: tileId,
            workerId: job.workerId,
            phase: DigitReservationPhase.traveling,
          ),
    for (final offer in _current.offers)
      for (final tileId in offer.tileIds.where(_isPadTile))
        DigitReservation(
          id: offer.id,
          digit: offer.digit,
          tileId: tileId,
          workerId: offer.workerId,
          phase: DigitReservationPhase.offered,
        ),
  ]);

  bool _isPadTile(String id) => _padReservationTiles.contains(id);

  bool requestPadDelivery(int digit, {String? tileId, bool priority = false}) {
    if (board.id == 'opening' ||
        cleared ||
        !_knownDigit(digit) ||
        _workingCreatures.isEmpty)
      return false;
    final stock = _current.stock[digit];
    if (stock == null || stock.isEmpty) return false;
    final index = tileId == null
        ? 0
        : stock.indexWhere((tile) => tile.id == tileId);
    if (index < 0) return false;
    final tile = stock.removeAt(index);
    _padReservationTiles.add(tile.id);
    final request = _Request(
      _id('pad'),
      TaskKind.digit,
      digit: digit,
      priority: priority,
      tileId: tile.id,
    );
    _current.queue.add(request);
    _dispatch();
    _changed();
    return true;
  }

  bool takeOverDigitReservation(String id) {
    final request = _current.queue
        .where((item) => item.id == id && item.tileId != null)
        .firstOrNull;
    if (request != null) {
      _current.queue.remove(request);
      _padReservationTiles.remove(request.tileId);
      _putStock(request.digit!, [_Tile(request.tileId!)]);
      _dispatch();
      _changed();
      return true;
    }
    final job = _current.jobs
        .where((item) => item.id == id && item.kind == TaskKind.digit)
        .firstOrNull;
    if (job != null && job.tileIds.any(_isPadTile)) {
      _current.jobs.remove(job);
      _padReservationTiles.removeAll(job.tileIds);
      _putStock(job.digit!, [for (final tileId in job.tileIds) _Tile(tileId)]);
      _dispatch();
      _changed();
      return true;
    }
    final offer = _current.offers
        .where((item) => item.id == id && item.tileIds.any(_isPadTile))
        .firstOrNull;
    if (offer != null) {
      _current.offers.remove(offer);
      _padReservationTiles.removeAll(offer.tileIds);
      _putStock(offer.digit, [
        for (final tileId in offer.tileIds) _Tile(tileId),
      ]);
      _dispatch();
      _changed();
      return true;
    }
    return false;
  }

  LandmarkWitness? compareLastVisit(String boardId, {String? eventId}) {
    for (final archive in _archives.reversed) {
      for (final saved in _maps(archive['landmarks'])) {
        if (saved['boardId'] != boardId ||
            (eventId != null && saved['eventId'] != eventId))
          continue;
        return LandmarkWitness(
          runId: saved['runId'] as String,
          boardId: saved['boardId'] as String,
          eventId: saved['eventId'] as String,
          workerId: saved['workerId'] as String,
          workerName: saved['workerName'] as String? ?? '',
          eventKind:
              TaskKind.values.asNameMap()[saved['eventKind']] ?? TaskKind.torch,
          visibleResult: saved['visibleResult'] as String? ?? '',
        );
      }
    }
    return null;
  }

  List<DeductionStep> _routeSteps(String routeId) => switch (routeId) {
    'lines' => const [
      DeductionStep('bound-r6c2', 'The region sums bound R6C2 at 6 or less.'),
      DeductionStep(
        'mirror-r7c4',
        'The palindrome carries that bound to R7C4.',
      ),
    ],
    'outside' => const [
      DeductionStep('xsum-r1c4', 'The column X-Sum fixes R1C4 as 8.'),
      DeductionStep('sandwich-r1c6', 'The row sandwich then fixes R1C6 as 4.'),
    ],
    'positions' => const [
      DeductionStep(
        'knight-elimination',
        'Anti-Knight removes the first two diagonal 9 positions.',
      ),
      DeductionStep('diagonal-r9c9', 'The diagonal therefore fixes R9C9 as 9.'),
    ],
    _ => const [],
  };

  FinaleCeremony finaleCeremony(String routeId) {
    final finaleCleared = campaignBoards.any(
      (candidate) =>
          candidate.route == routeId &&
          candidate.finale &&
          _cleared.contains(candidate.id),
    );
    return FinaleCeremony(
      routeId: routeId,
      steps: List.unmodifiable(_routeSteps(routeId)),
      signedStepIds: Set.unmodifiable(
        _ceremonySteps[routeId] ?? const <String>{},
      ),
      dedication: _dedications[routeId],
      ready: finaleCleared && _built.containsKey('meeting-hall'),
    );
  }

  bool signOffDeduction(String routeId, String stepId) {
    final ceremony = finaleCeremony(routeId);
    if (!ceremony.ready || !ceremony.steps.any((step) => step.id == stepId))
      return false;
    if (!(_ceremonySteps.putIfAbsent(routeId, () => <String>{}).add(stepId)))
      return false;
    _changed();
    return true;
  }

  bool chooseDedication(String routeId, String dedication) {
    const allowed = {
      'lines': 'Open the bridge',
      'outside': 'Open the provisions counter',
      'positions': 'Mark the crossing lanes',
    };
    final ceremony = finaleCeremony(routeId);
    if (!ceremony.ready ||
        !ceremony.deductionComplete ||
        allowed[routeId] != dedication ||
        _dedications.containsKey(routeId))
      return false;
    _dedications[routeId] = dedication;
    _changed();
    return true;
  }

  ExpeditionState expeditionState(String boardId) {
    final candidate = campaignBoards
        .where((item) => item.id == boardId && item.expedition)
        .firstOrNull;
    if (candidate == null) {
      return ExpeditionState(
        boardId: boardId,
        available: false,
        patternEarned: false,
        ornamentInstalled: false,
        installerIds: const {},
        familiarExample: false,
      );
    }
    return ExpeditionState(
      boardId: boardId,
      available: _isAvailable(candidate),
      patternEarned: _cleared.contains(boardId),
      ornamentInstalled: _built.containsKey('cosmetic-$boardId'),
      installerIds: Set.unmodifiable(
        _projectWorkers['cosmetic-$boardId'] ?? const <String>{},
      ),
      familiarExample: _archives.any(
        (archive) => _list<String>(archive['clears']).contains(boardId),
      ),
    );
  }

  bool markLesson(String id, {bool practiced = false}) {
    if (id.isEmpty || id.length > 200) return false;
    final changed =
        _seenLessons.add(id) | (practiced && _practicedLessons.add(id));
    if (changed) _changed();
    return changed;
  }

  bool beginShatter() {
    if (!_cleared.contains('growth-9')) return false;
    if (_shatter != null) return true;
    final source = _progress['growth-9'];
    if (source == null || !source.cleared) return false;
    final fragments = <String, ShatterFragment>{};
    for (final entry in source.tiles.entries) {
      fragments[entry.value.id] = ShatterFragment(
        entry.value.id,
        source.cells[entry.key],
        ShatterFragmentState.locked,
      );
    }
    _shatter = ShatterLedger(
      id: '$runId:shatter:renban',
      sourceBoardId: 'growth-9',
      destinationBoardId: 'renban',
      totalSeams: 12,
      fragments: fragments,
    );
    _changed();
    return true;
  }

  bool strikeShatterSeam() {
    if (!beginShatter() || !_shatter!.canStrike) return false;
    _shatter!.openedSeams++;
    if (_shatter!.remainingSeams == 0) _finishShatter();
    _changed();
    return true;
  }

  bool breakRemaining() {
    if (!beginShatter() || !_shatter!.canStrike) return false;
    _shatter!.openedSeams = _shatter!.totalSeams;
    _finishShatter();
    _changed();
    return true;
  }

  bool skipShatterAnimation() => breakRemaining();

  bool retryShatter() {
    final ledger = _shatter;
    if (ledger == null || !ledger.assembled) return false;
    final sorted = ledger.fragments.values
        .where((fragment) => fragment.state == ShatterFragmentState.stock)
        .map((fragment) => fragment.tileId)
        .toSet();
    _progress.remove('renban');
    for (final fragment in ledger.fragments.values.toList()) {
      ledger.fragments[fragment.tileId] = ShatterFragment(
        fragment.tileId,
        fragment.digit,
        ShatterFragmentState.locked,
      );
    }
    ledger.assembled = false;
    _directShatterPlacements.clear();
    _finishShatter();
    for (final id in sorted) {
      final fragment = ledger.fragments[id];
      if (fragment?.state == ShatterFragmentState.unsorted) {
        ledger.fragments[id] = ShatterFragment(
          id,
          fragment!.digit,
          ShatterFragmentState.stock,
        );
      }
    }
    _current = _progress['renban']!;
    _restockNow();
    _dispatch();
    _changed();
    return true;
  }

  void _finishShatter() {
    final ledger = _shatter!;
    if (ledger.assembled) return;
    final destination = _load('renban');
    final byDigit = <int, List<String>>{};
    for (final fragment in ledger.fragments.values) {
      byDigit.putIfAbsent(fragment.digit, () => []).add(fragment.tileId);
    }
    destination.tiles.clear();
    destination.stock.clear();
    for (final index in destination.fixed) {
      final digit = destination.cells[index];
      final id = byDigit[digit]!.removeAt(0);
      destination.tiles[index] = _Tile(id);
      ledger.fragments[id] = ShatterFragment(
        id,
        digit,
        ShatterFragmentState.placed,
      );
    }
    for (var digit = 1; digit <= 9; digit++) {
      for (var i = 0; i < (destination.board.eaten[digit] ?? 0); i++) {
        final id = byDigit[digit]!.removeAt(0);
        ledger.fragments[id] = ShatterFragment(
          id,
          digit,
          ShatterFragmentState.captured,
        );
      }
      destination.stock[digit] = [for (final id in byDigit[digit]!) _Tile(id)];
      for (final id in byDigit[digit]!) {
        ledger.fragments[id] = ShatterFragment(
          id,
          digit,
          ShatterFragmentState.unsorted,
        );
      }
    }
    ledger.assembled = true;
  }

  bool sortShatterFragment(String tileId) {
    final fragment = _shatter?.fragments[tileId];
    if (_shatter?.assembled != true ||
        fragment?.state != ShatterFragmentState.unsorted)
      return false;
    _shatter!.fragments[tileId] = ShatterFragment(
      tileId,
      fragment!.digit,
      ShatterFragmentState.stock,
    );
    _changed();
    return true;
  }

  bool sortRemainingShatter() {
    if (_shatter?.canSort != true) return false;
    for (final fragment in _shatter!.fragments.values.toList()) {
      if (fragment.state == ShatterFragmentState.unsorted) {
        _shatter!.fragments[fragment.tileId] = ShatterFragment(
          fragment.tileId,
          fragment.digit,
          ShatterFragmentState.stock,
        );
      }
    }
    _changed();
    return true;
  }

  FogStaffing get fogStaffing {
    if (board.fog == FogKind.none) {
      return const FogStaffing(
        required: 0,
        available: 0,
        assignedWorkerIds: [],
        busyWorkerIds: [],
        sequential: false,
      );
    }
    final sequential = charter == Charter.oneHelper;
    final required = sequential
        ? 1
        : switch (board.id) {
            'halo' when !_current.deliveredReveals.contains('starter') => 1,
            'halo' => 2,
            'trail' || 'linked-torches' => 3,
            'night-market' => 4,
            _ => 1,
          };
    final eligible = _workingCreatures.map((worker) => worker.id).toList();
    final preferred = _torchCrew[board.id] ?? const <String>[];
    final assigned = [
      ...preferred.where(eligible.contains),
      ...eligible.where((id) => !preferred.contains(id)),
    ].take(required).toList();
    return FogStaffing(
      required: required,
      available: eligible.length,
      assignedWorkerIds: List.unmodifiable(assigned),
      busyWorkerIds: List.unmodifiable(
        jobs
            .where((job) => job.kind == TaskKind.torch)
            .map((job) => job.workerId),
      ),
      sequential: sequential,
    );
  }

  bool assignTorchWorker(String workerId) {
    if (board.fog == FogKind.none ||
        !_workingCreatures.any((worker) => worker.id == workerId))
      return false;
    final crew = _torchCrew.putIfAbsent(board.id, () => <String>[]);
    if (crew.contains(workerId)) return false;
    crew.add(workerId);
    _dispatch();
    _changed();
    return true;
  }

  bool callBackTorchWorker(String workerId) {
    if (!(_torchCrew[board.id]?.remove(workerId) ?? false)) return false;
    _changed();
    return true;
  }

  int get _communalCapacity => _cleared.contains('arrows')
      ? 12
      : _cleared.contains('growth-8')
      ? 8
      : _cleared.contains('growth-6')
      ? 4
      : 0;
  int get _fieldPostLimit => _cleared.contains('arrows')
      ? 4
      : _cleared.contains('growth-8')
      ? 3
      : _cleared.contains('growth-6')
      ? 2
      : 1;

  bool setArrivalsPaused(bool paused) {
    if (_arrivalsPaused == paused) return false;
    _arrivalsPaused = paused;
    if (!paused) _spendArrivalCredits();
    _changed();
    return true;
  }

  bool welcomeResident() {
    if (_arrivalCredits <= 0 || _communalResidents.length >= _communalCapacity)
      return false;
    _arrivalCredits--;
    final sequence = 1000 + ++_populationSequence;
    final founder =
        CreatureFounder.values[sequence % CreatureFounder.values.length];
    final resident = Creature.generate(
      runSeed: seed,
      sequence: sequence,
      unlockedDigits: unlockedSize,
      recipe: CreatureRecipe.communal(
        founder,
        nicheIndex: sequence ~/ CreatureFounder.values.length,
      ),
    )..name = 'Resident $_populationSequence';
    _creatures.add(resident);
    _communalResidents.add(resident.id);
    _dispatch();
    _changed();
    return true;
  }

  void _spendArrivalCredits() {
    if (_arrivalsPaused) return;
    while (_arrivalCredits > 0 &&
        _communalResidents.length < _communalCapacity) {
      welcomeResident();
    }
  }

  bool moveIn(String creatureId, int cellIndex) {
    if (libraryChallenge ||
        !_creatures.any((worker) => worker.id == creatureId) ||
        !_inside(cellIndex) ||
        !_current.visible.contains(cellIndex) ||
        _current.cells[cellIndex] == 0 ||
        _current.cells[cellIndex] != board.solution[cellIndex] ||
        _residentAddresses.values.contains(cellIndex))
      return false;
    _residentAddresses[creatureId] = cellIndex;
    _changed();
    return true;
  }

  bool evictResident(String creatureId) {
    if (_residentAddresses.remove(creatureId) == null) return false;
    _changed();
    return true;
  }

  ProjectProgress projectProgress(String projectId) {
    final spec = projects.firstWhere((project) => project.id == projectId);
    Map<MaterialRole, int> count(Iterable<MaterialGlyph> glyphs) => {
      for (final role in MaterialRole.values)
        role: glyphs.where((glyph) => glyph.role == role).length,
    };
    final work = _construction[projectId];
    final installed = count(
      _built[projectId] ??
          work?.loads
              .where((load) => load.stage == ConstructionLoadStage.installed)
              .map((load) => load.glyph) ??
          const [],
    );
    final inTransit = count([
      ..._materialJobs
          .where((job) => job.projectId == projectId)
          .expand((job) => job.glyphs),
      ...?work?.loads
          .where(
            (load) =>
                load.stage == ConstructionLoadStage.cutting ||
                load.stage == ConstructionLoadStage.installing,
          )
          .map((load) => load.glyph),
    ]);
    final cutStock = count(
      work?.loads
              .where((load) => load.stage == ConstructionLoadStage.cut)
              .map((load) => load.glyph) ??
          const [],
    );
    final reserved = <MaterialRole, int>{
      for (final role in MaterialRole.values)
        role:
            _materialQueue
                .where(
                  (request) =>
                      request.project == projectId && request.role == role,
                )
                .fold(0, (sum, request) => sum + request.count) +
            (projectId == 'practice-site'
                ? _practiceMaterials.where((glyph) => glyph.role == role).length
                : 0) +
            (work?.loads
                    .where(
                      (load) =>
                          load.glyph.role == role &&
                          (load.stage == ConstructionLoadStage.reserved ||
                              load.stage == ConstructionLoadStage.cut),
                    )
                    .length ??
                0),
    };
    return ProjectProgress(
      projectId: projectId,
      name: spec.name,
      requirements: Map.unmodifiable(spec.requirements),
      installed: Map.unmodifiable(installed),
      reserved: Map.unmodifiable(reserved),
      inTransit: Map.unmodifiable(inTransit),
      complete: _built.containsKey(projectId),
      cutStock: Map.unmodifiable(cutStock),
      started: work != null,
      paused: work?.paused ?? false,
    );
  }

  bool setPinnedGoal(String? targetId) {
    if (targetId != null && (targetId.isEmpty || targetId.length > 200))
      return false;
    if (_pinnedGoal == targetId) return false;
    _pinnedGoal = targetId;
    _changed();
    return true;
  }

  Set<String> _requiredOrderSteps(SettlementOrder order) => switch (order) {
    SettlementOrder.supply => const {'value-1', 'value-2'},
    SettlementOrder.build => const {'beam', 'digit'},
    SettlementOrder.lanterns => const {'torch', 'priority', 'digit'},
  };

  SettlementOrderProgress orderProgress(SettlementOrder order) {
    final ledger = _orderProgress[order];
    return SettlementOrderProgress(
      order: order,
      accepted: ledger?.accepted ?? false,
      completed: ledger?.completed ?? false,
      steps: Set.unmodifiable(ledger?.steps ?? const <String>{}),
      requiredSteps: Set.unmodifiable(_requiredOrderSteps(order)),
      contributorIds: Set.unmodifiable(
        ledger?.contributors ?? const <String>{},
      ),
      rewardPresetId: 'preset-${order.name}',
    );
  }

  bool acceptOrder(SettlementOrder order) {
    final unlocked = switch (order) {
      SettlementOrder.supply => _cleared.contains('growth-6'),
      SettlementOrder.build => _cleared.contains('growth-8'),
      SettlementOrder.lanterns => _cleared.contains('halo'),
    };
    final ledger = _orderProgress.putIfAbsent(order, _OrderLedger.new);
    if (!unlocked || ledger.accepted || ledger.completed) return false;
    ledger.accepted = true;
    _changed();
    return true;
  }

  void _recordOrderStep(SettlementOrder order, String step, String workerId) {
    final ledger = _orderProgress[order];
    if (ledger == null || !ledger.accepted || ledger.completed) return;
    if (order == SettlementOrder.supply && step.startsWith('digit:')) {
      final prior = ledger.steps
          .where((value) => value.startsWith('digit:'))
          .toSet();
      if (!prior.contains(step)) ledger.steps.add('value-${prior.length + 1}');
    }
    ledger.steps.add(step);
    ledger.contributors.add(workerId);
    if (_requiredOrderSteps(order).every(ledger.steps.contains)) {
      ledger.completed = true;
      final id = 'preset-${order.name}';
      _presets.putIfAbsent(
        id,
        () => CrewPreset(
          id: id,
          name: '${order.name[0].toUpperCase()}${order.name.substring(1)}',
          assignments: _assignments,
          restockTargets: _restock,
        ),
      );
    }
  }

  bool savePreset(CrewPreset preset) {
    if (!_presets.containsKey(preset.id) || preset.id.length > 100)
      return false;
    _presets[preset.id] = preset;
    _changed();
    return true;
  }

  bool recallPreset(String id) {
    final preset = _presets[id];
    if (preset == null) return false;
    _assignments
      ..clear()
      ..addEntries(
        preset.assignments.entries.where(
          (entry) => _creatures.any((worker) => worker.id == entry.key),
        ),
      );
    if (charter != Charter.handOrders) {
      _restock
        ..clear()
        ..addAll(preset.restockTargets);
      _restockNow();
    }
    _dispatch();
    _changed();
    return true;
  }

  ProductionBatchState? get productionBatch {
    final opened = _batchOpenedBy;
    if (opened == null) return null;
    final id = '$runId:batch:$_batchSequence';
    return ProductionBatchState(
      id: id,
      openedBy: opened,
      deliveredCycles: Map.unmodifiable(_batchDelivered),
      cycleCaps: Map.unmodifiable({
        for (final entry in _producerMap.entries)
          entry.key: entry.value.type == ProducerType.rna ? 6 : 2,
      }),
      commissionedRanks: Map.unmodifiable(_batchRanks),
      settled: _settledBatches.contains(id),
    );
  }

  PrestigeQuote prestigeQuote({
    Map<LegacyUpgrade, int> upgrades = const {},
    String? transactionId,
  }) {
    var cost = 0;
    for (final entry in upgrades.entries) {
      final current = _legacyUpgrades[entry.key] ?? 0;
      cost += legacyUpgradeCosts(entry.key)
          .skip(current)
          .take(math.max(0, entry.value - current))
          .fold(0, (sum, value) => sum + value);
    }
    final routes = campaignBoards
        .where((item) => item.finale && _cleared.contains(item.id))
        .map((item) => item.route!)
        .toSet();
    return PrestigeQuote(
      transactionId: transactionId ?? '$runId:prestige',
      runId: runId,
      payout: prestigePayout,
      startingLegacy: legacy,
      purchaseCost: cost,
      endingLegacy: legacy + prestigePayout - cost,
      resetDna: dna,
      resetRna: rna,
      routes: Set.unmodifiable(routes),
      charterCredit:
          charter != Charter.standard && !_creditedCharters.contains(charter),
    );
  }

  void _onAuthoredClear(String boardId) {
    if (boardId == 'growth-6') _populationAccountedAt = _clock;
    if (_cleared.contains('growth-6') && _arrivalGrants.add('clear:$boardId')) {
      _arrivalCredits = math.min(2, _arrivalCredits + 1);
      _spendArrivalCredits();
    }
    _advanceProductionBatch(boardId);
  }

  void _accruePopulation(int from, int productiveEnd, int target) {
    if (!_cleared.contains('growth-6')) return;
    if (_populationAccountedAt == 0) _populationAccountedAt = from;
    final end = math.min(productiveEnd, target);
    final elapsed =
        math.max(0, end - _populationAccountedAt) + _populationRemainderMs;
    final grants = elapsed ~/ 60000;
    _populationRemainderMs = elapsed % 60000;
    _populationAccountedAt = target;
    if (grants > 0) {
      _arrivalCredits = math.min(2, _arrivalCredits + grants);
      if (_arrivalCredits == 2) _populationRemainderMs = 0;
      _spendArrivalCredits();
    }
  }

  void _advanceProductionBatch(String clearId) {
    if (charter == Charter.noProducers) return;
    if (_batchOpenedBy != null) _settleProductionBatch();
    _batchSequence++;
    _batchOpenedBy = clearId;
    _batchDelivered.clear();
    _batchRanks
      ..clear()
      ..addEntries(
        _producerMap.entries.map(
          (entry) => MapEntry(entry.key, entry.value.rank),
        ),
      );
    for (final producer in _producerMap.values) {
      producer.nextAt = _clock + producer.interval;
    }
    if (completed) _settleProductionBatch();
  }

  void _settleProductionBatch() {
    if (_batchOpenedBy == null || charter == Charter.noProducers) return;
    final id = '$runId:batch:$_batchSequence';
    if (!_settledBatches.add(id)) return;
    for (final entry in _producerMap.entries) {
      final cap = entry.value.type == ProducerType.rna ? 6 : 2;
      final delivered = _batchDelivered[entry.key] ?? 0;
      final units =
          math.max(0, cap - delivered) *
          (_batchRanks[entry.key] ?? entry.value.rank);
      if (entry.value.type == ProducerType.rna)
        rna += units;
      else
        dna += units;
      _batchDelivered[entry.key] = cap;
    }
  }
}
