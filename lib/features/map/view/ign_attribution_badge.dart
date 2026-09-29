// L'attribution IGN Géoplateforme — **extraite** de `map_view.dart` par
// `K1` (2026-09-23), au même titre que [MapScaleChips]
// (`map_scale_chips.dart`) et `MapControls` (`map_controls.dart`). Aucun
// changement de comportement : seuls les imports des appelants changent.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';

/// Corps du texte de l'attribution, en points.
const double ignAttributionFontSize = 11;

/// Marge intérieure horizontale de chaque côté du texte.
const double ignAttributionPaddingHorizontal = 6;

/// Marge intérieure verticale de chaque côté du texte.
const double ignAttributionPaddingVertical = 2;

/// Bandeau d'attribution IGN Géoplateforme, exigé par la Licence Ouverte.
/// Porte son propre fond opaque : un texte posé directement sur un fond de
/// carte quelconque ne tient aucun contraste (`04-ui.md` § 3). Entièrement
/// `const` : rien ici ne dépend de l'état de l'écran.
class IgnAttributionBadge extends StatelessWidget {
  const IgnAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ignAttributionPaddingHorizontal,
          vertical: ignAttributionPaddingVertical,
        ),
        child: Text(
          ignAttribution,
          style: TextStyle(fontSize: ignAttributionFontSize),
        ),
      ),
    );
  }
}
