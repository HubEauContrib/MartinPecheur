// L'étiquette d'un tronçon sur la lecture Crues (T4, M2 ; cadrage § 7.2 et
// § 7.4) : la jauge du niveau puis son nom, sur fond blanc à contour noir.
// Le nom n'est jamais posé sur la teinte : la jauge la porte seule
// (précédent : `drought_severity_badge.dart`).
//
// Cible tactile de la plateforme ([minimumTapTarget]) sur [floodLabelWidth]
// de large (D7) ; un contenu plus large est réduit (`FittedBox`), jamais
// coupé. Focalisable au clavier : Entrée ouvre la fiche, comme un toucher.

import 'package:flutter/widgets.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Largeur d'une étiquette, en pixels logiques (D7).
const double floodLabelWidth = 168;

const Color _white = Color(0xFFFFFFFF);

/// L'annonce d'une étiquette au lecteur d'écran : l'échelle, le niveau, puis
/// le tronçon (cadrage § 7.2, `BR-008`). `switch` exhaustif : un niveau
/// ajouté sans annonce est une erreur de compilation (`BR-011`).
String floodLabelAnnouncement(FloodSection section) => switch (section.level) {
  Vert() => 'crues : vigilance verte, ${section.name}',
  Jaune() => 'crues : vigilance jaune, ${section.name}',
  Orange() => 'crues : vigilance orange, ${section.name}',
  Rouge() => 'crues : vigilance rouge, ${section.name}',
  NiveauCruesInconnu() => 'crues : niveau non reconnu, ${section.name}',
};

/// L'étiquette de [section] : [FloodLevelGauge] puis [floodLevelLabel].
///
/// [onActivate] est appelé au toucher et à Entrée ou Espace ; `null`,
/// l'étiquette reste inerte et hors de l'ordre de tabulation.
class FloodSectionLabel extends StatelessWidget {
  const FloodSectionLabel({
    required this.section,
    required this.onActivate,
    super.key,
  });

  final FloodSection section;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final double height = minimumTapTarget;

    // Le geste est l'ANCÊTRE du `Semantics` : `excludeSemantics` ne masque
    // que les descendants, l'action de toucher reste annoncée.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onActivate,
      child: Semantics(
        button: true,
        label: floodLabelAnnouncement(section),
        excludeSemantics: true,
        child: SizedBox(
          width: floodLabelWidth,
          height: height,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: KeyboardFocusRing(
                onActivate: onActivate,
                canRequestFocus: onActivate != null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _white,
                    border: Border.all(
                      color: floodContourColor,
                      width: floodContourWidth,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FloodLevelGauge(level: section.level),
                          const SizedBox(width: 8),
                          Text(
                            floodLevelLabel(section.level),
                            softWrap: false,
                            style: const TextStyle(
                              color: floodContourColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
