import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'campaign.dart';
import 'creatures.dart';
import 'hum.dart';

/// Shape the bundled font at its displayed size. Only enclosed transparent
/// components count as vessels; an open 4 drains even when a different 4 holds.
class GlyphHollows {
  const GlyphHollows(this.size, this.pools);
  final Size size;
  final List<List<Rect>> pools;
  static final _cache =
      LinkedHashMap<(String, TextStyle), Future<GlyphHollows>>();
  static Future<GlyphHollows> measure(String text, TextStyle style) {
    final ink = style.copyWith(color: Colors.white);
    final key = (text, ink);
    if (_cache.length >= 200 && !_cache.containsKey(key))
      _cache.remove(_cache.keys.first);
    return _cache.putIfAbsent(key, () => _shape(text, ink));
  }

  static Future<GlyphHollows> _shape(String text, TextStyle style) async {
    final letter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = letter.size;
    final w = math.max(1, size.width.ceil() + 2),
        h = math.max(1, size.height.ceil() + 2);
    final recorder = ui.PictureRecorder();
    letter.paint(Canvas(recorder), const Offset(1, 1));
    letter.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) return GlyphHollows(size, []);
    final solid = Uint8List(w * h);
    for (var i = 0; i < solid.length; i++) {
      if (bytes.getUint8(i * 4 + 3) > 64) solid[i] = 1;
    }
    final pools = <List<Rect>>[];
    for (var i = 0; i < solid.length; i++) {
      if (solid[i] != 0) continue;
      final region = <int>[i];
      solid[i] = 1;
      var exterior = false, minY = h, maxY = 0;
      void visit(int ix) {
        if (solid[ix] == 0) {
          solid[ix] = 1;
          region.add(ix);
        }
      }

      for (var head = 0; head < region.length; head++) {
        final p = region[head], x = p % w, y = p ~/ w;
        exterior = exterior || x == 0 || x == w - 1 || y == 0 || y == h - 1;
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        if (x > 0) visit(p - 1);
        if (x < w - 1) visit(p + 1);
        if (y > 0) visit(p - w);
        if (y < h - 1) visit(p + w);
      }
      if (exterior || region.length < 4 || maxY - minY < 2) continue;
      final surface = (minY + maxY) ~/ 2;
      pools.add([
        for (final p in region)
          if (p ~/ w >= surface)
            Rect.fromLTWH(
              (p % w - 1).toDouble(),
              (p ~/ w - 1).toDouble(),
              1,
              1,
            ),
      ]);
    }
    return GlyphHollows(size, pools);
  }
}

class RainGlyph extends StatefulWidget {
  const RainGlyph({
    super.key,
    required this.run,
    required this.sourceId,
    required this.text,
    required this.style,
    this.dry = false,
  });
  final Campaign run;
  final String sourceId, text;
  final TextStyle style;
  final bool dry;
  @override
  State<RainGlyph> createState() => _RainGlyphState();
}

class _RainGlyphState extends State<RainGlyph> {
  GlyphHollows? _shape;
  int _version = 0;
  (String, TextStyle, String, bool)? _key;
  void _measure(TextStyle style) {
    final key = (widget.text, style, widget.sourceId, widget.dry);
    if (_key == key) return;
    _key = key;
    final version = ++_version;
    _shape = null;
    if (widget.dry) return;
    GlyphHollows.measure(widget.text, style).then((shape) {
      if (!mounted || _version != version) return;
      widget.run.weather.observe(widget.sourceId, shape.pools.length);
      setState(() => _shape = shape);
    });
  }

  @override
  void didUpdateWidget(RainGlyph old) {
    super.didUpdateWidget(old);
    if (old.sourceId != widget.sourceId ||
        old.run != widget.run ||
        old.dry != widget.dry) {
      old.run.weather.leave(old.sourceId);
      _key = null;
    }
  }

  @override
  void dispose() {
    widget.run.weather.leave(widget.sourceId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style.copyWith(
      fontSize: MediaQuery.textScalerOf(
        context,
      ).scale(widget.style.fontSize ?? 16),
    );
    _measure(style);
    final shape = _shape, water = widget.run.weather.pool(widget.sourceId);
    return Stack(
      children: [
        Text(widget.text, style: style, textScaler: TextScaler.noScaling),
        if (!widget.dry && shape != null && water > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _Pool(shape, water)),
            ),
          ),
      ],
    );
  }
}

class _Pool extends CustomPainter {
  const _Pool(this.shape, this.amount);
  final GlyphHollows shape;
  final int amount;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff53a9c4)
      ..isAntiAlias = false;
    for (final pool in shape.pools.take(amount)) {
      for (final rect in pool) {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Pool other) =>
      other.shape != shape || other.amount != amount;
}

class RainInscription extends StatelessWidget {
  const RainInscription({super.key, required this.campaign});
  final Campaign campaign;
  @override
  Widget build(BuildContext context) {
    final byIndex = {for (final piece in starterGlyphs) piece.index: piece};
    final source = starterMaterialSentence.characters.toList();
    final weather = campaign.weather;
    final open = campaign.population.communalCapacity > 0;
    final carrier = campaign.creatures
        .where((c) => c.id == weather.carrierId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: starterMaterialSentence,
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < source.length; i++)
                    RainGlyph(
                      run: campaign,
                      sourceId: byIndex[i]?.id ?? 'inscription-$i',
                      text: source[i],
                      dry:
                          !open ||
                          campaign.claimedGlyphs.contains(byIndex[i]?.id),
                      style: TextStyle(
                        fontFamily: Hum.headingFont,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: campaign.claimedGlyphs.contains(byIndex[i]?.id)
                            ? Hum.grid
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Text(
            carrier != null
                ? '${carrier.name} is carrying a bucket. Cistern ${weather.stored}/${ColonyWeather.capacity}.'
                : 'Cistern ${weather.stored}/${ColonyWeather.capacity} · Planter watered ${weather.watered} times',
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}
