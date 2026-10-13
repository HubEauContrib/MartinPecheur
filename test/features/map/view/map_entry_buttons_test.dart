// Verrouille `MapRoundButton` (extrait de `MapControls`, `F10a` de T3) et
// `MapEntryButtons` : le bouton « Filtres » et sa forme active, puis le bouton
// « Favoris » posé au-dessus (`S10` de T3). Widgets de CONTENU purs — ni
// `MapViewModel` ni caméra ; le branchement dans la carte est vérifié avec
// `F10b` (« Filtres ») et `S10` (« Favoris »).
//
// La forme active se lit sans se fier à la couleur seule (`04-ui.md § 3`) :
// l'icône change (`filter_alt` pleine au lieu de `filter_list`), le fond
// devient plein, une marque ronde se pose au coin.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart'
    show mapControlsSpacing;
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_round_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

const Key _roundButtonKey = Key('test-round-button');

void main() {
  Future<void> pumpRound(
    WidgetTester tester, {
    required VoidCallback? onTap,
    bool? filled,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: filled == null
                ? MapRoundButton(
                    semanticsKey: _roundButtonKey,
                    icon: Icons.add,
                    label: 'Un bouton',
                    onTap: onTap,
                  )
                : MapRoundButton(
                    semanticsKey: _roundButtonKey,
                    icon: Icons.add,
                    label: 'Un bouton',
                    onTap: onTap,
                    filled: filled,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpEntries(
    WidgetTester tester, {
    VoidCallback? onOpenFilters,
    VoidCallback? onOpenFavorites,
    bool filterActive = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: MapEntryButtons(
              onOpenFilters: onOpenFilters ?? () {},
              onOpenFavorites: onOpenFavorites,
              filterActive: filterActive,
            ),
          ),
        ),
      ),
    );
  }

  // Le focus courant est-il porté par un élément du sous-arbre de [ancestor] ?
  // Même construction que `map_keyboard_test.dart` : [Focus.of] ne cherche que
  // des ANCÊTRES, jamais l'inverse.
  bool focusedWithin(WidgetTester tester, Finder ancestor) {
    final BuildContext? focusedContext =
        FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) {
      return false;
    }
    bool found = false;
    void visit(Element element) {
      if (element == focusedContext) {
        found = true;
      }
      element.visitChildren(visit);
    }

    visit(tester.element(ancestor));
    return found;
  }

  // Le disque du bouton : le `DecoratedBox` rond qui porte une couleur de
  // fond.
  Finder disc(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((Widget w) {
      if (w is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = w.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color != null;
    }),
  );

  Color discColor(WidgetTester tester, Key key) {
    final DecoratedBox box = tester.widget<DecoratedBox>(disc(key));
    return (box.decoration as BoxDecoration).color!;
  }

  Color iconColor(WidgetTester tester, Key key) {
    return tester
        .widget<Icon>(
          find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
        )
        .color!;
  }

  // Le liséré blanc de 2 px posé entre le fond plein et l'anneau de focus.
  Finder whiteSeparation(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((Widget w) {
      if (w is! DecoratedBox) {
        return false;
      }
      final Decoration decoration = w.decoration;
      if (decoration is! BoxDecoration || decoration.shape != BoxShape.circle) {
        return false;
      }
      final BoxBorder? border = decoration.border;
      return border is Border &&
          border.top.color == Colors.white &&
          border.top.width == 2;
    }),
  );

  group('MapRoundButton', () {
    testWidgetsOnWindows('filled: true : fond noir et icône blanche', (
      WidgetTester tester,
    ) async {
      await pumpRound(tester, onTap: () {}, filled: true);

      expect(discColor(tester, _roundButtonKey), Colors.black);
      expect(iconColor(tester, _roundButtonKey), Colors.white);
    });

    testWidgetsOnWindows('filled omis : fond blanc et icône noire', (
      WidgetTester tester,
    ) async {
      await pumpRound(tester, onTap: () {});

      expect(discColor(tester, _roundButtonKey), Colors.white);
      expect(iconColor(tester, _roundButtonKey), Colors.black);
    });

    testWidgetsOnWindows('filled: true : un liséré blanc de 2 px sépare le '
        "fond de l'anneau de focus, à l'intérieur de la bande qu'il couvre", (
      WidgetTester tester,
    ) async {
      await pumpRound(tester, onTap: () {}, filled: true);

      expect(whiteSeparation(_roundButtonKey), findsOneWidget);
      final Rect button = tester.getRect(find.byKey(_roundButtonKey));
      final Rect separation = tester.getRect(whiteSeparation(_roundButtonKey));
      // L'anneau de focus se peint par-dessus les `focusRingWidth` pixels
      // du bord : le liséré commence juste en dessous.
      expect(separation.left - button.left, focusRingWidth);
      expect(button.right - separation.right, focusRingWidth);
      expect(separation.top - button.top, focusRingWidth);
      expect(button.bottom - separation.bottom, focusRingWidth);
    });

    testWidgetsOnWindows('fond blanc : aucun liséré blanc de séparation', (
      WidgetTester tester,
    ) async {
      await pumpRound(tester, onTap: () {});

      expect(whiteSeparation(_roundButtonKey), findsNothing);
    });

    testWidgetsOnWindows(
      'onTap nul : Semantics.enabled faux et hors de la tabulation',
      (WidgetTester tester) async {
        await pumpRound(tester, onTap: null);

        final Semantics semantics = tester.widget<Semantics>(
          find.byKey(_roundButtonKey),
        );
        expect(semantics.properties.enabled, isFalse);
        final KeyboardFocusRing ring = tester.widget<KeyboardFocusRing>(
          find.descendant(
            of: find.byKey(_roundButtonKey),
            matching: find.byType(KeyboardFocusRing),
          ),
        );
        expect(ring.canRequestFocus, isFalse);
      },
    );
  });

  group('MapEntryButtons : « Filtres » inactif', () {
    testWidgetsOnWindows(
      'nœud « Filtres », bouton ; icône filter_list ; aucune marque',
      (WidgetTester tester) async {
        await pumpEntries(tester);

        final Semantics semantics = tester.widget<Semantics>(
          find.byKey(mapFiltersButtonKey),
        );
        expect(semantics.properties.label, 'Filtres');
        expect(semantics.properties.button, isTrue);
        expect(find.byIcon(Icons.filter_list), findsOneWidget);
        expect(find.byIcon(Icons.filter_alt), findsNothing);
        expect(find.byKey(mapFiltersActiveMarkKey), findsNothing);
        expect(discColor(tester, mapFiltersButtonKey), Colors.white);
      },
    );
  });

  group('MapEntryButtons : « Filtres » actif', () {
    testWidgetsOnWindows(
      'libellé « Filtres — un filtre est actif » ; icône filter_alt ; marque '
      'présente ; fond noir',
      (WidgetTester tester) async {
        await pumpEntries(tester, filterActive: true);

        final Semantics semantics = tester.widget<Semantics>(
          find.byKey(mapFiltersButtonKey),
        );
        expect(semantics.properties.label, 'Filtres — un filtre est actif');
        expect(semantics.properties.button, isTrue);
        expect(find.byIcon(Icons.filter_alt), findsOneWidget);
        expect(find.byIcon(Icons.filter_list), findsNothing);
        expect(find.byKey(mapFiltersActiveMarkKey), findsOneWidget);
        expect(discColor(tester, mapFiltersButtonKey), Colors.black);
        expect(whiteSeparation(mapFiltersButtonKey), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'la marque : disque noir de 12 px à liseré blanc de 2 px, au coin haut '
      'droit, exclue de la sémantique',
      (WidgetTester tester) async {
        await pumpEntries(tester, filterActive: true);

        final Rect mark = tester.getRect(find.byKey(mapFiltersActiveMarkKey));
        final Rect button = tester.getRect(find.byKey(mapFiltersButtonKey));
        expect(mark.size, const Size(12, 12));
        expect(mark.right, button.right);
        expect(mark.top, button.top);

        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.byKey(mapFiltersActiveMarkKey),
        );
        final BoxDecoration decoration = box.decoration as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color, Colors.black);
        final Border border = decoration.border! as Border;
        expect(border.top.color, Colors.white);
        expect(border.top.width, 2);

        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is ExcludeSemantics &&
                w.excluding &&
                w.child?.key == mapFiltersActiveMarkKey,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsOnWindows('un tap sur la marque atteint le bouton', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpEntries(
        tester,
        onOpenFilters: () => calls++,
        filterActive: true,
      );

      // La marque est inerte au pointeur : le tap la traverse, c'est ce
      // qu'on affirme (d'où `warnIfMissed: false`).
      await tester.tap(
        find.byKey(mapFiltersActiveMarkKey),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(calls, 1);
    });
  });

  group('MapEntryButtons : activation', () {
    testWidgetsOnWindows('un tap appelle onOpenFilters UNE fois', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpEntries(tester, onOpenFilters: () => calls++);

      await tester.tap(find.byKey(mapFiltersButtonKey));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgetsOnWindows('Entrée, bouton focalisé : UNE fois', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpEntries(tester, onOpenFilters: () => calls++);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(calls, 1);
    });

    testWidgetsOnWindows('Espace, bouton focalisé : UNE fois', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpEntries(tester, onOpenFilters: () => calls++);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(calls, 1);
    });
  });

  group('MapEntryButtons : taille', () {
    testWidgetsOnWindows(
      'le bouton mesure minimumTapTargetFor(windows) de côté',
      (WidgetTester tester) async {
        await pumpEntries(tester);

        final Size size = tester.getSize(find.byKey(mapFiltersButtonKey));
        expect(size.width, minimumTapTargetFor(TargetPlatform.windows));
        expect(size.height, minimumTapTargetFor(TargetPlatform.windows));
      },
    );

    testWidgetsOnAndroid(
      'Android : le bouton mesure minimumTapTargetFor(android) de côté',
      (WidgetTester tester) async {
        await pumpEntries(tester, filterActive: true);

        final Size size = tester.getSize(find.byKey(mapFiltersButtonKey));
        expect(size.width, minimumTapTargetFor(TargetPlatform.android));
        expect(size.height, minimumTapTargetFor(TargetPlatform.android));
      },
    );

    testWidgetsOnWindows(
      'la marque ne grandit pas le groupe : même taille, actif ou non',
      (WidgetTester tester) async {
        await pumpEntries(tester);
        final Size inactive = tester.getSize(find.byType(MapEntryButtons));
        await pumpEntries(tester, filterActive: true);
        final Size active = tester.getSize(find.byType(MapEntryButtons));

        expect(active, inactive);
      },
    );
  });

  // « Favoris » (`S10` de T3, arbitrage 8 du cadrage) : le second bouton du
  // groupe, AU-DESSUS de « Filtres ». `onOpenFavorites` nul : le bouton est
  // absent et le groupe est celui du lot 4.
  group('MapEntryButtons : « Favoris »', () {
    testWidgetsOnWindows(
      'posé : nœud « Favoris », bouton, icône étoile, fond blanc (jamais '
      'plein)',
      (WidgetTester tester) async {
        await pumpEntries(tester, onOpenFavorites: () {});

        expect(mapFavoritesLabel, 'Favoris');
        final Semantics semantics = tester.widget<Semantics>(
          find.byKey(mapFavoritesButtonKey),
        );
        expect(semantics.properties.label, 'Favoris');
        expect(semantics.properties.button, isTrue);
        expect(
          find.descendant(
            of: find.byKey(mapFavoritesButtonKey),
            matching: find.byIcon(Icons.star),
          ),
          findsOneWidget,
        );
        expect(discColor(tester, mapFavoritesButtonKey), Colors.white);
        expect(iconColor(tester, mapFavoritesButtonKey), Colors.black);
        expect(whiteSeparation(mapFavoritesButtonKey), findsNothing);
      },
    );

    testWidgetsOnWindows('un tap appelle onOpenFavorites UNE fois, et pas '
        'onOpenFilters', (WidgetTester tester) async {
      int favoris = 0;
      int filtres = 0;
      await pumpEntries(
        tester,
        onOpenFavorites: () => favoris++,
        onOpenFilters: () => filtres++,
      );

      await tester.tap(find.byKey(mapFavoritesButtonKey));
      await tester.pump();

      expect(favoris, 1);
      expect(filtres, 0);
    });

    testWidgetsOnWindows(
      'Tab atteint « Favoris » JUSTE AVANT « Filtres » ; Entrée l’appelle '
      'UNE fois',
      (WidgetTester tester) async {
        int favoris = 0;
        await pumpEntries(tester, onOpenFavorites: () => favoris++);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          focusedWithin(tester, find.byKey(mapFavoritesButtonKey)),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(favoris, 1);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusedWithin(tester, find.byKey(mapFiltersButtonKey)), isTrue);
        expect(
          focusedWithin(tester, find.byKey(mapFavoritesButtonKey)),
          isFalse,
        );
      },
    );

    testWidgetsOnWindows('Espace, bouton focalisé : UNE fois', (
      WidgetTester tester,
    ) async {
      int favoris = 0;
      await pumpEntries(tester, onOpenFavorites: () => favoris++);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(favoris, 1);
    });

    testWidgetsOnWindows(
      'au-dessus de « Filtres » : même abscisse, séparé de lui par '
      'mapControlsSpacing ; taille minimumTapTargetFor(windows) de côté',
      (WidgetTester tester) async {
        await pumpEntries(tester, onOpenFavorites: () {});

        final Rect favoris = tester.getRect(find.byKey(mapFavoritesButtonKey));
        final Rect filtres = tester.getRect(find.byKey(mapFiltersButtonKey));
        expect(favoris.right, filtres.right);
        expect(favoris.left, filtres.left);
        expect(favoris.bottom + mapControlsSpacing, filtres.top);
        expect(favoris.size, filtres.size);
        expect(
          favoris.size,
          Size.square(minimumTapTargetFor(TargetPlatform.windows)),
        );
        expect(favoris.size, const Size(44, 44));
      },
    );

    testWidgetsOnAndroid(
      'Android : « Favoris » mesure minimumTapTargetFor(android) de côté, '
      '48 × 48',
      (WidgetTester tester) async {
        await pumpEntries(tester, onOpenFavorites: () {});

        final Size size = tester.getSize(find.byKey(mapFavoritesButtonKey));
        expect(size, Size.square(minimumTapTargetFor(TargetPlatform.android)));
        expect(size, const Size(48, 48));
      },
    );

    testWidgetsOnWindows(
      'onOpenFavorites nul : aucun bouton « Favoris » ; « Filtres » est à la '
      'place qu’il avait au lot 4 (le groupe n’est que lui)',
      (WidgetTester tester) async {
        await pumpEntries(tester);

        expect(find.byKey(mapFavoritesButtonKey), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
        final Rect groupe = tester.getRect(find.byType(MapEntryButtons));
        final Rect filtres = tester.getRect(find.byKey(mapFiltersButtonKey));
        expect(filtres, groupe);
        expect(groupe.size, const Size(44, 44));
        expect(groupe.bottomRight, const Offset(800, 600));
      },
    );
  });
}
