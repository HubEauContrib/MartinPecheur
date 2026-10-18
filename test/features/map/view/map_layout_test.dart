// La mise en page de la carte visible (`D1` d'Ergonomie, spec § 5.1 à § 5.6
// et § 6.5) : `MapLayout` et son `RenderMapLayout`, SEULS — `MapView` ne
// l'emploie pas encore (`D2`).
//
// Les enfants sont des pièces de test à hauteurs intrinsèques connues
// ([_Stub] : `min`, `max`), sauf le réticule, le vrai (`MapCenterReticle`).
// Une carte témoin, sous la mise en page, compte les taps qui lui arrivent.
//
// Ce que ces tests prouvent :
// - les positions des trois largeurs : bloc en haut (8 px des bords), avis
//   puis légende dessous, sans écart ; bas en rangée (compact) ou en colonne
//   à droite (au-delà) ; bande au-dessus de la rangée ou à gauche de la
//   colonne ; fiche du bas sous tout le reste, panneau de 380 à droite ;
// - le réticule au centre horizontal de la carte visible, au milieu vertical
//   de [bas de la partie fixe ; haut de la bande] — il ne bouge ni avec les
//   avis ni avec la légende ;
// - le repli 6 : bande et réticule à taille nulle, ni peints ni touchables, le
//   rapport sans réticule ;
// - le rapport publié après la trame, une fois par changement ;
// - la zone sûre et les tailles en deçà ; la colonne au-dessus de la fiche du
//   bas en wide ; les vraies hauteurs de `mesurerPieces` à 360 × 640 et 200 %
//   (arbitrage 13 : la partie fixe reçoit le reste).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugCheckIntrinsicSizes;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show RenderSheetFeaturedHeight;
import 'package:martinpecheur/features/shared/warning_link.dart';

import '../../../support/android_platform.dart';
import '../../../support/ergonomie_mesures.dart';
import '../../../support/layout_sizes.dart';
import '../../../support/roboto.dart';
import '../../../support/windows_platform.dart';

/// La bande du réticule de ces tests : le réticule et une marge de chaque côté
/// (la valeur que `D2` passera).
const double _bandeReticule = mapCenterReticleSize + 2 * margeDeSurcouche;

Key _cle(MapLayoutSlot slot) => Key('emplacement-${slot.name}');

/// Les pièces d'une configuration. [band] nulle : hors mode (bande et
/// réticule absents) ; [sheet] nulle : aucune fiche ouverte.
final class _Pieces {
  const _Pieces({
    this.fixed = const PieceHeights(min: 100, max: 150),
    this.notices = 0,
    this.legend = 0,
    this.bottom = 60,
    this.bottomWidth = 60,
    this.band,
    this.bandMinWidth = 120,
    this.sheet,
    this.sheetFeatured,
  });

  final PieceHeights fixed;
  final double notices;
  final double legend;
  final double bottom;
  final double bottomWidth;
  final PieceHeights? band;
  final double bandMinWidth;
  final PieceHeights? sheet;

  /// La mesure mise en avant de la fiche (arbitrage 18), ou `null` : son
  /// en-tête, `sheet.min`.
  final double? sheetFeatured;

  _Pieces copyWith({double? notices, double? legend}) => _Pieces(
    fixed: fixed,
    notices: notices ?? this.notices,
    legend: legend ?? this.legend,
    bottom: bottom,
    bottomWidth: bottomWidth,
    band: band,
    bandMinWidth: bandMinWidth,
    sheet: sheet,
    sheetFeatured: sheetFeatured,
  );
}

/// Ce que la carte témoin et la bande ont reçu, et combien de fois la bande a
/// été peinte.
final class _Compteurs {
  int carte = 0;
  int bande = 0;
  int bandePeinte = 0;
}

void _fenetre(WidgetTester tester, Size taille) {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pose la carte témoin puis `MapLayout` sur toute la fenêtre.
Future<void> _poser(
  WidgetTester tester, {
  required Size taille,
  required _Pieces pieces,
  required ValueNotifier<MapLayoutReport?> rapport,
  EdgeInsets marge = EdgeInsets.zero,
  _Compteurs? compteurs,
  Widget? auDessus,
}) async {
  _fenetre(tester, taille);
  final _Compteurs c = compteurs ?? _Compteurs();
  final PieceHeights? band = pieces.band;
  final PieceHeights? sheet = pieces.sheet;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => c.carte++,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: MapLayout(
              padding: margeDeSurcouche,
              safeInsets: marge,
              reticleBandHeight: _bandeReticule,
              report: rapport,
              children: <Widget>[
                MapLayoutChild(
                  slot: MapLayoutSlot.sheet,
                  child: _Stub(
                    key: _cle(MapLayoutSlot.sheet),
                    min: sheet?.min ?? 0,
                    max: sheet?.max ?? 0,
                    featured: pieces.sheetFeatured,
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.blockFixed,
                  child: _Stub(
                    key: _cle(MapLayoutSlot.blockFixed),
                    min: pieces.fixed.min,
                    max: pieces.fixed.max,
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.blockNotices,
                  child: _Stub(
                    key: _cle(MapLayoutSlot.blockNotices),
                    min: 0,
                    max: pieces.notices,
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.blockLegend,
                  child: _Stub(
                    key: _cle(MapLayoutSlot.blockLegend),
                    min: 0,
                    max: pieces.legend,
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.bottom,
                  child: _Stub(
                    key: _cle(MapLayoutSlot.bottom),
                    min: pieces.bottom,
                    max: pieces.bottom,
                    maxWidth: pieces.bottomWidth,
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.band,
                  child: GestureDetector(
                    onTap: () => c.bande++,
                    child: _Stub(
                      key: _cle(MapLayoutSlot.band),
                      min: band?.min ?? 0,
                      max: band?.max ?? 0,
                      minWidth: band == null ? 0 : pieces.bandMinWidth,
                      maxWidth: band == null ? 0 : pieces.bandMinWidth,
                      onPaint: () => c.bandePeinte++,
                    ),
                  ),
                ),
                MapLayoutChild(
                  slot: MapLayoutSlot.reticle,
                  child: band == null
                      ? SizedBox.shrink(key: _cle(MapLayoutSlot.reticle))
                      : const MapCenterReticle(),
                ),
              ],
            ),
          ),
          ?auDessus,
        ],
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, MapLayoutSlot slot) =>
    tester.getRect(find.byKey(_cle(slot)));

/// `RenderMapLayout.paintsChild` pour l'enfant direct qui porte [finder] : la
/// mise en page le peint-elle ?
bool _peint(WidgetTester tester, Finder finder) {
  final RenderMapLayout layout = tester.renderObject<RenderMapLayout>(
    find.byType(MapLayout),
  );
  RenderObject child = tester.renderObject(finder);
  while (!identical(child.parent, layout)) {
    child = child.parent!;
  }
  return layout.paintsChild(child as RenderBox);
}

Rect _reticule(WidgetTester tester) =>
    tester.getRect(find.byKey(mapCenterReticleKey));

/// Le centre attendu du réticule : centre horizontal de la carte visible,
/// milieu vertical de [bas de la partie fixe ; haut de la bande].
Offset _centreAttendu(WidgetTester tester, Rect visible) => Offset(
  visible.center.dx,
  (_rect(tester, MapLayoutSlot.blockFixed).bottom +
          _rect(tester, MapLayoutSlot.band).top) /
      2,
);

void main() {
  setUpAll(chargerRoboto);

  group('La fiche du bas garde sa mesure mise en avant (arbitrages 18 et 19)', () {
    // Partie fixe 100/150, rangée 60, fiche : en-tête 80, mesure mise en avant
    // 540, entière 560 ; 360 × 640, une marge : 632 de disponible. Repli 4 :
    // 736 ; repli 2 jusqu'à la mesure : 716, il manque encore 84. La partie
    // fixe défile jusqu'à son plancher, puis la fiche cède sous sa mesure : à
    // 48 (Android), 632 − (48 + 8 + 60 + 8) = 508 ; à 44 (ailleurs), 512.
    const _Pieces pieces = _Pieces(
      sheet: PieceHeights(min: 80, max: 560),
      sheetFeatured: 540,
    );

    Future<void> verifier(WidgetTester tester, double plancher) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: pieces,
        rapport: rapport,
      );

      final MapLayoutAllocation allocation = rapport.value!.allocation;
      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, plancher);
      expect(allocation.sheet, 632 - (plancher + 8 + 60 + 8));
      expect(_rect(tester, MapLayoutSlot.blockFixed).height, plancher);
      expect(
        _rect(tester, MapLayoutSlot.sheet),
        Rect.fromLTRB(0, 640 - allocation.sheet, 360, 640),
      );
      expect(tester.takeException(), isNull);
    }

    testWidgetsOnAndroid('Android : le plancher de la partie fixe est la cible '
        'tactile de la plateforme, 48', (WidgetTester tester) async {
      await verifier(tester, 48);
    });

    testWidgetsOnWindows('sous Windows, le plancher est 44', (
      WidgetTester tester,
    ) async {
      await verifier(tester, 44);
    });

    testWidgetsOnAndroid('Android : assez de place pour la mesure : la fiche '
        's\'y arrête, la partie fixe reçoit le reste, au-dessus de son '
        'plancher', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      // Mesure mise en avant 450 : 100 + 8 + 60 + 8 + 450 = 626 tient dans
      // 632 ; le surplus de 6 revient à la fiche.
      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: const _Pieces(
          sheet: PieceHeights(min: 80, max: 560),
          sheetFeatured: 450,
        ),
        rapport: rapport,
      );

      final MapLayoutAllocation allocation = rapport.value!.allocation;
      expect(allocation.overflows, isFalse);
      expect(allocation.sheet, 456);
      expect(allocation.blockFixed, 100);
    });
  });

  group('Compact', () {
    testWidgetsOnAndroid('Android : sans fiche, hors mode — partie fixe en '
        'haut à 8 px des bords, rangée collée en bas, avis puis légende entre '
        'les deux', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: const _Pieces(notices: 30, legend: 100),
        rapport: rapport,
      );

      expect(
        _rect(tester, MapLayoutSlot.blockFixed),
        const Rect.fromLTWH(8, 8, 344, 150),
      );
      expect(
        _rect(tester, MapLayoutSlot.blockNotices),
        const Rect.fromLTWH(8, 158, 344, 30),
      );
      expect(
        _rect(tester, MapLayoutSlot.blockLegend),
        const Rect.fromLTWH(8, 188, 344, 100),
      );
      expect(
        _rect(tester, MapLayoutSlot.bottom),
        const Rect.fromLTWH(8, 572, 344, 60),
      );
      expect(rapport.value, isNotNull);
      expect(rapport.value!.visible, const Rect.fromLTWH(0, 0, 360, 640));
      expect(rapport.value!.reticle, isNull);
      expect(rapport.value!.allocation.folds, isEmpty);
    });

    testWidgetsOnAndroid('Android : fiche ouverte, en mode — partie fixe, '
        'bande du réticule, bande et rangée au-dessus de la fiche ; réticule '
        'entre la partie fixe et la bande', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: const _Pieces(
          legend: 40,
          band: PieceHeights(min: 48, max: 80),
          sheet: PieceHeights(min: 80, max: 200),
        ),
        rapport: rapport,
      );

      final Rect fiche = _rect(tester, MapLayoutSlot.sheet);
      expect(fiche, const Rect.fromLTWH(0, 440, 360, 200));
      final Rect rangee = _rect(tester, MapLayoutSlot.bottom);
      final Rect bande = _rect(tester, MapLayoutSlot.band);
      expect(rangee, const Rect.fromLTWH(8, 372, 344, 60));
      expect(bande, const Rect.fromLTWH(8, 284, 344, 80));
      expect(_rect(tester, MapLayoutSlot.blockFixed).bottom, 158);

      final Rect visible = rapport.value!.visible;
      expect(visible, const Rect.fromLTWH(0, 0, 360, 440));
      final Rect reticule = _reticule(tester);
      expect(reticule.center, _centreAttendu(tester, visible));
      expect(reticule.center, const Offset(180, 221));
      expect(rapport.value!.reticle, reticule);
      // La partie variable s'arrête au-dessus de la bande du réticule.
      expect(
        _rect(tester, MapLayoutSlot.blockLegend).bottom,
        lessThanOrEqualTo(reticule.center.dy - _bandeReticule / 2 + 1e-6),
      );
      for (final MapLayoutSlot slot in <MapLayoutSlot>[
        MapLayoutSlot.blockFixed,
        MapLayoutSlot.blockNotices,
        MapLayoutSlot.blockLegend,
        MapLayoutSlot.bottom,
        MapLayoutSlot.band,
      ]) {
        expect(_rect(tester, slot).bottom, lessThanOrEqualTo(fiche.top));
      }
      expect(reticule.bottom, lessThanOrEqualTo(bande.top));
    });

    testWidgetsOnAndroid('Android : fiche du bas ouverte, en mode — le '
        'réticule ne bouge pas quand un avis paraît (arbitrage 15)', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      const _Pieces base = _Pieces(
        band: PieceHeights(min: 48, max: 80),
        sheet: PieceHeights(min: 80, max: 300),
      );
      final List<Rect> reticules = <Rect>[];
      final List<double> fiches = <double>[];
      for (final _Pieces pieces in <_Pieces>[
        base,
        base.copyWith(notices: 40),
      ]) {
        await _poser(
          tester,
          taille: const Size(360, 640),
          pieces: pieces,
          rapport: rapport,
        );
        reticules.add(_reticule(tester));
        fiches.add(_rect(tester, MapLayoutSlot.sheet).height);
      }

      expect(reticules.last, reticules.first);
      expect(fiches.last, fiches.first);
    });

    testWidgetsOnAndroid('Android : le réticule ne bouge pas quand seule la '
        'hauteur des avis ou de la légende change', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      const _Pieces base = _Pieces(
        legend: 100,
        band: PieceHeights(min: 48, max: 80),
      );
      final List<Rect> reticules = <Rect>[];
      final List<double> legendes = <double>[];
      for (final _Pieces pieces in <_Pieces>[
        base,
        base.copyWith(notices: 40),
        base.copyWith(legend: 20),
        base.copyWith(notices: 200, legend: 300),
      ]) {
        await _poser(
          tester,
          taille: const Size(360, 640),
          pieces: pieces,
          rapport: rapport,
        );
        reticules.add(_reticule(tester));
        legendes.add(_rect(tester, MapLayoutSlot.blockLegend).height);
        expect(rapport.value!.reticle, reticules.last);
      }

      expect(reticules.toSet(), hasLength(1));
      expect(reticules.first.center, const Offset(180, 321));
      // Les hauteurs, elles, ont changé.
      expect(legendes.toSet().length, greaterThan(1));
    });

    testWidgetsOnAndroid('Android : repli 6 — bande et réticule à taille '
        'nulle, ni peints ni touchables ; un tap à leur place atteint la carte '
        'témoin ; le rapport dit reticle == null', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      const _Pieces pieces = _Pieces(
        band: PieceHeights(min: 48, max: 80),
        sheet: PieceHeights(min: 80, max: 300),
      );

      // D'abord la bande posée : elle prend le tap posé sur elle.
      final _Compteurs pose = _Compteurs();
      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: pieces,
        rapport: rapport,
        compteurs: pose,
      );
      expect(rapport.value!.allocation.bandWithdrawn, isFalse);
      expect(pose.bandePeinte, greaterThan(0));
      expect(_peint(tester, find.byKey(_cle(MapLayoutSlot.band))), isTrue);
      expect(_peint(tester, find.byType(MapCenterReticle)), isTrue);
      await tester.tapAt(_rect(tester, MapLayoutSlot.band).center);
      expect(pose.bande, 1);
      expect(pose.carte, 0);

      // Puis la hauteur qui manque : repli 6. Disponible 370 − 8 (une seule
      // marge sous une fiche du bas) = 362 ; au plus bas avec la bande : 368.
      final _Compteurs retire = _Compteurs();
      await _poser(
        tester,
        taille: const Size(360, 370),
        pieces: pieces,
        rapport: rapport,
        compteurs: retire,
      );
      await tester.pump();
      expect(rapport.value!.allocation.bandWithdrawn, isTrue);
      expect(rapport.value!.reticle, isNull);
      expect(tester.getSize(find.byKey(_cle(MapLayoutSlot.band))), Size.zero);
      expect(tester.getSize(find.byKey(mapCenterReticleKey)), Size.zero);
      expect(retire.bandePeinte, 0);
      expect(_peint(tester, find.byKey(_cle(MapLayoutSlot.band))), isFalse);
      expect(_peint(tester, find.byType(MapCenterReticle)), isFalse);
      // Entre la partie fixe (8 à 108) et la rangée (116 à 176) : là où la
      // bande se poserait.
      expect(_rect(tester, MapLayoutSlot.blockFixed).bottom, 108);
      expect(_rect(tester, MapLayoutSlot.bottom).top, 116);
      expect(_rect(tester, MapLayoutSlot.band).topLeft, const Offset(8, 108));
      await tester.tapAt(const Offset(180, 112));
      expect(retire.carte, 1);
      expect(retire.bande, 0);
    });

    testWidgetsOnAndroid('Android : zone sûre du téléphone — rien ne se pose '
        'dans les marges', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(360, 640),
        marge: margeSystemeTelephone,
        pieces: const _Pieces(
          notices: 30,
          legend: 100,
          band: PieceHeights(min: 48, max: 80),
          sheet: PieceHeights(min: 80, max: 300),
        ),
        rapport: rapport,
      );

      for (final MapLayoutSlot slot in MapLayoutSlot.values) {
        final Rect rect = slot == MapLayoutSlot.reticle
            ? _reticule(tester)
            : _rect(tester, slot);
        if (rect.isEmpty) continue;
        expect(rect.top, greaterThanOrEqualTo(24), reason: '$slot');
        expect(rect.bottom, lessThanOrEqualTo(640 - 48), reason: '$slot');
      }
      expect(_rect(tester, MapLayoutSlot.blockFixed).top, 24 + 8);
      expect(_rect(tester, MapLayoutSlot.sheet).bottom, 640 - 48);
      expect(rapport.value!.visible.top, 24);
      expect(
        rapport.value!.visible.bottom,
        _rect(tester, MapLayoutSlot.sheet).top,
      );
    });
  });

  group('Wide et panneau', () {
    testWidgetsOnWindows('retirée n\'est pas « de taille nulle » : une bande '
        'qui ne tient pas, sans fiche, est posée à hauteur 0 mais PEINTE, et '
        'le réticule aussi ; retirée, ni l\'une ni l\'autre', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      final _Compteurs nulle = _Compteurs();
      // Bande de 1 196 de place pour 2 000 de large au moins : elle ne tient
      // pas ; sans fiche, elle ne se retire pas (débordement).
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(
          band: PieceHeights(min: 48, max: 80),
          bandMinWidth: 2000,
        ),
        rapport: rapport,
        compteurs: nulle,
      );
      expect(rapport.value!.allocation.bandWithdrawn, isFalse);
      expect(rapport.value!.allocation.overflows, isTrue);
      expect(_rect(tester, MapLayoutSlot.band).height, 0);
      expect(nulle.bandePeinte, greaterThan(0));
      expect(_peint(tester, find.byKey(_cle(MapLayoutSlot.band))), isTrue);
      expect(_peint(tester, find.byType(MapCenterReticle)), isTrue);

      // La même bande, une fiche ouverte : repli 6 étendu, retirée.
      final _Compteurs retiree = _Compteurs();
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(
          band: PieceHeights(min: 48, max: 80),
          bandMinWidth: 2000,
          sheet: PieceHeights(min: 80, max: 300),
        ),
        rapport: rapport,
        compteurs: retiree,
      );
      await tester.pump();
      expect(rapport.value!.allocation.bandWithdrawn, isTrue);
      expect(retiree.bandePeinte, 0);
      expect(_peint(tester, find.byKey(_cle(MapLayoutSlot.band))), isFalse);
      expect(_peint(tester, find.byType(MapCenterReticle)), isFalse);
    });

    testWidgetsOnWindows('panneau, fiche ouverte : fiche de 380 à droite, '
        'pleine hauteur ; tout le reste dans les largeur − 380 de gauche', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(
          legend: 100,
          bottom: 288,
          band: PieceHeights(min: 48, max: 80),
          sheet: PieceHeights(min: 80, max: 500),
        ),
        rapport: rapport,
      );

      expect(
        _rect(tester, MapLayoutSlot.sheet),
        const Rect.fromLTWH(900, 0, 380, 740),
      );
      expect(rapport.value!.visible, const Rect.fromLTWH(0, 0, 900, 740));
      expect(
        _rect(tester, MapLayoutSlot.blockFixed),
        const Rect.fromLTWH(8, 8, 480, 150),
      );
      expect(
        _rect(tester, MapLayoutSlot.bottom),
        const Rect.fromLTWH(832, 444, 60, 288),
      );
      // La bande, au bas de la carte visible, à gauche de la colonne.
      expect(
        _rect(tester, MapLayoutSlot.band),
        const Rect.fromLTWH(8, 652, 900 - 3 * 8 - 60, 80),
      );
      for (final MapLayoutSlot slot in <MapLayoutSlot>[
        MapLayoutSlot.blockFixed,
        MapLayoutSlot.blockNotices,
        MapLayoutSlot.blockLegend,
        MapLayoutSlot.bottom,
        MapLayoutSlot.band,
      ]) {
        expect(_rect(tester, slot).right, lessThanOrEqualTo(900));
      }
      expect(
        _reticule(tester).center,
        _centreAttendu(tester, rapport.value!.visible),
      );
      expect(_reticule(tester).center.dx, 450);
    });

    testWidgetsOnWindows('panneau, fiches fermées : rien n\'est réservé à '
        'droite', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(legend: 100, bottom: 288),
        rapport: rapport,
      );

      expect(_rect(tester, MapLayoutSlot.sheet).isEmpty, isTrue);
      expect(rapport.value!.visible, const Rect.fromLTWH(0, 0, 1280, 740));
      expect(_rect(tester, MapLayoutSlot.bottom).right, 1280 - 8);
    });

    testWidgetsOnWindows('1 280 × 740, en mode, sans fiche : le réticule est '
        'loin du bloc, la partie variable ne compte qu\'une fois — rien ne '
        'cède tant que tout tient', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      // 150 + 400 + 64 + 80 = 694 tient dans 724 ; compté deux fois, 1 094
      // ne tiendrait pas.
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(
          legend: 400,
          bottom: 288,
          band: PieceHeights(min: 48, max: 80),
        ),
        rapport: rapport,
      );

      expect(rapport.value!.allocation.folds, isEmpty);
      expect(_rect(tester, MapLayoutSlot.blockLegend).height, 400);
      final Rect reticule = _reticule(tester);
      expect(reticule.center.dx, 640);
      expect(
        reticule.left,
        greaterThan(_rect(tester, MapLayoutSlot.blockLegend).right),
      );
    });

    testWidgetsOnWindows('1 280 × 740, en mode, panneau ouvert : carte '
        'visible 900, le réticule passe sous le bloc — la partie variable '
        'compte deux fois', (WidgetTester tester) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(1280, 740),
        pieces: const _Pieces(
          legend: 400,
          bottom: 288,
          band: PieceHeights(min: 48, max: 80),
          sheet: PieceHeights(min: 80, max: 500),
        ),
        rapport: rapport,
      );

      // 724 − 150 − 64 − 80 = 430, partagés en deux : légende 215.
      expect(rapport.value!.allocation.folds, <int>[1]);
      expect(_rect(tester, MapLayoutSlot.blockLegend).height, 215);
      expect(
        _rect(tester, MapLayoutSlot.blockLegend).bottom,
        lessThanOrEqualTo(_reticule(tester).center.dy - _bandeReticule / 2),
      );
    });

    testWidgetsOnWindows('700 × 600, wide, fiche du bas ouverte : la colonne '
        'se pose au-dessus de la fiche, jamais dessous', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(700, 600),
        pieces: const _Pieces(
          legend: 100,
          bottom: 288,
          sheet: PieceHeights(min: 80, max: 1000),
        ),
        rapport: rapport,
      );

      final MapLayoutAllocation repartition = rapport.value!.allocation;
      expect(repartition.overflows, isFalse);
      expect(repartition.folds, <int>[2]);
      // Disponible 600 − 8 (une seule marge : la fiche du bas est collée au
      // bas) ; 592 − 288 − 8 : la colonne plafonne la fiche.
      expect(repartition.sheet, 296);
      final Rect fiche = _rect(tester, MapLayoutSlot.sheet);
      final Rect colonne = _rect(tester, MapLayoutSlot.bottom);
      expect(fiche, const Rect.fromLTWH(0, 304, 700, 296));
      expect(colonne, const Rect.fromLTWH(632, 8, 60, 288));
      expect(colonne.bottom, fiche.top - 8);
      expect(colonne.top, greaterThanOrEqualTo(8));
      expect(
        _rect(tester, MapLayoutSlot.blockFixed),
        const Rect.fromLTWH(8, 8, 480, 150),
      );
    });
  });

  group('Le rapport', () {
    testWidgetsOnAndroid('Android : publié après la trame, une fois par '
        'changement, jamais pendant la mise en page', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      final List<SchedulerPhase> phases = <SchedulerPhase>[];
      rapport.addListener(
        () => phases.add(SchedulerBinding.instance.schedulerPhase),
      );
      // Un écouteur qui reconstruit à chaque rapport, comme la vue (`D2`).
      final Widget ecouteur = ValueListenableBuilder<MapLayoutReport?>(
        valueListenable: rapport,
        builder: (BuildContext context, MapLayoutReport? valeur, Widget? _) =>
            const SizedBox.shrink(),
      );
      const _Pieces pieces = _Pieces(
        legend: 100,
        band: PieceHeights(min: 48, max: 80),
      );

      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: pieces,
        rapport: rapport,
        auDessus: ecouteur,
      );
      expect(phases, <SchedulerPhase>[SchedulerPhase.postFrameCallbacks]);
      final MapLayoutReport premier = rapport.value!;

      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: pieces,
        rapport: rapport,
        auDessus: ecouteur,
      );
      await tester.pump();
      expect(phases, hasLength(1));
      expect(rapport.value, premier);

      await _poser(
        tester,
        taille: const Size(360, 640),
        pieces: pieces.copyWith(legend: 300),
        rapport: rapport,
        auDessus: ecouteur,
      );
      await tester.pump();
      expect(phases, <SchedulerPhase>[
        SchedulerPhase.postFrameCallbacks,
        SchedulerPhase.postFrameCallbacks,
      ]);
      expect(rapport.value, isNot(premier));
      expect(tester.takeException(), isNull);
    });

    test('égalité par valeur : chaque champ compte', () {
      MapLayoutReport rapport({
        Rect visible = const Rect.fromLTWH(0, 0, 360, 640),
        Rect? reticle = const Rect.fromLTWH(156, 300, 48, 48),
        double available = 624,
        EdgeInsets covered = EdgeInsets.zero,
      }) => MapLayoutReport(
        visible: visible,
        reticle: reticle,
        covered: covered,
        allocation: allocateMapLayout(
          MapLayoutInput(
            available: available,
            width: MapLayoutWidth.compact,
            blockOverBottom: true,
            bandFits: true,
            reticleUnderBlock: true,
            designation: false,
            sheetOpen: false,
            blockFixed: const PieceHeights(min: 100, max: 150),
            blockFixedFloor: 48,
            notices: 0,
            legend: 100,
            bottom: 60,
            band: PieceHeights.none,
            reticleBand: 0,
            sheet: PieceHeights.none,
            sheetFeatured: 0,
            gap: 8,
          ),
        ),
      );

      expect(rapport(), rapport());
      expect(rapport().hashCode, rapport().hashCode);
      // La carte visible.
      expect(
        rapport(visible: const Rect.fromLTWH(0, 0, 360, 440)),
        isNot(rapport()),
      );
      // Le réticule : déplacé, ou absent.
      expect(
        rapport(reticle: const Rect.fromLTWH(156, 301, 48, 48)),
        isNot(rapport()),
      );
      expect(rapport(reticle: null), isNot(rapport()));
      // La répartition : 300 de disponible font replier la légende.
      expect(rapport(available: 300).allocation, isNot(rapport().allocation));
      expect(rapport(available: 300), isNot(rapport()));
      // La part que la fiche couvre (`D4`) : présente, ou autre.
      const EdgeInsets fiche = EdgeInsets.only(bottom: 200);
      expect(rapport(covered: fiche), isNot(rapport()));
      expect(rapport(covered: fiche), rapport(covered: fiche));
      expect(
        rapport(covered: fiche).hashCode,
        rapport(covered: fiche).hashCode,
      );
      expect(
        rapport(covered: const EdgeInsets.only(right: 200)),
        isNot(rapport(covered: fiche)),
      );
    });
  });

  group('En deçà des quatre tailles', () {
    for (final Size taille in taillesEnDeca) {
      final bool compact = switch (mapLayoutWidthFor(taille.width)) {
        MapLayoutWidth.compact => true,
        MapLayoutWidth.wide || MapLayoutWidth.panel => false,
      };
      final void Function(String, Future<void> Function(WidgetTester))
      testSurLaPlateforme = compact
          ? testWidgetsOnAndroid
          : testWidgetsOnWindows;
      testSurLaPlateforme(
        '${compact ? 'Android : ' : ''}${taille.width.round()} × '
        '${taille.height.round()}, en mode, fiche ouverte : aucune taille '
        'négative, aucune erreur, tout dans la surface ; en débordement, la '
        'partie fixe reçoit le reste',
        (WidgetTester tester) async {
          final ValueNotifier<MapLayoutReport?> rapport =
              ValueNotifier<MapLayoutReport?>(null);
          addTearDown(rapport.dispose);
          await _poser(
            tester,
            taille: taille,
            pieces: _Pieces(
              notices: 30,
              legend: 100,
              bottom: compact ? 60 : 288,
              band: const PieceHeights(min: 48, max: 80),
              sheet: const PieceHeights(min: 80, max: 300),
            ),
            rapport: rapport,
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          final Rect surface = Offset.zero & taille;
          for (final MapLayoutSlot slot in MapLayoutSlot.values) {
            final Rect rect = slot == MapLayoutSlot.reticle
                ? _reticule(tester)
                : _rect(tester, slot);
            expect(rect.width, greaterThanOrEqualTo(0), reason: '$slot');
            expect(rect.height, greaterThanOrEqualTo(0), reason: '$slot');
            if (rect.isEmpty) continue;
            expect(
              surface.contains(rect.topLeft) &&
                  rect.right <= surface.right &&
                  rect.bottom <= surface.bottom,
              isTrue,
              reason: '$slot : $rect hors de $surface',
            );
          }
          final MapLayoutAllocation repartition = rapport.value!.allocation;
          final Rect fixe = _rect(tester, MapLayoutSlot.blockFixed);
          expect(fixe.top, rapport.value!.visible.top + 8);
          if (repartition.overflows) {
            expect(fixe.height, moreOrLessEquals(repartition.blockFixed));
          }
        },
      );
    }

    testWidgetsOnWindows('640 × 360, wide : la colonne qui ne tient pas au-'
        'dessus de la fiche se colle au haut de la carte visible', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(640, 360),
        pieces: const _Pieces(
          fixed: PieceHeights(min: 90, max: 110),
          legend: 60,
          bottom: 288,
          sheet: PieceHeights(min: 70, max: 320),
        ),
        rapport: rapport,
      );

      expect(rapport.value!.allocation.overflows, isTrue);
      expect(rapport.value!.allocation.sheet, 70);
      expect(_rect(tester, MapLayoutSlot.bottom).top, 8);
      expect(_rect(tester, MapLayoutSlot.sheet).top, 290);
    });
  });

  group('En deçà, aux hauteurs de mesurerPieces', () {
    // Le vrai bas (rangée ou colonne) : posé à sa propre hauteur, bornée à la
    // zone sûre, il recouvre la fiche plutôt que de déborder ; la fiche du bas
    // ne dépasse jamais la zone sûre, la carte visible n'est jamais négative.
    for (final ({
          String nom,
          Size taille,
          bool android,
          bool enMode,
          EdgeInsets marge,
        })
        cas
        in <
          ({
            String nom,
            Size taille,
            bool android,
            bool enMode,
            EdgeInsets marge,
          })
        >[
          (
            nom: 'Android : 360 × 300, 200 %, fiche station, sans marge',
            taille: const Size(360, 300),
            android: true,
            enMode: false,
            marge: EdgeInsets.zero,
          ),
          (
            nom: 'Android : 360 × 300, 200 %, fiche station, marge',
            taille: const Size(360, 300),
            android: true,
            enMode: false,
            marge: margeSystemeTelephone,
          ),
          (
            nom: '640 × 360, 200 %, en mode, fiche station, marge',
            taille: const Size(640, 360),
            android: false,
            enMode: true,
            marge: margeSystemeTelephone,
          ),
        ]) {
      (cas.android ? testWidgetsOnAndroid : testWidgetsOnWindows)(
        '${cas.nom} : aucune erreur, aucune taille négative, carte visible '
        'positive, rien hors de la zone sûre',
        (WidgetTester tester) async {
          final MapLayoutInput entree = await mesurerPieces(
            tester,
            taille: cas.taille,
            echelle: 2,
            lecture: MapScaleKind.ecoulement,
            enMode: cas.enMode,
            fiche: ficheStation,
            avecAvis: true,
            marge: cas.marge,
          );
          final ValueNotifier<MapLayoutReport?> rapport =
              ValueNotifier<MapLayoutReport?>(null);
          addTearDown(rapport.dispose);
          _fenetre(tester, cas.taille);
          await tester.pumpWidget(
            _enDecaReel(
              taille: cas.taille,
              marge: cas.marge,
              entree: entree,
              rapport: rapport,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(rapport.value, isNotNull);
          final Rect visible = rapport.value!.visible;
          expect(visible.height, greaterThanOrEqualTo(0));
          expect(visible.width, greaterThanOrEqualTo(0));
          final Rect sure = cas.marge.deflateRect(Offset.zero & cas.taille);
          final RenderMapLayout layout = tester.renderObject<RenderMapLayout>(
            find.byType(MapLayout),
          );
          layout.visitChildren((RenderObject enfant) {
            final RenderBox boite = enfant as RenderBox;
            final Offset coin = boite.localToGlobal(Offset.zero);
            final Rect rect = coin & boite.size;
            expect(boite.size.width, greaterThanOrEqualTo(0));
            expect(boite.size.height, greaterThanOrEqualTo(0));
            if (rect.isEmpty) return;
            expect(rect.top, greaterThanOrEqualTo(sure.top - 1e-6));
            final MapLayoutSlot? slot =
                (boite.parentData! as MapLayoutParentData).slot;
            // Un bas plus haut que la zone sûre moins ses marges n'a aucune
            // hauteur où tenir : posé entier sous la marge du haut, il passe
            // sous la marge système du bas, jamais hors de l'écran.
            final bool basTropHaut =
                slot == MapLayoutSlot.bottom &&
                entree.bottom > sure.height - 2 * margeDeSurcouche;
            if (basTropHaut) {
              expect(rect.top, visible.top + margeDeSurcouche);
              expect(rect.bottom, lessThanOrEqualTo(cas.taille.height));
            } else {
              expect(
                rect.bottom,
                lessThanOrEqualTo(sure.bottom + 1e-6),
                reason: '$slot',
              );
            }
          });
        },
      );
    }
  });

  group('Les vraies hauteurs (S6)', () {
    testWidgetsOnAndroid('Android : 390 × 844, 100 %, débit, en mode, fiche '
        'station, sans marge — avis absent puis présent : le réticule reste '
        'fixe (arbitrage 15)', (WidgetTester tester) async {
      final List<Rect> reticules = <Rect>[];
      for (final bool avecAvis in <bool>[false, true]) {
        final MapLayoutInput entree = await mesurerPieces(
          tester,
          taille: const Size(390, 844),
          echelle: 1,
          lecture: MapScaleKind.debit,
          enMode: true,
          fiche: ficheStation,
          avecAvis: avecAvis,
          marge: EdgeInsets.zero,
        );
        final ValueNotifier<MapLayoutReport?> rapport =
            ValueNotifier<MapLayoutReport?>(null);
        addTearDown(rapport.dispose);
        await _poser(
          tester,
          taille: const Size(390, 844),
          pieces: _Pieces(
            fixed: entree.blockFixed,
            notices: entree.notices,
            legend: entree.legend,
            bottom: entree.bottom,
            band: entree.band,
            sheet: entree.sheet,
          ),
          rapport: rapport,
        );
        expect(rapport.value!.allocation, allocateMapLayout(entree));
        reticules.add(_reticule(tester));
      }

      expect(reticules.last, reticules.first);
    });

    testWidgetsOnAndroid('Android : 360 × 640, 200 %, écoulement, en mode, '
        'sans fiche, avis, marge — débordement (arbitrage 13) : la partie fixe '
        'reçoit le reste', (WidgetTester tester) async {
      final MapLayoutInput entree = await mesurerPieces(
        tester,
        taille: const Size(360, 640),
        echelle: 2,
        lecture: MapScaleKind.ecoulement,
        enMode: true,
        fiche: null,
        avecAvis: true,
        marge: margeSystemeTelephone,
      );
      final ValueNotifier<MapLayoutReport?> rapport =
          ValueNotifier<MapLayoutReport?>(null);
      addTearDown(rapport.dispose);
      await _poser(
        tester,
        taille: const Size(360, 640),
        marge: margeSystemeTelephone,
        pieces: _Pieces(
          fixed: entree.blockFixed,
          notices: entree.notices,
          legend: entree.legend,
          bottom: entree.bottom,
          band: entree.band,
        ),
        rapport: rapport,
      );

      final MapLayoutAllocation repartition = rapport.value!.allocation;
      expect(repartition, allocateMapLayout(entree));
      expect(repartition.overflows, isTrue);
      final Rect fixe = _rect(tester, MapLayoutSlot.blockFixed);
      expect(fixe.height, moreOrLessEquals(repartition.blockFixed));
      expect(fixe.top, 24 + 8);
      // La somme posée tient exactement : la rangée au bas de la zone sûre,
      // la bande au-dessus, la bande du réticule entre la partie fixe et elle.
      expect(_rect(tester, MapLayoutSlot.bottom).bottom, 640 - 48 - 8);
      final Rect bande = _rect(tester, MapLayoutSlot.band);
      expect(
        bande.top - fixe.bottom,
        moreOrLessEquals(repartition.reticleBand, epsilon: 1e-6),
      );
      expect(
        _reticule(tester).center.dy,
        moreOrLessEquals((fixe.bottom + bande.top) / 2),
      );
    });

    // Les VRAIES pièces dans `MapLayout`, intrinsèques vérifiées par Flutter
    // (`debugCheckIntrinsicSizes`) : aucune ne lève, et la répartition est
    // exactement celle que `S6` tire de `mesurerPieces` — mêmes largeurs, mêmes
    // hauteurs.
    for (final ({String nom, Size taille, bool android, EdgeInsets marge}) cas
        in <({String nom, Size taille, bool android, EdgeInsets marge})>[
          (
            nom:
                'Android : 360 × 640, 200 %, débit, en mode, sans fiche, '
                'avis, marge',
            taille: const Size(360, 640),
            android: true,
            marge: margeSystemeTelephone,
          ),
          (
            nom: '800 × 740, 200 %, débit, en mode, sans fiche, avis',
            taille: const Size(800, 740),
            android: false,
            marge: EdgeInsets.zero,
          ),
        ]) {
      (cas.android ? testWidgetsOnAndroid : testWidgetsOnWindows)(
        '${cas.nom} — les vraies pièces : la répartition de S6, aucune '
        'intrinsèque ne lève',
        (WidgetTester tester) async {
          final MapLayoutInput entree = await mesurerPieces(
            tester,
            taille: cas.taille,
            echelle: 2,
            lecture: MapScaleKind.debit,
            enMode: true,
            fiche: null,
            avecAvis: true,
            marge: cas.marge,
          );
          final ValueNotifier<MapLayoutReport?> rapport =
              ValueNotifier<MapLayoutReport?>(null);
          addTearDown(rapport.dispose);
          _fenetre(tester, cas.taille);
          debugCheckIntrinsicSizes = true;
          try {
            await tester.pumpWidget(
              _piecesReelles(
                taille: cas.taille,
                marge: cas.marge,
                rapport: rapport,
                compact: cas.android,
              ),
            );
            await tester.pump();
          } finally {
            debugCheckIntrinsicSizes = false;
          }

          expect(tester.takeException(), isNull);
          expect(rapport.value!.allocation, allocateMapLayout(entree));
          expect(rapport.value!.reticle, isNotNull);
        },
      );
    }
  });
}

/// Le vrai bas de la carte, composé comme `mesurerPieces` le compose : la
/// rangée (compact) ou la colonne, l'attribution dessous.
Widget _basReel({required bool compact}) {
  void rien() {}
  return compact
      ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Row(
              children: <Widget>[
                MapEntryButtons(
                  axis: Axis.horizontal,
                  onOpenFilters: rien,
                  onOpenFavorites: rien,
                  filterActive: false,
                ),
                const Spacer(),
                MapControls(
                  axis: Axis.horizontal,
                  onZoomIn: rien,
                  onZoomOut: rien,
                  onRecenter: rien,
                ),
              ],
            ),
            const SizedBox(height: margeDeSurcouche),
            const IgnAttributionBadge(),
          ],
        )
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            MapEntryButtons(
              onOpenFilters: rien,
              onOpenFavorites: rien,
              filterActive: false,
            ),
            const SizedBox(height: mapControlsSpacing),
            MapControls(onZoomIn: rien, onZoomOut: rien, onRecenter: rien),
            const SizedBox(height: margeDeSurcouche),
            const IgnAttributionBadge(),
          ],
        );
}

/// En deçà, aux hauteurs de `mesurerPieces` : le vrai bas, la vraie bande et
/// le vrai réticule en mode ; le bloc et la fiche en pièces de test, à leurs
/// hauteurs mesurées.
Widget _enDecaReel({
  required Size taille,
  required EdgeInsets marge,
  required MapLayoutInput entree,
  required ValueNotifier<MapLayoutReport?> rapport,
}) {
  final bool compact = switch (entree.width) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  };
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: taille, textScaler: TextScaler.linear(2)),
      child: Scaffold(
        body: MapLayout(
          padding: margeDeSurcouche,
          safeInsets: marge,
          reticleBandHeight: _bandeReticule,
          report: rapport,
          children: <Widget>[
            MapLayoutChild(
              slot: MapLayoutSlot.blockFixed,
              child: _Stub(
                min: entree.blockFixed.min,
                max: entree.blockFixed.max,
              ),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.blockNotices,
              child: _Stub(min: 0, max: entree.notices),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.blockLegend,
              child: _Stub(min: 0, max: entree.legend),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.bottom,
              child: _basReel(compact: compact),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.band,
              child: entree.designation
                  ? DesignationBand(onDesignate: () {})
                  : const SizedBox.shrink(),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.reticle,
              child: entree.designation
                  ? const MapCenterReticle()
                  : const SizedBox.shrink(),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.sheet,
              child: _Stub(min: entree.sheet.min, max: entree.sheet.max),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Les vraies pièces de la carte, en mode, lecture « Débit », l'avis
/// d'absence, sans fiche, texte à 200 % — composées comme `mesurerPieces` les
/// compose (`test/support/ergonomie_mesures.dart`).
Widget _piecesReelles({
  required Size taille,
  required EdgeInsets marge,
  required ValueNotifier<MapLayoutReport?> rapport,
  required bool compact,
}) {
  void rien() {}
  final Widget bas = _basReel(compact: compact);
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: taille, textScaler: TextScaler.linear(2)),
      child: Scaffold(
        body: MapLayout(
          padding: margeDeSurcouche,
          safeInsets: marge,
          reticleBandHeight: _bandeReticule,
          report: rapport,
          children: <Widget>[
            MapLayoutChild(
              slot: MapLayoutSlot.blockFixed,
              child: MapReadingBlockFixed(
                selector: MapReadingSelector(
                  scale: MapScaleKind.debit,
                  onSelect: (MapScaleKind _) {},
                  designationMode: true,
                  onToggleDesignationMode: rien,
                ),
                header: MapLegendHeader(
                  scale: MapScaleKind.debit,
                  warningLink: const WarningLink(),
                ),
              ),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.blockNotices,
              child: MapReadingBlockNotices(
                notices: <Widget>[NoDataInAreaNotice(onWiden: rien)],
              ),
            ),
            const MapLayoutChild(
              slot: MapLayoutSlot.blockLegend,
              child: MapReadingBlockLegend(
                legend: MapLegend(scale: MapScaleKind.debit, inBlock: true),
              ),
            ),
            MapLayoutChild(slot: MapLayoutSlot.bottom, child: bas),
            MapLayoutChild(
              slot: MapLayoutSlot.band,
              child: DesignationBand(onDesignate: rien),
            ),
            const MapLayoutChild(
              slot: MapLayoutSlot.reticle,
              child: MapCenterReticle(),
            ),
            const MapLayoutChild(
              slot: MapLayoutSlot.sheet,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Une pièce de test : ses hauteurs intrinsèques sont [min] et [max], ses
/// largeurs intrinsèques [minWidth] et [maxWidth], quelle que soit la largeur.
/// Posée, elle prend toute la largeur bornée qu'on lui donne et sa hauteur
/// entière, ramenée à la hauteur maximale reçue (comme une pièce qui se replie
/// ou défile). Elle prend les gestes posés sur elle. Comme une fiche
/// (`RenderSheetFeaturedHeight`), elle dit sa mesure mise en avant :
/// [featured], ou [min] sans elle.
class _Stub extends LeafRenderObjectWidget {
  const _Stub({
    required this.min,
    required this.max,
    this.featured,
    this.minWidth = 0,
    this.maxWidth = 0,
    this.onPaint,
    super.key,
  });

  final double min;
  final double max;
  final double? featured;
  final double minWidth;
  final double maxWidth;
  final VoidCallback? onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStub()
    ..min = min
    ..max = max
    ..featured = featured
    ..minWidth = minWidth
    ..maxWidth = maxWidth
    ..onPaint = onPaint;

  @override
  void updateRenderObject(BuildContext context, _RenderStub renderObject) {
    renderObject
      ..min = min
      ..max = max
      ..featured = featured
      ..minWidth = minWidth
      ..maxWidth = maxWidth
      ..onPaint = onPaint
      ..markNeedsLayout();
  }
}

class _RenderStub extends RenderBox implements RenderSheetFeaturedHeight {
  double min = 0;
  double max = 0;
  double? featured;
  double minWidth = 0;
  double maxWidth = 0;
  VoidCallback? onPaint;

  @override
  double featuredHeight(double width) => featured ?? min;

  @override
  double computeMinIntrinsicHeight(double width) => min;

  @override
  double computeMaxIntrinsicHeight(double width) => max;

  @override
  double computeMinIntrinsicWidth(double height) => minWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => maxWidth;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(
        Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : maxWidth,
          max,
        ),
      );

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint?.call();
  }
}
