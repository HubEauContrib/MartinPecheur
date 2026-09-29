// La couleur des actions principales (arbitrage du commanditaire du
// 2026-09-29, canvas de design « Arrêtés et bouton carte ») : le bouton
// « Restrictions au centre de la carte » et « Ouvrir l'arrêté ». Partagée par
// deux tranches (map, restrictions), donc sous `features/shared/`.
//
// Un bleu hors de toute teinte d'échelle d'état (`04-ui.md` § 2) : une action
// ne se confond pas avec un état de l'eau. Blanc dessus : 7,09:1, verrouillé
// par `test/features/shared/action_color_test.dart`.

import 'package:flutter/painting.dart';

/// Fond des actions principales.
const Color primaryActionColor = Color(0xFF0B5E86);

/// Texte et icône posés sur [primaryActionColor].
const Color onPrimaryActionColor = Color(0xFFFFFFFF);
