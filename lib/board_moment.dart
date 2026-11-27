import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'creature_view.dart';
import 'creatures.dart';
import 'hum.dart';

/// A named resident curled into its verified numeral address. Board input stays
/// available because the entire overlay ignores pointer events.
class ResidentHomeMoment extends StatelessWidget {
  const ResidentHomeMoment({
    super.key,
    required this.dimension,
    required this.cell,
    required this.resident,
    this.reducedMotion = false,
  });

  final int dimension;
  final int cell;
  final Creature resident;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = constraints.maxWidth / dimension;
          final size = math.max(18.0, step * .46);
          return Stack(
            children: [
              Positioned(
                left: cell % dimension * step + step - size,
                top: cell ~/ dimension * step + step - size,
                child: Opacity(
                  opacity: .78,
                  child: CreatureSprite(
                    creature: resident,
                    pose: CreaturePose.sleep,
                    size: size,
                    reducedMotion: reducedMotion,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// An owned torchbearer walking a real reveal route. The overlay never handles
/// input; it is a visual projection of an already-dispatched torch job.
class TorchRouteMoment extends StatefulWidget {
  const TorchRouteMoment({
    super.key,
    required this.dimension,
    required this.cells,
    required this.worker,
    this.reducedMotion = false,
  });

  final int dimension;
  final List<int> cells;
  final Creature worker;
  final bool reducedMotion;

  @override
  State<TorchRouteMoment> createState() => _TorchRouteMomentState();
}

class _TorchRouteMomentState extends State<TorchRouteMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reducedMotion || MediaQuery.disableAnimationsOf(context);
    if (still && _clock.isAnimating) _clock.stop();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final progress = still
                  ? 1.0
                  : Curves.easeInOut.transform(_clock.value);
              final cells = widget.cells.isEmpty ? const [0] : widget.cells;
              final from = cells.first;
              final to = cells.last;
              Offset center(int index) => Offset(
                (index % widget.dimension + .5) *
                    constraints.maxWidth /
                    widget.dimension,
                (index ~/ widget.dimension + .5) *
                    constraints.maxHeight /
                    widget.dimension,
              );
              final at = Offset.lerp(center(from), center(to), progress)!;
              final sprite = math.max(
                32.0,
                constraints.maxWidth / widget.dimension * .72,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TorchRoutePainter(
                        from: center(from),
                        to: center(to),
                        phase: still ? .5 : _clock.value,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (at.dx - sprite / 2)
                        .clamp(0, constraints.maxWidth - sprite)
                        .toDouble(),
                    top: (at.dy - sprite * .72)
                        .clamp(0, constraints.maxHeight - sprite)
                        .toDouble(),
                    child: CreatureSprite(
                      creature: widget.worker,
                      pose: CreaturePose.torch,
                      cargo: '✶',
                      size: sprite,
                      reducedMotion: still,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TorchRoutePainter extends CustomPainter {
  const _TorchRoutePainter({
    required this.from,
    required this.to,
    required this.phase,
  });
  final Offset from;
  final Offset to;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final flicker = .62 + math.sin(phase * math.pi * 12) * .12;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(size.width * .5, size.height * .12, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Hum.torch.withValues(alpha: .55),
    );
    canvas.drawCircle(
      to,
      11,
      Paint()..color = Hum.torch.withValues(alpha: flicker * .22),
    );
  }

  @override
  bool shouldRepaint(covariant _TorchRoutePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}

/// Workers opening the completed classic grid. [openedSeams] is authoritative;
/// animation cannot advance the ledger.
class GridShatterMoment extends StatelessWidget {
  const GridShatterMoment({
    super.key,
    required this.dimension,
    required this.openedSeams,
    required this.totalSeams,
    required this.workers,
    this.reducedMotion = false,
  });

  final int dimension;
  final int openedSeams;
  final int totalSeams;
  final List<Creature> workers;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final workerCount = math.min(4, workers.length);
          final sprite = math.max(34.0, constraints.maxWidth / dimension);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  key: ValueKey('grid-shatter-$openedSeams'),
                  painter: _GridShatterPainter(
                    dimension: dimension,
                    openedSeams: openedSeams,
                    totalSeams: totalSeams,
                    reducedMotion:
                        reducedMotion ||
                        MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
              for (var i = 0; i < workerCount; i++)
                Positioned(
                  left: (constraints.maxWidth * (.1 + i * .21))
                      .clamp(0, constraints.maxWidth - sprite)
                      .toDouble(),
                  top: (constraints.maxHeight * (.32 + (i % 2) * .28))
                      .clamp(0, constraints.maxHeight - sprite)
                      .toDouble(),
                  child: CreatureSprite(
                    creature: workers[i],
                    pose: CreaturePose.work,
                    cargo: i < openedSeams ? '◆' : null,
                    size: sprite,
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

class _GridShatterPainter extends CustomPainter {
  const _GridShatterPainter({
    required this.dimension,
    required this.openedSeams,
    required this.totalSeams,
    required this.reducedMotion,
  });

  final int dimension;
  final int openedSeams;
  final int totalSeams;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (openedSeams == 0 || totalSeams == 0) return;
    final step = size.shortestSide / dimension;
    final paint = Paint()
      ..isAntiAlias = false
      ..strokeWidth = math.max(2, step / 10)
      ..style = PaintingStyle.stroke
      ..color = Hum.pearEdge;
    for (var seam = 0; seam < openedSeams; seam++) {
      final vertical = seam.isEven;
      final track = 1 + seam ~/ 2 % math.max(1, dimension - 1);
      final along = (seam * 37 % 73) / 73;
      final center = vertical
          ? Offset(track * step, (along * .65 + .16) * size.height)
          : Offset((along * .65 + .16) * size.width, track * step);
      final crack = Path()..moveTo(center.dx, center.dy);
      for (var segment = 1; segment <= 3; segment++) {
        crack.relativeLineTo(
          vertical ? (segment.isEven ? -1 : 1) * step * .12 : step * .18,
          vertical ? step * .18 : (segment.isEven ? -1 : 1) * step * .12,
        );
      }
      canvas.drawPath(crack, paint);
      if (openedSeams == totalSeams || !reducedMotion) {
        canvas.drawRect(
          Rect.fromCenter(
            center: center + Offset(step * .18, step * .2),
            width: step * .23,
            height: step * .12,
          ),
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridShatterPainter oldDelegate) =>
      oldDelegate.openedSeams != openedSeams ||
      oldDelegate.totalSeams != totalSeams ||
      oldDelegate.dimension != dimension ||
      oldDelegate.reducedMotion != reducedMotion;
}

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
