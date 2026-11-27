import 'dart:async';

import 'package:flutter/foundation.dart';

import 'library_models.dart';

class LibraryCheckResult {
  const LibraryCheckResult(
    this.message, {
    this.solved = false,
    this.manual = false,
    this.conflicts = const {},
  });
  final String message;
  final bool solved;
  final bool manual;
  final Set<int> conflicts;
}

/// Native, inventory-free Library input and attempt engine.
class LibraryPlayerController extends ChangeNotifier {
  LibraryPlayerController({
    required this.puzzle,
    LibrarySave? save,
    DateTime Function()? now,
  }) : definition = puzzle.nativeDefinition!,
       _now = now ?? DateTime.now {
    if (save != null && save.history.isNotEmpty) {
      history.addAll(save.history.map(_normalize));
      cursor = save.index.clamp(0, history.length - 1);
      progress = save.progress;
      elapsedMilliseconds = save.elapsedMilliseconds;
      paused = save.paused;
      checkMessage = save.checkMessage;
    } else {
      history.add(_initial());
    }
    _lastTick = _now();
  }

  final LibraryDownload puzzle;
  final LibraryPuzzleDefinition definition;
  final DateTime Function() _now;
  final List<LibraryPosition> history = [];
  int cursor = 0;
  LibraryProgress progress = LibraryProgress.unplayed;
  LibraryInputMode mode = LibraryInputMode.value;
  final Set<int> selection = {};
  bool addSelection = false;
  bool alphabetic = false;
  bool upperCase = true;
  bool paused = false;
  int elapsedMilliseconds = 0;
  String? checkMessage;
  Set<int> conflicts = {};
  DateTime? _lastTick;
  Timer? replayTimer;
  int? liveCursor;

  LibraryPosition get position => history[cursor];
  bool get replaying => liveCursor != null;
  bool get replayPlaying => replayTimer?.isActive ?? false;
  Set<int> get visible => position.revealed;
  bool covered(int cell) => definition.hasFog && !visible.contains(cell);
  bool given(int cell) => !covered(cell) && definition.givens[cell] != null;
  bool editable(int cell) => definition.playable.contains(cell) && !given(cell);
  String? displayedValue(int cell) =>
      given(cell) ? definition.givens[cell] : position.values[cell];

  LibraryPosition _initial() {
    final visible = definition.initiallyVisible == null
        ? definition.playable.toSet()
        : definition.initiallyVisible!.toSet();
    final values = List<String?>.filled(definition.cellCount, null);
    for (final cell in visible) values[cell] = definition.givens[cell];
    return _make(
      values: values,
      revealed: visible,
      grantedFogTriggers: const {},
    );
  }

  LibraryPosition _normalize(LibraryPosition source) {
    final values = source.values.length == definition.cellCount
        ? List<String?>.of(source.values)
        : [for (final digit in source.digits) digit == 0 ? null : '$digit'];
    final revealed = source.revealed.isNotEmpty || !definition.hasFog
        ? (source.revealed.isNotEmpty
              ? source.revealed.toSet()
              : definition.playable.toSet())
        : definition.initiallyVisible!.toSet();
    return LibraryPosition(
      _legacyDigits(values),
      source.notes,
      values: values,
      cornerMarks: _copyMap(source.cornerMarks),
      centerMarks: _copyMap(source.centerMarks),
      letterNotes: _copyMap(source.letterNotes),
      colors: _copyMap(source.colors),
      pen: List.of(source.pen),
      freehand: List.of(source.freehand),
      revealed: revealed,
      grantedFogTriggers: source.grantedFogTriggers.toSet(),
      atMilliseconds: source.atMilliseconds,
    );
  }

  List<int> _legacyDigits(List<String?> values) => [
    for (final value in values) int.tryParse(value ?? '') ?? 0,
  ];
  Map<int, Set<String>> _copyMap(Map<int, Set<String>> source) => {
    for (final item in source.entries) item.key: {...item.value},
  };
  LibraryPosition _make({
    required List<String?> values,
    Map<int, Set<String>>? corners,
    Map<int, Set<String>>? centers,
    Map<int, Set<String>>? letters,
    Map<int, Set<String>>? colors,
    List<LibraryStroke>? pen,
    List<LibraryStroke>? freehand,
    Set<int>? revealed,
    Set<String>? grantedFogTriggers,
  }) {
    final cornerMarks = corners ?? const {};
    return LibraryPosition(
      _legacyDigits(values),
      {
        for (final item in cornerMarks.entries)
          item.key: item.value.map(int.tryParse).whereType<int>().toSet(),
      },
      values: values,
      cornerMarks: cornerMarks,
      centerMarks: centers ?? const {},
      letterNotes: letters ?? const {},
      colors: colors ?? const {},
      pen: pen ?? const [],
      freehand: freehand ?? const [],
      revealed: revealed ?? position.revealed,
      grantedFogTriggers: grantedFogTriggers ?? position.grantedFogTriggers,
      atMilliseconds: elapsedMilliseconds,
    );
  }

  void select(int cell, {bool extend = false, bool toggle = false}) {
    if (!definition.playable.contains(cell)) return;
    if (extend || toggle || addSelection) {
      if (!selection.add(cell) && toggle) selection.remove(cell);
    } else {
      selection
        ..clear()
        ..add(cell);
    }
    notifyListeners();
  }

  void selectAll() {
    selection
      ..clear()
      ..addAll(definition.playable);
    notifyListeners();
  }

  void deselect() {
    selection.clear();
    notifyListeners();
  }

  void invertSelection() {
    final old = selection.toSet();
    selection
      ..clear()
      ..addAll(definition.playable.difference(old));
    notifyListeners();
  }

  void selectMatching(String symbol) {
    selection
      ..clear()
      ..addAll(
        definition.playable.where(
          (cell) =>
              displayedValue(cell) == symbol &&
              (!covered(cell) || position.values[cell] == symbol),
        ),
      );
    notifyListeners();
  }

  void setMode(LibraryInputMode value) {
    mode = value;
    notifyListeners();
  }

  void setAddSelection(bool value) {
    addSelection = value;
    notifyListeners();
  }

  void toggleAlphabet() {
    alphabetic = !alphabetic;
    notifyListeners();
  }

  void toggleCase() {
    upperCase = !upperCase;
    notifyListeners();
  }

  void apply(String raw) {
    if (selection.isEmpty || replaying || paused) return;
    final symbol = mode == LibraryInputMode.color
        ? raw.toLowerCase()
        : (upperCase ? raw.toUpperCase() : raw.toLowerCase());
    final cells = selection.where(editable).toSet();
    if (cells.isEmpty) return;
    final old = position;
    final values = List<String?>.of(old.values);
    final corners = _copyMap(old.cornerMarks),
        centers = _copyMap(old.centerMarks);
    final letters = _copyMap(old.letterNotes), colors = _copyMap(old.colors);
    switch (mode) {
      case LibraryInputMode.value:
        if (!definition.symbols.contains(symbol) &&
            !(alphabetic && RegExp(r'^[A-Za-z]$').hasMatch(symbol)))
          return;
        for (final cell in cells) values[cell] = symbol;
      case LibraryInputMode.corner:
        _toggleAcross(corners, cells, symbol);
      case LibraryInputMode.center:
        _toggleAcross(centers, cells, symbol);
      case LibraryInputMode.letter:
        _toggleAcross(letters, cells, symbol);
      case LibraryInputMode.color:
        _toggleAcross(colors, cells, symbol);
      case LibraryInputMode.pen:
      case LibraryInputMode.freehand:
        return;
    }
    final fog = _evaluateReveals(values);
    _commit(
      _make(
        values: values,
        corners: corners,
        centers: centers,
        letters: letters,
        colors: colors,
        pen: old.pen,
        freehand: old.freehand,
        revealed: fog.visible,
        grantedFogTriggers: fog.grants,
      ),
    );
  }

  void _toggleAcross(
    Map<int, Set<String>> layer,
    Set<int> cells,
    String symbol,
  ) {
    final remove = cells.every(
      (cell) => layer[cell]?.contains(symbol) ?? false,
    );
    for (final cell in cells) {
      final marks = layer.putIfAbsent(cell, () => {});
      remove ? marks.remove(symbol) : marks.add(symbol);
      if (marks.isEmpty) layer.remove(cell);
    }
  }

  ({Set<int> visible, Set<String> grants}) _evaluateReveals(
    List<String?> values,
  ) {
    final lit =
        definition.initiallyVisible?.toSet() ?? definition.playable.toSet();
    final grants = position.grantedFogTriggers.toSet();
    for (final (index, trigger) in definition.fogTriggers.indexed) {
      if (!trigger.reversible && grants.contains(_triggerKey(index, trigger))) {
        lit.addAll(trigger.reveals);
      }
    }
    var changed = true;
    while (changed) {
      final before = lit.length;
      for (final (index, trigger) in definition.fogTriggers.indexed) {
        if (trigger.requiresLit && !trigger.requires.keys.every(lit.contains))
          continue;
        if (trigger.requires.entries.every(
          (item) => values[item.key] == item.value,
        )) {
          lit.addAll(trigger.reveals);
          if (!trigger.reversible) grants.add(_triggerKey(index, trigger));
        }
      }
      changed = lit.length != before;
    }
    return (visible: lit, grants: grants);
  }

  String _triggerKey(int index, LibraryFogTrigger trigger) {
    final requires = trigger.requires.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final reveals = trigger.reveals.toList()..sort();
    return '$index:${requires.map((item) => '${item.key}=${item.value}').join(',')}:${reveals.join(',')}';
  }

  void erase() {
    if (replaying || paused) return;
    if (selection.isEmpty &&
        mode != LibraryInputMode.pen &&
        mode != LibraryInputMode.freehand)
      return;
    final old = position;
    final values = List<String?>.of(old.values);
    final corners = _copyMap(old.cornerMarks),
        centers = _copyMap(old.centerMarks);
    final letters = _copyMap(old.letterNotes), colors = _copyMap(old.colors);
    final pen = List<LibraryStroke>.of(old.pen);
    final freehand = List<LibraryStroke>.of(old.freehand);
    if (mode == LibraryInputMode.pen && pen.isNotEmpty) pen.removeLast();
    if (mode == LibraryInputMode.freehand && freehand.isNotEmpty)
      freehand.removeLast();
    for (final cell in selection.where(editable)) {
      switch (mode) {
        case LibraryInputMode.value:
          values[cell] = null;
        case LibraryInputMode.corner:
          corners.remove(cell);
        case LibraryInputMode.center:
          centers.remove(cell);
        case LibraryInputMode.letter:
          letters.remove(cell);
        case LibraryInputMode.color:
          colors.remove(cell);
        case LibraryInputMode.pen:
        case LibraryInputMode.freehand:
          break;
      }
    }
    final fog = _evaluateReveals(values);
    _commit(
      _make(
        values: values,
        corners: corners,
        centers: centers,
        letters: letters,
        colors: colors,
        pen: pen,
        freehand: freehand,
        revealed: fog.visible,
        grantedFogTriggers: fog.grants,
      ),
    );
  }

  void addStroke(LibraryStroke stroke, {required bool freehand}) {
    final old = position;
    final pen = List<LibraryStroke>.of(old.pen),
        free = List<LibraryStroke>.of(old.freehand);
    (freehand ? free : pen).add(stroke);
    _commit(
      _make(
        values: List.of(old.values),
        corners: _copyMap(old.cornerMarks),
        centers: _copyMap(old.centerMarks),
        letters: _copyMap(old.letterNotes),
        colors: _copyMap(old.colors),
        pen: pen,
        freehand: free,
        revealed: old.revealed,
        grantedFogTriggers: old.grantedFogTriggers,
      ),
    );
  }

  void _commit(LibraryPosition next) {
    history.removeRange(cursor + 1, history.length);
    history.add(next);
    cursor++;
    progress = LibraryProgress.started;
    conflicts = {};
    checkMessage = null;
    notifyListeners();
  }

  void undo() {
    if (cursor > 0 && !replaying) {
      cursor--;
      progress = cursor == 0
          ? LibraryProgress.unplayed
          : LibraryProgress.started;
      conflicts = {};
      notifyListeners();
    }
  }

  void redo() {
    if (cursor + 1 < history.length && !replaying) {
      cursor++;
      progress = LibraryProgress.started;
      conflicts = {};
      notifyListeners();
    }
  }

  LibraryCheckResult check() {
    final effective = [
      for (final cell in List.generate(definition.cellCount, (cell) => cell))
        displayedValue(cell),
    ];
    final missing = definition.playable
        .where(
          (cell) =>
              effective[cell] == null &&
              !definition.deliberateBlanks.contains(cell),
        )
        .toSet();
    final found = <int>{};
    void duplicates(Iterable<int> cells, bool allowed) {
      if (allowed) return;
      final seen = <String, int>{};
      for (final cell in cells) {
        final value = displayedValue(cell);
        if (value == null) continue;
        if (seen[value] case final previous?)
          found.addAll([previous, cell]);
        else
          seen[value] = cell;
      }
    }

    for (var row = 0; row < definition.height; row++)
      duplicates([
        for (var col = 0; col < definition.width; col++)
          row * definition.width + col,
      ], definition.allowRowRepeats);
    for (var col = 0; col < definition.width; col++)
      duplicates([
        for (var row = 0; row < definition.height; row++)
          row * definition.width + col,
      ], definition.allowColumnRepeats);
    for (final region in definition.regions.whereType<int>().toSet())
      duplicates(
        definition.playable.where((cell) => definition.regions[cell] == region),
        definition.allowRegionRepeats,
      );
    conflicts = found;
    LibraryCheckResult result;
    if (missing.isNotEmpty)
      result = LibraryCheckResult(
        '${missing.length} playable cells are unfinished.',
        conflicts: found,
      );
    else if (found.isNotEmpty)
      result = LibraryCheckResult(
        'Visible row, column or region conflicts are marked.',
        conflicts: found,
      );
    else if (puzzle.finalCheck &&
        definition.solution.length == definition.cellCount) {
      final wrong = definition.playable
          .where(
            (cell) =>
                !definition.deliberateBlanks.contains(cell) &&
                effective[cell] != definition.solution[cell],
          )
          .toSet();
      result = wrong.isEmpty
          ? const LibraryCheckResult(
              'Puzzle solved. Final grid matches the authorized solution.',
              solved: true,
            )
          : LibraryCheckResult(
              'The completed grid differs from the authorized solution.',
              conflicts: wrong,
            );
      conflicts = wrong;
    } else if (puzzle.board case final board?) {
      final digits = _legacyDigits(effective);
      if (board.accepts(digits)) {
        result = puzzle.manual
            ? const LibraryCheckResult(
                'Manual check: the implemented clues pass. Check the additional written rules.',
                manual: true,
              )
            : const LibraryCheckResult('Puzzle solved.', solved: true);
      } else {
        final boardConflicts = board.conflicts(digits).toSet();
        conflicts = boardConflicts;
        result = LibraryCheckResult(
          'Check the marked cells and the puzzle rules.',
          conflicts: boardConflicts,
        );
      }
    } else if (puzzle.manual)
      result = const LibraryCheckResult(
        'Manual check: rendered clues include rules the app does not evaluate.',
        manual: true,
      );
    else
      result = const LibraryCheckResult(
        'Implemented Sudoku constraints pass. Additional written rules may still apply.',
        manual: true,
      );
    checkMessage = result.message;
    if (result.solved) progress = LibraryProgress.solved;
    notifyListeners();
    return result;
  }

  void markManualComplete() {
    progress = LibraryProgress.manual;
    checkMessage = 'Marked complete by manual check.';
    notifyListeners();
  }

  void togglePause() {
    tick();
    paused = !paused;
    _lastTick = _now();
    notifyListeners();
  }

  void tick() {
    final now = _now();
    if (!paused && !replaying && _lastTick != null)
      elapsedMilliseconds += now.difference(_lastTick!).inMilliseconds;
    _lastTick = now;
  }

  void startReplay() {
    if (replaying) return;
    liveCursor = cursor;
    cursor = 0;
    paused = true;
    notifyListeners();
  }

  void seekReplay(int index) {
    if (!replaying) return;
    cursor = index.clamp(0, history.length - 1);
    notifyListeners();
  }

  void toggleReplayPlay() {
    if (!replaying) return;
    if (replayPlaying) {
      replayTimer!.cancel();
      notifyListeners();
      return;
    }
    replayTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (cursor + 1 >= history.length) {
        timer.cancel();
      } else {
        cursor++;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void closeReplay() {
    replayTimer?.cancel();
    cursor = liveCursor ?? cursor;
    liveCursor = null;
    _lastTick = _now();
    notifyListeners();
  }

  void reset() {
    history
      ..clear()
      ..add(_initial());
    cursor = 0;
    progress = LibraryProgress.unplayed;
    selection.clear();
    conflicts = {};
    checkMessage = null;
    elapsedMilliseconds = 0;
    paused = false;
    notifyListeners();
  }

  LibrarySave snapshot() {
    tick();
    return LibrarySave(
      List.of(history),
      cursor,
      _now(),
      progress,
      elapsedMilliseconds: elapsedMilliseconds,
      paused: paused,
      checkMessage: checkMessage,
    );
  }

  @override
  void dispose() {
    replayTimer?.cancel();
    super.dispose();
  }
}
