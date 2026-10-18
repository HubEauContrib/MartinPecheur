// La zone des fiches de la carte (`MapSheetArea`, `D5` d'Ergonomie, spec § 6.1
// et § 6.5, arbitrage 3) : elle ne défile plus elle-même. Chaque panneau de
// fiche — un `SheetFrame` — défile son CORPS sous son EN-TÊTE épinglé, et la
// zone transmet à la mise en page de la carte les hauteurs du cadre : repliée,
// l'en-tête seul ; entière, la fiche entière. Ce qui est éprouvé ici, sur la
// zone seule :
// - aucun défilement de zone : le seul défilement est le corps du cadre ;
// - les intrinsèques de la zone sont celles des panneaux, la hauteur repliée
//   comprise (l'en-tête, jamais 0) ;
// - posée plus basse que la fiche entière, l'en-tête reste entier et le corps
//   défile ;
// - les panneaux s'empilent, et le panneau du dessous reçoit la hauteur que
//   celui du dessus laisse ;
// - de 776 à 799 px de large (fiche du bas, contenu dans la largeur de lecture
//   de 760), les intrinsèques sont lues à la largeur où le contenu est posé :
//   la sous-allocation relevée à la relecture de `D2` est corrigée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_sheet_area.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart'
    show readingColumnWidth;
import 'package:martinpecheur/features/shared/sheet_frame.dart';

import '../../../support/windows_platform.dart';

const Key _premierDuCorps = Key('zone-premier-du-corps');
const Key _panneauDuDessus = Key('zone-panneau-du-dessus');

/// Une fiche dans le cadre commun, au corps de [hauteurDuCorps] pixels.
Widget _fiche({double hauteurDuCorps = 600, ScrollController? controleur}) =>
    SheetFrame(
      nature: 'Station hydrométrique · K447001001',
      closeButtonKey: const Key('zone-fermer'),
      onClose: () {},
      bodyScrollController: controleur,
      body: SizedBox(
        height: hauteurDuCorps,
        child: const Align(
          alignment: Alignment.topLeft,
          child: Text('Corps', key: _premierDuCorps),
        ),
      ),
    );

/// Monte la zone des fiches, fiche du bas, dans une boîte de [largeur] sur
/// [hauteur] : la largeur est imposée, la hauteur est un plafond (comme la
/// mise en page de la carte pose la fiche du bas).
Future<void> _monter(
  WidgetTester tester, {
  required List<Widget> panneaux,
  double largeur = 400,
  double hauteur = 300,
  bool panneauLateral = false,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: largeur,
              maxWidth: largeur,
              maxHeight: hauteur,
            ),
            child: MapSheetArea(
              key: mapSheetAreaKey,
              sidePanel: panneauLateral,
              extend: EdgeInsets.zero,
              panels: panneaux,
            ),
          ),
        ),
      ),
    ),
  );
}

RenderBox _zone(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byKey(mapSheetAreaKey));

void main() {
  group('zone des fiches (D5 d’Ergonomie) — en-tête épinglé, corps défilant', () {
    testWidgetsOnWindows(
      'la zone ne défile pas elle-même : son seul défilement est le corps du '
      'cadre',
      (WidgetTester tester) async {
        await _monter(tester, panneaux: <Widget>[_fiche()]);

        final Finder defilements = find.descendant(
          of: find.byKey(mapSheetAreaKey),
          matching: find.byType(Scrollable),
        );
        expect(defilements, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(sheetFrameBodyKey),
            matching: find.byType(Scrollable),
          ),
          findsOneWidget,
          reason: 'le défilement est celui du corps',
        );
        expect(
          find.ancestor(
            of: find.byKey(sheetFrameHeaderKey),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
          reason: 'l’en-tête ne défile pas',
        );
      },
    );

    testWidgetsOnWindows(
      'hauteur repliée = l’en-tête du cadre, jamais 0 ; hauteur entière = la '
      'fiche entière',
      (WidgetTester tester) async {
        await _monter(tester, panneaux: <Widget>[_fiche()]);

        final RenderBox cadre = tester.renderObject<RenderBox>(
          find.byType(SheetFrame),
        );
        final double enTete = tester
            .getSize(find.byKey(sheetFrameHeaderKey))
            .height;
        expect(_zone(tester).getMinIntrinsicHeight(400), greaterThan(0));
        expect(
          _zone(tester).getMinIntrinsicHeight(400),
          moreOrLessEquals(cadre.getMinIntrinsicHeight(400)),
        );
        expect(
          _zone(tester).getMinIntrinsicHeight(400),
          moreOrLessEquals(enTete),
          reason: 'repliée, la zone dit l’en-tête',
        );
        expect(
          _zone(tester).getMaxIntrinsicHeight(400),
          moreOrLessEquals(cadre.getMaxIntrinsicHeight(400)),
        );
      },
    );

    testWidgetsOnWindows(
      'posée plus basse que la fiche entière : l’en-tête est entier, en haut '
      'de la zone, et reste en place quand le corps défile',
      (WidgetTester tester) async {
        final ScrollController controleur = ScrollController();
        addTearDown(controleur.dispose);
        await _monter(
          tester,
          panneaux: <Widget>[_fiche(controleur: controleur)],
          hauteur: 200,
        );

        final Rect zone = tester.getRect(find.byKey(mapSheetAreaKey));
        final Rect enTete = tester.getRect(find.byKey(sheetFrameHeaderKey));
        expect(zone.height, moreOrLessEquals(200));
        expect(enTete.top, moreOrLessEquals(zone.top));
        expect(enTete.bottom, lessThanOrEqualTo(zone.bottom));
        expect(controleur.position.maxScrollExtent, greaterThan(0));

        controleur.jumpTo(controleur.position.maxScrollExtent);
        await tester.pump();
        expect(
          tester.getRect(find.byKey(sheetFrameHeaderKey)),
          enTete,
          reason: 'l’en-tête ne bouge pas quand le corps défile',
        );
        expect(
          tester.getRect(find.byKey(_premierDuCorps)).top,
          lessThan(enTete.bottom),
          reason: 'le corps, lui, a défilé sous l’en-tête',
        );
      },
    );

    testWidgetsOnWindows(
      'deux panneaux : le second sous le premier, borné par ce que le premier '
      'laisse',
      (WidgetTester tester) async {
        await _monter(
          tester,
          panneaux: <Widget>[
            const SizedBox(key: _panneauDuDessus, height: 60),
            _fiche(),
          ],
          hauteur: 260,
        );

        final Rect dessus = tester.getRect(find.byKey(_panneauDuDessus));
        final Rect fiche = tester.getRect(find.byType(SheetFrame));
        expect(fiche.top, moreOrLessEquals(dessus.bottom));
        expect(fiche.bottom, lessThanOrEqualTo(dessus.top + 260 + 0.5));
        expect(
          _zone(tester).getMinIntrinsicHeight(400),
          moreOrLessEquals(
            60 + tester.getSize(find.byKey(sheetFrameHeaderKey)).height,
          ),
        );
      },
    );

    testWidgetsOnWindows(
      'la mesure mise en avant de la zone (arbitrage 18) : celle de la fiche, '
      'au travers du fond peint de la zone ; deux panneaux, la somme',
      (WidgetTester tester) async {
        await _monter(tester, panneaux: <Widget>[_fiche()]);

        final RenderBox cadre = tester.renderObject<RenderBox>(
          find.byType(SheetFrame),
        );
        final double vedette = sheetFeaturedHeightOf(cadre, 400);
        expect(vedette, greaterThan(cadre.getMinIntrinsicHeight(400)));
        expect(
          sheetFeaturedHeightOf(_zone(tester), 400),
          moreOrLessEquals(vedette),
        );

        await _monter(
          tester,
          panneaux: <Widget>[
            const SizedBox(key: _panneauDuDessus, height: 60),
            _fiche(),
          ],
          hauteur: 2000,
        );
        expect(
          sheetFeaturedHeightOf(_zone(tester), 400),
          moreOrLessEquals(60 + vedette),
        );
      },
    );

    testWidgetsOnWindows(
      'panneau latéral : la fiche prend la largeur entière du panneau',
      (WidgetTester tester) async {
        await _monter(
          tester,
          panneaux: <Widget>[_fiche()],
          largeur: 380,
          hauteur: 700,
          panneauLateral: true,
        );

        expect(tester.getSize(find.byType(SheetFrame)).width, 380);
      },
    );

    testWidgetsOnWindows(
      'de 776 à 799 px, fiche du bas : le contenu est posé dans la largeur de '
      'lecture, et ses hauteurs sont lues à cette largeur (sous-allocation '
      'relevée à la relecture de D2)',
      (WidgetTester tester) async {
        // Un texte dont le nombre de lignes change entre 760 et 790 px.
        final String long = List<String>.filled(400, 'mot').join(' ');
        const Key texte = Key('zone-texte-long');
        await _monter(
          tester,
          panneaux: <Widget>[Text(long, key: texte)],
          largeur: 790,
          hauteur: 2000,
        );

        final RenderBox contenu = tester.renderObject<RenderBox>(
          find.byKey(texte),
        );
        expect(contenu.size.width, readingColumnWidth);
        expect(
          contenu.getMaxIntrinsicHeight(readingColumnWidth),
          greaterThan(contenu.getMaxIntrinsicHeight(790)),
          reason: 'garde-fou : le texte change de hauteur entre les deux',
        );
        expect(
          _zone(tester).getMaxIntrinsicHeight(790),
          moreOrLessEquals(contenu.size.height),
          reason: 'la hauteur entière dite est celle du contenu posé',
        );
        expect(
          _zone(tester).getMinIntrinsicHeight(790),
          moreOrLessEquals(contenu.getMinIntrinsicHeight(readingColumnWidth)),
        );
        expect(
          tester.getRect(find.byKey(texte)).center.dx,
          moreOrLessEquals(395),
          reason: 'centré dans la zone',
        );
      },
    );
  });
}
