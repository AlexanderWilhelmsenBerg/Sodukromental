// Hallmark · macrostructure: Living Map · tone: playful · anchor hue: pear
// pre-emit critique: P5 H4 E4 S5 R4 V5 · contrast: pass · slop: pass
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'campaign.dart';
import 'creature_view.dart';
import 'creatures.dart';
import 'glyph_rain.dart';
import 'hum.dart';

class SettlementPlan {
  const SettlementPlan._({
    required this.plots,
    required this.street,
    required this.shapes,
  });

  static const generatorVersion = 2;
  final Map<String, Offset> plots;
  final List<Offset> street;
  final Map<String, ({int width, int height, int ridge, int door})> shapes;

  factory SettlementPlan.seeded(int seed) {
    int draw(int salt, int range) {
      var value = (seed ^ (salt * 0x45d9f3b)) & 0x7fffffff;
      value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
      value ^= value >> 16;
      return value % range;
    }

    Offset plot(int salt, int x, int y, int dx, int dy) =>
        Offset((x + draw(salt, dx)) / 100, (y + draw(salt + 29, dy)) / 100);
    ({int width, int height, int ridge, int door}) shape(
      int salt,
      int width,
      int height,
    ) => (
      width: width + draw(salt, 5),
      height: height + draw(salt + 7, 4),
      ridge: 32 + draw(salt + 13, 37),
      door: 22 + draw(salt + 19, 50),
    );

    return SettlementPlan._(
      plots: {
        'lodge': plot(11, 4, 47, 9, 10),
        'nest': plot(23, 43, 45, 15, 10),
        'house': plot(37, 62, 38, 14, 13),
        'storehouse': plot(47, 78, 45, 9, 10),
        'workshop': plot(59, 50, 13, 18, 13),
        'meeting-hall': plot(71, 69, 8, 12, 13),
        'memorial': plot(79, 56, 30, 12, 10),
      },
      street: [
        const Offset(0, .79),
        Offset((25 + draw(83, 20)) / 100, (67 + draw(89, 13)) / 100),
        Offset((52 + draw(97, 14)) / 100, (71 + draw(101, 13)) / 100),
        const Offset(1, .66),
      ],
      shapes: {
        'lodge': shape(107, 11, 11),
        'nest': shape(127, 9, 10),
        'house': shape(149, 12, 13),
        'storehouse': shape(167, 12, 11),
        'workshop': shape(181, 13, 12),
        'meeting-hall': shape(199, 17, 15),
        'memorial': shape(211, 5, 9),
      },
    );
  }

  String get structuralSignature => [
    generatorVersion,
    for (final entry in plots.entries)
      '${entry.key}:${(entry.value.dx * 100).round()},${(entry.value.dy * 100).round()}',
    for (final point in street)
      '${(point.dx * 100).round()},${(point.dy * 100).round()}',
    for (final entry in shapes.entries)
      '${entry.key}:${entry.value.width},${entry.value.height},${entry.value.ridge},${entry.value.door}',
  ].join('|');
}

/// A compact, authoritative view of the settlement attached to the board.
/// Only owned residents are drawn and carried cargo comes from real jobs.
class SettlementScene extends StatefulWidget {
  const SettlementScene({
    super.key,
    required this.seed,
    required this.creatures,
    required this.jobs,
    required this.projects,
    required this.projectProgresses,
    required this.buildings,
    required this.buildingGlyphs,
    required this.materials,
    this.campaign,
    this.reducedMotion = false,
    this.socialMoments = const [],
    this.antics = Antics.full,
    this.onResidentPressed,
  });

  final int seed;
  final List<Creature> creatures;
  final List<ColonyJob> jobs;
  final List<ProjectSpec> projects;
  final List<ProjectProgress> projectProgresses;
  final Set<String> buildings;
  final Map<String, List<MaterialGlyph>> buildingGlyphs;
  final Map<MaterialRole, int> materials;
  final Campaign? campaign;
  final bool reducedMotion;
  final List<SocialMoment> socialMoments;
  final Antics antics;
  final ValueChanged<Creature>? onResidentPressed;

  @override
  State<SettlementScene> createState() => _SettlementSceneState();
}

class _SettlementSceneState extends State<SettlementScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  bool get _still =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _clock.stop();
      _clock.value = .62;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SettlementScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reducedMotion != widget.reducedMotion) {
      if (_still) {
        _clock
          ..stop()
          ..value = .62;
      } else {
        _clock.repeat();
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeProject =
        widget.jobs
            .where((job) => job.kind == TaskKind.building)
            .map((job) => job.projectId)
            .whereType<String>()
            .firstOrNull ??
        widget.projects
            .where((project) => !widget.buildings.contains(project.id))
            .map((project) => project.id)
            .firstOrNull;
    final project = widget.projectProgresses
        .where((item) => item.projectId == activeProject)
        .firstOrNull;
    final foreground = _foregroundResidents();
    final stockedPieces = widget.materials.values.fold<int>(0, (a, b) => a + b);
    final requirement =
        project?.requirements.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final installed =
        project?.installed.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final reserved =
        project?.reserved.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final inTransit =
        project?.inTransit.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final progress = math.min(requirement, installed + reserved + inTransit);
    final label = project == null
        ? '${widget.buildings.length} buildings · ${widget.creatures.length} residents'
        : '${project.name} · $progress of $requirement pieces'
              '${inTransit > 0 ? ' · $inTransit traveling' : ''}';

    return Semantics(
      container: true,
      label:
          'Living settlement. $label.'
          '${reserved > 0 ? ' $reserved pieces reserved.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  key: const ValueKey('settlement-progress'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Hum.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_still)
                const Tooltip(
                  message: 'Reduced motion: trips show their current endpoint',
                  child: Icon(
                    Icons.motion_photos_off_outlined,
                    size: 18,
                    color: Hum.mutedInk,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.campaign case final Campaign campaign) ...[
            RainInscription(campaign: campaign),
            const SizedBox(height: 6),
          ],
          AspectRatio(
            aspectRatio: 2.05,
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _clock,
                builder: (context, _) {
                  final phase = _still ? .62 : _clock.value;
                  return ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          key: const ValueKey('settlement-map'),
                          painter: _SettlementPainter(
                            seed: widget.seed,
                            phase: phase,
                            buildings: widget.buildings,
                            project: project,
                            jobs: widget.jobs,
                            storedMaterials: stockedPieces,
                            showering:
                                widget.campaign?.weather.showering ?? false,
                            cisternStored: widget.campaign?.weather.stored ?? 0,
                            cisternCapacity: ColonyWeather.capacity,
                            bucketActive:
                                widget.campaign?.weather.carrierId != null,
                            reducedMotion: _still,
                            dark:
                                Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                        for (final (index, resident) in foreground.indexed)
                          _resident(
                            constraints.biggest,
                            resident,
                            index,
                            phase,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          _residentList(foreground),
          if (widget.socialMoments.firstOrNull case final SocialMoment moment
              when moment.kind == SocialMomentKind.argument ||
                  moment.kind == SocialMomentKind.tussle)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: widget.campaign == null
                    ? null
                    : () {
                        widget.campaign!.workApart(
                          moment.firstId,
                          moment.secondId,
                        );
                        setState(() {});
                      },
                icon: const Icon(Icons.call_split, size: 16),
                label: const Text('Work apart'),
              ),
            ),
          if (widget.socialMoments.firstOrNull case final SocialMoment moment
              when moment.kind == SocialMomentKind.returnGlyph &&
                  moment.glyphId != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: widget.campaign == null
                    ? null
                    : () {
                        widget.campaign!.returnSocialGlyph(moment.glyphId!);
                        setState(() {});
                      },
                icon: const Icon(Icons.keyboard_return, size: 16),
                label: const Text('Return letter'),
              ),
            ),
        ],
      ),
    );
  }

  List<Creature> _foregroundResidents() {
    final byId = {
      for (final creature in widget.creatures) creature.id: creature,
    };
    final result = <Creature>[];
    for (final job in widget.jobs) {
      final resident = byId[job.workerId];
      if (resident != null && !result.contains(resident)) result.add(resident);
    }
    for (final moment in widget.socialMoments) {
      for (final id in [moment.firstId, moment.secondId]) {
        final resident = byId[id];
        if (resident != null && !result.contains(resident))
          result.add(resident);
      }
    }
    for (final resident in widget.creatures) {
      // The habitat keeps one larger offer/recall actor below the scene.
      if (result.length == 5) break;
      if (!result.contains(resident)) result.add(resident);
    }
    return result.take(5).toList(growable: false);
  }

  Widget _resident(Size size, Creature resident, int index, double phase) {
    final job = widget.jobs
        .where((item) => item.workerId == resident.id)
        .firstOrNull;
    final social = widget.socialMoments
        .where((moment) => moment.involves(resident.id))
        .firstOrNull;
    final offset = (phase + (index % 3) / 3) % 1;
    final isWorking = job != null || social?.kind == SocialMomentKind.handoff;
    final sleeping = !isWorking && offset > .58 && offset < .82;
    final p = isWorking ? offset : (math.sin(offset * math.pi * 2) + 1) / 2;
    final start = Offset(
      size.width * (.07 + index % 2 * .08),
      size.height * .69,
    );
    final socialSide = social?.firstId == resident.id ? -.06 : .06;
    final socialVisible =
        social != null &&
        (job == null || social.kind == SocialMomentKind.handoff);
    final end = socialVisible
        ? Offset(size.width * (.53 + socialSide), size.height * .64)
        : switch (job?.kind) {
            TaskKind.digit => Offset(size.width * .82, size.height * .67),
            TaskKind.torch => Offset(size.width * .88, size.height * .30),
            TaskKind.building => Offset(size.width * .66, size.height * .54),
            null => Offset(
              size.width * (.32 + index % 3 * .17),
              size.height * .72,
            ),
          };
    final at = _still || sleeping
        ? end
        : Offset.lerp(start, end, Curves.easeInOut.transform(p))!;
    final spriteSize = size.width < 330 ? 42.0 : 48.0;
    final cargo = switch (job?.kind) {
      TaskKind.digit =>
        job!.count > 1 ? '${job.digit}×${job.count}' : '${job.digit}',
      TaskKind.torch => '✶',
      TaskKind.building => job!.glyphs.map((glyph) => glyph.glyph).join(),
      null => null,
    };
    return Positioned(
      left: (at.dx - spriteSize / 2)
          .clamp(0, size.width - spriteSize)
          .toDouble(),
      top: (at.dy - spriteSize * .72)
          .clamp(0, size.height - spriteSize)
          .toDouble(),
      child: IgnorePointer(
        child: CreatureSprite(
          creature: resident,
          size: spriteSize,
          pose: socialVisible
              ? switch (social.kind) {
                  SocialMomentKind.greeting => CreaturePose.cheer,
                  SocialMomentKind.handoff => CreaturePose.carry,
                  SocialMomentKind.argument => CreaturePose.recoil,
                  SocialMomentKind.tussle => CreaturePose.tussle,
                  SocialMomentKind.returnGlyph => CreaturePose.carry,
                  SocialMomentKind.standOff => CreaturePose.puzzled,
                }
              : switch (job?.kind) {
                  TaskKind.torch => CreaturePose.torch,
                  TaskKind.building => CreaturePose.work,
                  TaskKind.digit => CreaturePose.carry,
                  null =>
                    sleeping || _still ? CreaturePose.sleep : CreaturePose.walk,
                },
          cargo: social?.kind == SocialMomentKind.returnGlyph ? 'A' : cargo,
          reducedMotion: _still,
        ),
      ),
    );
  }

  Widget _residentList(List<Creature> residents) {
    if (residents.isEmpty) return const SizedBox.shrink();
    final busy = {for (final job in widget.jobs) job.workerId: job};
    final social = {
      for (final moment in widget.socialMoments) moment.firstId: moment,
      for (final moment in widget.socialMoments) moment.secondId: moment,
    };
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final resident in residents)
          Tooltip(
            message: _residentStatus(
              resident,
              busy[resident.id],
              social[resident.id],
            ),
            child: ActionChip(
              avatar: Icon(
                busy.containsKey(resident.id)
                    ? Icons.directions_walk
                    : Icons.bedtime_outlined,
                size: 16,
              ),
              label: Text(resident.name),
              onPressed: widget.onResidentPressed == null
                  ? null
                  : () => widget.onResidentPressed!(resident),
            ),
          ),
      ],
    );
  }

  String _residentStatus(
    Creature resident,
    ColonyJob? job,
    SocialMoment? social,
  ) => social == null
      ? switch (job?.kind) {
          TaskKind.digit => '${resident.name} is carrying digit ${job!.digit}',
          TaskKind.torch => '${resident.name} is carrying a torch',
          TaskKind.building => '${resident.name} is hauling a cut letter',
          null => '${resident.name} is resting at home',
        }
      : switch (social.kind) {
          SocialMomentKind.greeting =>
            '${resident.name} is greeting a neighbor',
          SocialMomentKind.handoff => '${resident.name} is handing off a load',
          SocialMomentKind.argument =>
            '${resident.name} is arguing with a neighbor',
          SocialMomentKind.tussle => '${resident.name} is in a brief tussle',
          SocialMomentKind.standOff =>
            '${resident.name} is giving a neighbor room',
          SocialMomentKind.returnGlyph =>
            '${resident.name} is returning a letter',
        };
}

class _SettlementPainter extends CustomPainter {
  const _SettlementPainter({
    required this.seed,
    required this.phase,
    required this.buildings,
    required this.project,
    required this.jobs,
    required this.storedMaterials,
    required this.showering,
    required this.cisternStored,
    required this.cisternCapacity,
    required this.bucketActive,
    required this.reducedMotion,
    required this.dark,
  });

  final int seed;
  final double phase;
  final Set<String> buildings;
  final ProjectProgress? project;
  final List<ColonyJob> jobs;
  final int storedMaterials;
  final bool showering;
  final int cisternStored;
  final int cisternCapacity;
  final bool bucketActive;
  final bool reducedMotion;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.max(2.0, (size.shortestSide / 48).floorToDouble());
    final plan = SettlementPlan.seeded(seed);
    final paint = Paint()..isAntiAlias = false;
    final rng = math.Random(seed ^ 0x51de);
    final ground = dark ? Hum.fog : Hum.paper;
    final soil = dark ? Hum.grid : Hum.torch.withValues(alpha: .72);
    final path = dark ? Hum.mutedInk : Hum.pearEdge.withValues(alpha: .58);
    final wall = dark ? Hum.grid : Hum.mutedInk;
    final roof = dark ? Hum.coral.withValues(alpha: .72) : Hum.coral;
    final water = dark ? Hum.cyan : Hum.focus;

    canvas.drawRect(Offset.zero & size, paint..color = ground);
    for (var i = 0; i < 7; i++) {
      final x = (rng.nextDouble() * size.width / unit).floor() * unit;
      final y = (rng.nextDouble() * size.height * .72 / unit).floor() * unit;
      canvas.drawRect(
        Rect.fromLTWH(x, y, unit * (1 + rng.nextInt(3)), unit),
        paint..color = i.isEven ? Hum.pearEdge : soil,
      );
    }

    Offset scaled(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    final street = Path()..moveTo(0, scaled(plan.street.first).dy);
    for (final point in plan.street.skip(1)) {
      street.lineTo(scaled(point).dx, scaled(point).dy);
    }
    canvas.drawPath(
      street,
      paint
        ..color = path
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 5,
    );
    final visibleBuildings = <String>{'lodge', ...buildings};
    double streetY(double x) {
      for (var i = 0; i < plan.street.length - 1; i++) {
        final a = plan.street[i];
        final b = plan.street[i + 1];
        if (x >= a.dx && x <= b.dx) {
          final progress = (x - a.dx) / (b.dx - a.dx);
          return a.dy + (b.dy - a.dy) * progress;
        }
      }
      return plan.street.last.dy;
    }

    for (final id in visibleBuildings) {
      final plot = plan.plots[id];
      final shape = plan.shapes[id];
      if (plot == null || shape == null) continue;
      final entranceX =
          plot.dx * size.width + shape.width * unit * shape.door / 100;
      final entranceY = plot.dy * size.height + shape.height * unit * .62;
      canvas.drawLine(
        Offset(entranceX, entranceY),
        Offset(entranceX, streetY(entranceX / size.width) * size.height),
        paint
          ..color = path
          ..strokeWidth = unit * 2,
      );
    }
    paint.style = PaintingStyle.fill;

    final lodgeAt = scaled(plan.plots['lodge']!);
    _building(canvas, unit, lodgeAt, plan.shapes['lodge']!, wall, roof);
    _cuttingBlock(
      canvas,
      unit,
      lodgeAt + Offset(plan.shapes['lodge']!.width * unit + unit * 2, unit * 7),
      wall,
    );
    _cistern(
      canvas,
      unit,
      scaled(plan.street[1]) - Offset(0, unit * 6),
      water,
      cisternStored,
      cisternCapacity,
      bucketActive,
    );
    _shatterPile(canvas, unit, scaled(plan.street[1]) + Offset(unit * 3, 0));
    if (buildings.contains('nest')) {
      _building(
        canvas,
        unit,
        scaled(plan.plots['nest']!),
        plan.shapes['nest']!,
        wall,
        Hum.pear,
      );
    }
    if (buildings.contains('house')) {
      _building(
        canvas,
        unit,
        scaled(plan.plots['house']!),
        plan.shapes['house']!,
        wall,
        roof,
      );
    }
    if (buildings.contains('storehouse')) {
      _building(
        canvas,
        unit,
        scaled(plan.plots['storehouse']!),
        plan.shapes['storehouse']!,
        wall,
        Hum.cyan,
      );
      for (var i = 0; i < math.min(4, storedMaterials); i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            scaled(plan.plots['storehouse']!).dx + unit * 2 + i % 2 * unit * 3,
            scaled(plan.plots['storehouse']!).dy + unit * 7 + i ~/ 2 * unit * 2,
            unit * 2,
            unit,
          ),
          paint..color = Hum.pearEdge,
        );
      }
    }
    if (buildings.contains('workshop')) {
      _building(
        canvas,
        unit,
        scaled(plan.plots['workshop']!),
        plan.shapes['workshop']!,
        wall,
        Hum.cyan,
      );
    }
    if (buildings.contains('meeting-hall')) {
      _building(
        canvas,
        unit,
        scaled(plan.plots['meeting-hall']!),
        plan.shapes['meeting-hall']!,
        wall,
        Hum.torch,
      );
    }
    if (buildings.contains('memorial')) {
      _memorial(
        canvas,
        unit,
        scaled(plan.plots['memorial']!),
        plan.shapes['memorial']!,
      );
    }

    _projectSockets(canvas, size, unit, project, wall);
    _cutLetters(canvas, size, unit, jobs);
    _torch(canvas, size, unit, jobs);
    if (showering) _rain(canvas, size, unit, water);
  }

  void _building(
    Canvas canvas,
    double u,
    Offset origin,
    ({int width, int height, int ridge, int door}) shape,
    Color wall,
    Color roof,
  ) {
    final paint = Paint()..isAntiAlias = false;
    final w = shape.width * u;
    final h = shape.height * u;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, w, h * .62),
      paint..color = wall,
    );
    final ridge = shape.ridge / 100;
    final roofPath = Path()
      ..moveTo(origin.dx - u, origin.dy)
      ..lineTo(origin.dx + w * ridge, origin.dy - h * .32)
      ..lineTo(origin.dx + w + u, origin.dy)
      ..close();
    canvas.drawPath(roofPath, paint..color = roof);
    for (var x = origin.dx; x < origin.dx + w; x += u * 3) {
      canvas.drawRect(
        Rect.fromLTWH(x, origin.dy - u, u * 2, u),
        paint..color = Hum.ink.withValues(alpha: .55),
      );
    }
    for (var y = origin.dy + u * 2; y < origin.dy + h * .62; y += u * 3) {
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, y, w, u * .45),
        paint..color = Hum.ink.withValues(alpha: .18),
      );
    }
    if ((shape.ridge + shape.width).isOdd) {
      canvas.drawRect(
        Rect.fromLTWH(origin.dx + w * .72, origin.dy - h * .34, u * 2, u * 4),
        paint..color = Hum.ink,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + w * shape.door / 100,
        origin.dy + h * .29,
        u * 3,
        h * .33,
      ),
      paint..color = Hum.ink,
    );
  }

  void _cuttingBlock(Canvas canvas, double u, Offset at, Color wood) {
    final p = Paint()..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, u * 8, u * 3), p..color = wood);
    canvas.drawRect(
      Rect.fromLTWH(at.dx + u, at.dy - u * 2, u * 6, u),
      p..color = Hum.pearEdge,
    );
    canvas.drawRect(
      Rect.fromLTWH(at.dx + u * 5, at.dy - u * 5, u, u * 4),
      p..color = Hum.ink,
    );
  }

  void _memorial(
    Canvas canvas,
    double u,
    Offset at,
    ({int width, int height, int ridge, int door}) shape,
  ) {
    final paint = Paint()..isAntiAlias = false;
    final width = shape.width * u;
    final height = shape.height * u;
    canvas.drawRect(
      Rect.fromLTWH(at.dx, at.dy + height * .25, width, height * .75),
      paint..color = Hum.grid,
    );
    canvas.drawRect(
      Rect.fromLTWH(at.dx - u, at.dy + height, width + u * 2, u * 2),
      paint..color = Hum.mutedInk,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(at.dx + width / 2, at.dy + height * .48),
        width: u * 2,
        height: u * 2,
      ),
      paint..color = Hum.torch,
    );
  }

  void _cistern(
    Canvas canvas,
    double u,
    Offset at,
    Color water,
    int stored,
    int capacity,
    bool bucketActive,
  ) {
    final p = Paint()..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(at.dx, at.dy, u * 7, u * 4),
      p..color = Hum.grid,
    );
    final fill = capacity == 0 ? 0.0 : stored / capacity;
    canvas.drawRect(
      Rect.fromLTWH(at.dx + u, at.dy + u * (3 - 2 * fill), u * 5, u * 2 * fill),
      p..color = water.withValues(alpha: .72),
    );
    canvas.drawRect(
      Rect.fromLTWH(at.dx + u * 7, at.dy + u * 2, u * 2, u),
      p..color = Hum.pearEdge,
    );
    if (bucketActive) {
      canvas.drawRect(
        Rect.fromLTWH(at.dx - u * 3, at.dy + u, u * 2, u * 3),
        p..color = Hum.cyan,
      );
      canvas.drawRect(
        Rect.fromLTWH(at.dx - u * 3, at.dy, u * 2, u),
        p..color = Hum.ink,
      );
    }
  }

  void _shatterPile(Canvas canvas, double u, Offset at) {
    final p = Paint()..isAntiAlias = false;
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(at.dx + i * u * 1.4, at.dy + (i % 2) * u);
      canvas.rotate((i.isEven ? -1 : 1) * math.pi / 8);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, u * 2.4, u),
        p..color = i.isEven ? Hum.grid : Hum.pearEdge,
      );
      canvas.restore();
    }
  }

  void _projectSockets(
    Canvas canvas,
    Size size,
    double u,
    ProjectProgress? project,
    Color wood,
  ) {
    if (project == null) return;
    final count = project.requirements.values.fold<int>(0, (a, b) => a + b);
    final installed = project.installed.values.fold<int>(0, (a, b) => a + b);
    final traveling = project.inTransit.values.fold<int>(0, (a, b) => a + b);
    final reserved = project.reserved.values.fold<int>(0, (a, b) => a + b);
    final p = Paint()
      ..isAntiAlias = false
      ..strokeWidth = u;
    final left = size.width * .61;
    final top = size.height * .38;
    for (var i = 0; i < count; i++) {
      final rect = Rect.fromLTWH(
        left + i % 4 * u * 4,
        top + i ~/ 4 * u * 3,
        u * 3,
        u * 2,
      );
      canvas.drawRect(
        rect,
        p
          ..color = i < installed
              ? wood
              : i < installed + traveling
              ? Hum.pearEdge
              : i < installed + traveling + reserved
              ? Hum.cyan
              : Hum.grid.withValues(alpha: .7)
          ..style = i < installed + traveling
              ? PaintingStyle.fill
              : PaintingStyle.stroke,
      );
    }
  }

  void _cutLetters(Canvas canvas, Size size, double u, List<ColonyJob> jobs) {
    final harvesting = jobs
        .where((job) => job.kind == TaskKind.building)
        .expand((job) => job.glyphs)
        .toList();
    final p = Paint()..isAntiAlias = false;
    for (var i = 0; i < harvesting.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .35 + i % 3 * u * 3,
          size.height * .54 + i ~/ 3 * u * 2,
          u * 2,
          u,
        ),
        p..color = Hum.pearEdge,
      );
    }
  }

  void _torch(Canvas canvas, Size size, double u, List<ColonyJob> jobs) {
    if (!jobs.any((job) => job.kind == TaskKind.torch)) return;
    final center = Offset(size.width * .91, size.height * .18);
    final pulse = reducedMotion
        ? 1.0
        : .78 + math.sin(phase * math.pi * 10) * .12;
    canvas.drawCircle(
      center,
      u * 5,
      Paint()..color = Hum.torch.withValues(alpha: .18 * pulse),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: u * 2, height: u * 4),
      Paint()..color = Hum.torch.withValues(alpha: pulse),
    );
  }

  void _rain(Canvas canvas, Size size, double u, Color water) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = water.withValues(alpha: dark ? .6 : .36)
      ..strokeWidth = u;
    for (var i = 0; i < 9; i++) {
      final x = ((seed * 13 + i * 47) % 101) / 101 * size.width;
      final drop = reducedMotion ? .68 : (phase * 1.7 + i / 9) % 1;
      final y = drop * size.height * .48;
      canvas.drawLine(Offset(x, y), Offset(x - u, y + u * 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _SettlementPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.seed != seed ||
      oldDelegate.project?.projectId != project?.projectId ||
      oldDelegate.jobs != jobs ||
      oldDelegate.buildings != buildings ||
      oldDelegate.storedMaterials != storedMaterials ||
      oldDelegate.showering != showering ||
      oldDelegate.cisternStored != cisternStored ||
      oldDelegate.cisternCapacity != cisternCapacity ||
      oldDelegate.bucketActive != bucketActive ||
      oldDelegate.dark != dark;
}
