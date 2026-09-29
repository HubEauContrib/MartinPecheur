// Le badge de gravite secheresse (echelle 3), E2 de T2 — arbitrage Q-7 de
// C1 (conception T2, § 7), `docs/04-ui.md` § 2 et § 3.
//
// Teintes, formes, glyphes et motifs RECOPIES de `04-ui.md § 2`, echelle 3 :
// aucune teinte ni forme nouvelle. Deux choses s'y ajoutent, arbitrees :
// - un contour noir de 2 px sur CHAQUE badge — la regle du halo de
//   `04-ui.md § 3` : sans lui, `#F0E442` (1,32:1) et `#E69F00` (2,25:1) ne
//   tiennent pas 3:1 contre le fond blanc de l'ecran ;
// - le second liseré de Crise, INTERIEUR, blanc, 1 px, separe du contour
//   par 1 px de teinte (`04-ui.md § 2` n'en donnait pas la couleur).
//
// Le libelle du niveau n'est JAMAIS ecrit sur la teinte : blanc sur `#D55E00`
// (3,87:1) et sur `#767676` (4,54:1) restent sous le 7:1 exige d'un libelle
// d'etat. L'ecran le pose a cote, en [droughtLevelLabelColor] sur
// [droughtScreenBackground]. Le badge lui-meme ne porte ni texte ni
// semantique : c'est un element graphique, annonce par le libelle voisin.
//
// Tous les ratios sont verrouilles par
// `test/features/restrictions/view/drought_severity_badge_test.dart`.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';

/// Forme d'un badge (colonne « Forme » de l'echelle 3).
enum DroughtBadgeShape {
  /// ● — Vigilance.
  circle,

  /// ▲ — Alerte, Alerte renforcee.
  triangle,

  /// ⬣ — Crise.
  hexagon,

  /// ◌ — Non renseigne.
  emptyCircle,
}

/// Motif d'un badge (colonne « Motif » de l'echelle 3).
enum DroughtBadgePattern {
  /// Plein.
  solid,

  /// Hachures.
  hatched,

  /// Plein, double liseré.
  doubleBorder,

  /// Pointille.
  dotted,
}

/// Ce que `04-ui.md § 2` dit d'un niveau : teinte, forme, glyphe dans la
/// forme (et sa couleur, colonne « Texte sur fond »), motif.
final class DroughtBadgeStyle {
  const DroughtBadgeStyle({
    required this.tint,
    required this.shape,
    required this.pattern,
    this.glyph,
    this.glyphColor,
  });

  final Color tint;
  final DroughtBadgeShape shape;
  final DroughtBadgePattern pattern;

  /// Glyphe dessine dans la forme, ou `null` (Non renseigne).
  final String? glyph;

  /// Couleur du glyphe, ou `null` sans glyphe.
  final Color? glyphColor;
}

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);

/// Le style d'un niveau, recopie de `04-ui.md § 2`, echelle 3. `switch`
/// exhaustif : une gravite ajoutee sans style est une erreur de compilation
/// (BR-011). [GraviteInconnue] ne prend la teinte ni la forme d'aucun niveau
/// connu.
DroughtBadgeStyle droughtBadgeStyle(DroughtSeverity severity) =>
    switch (severity) {
      Vigilance() => const DroughtBadgeStyle(
        tint: Color(0xFFF0E442),
        shape: DroughtBadgeShape.circle,
        pattern: DroughtBadgePattern.solid,
        glyph: '!',
        glyphColor: _black,
      ),
      Alerte() => const DroughtBadgeStyle(
        tint: Color(0xFFE69F00),
        shape: DroughtBadgeShape.triangle,
        pattern: DroughtBadgePattern.solid,
        glyph: '!',
        glyphColor: _black,
      ),
      AlerteRenforcee() => const DroughtBadgeStyle(
        tint: Color(0xFFD55E00),
        shape: DroughtBadgeShape.triangle,
        pattern: DroughtBadgePattern.hatched,
        glyph: '!!',
        glyphColor: _white,
      ),
      Crise() => const DroughtBadgeStyle(
        tint: Color(0xFF7B241C),
        shape: DroughtBadgeShape.hexagon,
        pattern: DroughtBadgePattern.doubleBorder,
        glyph: '✕',
        glyphColor: _white,
      ),
      GraviteInconnue() => const DroughtBadgeStyle(
        tint: Color(0xFF767676),
        shape: DroughtBadgeShape.emptyCircle,
        pattern: DroughtBadgePattern.dotted,
      ),
    };

/// Contour de chaque badge : noir (halo sur fond clair, `04-ui.md § 3`).
const Color droughtBadgeContourColor = _black;

/// Epaisseur du contour de chaque badge.
const double droughtBadgeContourWidth = 2;

/// Second liseré de Crise, interieur : blanc (Q-7 de C1).
const Color droughtBadgeInnerBorderColor = _white;

/// Epaisseur du second liseré de Crise.
const double droughtBadgeInnerBorderWidth = 1;

/// Ecart, en teinte, entre le contour et le second liseré de Crise.
const double droughtBadgeInnerBorderGap = 1;

/// Couleur du libelle de niveau, pose A COTE du badge (Q-7).
const Color droughtLevelLabelColor = _black;

/// Fond de l'ecran des restrictions, sur lequel badges et libelles sont
/// poses.
const Color droughtScreenBackground = _white;

/// Cote du badge, en pixels logiques. Le badge n'est pas interactif : la
/// cible tactile minimale ne s'y applique pas (conception T2 § 7).
const double droughtBadgeSize = 28;

/// Le badge d'un niveau de gravite secheresse : forme, teinte, motif et
/// glyphe, sans libelle ni semantique (le libelle est pose a cote).
class DroughtSeverityBadge extends StatelessWidget {
  const DroughtSeverityBadge({
    required this.severity,
    this.size = droughtBadgeSize,
    super.key,
  });

  final DroughtSeverity severity;

  /// Cote affiche. Le dessin est fait a la taille REELLE : la forme, le
  /// glyphe, les hachures et les points suivent [size], mais le contour
  /// ([droughtBadgeContourWidth]) et le liseré de Crise
  /// ([droughtBadgeInnerBorderWidth]) gardent leur epaisseur fixe (regle du
  /// halo, `04-ui.md` § 3). A [droughtBadgeSize], rendu inchange.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DroughtBadgePainter(droughtBadgeStyle(severity)),
        ),
      ),
    );
  }
}

class _DroughtBadgePainter extends CustomPainter {
  _DroughtBadgePainter(this.style);

  final DroughtBadgeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    // Le contour est trace a l'interieur du carre : on retire la moitie de
    // son epaisseur a chaque bord.
    const double half = droughtBadgeContourWidth / 2;
    final Rect box = (Offset.zero & size).deflate(half);
    // Facteur des elements qui suivent la taille (hachures, points).
    final double k = size.width / droughtBadgeSize;
    final Path outline = _shapePath(style.shape, box);

    final Paint contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = droughtBadgeContourWidth
      ..color = droughtBadgeContourColor;

    switch (style.pattern) {
      case DroughtBadgePattern.solid:
        canvas.drawPath(outline, Paint()..color = style.tint);
      case DroughtBadgePattern.hatched:
        canvas.drawPath(outline, Paint()..color = style.tint);
        _hatch(canvas, outline, box, k);
      case DroughtBadgePattern.doubleBorder:
        canvas.drawPath(outline, Paint()..color = style.tint);
        // Filet interieur blanc de 1 px, a 1 px de teinte du contour.
        const double inset =
            half +
            droughtBadgeInnerBorderGap +
            droughtBadgeInnerBorderWidth / 2;
        canvas.drawPath(
          _shapePath(style.shape, box.deflate(inset)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = droughtBadgeInnerBorderWidth
            ..color = droughtBadgeInnerBorderColor,
        );
      case DroughtBadgePattern.dotted:
        // ◌ : rond vide, fond de l'ecran, anneau pointille dans la teinte.
        canvas.drawPath(outline, Paint()..color = droughtScreenBackground);
        _dottedRing(canvas, box.deflate(3 * k), k);
    }
    canvas.drawPath(outline, contour);

    final String? glyph = style.glyph;
    final Color? glyphColor = style.glyphColor;
    if (glyph != null && glyphColor != null) {
      _glyph(canvas, size, glyph, glyphColor);
    }
  }

  static Path _shapePath(DroughtBadgeShape shape, Rect box) {
    switch (shape) {
      case DroughtBadgeShape.circle:
      case DroughtBadgeShape.emptyCircle:
        return Path()..addOval(box);
      case DroughtBadgeShape.triangle:
        return Path()
          ..moveTo(box.center.dx, box.top)
          ..lineTo(box.right, box.bottom)
          ..lineTo(box.left, box.bottom)
          ..close();
      case DroughtBadgeShape.hexagon:
        final double radius = box.shortestSide / 2;
        final Path path = Path();
        for (int i = 0; i < 6; i++) {
          final double angle = math.pi / 6 + i * math.pi / 3;
          final Offset corner =
              box.center +
              Offset(radius * math.cos(angle), radius * math.sin(angle));
          if (i == 0) {
            path.moveTo(corner.dx, corner.dy);
          } else {
            path.lineTo(corner.dx, corner.dy);
          }
        }
        return path..close();
    }
  }

  static void _hatch(Canvas canvas, Path clip, Rect box, double k) {
    canvas
      ..save()
      ..clipPath(clip);
    final Paint line = Paint()
      ..color = _black
      ..strokeWidth = k;
    for (double x = box.left - box.height; x < box.right; x += 4 * k) {
      canvas.drawLine(
        Offset(x, box.bottom),
        Offset(x + box.height, box.top),
        line,
      );
    }
    canvas.restore();
  }

  void _dottedRing(Canvas canvas, Rect box, double k) {
    final Paint dot = Paint()..color = style.tint;
    const int dots = 12;
    final double radius = box.shortestSide / 2;
    for (int i = 0; i < dots; i++) {
      final double angle = i * 2 * math.pi / dots;
      canvas.drawCircle(
        box.center + Offset(radius * math.cos(angle), radius * math.sin(angle)),
        1.5 * k,
        dot,
      );
    }
  }

  static void _glyph(Canvas canvas, Size size, String glyph, Color color) {
    // Taille fixe : le glyphe est un element graphique, il ne suit pas la
    // police de l'usager (le libelle voisin, lui, la suit).
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: color,
          fontSize: size.height * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Un peu sous le centre : le centre de gravite visuel d'un triangle est
    // bas, et le decalage reste imperceptible sur un rond.
    painter
      ..paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          (size.height - painter.height) / 2 + size.height * 0.06,
        ),
      )
      ..dispose();
  }

  @override
  bool shouldRepaint(_DroughtBadgePainter oldDelegate) =>
      oldDelegate.style != style;
}
