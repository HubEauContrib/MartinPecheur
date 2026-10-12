// Verrouille [FavoriteStarButton] et [FavoriteWriteFailedNotice] (`S4` de T3) :
// l'étoile partagée des deux fiches, lisible sans la couleur (critère 14),
// atteinte par Tab, basculée par Entrée ou Espace, cible de 44 (48 sur
// Android).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';

import '../../support/android_platform.dart';
import '../../support/windows_platform.dart';

Future<void> _pump(
  WidgetTester tester,
  FavoriteStar star,
  VoidCallback onToggle,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FavoriteStarButton(star: star, onToggle: onToggle),
        ),
      ),
    ),
  );
}

Color? _ringColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(KeyboardFocusRing),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).border?.top.color;
}

void main() {
  group('FavoriteStarButton — active', () {
    testWidgetsOnWindows(
      'étoile vide : Icons.star_border, « Ajouter aux favoris », bouton '
      'actif, un tap appelle onToggle une fois',
      (WidgetTester tester) async {
        int toggles = 0;
        await _pump(
          tester,
          const FavoriteStar(filled: false, enabled: true),
          () => toggles++,
        );

        expect(find.byIcon(Icons.star_border), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(addFavoriteLabel, 'Ajouter aux favoris');
        expect(
          tester.getSemantics(find.byKey(favoriteStarButtonKey)),
          matchesSemantics(
            label: 'Ajouter aux favoris',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();

        expect(toggles, 1);
      },
    );

    testWidgetsOnWindows(
      'étoile pleine : Icons.star, « Retirer des favoris »',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const FavoriteStar(filled: true, enabled: true),
          () {},
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.star_border), findsNothing);
        expect(removeFavoriteLabel, 'Retirer des favoris');
        expect(
          tester.getSemantics(find.byKey(favoriteStarButtonKey)),
          matchesSemantics(
            label: 'Retirer des favoris',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      'sans la couleur : même teinte pleine ou vide, libellés différents',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const FavoriteStar(filled: false, enabled: true),
          () {},
        );
        final Color? empty = tester.widget<Icon>(find.byType(Icon)).color;

        await _pump(
          tester,
          const FavoriteStar(filled: true, enabled: true),
          () {},
        );
        final Color? full = tester.widget<Icon>(find.byType(Icon)).color;

        expect(empty, isNotNull);
        expect(full, empty);
        expect(removeFavoriteLabel, isNot(addFavoriteLabel));
      },
    );

    testWidgetsOnWindows(
      'Tab atteint le bouton, le contour de focus apparaît, Entrée puis '
      'Espace appellent chacun onToggle',
      (WidgetTester tester) async {
        int toggles = 0;
        await _pump(
          tester,
          const FavoriteStar(filled: false, enabled: true),
          () => toggles++,
        );
        expect(_ringColor(tester), Colors.transparent);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(_ringColor(tester), focusRingColor);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggles, 1);

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggles, 2);
      },
    );

    testWidgetsOnWindows('la cible mesure 44 x 44', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FavoriteStar(filled: false, enabled: true),
        () {},
      );

      expect(
        tester.getSize(find.byKey(favoriteStarButtonKey)),
        const Size(44, 44),
      );
    });

    testWidgetsOnAndroid('Android : la cible mesure 48 x 48', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const FavoriteStar(filled: false, enabled: true),
        () {},
      );

      expect(
        tester.getSize(find.byKey(favoriteStarButtonKey)),
        const Size(48, 48),
      );
    });
  });

  group('FavoriteStarButton — inactive', () {
    testWidgetsOnWindows(
      'tap, Entrée et Espace n appellent pas onToggle ; la forme est gardée ; '
      'état désactivé annoncé ; reste focalisable (le focus ne se perd pas '
      'pendant une écriture)',
      (WidgetTester tester) async {
        int toggles = 0;
        await _pump(
          tester,
          const FavoriteStar(filled: true, enabled: false),
          () => toggles++,
        );

        expect(find.byIcon(Icons.star), findsOneWidget);

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggles, 0);

        // `hasEnabledState` sans `isEnabled` : le lecteur d'écran annonce
        // « indisponible ».
        expect(
          tester.getSemantics(find.byKey(favoriteStarButtonKey)),
          matchesSemantics(
            label: 'Retirer des favoris',
            isButton: true,
            hasEnabledState: true,
          ),
        );

        // Inactive, elle reste un arrêt de tabulation : Tab l'atteint, le
        // contour apparaît, mais Entrée et Espace ne font rien.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_ringColor(tester), focusRingColor);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(toggles, 0);
      },
    );

    // Le ViewModel rend `enabled: false` pendant toute écriture. Un nœud qui
    // cesserait d'être focalisable à cet instant perdrait le focus, et Flutter
    // ne le rendrait pas : un usager au clavier perdrait l'étoile à chaque
    // Entrée.
    testWidgetsOnWindows(
      'focus sur l etoile, reconstruction inactive puis active : le focus '
      'reste sur l etoile, et Entree rebascule',
      (WidgetTester tester) async {
        int toggles = 0;
        await _pump(
          tester,
          const FavoriteStar(filled: false, enabled: true),
          () => toggles++,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_ringColor(tester), focusRingColor);

        await _pump(
          tester,
          const FavoriteStar(filled: false, enabled: false),
          () => toggles++,
        );
        await tester.pump();
        expect(_ringColor(tester), focusRingColor);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggles, 0);

        await _pump(
          tester,
          const FavoriteStar(filled: true, enabled: true, writeFailed: true),
          () => toggles++,
        );
        await tester.pump();
        expect(_ringColor(tester), focusRingColor);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(toggles, 1);
      },
    );
  });

  group('FavoriteWriteFailedNotice', () {
    testWidgetsOnWindows('échec d ajout : le texte exact, en région vivante', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FavoriteWriteFailedNotice(favoriteWriteFailedText),
          ),
        ),
      );

      expect(favoriteWriteFailedText, "Le favori n'a pas pu être enregistré.");
      final Finder text = find.text("Le favori n'a pas pu être enregistré.");
      expect(text, findsOneWidget);
      expect(
        tester
            .getSemantics(text)
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });

    testWidgetsOnWindows('échec de retrait : le texte exact', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FavoriteWriteFailedNotice(favoriteRemoveFailedText),
          ),
        ),
      );

      expect(favoriteRemoveFailedText, "Le favori n'a pas pu être retiré.");
      expect(find.text("Le favori n'a pas pu être retiré."), findsOneWidget);
    });
  });
}
