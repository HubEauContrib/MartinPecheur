// Definitions publiees par Vigicrues pour chaque niveau : page d'accueil de
// Vigicrues, relevee le 2026-10-14, `docs/sources/vigicrues.md`, `VC-13` ;
// fixture `test/fixtures/vigicrues/accueil_legende_2026-10-14.html` ;
// arbitrage 5 du cadrage de T4 : le texte du site, pas celui du Sandre.
//
// Citations au caractere pres (apostrophes comprises) : on ne les reformule
// pas (BR-015).

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';

/// Legende publiee d'un niveau ; `null` pour un niveau non reconnu.
String? publishedFloodLegend(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'Pas de vigilance particulière requise',
  Jaune() => 'Risque de crue génératrice de débordements',
  Orange() => 'Risque de crue génératrice de débordements importants',
  Rouge() => 'Risque de crue majeure',
  NiveauCruesInconnu() => null,
};

/// Explication publiee d'un niveau ; `null` pour le vert et pour un niveau
/// non reconnu.
String? publishedFloodExplanation(FloodVigilanceLevel level) => switch (level) {
  Vert() => null,
  Jaune() => "Risque de crue génératrice de débordements et de dommages localisés ou de montée rapide et dangereuse des eaux, nécessitant une vigilance particulière notamment dans le cas d'activités exposées et/ou saisonnières.",
  Orange() => 'Risque de crue génératrice de débordements importants susceptibles d’avoir un impact significatif sur la vie collective et la sécurité des biens et des personnes.',
  Rouge() => 'Risque de crue majeure. Menace directe et généralisée de la sécurité des personnes et des biens.',
  NiveauCruesInconnu() => null,
};
