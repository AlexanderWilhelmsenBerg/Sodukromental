import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'creatures.dart';
import 'library_artwork.dart';
import 'library_models.dart';
import 'library_player_controller.dart';
import 'library_store.dart';

class LibraryPlayer extends StatefulWidget {
  const LibraryPlayer({
    super.key,
    required this.store,
    required this.puzzle,
    this.torchbearer,
    this.reduceMotion = false,
  });
  final LibraryStore store;
  final LibraryDownload puzzle;
  final ValueListenable<Creature?>? torchbearer;
  final bool reduceMotion;

  @override
  State<LibraryPlayer> createState() => _LibraryPlayerState();
}

class _LibraryPlayerState extends State<LibraryPlayer>
    with WidgetsBindingObserver {
  late final LibraryPlayerController controller;
  final _focus = FocusNode(debugLabel: 'Library player');
  final _boardTransform = TransformationController();
  Timer? _saveTimer;
  Timer? _clockTimer;
  bool _showCounts = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.puzzle.entry;
    controller = LibraryPlayerController(
      puzzle: widget.puzzle,
      save: widget.store.getSave(entry.id, entry.revision),
    );
    controller.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !controller.paused && !controller.replaying) {
        controller.tick();
        setState(() {});
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 120), _persist);
  }

  void _persist() {
    if (!mounted) return;
    final entry = widget.puzzle.entry;
    unawaited(
      widget.store.save(entry.id, entry.revision, controller.snapshot()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _persist();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _clockTimer?.cancel();
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    controller
      ..removeListener(_changed)
      ..dispose();
    _focus.dispose();
    _boardTransform.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (control && key == LogicalKeyboardKey.keyZ) {
      HardwareKeyboard.instance.isShiftPressed
          ? controller.redo()
          : controller.undo();
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyA) {
      controller.selectAll();
      return KeyEventResult.handled;
    }
    final d = controller.definition;
    final current = controller.selection.isEmpty
        ? d.playable.first
        : controller.selection.last;
    final row = current ~/ d.width;
    final column = current % d.width;
    final next = switch (key) {
      LogicalKeyboardKey.arrowUp => math.max(0, row - 1) * d.width + column,
      LogicalKeyboardKey.arrowDown =>
        math.min(d.height - 1, row + 1) * d.width + column,
      LogicalKeyboardKey.arrowLeft => row * d.width + math.max(0, column - 1),
      LogicalKeyboardKey.arrowRight =>
        row * d.width + math.min(d.width - 1, column + 1),
      _ => null,
    };
    if (next != null) {
      controller.select(
        next.toInt(),
        extend: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.deselect();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      controller.erase();
      return KeyEventResult.handled;
    }
    if (!controller.alphabetic) {
      final digit = int.tryParse(key.keyLabel);
      if (digit != null) {
        controller.apply('$digit');
        return KeyEventResult.handled;
      }
    } else if (RegExp(r'^[A-Za-z]$').hasMatch(key.keyLabel)) {
      controller.apply(key.keyLabel);
      return KeyEventResult.handled;
    }
    final mode = switch (key) {
      LogicalKeyboardKey.keyV => LibraryInputMode.value,
      LogicalKeyboardKey.keyC => LibraryInputMode.corner,
      LogicalKeyboardKey.keyM => LibraryInputMode.center,
      LogicalKeyboardKey.keyL => LibraryInputMode.letter,
      LogicalKeyboardKey.keyP => LibraryInputMode.pen,
      _ => null,
    };
    if (mode != null) {
      controller.setMode(mode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.puzzle.entry;
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final base = Theme.of(context);
    return Theme(
      data: dark
          ? ThemeData.dark(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: base.colorScheme.primary,
                brightness: Brightness.dark,
              ),
            )
          : base,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title),
              Text(
                _time(controller.elapsedMilliseconds),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: controller.paused ? 'Resume timer' : 'Pause timer',
              onPressed: controller.togglePause,
              icon: Icon(controller.paused ? Icons.play_arrow : Icons.pause),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: controller.cursor > 0 && !controller.replaying
                  ? controller.undo
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed:
                  controller.cursor + 1 < controller.history.length &&
                      !controller.replaying
                  ? controller.redo
                  : null,
              icon: const Icon(Icons.redo),
            ),
            PopupMenuButton<String>(
              tooltip: 'Player options',
              onSelected: _menu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rules', child: Text('Rules sheet')),
                const PopupMenuItem(value: 'help', child: Text('Input help')),
                PopupMenuItem(
                  value: 'counts',
                  child: Text(
                    _showCounts ? 'Hide keypad counts' : 'Show keypad counts',
                  ),
                ),
                const PopupMenuItem(
                  value: 'replay',
                  child: Text('Replay solve'),
                ),
                const PopupMenuItem(
                  value: 'calculator',
                  child: Text('Cage calculator'),
                ),
                const PopupMenuItem(
                  value: 'restart',
                  child: Text('Restart attempt'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Focus(
            autofocus: true,
            focusNode: _focus,
            onKeyEvent: _key,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final boardExtent = math.min(
                  bounds.maxWidth - 16,
                  math.min(620.0, bounds.maxHeight * .60),
                );
                final definition = controller.definition;
                final artworkMargin = libraryArtworkMargin(
                  widget.puzzle,
                  definition,
                );
                return ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (controller.paused && !controller.replaying)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Attempt paused')),
                        ),
                      ),
                    Center(
                      child: SizedBox(
                        width: boardExtent,
                        height:
                            boardExtent *
                            (definition.height + artworkMargin * 2) /
                            (definition.width + artworkMargin * 2),
                        child: InteractiveViewer(
                          transformationController: _boardTransform,
                          minScale: .65,
                          maxScale: 4,
                          boundaryMargin: const EdgeInsets.all(120),
                          child: _NativeLibraryBoard(
                            controller: controller,
                            puzzle: widget.puzzle,
                            torchbearer: widget.torchbearer,
                            reduceMotion: widget.reduceMotion,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Keypad(controller: controller, showCounts: _showCounts),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Zoom out',
                          onPressed: () => _zoomBoard(.8),
                          icon: const Icon(Icons.zoom_out),
                        ),
                        TextButton.icon(
                          onPressed: _fitBoard,
                          icon: const Icon(Icons.fit_screen),
                          label: const Text('Fit board'),
                        ),
                        IconButton(
                          tooltip: 'Zoom in',
                          onPressed: () => _zoomBoard(1.25),
                          icon: const Icon(Icons.zoom_in),
                        ),
                      ],
                    ),
                    _ToolBar(controller: controller),
                    if (_selectedSum(controller) case final sum?)
                      Text(
                        'Selected-cell sum: $sum',
                        semanticsLabel: 'Selected cell sum $sum',
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: const Text('Add selection'),
                          selected: controller.addSelection,
                          onSelected: controller.setAddSelection,
                        ),
                        ActionChip(
                          label: const Text('Select all'),
                          onPressed: controller.selectAll,
                        ),
                        ActionChip(
                          label: const Text('Invert'),
                          onPressed: controller.invertSelection,
                        ),
                        ActionChip(
                          label: const Text('Deselect'),
                          onPressed: controller.deselect,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.backspace_outlined),
                          label: const Text('Erase layer'),
                          onPressed: controller.erase,
                        ),
                        ActionChip(
                          label: const Text('Choose cell'),
                          onPressed: _chooseCell,
                        ),
                        ActionChip(
                          label: const Text('Clue inspector'),
                          onPressed: _inspectClues,
                        ),
                        if (controller.mode == LibraryInputMode.pen)
                          ActionChip(
                            label: const Text(
                              'Pen segment between selected cells',
                            ),
                            onPressed: controller.selection.length >= 2
                                ? () => _accessiblePen(false)
                                : null,
                          ),
                        if (controller.mode == LibraryInputMode.pen)
                          ActionChip(
                            label: const Text('Edge mark beside selected cell'),
                            onPressed: controller.selection.isNotEmpty
                                ? () => _accessiblePen(true)
                                : null,
                          ),
                        FilledButton.tonal(
                          onPressed: _check,
                          child: const Text('Check board'),
                        ),
                      ],
                    ),
                    if (controller.checkMessage != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Last check: ${controller.checkMessage!}',
                          ),
                        ),
                      ),
                    Text(
                      widget.puzzle.finalCheck
                          ? 'Check scope: implemented constraints and authorized final grid.'
                          : widget.puzzle.manual
                          ? 'Check scope: implemented constraints; finish is manual.'
                          : 'Check scope: implemented local constraints.',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _check() {
    final result = controller.check();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        action: result.manual
            ? SnackBarAction(
                label: 'Mark complete',
                onPressed: controller.markManualComplete,
              )
            : null,
      ),
    );
    _persist();
  }

  void _zoomBoard(double factor) {
    final current = _boardTransform.value.getMaxScaleOnAxis();
    final scale = (current * factor).clamp(.65, 4.0);
    _boardTransform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _fitBoard() => _boardTransform.value = Matrix4.identity();

  Future<void> _chooseCell() async {
    final cell = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        children: [
          for (final index in controller.definition.playable)
            ListTile(
              title: Text(
                'Row ${index ~/ controller.definition.width + 1}, column ${index % controller.definition.width + 1}',
              ),
              subtitle: Text(_cellDescription(controller, index)),
              onTap: () => Navigator.pop(context, index),
            ),
        ],
      ),
    );
    if (cell != null) controller.select(cell);
  }

  void _inspectClues() {
    final clues = _visibleClueDescriptions(
      widget.puzzle,
      controller.definition,
      controller.visible,
    );
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('Linear clue inspector')),
          if (clues.isEmpty)
            const ListTile(
              title: Text('No authored clues are currently visible.'),
            ),
          for (final clue in clues)
            ListTile(leading: const Icon(Icons.visibility), title: Text(clue)),
        ],
      ),
    );
  }

  void _accessiblePen(bool edge) {
    final width = controller.definition.width;
    final cells = controller.selection.toList();
    final first = cells.first;
    final a = LibraryStrokePoint(
      first % width + (edge ? 1 : .5),
      first ~/ width + (edge ? .2 : .5),
    );
    final second = cells.length > 1 ? cells[1] : first;
    final b = LibraryStrokePoint(
      second % width + (edge ? 1 : .5),
      second ~/ width + (edge ? .8 : .5),
    );
    controller.addStroke(
      LibraryStroke(points: [a, b], color: 'amber', snapped: true, edge: edge),
      freehand: false,
    );
  }

  void _menu(String action) {
    switch (action) {
      case 'rules':
        _sheet(
          'Puzzle rules',
          widget.puzzle.entry.rules.isEmpty
              ? 'No written rules were included.'
              : widget.puzzle.entry.rules,
        );
      case 'help':
        _sheet(
          'Input help',
          'Tap a cell to select it. Turn on Add selection for disjoint cells. Long press toggles one cell. V Value, C Corner, M Center, L Letter, P Pen. Ctrl+A selects all; Ctrl+Z/Shift+Ctrl+Z undo/redo; Delete erases the active layer. ABC / 123 changes keyboard input without changing selection.',
        );
      case 'counts':
        setState(() => _showCounts = !_showCounts);
      case 'replay':
        _replay();
      case 'calculator':
        _calculator();
      case 'restart':
        _restart();
    }
  }

  void _sheet(String title, String text) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      ),
    ),
  );

  Future<void> _restart() async {
    final okay =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restart this attempt?'),
            content: const Text(
              'Values, marks, strokes, replay history and timer for this attempt will be cleared.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restart'),
              ),
            ],
          ),
        ) ??
        false;
    if (okay) {
      controller.reset();
      _persist();
    }
  }

  void _replay() {
    controller.startReplay();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Replay solve'),
              Slider(
                value: controller.cursor.toDouble(),
                max: math.max(1, controller.history.length - 1).toDouble(),
                divisions: math.max(1, controller.history.length - 1),
                label: '${controller.cursor}',
                onChanged: (value) {
                  controller.seekReplay(value.round());
                },
              ),
              IconButton(
                tooltip: controller.replayPlaying
                    ? 'Pause replay'
                    : 'Play replay',
                onPressed: controller.toggleReplayPlay,
                icon: Icon(
                  controller.replayPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
              Text(
                'Step ${controller.cursor} of ${controller.history.length - 1} · fog and marks restored',
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to live attempt'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.closeReplay);
  }

  void _calculator() {
    var total = 6, count = 3, repeats = false;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final combinations = _combinations(
            controller.definition.symbols
                .map(int.tryParse)
                .whereType<int>()
                .toList(),
            count,
            total,
            repeats,
          );
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Killer cage calculator'),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total'),
                  onChanged: (value) =>
                      setSheet(() => total = int.tryParse(value) ?? total),
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cell count'),
                  onChanged: (value) =>
                      setSheet(() => count = int.tryParse(value) ?? count),
                ),
                SwitchListTile(
                  title: const Text('Repeats allowed'),
                  value: repeats,
                  onChanged: (value) => setSheet(() => repeats = value),
                ),
                Text(
                  combinations.isEmpty
                      ? 'No combinations.'
                      : combinations
                            .map((items) => items.join(', '))
                            .join('\n'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.controller});
  final LibraryPlayerController controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<LibraryInputMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: LibraryInputMode.value, label: Text('Value')),
        ButtonSegment(value: LibraryInputMode.corner, label: Text('Corner')),
        ButtonSegment(value: LibraryInputMode.center, label: Text('Center')),
        ButtonSegment(value: LibraryInputMode.letter, label: Text('Letter')),
        ButtonSegment(value: LibraryInputMode.color, label: Text('Color')),
        ButtonSegment(value: LibraryInputMode.pen, label: Text('Pen')),
        ButtonSegment(
          value: LibraryInputMode.freehand,
          label: Text('Freehand'),
        ),
      ],
      selected: {controller.mode},
      onSelectionChanged: (value) => controller.setMode(value.single),
    ),
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller, required this.showCounts});
  final LibraryPlayerController controller;
  final bool showCounts;
  @override
  Widget build(BuildContext context) {
    final symbols = controller.mode == LibraryInputMode.color
        ? const ['amber', 'blue', 'green', 'purple', 'red']
        : controller.alphabetic
        ? [for (var code = 65; code <= 90; code++) String.fromCharCode(code)]
        : controller.definition.symbols;
    final numericGrid =
        !controller.alphabetic && controller.mode != LibraryInputMode.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton(
              onPressed: controller.toggleAlphabet,
              child: Text(controller.alphabetic ? '123' : 'ABC'),
            ),
            if (controller.alphabetic)
              IconButton(
                tooltip: controller.upperCase
                    ? 'Use lowercase notes'
                    : 'Use uppercase notes',
                onPressed: controller.toggleCase,
                icon: Text(controller.upperCase ? 'A' : 'a'),
              ),
            if (showCounts && numericGrid)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Visible counts'),
              ),
          ],
        ),
        if (numericGrid)
          GridView.count(
            key: const ValueKey('library-numeric-keypad'),
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: math.max(
              48.0,
              MediaQuery.textScalerOf(context).scale(showCounts ? 40 : 24) + 8,
            ),
            children: [for (final symbol in symbols) _key(context, symbol)],
          )
        else
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final symbol in symbols)
                SizedBox.square(dimension: 48, child: _key(context, symbol)),
            ],
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String symbol) {
    final count = _visibleSymbolCount(controller, symbol);
    return Semantics(
      button: true,
      label: controller.mode == LibraryInputMode.color
          ? '$symbol color'
          : 'Digit $symbol, $count visible; enter as ${controller.mode.name}',
      child: Draggable<String>(
        data: symbol,
        feedback: Material(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 48,
            child: Center(child: Text(symbol)),
          ),
        ),
        child: FilledButton.tonal(
          key: ValueKey('library-key-$symbol'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            minimumSize: const Size(48, 48),
          ),
          onPressed: () => controller.apply(symbol),
          child: controller.mode == LibraryInputMode.color
              ? _ColorSwatch(symbol)
              : showCounts && !controller.alphabetic
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(symbol, textAlign: TextAlign.center),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$count visible',
                        key: ValueKey('symbol-count-$symbol'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                )
              : Text(symbol, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _NativeLibraryBoard extends StatefulWidget {
  const _NativeLibraryBoard({
    required this.controller,
    required this.puzzle,
    this.torchbearer,
    required this.reduceMotion,
  });
  final LibraryPlayerController controller;
  final LibraryDownload puzzle;
  final ValueListenable<Creature?>? torchbearer;
  final bool reduceMotion;
  @override
  State<_NativeLibraryBoard> createState() => _NativeLibraryBoardState();
}

class _NativeLibraryBoardState extends State<_NativeLibraryBoard> {
  final _stroke = <LibraryStrokePoint>[];
  @override
  Widget build(BuildContext context) {
    final c = widget.controller, d = c.definition;
    return LayoutBuilder(
      builder: (context, bounds) {
        final margin = libraryArtworkMargin(widget.puzzle, d);
        final step = bounds.maxWidth / (d.width + margin * 2);
        final origin = margin * step;
        return GestureDetector(
          onPanStart:
              c.mode == LibraryInputMode.pen ||
                  c.mode == LibraryInputMode.freehand
              ? (details) {
                  _stroke
                    ..clear()
                    ..add(
                      _point(
                        details.localPosition,
                        step,
                        c.mode == LibraryInputMode.pen,
                        margin,
                      ),
                    );
                }
              : (details) =>
                    _dragSelect(details.localPosition, step, margin, false),
          onPanUpdate:
              c.mode == LibraryInputMode.pen ||
                  c.mode == LibraryInputMode.freehand
              ? (details) {
                  setState(
                    () => _stroke.add(
                      _point(
                        details.localPosition,
                        step,
                        c.mode == LibraryInputMode.pen,
                        margin,
                      ),
                    ),
                  );
                }
              : (details) =>
                    _dragSelect(details.localPosition, step, margin, true),
          onPanEnd:
              c.mode == LibraryInputMode.pen ||
                  c.mode == LibraryInputMode.freehand
              ? (_) {
                  if (_stroke.length > 1)
                    c.addStroke(
                      LibraryStroke(
                        points: List.of(_stroke),
                        color: 'amber',
                        snapped: c.mode == LibraryInputMode.pen,
                      ),
                      freehand: c.mode == LibraryInputMode.freehand,
                    );
                  setState(_stroke.clear);
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _LibraryGround(
                  c,
                  margin,
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              if (widget.puzzle.refs.isNotEmpty || d.layers.isNotEmpty)
                IgnorePointer(
                  child: LibraryArtwork(
                    widget.puzzle,
                    definition: d,
                    visible: c.visible,
                  ),
                ),
              CustomPaint(
                painter: _FogPainter(
                  c,
                  Theme.of(context).brightness == Brightness.dark,
                  margin,
                ),
              ),
              if (d.hasFog && widget.torchbearer != null)
                ValueListenableBuilder<Creature?>(
                  valueListenable: widget.torchbearer!,
                  builder: (context, creature, _) => _TorchVisitor(
                    creature: creature,
                    controller: c,
                    reduceMotion: widget.reduceMotion,
                    margin: margin,
                  ),
                ),
              for (final cell in d.playable)
                Positioned(
                  left: origin + cell % d.width * step,
                  top: origin + cell ~/ d.width * step,
                  width: step,
                  height: step,
                  child: _Cell(controller: c, cell: cell),
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _StrokePainter(
                    [
                      ...c.position.pen,
                      ...c.position.freehand,
                      if (_stroke.isNotEmpty)
                        LibraryStroke(points: _stroke, color: 'amber'),
                    ],
                    d.width,
                    d.height,
                    margin,
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _LibraryGrid(
                    d,
                    margin,
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  LibraryStrokePoint _point(
    Offset point,
    double step,
    bool snap,
    double margin,
  ) => LibraryStrokePoint(
    snap
        ? (point.dx / step - margin).roundToDouble()
        : point.dx / step - margin,
    snap
        ? (point.dy / step - margin).roundToDouble()
        : point.dy / step - margin,
  );

  void _dragSelect(Offset point, double step, double margin, bool extend) {
    final d = widget.controller.definition;
    final col = (point.dx / step - margin).floor();
    final row = (point.dy / step - margin).floor();
    if (row < 0 || col < 0 || row >= d.height || col >= d.width) return;
    widget.controller.select(row * d.width + col, extend: extend);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.controller, required this.cell});
  final LibraryPlayerController controller;
  final int cell;
  @override
  Widget build(BuildContext context) {
    final value = controller.displayedValue(cell),
        ownCovered =
            controller.covered(cell) &&
            controller.position.values[cell] != null;
    final label = _cellDescription(controller, cell);
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => controller.editable(cell),
      onAcceptWithDetails: (details) {
        controller.select(cell);
        controller.apply(details.data);
      },
      builder: (context, candidates, rejected) => Semantics(
        key: ValueKey('cell-$cell'),
        button: true,
        selected: controller.selection.contains(cell),
        label: label,
        onTap: () => controller.select(cell),
        onLongPress: () => controller.select(cell, toggle: true),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => controller.select(cell, extend: controller.addSelection),
          onLongPress: () => controller.select(cell, toggle: true),
          onDoubleTap: value == null
              ? null
              : () => controller.selectMatching(value),
          child: Stack(
            children: [
              if (controller.position.colors[cell]?.isNotEmpty == true)
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final color in controller.position.colors[cell]!)
                        Expanded(
                          child: CustomPaint(painter: _ColorPattern(color)),
                        ),
                    ],
                  ),
                ),
              if (value != null)
                Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: ownCovered ? 24 : 25,
                      fontWeight: controller.given(cell)
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: ownCovered
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                          : null,
                    ),
                  ),
                ),
              if (controller.position.cornerMarks[cell]?.isNotEmpty == true)
                Positioned(
                  left: 2,
                  top: 1,
                  child: Text(
                    controller.position.cornerMarks[cell]!.join(' '),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              if (controller.position.centerMarks[cell]?.isNotEmpty == true)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Text(
                      controller.position.centerMarks[cell]!.join(' '),
                      style: const TextStyle(fontSize: 8),
                    ),
                  ),
                ),
              if (controller.position.letterNotes[cell]?.isNotEmpty == true)
                Positioned(
                  right: 2,
                  bottom: 1,
                  child: Text(
                    controller.position.letterNotes[cell]!.join(''),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorchVisitor extends StatefulWidget {
  const _TorchVisitor({
    required this.creature,
    required this.controller,
    required this.reduceMotion,
    required this.margin,
  });
  final Creature? creature;
  final LibraryPlayerController controller;
  final bool reduceMotion;
  final double margin;
  @override
  State<_TorchVisitor> createState() => _TorchVisitorState();
}

class _TorchVisitorState extends State<_TorchVisitor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
    lowerBound: .78,
    upperBound: 1,
  );
  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _flicker.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TorchVisitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _flicker.stop();
      _flicker.value = 1;
    } else if (!_flicker.isAnimating) {
      _flicker.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final d = widget.controller.definition;
      if (widget.controller.visible.isEmpty) return const SizedBox.shrink();
      final boundary = widget.controller.visible.firstWhere((cell) {
        final row = cell ~/ d.width, col = cell % d.width;
        return [
          if (row > 0) cell - d.width,
          if (row + 1 < d.height) cell + d.width,
          if (col > 0) cell - 1,
          if (col + 1 < d.width) cell + 1,
        ].any(widget.controller.covered);
      }, orElse: () => widget.controller.visible.first);
      final step = bounds.maxWidth / (d.width + widget.margin * 2);
      final x = (widget.margin + boundary % d.width) * step;
      final y = (widget.margin + boundary ~/ d.width) * step;
      final name = widget.creature?.name;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: x,
            top: y,
            width: step,
            height: step,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: name == null
                      ? 'Resting colony lamp at the already lit fog boundary'
                      : '$name visits with a torch at the already lit fog boundary',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (name != null)
                          CircleAvatar(
                            radius: step * .13,
                            child: Text(name.substring(0, 1)),
                          ),
                        FadeTransition(
                          opacity: _flicker,
                          child: Icon(
                            Icons.local_fire_department,
                            size: step * .32,
                            color: Colors.amber,
                            shadows: const [
                              Shadow(color: Colors.amber, blurRadius: 9),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

String _cellDescription(LibraryPlayerController c, int cell) {
  final row = cell ~/ c.definition.width + 1,
      col = cell % c.definition.width + 1;
  final value = c.displayedValue(cell);
  return [
    'Row $row column $col',
    if (c.covered(cell)) 'covered by fog',
    if (value == null) 'empty' else 'value $value',
    if (c.given(cell)) 'given, locked',
    if (c.position.cornerMarks[cell]?.isNotEmpty == true)
      'corner marks ${c.position.cornerMarks[cell]!.join(', ')}',
    if (c.position.centerMarks[cell]?.isNotEmpty == true)
      'center marks ${c.position.centerMarks[cell]!.join(', ')}',
    if (c.position.letterNotes[cell]?.isNotEmpty == true)
      'letter annotations ${c.position.letterNotes[cell]!.join(', ')}',
    for (final color in c.position.colors[cell] ?? const <String>{})
      '$color color pattern',
  ].join(', ');
}

List<String> _visibleClueDescriptions(
  LibraryDownload puzzle,
  LibraryPuzzleDefinition definition,
  Set<int> visible,
) {
  final refs = puzzle.refs.isNotEmpty ? puzzle.refs : definition.layers;
  final result = <String>[];
  int? pointCell(dynamic point) {
    if (point is! List || point.length < 2) return null;
    final row = (point[0] as num).floor(), col = (point[1] as num).floor();
    if (row < 0 ||
        col < 0 ||
        row >= definition.height ||
        col >= definition.width)
      return null;
    return row * definition.width + col;
  }

  for (final ref in refs) {
    if (ref['hidden'] == true) continue;
    final layer = '${ref['layer'] ?? 'clue'}';
    final cells = <int>[];
    if (ref['cells'] case final List rawCells) {
      for (final raw in rawCells.whereType<List>()) {
        if (pointCell(raw) case final cell?) cells.add(cell);
      }
    }
    final points = (ref['wayPoints'] as List? ?? const [])
        .whereType<List>()
        .toList();
    for (final point in points) {
      if (pointCell(point) case final cell?) cells.add(cell);
    }
    if (cells.isNotEmpty && !cells.any(visible.contains)) continue;
    var detail = switch (layer) {
      'cages' => 'Killer cage',
      'lines' => 'Line clue',
      'arrows' => 'Arrow clue',
      'underlays' || 'overlays' => 'Artwork clue',
      _ => '$layer clue',
    };
    final center = ref['center'];
    final outside =
        center is List &&
        center.length >= 2 &&
        ((center[0] as num) < 0 ||
            (center[1] as num) < 0 ||
            (center[0] as num) > definition.height ||
            (center[1] as num) > definition.width);
    if (outside) detail += ' outside the grid';
    final label = ref['text'] ?? ref['value'] ?? ref['label'];
    final labelCell = cells.isEmpty ? null : cells.first;
    if (label != null && (labelCell == null || visible.contains(labelCell)))
      detail += ', $label';
    for (var index = 1; index < points.length; index++) {
      final from = pointCell(points[index - 1]), to = pointCell(points[index]);
      if (from != null &&
          to != null &&
          visible.contains(from) &&
          !visible.contains(to)) {
        final dy = (points[index][0] as num) - (points[index - 1][0] as num);
        final dx = (points[index][1] as num) - (points[index - 1][1] as num);
        detail +=
            ', enters fog toward ${_direction(dx.toDouble(), dy.toDouble())}';
        break;
      }
    }
    result.add(detail);
  }
  return result;
}

String _direction(double dx, double dy) {
  final vertical = dy < -.1
      ? 'north'
      : dy > .1
      ? 'south'
      : '';
  final horizontal = dx < -.1
      ? 'west'
      : dx > .1
      ? 'east'
      : '';
  return '$vertical$horizontal'.isEmpty
      ? 'the boundary'
      : '$vertical$horizontal';
}

class _LibraryGround extends CustomPainter {
  _LibraryGround(this.controller, this.margin, this.dark);
  final LibraryPlayerController controller;
  final double margin;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final d = controller.definition,
        sx = size.width / (d.width + margin * 2),
        sy = size.height / (d.height + margin * 2);
    final origin = Offset(margin * sx, margin * sy);
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, d.width * sx, d.height * sy),
      Paint()..color = dark ? const Color(0xff202124) : Colors.white,
    );
    for (final cell in d.playable) {
      final rect = Rect.fromLTWH(
        origin.dx + cell % d.width * sx,
        origin.dy + cell ~/ d.width * sy,
        sx,
        sy,
      );
      final colors = controller.position.colors[cell] ?? const <String>{};
      if (colors.isNotEmpty) {
        final list = colors.toList();
        for (var i = 0; i < list.length; i++)
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + rect.width * i / list.length,
              rect.top,
              rect.width / list.length,
              rect.height,
            ),
            Paint()..color = _namedColor(list[i]).withValues(alpha: .45),
          );
      }
      if (controller.selection.contains(cell))
        canvas.drawRect(
          rect.deflate(2),
          Paint()..color = Colors.lightBlue.withValues(alpha: .28),
        );
      if (controller.conflicts.contains(cell))
        canvas.drawRect(
          rect.deflate(3),
          Paint()..color = Colors.red.withValues(alpha: .25),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LibraryGround old) => true;
}

class _FogPainter extends CustomPainter {
  _FogPainter(this.controller, this.dark, this.margin);
  final LibraryPlayerController controller;
  final bool dark;
  final double margin;
  @override
  void paint(Canvas canvas, Size size) {
    final d = controller.definition;
    if (!d.hasFog) return;
    final sx = size.width / (d.width + margin * 2),
        sy = size.height / (d.height + margin * 2);
    final origin = Offset(margin * sx, margin * sy);
    final color = dark ? const Color(0xff4d4d4d) : const Color(0xffafafaf);
    final fog = Paint()..color = color;
    for (final cell in d.playable.where(controller.covered)) {
      final row = cell ~/ d.width, col = cell % d.width;
      final rect = Rect.fromLTWH(
        origin.dx + col * sx,
        origin.dy + row * sy,
        sx,
        sy,
      );
      final left = col > 0 && !controller.covered(cell - 1);
      final right = col + 1 < d.width && !controller.covered(cell + 1);
      final top = row > 0 && !controller.covered(cell - d.width);
      final bottom = row + 1 < d.height && !controller.covered(cell + d.width);
      final bx = sx * .2, by = sy * .2;
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left + (left ? bx : 0),
          rect.top + (top ? by : 0),
          rect.right - (right ? bx : 0),
          rect.bottom - (bottom ? by : 0),
        ),
        fog,
      );
      if (left)
        _fogBand(
          canvas,
          Rect.fromLTWH(rect.left, rect.top, bx, sy),
          color,
          Alignment.centerLeft,
          Alignment.centerRight,
        );
      if (right)
        _fogBand(
          canvas,
          Rect.fromLTWH(rect.right - bx, rect.top, bx, sy),
          color,
          Alignment.centerRight,
          Alignment.centerLeft,
        );
      if (top)
        _fogBand(
          canvas,
          Rect.fromLTWH(rect.left, rect.top, sx, by),
          color,
          Alignment.topCenter,
          Alignment.bottomCenter,
        );
      if (bottom)
        _fogBand(
          canvas,
          Rect.fromLTWH(rect.left, rect.bottom - by, sx, by),
          color,
          Alignment.bottomCenter,
          Alignment.topCenter,
        );
      if (!left && !right && !top && !bottom) canvas.drawRect(rect, fog);
    }
  }

  void _fogBand(
    Canvas canvas,
    Rect rect,
    Color color,
    Alignment clearEdge,
    Alignment fogEdge,
  ) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: clearEdge,
          end: fogEdge,
          colors: [color.withValues(alpha: .08), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FogPainter old) => true;
}

class _LibraryGrid extends CustomPainter {
  _LibraryGrid(this.definition, this.margin, this.dark);
  final LibraryPuzzleDefinition definition;
  final double margin;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / (definition.width + margin * 2),
        sy = size.height / (definition.height + margin * 2);
    final origin = Offset(margin * sx, margin * sy);
    final thin = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final cell in definition.playable)
      canvas.drawRect(
        Rect.fromLTWH(
          origin.dx + cell % definition.width * sx,
          origin.dy + cell ~/ definition.width * sy,
          sx,
          sy,
        ),
        thin,
      );
    final thick = Paint()
      ..color = dark ? Colors.white : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;
    for (final cell in definition.playable) {
      final region = definition.regions[cell];
      if (region == null) continue;
      final row = cell ~/ definition.width,
          col = cell % definition.width,
          x = origin.dx + col * sx,
          y = origin.dy + row * sy;
      if (row == 0 || definition.regions[cell - definition.width] != region)
        canvas.drawLine(Offset(x, y), Offset(x + sx, y), thick);
      if (row == definition.height - 1 ||
          definition.regions[cell + definition.width] != region)
        canvas.drawLine(Offset(x, y + sy), Offset(x + sx, y + sy), thick);
      if (col == 0 || definition.regions[cell - 1] != region)
        canvas.drawLine(Offset(x, y), Offset(x, y + sy), thick);
      if (col == definition.width - 1 || definition.regions[cell + 1] != region)
        canvas.drawLine(Offset(x + sx, y), Offset(x + sx, y + sy), thick);
    }
  }

  @override
  bool shouldRepaint(covariant _LibraryGrid old) =>
      old.definition != definition;
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes, this.width, this.height, this.margin);
  final List<LibraryStroke> strokes;
  final int width;
  final int height;
  final double margin;
  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final path = Path()
        ..moveTo(
          (stroke.points.first.x + margin) * size.width / (width + margin * 2),
          (stroke.points.first.y + margin) *
              size.height /
              (height + margin * 2),
        );
      for (final point in stroke.points.skip(1))
        path.lineTo(
          (point.x + margin) * size.width / (width + margin * 2),
          (point.y + margin) * size.height / (height + margin * 2),
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = _namedColor(stroke.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.snapped ? 4 : 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _namedColor(name),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _ColorPattern extends CustomPainter {
  _ColorPattern(this.name);
  final String name;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _namedColor(name).withValues(alpha: .38),
    );
    final ink = Paint()
      ..color = _namedColor(name).withValues(alpha: .75)
      ..strokeWidth = 1.4;
    if (name.hashCode.isEven) {
      for (var x = -size.height; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          ink,
        );
      }
    } else {
      for (var y = 3.0; y < size.height; y += 7) {
        for (var x = 3.0; x < size.width; x += 7) {
          canvas.drawCircle(Offset(x, y), 1.1, ink);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ColorPattern oldDelegate) =>
      oldDelegate.name != name;
}

Color _namedColor(String name) => switch (name) {
  'blue' => Colors.blue,
  'green' => Colors.green,
  'purple' => Colors.purple,
  'red' => Colors.red,
  _ => Colors.amber,
};
String _time(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

int? _selectedSum(LibraryPlayerController controller) {
  if (controller.selection.isEmpty) return null;
  final values = controller.selection
      .map(controller.displayedValue)
      .map((value) => int.tryParse(value ?? ''));
  if (values.any((value) => value == null)) return null;
  return values.whereType<int>().fold<int>(0, (sum, value) => sum + value);
}

int _visibleSymbolCount(LibraryPlayerController controller, String symbol) =>
    controller.definition.playable.where((cell) {
      if (controller.displayedValue(cell) != symbol) return false;
      return !controller.covered(cell) ||
          controller.position.values[cell] == symbol;
    }).length;

List<List<int>> _combinations(
  List<int> symbols,
  int count,
  int total,
  bool repeats, [
  int start = 0,
]) {
  if (count == 0) return total == 0 ? [const []] : [];
  final result = <List<int>>[];
  for (var i = start; i < symbols.length; i++) {
    for (final rest in _combinations(
      symbols,
      count - 1,
      total - symbols[i],
      repeats,
      repeats ? i : i + 1,
    ))
      result.add([symbols[i], ...rest]);
  }
  return result;
}
