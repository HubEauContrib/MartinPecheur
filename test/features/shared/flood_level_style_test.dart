import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';

import '../restrictions/view/drought_severity_badge_test.dart'
    show contrastRatio;

const Color _white = Color(0xFFFFFFFF);

void main() {
  group('floodLevelStyle', () {
    test('la table des cinq styles', () {
      final List<(FloodVigilanceLevel, Color, double, bool, int)> table = [
        (const Vert(), const Color(0xFF009E73), 3, false, 0),
        (const Jaune(), const Color(0xFFF0E442), 5, false, 1),
        (const Orange(), const Color(0xFFE69F00), 6, false, 2),
        (const Rouge(), const Color(0xFF7B241C), 7, false, 3),
        (const NiveauCruesInconnu(9), const Color(0xFF767676), 4, true, 0),
      ];
      for (final (level, tint, width, dotted, bars) in table) {
        final FloodLevelStyle style = floodLevelStyle(level);
        expect(style.tint, tint, reason: '$level');
        expect(style.strokeWidth, width, reason: '$level');
        expect(style.dotted, dotted, reason: '$level');
        expect(style.bars, bars, reason: '$level');
      }
    });

    test("l'épaisseur croît strictement de vert à rouge", () {
      final List<double> widths = <FloodVigilanceLevel>[
        const Vert(),
        const Jaune(),
        const Orange(),
        const Rouge(),
      ].map((FloodVigilanceLevel l) => floodLevelStyle(l).strokeWidth).toList();
      for (int i = 1; i < widths.length; i++) {
        expect(widths[i], greaterThan(widths[i - 1]));
      }
    });

    test('seul le niveau inconnu est en pointillé', () {
      expect(floodLevelStyle(const Vert()).dotted, isFalse);
      expect(floodLevelStyle(const Jaune()).dotted, isFalse);
      expect(floodLevelStyle(const Orange()).dotted, isFalse);
      expect(floodLevelStyle(const Rouge()).dotted, isFalse);
      expect(floodLevelStyle(const NiveauCruesInconnu(null)).dotted, isTrue);
    });

    test('contour noir de 2 px, barres blanches sur le rouge', () {
      expect(floodContourColor, const Color(0xFF000000));
      expect(floodContourWidth, 2);
      expect(floodRedBarsColor, _white);
    });

    test('jaune et orange sous 3:1 contre le blanc : le contour les porte', () {
      expect(
        contrastRatio(floodLevelStyle(const Jaune()).tint, _white),
        lessThan(3),
      );
      expect(
        contrastRatio(floodLevelStyle(const Orange()).tint, _white),
        lessThan(3),
      );
      expect(contrastRatio(floodContourColor, _white), greaterThan(3));
    });

    test('le blanc sur le rouge dépasse 4,5:1', () {
      expect(
        contrastRatio(floodRedBarsColor, floodLevelStyle(const Rouge()).tint),
        greaterThan(4.5),
      );
    });
  });
}
