import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import 'library_models.dart';

double libraryArtworkMargin(
  LibraryDownload puzzle,
  LibraryPuzzleDefinition definition,
) {
  final refs = puzzle.refs.isNotEmpty ? puzzle.refs : definition.layers;
  bool outside(dynamic point) =>
      point is List &&
      point.length >= 2 &&
      ((point[0] as num) < 0 ||
          (point[1] as num) < 0 ||
          (point[0] as num) > definition.height ||
          (point[1] as num) > definition.width);
  for (final ref in refs) {
    if (outside(ref['center'])) return .8;
    if (ref['wayPoints'] case final List points) {
      if (points.any(outside)) return .8;
    }
  }
  return 0;
}

class LibraryArtwork extends StatelessWidget {
  const LibraryArtwork(this.puzzle, {super.key, this.definition, this.visible});
  final LibraryDownload puzzle;
  final LibraryPuzzleDefinition? definition;
  final Set<int>? visible;

  @override
  Widget build(BuildContext context) {
    final native = definition ?? puzzle.nativeDefinition;
    return LayoutBuilder(
      builder: (context, bounds) {
        final margin = native == null
            ? 0.0
            : libraryArtworkMargin(puzzle, native);
        final width = native?.width ?? puzzle.board!.size;
        final height = native?.height ?? width;
        final step = math.min(
          bounds.maxWidth / (width + margin * 2),
          bounds.maxHeight / (height + margin * 2),
        );
        final refs = puzzle.refs.isNotEmpty
            ? puzzle.refs
            : native?.layers ?? const <Map<String, dynamic>>[];
        final assets = {
          for (final item in puzzle.assetManifest) item['id']: item,
        };
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ArtworkPainter(puzzle, native, visible)),
            for (final ref in refs)
              if (_assetId(ref) case final id?)
                if (assets[id]?['data'] case final String data)
                  Positioned(
                    left:
                        (margin + _coordinate(ref['center'], 1)) * step -
                        _dimension(ref['width'], 1) * step / 2,
                    top:
                        (margin + _coordinate(ref['center'], 0)) * step -
                        _dimension(ref['height'], 1) * step / 2,
                    width: _dimension(ref['width'], 1) * step,
                    height: _dimension(ref['height'], 1) * step,
                    child: ExcludeSemantics(
                      excluding: !_refRevealed(ref, native),
                      child: Image.memory(
                        base64Decode(data),
                        fit: BoxFit.contain,
                        semanticLabel:
                            ref['alt']?.toString() ??
                            'Locally saved puzzle clue image',
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  static String? _assetId(Map<String, dynamic> ref) {
    for (final key in const [
      'image',
      'imageUrl',
      'src',
      'url',
      'backgroundImage',
    ]) {
      final value = ref[key];
      if (value is String && value.startsWith('asset:'))
        return value.substring(6);
    }
    return null;
  }

  static double _coordinate(dynamic center, int index) =>
      center is List && center.length > index
      ? (center[index] as num).toDouble()
      : 0;
  static double _dimension(dynamic value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  bool _refRevealed(
    Map<String, dynamic> ref,
    LibraryPuzzleDefinition? definition,
  ) {
    if (visible == null || definition == null) return true;
    if (ref['cells'] case final List cells when cells.isNotEmpty) {
      return cells.cast<List>().every(
        (cell) => visible!.contains(
          (cell[0] as num).toInt() * definition.width +
              (cell[1] as num).toInt(),
        ),
      );
    }
    return true;
  }
}

class _ArtworkPainter extends CustomPainter {
  _ArtworkPainter(this.puzzle, this.definition, this.visible);
  final LibraryDownload puzzle;
  final LibraryPuzzleDefinition? definition;
  final Set<int>? visible;
  final _ink = const Color(0xff24262a);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = definition?.width ?? puzzle.board!.size;
    final margin = definition == null
        ? 0.0
        : libraryArtworkMargin(puzzle, definition!);
    final height = definition?.height ?? grid;
    final step = math.min(
      size.width / (grid + margin * 2),
      size.height / (height + margin * 2),
    );
    _origin = Offset(margin * step, margin * step);
    canvas.save();
    final refs = puzzle.refs.isNotEmpty
        ? puzzle.refs
        : definition?.layers ?? const <Map<String, dynamic>>[];
    for (final item in refs) {
      if (!_itemVisible(item)) continue;
      switch (item['layer']) {
        case 'underlays':
        case 'overlays':
          _shape(canvas, item, step);
        case 'cages':
          _cage(canvas, item, step);
        case 'lines':
        case 'arrows':
          _line(canvas, item, step);
      }
    }
    canvas.restore();
  }

  Offset _origin = Offset.zero;

  bool _itemVisible(Map<String, dynamic> item) {
    if (visible == null) return true;
    if (item['hidden'] == true) return false;
    // Preserve an incoming visible segment, but never expose a wholly covered
    // clue. Geometry without cell metadata is clipped by the opaque fog layer.
    return true;
  }

  void _shape(Canvas canvas, Map<String, dynamic> item, double step) {
    final center = _point(item['center'] as List, step);
    final width = _num(item['width'], 1).clamp(0, 10) * step;
    final height = _num(item['height'], 1).clamp(0, 10) * step;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final fill = _color(
      item['backgroundColor'] ?? item['fill'],
      Colors.transparent,
    );
    final border = _color(
      item['stroke'] ?? item['borderColor'],
      Colors.transparent,
    );
    final thickness =
        _num(item['stroke-width'], 1) * step / _num(item['unit'], 64);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_num(item['angle'], 0) * math.pi / 180);
    void draw(Paint paint) {
      if (item['rounded'] == true) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    }

    if (fill.a > 0) draw(Paint()..color = fill);
    if (border.a > 0 && thickness > 0) {
      draw(
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
    }
    if (item['text'] case final text?) {
      final font = _num(item['fontSize'], 16) * step / _num(item['unit'], 64);
      _text(
        canvas,
        text.toString(),
        Offset.zero,
        font,
        _color(item['textColor'] ?? item['color'], _ink),
      );
    }
    canvas.restore();
  }

  void _cage(Canvas canvas, Map<String, dynamic> item, double step) {
    if (item['hidden'] == true) return;
    final cells = (item['cells'] as List)
        .cast<List>()
        .map((item) => ((item[0] as num).toInt(), (item[1] as num).toInt()))
        .toSet();
    final dx = step * .08;
    final color = _color(item['color'] ?? item['stroke'], _ink);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = step * .035;
    final fill = _color(item['backgroundColor'], Colors.transparent);
    for (final (row, col) in cells) {
      final x = _origin.dx + col * step;
      final y = _origin.dy + row * step;
      if (fill.a > 0)
        canvas.drawRect(Rect.fromLTWH(x, y, step, step), Paint()..color = fill);
      final left = x + dx;
      final right = x + step - dx;
      final top = y + dx;
      final bottom = y + step - dx;
      if (!cells.contains((row - 1, col)))
        _dash(canvas, Offset(left, top), Offset(right, top), stroke, step);
      if (!cells.contains((row + 1, col)))
        _dash(
          canvas,
          Offset(left, bottom),
          Offset(right, bottom),
          stroke,
          step,
        );
      if (!cells.contains((row, col - 1)))
        _dash(canvas, Offset(left, top), Offset(left, bottom), stroke, step);
      if (!cells.contains((row, col + 1)))
        _dash(canvas, Offset(right, top), Offset(right, bottom), stroke, step);
    }
    final value = item['value'] ?? item['label'];
    if (value != null) {
      final ordered = cells.toList()
        ..sort(
          (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
        );
      final (row, col) = ordered.first;
      _text(
        canvas,
        value.toString(),
        _origin + Offset((col + .23) * step, (row + .22) * step),
        step * .22,
        color,
      );
    }
  }

  void _line(Canvas canvas, Map<String, dynamic> item, double step) {
    final points = (item['wayPoints'] as List)
        .cast<List>()
        .map((point) => _point(point, step))
        .toList();
    final thickness =
        _num(item['thickness'] ?? item['stroke-width'], 3) *
        step /
        _num(item['unit'], 64);
    if (thickness <= 0) return;
    final paint = Paint()
      ..color = _color(item['color'] ?? item['stroke'], _ink)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = item['stroke-linecap'] == 'butt'
          ? StrokeCap.butt
          : StrokeCap.round
      ..strokeJoin = item['stroke-linejoin'] == 'miter'
          ? StrokeJoin.miter
          : StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (item['stroke-dasharray'] != null) {
      for (var i = 1; i < points.length; i++) {
        _dash(canvas, points[i - 1], points[i], paint, step);
      }
    } else {
      canvas.drawPath(path, paint);
    }
    if (item['layer'] == 'arrows') {
      final tip = points.last;
      final direction = tip - points[points.length - 2];
      final length = _num(item['headLength'], .3) * step;
      final angle = math.atan2(direction.dy, direction.dx);
      for (final spread in [-.43, .43]) {
        canvas.drawLine(
          tip,
          tip -
              Offset(math.cos(angle + spread), math.sin(angle + spread)) *
                  length,
          paint,
        );
      }
    }
  }

  void _dash(Canvas canvas, Offset from, Offset to, Paint paint, double step) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    for (var distance = 0.0; distance < length; distance += .15 * step) {
      canvas.drawLine(
        from + delta * (distance / length),
        from + delta * (math.min(1.0, (distance + .08 * step) / length)),
        paint,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size.clamp(3, 96).toDouble(),
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  Offset _point(List position, double step) =>
      _origin +
      Offset((position[1] as num) * step, (position[0] as num) * step);
  double _num(dynamic value, double defaultValue) =>
      (value is num ? value.toDouble() : double.tryParse('$value')) ??
      defaultValue;
  Color _color(dynamic value, Color fallback) {
    if (value == null) return fallback;
    if (value == 'none' || value == 'transparent') return Colors.transparent;
    var hex = value.toString().replaceFirst('#', '');
    if (hex.length == 3 || hex.length == 4)
      hex = hex.split('').map((char) => char * 2).join();
    final rgba = int.tryParse(hex, radix: 16);
    if (rgba == null) return fallback;
    return Color(
      hex.length == 8 ? ((rgba & 0xff) << 24) | (rgba >> 8) : 0xff000000 | rgba,
    );
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.puzzle != puzzle ||
      oldDelegate.visible != visible ||
      oldDelegate.definition != definition;
}
