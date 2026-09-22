// Verrouille le bandeau d'avertissement de la carte (`W3`, `W3b`,
// emplacement 2 de `04-ui.md § 5`, `BR-014`) : texte figé mot pour mot,
// cible tactile de l'action « Ce que ça dit » ≥ 44 pt, une surface publique
// EN LISTE BLANCHE — `onExplain` et `onDismiss`, jamais un troisième
// paramètre non anticipé —, région d'alerte, contraste ≥ 7:1 du couple de
// teintes déclaré, et absence de mot de garantie.
//
// Arbitrage du commanditaire du 2026-09-22 : le tap sur l'action « Ce que ça
// dit » ouvre une feuille ([WarningReviewSheet]) qui RÉAFFICHE en lecture
// seule le titre et le corps du modal initial — sans case ni bouton
// d'acquittement — et se referme par son propre bouton.
//
// Arbitrage du commanditaire du 2026-09-23 (`W3b`) : le bandeau n'est plus
// permanent — il est affiché à CHAQUE lancement, mais un bouton « Fermer »
// ([onDismiss]) le referme pour la SESSION en cours, sans rien persister ; un
// menu de la carte ([map_menu.dart]) le réaffiche. C'est [MapViewModel] qui
// porte cet état (`bannerVisible`) : le bandeau lui-même ne décide rien, il
// reçoit `onDismiss` et ne fait qu'appeler ce rappel.
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

  group('MapWarningBanner — surface publique (04-ui.md § 4, arbitrage '
      '2026-09-23)', () {
    test("n'expose EXACTEMENT que `onExplain`, `onDismiss` et `key` — liste "
        'BLANCHE, pas une liste noire de mots interdits : seule une liste '
        "blanche garantit qu'AUCUN paramètre non anticipé ne puisse s'ajouter "
        'sans faire échouer ce test', () {
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
        '{this.onExplain,this.onDismiss,super.key}',
        reason:
            'la surface publique de MapWarningBanner a changé : seuls '
            '`onExplain` (l\'action « Ce que ça dit »), `onDismiss` (la '
            'fermeture pour la session, W3b) et `key` (générique à tout '
            'widget) sont tolérés — $parameters',
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
    });
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

  group('MapWarningBanner — fermeture (W3b, arbitrage du 2026-09-23)', () {
    testWidgets("le bouton « Fermer » est atteignable, cible >= 44 pt", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      final Finder dismiss = find.byKey(mapWarningBannerDismissKey);
      expect(dismiss, findsOneWidget);

      final Size size = tester.getSize(dismiss);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets("le tap sur « Fermer » appelle onDismiss", (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        _harness(MapWarningBanner(onDismiss: () => calls++)),
      );

      await tester.tap(find.byKey(mapWarningBannerDismissKey));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('porte le libellé « $warningReviewCloseLabel »', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const MapWarningBanner()));

      expect(find.text(warningReviewCloseLabel), findsOneWidget);
    });

    testWidgets(
      "porte une action tap pour le lecteur d'écran — sans elle, un double "
      "tap au lecteur d'écran n'active rien, même si le rendu répond au "
      'toucher direct (relecture du 2026-09-23)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(MapWarningBanner(onDismiss: () {})));

        final SemanticsNode node = tester.getSemantics(
          find.byKey(mapWarningBannerDismissKey),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
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
