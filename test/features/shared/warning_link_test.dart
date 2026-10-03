// Verrouille le contrôle d'avertissement partagé (`W3c`, arbitrage du
// commanditaire du 2026-09-23) : icône + libellé « Avertissement », cible
// tactile ≥ 44 pt, atteignable et activable au clavier (Tab + Entrée),
// action de tap exposée au lecteur d'écran, ouvre la fenêtre avec le texte
// général du modal initial et, quand elle est fournie, la phrase propre à
// l'écran appelant SOUS ce texte général. Depuis `S1` (T2), la fenêtre porte
// aussi le lien « D'où vient cette donnée ? » vers l'écran des sources.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/shared/data_sources_view.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
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

  group("WarningWindow — lien « D'où vient cette donnée ? » (T2, S1)", () {
    testWidgets(
      "la fenêtre porte le lien libellé dataSourcesTitle, avec ou sans "
      "phrase propre à l'écran",
      (WidgetTester tester) async {
        for (final String? extra in <String?>[null, 'Mesure brute du 27/08…']) {
          await tester.pumpWidget(_harness(WarningLink(extraText: extra)));
          await tester.tap(find.byKey(warningLinkKey));
          await tester.pumpAndSettle();

          expect(find.byKey(warningWindowSourcesLinkKey), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(warningWindowSourcesLinkKey),
              matching: find.text(dataSourcesTitle),
            ),
            findsOneWidget,
          );

          await tester.tap(find.byKey(warningWindowCloseButtonKey));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('le lien se lit sous le texte, au-dessus de « Fermer »', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const WarningLink(extraText: 'Mesure brute du 27/08…')),
      );
      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      final double link = tester
          .getTopLeft(find.byKey(warningWindowSourcesLinkKey))
          .dy;
      expect(
        link,
        greaterThan(
          tester.getBottomLeft(find.byKey(warningWindowExtraTextKey)).dy - 1,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(warningWindowCloseButtonKey)).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(warningWindowSourcesLinkKey)).dy - 1,
        ),
      );
    });

    testWidgets("le lien ouvre l'écran des sources, par-dessus la fenêtre", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));
      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(warningWindowSourcesLinkKey));
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsOneWidget);
    });

    testWidgets(
      "le retour ramène à la fenêtre d'avertissement, telle qu'elle était : "
      'texte et phrase propre inchangés',
      (WidgetTester tester) async {
        const String extra = 'Mesure brute du 27/08/2026 à 10:00…';
        await tester.pumpWidget(_harness(const WarningLink(extraText: extra)));
        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(warningWindowSourcesLinkKey));
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(DataSourcesView), findsNothing);
        expect(find.byKey(warningWindowRegionKey), findsOneWidget);
        expect(find.text(initialWarningBody), findsOneWidget);
        expect(find.text(extra), findsOneWidget);
      },
    );

    testWidgets("Échap referme d'abord l'écran des sources, puis la fenêtre", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));
      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(warningWindowSourcesLinkKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DataSourcesView), findsNothing);
      expect(find.byKey(warningWindowRegionKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(warningWindowRegionKey), findsNothing);
    });

    testWidgets('le lien mesure au moins minimumTapTarget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));
      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(find.byKey(warningWindowSourcesLinkKey));
      expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
    });

    testWidgets(
      'à 200 % de police, fenêtre Windows minimale : le lien défile, reste '
      'atteignable et ouvre l\'écran',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _harness(
              const WarningLink(extraText: 'Mesure brute du 27/08/2026…'),
            ),
          ),
        );
        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(warningWindowSourcesLinkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(warningWindowSourcesLinkKey));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DataSourcesView), findsOneWidget);
      },
    );
  });

  group('WarningWindow — taille minimale de fenêtre Windows (800 × 740, '
      'décision 8 amendée le 2026-09-23, K3) à 200 % de police', () {
    testWidgets(
      'le texte défile au lieu d\'être tronqué, "Fermer" reste atteignable',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 740);
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
    // Depuis `S1`, le lien vers les sources précède « Fermer » dans l'ordre
    // de lecture : il est le PREMIER arrêt de tabulation, « Fermer » le
    // second. `skipOffstage: false` : un titre caché sous l'écran des sources
    // ne doit pas passer pour une fenêtre fermée.
    testWidgets('Tab puis Entrée sur le lien ouvre l\'écran des sources, '
        'sans fermer la fenêtre', (WidgetTester tester) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsOneWidget);
      expect(
        find.text(initialWarningTitle, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Tab, Tab puis Entrée sur « Fermer » referme la fenêtre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const WarningLink()));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsNothing);
      expect(find.text(initialWarningTitle, skipOffstage: false), findsNothing);
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
