import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'creatures.dart';

/// Contact-preserving procedural poses shared by the hatch preview and colony.
/// `travel` remains as the legacy alias used by existing screens.
enum CreaturePose {
  idle,
  travel,
  walk,
  run,
  crouch,
  carry,
  poke,
  recoil,
  plant,
  tussle,
  returnHome,
  sleep,
  work,
  torch,
  cheer,
  puzzled,
}

class CreatureSprite extends StatelessWidget {
  const CreatureSprite({
    super.key,
    required this.creature,
    this.size = 72,
    this.pose = CreaturePose.idle,
    this.cargo,
    this.reducedMotion = false,
  });

  final Creature creature;
  final double size;
  final CreaturePose pose;
  final String? cargo;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final staticPose = reducedMotion || MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: staticPose
            ? CustomPaint(painter: _CreaturePainter(creature, pose, cargo, 0))
            : _MovingSprite(creature: creature, pose: pose, cargo: cargo),
      ),
    );
  }

  static Future<Uint8List> renderPng(Creature creature) async {
    final recorder = ui.PictureRecorder();
    _CreaturePainter(
      creature,
      CreaturePose.idle,
      null,
      0,
    ).paint(Canvas(recorder), const Size.square(72));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(72, 72);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Could not draw the companion.');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}

class _MovingSprite extends StatefulWidget {
  const _MovingSprite({required this.creature, required this.pose, this.cargo});

  final Creature creature;
  final CreaturePose pose;
  final String? cargo;

  @override
  State<_MovingSprite> createState() => _MovingSpriteState();
}

class _MovingSpriteState extends State<_MovingSprite>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (_, _) => CustomPaint(
      painter: _CreaturePainter(
        widget.creature,
        widget.pose,
        widget.cargo,
        _clock.value,
      ),
    ),
  );
}

class _CreaturePainter extends CustomPainter {
  const _CreaturePainter(this.creature, this.pose, this.cargo, this.phase);

  final Creature creature;
  final CreaturePose pose;
  final String? cargo;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final relativeSize = size.shortestSide / 36;
    final scale = relativeSize < 1
        ? relativeSize
        : relativeSize.floorToDouble();
    canvas.save();
    canvas.translate(
      ((size.width - scale * 36) / 2).roundToDouble(),
      ((size.height - scale * 36) / 2).roundToDouble(),
    );
    canvas.scale(scale);
    final parts = creature.appearance.parts;
    final ink = Color(CreatureAppearance.outline);
    final palette = creature.appearance.palette;
    final skin = Color(palette[0]);
    final shadow = Color(palette[1]);
    final light = Color(palette[2]);
    final paint = Paint()..isAntiAlias = false;
    void box(num x, num y, num w, num h, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(
          x.roundToDouble(),
          y.roundToDouble(),
          w.toDouble(),
          h.toDouble(),
        ),
        paint..color = color,
      );
    }

    void blob(int x, int y, int w, int h, Color fill) {
      box(x + 2, y, w - 4, h, ink);
      box(x, y + 2, w, h - 4, ink);
      box(x + 2, y + 1, w - 4, h - 2, fill);
      box(x + 1, y + 3, w - 2, h - 6, fill);
    }

    final wave = math.sin(phase * math.pi * 2);
    final moving = const {
      CreaturePose.travel,
      CreaturePose.walk,
      CreaturePose.run,
      CreaturePose.carry,
      CreaturePose.returnHome,
      CreaturePose.tussle,
    }.contains(pose);
    final cheering = pose == CreaturePose.cheer;
    final sleeping = pose == CreaturePose.sleep;
    final crouching = pose == CreaturePose.crouch || pose == CreaturePose.plant;
    final hovering = parts.contains('hover');
    final slime = parts.contains('slime');
    final dims = switch (parts.firstWhere(
      (part) => growthById[part]?.group == GrowthGroup.shape,
      orElse: () => 'round',
    )) {
      'long' => (22, 13),
      'squat' => (20, 12),
      'flat' => (26, 9),
      'segmented' => (23, 13),
      'lobes' => (22, 14),
      _ => (18, 16),
    };
    final speed = pose == CreaturePose.run ? 1.6 : 1.0;
    final stretch = slime && moving ? (wave * 2 * speed).round() : 0;
    final w = dims.$1 + stretch;
    final h = dims.$2 - stretch;
    final x = 18 - w ~/ 2;
    final bottom =
        27 +
        (crouching ? 2 : 0) -
        (hovering
            ? 4 + wave.round()
            : cheering
            ? (wave.abs() * 3).round()
            : 0);
    final y = bottom - h;
    final end = x + w;
    final face = end - 6;

    box(10, 30, 16, 1, const Color(0x40212832));
    final legs = switch (parts.firstWhere(
      (part) => growthById[part]?.group == GrowthGroup.locomotion,
      orElse: () => 'bipedal',
    )) {
      'quadrupedal' => 4,
      'six-legs' => 6,
      'tiny-feet' => 8,
      'hover' || 'slime' => 0,
      _ => 2,
    };
    for (var i = 0; i < legs; i++) {
      final foot = x + 2 + i * (w - 6) ~/ math.max(1, legs - 1);
      final gaitPhase = legs > 4
          ? math.pi * 2 * (i % 3) / 3
          : legs == 4
          ? math.pi * (i ~/ 2)
          : math.pi * (i % 2);
      final step = math.sin(phase * 2 * math.pi + gaitPhase);
      final stride = moving ? (step * (legs > 4 ? 1 : 2) * speed).round() : 0;
      final lift = moving ? math.max(0, -step).round() : 0;
      final footColor = parts.contains('clear-paws')
          ? light.withAlpha(130)
          : shadow;
      box(foot, bottom - 2, 2, math.max(2, 4 - lift), ink);
      box(foot + stride, bottom + 1 - lift, 3, 2, footColor);
      box(foot + stride, bottom + 3 - lift, 3, 1, ink);
      if (parts.contains('ankle-ears') && i == 0) {
        box(foot - 1, bottom - 2, 2, 3, light);
      }
    }

    if (legs == 0 && parts.contains('ankle-ears')) {
      box(x + 1, bottom - 3, 2, 4, ink);
      box(x + 1, bottom - 3, 1, 3, light);
    }

    if (parts.contains('hooked-tail')) {
      box(x - 3, bottom - 4, 5, 2, ink);
      box(x - 4, bottom - 7, 2, 4, shadow);
      if (parts.contains('tail-feet')) {
        final trot = (math.sin(phase * 4 * math.pi) * 2).round();
        box(x - 5 + trot, bottom - 2, 2, 4, ink);
        box(x - 3 - trot, bottom - 2, 2, 4, shadow);
      }
    }

    if (parts.contains('lobes')) {
      blob(x, y + (wave * 2).round(), w ~/ 2 + 2, h, shadow);
      blob(x + w ~/ 2 - 2, y, w ~/ 2 + 2, h, skin);
    } else if (parts.contains('segmented')) {
      for (var i = 0; i < 3; i++) {
        blob(
          x + i * (w - 11) ~/ 2,
          y + 2 - i,
          11,
          h - 2 + i,
          i.isEven ? skin : shadow,
        );
      }
    } else {
      blob(x, y, w, h, skin);
    }
    box(x + 3, bottom - 3, w - 6, 2, shadow);
    if (slime) box(x + 2, bottom - 1, w - 4, 1, ink);
    if (hovering) box(13, bottom + 3, 10, 1, light);

    final coat = parts.firstWhere(
      (part) => growthById[part]?.group == GrowthGroup.coat,
      orElse: () => 'smooth',
    );
    switch (coat) {
      case 'fur':
        for (var i = 2; i < w - 2; i += 3) {
          box(x + i, y - i % 2, 1, 2, ink);
        }
      case 'gel':
        box(x + 3, y + 3, 5, 2, light);
      case 'scales':
        for (var i = 3; i < w ~/ 2; i += 3) {
          box(x + i, y + 4 + i % 2, 2, 2, shadow);
          box(x + i + 1, y + 3 + i % 2, 1, 1, light);
        }
      case 'plates':
        for (var i = 4; i < w ~/ 2; i += 3) {
          box(x + i, y + 2, 1, h - 5, shadow);
        }
      case 'paper':
        for (var i = 3; i < h - 3; i += 2) {
          box(x + 2 + i % 3, y + i, w ~/ 3, 1, light);
        }
    }

    switch (creature.appearance.marking) {
      case 'stripe':
        box(x + 4, bottom - 7, 2, 4, light);
      case 'diamond':
        box(x + 4, bottom - 7, 3, 2, light);
        box(x + 5, bottom - 8, 1, 4, light);
      case 'freckles':
        box(x + 3, bottom - 7, 1, 1, light);
        box(x + 6, bottom - 6, 1, 1, light);
        box(x + 5, bottom - 9, 1, 1, light);
      default:
        box(x + 5, bottom - 7, 2, 2, light);
    }

    final puzzled = pose == CreaturePose.puzzled || pose == CreaturePose.poke;
    final expression = creature.personality;
    final eyeY = y + 3 + (parts.contains('head-bob') ? wave.round() : 0);
    final stalks = parts.contains('stalks');
    final eyeCount = parts.contains('rotating-eye')
        ? 1
        : creature.appearance.eyeCount;
    for (var i = 0; i < eyeCount; i++) {
      final eye = face - i * 4;
      if (stalks) {
        box(eye, y - 3, 1, 5, ink);
        box(eye - 1, y - 5, 3, 3, light);
        box(eye, y - 4, 1, 1, ink);
      } else {
        final peek = expression == Personality.curious && puzzled;
        final lid = eyeY + (peek && i.isOdd ? wave.round() : 0);
        final blink = sleeping || phase > 0.93;
        if (blink) {
          box(eye - 1, lid + 2, 3, 1, ink);
        } else {
          box(eye - 1, lid, 3, 3, light);
          box(
            eye + (peek || parts.contains('rotating-eye') ? wave.round() : 0),
            lid + 1,
            1,
            2,
            ink,
          );
        }
        if (expression == Personality.tinkerer && puzzled) {
          box(eye - 1 + i % 2, lid - 1, 2, 1, ink);
        }
      }
    }
    final mouthY = math.min(bottom - 3, eyeY + 5);
    box(face + 1, mouthY, 3, cheering ? 2 : 1, ink);
    if (expression == Personality.collector) {
      box(face + 3, mouthY - 1, 1, 1, ink);
    }
    if (creature.appearance.cheeks)
      box(face - 2, mouthY, 2, 1, const Color(0xfff3a291));
    if (parts.contains('whiskers')) {
      box(end - 1, mouthY - 1, 4, 1, ink);
      box(end, mouthY + 1, 3, 1, ink);
    }
    if (parts.contains('ears')) {
      box(x + 4, y - 4, 3, 5, ink);
      box(x + 5, y - 3, 1, 4, light);
    }
    if (parts.contains('feelers') ||
        parts.contains('small-feeler') ||
        parts.contains('fan-feelers')) {
      final fan = parts.contains('fan-feelers')
          ? (wave * 2).round()
          : wave.round();
      box(x + 5, y - 4, 1, 4, ink);
      box(x + 5 + fan, y - 5, 2, 2, light);
    }
    if (parts.contains('scallop')) box(x + 1, y + 1, 2, 2, light);
    if (parts.contains('cheek-dots')) box(face - 2, mouthY + 1, 1, 1, light);

    if (parts.contains('under-fur')) {
      for (var i = 4; i < w - 3; i += 3) {
        box(x + i, bottom - 1, 1, 3, light);
      }
    }
    if (parts.contains('knee-fin')) box(x - 1, bottom - 4, 4, 2, light);
    if (parts.contains('belly-hinge')) {
      box(x + w ~/ 2 - 2, bottom - 4, 4, 1, ink);
      box(x + w ~/ 2, bottom - 5 + wave.round(), 1, 3, light);
    }
    if (parts.contains('elbow-fur')) box(x - 1, bottom - 6, 3, 2, light);
    if (parts.contains('floating-hand')) {
      final orbit = (math.cos(phase * 2 * math.pi) * 2).round();
      box(end + orbit, y - 3 + wave.round(), 3, 2, light);
      box(end + orbit + 1, y - 4 + wave.round(), 2, 1, ink);
    }
    if (parts.contains('yawning-mouth')) {
      box(x + 4, bottom - 6, 3, 1 + (wave.abs() * 2).round(), ink);
    }
    if (parts.contains('tail-tap'))
      box(x - 3, bottom - 2 + wave.round(), 4, 1, shadow);
    if (parts.contains('side-flap'))
      box(x - 1, y + 4 + wave.round(), 3, 2, light);

    // Life decisions remain legible at sprite scale. Each response owns a
    // stable attachment, even when several responses compose on one body.
    for (final choice
        in creature.recipe.ecologyPath?.decisions.values ??
            const <EcologyChoice>[]) {
      final slot = choice.index % 4;
      final ax = x + 2 + slot * math.max(2, (w - 7) ~/ 3);
      final ay = y - 2 - choice.family.index;
      switch (choice.index % 4) {
        case 0:
          box(ax, ay, 4, 2, ink);
          box(ax + 1, ay, 2, 1, light);
        case 1:
          box(ax, ay - 1, 2, 3, ink);
          box(ax + 3, ay - 1, 2, 3, ink);
          box(ax + 1, ay, 3, 1, light);
        case 2:
          box(ax, ay, 5, 1, ink);
          box(ax + 2, ay - 2, 1, 4, light);
        case 3:
          box(ax, ay - 1, 4, 3, ink);
          box(ax + 1, ay, 2, 1, light);
      }
    }
    if (parts.contains('crown-brace')) box(x + 2, y - 6, w - 5, 2, shadow);
    if (parts.contains('lit-gills'))
      box(x + 3, y + 2, w - 7, 2, const Color(0xffffcc60));
    if (parts.contains('free-forelimbs')) box(end - 1, y + 4, 5, 2, light);
    if (parts.contains('backward-hand')) box(x - 4, y + 3, 4, 2, light);
    if (parts.contains('knee-mouth')) box(x + 2, bottom - 4, 3, 2, ink);

    final carrying = pose == CreaturePose.carry || pose == CreaturePose.torch;
    final torch = pose == CreaturePose.torch || cargo == '☀' || cargo == '♨';
    final mount = parts.firstWhere(
      (part) =>
          growthById[part]?.group ==
          (torch ? GrowthGroup.torch : GrowthGroup.carrying),
      orElse: () => torch ? 'hooded-lamp' : 'hands',
    );
    var gripX = end - 2;
    var gripY = y - 2;
    switch (mount) {
      case 'hooked-tail' || 'tail-lamp':
        gripX = x - 3;
        gripY = y + 2;
      case 'lip-pocket' || 'chin-light':
        gripX = end - 2;
        gripY = mouthY + 1;
      case 'sling-lantern':
        gripX = end - 1 + wave.round();
        gripY = bottom - 1;
      case 'sticky-pad':
        gripX = x + w ~/ 2;
        gripY = y;
      case 'cradle' || 'candle' || 'fin-torch':
        gripX = x + w ~/ 2;
        gripY = y - 3;
    }
    if (torch && mount == 'fin-torch') {
      box(gripX - 3, gripY + 1, 3, 2, light);
      box(gripX + 2, gripY + 1, 3, 2, light);
    }
    if (parts.contains('sideways') && !torch) {
      gripX = x - 1;
      gripY = y + 2;
    }
    if (carrying ||
        parts.contains(mount) ||
        cheering ||
        parts.contains('salute') ||
        parts.contains('wide-swing')) {
      final swing = parts.contains('wide-swing') ? (wave * 3).round() : 0;
      box(gripX - 1 + swing, gripY + 1, 4, 2, ink);
      box(gripX + swing, gripY, 2, 3, light);
      if (parts.contains('pincers')) box(gripX + 2, gripY - 1, 1, 2, light);
      if (parts.contains('salute')) box(x + 1, y - wave.round(), 2, 3, light);
    }

    if (carrying && cargo != null) {
      if (torch) {
        final flameHeight = mount == 'candle' ? 5 : 3;
        box(gripX, gripY - flameHeight, 2, flameHeight + 3, ink);
        box(
          gripX - 1,
          gripY - flameHeight - 1,
          4,
          flameHeight,
          const Color(0xffffcc60),
        );
        box(
          gripX,
          gripY - flameHeight - 1,
          2,
          flameHeight - 1,
          const Color(0xffffe59a),
        );
        if (mount == 'hooded-lamp')
          box(gripX - 1, gripY - flameHeight - 2, 4, 1, ink);
      } else {
        final construction = parts.firstWhere(
          (part) => growthById[part]?.group == GrowthGroup.building,
          orElse: () => '',
        );
        final isLetter = int.tryParse(cargo!) == null;
        final gesture = isLetter ? construction : '';
        final offset = switch (gesture) {
          'stack' => (0, -(1 + wave.abs()).round()),
          'weave' => ((wave * 2).round(), 0),
          'press' => (-2, 1),
          'wedge' => (1, (wave.abs() * 2).round()),
          _ => (0, 0),
        };
        final cargoX = (gripX - 3 + offset.$1).clamp(0, 27);
        final cargoY = (gripY - 8 + offset.$2).clamp(0, 27);
        canvas.save();
        if (gesture == 'fold') {
          canvas.translate(cargoX + 4.0, cargoY + 4.0);
          canvas.rotate(wave * 0.18);
          canvas.translate(-cargoX - 4.0, -cargoY - 4.0);
        }
        box(cargoX, cargoY, 9, 9, ink);
        box(cargoX + 1, cargoY + 1, 7, 7, const Color(0xffe6dc53));
        final glyph = TextPainter(
          text: TextSpan(
            text: cargo,
            style: TextStyle(
              color: ink,
              fontFamily: 'monospace',
              fontSize: 6,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 7);
        glyph.paint(canvas, Offset(cargoX + (9 - glyph.width) / 2, cargoY + 2));
        glyph.dispose();
        if (gesture == 'polish' && wave > 0) {
          box(cargoX + 6, cargoY + 1, 2, 1, light);
          box(cargoX + 7, cargoY, 1, 3, light);
        }
        canvas.restore();
      }
    }
    if (puzzled) {
      switch (expression) {
        case Personality.curious:
          box(end, y - 4, 3, 1, ink);
          box(end + 2, y - 3, 1, 1, ink);
          box(end + 1, y - 2, 1, 1, ink);
          box(end + 1, y, 1, 1, ink);
        case Personality.collector:
          final lift = (wave.abs() * 2).round();
          box(end - 1, y - 3 - lift, 4, 4, ink);
          box(end, y - 2 - lift, 2, 2, light);
          box(end - 2, y + 1 - lift, 3, 2, shadow);
        case Personality.tinkerer:
          final tap = (phase * 4).floor().isEven ? 1 : 0;
          box(end - 1, y + 5 + tap, 3, 2, shadow);
          box(end + 2, y + 6 + tap, 2, 1, ink);
          if (tap == 1) {
            box(end + 3, y + 4, 1, 3, light);
            box(end + 2, y + 5, 3, 1, light);
          }
      }
    }
    if (pose == CreaturePose.recoil) {
      box(x - 2, y + 2, 2, 1, ink);
      box(x - 4, y, 1, 1, ink);
      box(x - 3, y + 4, 1, 1, ink);
    }
    if (pose == CreaturePose.work || pose == CreaturePose.plant) {
      final tap = (phase * 6).floor().isEven ? 0 : 2;
      box(end - 1 + tap, bottom - 4, 4, 2, ink);
      box(end + tap, bottom - 5, 2, 3, light);
    }
    if (pose == CreaturePose.tussle) {
      final puff = (wave.abs() * 2).round();
      box(x - 3 - puff, y - 2, 2, 2, light);
      box(end + 2 + puff, y, 2, 2, light);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CreaturePainter oldDelegate) =>
      oldDelegate.creature != creature ||
      oldDelegate.pose != pose ||
      oldDelegate.phase != phase ||
      oldDelegate.cargo != cargo;
}

class CreatureCreatorScreen extends StatefulWidget {
  const CreatureCreatorScreen({
    super.key,
    required this.milestone,
    required this.quote,
    required this.onHatch,
    required this.dna,
    required this.rna,
    required this.occupied,
    required this.housing,
    this.oneHelper = false,
    this.reducedMotion = false,
    this.initialRecipe,
    this.initialDraft,
    this.onDraftChanged,
  });

  final GrowthMilestone milestone;
  final HatchPrice Function(int perkCount) quote;
  final Creature? Function(
    String commandId,
    CreatureRecipe recipe,
    HatchPrice quote,
  )
  onHatch;
  final int dna;
  final int rna;
  final int occupied;
  final int housing;
  final bool oneHelper;
  final bool reducedMotion;
  final CreatureRecipe? initialRecipe;
  final CreatureDraft? initialDraft;
  final ValueChanged<CreatureDraft?>? onDraftChanged;

  @override
  State<CreatureCreatorScreen> createState() => _CreatureCreatorScreenState();
}

/// Phase 2 entry point. It intentionally delegates commit/idempotency to the
/// established creator while starting from the guided ecology graph.
class EcologyCreatureCreatorScreen extends StatelessWidget {
  const EcologyCreatureCreatorScreen({
    super.key,
    required this.milestone,
    required this.quote,
    required this.onHatch,
    required this.dna,
    required this.rna,
    required this.occupied,
    required this.housing,
    this.oneHelper = false,
    this.reducedMotion = false,
    this.initialDraft,
    this.initialRecipe,
    this.onDraftChanged,
  });

  final GrowthMilestone milestone;
  final HatchPrice Function(int responseCount) quote;
  final Creature? Function(String, CreatureRecipe, HatchPrice) onHatch;
  final int dna;
  final int rna;
  final int occupied;
  final int housing;
  final bool oneHelper;
  final bool reducedMotion;
  final CreatureDraft? initialDraft;
  final CreatureRecipe? initialRecipe;
  final ValueChanged<CreatureDraft?>? onDraftChanged;

  @override
  Widget build(BuildContext context) => CreatureCreatorScreen(
    milestone: milestone,
    quote: quote,
    onHatch: onHatch,
    dna: dna,
    rna: rna,
    occupied: occupied,
    housing: housing,
    oneHelper: oneHelper,
    reducedMotion: reducedMotion,
    initialDraft: initialDraft,
    initialRecipe: initialDraft == null
        ? initialRecipe ??
              CreatureRecipe.ecology(
                founder: CreatureFounder.plant,
                nicheId: 'plant.brace',
                firstDecision: EcologyChoice.chase,
              )
        : null,
    onDraftChanged: onDraftChanged,
  );
}

class _CreatureCreatorScreenState extends State<CreatureCreatorScreen> {
  late CreatureRecipe _recipe =
      widget.initialDraft?.recipe ??
      widget.initialRecipe ??
      CreatureRecipe.starter();
  late final String _command =
      widget.initialDraft?.commandId ??
      'hatch-${DateTime.now().microsecondsSinceEpoch}';
  CreaturePose _pose = CreaturePose.idle;
  late bool _reviewing = widget.initialDraft?.reviewing ?? false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _saveDraft();
    });
  }

  void _saveDraft() => widget.onDraftChanged?.call(
    CreatureDraft(commandId: _command, recipe: _recipe, reviewing: _reviewing),
  );

  void _review(bool reviewing) {
    setState(() => _reviewing = reviewing);
    _saveDraft();
  }

  void _change(CreatureRecipe next, {CreaturePose? pose}) {
    setState(() {
      _recipe = next;
      if (pose != null) _pose = pose;
      _message = null;
    });
    _saveDraft();
  }

  void _hatch(HatchPrice quoted) {
    final current = widget.quote(_responseCount);
    if (current != quoted) {
      setState(
        () => _message =
            'The price changed. Check the new quote before hatching.',
      );
      return;
    }
    final creature = widget.onHatch(_command, _recipe, quoted);
    if (creature == null) {
      setState(
        () => _message =
            'The hatch could not be completed. Check the price, growth choices, and shelter.',
      );
      return;
    }
    widget.onDraftChanged?.call(null);
    Navigator.of(context).pop(creature);
  }

  @override
  Widget build(BuildContext context) {
    final preview = Creature.preview(_recipe, widget.milestone);
    final errors = _recipe.validate(widget.milestone);
    final quote = widget.quote(_responseCount);
    final perkLimit = CreatureRecipe.perkLimit(widget.milestone);
    final availability = [
      if (widget.oneHelper) 'One Helper closes the hatchery.',
      if (widget.occupied >= widget.housing) 'Build a shelter to make room.',
      if (widget.dna < quote.dna || widget.rna < quote.rna)
        'More DNA or RNA is needed.',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_reviewing ? 'Review hatch' : 'Design creature'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Creature preview', textAlign: TextAlign.center),
                  Center(
                    child: CreatureSprite(
                      creature: preview,
                      pose: _pose,
                      cargo: _pose == CreaturePose.carry ? _previewCargo : null,
                      size: 108,
                      reducedMotion: widget.reducedMotion,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final option in const {
                        CreaturePose.idle: 'Wait',
                        CreaturePose.travel: 'Travel',
                        CreaturePose.carry: 'Carry',
                      }.entries)
                        ChoiceChip(
                          label: Text(option.value),
                          selected: _pose == option.key,
                          onSelected: (_) => setState(() => _pose = option.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_reviewing) ...[
            Text(
              _recipe.ecologyPath == null ? 'Growth paths' : 'Life path',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_recipe.ecologyPath case final EcologyPath path) ...[
              Text('Founder · ${path.founder.label}'),
              if (path.niche case final EcologyNiche niche)
                Text('Habitat · ${niche.label}'),
              for (final family in DecisionFamily.values)
                if (path.decisions[family] case final EcologyChoice choice)
                  Text('${family.question} · ${choice.label}'),
              if (path.secretId case final String secretId)
                Text(
                  'Discovery · ${ecologySecretById(secretId)?.label ?? secretId}',
                ),
            ] else
              for (final group in GrowthGroup.values)
                if (growthById[_recipe.choices[group]]
                    case final GrowthNode node)
                  Text('${group.label} · ${node.label}'),
            const SizedBox(height: 8),
            Text(
              _recipe.ecologyPath == null
                  ? 'Work perks'
                  : 'Demonstrated skills',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_recipe.ecologyPath case final EcologyPath path)
              for (final choice in path.decisions.values) Text(choice.effect)
            else
              for (final perk in _recipe.perks) Text(perk.label),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _review(false),
              child: const Text('Edit growth paths'),
            ),
          ] else ...[
            if (_recipe.ecologyPath case final EcologyPath path)
              ..._ecologyEditor(path)
            else ...[
              for (final group in GrowthGroup.values) _path(group),
              const SizedBox(height: 12),
              Text(
                'Work perks (${_recipe.perks.length}/$perkLimit)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final perk in WorkPerk.values)
                if (perk.milestone.index <= widget.milestone.index ||
                    _recipe.perks.contains(perk))
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(perk.label),
                    subtitle: Text(
                      perk.milestone.index > widget.milestone.index
                          ? 'Unlocks at ${_milestoneLabel(perk.milestone)}'
                          : perk.description,
                    ),
                    value: _recipe.perks.contains(perk),
                    onChanged:
                        _recipe.perks.contains(perk) ||
                            perk.milestone.index <= widget.milestone.index
                        ? (add) {
                            final current = [..._recipe.perks];
                            if (add == false) {
                              current.remove(perk);
                            } else if (perkLimit == 1) {
                              current
                                ..clear()
                                ..add(perk);
                            } else if (current.length < perkLimit) {
                              current.add(perk);
                            } else {
                              setState(
                                () => _message =
                                    'Remove a work perk to make room.',
                              );
                              return;
                            }
                            _change(_recipe.withPerks(current));
                          }
                        : null,
                  ),
            ],
          ],
          const Divider(height: 24),
          Text(
            '${quote.dna} DNA · ${quote.rna} RNA',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${widget.dna} DNA and ${widget.rna} RNA available'),
          Text('Housing · ${widget.occupied}/${widget.housing} occupied'),
          if (errors.isNotEmpty || availability.isNotEmpty || _message != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  [
                    ...errors,
                    ...availability,
                    if (_message case final String message) message,
                  ].join('\n'),
                ),
              ),
            ),
          if (_reviewing)
            FilledButton(
              onPressed: errors.isEmpty && availability.isEmpty
                  ? () => _hatch(quote)
                  : null,
              child: const Text('Hatch'),
            )
          else
            FilledButton(
              onPressed: errors.isEmpty ? () => _review(true) : null,
              child: const Text('Review hatch'),
            ),
        ],
      ),
    );
  }

  int get _responseCount =>
      _recipe.ecologyPath?.responseCount ?? _recipe.perks.length;

  List<Widget> _ecologyEditor(EcologyPath path) {
    final cap = ecologyDecisionCap(widget.milestone);
    return [
      Text('Choose a lineage', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final founder in CreatureFounder.values)
            ChoiceChip(
              label: Text(founder.label),
              selected: path.founder == founder,
              onSelected: (_) {
                final niche = ecologyNiches.firstWhere(
                  (item) => item.founder == founder,
                );
                _change(
                  CreatureRecipe.ecology(
                    founder: founder,
                    nicheId: niche.id,
                    firstDecision: EcologyChoice.chase,
                  ),
                  pose: CreaturePose.walk,
                );
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        path.niche?.question ?? 'Choose a habitat',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      RadioGroup<String>(
        groupValue: path.nicheId,
        onChanged: (id) {
          if (id == null) return;
          _change(
            _recipe.withEcologyPath(
              EcologyPath(
                founder: path.founder,
                nicheId: id,
                decisions: path.decisions,
                witnessedEvents: path.witnessedEvents,
              ),
            ),
            pose: CreaturePose.walk,
          );
        },
        child: Column(
          children: [
            for (final niche in ecologyNiches.where(
              (item) => item.founder == path.founder,
            ))
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: niche.id,
                title: Text(niche.label),
                subtitle: Text(niche.effect),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Life decisions (${path.responseCount}/$cap)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final family in DecisionFamily.values)
        if (path.availableChoices(widget.milestone, family).isNotEmpty &&
            (path.decisions.containsKey(family) || path.responseCount < cap))
          ExpansionTile(
            key: PageStorageKey('ecology-${family.name}'),
            initiallyExpanded: family == DecisionFamily.digit,
            tilePadding: EdgeInsets.zero,
            title: Text(family.question),
            subtitle: path.decisions[family] == null
                ? const Text('Leave open for nurture')
                : Text(path.decisions[family]!.label),
            children: [
              RadioGroup<EcologyChoice>(
                groupValue: path.decisions[family],
                onChanged: (choice) {
                  if (choice == null) return;
                  _change(
                    _recipe.withEcologyPath(path.choose(choice)),
                    pose: switch (family) {
                      DecisionFamily.digit => CreaturePose.run,
                      DecisionFamily.roof => CreaturePose.work,
                      DecisionFamily.light => CreaturePose.torch,
                      DecisionFamily.coordination => CreaturePose.poke,
                    },
                  );
                },
                child: Column(
                  children: [
                    for (final choice in path.availableChoices(
                      widget.milestone,
                      family,
                    ))
                      RadioListTile<EcologyChoice>(
                        contentPadding: const EdgeInsetsDirectional.only(
                          start: 4,
                        ),
                        value: choice,
                        title: Text(choice.label),
                        subtitle: Text(choice.effect),
                      ),
                  ],
                ),
              ),
            ],
          ),
    ];
  }

  String get _previewCargo => _recipe.choices.containsKey(GrowthGroup.torch)
      ? '☀'
      : _recipe.choices.containsKey(GrowthGroup.building)
      ? 'A'
      : '4';

  Widget _path(GrowthGroup group) {
    final options = growthNodes.where((node) => node.group == group).toList();
    final selected = growthById[_recipe.choices[group]];
    final unlocked = options.any(
      (node) => node.milestone.index <= widget.milestone.index,
    );
    if (!unlocked && selected == null) return const SizedBox.shrink();
    return ExpansionTile(
      key: PageStorageKey(group),
      initiallyExpanded: group == GrowthGroup.locomotion,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(group.label),
      subtitle: selected == null ? null : Text(selected.label),
      children: [
        for (final node in options)
          if (node.milestone.index <= widget.milestone.index ||
              selected == node) ...[
            _growthOption(node, selected == node),
            if (selected == node)
              for (final branch in growthNodes)
                if (branch.requires.contains(node.id) &&
                    branch.isAvailable(
                      widget.milestone,
                      _recipe.choices.values,
                    ))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _change(_recipe.withChoice(branch)),
                      icon: const Icon(Icons.call_split),
                      label: Text(branch.label),
                    ),
                  ),
          ],
        if (selected != null && group.index >= 3)
          TextButton(
            onPressed: () => _change(_recipe.withoutChoice(group)),
            child: Text('Remove ${group.label.toLowerCase()} choice'),
          ),
      ],
    );
  }

  Widget _growthOption(GrowthNode node, bool selected) {
    final enabled = node.isAvailable(widget.milestone, _recipe.choices.values);
    final prerequisites = node.requires
        .map((id) => growthById[id]!.label.toLowerCase())
        .join(' and ');
    final subtitle = enabled
        ? node.effect
        : node.milestone.index > widget.milestone.index
        ? 'Unlocks at ${_milestoneLabel(node.milestone)}'
        : 'Requires $prerequisites';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(node.label),
      subtitle: Text(subtitle),
      selected: selected,
      enabled: enabled,
      onTap: enabled
          ? () => _change(
              _recipe.withChoice(node),
              pose: switch (node.group) {
                GrowthGroup.locomotion => CreaturePose.travel,
                GrowthGroup.building ||
                GrowthGroup.carrying ||
                GrowthGroup.torch => CreaturePose.carry,
                _ => CreaturePose.idle,
              },
            )
          : null,
    );
  }
}

String _milestoneLabel(GrowthMilestone value) => switch (value) {
  GrowthMilestone.opening => 'the opening',
  GrowthMilestone.five => '5×5',
  GrowthMilestone.six => '6×6',
  GrowthMilestone.seven => '7×7',
  GrowthMilestone.eight => '8×8',
  GrowthMilestone.halo => 'Halo fog',
  GrowthMilestone.arrows => 'Arrows',
};

class CreatureRoaming {
  const CreatureRoaming();

  static const MethodChannel channel = MethodChannel(
    'org.sodukromental/companion',
  );

  Future<bool> canDrawOverlays() async =>
      await channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  Future<bool> requestOverlayPermission() async =>
      await channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
  Future<bool> isRoaming() async =>
      await channel.invokeMethod<bool>('isRoaming') ?? false;
  Future<void> stop() => channel.invokeMethod<void>('stopRoaming');

  Future<bool> start(Creature creature, {required bool reducedMotion}) async {
    final memory = creature.memory;
    if (!memory.canAskOutside ||
        !memory.outsideOptIn ||
        !await canDrawOverlays())
      return false;
    final sprite = await CreatureSprite.renderPng(creature);
    return await channel.invokeMethod<bool>('startRoaming', {
          'id': creature.id,
          'name': creature.name,
          'appearance': creature.appearance.toJson(),
          'sprite': sprite,
          'phrases': memory.approvedOutsidePhrases,
          'greetings': memory.muted
              ? <String>[]
              : ['Hello!', 'A good day for a walk.'],
          'reducedMotion': reducedMotion,
        }) ??
        false;
  }
}

class CreatureProfileScreen extends StatefulWidget {
  const CreatureProfileScreen({
    super.key,
    required this.creature,
    required this.selectedToKeep,
    required this.onKeep,
    required this.onChanged,
    this.onEncourage,
    this.onEditRecipe,
    this.nurtureChoices = const [],
    this.discoveryChoices = const [],
    this.ecologyMilestone,
    this.onNurture,
    this.onDiscover,
    this.suggestedDigit,
    this.reducedMotion = false,
    this.roaming = const CreatureRoaming(),
  });

  final Creature creature;
  final bool selectedToKeep;
  final void Function(bool) onKeep;
  final VoidCallback onChanged;
  final bool Function()? onEncourage;
  final VoidCallback? onEditRecipe;
  final List<EcologyChoice> nurtureChoices;
  final List<EcologySecret> discoveryChoices;
  final GrowthMilestone? ecologyMilestone;
  final bool Function(EcologyChoice)? onNurture;
  final bool Function(String)? onDiscover;
  final int? suggestedDigit;
  final bool reducedMotion;
  final CreatureRoaming roaming;

  @override
  State<CreatureProfileScreen> createState() => _CreatureProfileScreenState();
}

class _CreatureProfileScreenState extends State<CreatureProfileScreen>
    with WidgetsBindingObserver {
  late bool _keep = widget.selectedToKeep;
  final _phrase = TextEditingController();
  bool _waitingOnGrant = false;
  bool _outsideActive = false;
  bool _busy = false;
  String? _notice;
  String? _spoken;

  Creature get _creature => widget.creature;
  CompanionMemory get _memory => _creature.memory;
  bool get _android => Theme.of(context).platform == TargetPlatform.android;
  List<EcologyChoice> get _nurtureChoices => widget.ecologyMilestone == null
      ? widget.nurtureChoices
      : [
          for (final choice in EcologyChoice.values)
            if (_creature.canNurture(choice, widget.ecologyMilestone!)) choice,
        ];
  List<EcologySecret> get _discoveryChoices {
    final path = _creature.recipe.ecologyPath;
    if (widget.ecologyMilestone == null) return widget.discoveryChoices;
    if (path == null || path.secretId != null) return const [];
    return [
      for (final secret in ecologySecrets)
        if (secret.matches(path)) secret,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _android && _memory.canAskOutside) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phrase.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_android) return;
    if (_waitingOnGrant) {
      _waitingOnGrant = false;
      unawaited(_start());
    } else if (_memory.canAskOutside) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final active = await widget.roaming.isRoaming();
      if (mounted) setState(() => _outsideActive = active);
    } on MissingPluginException {
      if (mounted) setState(() => _outsideActive = false);
    } on PlatformException {
      if (mounted) setState(() => _outsideActive = false);
    }
  }

  void _save() {
    setState(() {});
    widget.onChanged();
  }

  void _updateSpeech() {
    // The native outing receives a fixed consent snapshot. Stop it whenever that
    // snapshot could contain a phrase the player just muted, changed or removed.
    _spoken = null;
    _save();
    if (_outsideActive || _memory.outsideOptIn) unawaited(_stop());
  }

  void _teach(String text) {
    if (_memory.teach(text) == null) return;
    _phrase.clear();
    _spoken = _memory.nextEcho(DateTime.now().millisecondsSinceEpoch);
    _save();
  }

  Future<void> _rename() async {
    final currentName = _creature.name;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CreatureNameDialog(currentName),
    );
    if (!mounted || name == null || name == currentName) return;
    _creature.name = name;
    _save();
  }

  Future<void> _allow() async {
    if (_busy) return;
    _memory.outsideOptIn = true;
    _save();
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      if (await widget.roaming.canDrawOverlays()) {
        if (mounted) await _start();
      } else {
        _waitingOnGrant = true;
        if (!await widget.roaming.requestOverlayPermission()) {
          _waitingOnGrant = false;
          _clearRoamingConsent('Android did not open the overlay setting.');
        }
      }
    } on MissingPluginException {
      _clearRoamingConsent('Outside visits are unavailable on this device.');
    } on PlatformException {
      _clearRoamingConsent('Android could not open the overlay setting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearRoamingConsent(String notice) {
    if (!mounted) return;
    _memory.outsideOptIn = false;
    setState(() => _notice = notice);
    widget.onChanged();
  }

  Future<void> _start() async {
    try {
      final started = await widget.roaming.start(
        _creature,
        reducedMotion: widget.reducedMotion,
      );
      if (!mounted) return;
      setState(() => _outsideActive = started);
      if (!started)
        _clearRoamingConsent('Your companion will stay in the game.');
    } on MissingPluginException {
      _clearRoamingConsent('Outside visits are unavailable on this device.');
    } on PlatformException {
      _clearRoamingConsent('Android could not start this outing.');
    }
  }

  Future<void> _stop() async {
    _memory.outsideOptIn = false;
    _waitingOnGrant = false;
    _save();
    try {
      await widget.roaming.stop();
      if (mounted) setState(() => _outsideActive = false);
    } on MissingPluginException {
      if (mounted) setState(() => _outsideActive = false);
    } on PlatformException {
      if (mounted)
        setState(
          () => _notice =
              'Android could not end the outing. Use Stop roaming in the notification.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_creature.name)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            CreatureSprite(
              creature: _creature,
              size: 108,
              reducedMotion: widget.reducedMotion,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Favorite digit · ${_creature.favorite}'),
                Text('Personality · ${_creature.personality.name}'),
                Text('${_memory.sharedClears} shared clears'),
                if (_memory.preferredTask case final TaskKind task)
                  Text('Prefers ${task.name} jobs'),
                if (widget.suggestedDigit case final int digit)
                  Text('Suggests fetching another $digit'),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: _rename, child: const Text('Name creature')),
            if (widget.onEditRecipe != null)
              TextButton(
                onPressed: widget.onEditRecipe,
                child: const Text('Open saved recipe'),
              ),
            if (widget.onEncourage case final bool Function() encourage)
              OutlinedButton(
                onPressed: () {
                  final learned = encourage();
                  setState(
                    () => _notice = learned
                        ? '${_creature.name} remembers this kind of work.'
                        : 'Good job is available once after contributing to a puzzle.',
                  );
                  if (learned) widget.onChanged();
                },
                child: const Text('Good job'),
              ),
          ],
        ),
        if (_creature.recipe.ecologyPath case final EcologyPath path) ...[
          const Divider(height: 24),
          Text('Life path', style: Theme.of(context).textTheme.titleMedium),
          Text('${path.founder.label} · ${path.niche?.label ?? path.nicheId}'),
          for (final family in DecisionFamily.values)
            if (path.decisions[family] case final EcologyChoice choice)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(choice.label),
                subtitle: Text(choice.effect),
              ),
          if (path.secretId case final String secretId)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(ecologySecretById(secretId)?.label ?? secretId),
              subtitle: const Text('Discovered identity'),
            ),
          if (_nurtureChoices.isNotEmpty && widget.onNurture != null) ...[
            Text(
              'Nurture · 1 DNA / 2 RNA',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final choice in _nurtureChoices)
              OutlinedButton(
                onPressed: () {
                  final nurtured = widget.onNurture!(choice);
                  setState(
                    () => _notice = nurtured
                        ? '${_creature.name} expressed ${choice.label}.'
                        : 'This response is unavailable or the colony needs 1 DNA and 2 RNA.',
                  );
                  if (nurtured) widget.onChanged();
                },
                child: Text('${choice.label} · ${choice.effect}'),
              ),
          ],
          for (final secret in ecologySecrets)
            if (path.witnessedEvents.contains(secret.eventId))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_outlined),
                title: Text(secret.clue),
                subtitle: const Text('Witnessed in this colony'),
              ),
          if (_discoveryChoices.isNotEmpty && widget.onDiscover != null)
            for (final secret in _discoveryChoices)
              FilledButton.tonalIcon(
                onPressed: () {
                  final discovered = widget.onDiscover!(secret.id);
                  setState(
                    () => _notice = discovered
                        ? '${_creature.name} discovered ${secret.label}.'
                        : 'The witnessed clue and life decisions do not match yet.',
                  );
                  if (discovered) widget.onChanged();
                },
                icon: const Icon(Icons.auto_awesome),
                label: Text('Discover ${secret.label}'),
              ),
        ],
        SwitchListTile(
          title: const Text('Keep as companion'),
          subtitle: const Text('Bring this creature into your next colony.'),
          contentPadding: EdgeInsets.zero,
          value: _keep,
          onChanged: (keep) {
            setState(() => _keep = keep);
            widget.onKeep(keep);
          },
        ),
        const Divider(height: 24),
        Text(
          'Talk to creature',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phrase,
          textInputAction: TextInputAction.send,
          onSubmitted: _teach,
          decoration: InputDecoration(
            labelText: 'Teach a phrase',
            suffixIcon: IconButton(
              tooltip: 'Teach phrase',
              onPressed: () => _teach(_phrase.text),
              icon: const Icon(Icons.send),
            ),
          ),
        ),
        if (_spoken case final String spoken)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${_creature.name}: $spoken'),
            ),
          ),
        SwitchListTile(
          title: const Text('Mute speech'),
          contentPadding: EdgeInsets.zero,
          value: _memory.muted,
          onChanged: (value) {
            _memory.muted = value;
            _updateSpeech();
          },
        ),
        for (final phrase in _memory.phrases)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(phrase.text),
                  trailing: IconButton(
                    tooltip: 'Delete phrase',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      _memory.deletePhrase(phrase.id);
                      _updateSpeech();
                    },
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Allow this phrase outside the app'),
                  value: phrase.allowOutside,
                  onChanged: (value) {
                    phrase.allowOutside = value == true;
                    _updateSpeech();
                  },
                ),
              ],
            ),
          ),
        if (_memory.canAskOutside && _android) ...[
          const Divider(height: 24),
          Text(
            'Can I explore outside the game?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _stop,
                child: Text(_outsideActive ? 'Stop roaming' : 'Stay here'),
              ),
              if (!_outsideActive)
                FilledButton(
                  onPressed: _busy ? null : _allow,
                  child: const Text('Let it roam'),
                ),
            ],
          ),
        ],
        if (_notice case final String notice)
          Semantics(liveRegion: true, child: Text(notice)),
      ],
    ),
  );
}

class _CreatureNameDialog extends StatefulWidget {
  const _CreatureNameDialog(this.name);
  final String name;

  @override
  State<_CreatureNameDialog> createState() => _CreatureNameDialogState();
}

class _CreatureNameDialogState extends State<_CreatureNameDialog> {
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final value = _name.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Name creature'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 40,
      onSubmitted: (_) => _done(),
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _done, child: const Text('Save name')),
    ],
  );
}

class CompanionVisit extends StatefulWidget {
  const CompanionVisit({
    super.key,
    required this.creature,
    required this.waypoint,
    required this.onCallBack,
    required this.onChanged,
    this.priorityWork = false,
    this.reducedMotion = false,
    this.invited = false,
  });

  final Creature creature;
  final CompanionWaypoint waypoint;
  final VoidCallback onCallBack;
  final VoidCallback onChanged;
  final bool priorityWork;
  final bool reducedMotion;
  final bool invited;

  @override
  State<CompanionVisit> createState() => _CompanionVisitState();
}

class _CompanionVisitState extends State<CompanionVisit> {
  late final Timer _visitClock;
  String? _bubble;
  int _echoExpiresAt = 0;
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    _visitClock = Timer.periodic(const Duration(seconds: 2), (_) => _update());
  }

  @override
  void didUpdateWidget(CompanionVisit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priorityWork != widget.priorityWork ||
        oldWidget.invited != widget.invited ||
        oldWidget.waypoint != widget.waypoint ||
        oldWidget.creature.id != widget.creature.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    }
  }

  void _update() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final memory = widget.creature.memory;
    final present =
        !widget.priorityWork &&
        (widget.invited && memory.retained ||
            memory.waypoint(now, priorityWork: widget.priorityWork) ==
                widget.waypoint);
    String? bubble = _bubble;
    if (!present || now >= _echoExpiresAt || memory.muted) bubble = null;
    final echo = present ? memory.nextEcho(now) : null;
    if (echo != null) {
      bubble = echo;
      _echoExpiresAt = now + 10000;
    }
    if (_arrived != present || _bubble != bubble) {
      setState(() {
        _arrived = present;
        _bubble = bubble;
      });
    }
    if (echo != null) widget.onChanged();
  }

  @override
  void dispose() {
    _visitClock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_arrived || widget.priorityWork) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CreatureSprite(
              creature: widget.creature,
              size: 48,
              reducedMotion: widget.reducedMotion,
            ),
            Text(widget.creature.name),
            if (_bubble != null && !widget.creature.memory.muted)
              Text(_bubble!),
            TextButton(
              onPressed: widget.onCallBack,
              child: const Text('Call back'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettlementProjectPreview extends StatelessWidget {
  const SettlementProjectPreview({
    super.key,
    required this.glyphs,
    required this.complete,
  });
  final List<MaterialGlyph> glyphs;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pieces = {
      for (final role in MaterialRole.values)
        role: glyphs
            .where((piece) => piece.role == role)
            .map((piece) => piece.glyph)
            .join(' '),
    };
    return Semantics(
      label:
          '${complete ? 'Finished' : 'In progress'} construction with ${pieces.entries.where((entry) => entry.value.isNotEmpty).map((entry) => '${entry.key.name} ${entry.value}').join(', ')}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pieces[MaterialRole.roof]!,
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  '${pieces[MaterialRole.support]} ${pieces[MaterialRole.ring]}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  pieces[MaterialRole.beam]!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettlementMaterialNotice extends StatelessWidget {
  const SettlementMaterialNotice({
    super.key,
    required this.available,
    required this.remaining,
    required this.onSelect,
    this.sentence = starterMaterialSentence,
  });

  final Iterable<MaterialGlyph> available;
  final Map<MaterialRole, int> remaining;
  final ValueChanged<MaterialGlyph> onSelect;
  final String sentence;

  @override
  Widget build(BuildContext context) {
    final ids = {for (final piece in available) piece.id: piece};
    final starterIndices = {
      for (final piece in starterGlyphs)
        if (sentence == starterMaterialSentence && piece.index != null)
          piece.index!: piece,
    };
    final style = Theme.of(context).textTheme.bodyLarge;
    final notice = available.where(
      (piece) => piece.index == null && (remaining[piece.role] ?? 0) > 0,
    );
    final words = <List<Widget>>[[]];
    var index = 0;
    for (final glyph in sentence.characters) {
      final piece = starterIndices[index++];
      if (glyph == ' ') {
        words.add([]);
      } else if (piece == null) {
        words.last.add(Center(child: Text(glyph, style: style)));
      } else if (ids.containsKey(piece.id)) {
        words.last.add(_pieceButton(piece));
      } else {
        words.last.add(
          Tooltip(
            message: '${piece.glyph} · ${piece.role.name} collected',
            child: Center(
              child: SizedBox.square(
                dimension: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      glyph,
                      style: style?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: sentence,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final word in words)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: word,
                ),
            ],
          ),
        ),
        if (notice.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Settlement notice'),
          Wrap(
            spacing: 8,
            children: [
              for (final piece in notice) _pieceButton(piece, withRole: true),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pieceButton(MaterialGlyph piece, {bool withRole = false}) {
    final remainingCount = remaining[piece.role] ?? 0;
    return Tooltip(
      message: remainingCount > 0
          ? 'Collect ${piece.glyph} as ${piece.role.name}'
          : '${piece.role.name} is ready for this project',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.square(48),
          padding: const EdgeInsets.symmetric(horizontal: 5),
        ),
        onPressed: remainingCount > 0 ? () => onSelect(piece) : null,
        child: Text(
          withRole ? '${piece.glyph} · ${piece.role.name}' : piece.glyph,
        ),
      ),
    );
  }
}
