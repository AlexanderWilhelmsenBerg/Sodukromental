import 'package:flutter/material.dart';
import 'hum.dart';

/// The same 32-pixel amoeba and four as the Android launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Center(
      child: SizedBox.square(
        dimension: 36,
        child: CustomPaint(painter: _MarkPainter()),
      ),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()..isAntiAlias = false;
    void pixels(int l, int t, int r, int b, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0),
        paint,
      );
    }

    paint.color = Hum.ink;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, 30, 30),
        const Radius.circular(7),
      ),
      paint,
    );
    pixels(5, 24, 26, 25, Hum.mutedInk);
    pixels(8, 16, 22, 23, Hum.pear);
    pixels(11, 14, 19, 15, Hum.pear);
    pixels(6, 20, 24, 23, Hum.pear);
    pixels(6, 23, 9, 24, Hum.pear);
    pixels(14, 23, 17, 24, Hum.pear);
    pixels(22, 21, 25, 23, Hum.pear);
    pixels(10, 17, 11, 18, Hum.board);
    pixels(15, 17, 16, 19, Hum.ink);
    pixels(21, 17, 22, 19, Hum.ink);
    pixels(19, 20, 20, 20, Hum.pearEdge);
    const digit = ['10010', '10010', '10010', '11111', '00010', '00010'];
    for (var y = 0; y < digit.length; y++) {
      for (var x = 0; x < digit[y].length; x++) {
        if (digit[y][x] == '1')
          pixels(12 + x * 2, 3 + y * 2, 13 + x * 2, 4 + y * 2, Hum.cyan);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
