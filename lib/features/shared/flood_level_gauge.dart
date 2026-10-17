// La jauge d'un niveau de vigilance crues (T4, M1) : carré à coins arrondis à
// la teinte du niveau, contour noir, 0 à 3 barres. Le nom du niveau n'est
// jamais posé sur la teinte : le libellé voisin l'annonce, la jauge n'a pas de
// sémantique propre (précédent : `drought_severity_badge.dart`).

import 'package:flutter/widgets.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';

const Color _white = Color(0xFFFFFFFF);

/// Jauge d'un niveau, [size] de côté (20 par défaut).
class FloodLevelGauge extends StatelessWidget {
  const FloodLevelGauge({required this.level, this.size = 20, super.key});

  final FloodVigilanceLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final FloodLevelStyle style = floodLevelStyle(level);
    final Color barColor = switch (level) {
      Rouge() => floodRedBarsColor,
      Vert() ||
      Jaune() ||
      Orange() ||
      NiveauCruesInconnu() => floodContourColor,
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _FloodLevelGaugePainter(
            tint: style.tint,
            dotted: style.dotted,
            barCount: style.bars,
            barColor: barColor,
          ),
        ),
      ),
    );
  }
}

/// Peintre de la jauge.
class _FloodLevelGaugePainter extends CustomPainter {
  const _FloodLevelGaugePainter({
    required this.tint,
    required this.dotted,
    required this.barCount,
    required this.barColor,
  });

  final Color tint;
  final bool dotted;
  final int barCount;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double half = floodContourWidth / 2;
    final double radius = 3 * size.width / 20;
    final RRect box = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(half),
      Radius.circular(radius),
    );
    canvas.drawRRect(box, Paint()..color = dotted ? _white : tint);

    final Rect inner = box.deflate(floodContourWidth).outerRect;
    final double barHeight = inner.height / 7;
    for (int i = 0; i < barCount; i++) {
      // Barres équidistantes, du bas vers le haut du carré.
      final double top = inner.bottom - barHeight * (2 * i + 1.5);
      canvas.drawRect(
        Rect.fromLTWH(inner.left, top, inner.width, barHeight),
        Paint()..color = barColor,
      );
    }

    if (dotted) {
      _dashedOutline(canvas, box, tint);
    } else {
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floodContourWidth
          ..color = floodContourColor,
      );
    }
  }

  // Contour pointillé gris : traits courts le long du périmètre.
  static void _dashedOutline(Canvas canvas, RRect box, Color color) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = floodContourWidth
      ..color = color;
    final Path path = Path()..addRRect(box);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 4) {
        canvas.drawPath(metric.extractPath(d, d + 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FloodLevelGaugePainter old) =>
      old.tint != tint ||
      old.dotted != dotted ||
      old.barCount != barCount ||
      old.barColor != barColor;
}
