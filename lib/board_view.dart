import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'hum.dart';

/// A digit selects a placement; a source cell identifies a slide.
class BoardDrag {
  const BoardDrag.digit(this.value, {this.token, this.offerId}) : source = null;
  const BoardDrag.slide(this.source)
    : value = null,
      token = null,
      offerId = null;

  final int? value;
  final int? source;
  final int? token;
  final String? offerId;
}

class BoardMark {
  const BoardMark(this.kind, this.cells, [this.value]);

  final String kind;
  final List<int> cells;
  final int? value;

  String get description {
    final name = switch (kind) {
      'germanWhispers' => 'German Whispers',
      'regionSum' || 'regionSumLines' => 'Region Sum Line',
      'kropkiWhite' || 'whiteDot' => 'White Kropki dot',
      'kropkiBlack' || 'blackDot' => 'Black Kropki dot',
      'thermometer' => 'Thermometer',
      'renban' => 'Renban line',
      'killer' || 'killerCage' => 'Killer cage',
      'arrow' || 'arrows' => 'Arrow',
      'palindrome' => 'Palindrome',
      'sandwich' => 'Sandwich',
      'xSum' || 'xSums' => 'X-Sum',
      'diagonal' => 'Diagonal',
      'antiKnight' => 'Anti-Knight',
      _ => kind,
    };
    return value == null ? name : '$name $value';
  }
}

/// Square Sudoku board shared by touch, drag, keyboard and assistive input.
class SudokuBoardView extends StatefulWidget {
  const SudokuBoardView({
    super.key,
    required this.size,
    required this.cells,
    required this.regions,
    required this.onCell,
    this.fixed = const {},
    this.anchors = const {},
    this.visible,
    this.notes = const {},
    this.conflicts = const {},
    this.marks = const [],
    this.clueArtwork,
    this.selected,
    this.highlightRegion,
    this.sliding = false,
    this.renderGiven,
    this.onDrop,
    this.onDigit,
    this.onErase,
  });

  final int size;
  final List<int> cells;
  final List<int> regions;
  final Set<int> fixed;
  final Set<int> anchors;
  final Set<int>? visible;
  final Map<int, Set<int>> notes;
  final Set<int> conflicts;
  final List<BoardMark> marks;
  final Widget? clueArtwork;
  final int? selected;
  final int? highlightRegion;
  final bool sliding;
  final Widget Function(int index, String digit, TextStyle style)? renderGiven;
  final ValueChanged<int> onCell;
  final void Function(int index, BoardDrag data)? onDrop;
  final void Function(int index, int digit)? onDigit;
  final ValueChanged<int>? onErase;

  @override
  State<SudokuBoardView> createState() => _SudokuBoardViewState();
}

class _SudokuBoardViewState extends State<SudokuBoardView> {
  final _focus = FocusNode(debugLabel: 'Sudoku board');
  int _cursor = 0;
  final _pointers = <int>{};
  bool _multitouch = false;
  int? _moving;
  int? _track;
  Offset _origin = Offset.zero;
  double _travel = 0;
  double? _boardWidth;

  Map<int, (String, Offset)> _tracks(int index) {
    final n = widget.size;
    if (!widget.sliding ||
        widget.cells[index] == 0 ||
        widget.fixed.contains(index) ||
        widget.anchors.contains(index))
      return {};
    return {
      if (index >= n && widget.cells[index - n] == 0)
        index - n: ('up', const Offset(0, -1)),
      if (index + n < n * n && widget.cells[index + n] == 0)
        index + n: ('down', const Offset(0, 1)),
      if (index % n > 0 && widget.cells[index - 1] == 0)
        index - 1: ('left', const Offset(-1, 0)),
      if (index % n < n - 1 && widget.cells[index + 1] == 0)
        index + 1: ('right', const Offset(1, 0)),
    };
  }

  void _resetSlide() {
    _moving = _track = null;
    _travel = 0;
  }

  void _updateSlide(Offset position, double extent) {
    final from = _moving;
    if (from == null || _pointers.length != 1) return;
    final delta = position - _origin;
    final tracks = _tracks(from);
    if (_track == null) {
      final ax = delta.dx.abs();
      final ay = delta.dy.abs();
      if (math.max(ax, ay) < 8 || (ax - ay).abs() < math.max(ax, ay) * .25)
        return;
      final direction = ax > ay
          ? Offset(delta.dx.sign, 0)
          : Offset(0, delta.dy.sign);
      _track = tracks.entries
          .where((e) => e.value.$2 == direction)
          .firstOrNull
          ?.key;
    }
    final direction = tracks[_track]?.$2;
    if (direction == null) return;
    setState(
      () => _travel = (delta.dx * direction.dx + delta.dy * direction.dy).clamp(
        0.0,
        extent,
      ),
    );
  }

  void _finishSlide(double extent) {
    final from = _moving;
    final to = _track;
    final commit =
        from != null &&
        to != null &&
        _travel > extent / 2 &&
        _tracks(from).containsKey(to);
    setState(_resetSlide);
    if (commit) widget.onDrop?.call(to, BoardDrag.slide(from));
  }

  @override
  void didUpdateWidget(covariant SudokuBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size || !widget.sliding) _resetSlide();
    if (oldWidget.size != widget.size) _cursor = 0;
    if (widget.selected != oldWidget.selected && widget.selected != null) {
      _cursor = widget.selected!;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final size = widget.size;
    final row = _cursor ~/ size;
    final column = _cursor % size;
    final next = switch (key) {
      LogicalKeyboardKey.arrowUp => math.max(0, row - 1) * size + column,
      LogicalKeyboardKey.arrowDown =>
        math.min(size - 1, row + 1) * size + column,
      LogicalKeyboardKey.arrowLeft => row * size + math.max(0, column - 1),
      LogicalKeyboardKey.arrowRight =>
        row * size + math.min(size - 1, column + 1),
      _ => null,
    };
    if (next != null) {
      if (_cursor == widget.selected && _tracks(_cursor).containsKey(next)) {
        widget.onDrop?.call(next.toInt(), BoardDrag.slide(_cursor));
      }
      setState(() => _cursor = next.toInt());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      widget.onCell(_cursor);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      widget.onErase?.call(_cursor);
      return KeyEventResult.handled;
    }
    final digit = int.tryParse(key.keyLabel);
    if (digit != null &&
        digit >= 1 &&
        digit <= size &&
        widget.onDigit != null) {
      widget.onDigit!(_cursor, digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final visible = widget.visible;
    final fogColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff4d4d4d)
        : const Color(0xffafafaf);
    final marks = widget.marks
        .where((mark) => visible == null || mark.cells.every(visible.contains))
        .toList();
    return Focus(
      focusNode: _focus,
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        label: '$size by $size Sudoku board',
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final step = constraints.maxWidth / size;
              if (_boardWidth != constraints.maxWidth) _resetSlide();
              _boardWidth = constraints.maxWidth;
              final active = _moving ?? widget.selected;
              final tracks = active == null
                  ? <int, (String, Offset)>{}
                  : _tracks(active);
              final direction = tracks[_track]?.$2 ?? Offset.zero;
              return Listener(
                onPointerDown: (e) {
                  if (_pointers.isEmpty) _multitouch = false;
                  _pointers.add(e.pointer);
                  if (_pointers.length > 1) _multitouch = true;
                  if (_pointers.length > 1 && _moving != null)
                    setState(_resetSlide);
                },
                onPointerUp: (e) => _pointers.remove(e.pointer),
                onPointerCancel: (e) {
                  _pointers.remove(e.pointer);
                  if (_moving != null) setState(_resetSlide);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _BoardGround(
                        fogColor: fogColor,
                        size: size,
                        regions: widget.regions,
                        visible: visible,
                        highlight: widget.highlightRegion,
                        selected: widget.selected,
                        conflicts: widget.conflicts,
                        marks: const [],
                      ),
                    ),
                    CustomPaint(
                      painter: _BoardGrid(size: size, regions: widget.regions),
                    ),
                    if (widget.clueArtwork != null)
                      IgnorePointer(child: widget.clueArtwork),
                    CustomPaint(
                      painter: _BoardGround(
                        fogColor: fogColor,
                        size: size,
                        regions: widget.regions,
                        visible: visible,
                        highlight: null,
                        selected: null,
                        conflicts: const {},
                        marks: marks,
                        drawGround: false,
                      ),
                    ),
                    if (visible != null && visible.length < size * size)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _FogLineEdges(
                            size,
                            visible,
                            widget.marks,
                            fogColor,
                          ),
                        ),
                      ),
                    Column(
                      children: List.generate(
                        size,
                        (row) => Expanded(
                          child: Row(
                            children: List.generate(
                              size,
                              (column) => Expanded(
                                child: _cell(
                                  context,
                                  row * size + column,
                                  step,
                                  marks,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _BoardGrid(
                          size: size,
                          regions: widget.regions,
                          cursor: _focus.hasFocus ? _cursor : null,
                          selected: widget.selected,
                          drawGrid: false,
                        ),
                      ),
                    ),
                    if (active != null)
                      for (final track in tracks.values)
                        Positioned(
                          left:
                              (active % size + .5 + track.$2.dx * .55) * step -
                              step * .15,
                          top:
                              (active ~/ size + .5 + track.$2.dy * .55) * step -
                              step * .15,
                          child: IgnorePointer(
                            child: Icon(
                              switch (track.$1) {
                                'up' => Icons.arrow_upward,
                                'down' => Icons.arrow_downward,
                                'left' => Icons.arrow_back,
                                _ => Icons.arrow_forward,
                              },
                              size: step * .30,
                              color: Hum.focus,
                            ),
                          ),
                        ),
                    if (_moving case final int index when _travel > 0)
                      Positioned(
                        left: index % size * step + direction.dx * _travel,
                        top: index ~/ size * step + direction.dy * _travel,
                        width: step,
                        height: step,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: BoardDigitFace(
                              value: widget.cells[index],
                              selected: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _digitText(
    String value, {
    required TextStyle style,
    required int index,
    required bool given,
  }) {
    final render = widget.renderGiven;
    return given && render != null
        ? render(index, value, style)
        : Text(value, style: style);
  }

  Widget _cell(
    BuildContext context,
    int index,
    double extent,
    List<BoardMark> marks,
  ) {
    final hidden = widget.visible != null && !widget.visible!.contains(index);
    final value = hidden ? 0 : widget.cells[index];
    final anchored = widget.anchors.contains(index) && !hidden;
    final fixed = widget.fixed.contains(index) && !hidden;
    final conflict = widget.conflicts.contains(index) && !hidden;
    final notes = hidden ? const <int>{} : widget.notes[index] ?? const <int>{};
    final row = index ~/ widget.size + 1;
    final column = index % widget.size + 1;
    final covering = marks.where((mark) => mark.cells.contains(index));
    final label = [
      'Row $row column $column',
      if (hidden) 'fog' else if (value == 0) 'empty' else '$value',
      if (anchored) 'locked' else if (fixed) 'given',
      if (conflict) 'conflict',
      if (notes.isNotEmpty) 'candidates ${notes.join(', ')}',
      ...covering.map((mark) => mark.description).toSet(),
    ].join(', ');
    void select() {
      _focus.requestFocus();
      setState(() => _cursor = index);
      widget.onCell(index);
    }

    final tracks = _tracks(index);
    Widget cell = DragTarget<BoardDrag>(
      onWillAcceptWithDetails: (details) => !hidden && widget.onDrop != null,
      onAcceptWithDetails: (details) =>
          widget.onDrop?.call(index, details.data),
      builder: (context, candidates, rejected) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: select,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (candidates.isNotEmpty) const ColoredBox(color: Hum.cyan),
            Center(
              child: _moving == index && _travel > 0
                  ? const SizedBox.shrink()
                  : hidden
                  ? const SizedBox.shrink()
                  : value > 0
                  ? SizedBox(
                      width: extent * .72,
                      height: extent * .75,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _digitText(
                          '$value',
                          index: index,
                          given: fixed,
                          style: TextStyle(
                            fontFamily: Hum.digitFont,
                            fontSize: extent * .53,
                            height: 1,
                            fontWeight: fixed
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: conflict
                                ? Hum.error
                                : fixed
                                ? Hum.ink
                                : Hum.focus,
                          ),
                        ),
                      ),
                    )
                  : notes.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          (notes.toList()..sort()).join(' '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: Hum.digitFont,
                            color: Hum.mutedInk,
                            fontSize: math.min(13, extent * .25),
                          ),
                        ),
                      ),
                    ),
            ),
            if (anchored || conflict)
              Positioned(
                top: 3,
                right: 3,
                child: Icon(
                  anchored ? Icons.lock_outline : Icons.error_outline,
                  size: math.min(14, extent * .26),
                  color: conflict ? Hum.error : Hum.mutedInk,
                ),
              ),
          ],
        ),
      ),
    );
    if (tracks.isNotEmpty) {
      cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onPanDown: (e) => _origin = e.globalPosition,
        onPanStart: (e) {
          if (!_multitouch && _pointers.length == 1) {
            setState(() => _moving = index);
            _updateSlide(e.globalPosition, extent);
          }
        },
        onPanUpdate: (e) => _updateSlide(e.globalPosition, extent),
        onPanEnd: (_) => _finishSlide(extent),
        onPanCancel: () {
          if (_moving != null) setState(_resetSlide);
        },
        child: cell,
      );
    }
    return Semantics(
      key: ValueKey('cell-$index'),
      label: label,
      selected: widget.selected == index,
      button: true,
      customSemanticsActions: {
        for (final entry in tracks.entries)
          CustomSemanticsAction(
            label:
                'Slide ${entry.value.$1} into row ${entry.key ~/ widget.size + 1}, column ${entry.key % widget.size + 1}',
          ): () =>
              widget.onDrop?.call(entry.key, BoardDrag.slide(index)),
      },
      onTap: select,
      child: ExcludeSemantics(child: cell),
    );
  }
}

/// Tactile number tile, also used as the drag feedback.
class BoardDigitFace extends StatelessWidget {
  const BoardDigitFace({
    super.key,
    required this.value,
    this.selected = false,
    this.used = false,
    this.footer,
    this.offer = false,
  });

  final int value;
  final bool selected;
  final bool used;
  final String? footer;
  final bool offer;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: selected
          ? Hum.cyan
          : offer
          ? Hum.pear
          : Hum.board,
      border: Border(
        top: BorderSide(color: selected ? Hum.focus : Hum.grid),
        left: BorderSide(color: selected ? Hum.focus : Hum.grid),
        right: BorderSide(color: selected ? Hum.focus : Hum.grid),
        bottom: BorderSide(color: selected ? Hum.focus : Hum.grid, width: 3),
      ),
    ),
    child: SizedBox(
      width: 48,
      height: 48,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                used ? '□' : '$value',
                style: const TextStyle(
                  color: Hum.ink,
                  fontFamily: Hum.digitFont,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              if (footer != null)
                Text(
                  footer!,
                  style: const TextStyle(
                    color: Hum.mutedInk,
                    fontFamily: Hum.digitFont,
                    fontSize: 10,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BoardGround extends CustomPainter {
  const _BoardGround({
    required this.size,
    required this.regions,
    required this.visible,
    required this.highlight,
    required this.selected,
    required this.conflicts,
    required this.marks,
    this.drawGround = true,
    required this.fogColor,
  });

  final int size;
  final List<int> regions;
  final Set<int>? visible;
  final int? highlight;
  final int? selected;
  final Set<int> conflicts;
  final List<BoardMark> marks;
  final bool drawGround;
  final Color fogColor;

  @override
  void paint(Canvas canvas, Size bounds) {
    final step = bounds.width / size;
    Rect cell(int index) =>
        Rect.fromLTWH(index % size * step, index ~/ size * step, step, step);
    final paint = Paint();
    for (var index = 0; drawGround && index < size * size; index++) {
      final hidden = visible != null && !visible!.contains(index);
      paint.color = hidden
          ? fogColor
          : conflicts.contains(index)
          ? Hum.coral
          : index == selected
          ? Hum.cyan
          : regions[index] == highlight
          ? Color.lerp(Hum.board, Hum.torch, .55)!
          : Hum.board;
      canvas.drawRect(cell(index), paint);
    }
    for (final mark in marks) {
      if (mark.cells.isEmpty) continue;
      final points = mark.cells.map((index) => cell(index).center).toList();
      final first = points.first;
      if ([
            'whiteDot',
            'blackDot',
            'kropkiWhite',
            'kropkiBlack',
          ].contains(mark.kind) &&
          points.length > 1) {
        final center = Offset.lerp(first, points[1], .5)!;
        final radius = step * .083;
        canvas.drawCircle(center, radius + 1, Paint()..color = Hum.ink);
        if (mark.kind == 'whiteDot' || mark.kind == 'kropkiWhite') {
          canvas.drawCircle(center, radius, Paint()..color = Hum.board);
        }
        continue;
      }
      if (mark.kind == 'killer' || mark.kind == 'killerCage') {
        final cage = mark.cells.toSet();
        for (final index in cage) {
          final inset = cell(index).deflate(3);
          if (index < size || !cage.contains(index - size))
            _dash(canvas, inset.topLeft, inset.topRight, Hum.error);
          if (index >= size * (size - 1) || !cage.contains(index + size))
            _dash(canvas, inset.bottomLeft, inset.bottomRight, Hum.error);
          if (index % size == 0 || !cage.contains(index - 1))
            _dash(canvas, inset.topLeft, inset.bottomLeft, Hum.error);
          if (index % size == size - 1 || !cage.contains(index + 1))
            _dash(canvas, inset.topRight, inset.bottomRight, Hum.error);
        }
        if (mark.value case final int total) {
          _paintClue(
            canvas,
            '$total',
            cell(mark.cells.first).topLeft + const Offset(5, 3),
          );
        }
        continue;
      }
      if (['sandwich', 'xSum', 'xSums', 'antiKnight'].contains(mark.kind))
        continue;
      if (points.length < 2) continue;
      final color = switch (mark.kind) {
        'thermometer' => Hum.grid.withValues(alpha: .40),
        'renban' => Hum.coral,
        'germanWhispers' => Hum.pear,
        'palindrome' => Hum.grid.withValues(alpha: .35),
        'regionSum' || 'regionSumLines' => Hum.cyan,
        _ => Hum.focus.withValues(alpha: .30),
      };
      final stroke = Paint()
        ..color = color
        ..strokeWidth = step * (mark.kind == 'diagonal' ? .10 : .18)
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < points.length; i++) {
        if (mark.kind == 'diagonal' || mark.kind == 'palindrome') {
          _dash(canvas, points[i - 1], points[i], Hum.focus);
        } else {
          canvas.drawLine(points[i - 1], points[i], stroke);
        }
        if (['regionSum', 'regionSumLines'].contains(mark.kind) &&
            regions[mark.cells[i - 1]] != regions[mark.cells[i]]) {
          canvas.drawCircle(
            Offset.lerp(points[i - 1], points[i], .5)!,
            step * .065,
            Paint()..color = Hum.focus,
          );
        }
      }
      if (mark.kind == 'thermometer') {
        canvas.drawCircle(first, step * .29, Paint()..color = color);
      }
      if (mark.kind == 'arrow' || mark.kind == 'arrows') {
        canvas.drawCircle(first, step * .30, Paint()..color = Hum.board);
        canvas.drawCircle(
          first,
          step * .27,
          Paint()
            ..color = Hum.focus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        final delta = points.last - points[points.length - 2];
        if (delta.distance > 0) {
          final direction = delta / delta.distance;
          final perpendicular = Offset(-direction.dy, direction.dx);
          for (final side in [-1, 1]) {
            canvas.drawLine(
              points.last,
              points.last -
                  direction * step * .19 +
                  perpendicular * step * .13 * side.toDouble(),
              Paint()
                ..color = Hum.focus
                ..strokeWidth = 1.4,
            );
          }
        }
      }
    }
  }

  void _paintClue(Canvas canvas, String value, Offset origin) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Hum.error,
          backgroundColor: Hum.board,
          fontFamily: Hum.digitFont,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, origin);
    text.dispose();
  }

  void _dash(Canvas canvas, Offset a, Offset b, Color color) {
    final length = (b - a).distance;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25;
    for (var offset = 0.0; offset < length; offset += 7) {
      canvas.drawLine(
        Offset.lerp(a, b, offset / length)!,
        Offset.lerp(a, b, math.min(offset + 4, length) / length)!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardGround oldDelegate) => true;
}

/// Carries only the incoming tangent into the feather at an earned light edge.
class _FogLineEdges extends CustomPainter {
  const _FogLineEdges(this.size, this.visible, this.marks, this.fog);
  final int size;
  final Set<int> visible;
  final List<BoardMark> marks;
  final Color fog;

  @override
  void paint(Canvas canvas, Size bounds) {
    final step = bounds.width / size;
    Offset center(int index) =>
        Offset((index % size + .5) * step, (index ~/ size + .5) * step);
    final lines = Paint()
      ..strokeWidth = step * .13
      ..strokeCap = StrokeCap.butt;
    for (final cell in visible) {
      final origin = center(cell);
      final neighbors = {
        if (cell % size > 0) cell - 1: const Offset(-1, 0),
        if (cell % size < size - 1) cell + 1: const Offset(1, 0),
        if (cell >= size) cell - size: const Offset(0, -1),
        if (cell < size * (size - 1)) cell + size: const Offset(0, 1),
      };
      for (final edge in neighbors.entries.where(
        (e) => !visible.contains(e.key),
      )) {
        final dir = edge.value;
        final start = origin + dir * (step * .50);
        final end = start + dir * (step * .20);
        final band = Rect.fromCenter(
          center: (start + end) / 2,
          width: dir.dx == 0 ? step : step * .20,
          height: dir.dy == 0 ? step : step * .20,
        );
        canvas.drawRect(
          band,
          Paint()
            ..shader = ui.Gradient.linear(start, end, [
              Color.lerp(fog, Hum.board, .35)!,
              fog,
            ]),
        );
      }
    }
    for (final mark in marks) {
      if (mark.cells.every(visible.contains)) continue;
      final color = switch (mark.kind) {
        'renban' => Hum.coral,
        'germanWhispers' => Hum.pearEdge,
        'regionSum' || 'regionSumLines' => Hum.focus,
        'thermometer' || 'palindrome' => Hum.grid,
        'arrow' || 'arrows' || 'diagonal' => Hum.focus,
        _ => null,
      };
      if (color == null) continue;
      for (var i = 1; i < mark.cells.length; i++) {
        final a = mark.cells[i - 1], b = mark.cells[i];
        if (!visible.contains(a) && !visible.contains(b)) continue;
        if (visible.contains(a) && visible.contains(b)) {
          canvas.drawLine(
            center(a),
            center(b),
            lines
              ..shader = null
              ..color = color,
          );
          continue;
        }
        // Authored campaign paths connect cell centers one step at a time.
        if ((a % size - b % size).abs() > 1 ||
            (a ~/ size - b ~/ size).abs() > 1)
          continue;
        final from = center(visible.contains(a) ? a : b);
        final to = center(visible.contains(a) ? b : a);
        final delta = to - from;
        if (delta.distance == 0) continue;
        final edge = from + delta * .5;
        final tip = edge + delta / delta.distance * step * .18;
        lines
          ..color = color
          ..shader = ui.Gradient.linear(edge, tip, [
            color,
            color.withValues(alpha: 0),
          ]);
        canvas.drawLine(from, tip, lines);
      }
    }
  }

  @override
  bool shouldRepaint(_FogLineEdges old) =>
      old.size != size ||
      old.visible != visible ||
      old.marks != marks ||
      old.fog != fog;
}

class _BoardGrid extends CustomPainter {
  const _BoardGrid({
    required this.size,
    required this.regions,
    this.cursor,
    this.selected,
    this.drawGrid = true,
  });

  final int size;
  final List<int> regions;
  final int? cursor;
  final int? selected;
  final bool drawGrid;

  @override
  void paint(Canvas canvas, Size bounds) {
    final step = bounds.width / size;
    final thin = Paint()
      ..color = Hum.grid.withValues(alpha: .55)
      ..strokeWidth = .75;
    final thick = Paint()
      ..color = Hum.ink
      ..strokeWidth = 2.5;
    for (var row = 0; drawGrid && row < size; row++) {
      for (var column = 0; column < size; column++) {
        final index = row * size + column;
        final x = column * step;
        final y = row * step;
        if (row > 0)
          canvas.drawLine(
            Offset(x, y),
            Offset(x + step, y),
            regions[index] != regions[index - size] ? thick : thin,
          );
        if (column > 0)
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + step),
            regions[index] != regions[index - 1] ? thick : thin,
          );
      }
    }
    if (drawGrid)
      canvas.drawRect(
        (Offset.zero & bounds).deflate(1.25),
        thick..style = PaintingStyle.stroke,
      );
    final focus = cursor ?? selected;
    if (focus != null) {
      final rect = Rect.fromLTWH(
        focus % size * step,
        focus ~/ size * step,
        step,
        step,
      );
      canvas.drawRect(
        rect.deflate(2),
        Paint()
          ..color = Hum.focus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardGrid oldDelegate) =>
      oldDelegate.drawGrid != drawGrid ||
      oldDelegate.size != size ||
      oldDelegate.regions != regions ||
      oldDelegate.cursor != cursor ||
      oldDelegate.selected != selected;
}
