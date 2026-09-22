// Verrouille le menu de la carte (`W3b`, arbitrage du commanditaire du
// 2026-09-23, qui remplace l'invariant « bandeau permanent, non repliable »
// de `W3`) : un bouton d'icône (`Icons.menu`) en haut à droite de la carte,
// cible tactile >= 44 pt, libellé d'accessibilité « Menu »
// ([mapMenuLabel]), atteignable et activable au clavier (Tab puis
// Entrée/Espace). Son unique entrée en T1, « Avertissement »
// ([mapMenuWarningItemLabel]), réaffiche le bandeau fermé pour la session —
// en production, `MapViewModel.showBanner` — et est elle-même activable au
// clavier, une fois atteinte à la flèche bas — un menu Material se parcourt
// aux flèches, pas au Tab (`menu_anchor.dart`, paquet Flutter installé).
//
// Le positionnement relatif à la légende et à l'attribution IGN (`04-ui.md
// § 4` : ne recouvre ni l'une ni l'autre, ni les puces) est verrouillé côté
// `map_view_test.dart`, dans `buildMapOverlays` — ce fichier ne teste que le
// widget seul, indépendant de la carte.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_menu.dart';

/// Mots bannis (`CLAUDE.md`) et mots de garantie (`BR-014`) : aucun des deux
/// libellés du menu ne doit en porter un.
final RegExp _forbiddenWords = RegExp(
  r'(?<!\p{L})(suffisant|insuffisant|normal|bon|s[uû]r|fiable|officiel|'
  r'officielle|en direct)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MapMenuButton — texte et cible tactile', () {
    testWidgets('cible tactile >= 44 pt', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(MapMenuButton(onShowBanner: () {})));

      final Size size = tester.getSize(find.byKey(mapMenuButtonKey));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('libellé d\'accessibilité « Menu »', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(MapMenuButton(onShowBanner: () {})));

      final SemanticsNode node = tester.getSemantics(
        find.byKey(mapMenuButtonKey),
      );
      expect(node.label, mapMenuLabel);

      handle.dispose();
    });

    testWidgets(
      "porte une action tap pour le lecteur d'écran — sans elle, un double "
      "tap au lecteur d'écran n'ouvre pas le menu, même si le rendu répond "
      'au toucher direct (relecture du 2026-09-23)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(MapMenuButton(onShowBanner: () {})));

        final SemanticsNode node = tester.getSemantics(
          find.byKey(mapMenuButtonKey),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
      },
    );

    test('aucun mot interdit dans mapMenuLabel ni mapMenuWarningItemLabel', () {
      expect(_forbiddenWords.hasMatch(mapMenuLabel), isFalse);
      expect(_forbiddenWords.hasMatch(mapMenuWarningItemLabel), isFalse);
    });
  });

  group('MapMenuButton — ouverture et entrée « Avertissement »', () {
    testWidgets('le tap ouvre le menu avec la seule entrée Avertissement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(MapMenuButton(onShowBanner: () {})));

      await tester.tap(find.byKey(mapMenuButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(mapMenuWarningItemLabel), findsOneWidget);
      expect(find.byKey(mapMenuWarningItemKey), findsOneWidget);
    });

    testWidgets(
      'le tap sur « Avertissement » appelle onShowBanner et referme le menu',
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _harness(MapMenuButton(onShowBanner: () => calls++)),
        );

        await tester.tap(find.byKey(mapMenuButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(mapMenuWarningItemKey));
        await tester.pumpAndSettle();

        expect(calls, 1);
        expect(find.text(mapMenuWarningItemLabel), findsNothing);
      },
    );
  });

  group('MapMenuButton — clavier (04-ui.md § 3)', () {
    testWidgets(
      'le bouton de menu est atteignable au Tab et activable à Entrée',
      (WidgetTester tester) async {
        await tester.pumpWidget(_harness(MapMenuButton(onShowBanner: () {})));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text(mapMenuWarningItemLabel), findsOneWidget);
      },
    );

    testWidgets(
      "l'entrée « Avertissement » est activable au clavier (Espace)",
      (WidgetTester tester) async {
        int calls = 0;
        await tester.pumpWidget(
          _harness(MapMenuButton(onShowBanner: () => calls++)),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        // Un menu Material se parcourt aux flèches, pas au Tab (les
        // événements directionnels, pas la traversée par défaut —
        // `menu_anchor.dart`, paquet Flutter installé) : la flèche bas
        // atteint la première — et seule — entrée.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(calls, 1);
      },
    );
  });
}
