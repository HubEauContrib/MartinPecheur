// Verrouille le bandeau permanent de la carte (`W3`, emplacement 2 de
// `04-ui.md § 5`, `BR-014`) : texte figé mot pour mot, cible tactile de
// l'action « Ce que ça dit » ≥ 44 pt, AUCUN paramètre de repli, de fermeture
// ni de masquage sur la surface publique — un bandeau qu'on peut fermer
// n'est pas permanent (`04-ui.md § 4`) — région d'alerte, contraste ≥ 7:1 du
// couple de teintes déclaré, et absence de mot de garantie.
//
// Arbitrage du commanditaire du 2026-09-22 : le tap sur l'action ouvre une
// feuille ([WarningReviewSheet]) qui RÉAFFICHE en lecture seule le titre et
// le corps du modal initial — sans case ni bouton d'acquittement — et se
// referme par son propre bouton.
//
// ⚠️ Aucun `FlutterMap` n'est monté ici : ce fichier ne teste que le bandeau
// et la feuille, tous deux indépendants de la carte.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_warning_banner.dart';

/// Le fichier source du bandeau, lu par le verrou de surface publique
/// ci-dessous — même convention que `test/architecture/layers_test.dart` et
/// `map_empty_states_test.dart` : lire le code plutôt que de le deviner.
const String _sourcePath = 'lib/features/map/view/map_warning_banner.dart';

/// Luminance relative WCAG d'une couleur (sRGB), formule officielle
/// (https://www.w3.org/TR/WCAG21/#dfn-relative-luminance).
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  final double r = channel(color.r);
  final double g = channel(color.g);
  final double b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Ratio de contraste WCAG entre deux couleurs — toujours ≥ 1.
double _contrastRatio(Color a, Color b) {
  final double lumA = _relativeLuminance(a) + 0.05;
  final double lumB = _relativeLuminance(b) + 0.05;
  return lumA > lumB ? lumA / lumB : lumB / lumA;
}

/// Aucun mot de garantie (`BR-014`) : ni *fiable*, ni *officiel*, ni
/// *en direct* — frontière de mot linguistique, comme
/// `test/domain/warnings/warning_texts_test.dart`.
final RegExp _guaranteeWords = RegExp(
  r'(?<!\p{L})(fiable|officiel|officielle|en direct)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MapWarningBanner — texte et cible tactile', () {
    testWidgets('rend mapBannerText exactement', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      expect(find.text(mapBannerText), findsOneWidget);
    });

    testWidgets("l'action « Ce que ça dit » est atteignable, cible >= 44 pt", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      final Finder action = find.byKey(mapWarningBannerExplainKey);
      expect(action, findsOneWidget);

      final Size size = tester.getSize(action);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    test('mapBannerText ne contient aucun mot de garantie (BR-014)', () {
      expect(_guaranteeWords.hasMatch(mapBannerText), isFalse);
    });
  });

  group('MapWarningBanner — surface publique (04-ui.md § 4)', () {
    test(
      "n'expose EXACTEMENT que `onExplain` et `key` — liste BLANCHE, pas une "
      "liste noire de mots interdits : un bandeau qu'on peut fermer n'est "
      'pas permanent, et seule une liste blanche garantit qu\'AUCUN '
      "paramètre de repli, de fermeture ou de masquage, même sous un nom "
      "qu'on n'aurait pas anticipé, ne puisse s'ajouter sans faire échouer "
      'ce test',
      () {
        final String source = File(_sourcePath).readAsStringSync();
        final RegExp constructorPattern = RegExp(
          r'const MapWarningBanner\(([^)]*)\)',
        );
        final Match? match = constructorPattern.firstMatch(source);
        expect(
          match,
          isNotNull,
          reason:
              'constructeur de MapWarningBanner introuvable dans '
              '$_sourcePath : le verrou ne peut pas lire sa surface publique',
        );
        final String parameters = match!.group(1) ?? '';

        expect(
          parameters.replaceAll(RegExp(r'\s'), ''),
          '{this.onExplain,super.key}',
          reason:
              'la surface publique de MapWarningBanner a changé : seuls '
              '`onExplain` (l\'action, jamais un repli) et `key` '
              '(générique à tout widget) sont tolérés — $parameters',
        );

        expect(
          RegExp(r'MapWarningBanner\.\w+\(').hasMatch(source),
          isFalse,
          reason:
              'un constructeur NOMMÉ est apparu sur MapWarningBanner : la '
              'liste blanche ci-dessus ne verrouille que le constructeur '
              'par défaut, un second constructeur la contournerait '
              'silencieusement',
        );
      },
    );
  });

  group('MapWarningBanner — accessibilité', () {
    testWidgets('est une région d\'alerte (liveRegion)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      final SemanticsNode region = tester.getSemantics(
        find.byKey(mapWarningBannerRegionKey),
      );
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    test('contraste du couple de teintes déclaré >= 7:1 (04-ui.md § 3)', () {
      expect(
        _contrastRatio(mapWarningBannerForeground, mapWarningBannerBackground),
        greaterThanOrEqualTo(7),
      );
    });
  });

  group('MapWarningBanner — typographie dynamique (04-ui.md § 3)', () {
    testWidgets(
      'sur un format téléphone, à 200 % de police, le bandeau n\'est pas '
      'tronqué',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _harness(const MapWarningBanner()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(mapBannerText), findsOneWidget);

        final Size actionSize = tester.getSize(
          find.byKey(mapWarningBannerExplainKey),
        );
        expect(actionSize.width, greaterThanOrEqualTo(44));
        expect(actionSize.height, greaterThanOrEqualTo(44));
      },
    );
  });

  group('WarningReviewSheet — arbitrage du commanditaire du 2026-09-22', () {
    testWidgets(
      'le tap sur l\'action ouvre la feuille avec le titre et le corps du '
      'modal initial, sans case ni bouton d\'acquittement',
      (WidgetTester tester) async {
        await tester.pumpWidget(_harness(const MapWarningBanner()));

        await tester.tap(find.byKey(mapWarningBannerExplainKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningTitle), findsOneWidget);
        expect(find.text(initialWarningBody), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text(initialWarningButtonLabel), findsNothing);
        expect(find.byKey(warningReviewSheetCloseButtonKey), findsOneWidget);
      },
    );

    testWidgets('la fermeture referme la feuille', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      await tester.tap(find.byKey(mapWarningBannerExplainKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.tap(find.byKey(warningReviewSheetCloseButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsNothing);
    });
  });
}
