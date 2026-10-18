// Le bas de la carte (`MapBottom`, `S4` et `D2` d'Ergonomie, spec § 5.4),
// depuis `D8` (arbitrage 24 du commanditaire, 2026-10-18) : la COLONNE (à
// partir de 600 px) peut céder en deçà des quatre tailles — ses cinq boutons
// défilent, ancrés en bas, au-dessus de l'attribution IGN, qui reste entière
// et affichée ; la RANGÉE (téléphone) ne cède jamais.
//
// Ce que ces tests prouvent :
// - les deux hauteurs intrinsèques de la colonne (note d'architecture, 1) :
//   repliée = l'écart et l'attribution, entière = boutons compris ; la rangée
//   n'en dit qu'une ;
// - posée sous sa hauteur entière, la colonne ne déborde pas : ses boutons
//   défilent, « recentrer » et l'attribution restent en vue au repos, et
//   « Favoris » s'amène en vue en glissant ou par le focus ;
// - son défilement ne prend pas les gestes posés hors des boutons (ils vont à
//   la carte dessous, comme avant).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_bottom.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/android_platform.dart';
import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// La carte témoin sous le bas : elle compte les taps qui lui arrivent.
const Key _carteKey = Key('bas-carte-temoin');

/// Pose le bas en bas à droite d'un écran de 640 × 360, au-dessus d'une carte
/// témoin, borné à [hauteur] s'il y en a une.
Future<void> _poser(
  WidgetTester tester, {
  required bool compact,
  double? hauteur,
  VoidCallback? surLaCarte,
}) async {
  tester.view.physicalSize = const Size(640, 360);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  void rien() {}
  final Widget bas = MapBottom(
    compact: compact,
    onOpenFilters: rien,
    onOpenFavorites: rien,
    filterActive: false,
    onZoomIn: rien,
    onZoomOut: rien,
    onRecenter: rien,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                key: _carteKey,
                behavior: HitTestBehavior.opaque,
                onTap: surLaCarte,
                child: const SizedBox.expand(),
              ),
            ),
            // La rangée prend la largeur de la carte (elle porte un
            // `Spacer`) ; la colonne, la sienne, à droite.
            Positioned(
              left: compact ? 8 : null,
              right: 8,
              bottom: 8,
              child: hauteur == null
                  ? bas
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: hauteur),
                      child: bas,
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderBox _boite(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(MapBottom));

/// Le rectangle de [f] est-il entier dans [r] ?
bool _entier(Rect f, Rect r) =>
    f.left >= r.left - 0.5 &&
    f.top >= r.top - 0.5 &&
    f.right <= r.right + 0.5 &&
    f.bottom <= r.bottom + 0.5;

void main() {
  group('D8 — la colonne du bas défile au-dessus de son attribution '
      '(arbitrage 24)', () {
    testWidgetsOnWindows('la colonne dit deux hauteurs : repliée, l’écart et '
        'l’attribution ; entière, ses cinq boutons compris', (
      WidgetTester tester,
    ) async {
      await _poser(tester, compact: false);

      final RenderBox boite = _boite(tester);
      final double largeur = boite.size.width;
      final double attribution = tester
          .getRect(find.byType(IgnAttributionBadge))
          .height;
      expect(boite.getMinIntrinsicHeight(largeur), 8 + attribution);
      expect(boite.getMaxIntrinsicHeight(largeur), boite.size.height);
      expect(
        boite.size.height,
        greaterThan(8 + attribution + 5 * minimumTapTarget),
      );
    });

    testWidgetsOnAndroid('Android : la rangée ne se replie pas — une seule '
        'hauteur', (WidgetTester tester) async {
      await _poser(tester, compact: true);

      final RenderBox boite = _boite(tester);
      final double largeur = boite.size.width;
      expect(
        boite.getMinIntrinsicHeight(largeur),
        boite.getMaxIntrinsicHeight(largeur),
      );
    });

    testWidgetsOnWindows('posée sous sa hauteur entière : aucun débordement ; '
        'ancrée en bas, « recentrer » et l’attribution en vue au repos ; '
        '« Favoris » amené en vue en glissant, puis par le focus', (
      WidgetTester tester,
    ) async {
      await _poser(tester, compact: false, hauteur: 150);

      expect(tester.takeException(), isNull);
      final Rect boite = tester.getRect(find.byType(MapBottom));
      expect(boite.height, lessThanOrEqualTo(150));
      final Rect attribution = tester.getRect(find.byType(IgnAttributionBadge));
      expect(_entier(attribution, boite), isTrue, reason: '$attribution');
      expect(attribution.bottom, moreOrLessEquals(boite.bottom));
      expect(find.byType(IgnAttributionBadge).hitTestable(), findsOneWidget);
      expect(find.byKey(mapRecenterButtonKey).hitTestable(), findsOneWidget);
      expect(find.byKey(mapFavoritesButtonKey).hitTestable(), findsNothing);

      // Glisser vers le bas sur un bouton fait défiler la colonne.
      await tester.drag(find.byKey(mapRecenterButtonKey), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(mapFavoritesButtonKey).hitTestable(), findsOneWidget);
      expect(find.byType(IgnAttributionBadge).hitTestable(), findsOneWidget);

      // Remis au repos, le focus l'amène en vue, entier.
      await _poser(tester, compact: false, hauteur: 150);
      for (
        int i = 0;
        i < 8 && !focusedWithin(tester, find.byKey(mapFavoritesButtonKey));
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(focusedWithin(tester, find.byKey(mapFavoritesButtonKey)), isTrue);
      final Rect favoris = tester.getRect(find.byKey(mapFavoritesButtonKey));
      expect(
        _entier(favoris, tester.getRect(find.byType(MapBottom))),
        isTrue,
        reason: '« Favoris » $favoris',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgetsOnWindows('son défilement ne prend pas les gestes posés hors '
        'des boutons : un tap dans l’écart entre « + » et « − », ou à gauche '
        'des boutons, va à la carte', (WidgetTester tester) async {
      int taps = 0;
      await _poser(
        tester,
        compact: false,
        hauteur: 150,
        surLaCarte: () => taps++,
      );

      final Rect plus = tester.getRect(find.byKey(mapZoomInButtonKey));
      final Rect moins = tester.getRect(find.byKey(mapZoomOutButtonKey));
      final Rect haut = plus.top < moins.top ? plus : moins;
      final Rect bas = plus.top < moins.top ? moins : plus;
      expect(bas.top - haut.bottom, greaterThanOrEqualTo(mapControlsSpacing));
      await tester.tapAt(Offset(haut.center.dx, (haut.bottom + bas.top) / 2));
      await tester.tapAt(Offset(haut.left - 4, haut.center.dy));
      await tester.pumpAndSettle();
      expect(taps, 2);
    });
  });
}
