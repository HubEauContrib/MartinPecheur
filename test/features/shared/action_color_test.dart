// Verrouille la couleur des actions principales (arbitrage du commanditaire du
// 2026-09-29, canvas de design « Arrêtés et bouton carte ») : #0B5E86, texte
// blanc dessus, au moins 7:1 — un libellé d'action porte le même seuil qu'un
// libellé d'état (`04-ui.md` § 3).
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/action_color.dart';

import '../restrictions/view/drought_severity_badge_test.dart'
    show contrastRatio;

void main() {
  test('la couleur des actions principales est #0B5E86', () {
    expect(primaryActionColor, const Color(0xFF0B5E86));
  });

  test('le texte des actions principales est blanc', () {
    expect(onPrimaryActionColor, const Color(0xFFFFFFFF));
  });

  test('blanc sur la couleur des actions tient 7:1', () {
    expect(
      contrastRatio(onPrimaryActionColor, primaryActionColor),
      greaterThanOrEqualTo(7),
    );
  });
}
