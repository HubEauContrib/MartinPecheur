// Verrouille le contrôle d'avertissement partagé (`W3c`, arbitrage du
// commanditaire du 2026-09-23) : icône + libellé « Avertissement », cible
// tactile ≥ 44 pt, atteignable et activable au clavier (Tab + Entrée),
// action de tap exposée au lecteur d'écran, ouvre la fenêtre avec le texte
// général du modal initial et, quand elle est fournie, la phrase propre à
// l'écran appelant SOUS ce texte général.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Le focus courant (`FocusManager.instance.primaryFocus`) est-il porté par
/// un élément du sous-arbre de [ancestor] ? [Focus.of] ne cherche que des
/// ANCÊTRES ; ici c'est l'inverse qu'il faut vérifier — le focus est-il
/// DESCENDU dans ce sous-arbre — d'où ce parcours manuel plutôt que
/// [Focus.of].
bool _hasFocusWithin(WidgetTester tester, Finder ancestor) {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  final Element root = tester.element(ancestor);
  bool found = false;
  void visit(Element element) {
    if (element == focusedContext) {
      found = true;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

void main() {
  group('WarningLink — texte et cible tactile', () {
    testWidgets('rend warningLinkLabel exactement', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      expect(find.text(warningLinkLabel), findsOneWidget);
    });

    testWidgets('cible tactile >= 44 pt', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      final Size size = tester.getSize(find.byKey(warningLinkKey));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets(
      "porte une action tap pour le lecteur d'écran — `excludeSemantics` "
      'masque celle du geste sans ce rappel',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(const WarningLink()));

        final SemanticsNode node = tester.getSemantics(
          find.byKey(warningLinkKey),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.label, warningLinkLabel);

        handle.dispose();
      },
    );
  });

  group('WarningLink — clavier (04-ui.md § 3)', () {
    testWidgets('atteignable au Tab et activable à Entrée', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsOneWidget);
    });
  });

  group('WarningLink — ouverture de la fenêtre', () {
    testWidgets(
      'le tap ouvre la fenêtre avec le titre et le corps du modal initial, '
      "sans case ni bouton d'acquittement",
      (WidgetTester tester) async {
        await tester.pumpWidget(_harness(const WarningLink()));

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningTitle), findsOneWidget);
        expect(find.text(initialWarningBody), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text(initialWarningButtonLabel), findsNothing);
        expect(find.byKey(warningWindowCloseButtonKey), findsOneWidget);
      },
    );

    testWidgets('sans extraText, aucune phrase propre ne complète le texte '
        "général (arbitrage du 2026-09-23 : « sans date, aucun encart »)", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      expect(find.byKey(warningWindowExtraTextKey), findsNothing);
    });

    testWidgets('avec extraText, la phrase propre apparaît SOUS le corps '
        'général', (WidgetTester tester) async {
      const String extra = 'Mesure brute du 27/08/2026 à 10:00…';
      await tester.pumpWidget(_harness(const WarningLink(extraText: extra)));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      expect(find.text(extra), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(initialWarningBody)).dy,
        lessThan(tester.getTopLeft(find.byKey(warningWindowExtraTextKey)).dy),
        reason: 'la phrase propre se lit SOUS le texte général',
      );
    });

    testWidgets('la fermeture referme la fenêtre', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.tap(find.byKey(warningWindowCloseButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsNothing);
    });

    testWidgets("la fermeture porte une action tap pour le lecteur d'écran", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(
        find.byKey(warningWindowCloseButtonKey),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsNothing);

      handle.dispose();
    });

    testWidgets('forme une région sémantique repérable par sa clé', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      expect(find.byKey(warningWindowRegionKey), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(warningWindowRegionKey)),
        isNotNull,
      );

      handle.dispose();
    });
  });

  group('WarningWindow — taille minimale de fenêtre Windows (800 × 700, '
      'décision 8 amendée le 2026-09-23, K3) à 200 % de police', () {
    testWidgets(
      'le texte défile au lieu d\'être tronqué, "Fermer" reste atteignable',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const String extra = 'Mesure brute du 27/08/2026 à 10:00…';
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _harness(const WarningLink(extraText: extra)),
          ),
        );

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        // Aucune exception de rendu (dépassement, `RenderFlex
        // overflowed`…) : le texte défile au lieu d'être tronqué.
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byKey(warningWindowCloseButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(warningWindowCloseButtonKey));
        await tester.pumpAndSettle();

        expect(find.text(initialWarningTitle), findsNothing);
      },
    );
  });

  group('WarningWindow — clavier et focus (relecture du 2026-09-23)', () {
    testWidgets('Tab puis Entrée sur « Fermer » referme la fenêtre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsNothing);
    });

    testWidgets('Échap referme la fenêtre', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsNothing);
    });

    testWidgets(
      'après fermeture, le focus revient dans le sous-arbre du contrôle',
      (WidgetTester tester) async {
        await tester.pumpWidget(_harness(const WarningLink()));

        // Ouverture au clavier : le contrôle porte le focus avant que la
        // fenêtre ne s'ouvre, comme un usager au clavier le ferait.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(initialWarningTitle), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(initialWarningTitle), findsNothing);

        expect(
          _hasFocusWithin(tester, find.byKey(warningLinkKey)),
          isTrue,
          reason:
              'le focus ne doit pas se perdre à la fermeture : il revient '
              'sur le contrôle qui a ouvert la fenêtre',
        );
      },
    );
  });
}
