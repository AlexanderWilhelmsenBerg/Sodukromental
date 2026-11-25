// Hallmark · Map / Diagram · Hum · pre-emit critique: P4 H5 E4 S4 R5 V4
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'board_moment.dart';
import 'board_view.dart';
import 'campaign.dart';
import 'creature_view.dart';
import 'creatures.dart';
import 'hum.dart';
import 'tilt_input.dart';

class ColonyScreen extends StatefulWidget {
  const ColonyScreen({
    super.key,
    required this.campaign,
    required this.onChanged,
    this.onOpenCreator,
    this.onOpenSettings,
    this.onOpenProfile,
    this.showHabitat = true,
    this.reducedMotion = false,
    this.tiltEnabled = true,
  });

  final Campaign campaign;
  final VoidCallback onChanged;
  final VoidCallback? onOpenCreator;
  final VoidCallback? onOpenSettings;
  final ValueChanged<Creature>? onOpenProfile;
  final bool showHabitat;
  final bool reducedMotion;
  final bool tiltEnabled;

  @override
  State<ColonyScreen> createState() => _ColonyScreenState();
}

class _ColonyScreenState extends State<ColonyScreen> {
  final _tilt = TiltInput();
  StreamSubscription<AccelerometerEvent>? _motion;
  late String _boardId;
  int? _cell;
  int? _slide;
  int? _token;
  int? _digit;
  String? _offer;
  int? _region;
  bool _notes = false;
  bool _dragging = false;
  bool _allMarks = true;
  String? _highlightRule;
  String? _feedback;
  Set<int> _conflicts = {};
  Set<int> _knownVisible = {};
  List<int> _newlyLit = [];
  int _revealSerial = 0;

  Campaign get run => widget.campaign;
  BoardSpec get board => run.board;
  bool get opening => board.id == 'opening';
  bool get grown => board.id != 'opening';

  @override
  void initState() {
    super.initState();
    _boardId = board.id;
    _updateBoard();
    _connectMotion();
  }

  @override
  void didUpdateWidget(covariant ColonyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaign != run || _boardId != board.id) _updateBoard();
    if (board.gravity != (_motion != null) ||
        oldWidget.tiltEnabled != widget.tiltEnabled) {
      _connectMotion();
    }
    final visible = run.visible;
    if (board.fog != FogKind.none && visible.length > _knownVisible.length) {
      _newlyLit = visible.difference(_knownVisible).toList();
      _revealSerial++;
    }
    _knownVisible = visible;
    if (_offer != null && !run.offers.any((offer) => offer.id == _offer))
      _offer = null;
  }

  void _updateBoard() {
    _boardId = board.id;
    _cell = _slide = _token = _digit = null;
    _offer = _feedback = _highlightRule = null;
    _notes = false;
    _allMarks = true;
    _conflicts = {};
    _region = [5, 7].contains(board.size) ? board.regions.first : null;
    _knownVisible = run.visible;
    _newlyLit = [];
    _tilt.reset(run.gravity);
  }

  void _connectMotion() {
    final platform = defaultTargetPlatform;
    final supported =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!board.gravity || !widget.tiltEnabled || kIsWeb || !supported) {
      unawaited(_motion?.cancel());
      _motion = null;
      return;
    }
    _motion ??= accelerometerEventStream().listen((event) {
      if (!mounted || _dragging) return;
      final direction = _tilt.add(event.x, event.y, event.timestamp);
      if (direction != null) _settle(direction);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    unawaited(_motion?.cancel());
    super.dispose();
  }

  void _change(VoidCallback action) {
    setState(action);
    if (_boardId != board.id) {
      setState(_updateBoard);
      _connectMotion();
    }
    widget.onChanged();
  }

  void _result(bool success, String failure, [String? message]) {
    _feedback = success ? message : run.lastFeedback ?? failure;
    if (success) {
      _conflicts = {};
      _region = null;
    }
  }

  void _releaseOffer() {
    if (_offer != null) run.holdOffer(null);
    _offer = null;
  }

  void _selectToken(int index) => _change(() {
    _releaseOffer();
    _digit = _slide = null;
    // A selected sentence token must stay movable while the board is sliding.
    if (_token != index) {
      _token = index;
      _feedback = 'Tap a gap to place this 4.';
    } else {
      _token = null;
      _feedback = null;
    }
  });

  void _onCell(int index) => _change(() {
    _cell = index;
    if (!run.visible.contains(index)) {
      _feedback = 'A torch will reveal this square.';
      return;
    }
    if (_token case final int token) {
      _useToken(index, token);
    } else if (_offer case final String offer) {
      _claim(offer, index);
    } else if (_digit case final int digit) {
      _place(index, digit);
    } else if (run.sliding) {
      if (run.cells[index] == 0 && _slide != null) {
        _shift(_slide!, index);
      } else if (run.cells[index] > 0 && !run.anchors.contains(index)) {
        _slide = _slide == index ? null : index;
        _feedback = _slide == null ? null : 'Choose a gap beside this tile.';
      } else if (run.anchors.contains(index)) {
        _feedback = 'That clue is anchored.';
      }
    } else if (_region != null) {
      _region = board.regions[index];
    }
  });

  void _onDrop(int index, BoardDrag data) => _change(() {
    _dragging = false;
    _cell = index;
    if (data.source case final int source) {
      _shift(source, index);
    } else if (data.token case final int token) {
      _useToken(index, token);
    } else if (data.offerId case final String offer) {
      _claim(offer, index);
    } else if (data.value case final int digit) {
      _place(index, digit);
    }
  });

  void _useToken(int index, int token) {
    final accepted = run.placeTutorialToken(index, token: token);
    _result(
      accepted,
      'Keep sliding until all four gaps can hold a 4.',
      '+1 DNA',
    );
    if (accepted) _token = null;
  }

  void _shift(int source, int destination) {
    final accepted = run.slide(source, destination);
    _result(accepted, 'Slide into an empty square directly beside the tile.');
    if (accepted) _slide = null;
  }

  void _place(int index, int digit) {
    if (_notes) {
      run.toggleNote(index, digit);
      _feedback = null;
      return;
    }
    final accepted = run.place(index, digit);
    _result(accepted, 'Choose a visible open square and a digit in stock.');
    _cell = index;
    if (accepted && (run.tray[digit] ?? 0) == 0) _digit = null;
  }

  void _claim(String offer, int index) {
    if (_notes) {
      final current = run.offers.where((item) => item.id == offer).firstOrNull;
      if (current != null) run.toggleNote(index, current.digit);
      _releaseOffer();
      return;
    }
    final accepted = run.claimOffer(offer, index);
    _result(accepted, 'This delivery needs a visible open square.');
    if (accepted) _releaseOffer();
  }

  void _selectDigit(int digit) => _change(() {
    _releaseOffer();
    _token = _slide = null;
    _digit = _digit == digit ? null : digit;
    _feedback = _digit == null
        ? null
        : 'Tap a square ${_notes ? 'to note' : 'for'} $digit.';
  });

  void _digitFromKeyboard(int index, int digit) => _change(() {
    _cell = index;
    if (opening && run.tutorialTokens > 0 && digit == 4) {
      final token = Iterable<int>.generate(
        3,
      ).firstWhere((id) => !run.usedTutorialTokens.contains(id));
      _useToken(index, token);
    } else {
      _place(index, digit);
    }
  });

  void _erase(int index) => _change(() {
    _cell = index;
    _result(run.erase(index), 'Choose a player-placed digit to erase.');
  });

  void _settle(GravityDirection direction) {
    if (_dragging || direction == run.gravity) return;
    _change(() => run.tilt(direction));
  }

  void _retry() {
    _releaseOffer();
    run.retry();
    _updateBoard();
  }

  Color get _feedbackColor => _conflicts.isNotEmpty ? Hum.error : Hum.focus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reducedMotion =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    final gravityUp = board.gravity && run.gravity == GravityDirection.up;
    final tray = _tray();
    final landscape = <Widget>[
      if (gravityUp) ...[tray, const SizedBox(height: 12)],
      _board(reducedMotion),
      if (!gravityUp && tray is! SizedBox) ...[
        const SizedBox(height: 12),
        tray,
      ],
      const SizedBox(height: 4),
      _boardTools(),
    ];
    return SingleChildScrollView(
      key: const PageStorageKey('colony-board-scroll'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 700 &&
                  widget.showHabitat &&
                  run.creatures.isNotEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        opening ? 'The missing four' : board.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Hum.ink,
                        ),
                      ),
                      if (run.cleared)
                        const Icon(
                          Icons.check_circle_outline,
                          color: Hum.focus,
                          semanticLabel: 'Board cleared',
                        ),
                    ],
                  ),
                  if (opening && !run.cleared)
                    _openingPrompt()
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        board.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Hum.mutedInk,
                        ),
                      ),
                    ),
                  if (grown ||
                      run.creatures.isNotEmpty ||
                      run.dna > 0 ||
                      run.rna > 0)
                    _resources(),
                  if (!run.cleared)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        run.objective,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_feedback != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _feedback!,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (run.canCreateAmoeba) ...[
                    _PrimaryAction(
                      label: 'Create amoeba',
                      icon: Icons.egg_alt_outlined,
                      onPressed: () => _change(
                        () => _result(
                          run.createAmoeba(),
                          'You need 3 DNA.',
                          'The amoeba is looking for the last 4.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (run.cleared) ...[
                    _clearActions(),
                    const SizedBox(height: 12),
                  ],
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: Column(children: landscape)),
                        const SizedBox(width: 20),
                        Expanded(flex: 3, child: _habitat(reducedMotion)),
                      ],
                    )
                  else ...[
                    ...landscape,
                    if (widget.showHabitat && run.creatures.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _habitat(reducedMotion),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _openingPrompt() {
    final pieces =
        'In this 4×4 puzzle, the 4 is missing. Can you find someone to help you?'
            .split('4');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < pieces.length; i++) ...[
              TextSpan(text: pieces[i]),
              if (i < pieces.length - 1)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: run.usedTutorialTokens.contains(i)
                      ? Semantics(
                          label: '4 tile placed',
                          child: const ExcludeSemantics(
                            child: BoardDigitFace(value: 4, used: true),
                          ),
                        )
                      : _DigitControl(
                          key: ValueKey('tutorial-token-$i'),
                          data: BoardDrag.digit(4, token: i),
                          label: '4, sentence tile ${i + 1} of 3',
                          selected: _token == i,
                          onTap: () => _selectToken(i),
                          onDrag: _setDragging,
                        ),
                ),
            ],
          ],
        ),
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Hum.ink, height: 1.35),
      ),
    );
  }

  Widget _resources() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _Resource(label: 'DNA', count: run.dna, icon: Icons.biotech),
        if (run.rna > 0 || grown || run.cleared)
          _Resource(
            label: 'RNA',
            count: run.rna,
            icon: Icons.bubble_chart_outlined,
          ),
        if (run.legacy > 0)
          _Resource(
            label: 'Legacy',
            count: run.legacy,
            icon: Icons.auto_awesome_outlined,
          ),
      ],
    ),
  );

  Widget _board(bool reducedMotion) {
    final allMarks = board.rules
        .where(
          (rule) =>
              rule.kind != RuleKind.antiKnight ||
              _cell != null && rule.cells.contains(_cell),
        )
        .map((rule) => BoardMark(rule.kind.name, rule.cells, rule.target))
        .toList();
    final marks = _allMarks
        ? allMarks
        : allMarks.where((mark) => mark.kind == _highlightRule).toList();
    final wormPath = board.id == 'renban'
        ? board.rules
              .where((rule) => rule.kind == RuleKind.renban)
              .firstOrNull
              ?.cells
        : null;
    final reaction = run.reaction;
    final crew = _reactionCrew(reaction);
    final game = SudokuBoardView(
      key: ValueKey(board.id),
      size: board.size,
      cells: run.cells,
      regions: board.regions,
      fixed: run.fixed,
      anchors: run.anchors,
      visible: run.visible,
      notes: run.notes,
      selected: _slide ?? _cell,
      highlightRegion: _region,
      conflicts: _conflicts,
      marks: marks,
      sliding: run.sliding,
      onCell: _onCell,
      onDrop: _onDrop,
      onDigit: _digitFromKeyboard,
      onErase: _erase,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 530),
        child: AnimatedSwitcher(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 140),
          child: _OutsideClues(
            key: ValueKey('clues-${board.id}'),
            size: board.size,
            marks: marks,
            child: Stack(
              children: [
                game,
                if (reaction != null &&
                    reaction.index >= 0 &&
                    run.visible.contains(reaction.index) &&
                    crew.isNotEmpty)
                  Positioned.fill(
                    child: _CellReaction(
                      key: ValueKey('reaction-${reaction.dueAt}'),
                      boardSize: board.size,
                      index: reaction.index,
                      crew: crew,
                      cheer: reaction.kind == ReactionKind.flock,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                if (!reducedMotion && wormPath != null)
                  Positioned.fill(
                    child: BoardMoment(
                      key: ValueKey('worm-${board.id}'),
                      size: board.size,
                      cells: wormPath,
                      worm: true,
                    ),
                  ),
                if (!reducedMotion && _newlyLit.isNotEmpty)
                  Positioned.fill(
                    child: BoardMoment(
                      key: ValueKey('torch-$_revealSerial'),
                      size: board.size,
                      cells: _newlyLit,
                      worm: false,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setDragging(bool dragging) {
    _dragging = dragging;
  }

  List<Creature> _reactionCrew(CreatureReaction? reaction) {
    if (reaction == null) return const [];
    final busy = run.jobs.map((job) => job.workerId).toSet();
    return run.creatures
        .where(
          (creature) =>
              !busy.contains(creature.id) &&
              (creature.id == reaction.workerId ||
                  reaction.kind == ReactionKind.flock &&
                      creature.favorite == reaction.digit),
        )
        .take(4)
        .toList();
  }

  Widget _tray() {
    if (opening &&
        run.tray.values.every((value) => value == 0) &&
        run.offers.isEmpty)
      return const SizedBox.shrink();
    int unreserved(int digit) =>
        (run.tray[digit] ?? 0) -
        run.offers
            .where((offer) => offer.idle && offer.digit == digit)
            .fold(0, (sum, offer) => sum + offer.count);
    final values = Iterable<int>.generate(
      board.size,
      (index) => index + 1,
    ).where((digit) => unreserved(digit) > 0 || _notes).toList();
    if (board.gravity &&
        (run.gravity == GravityDirection.left ||
            run.gravity == GravityDirection.up)) {
      values.sort((a, b) => b.compareTo(a));
    }
    final alignment = board.gravity
        ? switch (run.gravity) {
            GravityDirection.left => WrapAlignment.start,
            GravityDirection.right => WrapAlignment.end,
            GravityDirection.up ||
            GravityDirection.down => WrapAlignment.center,
          }
        : WrapAlignment.start;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                _notes ? 'Candidates' : 'Digit tray',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (grown && !run.cleared)
                TextButton.icon(
                  onPressed: _requests,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Request digits'),
                ),
            ],
          ),
          if (values.isEmpty && run.offers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No digits in the tray.',
                style: TextStyle(color: Hum.mutedInk),
              ),
            ),
          Wrap(
            alignment: alignment,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final digit in values)
                _DigitControl(
                  key: ValueKey('tray-$digit'),
                  data: BoardDrag.digit(digit),
                  label: _notes
                      ? 'Candidate $digit'
                      : 'Digit $digit, ${unreserved(digit)} available',
                  count: _notes ? null : unreserved(digit),
                  selected: _digit == digit,
                  onTap: () => _selectDigit(digit),
                  onDrag: _setDragging,
                ),
              for (final offer in run.offers)
                _DigitControl(
                  key: ValueKey('offer-${offer.id}'),
                  data: BoardDrag.digit(offer.digit, offerId: offer.id),
                  label:
                      'Helper offers ${offer.count} copies of ${offer.digit}',
                  count: offer.count,
                  selected: _offer == offer.id,
                  offered: true,
                  onTap: () => _selectOffer(offer),
                  onDrag: (dragging) {
                    _setDragging(dragging);
                    if (dragging) _change(() => run.holdOffer(offer.id));
                    if (!dragging && _offer != offer.id)
                      _change(() => run.holdOffer(null));
                  },
                ),
            ],
          ),
          if (run.reaction case final CreatureReaction reaction
              when reaction.index < 0)
            if (_reactionCrew(reaction).isNotEmpty)
              _TrayReaction(
                key: ValueKey('tray-reaction-${reaction.dueAt}'),
                crew: _reactionCrew(reaction),
                digit: reaction.digit,
                cheer: reaction.kind == ReactionKind.flock,
                reducedMotion:
                    widget.reducedMotion ||
                    MediaQuery.disableAnimationsOf(context),
              ),
          if (board.gravity) _gravityControls(),
        ],
      ),
    );
  }

  void _selectOffer(DigitOffer offer) => _change(() {
    final selected = _offer != offer.id;
    _releaseOffer();
    _token = _slide = _digit = null;
    if (selected) {
      _offer = offer.id;
      run.holdOffer(offer.id);
      _feedback = 'Tap a square for ${offer.digit}.';
    } else {
      _feedback = null;
    }
  });

  Widget _gravityControls() => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final direction = switch (event.logicalKey) {
        LogicalKeyboardKey.keyW => GravityDirection.up,
        LogicalKeyboardKey.keyD => GravityDirection.right,
        LogicalKeyboardKey.keyS => GravityDirection.down,
        LogicalKeyboardKey.keyA => GravityDirection.left,
        _ => null,
      };
      if (direction == null) return KeyEventResult.ignored;
      _settle(direction);
      return KeyEventResult.handled;
    },
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Gravity', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final direction in GravityDirection.values)
          IconButton(
            tooltip: 'Settle ${direction.name}',
            isSelected: run.gravity == direction,
            style: IconButton.styleFrom(minimumSize: const Size.square(48)),
            onPressed: () => _settle(direction),
            icon: Icon(switch (direction) {
              GravityDirection.up => Icons.arrow_upward,
              GravityDirection.right => Icons.arrow_forward,
              GravityDirection.down => Icons.arrow_downward,
              GravityDirection.left => Icons.arrow_back,
            }),
          ),
      ],
    ),
  );

  Widget _boardTools() => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: run.cleared
              ? null
              : () => _change(
                  () => _result(run.undo(), 'There is no move to undo.'),
                ),
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        if (grown && !run.cleared) ...[
          FilterChip(
            label: const Text('Notes'),
            selected: _notes,
            visualDensity: VisualDensity.standard,
            onSelected: (value) => _change(() {
              _releaseOffer();
              _notes = value;
              _digit = null;
              _feedback = null;
            }),
          ),
          TextButton.icon(
            onPressed: _cell == null ? null : () => _erase(_cell!),
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Erase'),
          ),
          TextButton.icon(
            onPressed: () => _change(() {
              _conflicts = run.checkBoard().toSet();
              _feedback = _conflicts.isEmpty
                  ? 'No visible conflicts.'
                  : 'Review the marked conflicts.';
            }),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Check board'),
          ),
          TextButton.icon(
            onPressed: _hint,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Hint'),
          ),
        ],
        if (grown)
          TextButton.icon(
            onPressed: _rules,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Rules'),
          ),
        if (board.size >= 7 && !run.cleared)
          TextButton.icon(
            onPressed: _cellSelector,
            icon: const Icon(Icons.grid_view),
            label: const Text('Select square'),
          ),
        TextButton.icon(
          onPressed: _more,
          icon: const Icon(Icons.more_horiz),
          label: const Text('More'),
        ),
      ],
    ),
  );

  Widget _clearActions() {
    if (run.libraryChallenge) {
      return _PrimaryAction(
        label: 'Return to campaign',
        icon: Icons.arrow_back,
        onPressed: () => _change(() => run.returnToCampaign()),
      );
    }
    final routeChoice =
        board.id == 'arrows' ||
        board.finale ||
        board.expedition ||
        board.id == 'trail' ||
        board.id == 'linked-torches';
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _PrimaryAction(
          label: routeChoice
              ? board.id == 'arrows'
                    ? 'Choose a route'
                    : 'Campaign map'
              : run.completed
              ? 'Campaign map'
              : board.size < 9
              ? 'Grow to ${board.size + 1}×${board.size + 1}'
              : 'Next encounter',
          icon: routeChoice || run.completed
              ? Icons.map_outlined
              : Icons.arrow_forward,
          onPressed: routeChoice || run.completed
              ? _map
              : () => _change(() {
                  _result(
                    run.advance(),
                    'Choose an available encounter from the map.',
                  );
                }),
        ),
        if (!run.completed && board.finale)
          OutlinedButton(
            onPressed: _settlement,
            child: const Text('Build the Meeting Hall'),
          ),
        if (run.completed)
          OutlinedButton(
            onPressed: _prestige,
            child: const Text('Start a new colony'),
          ),
      ],
    );
  }

  Widget _habitat(bool reducedMotion) {
    final firstOffer = run.offers.firstOrNull;
    final trip = run.jobs.firstOrNull;
    final reaction = run.reaction;
    final worker = firstOffer?.workerId ?? trip?.workerId ?? reaction?.workerId;
    final creature =
        run.creatures.where((creature) => creature.id == worker).firstOrNull ??
        run.creatures.firstOrNull;
    if (creature == null) return const SizedBox.shrink();
    final reactionText = switch (reaction?.kind.name) {
      'curious' => 'A helper is inspecting a digit.',
      'collector' => 'A helper took a conflicting digit.',
      'tinkerer' => 'A helper tapped a conflicting digit.',
      'puzzled' => 'A helper spotted a conflict.',
      'flock' => 'Helpers found a favorite digit.',
      _ => null,
    };
    final status = firstOffer != null
        ? 'Offering ${firstOffer.digit}'
        : trip != null
        ? switch (trip.kind.name) {
            'torch' => 'Carrying a torch',
            'building' => 'Gathering materials',
            _ => 'Fetching ${trip.digit}',
          }
        : reactionText ?? 'Ready for a job';
    final pose = firstOffer != null
        ? CreaturePose.carry
        : trip != null
        ? CreaturePose.carry
        : reactionText != null
        ? reaction?.kind.name == 'flock'
              ? CreaturePose.cheer
              : CreaturePose.puzzled
        : CreaturePose.idle;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habitat',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              _OfferSprite(
                offer: firstOffer,
                onSelect: _selectOffer,
                onDrag: (dragging) {
                  _setDragging(dragging);
                  if (firstOffer != null) {
                    if (dragging) _change(() => run.holdOffer(firstOffer.id));
                    if (!dragging && _offer != firstOffer.id)
                      _change(() => run.holdOffer(null));
                  }
                },
                child: _WorkerTrip(
                  trip: trip?.id,
                  reducedMotion: reducedMotion,
                  child: CreatureSprite(
                    creature: creature,
                    size: 68,
                    pose: pose,
                    cargo:
                        firstOffer?.digit.toString() ??
                        switch (trip?.kind) {
                          TaskKind.building =>
                            trip!.glyphs.map((glyph) => glyph.glyph).join(),
                          TaskKind.torch => '✶',
                          TaskKind.digit => trip!.digit?.toString(),
                          null => null,
                        },
                    reducedMotion: reducedMotion,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creature.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(status, style: const TextStyle(color: Hum.mutedInk)),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              if (firstOffer != null)
                TextButton(
                  onPressed: () => _selectOffer(firstOffer),
                  child: Text('Take ${firstOffer.digit}'),
                ),
              if (run.stashedDigit != null)
                TextButton(
                  onPressed: () => _change(
                    () => _result(
                      run.recallStash(),
                      'The digit has already returned.',
                    ),
                  ),
                  child: const Text('Bring back'),
                ),
              if (widget.onOpenProfile != null)
                TextButton(
                  onPressed: () => widget.onOpenProfile!(creature),
                  child: const Text('Profile'),
                ),
              for (final project in run.projects.where(
                (item) => run.buildings.contains(item.id),
              ))
                Tooltip(
                  message: '${project.name} built',
                  child: SettlementProjectPreview(
                    glyphs: run.buildingGlyphs[project.id]!,
                    complete: true,
                  ),
                ),
              if (grown || run.cleared)
                TextButton.icon(
                  onPressed: _settlement,
                  icon: const Icon(Icons.cottage_outlined),
                  label: const Text('Colony jobs'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<T?> _sheet<T>(String title, Widget Function(BuildContext) content) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Hum.board,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    content(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _requests() {
    var digit = board.size;
    var count = 1;
    var priority = false;
    _sheet<void>(
      'Request digits',
      (sheet) => StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var value = 1; value <= board.size; value++)
                  ChoiceChip(
                    label: Text('$value'),
                    selected: digit == value,
                    onSelected: (_) => update(() {
                      digit = value;
                      count = 1;
                    }),
                  ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'One fewer copy',
                  onPressed: count > 1 ? () => update(() => count--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$count ${count == 1 ? 'copy' : 'copies'}'),
                IconButton(
                  tooltip: 'One more copy',
                  onPressed: count < board.size
                      ? () => update(() => count++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Priority delivery'),
              value: priority,
              onChanged: (value) => update(() => priority = value),
            ),
            _PrimaryAction(
              label: 'Send helper',
              icon: Icons.outbound_outlined,
              onPressed: () {
                Navigator.pop(sheet);
                _change(
                  () => _result(
                    run.requestDigit(digit, count: count, priority: priority),
                    'No more copies of $digit are needed.',
                    'Requested $digit × $count.',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _rules() {
    _sheet<void>(
      'Board rules',
      (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use each digit from 1 to ${board.size} once in every row, column and outlined region.',
          ),
          if (board.fog.name != 'none')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(switch (board.fog.name) {
                'trail' =>
                  'Trail fog. Each correct placement lights the next part of the trail.',
                'linked' =>
                  'Linked torches. Complete the linked placements to light the next patch.',
                _ =>
                  'Halo fog. A torch lights the cells around a correct placement.',
              }),
            ),
          if (board.gravity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Gravity moves the loose tray digits. Use the four arrows, W A S D, or tilt a supported phone.',
              ),
            ),
          for (final kind in board.rules.map((rule) => rule.kind).toSet())
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(kind.label),
              subtitle: Text(kind.explanation),
              trailing: IconButton(
                tooltip: 'Show ${kind.label} on the board',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () {
                  Navigator.pop(sheet);
                  setState(() {
                    _allMarks = false;
                    _highlightRule = kind.name;
                    _feedback =
                        'Showing ${kind.label}. Open Rules to restore all markings.';
                  });
                },
              ),
            ),
          if (!_allMarks)
            TextButton(
              onPressed: () {
                Navigator.pop(sheet);
                setState(() {
                  _allMarks = true;
                  _feedback = null;
                });
              },
              child: const Text('Show all markings'),
            ),
        ],
      ),
    );
  }

  void _hint() {
    var explain = false;
    _sheet<void>(
      'Hint',
      (_) => StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              run.hint(explain: explain) ??
                  'Look for a row, column or region with a single missing value.',
            ),
            if (!explain)
              TextButton(
                onPressed: () => update(() => explain = true),
                child: const Text('Explain the hint'),
              ),
          ],
        ),
      ),
    );
  }

  void _cellSelector() {
    var row = (_cell ?? 0) ~/ board.size;
    _sheet<void>(
      'Select square',
      (sheet) => StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: row,
              decoration: const InputDecoration(labelText: 'Row'),
              items: List.generate(
                board.size,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text('Row ${index + 1}'),
                ),
              ),
              onChanged: (index) {
                if (index != null) update(() => row = index);
              },
            ),
            for (var column = 0; column < board.size; column++)
              ListTile(
                title: Text('Column ${column + 1}'),
                subtitle: Text(switch (run.visible.contains(
                  row * board.size + column,
                )) {
                  false => 'In fog',
                  true =>
                    run.cells[row * board.size + column] == 0
                        ? 'Empty'
                        : '${run.cells[row * board.size + column]}',
                }),
                onTap: () {
                  Navigator.pop(sheet);
                  _onCell(row * board.size + column);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _map() {
    _sheet<void>(
      'Campaign map',
      (sheet) => Column(
        children: [
          for (final entry in run.availableBoards)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.id == board.id ? Icons.my_location : Icons.grid_on,
              ),
              title: Text(entry.title),
              subtitle: Text(
                '${entry.size}×${entry.size}${entry.rules.isEmpty ? '' : ' · ${entry.rules.map((rule) => rule.kind.label).toSet().join(', ')}'}',
              ),
              trailing: entry.id == board.id
                  ? null
                  : const Icon(Icons.chevron_right),
              enabled: entry.id != board.id,
              onTap: () {
                Navigator.pop(sheet);
                _change(() {
                  _releaseOffer();
                  _result(
                    run.openBoard(entry.id),
                    'This encounter is still locked.',
                  );
                });
              },
            ),
        ],
      ),
    );
  }

  void _settlement() {
    _sheet<void>(
      'Colony jobs',
      (sheet) => ColonyManagementScreen(
        campaign: run,
        embedded: true,
        onChanged: () => _change(() {}),
        onOpenCreator: widget.onOpenCreator == null
            ? null
            : () {
                Navigator.pop(sheet);
                widget.onOpenCreator!();
              },
        onOpenProfile: widget.onOpenProfile == null
            ? null
            : (creature) {
                Navigator.pop(sheet);
                widget.onOpenProfile!(creature);
              },
      ),
    );
  }

  void _more() {
    final mapUnlocked = run.mapUnlocked;
    _sheet<void>(
      'Board options',
      (sheet) => Column(
        children: [
          if (mapUnlocked)
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Campaign map'),
              onTap: () {
                Navigator.pop(sheet);
                _map();
              },
            ),
          if (run.libraryChallenge)
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Return to campaign'),
              onTap: () {
                Navigator.pop(sheet);
                _change(() => run.returnToCampaign());
              },
            ),
          if (run.learnedRules.isNotEmpty || run.learnedFog.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Rule Almanac'),
              onTap: () {
                Navigator.pop(sheet);
                _almanac();
              },
            ),
          if (run.producerLimit > 0)
            ListTile(
              leading: const Icon(Icons.biotech),
              title: const Text('Digit production'),
              onTap: () {
                Navigator.pop(sheet);
                _production();
              },
            ),
          if (widget.onOpenSettings != null)
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(sheet);
                widget.onOpenSettings!();
              },
            ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Restart this board'),
            onTap: () {
              Navigator.pop(sheet);
              _confirmRetry();
            },
          ),
        ],
      ),
    );
  }

  void _almanac() => _sheet<void>(
    'Rule Almanac',
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in run.learnedRules)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(rule.label),
            subtitle: Text(rule.explanation),
            trailing: run.masteredRules.contains(rule)
                ? const Icon(Icons.verified_outlined, semanticLabel: 'Mastered')
                : null,
          ),
        if (run.learnedFog.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fog of war'),
            subtitle: Text(
              run.learnedFog
                  .map(
                    (fog) => switch (fog) {
                      FogKind.halo => 'Halo',
                      FogKind.trail => 'Trail',
                      FogKind.linked => 'Linked torches',
                      _ => '',
                    },
                  )
                  .join(' · '),
            ),
          ),
        for (final expedition in campaignBoards.where(
          (item) => item.expedition && run.clearedBoards.contains(item.id),
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(expedition.title),
            subtitle: Text(
              run.almanacCrew(expedition.id).isEmpty
                  ? 'Expedition cleared'
                  : 'Crew · ${run.almanacCrew(expedition.id).join(', ')}',
            ),
          ),
      ],
    ),
  );

  void _confirmRetry() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restart this board?'),
        content: const Text(
          'The encounter returns to its starting layout. Your colony and earned rewards are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) _change(_retry);
  }

  void _production() => _sheet<void>(
    'Digit production',
    (_) => _ProductionPanel(
      campaign: run,
      onChanged: () => _change(() {}),
      initialDigit: _cell == null ? null : run.cells[_cell!],
    ),
  );

  void _prestige() {
    var quick = false;
    var charter = Charter.standard;
    String? companion = run.companionChoice;
    final upgrades = <LegacyUpgrade, int>{};
    final total = run.legacy + run.prestigePayout;
    final companions = {
      for (final creature in run.creatures) creature.id: creature,
      if (run.companion case final Creature creature) creature.id: creature,
    };
    int cost(LegacyUpgrade upgrade, int rank) {
      final current = run.legacyUpgrades[upgrade] ?? 0;
      return run
          .legacyUpgradeCosts(upgrade)
          .skip(current)
          .take(rank - current)
          .fold(0, (sum, price) => sum + price);
    }

    int spent() => upgrades.entries.fold(
      0,
      (sum, entry) => sum + cost(entry.key, entry.value),
    );
    if (!companions.containsKey(companion)) companion = null;
    _sheet<void>(
      'Start a new colony',
      (sheet) => StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Archive this colony and earn ${run.prestigePayout} Legacy. Your Library and learned rules carry forward.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start at 5×5'),
              subtitle: const Text('Take the starter amoeba and 6 RNA.'),
              value: quick,
              onChanged: (value) => update(() => quick = value),
            ),
            DropdownButtonFormField<Charter>(
              initialValue: charter,
              decoration: const InputDecoration(labelText: 'Charter'),
              items: [
                for (final option in Charter.values)
                  DropdownMenuItem(
                    value: option,
                    child: Text(_charterName(option)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) update(() => charter = value);
              },
            ),
            Text(switch (charter.name) {
              'oneHelper' =>
                'The amoeba handles every job. A retained companion can still visit.',
              'handOrders' => 'You issue every restock request.',
              'noProducers' => 'Earn DNA and RNA through puzzle clears.',
              _ => 'Use the standard colony rules.',
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: companion ?? '',
              decoration: const InputDecoration(labelText: 'Keep a companion'),
              items: [
                const DropdownMenuItem(value: '', child: Text('No companion')),
                for (final creature in companions.values)
                  DropdownMenuItem(
                    value: creature.id,
                    child: Text(creature.name),
                  ),
              ],
              onChanged: (value) =>
                  update(() => companion = value == '' ? null : value),
            ),
            const SizedBox(height: 8),
            Text(
              '${total - spent()} Legacy available',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final upgrade in LegacyUpgrade.values)
              Builder(
                builder: (_) {
                  final current = run.legacyUpgrades[upgrade] ?? 0;
                  final prices = run.legacyUpgradeCosts(upgrade);
                  final name = switch (upgrade) {
                    LegacyUpgrade.shorterRoutes => 'Shorter routes',
                    LegacyUpgrade.warmStart => 'Warm start',
                    LegacyUpgrade.extraNest => 'Extra nest',
                  };
                  final selected = upgrades[upgrade] ?? current;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(switch (upgrade) {
                      LegacyUpgrade.shorterRoutes =>
                        'Rank $selected · ${selected * 10}% faster digit trips',
                      LegacyUpgrade.warmStart => 'An RNA producer after 4×4.',
                      LegacyUpgrade.extraNest =>
                        'One more housing slot after 5×5.',
                    }),
                    trailing: DropdownButton<int>(
                      value: selected,
                      items: [
                        for (var rank = current; rank <= prices.length; rank++)
                          DropdownMenuItem(
                            value: rank,
                            enabled:
                                cost(upgrade, rank) <=
                                total - spent() + cost(upgrade, selected),
                            child: Text(
                              rank == current
                                  ? 'Keep rank $rank'
                                  : 'Rank $rank · ${cost(upgrade, rank)}',
                            ),
                          ),
                      ],
                      onChanged: (rank) {
                        if (rank != null)
                          update(() => upgrades[upgrade] = rank);
                      },
                    ),
                  );
                },
              ),
            _PrimaryAction(
              label: 'Archive and begin',
              icon: Icons.eco_outlined,
              onPressed: () {
                _change(() {
                  final success = run.prestige(
                    quick: quick,
                    charter: charter,
                    companionId: companion,
                    keepSelectedCompanion: false,
                    upgrades: upgrades,
                  );
                  _result(
                    success,
                    'Check your Legacy balance and selected upgrades.',
                  );
                  if (success) Navigator.pop(sheet);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _charterName(Charter charter) => switch (charter.name) {
    'oneHelper' => 'One Helper',
    'handOrders' => 'Hand Orders',
    'noProducers' => 'No Producers',
    _ => 'Standard',
  };
}

class ColonyManagementScreen extends StatefulWidget {
  const ColonyManagementScreen({
    super.key,
    required this.campaign,
    required this.onChanged,
    this.onOpenCreator,
    this.onOpenProfile,
    this.embedded = false,
  });

  final Campaign campaign;
  final VoidCallback onChanged;
  final VoidCallback? onOpenCreator;
  final ValueChanged<Creature>? onOpenProfile;
  final bool embedded;

  @override
  State<ColonyManagementScreen> createState() => _ColonyManagementScreenState();
}

class _ColonyManagementScreenState extends State<ColonyManagementScreen> {
  Campaign get run => widget.campaign;
  String? _message;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    if (widget.embedded) {
      _refresh = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void _change(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = run.availableBoards.map((board) => board.id).toSet();
    final designer = unlocked.contains('growth-6');
    final village = unlocked.contains('growth-7');
    final civilization = run.projects.any(
      (project) => project.id == 'meeting-hall',
    );
    final projects = run.projects;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            'The colony',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _Resource(label: 'DNA', count: run.dna, icon: Icons.biotech),
            _Resource(
              label: 'RNA',
              count: run.rna,
              icon: Icons.bubble_chart_outlined,
            ),
            if (run.legacy > 0)
              _Resource(
                label: 'Legacy',
                count: run.legacy,
                icon: Icons.auto_awesome_outlined,
              ),
          ],
        ),
        if (run.creatures.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Place the three 4s in the opening board to hatch your first helper.',
            ),
          ),
        if (run.creatures.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading(
                  'Workers · ${run.creatures.length}/${run.housing} housed',
                ),
                for (final creature in run.creatures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CreatureSprite(
                      creature: creature,
                      size: 40,
                      reducedMotion: MediaQuery.disableAnimationsOf(context),
                    ),
                    title: Text(creature.name),
                    subtitle: Text('Favorite ${creature.favorite}'),
                    onTap: widget.onOpenProfile == null
                        ? null
                        : () => widget.onOpenProfile!(creature),
                    trailing: designer
                        ? PopupMenuButton<String>(
                            tooltip: 'Assign ${creature.name}',
                            icon: const Icon(Icons.assignment_outlined),
                            onSelected: (value) => _change(() {
                              final task = TaskKind.values
                                  .where((job) => job.name == value)
                                  .firstOrNull;
                              run.assign(creature.id, task);
                              _message =
                                  '${creature.name} assigned to ${_jobName(task).toLowerCase()}.';
                            }),
                            itemBuilder: (_) => [
                              for (final task in <TaskKind?>[
                                null,
                                ...TaskKind.values,
                              ])
                                PopupMenuItem(
                                  value: task?.name ?? 'flexible',
                                  child: Text(_jobName(task)),
                                ),
                            ],
                          )
                        : null,
                  ),
                if (designer &&
                    run.charter != Charter.oneHelper &&
                    widget.onOpenCreator != null)
                  _PrimaryAction(
                    label: 'Design a creature',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: widget.onOpenCreator!,
                  ),
                if (run.jobs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeading('Deliveries'),
                  for (final job in run.jobs)
                    Text(
                      '${_jobName(job.kind)}${job.digit == null ? '' : ' ${job.digit} × ${job.count}'}',
                    ),
                ],
              ],
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(_message!, style: const TextStyle(color: Hum.focus)),
            ),
          ),
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeading('Construction'),
                for (final project in projects)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(project.name),
                    subtitle: Text(
                      run.buildings.contains(project.id)
                          ? 'Built'
                          : 'Gather letter pieces',
                    ),
                    children: [
                      if (run.buildings.contains(project.id))
                        SettlementProjectPreview(
                          glyphs: run.buildingGlyphs[project.id]!,
                          complete: true,
                        ),
                      if (!run.buildings.contains(project.id) &&
                          run.stockedGlyphs.isNotEmpty)
                        SettlementProjectPreview(
                          glyphs: [
                            for (final role in project.requirements.keys)
                              ...run.stockedGlyphs
                                  .where((glyph) => glyph.role == role)
                                  .take(project.requirements[role]!),
                          ],
                          complete: false,
                        ),
                      if (!run.buildings.contains(project.id))
                        SettlementMaterialNotice(
                          available: starterGlyphs.where(
                            (glyph) => !run.claimedGlyphs.contains(glyph.id),
                          ),
                          remaining: {
                            for (final role in project.requirements.keys)
                              role: run.materialDemand(project.id, role),
                          },
                          onSelect: (glyph) => _change(() {
                            final accepted = run.requestMaterial(
                              project.id,
                              glyph.role,
                              glyphId: glyph.index == null ? null : glyph.id,
                            );
                            _message = accepted
                                ? 'Helper dispatched for ${glyph.role.name}.'
                                : 'This piece is already covered.';
                          }),
                        ),
                      for (final entry in project.requirements.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            entry.key.name == 'roof'
                                ? 'Roof pieces'
                                : '${entry.key.name}s',
                          ),
                          subtitle: Text(
                            '${run.materials[entry.key] ?? 0} / ${entry.value}',
                          ),
                          trailing: TextButton(
                            onPressed:
                                run.materialDemand(project.id, entry.key) == 0
                                ? null
                                : () => _change(() {
                                    final accepted = run.requestMaterial(
                                      project.id,
                                      entry.key,
                                    );
                                    _message = accepted
                                        ? 'Helper dispatched for ${entry.key.name}.'
                                        : 'This piece is already covered.';
                                  }),
                            child: const Text('Gather'),
                          ),
                        ),
                      if (!run.buildings.contains(project.id))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _PrimaryAction(
                            label: 'Build ${project.name}',
                            icon: Icons.handyman_outlined,
                            onPressed: run.canBuild(project.id)
                                ? () => _change(() {
                                    final accepted = run.build(project.id);
                                    _message = accepted
                                        ? '${project.name} is built.'
                                        : 'Gather the remaining materials.';
                                  })
                                : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        if (run.producerLimit > 0) ...[
          const SizedBox(height: 12),
          _Panel(
            child: _ProductionPanel(campaign: run, onChanged: widget.onChanged),
          ),
        ],
        if (village && run.charter != Charter.handOrders) ...[
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeading('Restock targets'),
                const Text('Keep one or two copies ready in the tray.'),
                for (var digit = 1; digit <= boardSize; digit++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Digit $digit'),
                    trailing: DropdownButton<int>(
                      value: math.min(
                        run.restock[digit] ?? 0,
                        run.buildings.contains('storehouse') ? 3 : 2,
                      ),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('Off')),
                        const DropdownMenuItem(value: 1, child: Text('1')),
                        const DropdownMenuItem(value: 2, child: Text('2')),
                        if (run.buildings.contains('storehouse'))
                          const DropdownMenuItem(value: 3, child: Text('3')),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          _change(() => run.setRestock(digit, value));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (civilization) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<SettlementPolicy>(
            initialValue: run.policy,
            decoration: const InputDecoration(labelText: 'Settlement policy'),
            items: [
              for (final policy in SettlementPolicy.values)
                DropdownMenuItem(
                  value: policy,
                  child: Text(switch (policy.name) {
                    'sharedReserves' => 'Shared reserves',
                    'sharedCrews' => 'Shared crews',
                    _ => 'Independent',
                  }),
                ),
            ],
            onChanged: (value) {
              if (value != null) _change(() => run.setPolicy(value));
            },
          ),
        ],
        if (designer) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Antics>(
            initialValue: run.antics,
            decoration: const InputDecoration(labelText: 'Creature antics'),
            items: [
              for (final mode in Antics.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(switch (mode.name) {
                    'full' => 'Full antics',
                    'reactions' => 'Reactions only',
                    _ => 'Off',
                  }),
                ),
            ],
            onChanged: (value) {
              if (value != null) _change(() => run.setAntics(value));
            },
          ),
        ],
      ],
    );
    if (widget.embedded) return content;
    return SingleChildScrollView(
      key: const PageStorageKey('colony-management-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      ),
    );
  }

  int get boardSize => run.board.size;

  String _jobName(TaskKind? task) => switch (task?.name) {
    'digit' => 'Digit deliveries',
    'torch' => 'Torch deliveries',
    'building' => 'Construction',
    _ => 'Flexible',
  };
}

class _ProductionPanel extends StatefulWidget {
  const _ProductionPanel({
    required this.campaign,
    required this.onChanged,
    this.initialDigit,
  });

  final Campaign campaign;
  final VoidCallback onChanged;
  final int? initialDigit;

  @override
  State<_ProductionPanel> createState() => _ProductionPanelState();
}

class _ProductionPanelState extends State<_ProductionPanel> {
  late int _digit;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _digit = math.max(1, widget.initialDigit ?? widget.campaign.board.size);
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.campaign;
    final digit = math.min(_digit, run.board.size);
    final current = run.producers[digit];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          'Producers · ${run.producers.length}/${run.producerLimit} active',
        ),
        for (final producer in run.producers.values)
          Text(
            '${producer.digit} produces ${producer.rank} ${producer.type.name.toUpperCase()} every ${producer.type.name == 'rna' ? 10 : 40} seconds.',
          ),
        if (run.producerLimit > 0) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey(run.board.size),
            initialValue: digit,
            decoration: const InputDecoration(labelText: 'Upgrade digit'),
            items: [
              for (var value = 1; value <= run.board.size; value++)
                DropdownMenuItem(value: value, child: Text('$value')),
            ],
            onChanged: (value) {
              if (value != null)
                setState(() {
                  _digit = value;
                  _feedback = null;
                });
            },
          ),
          for (final type in ProducerType.values)
            if ((type != ProducerType.dna ||
                    run.clearedBoards.contains('growth-5')) &&
                (current == null || current.type == type))
              Builder(
                builder: (context) {
                  final rank = (current?.rank ?? 0) + 1;
                  final price = run.producerCost(type, rank);
                  final visibleClue = run.cells.asMap().entries.any(
                    (item) =>
                        item.value == digit &&
                        run.visible.contains(item.key) &&
                        (run.cleared || run.fixed.contains(item.key)),
                  );
                  final canBuy =
                      run.charter != Charter.noProducers &&
                      visibleClue &&
                      rank <= run.producerRankLimit &&
                      run.dna >= price.dna &&
                      run.rna >= price.rna &&
                      (current != null ||
                          run.producers.length < run.producerLimit);
                  return ListTile(
                    title: Text(
                      '${type.name.toUpperCase()} producer · rank $rank',
                    ),
                    subtitle: Text(
                      [
                        if (price.dna > 0) '${price.dna} DNA',
                        '${price.rna} RNA',
                      ].join(' + '),
                    ),
                    contentPadding: EdgeInsets.zero,
                    trailing: TextButton(
                      onPressed: canBuy
                          ? () {
                              final result = run.upgradeDigit(digit, type);
                              setState(
                                () => _feedback = result
                                    ? 'Producer upgraded.'
                                    : 'That upgrade is still locked.',
                              );
                              widget.onChanged();
                            }
                          : null,
                      child: const Text('Upgrade'),
                    ),
                  );
                },
              ),
        ],
        if (_feedback != null)
          Semantics(
            liveRegion: true,
            child: Text(_feedback!, style: const TextStyle(color: Hum.focus)),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Hum.board,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Hum.grid.withValues(alpha: .44)),
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

class _Resource extends StatelessWidget {
  const _Resource({
    required this.label,
    required this.count,
    required this.icon,
  });
  final String label;
  final int count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count $label',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Hum.focus),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: Hum.digitFont,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? null
            : states.contains(WidgetState.pressed)
            ? Hum.torch
            : Hum.pear,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : Hum.ink,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? Hum.focus
              : Hum.pearEdge,
          width: states.contains(WidgetState.focused) ? 3 : 1,
        ),
      ),
      elevation: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.disabled)
            ? 0
            : 2,
      ),
      shadowColor: const WidgetStatePropertyAll(Hum.pearEdge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}

class _DigitControl extends StatefulWidget {
  const _DigitControl({
    super.key,
    required this.data,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onDrag,
    this.count,
    this.offered = false,
  });
  final BoardDrag data;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onDrag;
  final int? count;
  final bool offered;
  @override
  State<_DigitControl> createState() => _DigitControlState();
}

class _DigitControlState extends State<_DigitControl> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final face = BoardDigitFace(
      value: widget.data.value!,
      selected: widget.selected || _focused,
      offer: widget.offered,
      footer: widget.count == null ? null : '×${widget.count}',
    );
    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Draggable<BoardDrag>(
          data: widget.data,
          maxSimultaneousDrags: 1,
          onDragStarted: () => widget.onDrag(true),
          onDragEnd: (_) => widget.onDrag(false),
          feedback: BoardDigitFace(value: widget.data.value!, selected: true),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onTap,
              onFocusChange: (value) => setState(() => _focused = value),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutsideClues extends StatelessWidget {
  const _OutsideClues({
    super.key,
    required this.size,
    required this.marks,
    required this.child,
  });
  final int size;
  final List<BoardMark> marks;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edges = <String, Map<int, List<BoardMark>>>{};
    for (final mark in marks) {
      if (!['sandwich', 'xSum', 'xSums'].contains(mark.kind) ||
          mark.cells.length < 2)
        continue;
      final first = mark.cells.first;
      final change = mark.cells[1] - first;
      final edge = switch (change) {
        1 => 'left',
        -1 => 'right',
        _ => change > 0 ? 'top' : 'bottom',
      };
      final position = change.abs() == 1 ? first ~/ size : first % size;
      (edges[edge] ??= {}).putIfAbsent(position, () => []).add(mark);
    }
    if (edges.isEmpty) return child;
    const gutter = 28.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = edges.containsKey('left') ? gutter : 0.0;
        final right = edges.containsKey('right') ? gutter : 0.0;
        final top = edges.containsKey('top') ? gutter : 0.0;
        final bottom = edges.containsKey('bottom') ? gutter : 0.0;
        final width = constraints.maxWidth - left - right;
        final step = width / size;
        return SizedBox(
          width: constraints.maxWidth,
          height: width + top + bottom,
          child: Stack(
            children: [
              Positioned(
                top: top,
                left: left,
                width: width,
                height: width,
                child: child,
              ),
              for (final entry in edges.entries)
                for (final clue in entry.value.entries)
                  Positioned(
                    left: switch (entry.key) {
                      'left' => 0,
                      'right' => width + left,
                      _ => left + step * clue.key,
                    },
                    top: switch (entry.key) {
                      'top' => 0,
                      'bottom' => top + width,
                      _ => top + step * clue.key,
                    },
                    width: entry.key == 'left' || entry.key == 'right'
                        ? gutter
                        : step,
                    height: entry.key == 'left' || entry.key == 'right'
                        ? step
                        : gutter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final mark in clue.value)
                            Semantics(
                              label:
                                  '${mark.description} at ${entry.key} edge, ${entry.key == 'left' || entry.key == 'right' ? 'row' : 'column'} ${clue.key + 1}',
                              child: ExcludeSemantics(
                                child: Text(
                                  '${mark.kind == 'sandwich' ? 'S' : 'X'}${mark.value ?? ''}',
                                  style: const TextStyle(
                                    fontFamily: Hum.digitFont,
                                    color: Hum.focus,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferSprite extends StatelessWidget {
  const _OfferSprite({
    required this.offer,
    required this.onSelect,
    required this.onDrag,
    required this.child,
  });

  final DigitOffer? offer;
  final ValueChanged<DigitOffer> onSelect;
  final ValueChanged<bool> onDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active = offer;
    if (active == null) return child;
    return Draggable<BoardDrag>(
      data: BoardDrag.digit(active.digit, offerId: active.id),
      maxSimultaneousDrags: 1,
      feedback: BoardDigitFace(value: active.digit, offer: true),
      onDragStarted: () => onDrag(true),
      onDragEnd: (_) => onDrag(false),
      child: GestureDetector(onTap: () => onSelect(active), child: child),
    );
  }
}

class _WorkerTrip extends StatelessWidget {
  const _WorkerTrip({
    required this.trip,
    required this.reducedMotion,
    required this.child,
  });
  final String? trip;
  final bool reducedMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trip == null || reducedMotion) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trip),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      child: child,
      builder: (context, progress, sprite) => Transform.translate(
        offset: Offset(math.sin(progress * math.pi) * 13, 0),
        child: sprite,
      ),
    );
  }
}

class _CellReaction extends StatelessWidget {
  const _CellReaction({
    super.key,
    required this.boardSize,
    required this.index,
    required this.crew,
    required this.cheer,
    required this.reducedMotion,
  });
  final int boardSize;
  final int index;
  final List<Creature> crew;
  final bool cheer;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = constraints.maxWidth / boardSize;
          return Stack(
            children: [
              for (final (sequence, creature) in crew.indexed)
                Positioned(
                  left:
                      (index % boardSize + (sequence.isEven ? .02 : .63)) *
                      step,
                  top: (index ~/ boardSize + (sequence < 2 ? .70 : .00)) * step,
                  child: _ReactionSprite(
                    creature: creature,
                    extent: step * .32,
                    cheer: cheer,
                    reducedMotion: reducedMotion,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _TrayReaction extends StatelessWidget {
  const _TrayReaction({
    super.key,
    required this.crew,
    required this.digit,
    required this.cheer,
    required this.reducedMotion,
  });
  final List<Creature> crew;
  final int digit;
  final bool cheer;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => Semantics(
    label: cheer
        ? '${crew.length} helpers gathered for $digit'
        : 'A helper inspected $digit',
    child: ExcludeSemantics(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final creature in crew)
            _ReactionSprite(
              creature: creature,
              extent: 30,
              cheer: cheer,
              reducedMotion: reducedMotion,
            ),
          Text(
            '$digit',
            style: const TextStyle(
              fontFamily: Hum.digitFont,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReactionSprite extends StatelessWidget {
  const _ReactionSprite({
    required this.creature,
    required this.extent,
    required this.cheer,
    required this.reducedMotion,
  });
  final Creature creature;
  final double extent;
  final bool cheer;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 340),
    curve: Curves.easeOutCubic,
    child: CreatureSprite(
      key: ValueKey('reacting-${creature.id}'),
      creature: creature,
      size: extent,
      reducedMotion: reducedMotion,
      pose: cheer ? CreaturePose.cheer : CreaturePose.puzzled,
    ),
    builder: (context, travel, child) => Transform.translate(
      offset: Offset(-extent * travel, extent * travel),
      child: child,
    ),
  );
}
