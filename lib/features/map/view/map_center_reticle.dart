// Le réticule au centre exact de la carte (`E1` de T2, canvas de design du
// 2026-09-29) : il montre ce que désigne le bouton « Restrictions au centre de
// la carte ». Une croix à quatre branches et un petit cercle central, trait
// noir sur halo blanc — lisible sur tout fond de carte.
//
// Ce n'est PAS une forme d'échelle d'état (`04-ui.md` § 2) : ni rond plein, ni
// triangle, ni carré, ni losange. Inerte : hors pointeur, hors sémantique,
// hors tabulation.
//
// N'existe que dans le MODE de désignation (`E5`, 2026-10-03) : le choix
// « Restrictions » du sélecteur le fait apparaître avec le bouton.

import 'package:flutter/material.dart';

/// Clé du réticule.
const Key mapCenterReticleKey = Key('map-center-reticle');

/// Côté du réticule, en pixels logiques.
const double mapCenterReticleSize = 48;

class MapCenterReticle extends StatelessWidget {
  const MapCenterReticle({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: SizedBox(
            key: mapCenterReticleKey,
            width: mapCenterReticleSize,
            height: mapCenterReticleSize,
            child: CustomPaint(painter: _ReticlePainter()),
          ),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double arm = size.width / 2 - 4;
    const double gap = 6;
    const double radius = 3;

    void draw(Paint paint) {
      canvas
        ..drawLine(Offset(c.dx - arm, c.dy), Offset(c.dx - gap, c.dy), paint)
        ..drawLine(Offset(c.dx + gap, c.dy), Offset(c.dx + arm, c.dy), paint)
        ..drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy - gap), paint)
        ..drawLine(Offset(c.dx, c.dy + gap), Offset(c.dx, c.dy + arm), paint)
        ..drawCircle(c, radius, paint);
    }

    final Paint halo = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    final Paint trait = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    draw(halo);
    draw(trait);
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) => false;
}
