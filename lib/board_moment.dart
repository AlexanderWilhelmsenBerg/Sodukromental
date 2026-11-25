import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'hum.dart';

/// Brief, decorative reactions to already-committed campaign events.
class BoardMoment extends StatefulWidget {
  const BoardMoment({
    super.key,
    required this.size,
    required this.cells,
    required this.worm,
  });

  final int size;
  final List<int> cells;
  final bool worm;

  @override
  State<BoardMoment> createState() => _BoardMomentState();
}

class _BoardMomentState extends State<BoardMoment> {
  late final _BoardMomentGame _game = _BoardMomentGame(
    widget.size,
    widget.cells,
    widget.worm,
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(child: GameWidget(game: _game)),
  );
}

class _BoardMomentGame extends FlameGame {
  _BoardMomentGame(this.dimension, this.cells, this.worm);

  final int dimension;
  final List<int> cells;
  final bool worm;
  double _elapsed = 0;

  double get _duration => worm ? 1.35 : .52;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed > _duration) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_elapsed > _duration || cells.isEmpty) return;
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final cellSize = math.min(size.x, size.y) / dimension;
    final left = (size.x - cellSize * dimension) / 2;
    final top = (size.y - cellSize * dimension) / 2;
    Offset center(int index) => Offset(
      left + (index % dimension + .5) * cellSize,
      top + (index ~/ dimension + .5) * cellSize,
    );
    if (!worm) {
      final paint = Paint()
        ..color = Hum.torch.withValues(alpha: (1 - progress) * .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final index in cells) {
        canvas.drawRect(
          Rect.fromCenter(
            center: center(index),
            width: cellSize * (.58 + progress * .32),
            height: cellSize * (.58 + progress * .32),
          ),
          paint,
        );
      }
      return;
    }
    Offset point(double distance) {
      final current = distance.clamp(0.0, cells.length - 1.0);
      final from = current.floor();
      final next = math.min(from + 1, cells.length - 1);
      return Offset.lerp(
        center(cells[from]),
        center(cells[next]),
        current - from,
      )!;
    }

    final distance = progress * (cells.length - 1);
    final opacity = math.min(1.0, 8 * (1 - progress));
    final pixel = math.max(2.0, (cellSize / 11).floorToDouble());
    final paint = Paint();
    for (var segment = 4; segment >= 0; segment--) {
      final at = point(distance - segment * .22) + Offset(0, cellSize * .22);
      final position = Offset(
        (at.dx / pixel).round() * pixel,
        (at.dy / pixel).round() * pixel,
      );
      paint.color = (segment.isEven ? Hum.coral : Hum.pear).withValues(
        alpha: opacity,
      );
      canvas.drawRect(
        Rect.fromCenter(center: position, width: pixel * 5, height: pixel * 3),
        paint,
      );
      paint.color = Hum.ink.withValues(alpha: opacity);
      if (segment == 0)
        canvas.drawRect(
          Rect.fromLTWH(position.dx + pixel, position.dy - pixel, pixel, pixel),
          paint,
        );
    }
  }
}
