// Le style des niveaux de vigilance crues (T4, M1) : cadrage § 7.3 et § 7.4.
//
// Teintes du canvas du 2026-10-03, déjà employées par d'autres échelles ; leur
// réemploi d'une échelle à l'autre est permis par BR-008. Contour noir sur
// chaque trait et chaque jauge (halo, `04-ui.md` § 3) : `#F0E442` et `#E69F00`
// ne tiennent pas 3:1 contre le blanc sans lui.

import 'package:flutter/painting.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';

/// Ce que le cadrage dit d'un niveau : teinte, épaisseur du trait, motif et
/// nombre de barres de la jauge.
final class FloodLevelStyle {
  const FloodLevelStyle({
    required this.tint,
    required this.strokeWidth,
    required this.dotted,
    required this.bars,
  });

  final Color tint;

  /// Épaisseur du trait, en pixels.
  final double strokeWidth;

  /// Trait en pointillé (niveau non reconnu seulement).
  final bool dotted;

  /// Nombre de barres horizontales de la jauge.
  final int bars;
}

/// Le style d'un niveau. `switch` exhaustif : un niveau ajouté sans style est
/// une erreur de compilation (BR-011).
FloodLevelStyle floodLevelStyle(FloodVigilanceLevel level) => switch (level) {
  Vert() => const FloodLevelStyle(
    tint: Color(0xFF009E73),
    strokeWidth: 3,
    dotted: false,
    bars: 0,
  ),
  Jaune() => const FloodLevelStyle(
    tint: Color(0xFFF0E442),
    strokeWidth: 5,
    dotted: false,
    bars: 1,
  ),
  Orange() => const FloodLevelStyle(
    tint: Color(0xFFE69F00),
    strokeWidth: 6,
    dotted: false,
    bars: 2,
  ),
  Rouge() => const FloodLevelStyle(
    tint: Color(0xFF7B241C),
    strokeWidth: 7,
    dotted: false,
    bars: 3,
  ),
  NiveauCruesInconnu() => const FloodLevelStyle(
    tint: Color(0xFF767676),
    strokeWidth: 4,
    dotted: true,
    bars: 0,
  ),
};

/// Contour de chaque trait et de chaque jauge : noir.
const Color floodContourColor = Color(0xFF000000);

/// Largeur VISIBLE du contour de chaque côté du trait et de la jauge. Un
/// `Polyline.borderStrokeWidth` s'ajoute à la largeur du trait et se partage
/// entre les deux côtés : le calque passe `2 * floodContourWidth`.
const double floodContourWidth = 2;

/// Barres blanches sur le rouge (noires ailleurs).
const Color floodRedBarsColor = Color(0xFFFFFFFF);
