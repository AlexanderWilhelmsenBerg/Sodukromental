import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'creature_view.dart';
import 'creatures.dart';

/// Input-transparent idle routes from the board edge to visible, player-known
/// digits. These sprites are sourced from the owned roster and never count as
/// workers or advance a job.
class BoardRoamingLayer extends StatelessWidget {
  const BoardRoamingLayer({
    super.key,
    required this.dimension,
    required this.cells,
    required this.visible,
    required this.residents,
    required this.reducedMotion,
  });

  final int dimension;
  final List<int> cells;
  final Set<int> visible;
  final List<Creature> residents;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = constraints.maxWidth / dimension;
          return Stack(
            children: [
              for (final (order, resident) in residents.take(6).indexed)
                _BoardRoamer(
                  key: ValueKey('board-roamer-${resident.id}'),
                  resident: resident,
                  order: order,
                  step: step,
                  dimension: dimension,
                  target: _target(resident, order),
                  reducedMotion: reducedMotion,
                ),
            ],
          );
        },
      ),
    ),
  );

  int _target(Creature resident, int order) {
    final favorites = [
      for (final index in visible)
        if (index < cells.length && cells[index] == resident.favorite) index,
    ];
    if (favorites.isNotEmpty) return favorites[order % favorites.length];
    final known = visible.toList()..sort();
    return known.isEmpty
        ? order % (dimension * dimension)
        : known[order % known.length];
  }
}

class _BoardRoamer extends StatefulWidget {
  const _BoardRoamer({
    super.key,
    required this.resident,
    required this.order,
    required this.step,
    required this.dimension,
    required this.target,
    required this.reducedMotion,
  });

  final Creature resident;
  final int order;
  final double step;
  final int dimension;
  final int target;
  final bool reducedMotion;

  @override
  State<_BoardRoamer> createState() => _BoardRoamerState();
}

class _BoardRoamerState extends State<_BoardRoamer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2600 + widget.order * 230),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reducedMotion) {
      _clock.value = 1;
    } else {
      _clock.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BoardRoamer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reducedMotion == widget.reducedMotion) return;
    if (widget.reducedMotion) {
      _clock
        ..stop()
        ..value = 1;
    } else {
      _clock.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = math.max(18.0, widget.step * .34);
    final column = widget.target % widget.dimension;
    final row = widget.target ~/ widget.dimension;
    final destination = Offset(
      (column + (widget.order.isEven ? .04 : .62)) * widget.step,
      (row + .64) * widget.step,
    );
    final origin = Offset(
      widget.order.isEven ? 0 : widget.step * (widget.dimension - .35),
      destination.dy,
    );
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_clock.value);
        final at = Offset.lerp(origin, destination, progress)!;
        return Positioned(
          left: at.dx.clamp(0, widget.step * widget.dimension - extent),
          top: at.dy.clamp(0, widget.step * widget.dimension - extent),
          child: child!,
        );
      },
      child: CreatureSprite(
        creature: widget.resident,
        size: extent,
        pose: widget.reducedMotion ? CreaturePose.idle : CreaturePose.walk,
        reducedMotion: widget.reducedMotion,
      ),
    );
  }
}
