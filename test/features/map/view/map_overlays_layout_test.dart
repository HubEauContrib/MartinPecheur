// La mise en page des surcouches de la carte (`F10b` de T3, arbitrage du
// commanditaire du 2026-10-12, « La légende défile ») : `MapOverlaysLayout`,
// le délégué, seul ; puis l'ordre dans lequel `buildMapOverlays` lui donne ses
// enfants — c'est l'ordre de peinture, donc celui du toucher.
//
// Ce que ces tests prouvent :
// - la colonne du bas à droite est mise en page d'abord, celle du haut reçoit
//   la hauteur qui reste au-dessus d'elle, moins la marge ;
// - sur une surface trop courte, la colonne du bas cède jusqu'à laisser
//   `topMinHeight` à celle du haut (décision de la boucle principale du
//   2026-10-12, réversible) ;
// - les emplacements `left` et `middle` gardent toute la surface, et sont
//   facultatifs ;
// - l'ordre de peinture est celui d'avant `F10b` : colonne du haut à droite,
//   puis colonne de gauche, puis zone des fiches, puis colonne du bas à
//   droite. Là où le contrôle « ⚠ Avertissement » et une puce d'échelle se
//   recoupent, c'est la puce qui reçoit le tap.
//
// Police de test de Flutter (un carré par glyphe) : les largeurs ne sont pas
// celles d'un écran. Le recoupement du dernier cas n'existe qu'avec elle, à
// 600 de large et 200 % ; en Roboto le contrôle et les puces ne se recoupent
// pas à cette taille (`map_overlays_phone_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/map_overlays_layout.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';

const Key _left = Key('emplacement-left');
const Key _top = Key('emplacement-top');
const Key _middle = Key('emplacement-middle');
const Key _bottom = Key('emplacement-bottom');

const double _padding = 8;
const double _topMinHeight = 44;
const Size _surface = Size(800, 740);

void _fenetre(WidgetTester tester, Size taille) {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pose le délégué seul sur toute la fenêtre ([_surface]). La colonne du haut
/// et celle du bas demandent [hauteurHaut] et [hauteurBas] : un `SizedBox` se
/// plie à la hauteur maximale qu'on lui offre.
Future<void> _poser(
  WidgetTester tester, {
  required double hauteurHaut,
  required double hauteurBas,
  bool avecGaucheEtMilieu = true,
}) async {
  _fenetre(tester, _surface);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: CustomMultiChildLayout(
        delegate: MapOverlaysLayout(
          padding: _padding,
          topMinHeight: _topMinHeight,
        ),
        children: <Widget>[
          LayoutId(
            id: MapOverlaySlot.top,
            child: SizedBox(key: _top, width: 100, height: hauteurHaut),
          ),
          if (avecGaucheEtMilieu)
            LayoutId(
              id: MapOverlaySlot.left,
              child: const SizedBox.expand(key: _left),
            ),
          if (avecGaucheEtMilieu)
            LayoutId(
              id: MapOverlaySlot.middle,
              child: const SizedBox.expand(key: _middle),
            ),
          LayoutId(
            id: MapOverlaySlot.bottom,
            child: SizedBox(key: _bottom, width: 50, height: hauteurBas),
          ),
        ],
      ),
    ),
  );
}

/// Les emplacements de la mise en page, dans l'ordre où `buildMapOverlays`
/// les donne : l'ordre de peinture.
List<MapOverlaySlot> _emplacements(WidgetTester tester) => <MapOverlaySlot>[
  for (final LayoutId enfant in tester.widgetList<LayoutId>(
    find.byType(LayoutId),
  ))
    if (enfant.id case final MapOverlaySlot emplacement) emplacement,
];

Future<void> _poserLesSurcouches(
  WidgetTester tester,
  Size taille, {
  double textScale = 1,
  bool avecFiche = false,
  void Function(MapScaleKind kind)? onSelect,
}) async {
  _fenetre(tester, taille);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: buildMapOverlays(
            scale: MapScaleKind.ecoulement,
            onSelect: onSelect ?? (MapScaleKind kind) {},
            onWiden: () {},
            error: null,
            stations: const <StationPoint>[],
            ondeObservations: const <OndeStationCode, OndeObservation>{},
            ondeUnreadableRows: 0,
            filterHidesEverything: false,
            onClearFilters: () {},
            filterActive: false,
            onOpenFilters: () {},
            onZoomIn: () {},
            onZoomOut: () {},
            onRecenter: () {},
            onToggleDesignationMode: () {},
            stationSheet: avecFiche
                ? const SizedBox(width: 200, height: 40)
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MapOverlaysLayout — le délégué seul', () {
    testWidgetsOnWindows('les deux colonnes tiennent : celle du bas est en bas '
        'à droite à la marge, celle du haut en haut à droite à la marge, '
        'chacune à sa hauteur', (WidgetTester tester) async {
      await _poser(tester, hauteurHaut: 300, hauteurBas: 200);

      expect(
        tester.getRect(find.byKey(_bottom)),
        const Rect.fromLTRB(742, 532, 792, 732),
      );
      expect(
        tester.getRect(find.byKey(_top)),
        const Rect.fromLTRB(692, 8, 792, 308),
      );
    });

    testWidgetsOnWindows('la colonne du haut demande plus qu’il ne reste : '
        'elle s’arrête à la marge au-dessus de la colonne du bas', (
      WidgetTester tester,
    ) async {
      await _poser(tester, hauteurHaut: 5000, hauteurBas: 200);

      final Rect bas = tester.getRect(find.byKey(_bottom));
      final Rect haut = tester.getRect(find.byKey(_top));
      expect(bas, const Rect.fromLTRB(742, 532, 792, 732));
      expect(haut.top, _padding);
      expect(haut.bottom, bas.top - _padding);
    });

    testWidgetsOnWindows('la colonne du bas demande plus que la surface : elle '
        'cède, et laisse topMinHeight à la colonne du haut', (
      WidgetTester tester,
    ) async {
      await _poser(tester, hauteurHaut: 5000, hauteurBas: 5000);

      final Rect bas = tester.getRect(find.byKey(_bottom));
      final Rect haut = tester.getRect(find.byKey(_top));
      expect(haut.top, _padding);
      expect(haut.height, _topMinHeight);
      expect(bas.top, haut.bottom + _padding);
      expect(bas.bottom, _surface.height - _padding);
    });

    testWidgetsOnWindows('les emplacements left et middle prennent toute la '
        'surface', (WidgetTester tester) async {
      await _poser(tester, hauteurHaut: 300, hauteurBas: 200);

      expect(tester.getRect(find.byKey(_left)), Offset.zero & _surface);
      expect(tester.getRect(find.byKey(_middle)), Offset.zero & _surface);
    });

    testWidgetsOnWindows('sans left ni middle : aucune exception, les deux '
        'colonnes sont posées de même', (WidgetTester tester) async {
      await _poser(
        tester,
        hauteurHaut: 300,
        hauteurBas: 200,
        avecGaucheEtMilieu: false,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(_bottom)),
        const Rect.fromLTRB(742, 532, 792, 732),
      );
      expect(
        tester.getRect(find.byKey(_top)),
        const Rect.fromLTRB(692, 8, 792, 308),
      );
    });

    test('shouldRelayout : seulement quand la marge ou la hauteur gardée '
        'change', () {
      final MapOverlaysLayout reference = MapOverlaysLayout(
        padding: _padding,
        topMinHeight: _topMinHeight,
      );
      expect(
        MapOverlaysLayout(
          padding: _padding,
          topMinHeight: _topMinHeight,
        ).shouldRelayout(reference),
        isFalse,
      );
      expect(
        MapOverlaysLayout(
          padding: 12,
          topMinHeight: _topMinHeight,
        ).shouldRelayout(reference),
        isTrue,
      );
      expect(
        MapOverlaysLayout(
          padding: _padding,
          topMinHeight: 48,
        ).shouldRelayout(reference),
        isTrue,
      );
    });
  });

  group('buildMapOverlays — l’ordre de peinture des surcouches est celui '
      'd’avant F10b', () {
    testWidgetsOnWindows('disposition large (800 × 740), une fiche ouverte : '
        'colonne du haut à droite, puis colonne de gauche, puis zone des '
        'fiches, puis colonne du bas à droite', (WidgetTester tester) async {
      await _poserLesSurcouches(tester, _surface, avecFiche: true);

      expect(_emplacements(tester), <MapOverlaySlot>[
        MapOverlaySlot.top,
        MapOverlaySlot.left,
        MapOverlaySlot.middle,
        MapOverlaySlot.bottom,
      ]);
    });

    testWidgetsOnAndroid('Android : disposition compacte (360 × 640), une '
        'fiche ouverte : colonne du haut, puis zone des fiches, puis colonne '
        'du bas à droite', (WidgetTester tester) async {
      await _poserLesSurcouches(tester, const Size(360, 640), avecFiche: true);

      expect(_emplacements(tester), <MapOverlaySlot>[
        MapOverlaySlot.top,
        MapOverlaySlot.middle,
        MapOverlaySlot.bottom,
      ]);
    });

    testWidgetsOnWindows('à 600 × 740, police 200 % (police de test) : là où '
        'le contrôle « ⚠ Avertissement » et la puce « écoulement » se '
        'recoupent, le tap va à la puce — la colonne de gauche est peinte '
        'APRÈS celle de droite', (WidgetTester tester) async {
      final List<MapScaleKind> choisies = <MapScaleKind>[];
      await _poserLesSurcouches(
        tester,
        const Size(600, 740),
        textScale: 2,
        onSelect: choisies.add,
      );

      final Rect lien = tester.getRect(find.byType(WarningLink));
      final Rect puce = tester.getRect(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
      );
      final Rect commun = lien.intersect(puce);
      expect(
        commun.width > 0 && commun.height > 0,
        isTrue,
        reason: 'le cas suppose un recoupement : lien=$lien, puce=$puce',
      );

      await tester.tapAt(commun.center);
      await tester.pumpAndSettle();

      expect(choisies, <MapScaleKind>[MapScaleKind.ecoulement]);
      expect(find.byKey(warningWindowRegionKey), findsNothing);
    });
  });
}
