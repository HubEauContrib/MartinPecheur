// Verrouille le badge de gravite secheresse (E2 de T2, arbitrage Q-7 de C1,
// conception § 7) : teintes, formes, motifs et glyphes RECOPIES de
// `docs/04-ui.md § 2`, echelle 3 — aucune teinte inventee ; contour noir de
// 2 px sur chaque badge ; second liseré de Crise BLANC ; aucun libelle ecrit
// sur la teinte (il est pose a cote, par l'ecran).
//
// Les ratios de contraste sont CALCULES ici (luminance relative WCAG) sur
// les couples declares, pas recopies : un changement de teinte qui ferait
// tomber un couple sous son seuil rend ce test rouge.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

/// Ratio de contraste WCAG entre [a] et [b].
double contrastRatio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

void main() {
  group('droughtBadgeStyle — recopie de 04-ui.md § 2, echelle 3', () {
    test('Vigilance : #F0E442, rond, « ! » noir, plein', () {
      final DroughtBadgeStyle style = droughtBadgeStyle(const Vigilance());
      expect(style.tint, const Color(0xFFF0E442));
      expect(style.shape, DroughtBadgeShape.circle);
      expect(style.glyph, '!');
      expect(style.glyphColor, _black);
      expect(style.pattern, DroughtBadgePattern.solid);
    });

    test('Alerte : #E69F00, triangle, « ! » noir, plein', () {
      final DroughtBadgeStyle style = droughtBadgeStyle(const Alerte());
      expect(style.tint, const Color(0xFFE69F00));
      expect(style.shape, DroughtBadgeShape.triangle);
      expect(style.glyph, '!');
      expect(style.glyphColor, _black);
      expect(style.pattern, DroughtBadgePattern.solid);
    });

    test('Alerte renforcee : #D55E00, triangle, « !! » blanc, hachures', () {
      final DroughtBadgeStyle style = droughtBadgeStyle(
        const AlerteRenforcee(),
      );
      expect(style.tint, const Color(0xFFD55E00));
      expect(style.shape, DroughtBadgeShape.triangle);
      expect(style.glyph, '!!');
      expect(style.glyphColor, _white);
      expect(style.pattern, DroughtBadgePattern.hatched);
    });

    test('Crise : #7B241C, hexagone, « ✕ » blanc, double liseré', () {
      final DroughtBadgeStyle style = droughtBadgeStyle(const Crise());
      expect(style.tint, const Color(0xFF7B241C));
      expect(style.shape, DroughtBadgeShape.hexagon);
      expect(style.glyph, '✕');
      expect(style.glyphColor, _white);
      expect(style.pattern, DroughtBadgePattern.doubleBorder);
    });

    test('Non renseigné : #767676, rond vide, aucun glyphe, pointillé', () {
      for (final DroughtSeverity unknown in const <DroughtSeverity>[
        GraviteInconnue(null),
        GraviteInconnue('extreme'),
      ]) {
        final DroughtBadgeStyle style = droughtBadgeStyle(unknown);
        expect(style.tint, const Color(0xFF767676));
        expect(style.shape, DroughtBadgeShape.emptyCircle);
        expect(style.glyph, isNull);
        expect(style.pattern, DroughtBadgePattern.dotted);
      }
    });

    test('un niveau inconnu ne prend la teinte ni la forme d aucun des quatre '
        'niveaux (BR-011)', () {
      final DroughtBadgeStyle unknown = droughtBadgeStyle(
        const GraviteInconnue('x'),
      );
      for (final DroughtSeverity known in droughtSeverityScale) {
        final DroughtBadgeStyle style = droughtBadgeStyle(known);
        expect(unknown.tint, isNot(style.tint));
        expect(unknown.shape, isNot(style.shape));
      }
    });
  });

  group('contour et liseré (Q-7, 04-ui.md § 3)', () {
    test('contour noir de 2 px sur chaque badge', () {
      expect(droughtBadgeContourColor, _black);
      expect(droughtBadgeContourWidth, 2.0);
    });

    test('Crise : second liseré intérieur blanc de 1 px, séparé d 1 px', () {
      expect(droughtBadgeInnerBorderColor, _white);
      expect(droughtBadgeInnerBorderWidth, 1.0);
      expect(droughtBadgeInnerBorderGap, 1.0);
    });
  });

  group('couples de teintes déclarés — ratios de la conception (K-5)', () {
    test('libellé du niveau, posé à côté du badge : au moins 7:1 sur le fond '
        'de l écran (04-ui.md § 3)', () {
      expect(
        contrastRatio(droughtLevelLabelColor, droughtScreenBackground),
        greaterThanOrEqualTo(7),
      );
    });

    test(
      'glyphe dans la forme : au moins 3:1 contre sa teinte (WCAG 1.4.11)',
      () {
        for (final DroughtSeverity level in droughtSeverityScale) {
          final DroughtBadgeStyle style = droughtBadgeStyle(level);
          expect(
            contrastRatio(style.glyphColor!, style.tint),
            greaterThanOrEqualTo(3),
            reason: droughtSeverityLabel(level),
          );
        }
      },
    );

    test('contour noir contre le fond blanc de l écran : au moins 3:1', () {
      expect(
        contrastRatio(droughtBadgeContourColor, droughtScreenBackground),
        greaterThanOrEqualTo(3),
      );
    });

    test('Crise : liseré intérieur blanc contre #7B241C = 9,95:1', () {
      expect(
        contrastRatio(
          droughtBadgeInnerBorderColor,
          droughtBadgeStyle(const Crise()).tint,
        ),
        closeTo(9.95, 0.01),
      );
    });

    test('ratios de K-5, qui justifient le libellé à côté et le contour', () {
      // Blanc écrit sur #D55E00 et sur #767676 : sous 7:1, d'où le libellé
      // posé à côté du badge, jamais sur la teinte.
      expect(
        contrastRatio(_white, droughtBadgeStyle(const AlerteRenforcee()).tint),
        closeTo(3.87, 0.01),
      );
      expect(
        contrastRatio(
          _white,
          droughtBadgeStyle(const GraviteInconnue(null)).tint,
        ),
        closeTo(4.54, 0.01),
      );
      // #F0E442 et #E69F00 contre blanc : sous 3:1, d'où le contour noir.
      expect(
        contrastRatio(droughtBadgeStyle(const Vigilance()).tint, _white),
        closeTo(1.32, 0.01),
      );
      expect(
        contrastRatio(droughtBadgeStyle(const Alerte()).tint, _white),
        closeTo(2.25, 0.01),
      );
    });
  });

  group('DroughtSeverityBadge — widget', () {
    testWidgets('dessine la forme sans aucun texte ni sémantique propre : le '
        'libellé est posé à côté par l écran', (WidgetTester tester) async {
      for (final DroughtSeverity level in <DroughtSeverity>[
        ...droughtSeverityScale,
        const GraviteInconnue(null),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: DroughtSeverityBadge(severity: level)),
          ),
        );
        expect(find.byType(Text), findsNothing);
        expect(
          find.descendant(
            of: find.byType(DroughtSeverityBadge),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
        );
        final Size size = tester.getSize(find.byType(DroughtSeverityBadge));
        expect(size.width, droughtBadgeSize);
        expect(size.height, droughtBadgeSize);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
