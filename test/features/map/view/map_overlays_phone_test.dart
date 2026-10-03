// Surcouches de la carte aux largeurs de téléphone (constat du 2026-09-29),
// à 360 × 640 et 390 × 844, police à 100 % et à 200 %. Ce que ces tests
// prouvent, et rien de plus :
//
// - aucune erreur de rendu, avec ou sans fiche de 320 px ouverte (l'aide
//   `pumpOverlays` l'affirme elle-même, sauf pour un test qui l'ATTEND) ;
// - le contrôle d'avertissement et les puces d'échelle sont entièrement dans
//   l'écran, leur libellé à l'intérieur de leur boîte ;
// - la colonne du haut laisse passer à la carte les gestes (tap, molette,
//   glisser) posés hors de ses enfants, et la bascule de disposition se fait
//   à 600 px de large ;
// - l'ordre de la colonne : avertissement, puces, avis, puis légende. La
//   légende n'est repoussée que pendant qu'un avis s'affiche : un écart à
//   `BR-008` (« toujours visible »), accepté par le commanditaire le
//   2026-10-03 ;
// - l'ordre de tabulation (`K2`) sous 600 px : puces, contrôles de zoom,
//   bouton de désignation, contrôle d'avertissement ;
// - à 100 %, avec un avis, l'avis est entier dans l'écran, libre de toute
//   surcouche du bas, et son action « Élargir la recherche » est atteignable ;
// - à 100 %, sans avis, la légende « écoulement » est entière et libre de
//   toute autre surcouche ;
// - à 200 %, faire défiler la colonne amène le bord bas de la légende dans la
//   fenêtre.
//
// Ils ne prouvent PAS que tout ce que la colonne porte est visible ou
// atteignable à tout moment. Les tests « CONSTAT » verrouillent des faits
// mesurés qui ne sont pas des invariants voulus — ils décrivent l'écran tel
// qu'il est, et se corrigent À LA MAIN quand l'écran change, jamais en
// silence. Plusieurs ne tiennent que de quelques pixels (marqués dans le
// fichier) : ce sont les premiers à basculer.
//
// - la légende « débit » (468 px de haut à 100 %) recoupe les surcouches du
//   bas, avec ou sans avis ; repoussée sous un avis, la légende est aussi
//   recoupée ou coupée par la fenêtre de la colonne ;
// - à 200 %, l'avis n'est jamais entier au repos et son action n'est pas
//   atteignable ; la légende est cachée au repos, et même amenée dans la
//   fenêtre elle passe sous le bouton de désignation ; à 360 × 640, ce bouton
//   recouvre aussi le contrôle d'avertissement et les puces (leur centre
//   n'est pas atteignable) ;
// - une fiche de 320 px recouvre une partie des surcouches du haut ;
// - en disposition LARGE, à 600 × 360 (téléphone en paysage), la colonne
//   gauche (puces et avis) déborde par le bas : défaut antérieur à la colonne
//   compacte, non corrigé.
//
// Toutes les mesures viennent de la POLICE DE TEST de Flutter, où chaque glyphe
// est un carré d'un em : plus large qu'une police d'appareil. Les pixels et
// les recouvrements sont des mesures de test, pas des constats d'écran.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show warningLinkLabel;
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Clé de la fiche de test : une hauteur réaliste de 320, comme
/// `map_view_test.dart` (proche des fiches réelles de `station_sheet` et
/// `onde_sheet`).
const Key _ficheKey = Key('fiche-de-test-telephone');
const double _hauteurFiche = 320;

const Size _petit = Size(360, 640);
const Size _grand = Size(390, 844);

/// Une station et un point ONDE : ils ne servent qu'à ce que la carte ne soit
/// pas vide (`mapNoticesFor`) — `buildMapOverlays` ne dessine aucun marqueur.
StationPoint _uneStation() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074484784,
  longitude: 1.3351479476905552,
);

Map<OndeStationCode, OndeObservation> _uneObservation() {
  final OndePoint point = OndePoint(
    code: OndeStationCode('04170001'),
    label: 'Le Trey à Vilcey-sur-Trey',
    latitude: 48.885312,
    longitude: 6.023145,
    waterCourseLabel: 'Le Trey',
    departement: const AdministrativeArea(code: '54', label: '54'),
  );
  return <OndeStationCode, OndeObservation>{
    point.code: OndeObservation(
      station: point.code,
      point: point,
      observedAt: DateTime.utc(2026, 8, 25),
      category: const Assec(),
      rawFlowCode: '3',
      officialLabel: 'Assec',
      campaignCode: '1',
    ),
  };
}

/// Le focus courant est-il porté par un élément du sous-arbre de [ancestor] ?
/// Même construction que `map_keyboard_test.dart` : [Focus.of] ne cherche que
/// des ANCÊTRES, jamais l'inverse.
bool _focusedWithin(WidgetTester tester, Finder ancestor) {
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

const String _controles = 'MapControls';
const String _designation = 'DesignateCenterControl';
const String _attribution = 'IgnAttributionBadge';

void main() {
  /// Pose les surcouches à [size] et [textScale], et **affirme l'absence de
  /// toute erreur de rendu** levée pendant la pose — aucune n'est filtrée.
  /// Seul un test qui ATTEND une erreur ([attendErreurs], un CONSTAT) les
  /// reçoit en retour sans échouer ; les autres ne peuvent pas en laisser
  /// passer une.
  ///
  /// Comme `main.dart`, le bouton de désignation est toujours fourni. Par
  /// défaut ([avecAvis]), sans station ni point ONDE, un avis d'absence est
  /// affiché (« Élargir la recherche ») : c'est l'état d'une carte vide. Avec
  /// `avecAvis: false`, une station et un point ONDE existent : aucun avis.
  /// Sous les surcouches, une couche « carte » compte les taps ([onCarteTap]),
  /// les crans de molette ([onCarteMolette]) et les glissers ([onCarteGlisser])
  /// qui lui parviennent. Les surcouches sont dans un groupe de tabulation
  /// ordonné, comme dans `MapView` (`K2`).
  Future<List<FlutterErrorDetails>> pumpOverlays(
    WidgetTester tester,
    Size size, {
    required MapScaleKind scale,
    double textScale = 1,
    bool avecFiche = false,
    bool avecAvis = true,
    bool attendErreurs = false,
    void Function(MapScaleKind kind)? onSelect,
    VoidCallback? onCarteTap,
    VoidCallback? onCarteMolette,
    VoidCallback? onCarteGlisser,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final List<FlutterErrorDetails> erreurs = <FlutterErrorDetails>[];
    final void Function(FlutterErrorDetails)? avant = FlutterError.onError;
    FlutterError.onError = erreurs.add;
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Listener(
                      onPointerSignal: (PointerSignalEvent _) =>
                          onCarteMolette?.call(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onCarteTap,
                        onPanUpdate: (DragUpdateDetails _) =>
                            onCarteGlisser?.call(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  ...buildMapOverlays(
                    scale: scale,
                    onSelect: onSelect ?? (MapScaleKind kind) {},
                    onWiden: () {},
                    error: null,
                    stations: avecAvis
                        ? const <StationPoint>[]
                        : <StationPoint>[_uneStation()],
                    ondeObservations: avecAvis
                        ? const <OndeStationCode, OndeObservation>{}
                        : _uneObservation(),
                    ondeUnreadableRows: 0,
                    onZoomIn: () {},
                    onZoomOut: () {},
                    onRecenter: () {},
                    onDesignateCenter: () {},
                    stationSheet: avecFiche
                        ? Container(
                            key: _ficheKey,
                            width: double.infinity,
                            height: _hauteurFiche,
                            color: Colors.red,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = avant;
    }
    if (!attendErreurs) {
      expect(
        erreurs,
        isEmpty,
        reason: erreurs.map((FlutterErrorDetails d) => '$d').join('\n'),
      );
    }
    return erreurs;
  }

  /// La fenêtre de la colonne du haut : ce qu'on voit de la colonne tient
  /// dedans, le reste est atteint en la faisant défiler.
  Rect fenetre(WidgetTester tester) =>
      tester.getRect(find.byType(SingleChildScrollView));

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  /// La partie VISIBLE de [finder] : sa boîte, coupée par la fenêtre de la
  /// colonne. `null` quand rien n'en dépasse dans la fenêtre.
  Rect? visible(WidgetTester tester, Finder finder) {
    final Rect r = rectOf(tester, finder).intersect(fenetre(tester));
    return (r.width <= 0 || r.height <= 0) ? null : r;
  }

  /// Les noms de [candidats] dont la boîte recoupe la partie visible de
  /// [piece].
  Set<String> recoupements(
    WidgetTester tester,
    Finder piece,
    Map<String, Finder> candidats,
  ) {
    final Rect? v = visible(tester, piece);
    if (v == null) {
      return <String>{};
    }
    return <String>{
      for (final MapEntry<String, Finder> c in candidats.entries)
        if (v.overlaps(rectOf(tester, c.value))) c.key,
    };
  }

  /// Les surcouches du bas, avec lesquelles la colonne du haut se superpose.
  final Map<String, Finder> bas = <String, Finder>{
    _controles: find.byType(MapControls),
    _designation: find.byType(DesignateCenterControl),
    _attribution: find.byType(IgnAttributionBadge),
  };

  /// L'avis affiché par l'état « carte vide » de [scale].
  Finder avis(MapScaleKind scale) => switch (scale) {
    MapScaleKind.ecoulement => find.byType(NoDataInAreaNotice),
    MapScaleKind.debit => find.byType(NoStationInAreaNotice),
  };

  String nom(Size size, double textScale, MapScaleKind scale) =>
      '${size.width.toInt()} × ${size.height.toInt()}, police '
      '${(textScale * 100).toInt()} %, échelle ${scale.name}';

  // ---------------------------------------------------------------------
  // Aucune erreur de rendu, avertissement et puces entiers dans l'écran
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      for (final MapScaleKind scale in MapScaleKind.values) {
        for (final bool avecFiche in <bool>[false, true]) {
          final String cas =
              '${nom(size, textScale, scale)}'
              '${avecFiche ? ', fiche de 320 px ouverte' : ''}';

          testWidgets('$cas : aucune erreur de rendu, avertissement et '
              'puces entiers dans l’écran', (WidgetTester tester) async {
            // `pumpOverlays` affirme l'absence de toute erreur de rendu.
            await pumpOverlays(
              tester,
              size,
              textScale: textScale,
              scale: scale,
              avecFiche: avecFiche,
            );

            final Rect ecran = Offset.zero & size;
            final Rect lien = rectOf(tester, find.byType(WarningLink));
            expect(
              ecran.intersect(lien),
              lien,
              reason: 'WarningLink hors de l’écran : $lien',
            );
            // Le libellé tient dans son contrôle, le contrôle dans l'écran.
            // `Rect.contains` exclut les bords droit et bas : l'inclusion se
            // vérifie par l'intersection.
            final Rect libelle = rectOf(tester, find.text(warningLinkLabel));
            expect(lien.intersect(libelle), libelle);
            for (final MapScaleKind kind in MapScaleKind.values) {
              final Finder puceFinder = find.byKey(
                ValueKey<MapScaleKind>(kind),
              );
              final Rect puce = rectOf(tester, puceFinder);
              expect(
                ecran.intersect(puce),
                puce,
                reason: 'puce ${kind.name} hors de l’écran : $puce',
              );
              final Rect texte = rectOf(
                tester,
                find.descendant(
                  of: puceFinder,
                  matching: find.text(mapScaleLabel(kind)),
                ),
              );
              expect(puce.intersect(texte), texte);
            }
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Gestes rendus à la carte
  // ---------------------------------------------------------------------
  group('gestes — à 360 × 640, 100 %, échelle écoulement, un avis affiché', () {
    /// Un point DANS la fenêtre de la colonne, à gauche du contrôle
    /// d'avertissement, hors de tout enfant de la colonne : de la carte
    /// visible, au sens de l'usager.
    Offset pointALaGaucheDuLien(WidgetTester tester) {
      final Rect colonne = fenetre(tester);
      final Rect lien = rectOf(tester, find.byType(WarningLink));
      final Offset p = Offset((colonne.left + lien.left) / 2, lien.center.dy);
      expect(colonne.contains(p), isTrue, reason: '$p hors de $colonne');
      for (final Finder enfant in <Finder>[
        find.byType(WarningLink),
        find.byType(MapScaleChips),
        find.byType(MapLegend),
        avis(MapScaleKind.ecoulement),
      ]) {
        expect(
          rectOf(tester, enfant).contains(p),
          isFalse,
          reason: '$p tombe dans un enfant de la colonne',
        );
      }
      return p;
    }

    testWidgets('un tap hors des enfants de la colonne atteint la carte', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpOverlays(
        tester,
        _petit,
        scale: MapScaleKind.ecoulement,
        onCarteTap: () => taps++,
      );

      await tester.tapAt(pointALaGaucheDuLien(tester));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('un cran de molette hors des enfants de la colonne atteint la '
        'carte', (WidgetTester tester) async {
      int crans = 0;
      await pumpOverlays(
        tester,
        _petit,
        scale: MapScaleKind.ecoulement,
        onCarteMolette: () => crans++,
      );
      final Offset p = pointALaGaucheDuLien(tester);

      final TestPointer souris = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(souris.hover(p));
      await tester.sendEventToBinding(souris.scroll(const Offset(0, -100)));
      await tester.pump();

      expect(crans, 1);
    });

    testWidgets('un glisser hors des enfants de la colonne atteint la carte', (
      WidgetTester tester,
    ) async {
      int glissers = 0;
      await pumpOverlays(
        tester,
        _petit,
        scale: MapScaleKind.ecoulement,
        onCarteGlisser: () => glissers++,
      );

      await tester.dragFrom(pointALaGaucheDuLien(tester), const Offset(0, 80));
      await tester.pump();

      expect(glissers, greaterThan(0));
    });

    testWidgets('un tap sur une puce atteint la puce, pas la carte', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      final List<MapScaleKind> choisies = <MapScaleKind>[];
      await pumpOverlays(
        tester,
        _petit,
        scale: MapScaleKind.ecoulement,
        onCarteTap: () => taps++,
        onSelect: choisies.add,
      );

      await tester.tap(
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      await tester.pump();

      expect(choisies, <MapScaleKind>[MapScaleKind.debit]);
      expect(taps, 0);
    });
  });

  // ---------------------------------------------------------------------
  // Ordre de la colonne : avertissement, puces, avis, puis légende
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgets(
        'ordre de la colonne à ${nom(size, 1, scale)} : avertissement, puces, '
        'avis, puis légende (la légende n’est repoussée que pendant qu’un '
        'avis s’affiche : écart à BR-008 accepté le 2026-10-03)',
        (WidgetTester tester) async {
          await pumpOverlays(tester, size, scale: scale);

          final Rect lien = rectOf(tester, find.byType(WarningLink));
          final Rect puces = rectOf(tester, find.byType(MapScaleChips));
          final Rect lAvis = rectOf(tester, avis(scale));
          final Rect legende = rectOf(tester, find.byType(MapLegend));

          expect(lien.bottom, lessThanOrEqualTo(puces.top));
          expect(
            puces.bottom,
            lessThanOrEqualTo(lAvis.top),
            reason: 'l’avis est sous les puces : $puces, $lAvis',
          );
          expect(
            lAvis.bottom,
            lessThanOrEqualTo(legende.top),
            reason: 'l’avis est au-dessus de la légende : $lAvis, $legende',
          );
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // Ordre de tabulation (`K2`) en disposition compacte
  // ---------------------------------------------------------------------
  // L'ordre visuel de la colonne compacte (avertissement en premier) n'est PAS
  // l'ordre de tabulation : les pièces sont construites une fois, avec leurs
  // `FocusTraversalOrder`, pour les deux dispositions. `map_keyboard_test.dart`
  // le vérifie sur `MapView` à 800 × 600 (large) ; ici, sous 600 px, sans
  // « carte » (aucun `FlutterMap` dans ce banc).
  for (final Size size in <Size>[_petit, _grand]) {
    for (final double textScale in <double>[1, 2]) {
      testWidgets(
        'Tab à ${nom(size, textScale, MapScaleKind.ecoulement)} : puces → '
        'contrôles de zoom → bouton de désignation → contrôle '
        'd’avertissement, puis reboucle',
        (WidgetTester tester) async {
          await pumpOverlays(
            tester,
            size,
            textScale: textScale,
            scale: MapScaleKind.ecoulement,
          );

          final List<Finder> ordreAttendu = <Finder>[
            find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
            find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
            find.byKey(mapZoomInButtonKey),
            find.byKey(mapZoomOutButtonKey),
            find.byKey(mapRecenterButtonKey),
            find.byKey(mapDesignateCenterButtonKey),
            find.byKey(warningLinkKey),
          ];
          for (final Finder attendu in ordreAttendu) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            expect(
              _focusedWithin(tester, attendu),
              isTrue,
              reason: 'attendu à ce Tab : $attendu',
            );
          }

          // Un Tab de plus reboucle sur le premier arrêt : rien de ce que Tab
          // atteint n'est resté hors de l'ordre déclaré.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(_focusedWithin(tester, ordreAttendu.first), isTrue);
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // Avis à 100 %
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    for (final MapScaleKind scale in MapScaleKind.values) {
      testWidgets(
        'à ${nom(size, 1, scale)}, AVEC un avis : l’avis est entier dans '
        'l’écran, libre de toute surcouche du bas, et son action « Élargir la '
        'recherche » est atteignable',
        (WidgetTester tester) async {
          await pumpOverlays(tester, size, scale: scale);

          final Rect ecran = Offset.zero & size;
          final Rect lAvis = rectOf(tester, avis(scale));
          final Rect colonne = fenetre(tester);
          expect(ecran.intersect(lAvis), lAvis, reason: 'hors écran : $lAvis');
          expect(
            colonne.intersect(lAvis),
            lAvis,
            reason: 'coupé par la fenêtre de la colonne : $lAvis, $colonne',
          );
          expect(
            recoupements(tester, avis(scale), bas),
            isEmpty,
            reason: 'avis=$lAvis',
          );
          // Marges de l'écran (à 360 × 640, « écoulement », la plus mince) :
          // l'avis (bas à 410) est à 14 px du bouton de désignation (haut à
          // 424) et à 18 px des contrôles (haut à 428) — l'affirmation est
          // stricte, mais une police plus large la ferait basculer.
          expect(
            find.text(widenSearchLabel).hitTestable().evaluate(),
            isNotEmpty,
            reason: 'action=${rectOf(tester, find.text(widenSearchLabel))}',
          );
        },
      );
    }
  }

  // ---------------------------------------------------------------------
  // Légende à 100 %
  // ---------------------------------------------------------------------
  for (final Size size in <Size>[_petit, _grand]) {
    testWidgets(
      'à ${nom(size, 1, MapScaleKind.ecoulement)}, SANS avis : la légende est '
      'entière, dans l’écran, et ne recoupe ni les contrôles de zoom, ni le '
      'bouton de désignation, ni l’attribution',
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          size,
          scale: MapScaleKind.ecoulement,
          avecAvis: false,
        );

        final Rect ecran = Offset.zero & size;
        final Rect legende = rectOf(tester, find.byType(MapLegend));
        final Rect colonne = fenetre(tester);
        expect(ecran.intersect(legende), legende, reason: 'hors écran');
        expect(
          colonne.intersect(legende),
          legende,
          reason: 'coupée par la fenêtre de la colonne : $legende, $colonne',
        );
        expect(
          recoupements(tester, find.byType(MapLegend), bas),
          isEmpty,
          reason: 'légende=$legende',
        );
      },
    );
  }

  // `(taille, légende coupée par la fenêtre, ce que la légende recoupe)`.
  //
  // ⚠️ Tenus de PEU, donc les premiers à basculer — et leur bascule
  // n'apprendrait rien de plus (quelques pixels de police ou de marge) :
  // - 360 × 640 : la fenêtre coupe la légende de 14 px (646 contre 632) ;
  // - 390 × 844 : la légende recoupe les contrôles de 12 px (644 contre 632)
  //   et ne recoupe PAS le bouton de désignation, à 4 px près (644 contre 648).
  for (final (Size, bool, Set<String>) cas in <(Size, bool, Set<String>)>[
    (_petit, true, <String>{_controles, _designation, _attribution}),
    (_grand, false, <String>{_controles}),
  ]) {
    testWidgets(
      'CONSTAT — à ${nom(cas.$1, 1, MapScaleKind.debit)}, SANS avis : la '
      'légende « débit » (paragraphe de BR-003, 468 px de haut) recoupe : '
      '${cas.$3.join(', ')}${cas.$2 ? ', et sa fenêtre la coupe' : ''}',
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          cas.$1,
          scale: MapScaleKind.debit,
          avecAvis: false,
        );

        // ⚠️ Ce test verrouille un FAIT CONSTATÉ, pas un invariant voulu : si
        // la légende « débit » cesse de recouper ces surcouches, l'écran
        // s'est amélioré — corriger ce test À LA MAIN pour le dire.
        final Rect legende = rectOf(tester, find.byType(MapLegend));
        final Rect colonne = fenetre(tester);
        expect(
          legende.bottom > colonne.bottom,
          cas.$2,
          reason: 'légende=$legende, fenêtre=$colonne',
        );
        expect(
          recoupements(tester, find.byType(MapLegend), bas),
          cas.$3,
          reason: 'légende=$legende',
        );
      },
    );
  }

  // `(taille, échelle, légende coupée par la fenêtre, ce que la légende
  // recoupe)`, AVEC un avis : la légende, repoussée sous lui.
  //
  // ⚠️ Tenus de PEU, donc les premiers à basculer — leur bascule n'apprendrait
  // rien de plus :
  // - 360 × 640 écoulement : la légende ne recoupe PAS l'attribution, à 13 px
  //   près (583 contre 596) ;
  // - 390 × 844 débit : la fenêtre coupe la légende de 10 px (846 contre 836),
  //   qui dépasse même l'écran de 2 px (844).
  for (final (Size, MapScaleKind, bool, Set<String>) cas
      in <(Size, MapScaleKind, bool, Set<String>)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          false,
          <String>{_controles, _designation},
        ),
        (
          _petit,
          MapScaleKind.debit,
          true,
          <String>{_controles, _designation, _attribution},
        ),
        (_grand, MapScaleKind.ecoulement, false, <String>{}),
        (
          _grand,
          MapScaleKind.debit,
          true,
          <String>{_controles, _designation, _attribution},
        ),
      ]) {
    testWidgets(
      'CONSTAT — à ${nom(cas.$1, 1, cas.$2)}, AVEC un avis : la légende, '
      'repoussée sous l’avis, '
      '${cas.$4.isEmpty ? 'ne recoupe aucune surcouche du bas' : 'recoupe '
                '${cas.$4.join(', ')}'}'
      '${cas.$3 ? ', et sa fenêtre la coupe' : ''}',
      (WidgetTester tester) async {
        await pumpOverlays(tester, cas.$1, scale: cas.$2);

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu — voir plus haut. C'est
        // l'écart à `BR-008` accepté le 2026-10-03 : un avis repousse la
        // légende.
        final Rect legende = rectOf(tester, find.byType(MapLegend));
        final Rect colonne = fenetre(tester);
        expect(
          legende.bottom > colonne.bottom,
          cas.$3,
          reason: 'légende=$legende, fenêtre=$colonne',
        );
        expect(
          recoupements(tester, find.byType(MapLegend), bas),
          cas.$4,
          reason: 'légende=$legende',
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Seuil de la disposition compacte
  // ---------------------------------------------------------------------
  testWidgets('à 599 px de large la disposition est compacte : la légende est '
      'SOUS les puces', (WidgetTester tester) async {
    await pumpOverlays(
      tester,
      const Size(599, 900),
      scale: MapScaleKind.ecoulement,
    );

    final Rect puces = rectOf(tester, find.byType(MapScaleChips));
    final Rect legende = rectOf(tester, find.byType(MapLegend));
    expect(puces.bottom, lessThanOrEqualTo(legende.top));
  });

  testWidgets('à 600 px de large la disposition est large : la légende est À '
      'DROITE des puces, en haut', (WidgetTester tester) async {
    await pumpOverlays(
      tester,
      const Size(600, 900),
      scale: MapScaleKind.ecoulement,
    );

    final Rect puces = rectOf(tester, find.byType(MapScaleChips));
    final Rect legende = rectOf(tester, find.byType(MapLegend));
    expect(puces.right, lessThanOrEqualTo(legende.left));
    expect(puces.top, lessThan(legende.top));
  });

  // ---------------------------------------------------------------------
  // Disposition LARGE, téléphone en paysage : défaut antérieur, non corrigé
  // ---------------------------------------------------------------------
  testWidgets(
    'CONSTAT — disposition LARGE à 600 × 360 (téléphone en paysage), police '
    '100 %, avis affiché : la colonne gauche (puces et avis) déborde de 21 px '
    'par le bas — défaut antérieur à la colonne compacte, non corrigé',
    (WidgetTester tester) async {
      const Size taille = Size(600, 360);
      final List<FlutterErrorDetails> erreurs = await pumpOverlays(
        tester,
        taille,
        scale: MapScaleKind.ecoulement,
        attendErreurs: true,
      );

      // ⚠️ FAIT CONSTATÉ, pas un invariant voulu. À partir de 600 px de
      // large, la colonne gauche n'est pas défilante : quand la hauteur
      // manque, elle déborde. Elle ne passe pas par la colonne compacte, que
      // ce changement n'a pas touchée.
      expect(erreurs, hasLength(1));
      expect('${erreurs.single}', contains('map_view.dart'));
      final RegExpMatch? m = RegExp(
        r'overflowed by ([0-9.]+) pixels on the bottom',
      ).firstMatch(erreurs.single.exceptionAsString());
      expect(m, isNotNull, reason: erreurs.single.exceptionAsString());
      // Le débordement est exactement celui de la colonne gauche : le bas de
      // l'avis, plus la marge de 8 px, moins la hauteur de l'écran.
      final Rect lAvis = rectOf(tester, avis(MapScaleKind.ecoulement));
      expect(
        double.parse(m!.group(1)!),
        closeTo(lAvis.bottom + 8 - taille.height, 0.5),
        reason: 'avis=$lAvis',
      );
    },
  );

  // ---------------------------------------------------------------------
  // Légende à 200 %
  // ---------------------------------------------------------------------
  /// Où en est [finder] dans la fenêtre de la colonne : « cachée », « en
  /// partie » ou « entière ».
  String etat(WidgetTester tester, Finder finder) {
    final Rect? v = visible(tester, finder);
    if (v == null) {
      return 'cachée';
    }
    return v == rectOf(tester, finder) ? 'entière' : 'en partie';
  }

  /// Ce que la colonne doit défiler pour que le BORD BAS de la légende arrive
  /// au bord bas de la fenêtre ; 0 quand elle n'a rien à défiler.
  double adefiler(WidgetTester tester) => math.max(
    0,
    rectOf(tester, find.byType(MapLegend)).bottom - fenetre(tester).bottom,
  );

  /// Fait défiler la colonne DU DOIGT de [distance], depuis le bout droit de la
  /// puce « débit » — hors de la boîte du bouton de désignation, qui recouvre
  /// le reste de la puce à 360 × 640 : la colonne ne capte les gestes que sur
  /// ses enfants. Le doigt perd `kDragSlopDefault` avant que la colonne ne
  /// suive.
  Future<void> defilerDuDoigt(WidgetTester tester, double distance) async {
    final Rect puce = rectOf(
      tester,
      find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
    );
    await tester.dragFrom(
      Offset(puce.right - 12, puce.center.dy),
      Offset(0, -(distance + kDragSlopDefault)),
    );
    await tester.pumpAndSettle();
  }

  // Affirmation stricte : quand la légende dépasse le bas de la fenêtre,
  // faire défiler la colonne en amène le bord bas dans la fenêtre, et elle y
  // tient entière si elle est plus basse que la fenêtre n'est haute. Sans
  // table de valeurs mesurées : tout vient de la géométrie du test. Le cas
  // 390 × 844, écoulement, sans avis n'est pas là : rien n'y défile (voir le
  // CONSTAT ci-dessous).
  for (final (Size, MapScaleKind, bool) cas in <(Size, MapScaleKind, bool)>[
    (_petit, MapScaleKind.ecoulement, true),
    (_petit, MapScaleKind.debit, true),
    (_grand, MapScaleKind.ecoulement, true),
    (_grand, MapScaleKind.debit, true),
    (_petit, MapScaleKind.ecoulement, false),
    (_petit, MapScaleKind.debit, false),
    (_grand, MapScaleKind.debit, false),
  ]) {
    testWidgets(
      'à ${nom(cas.$1, 2, cas.$2)}${cas.$3 ? ', AVEC un avis' : ', SANS avis'}'
      ' : faire défiler la colonne amène le bord bas de la légende dans la '
      'fenêtre',
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: cas.$2,
          avecAvis: cas.$3,
        );

        final Rect colonne = fenetre(tester);
        Rect legende() => rectOf(tester, find.byType(MapLegend));
        final double distance = adefiler(tester);
        final double basAvant = legende().bottom;
        expect(
          distance,
          greaterThan(0),
          reason: 'rien à défiler : fenêtre=$colonne, légende=${legende()}',
        );

        await defilerDuDoigt(tester, distance);

        expect(
          basAvant - legende().bottom,
          greaterThan(0),
          reason: 'la colonne n’a pas défilé : légende=${legende()}',
        );
        expect(
          legende().bottom,
          lessThanOrEqualTo(colonne.bottom + 0.5),
          reason: 'après défilement : fenêtre=$colonne, légende=${legende()}',
        );
        final bool entiere =
            legende().top >= colonne.top && legende().bottom <= colonne.bottom;
        expect(
          entiere,
          legende().height <= colonne.height,
          reason: 'après défilement : fenêtre=$colonne, légende=${legende()}',
        );
      },
    );
  }

  // `(taille, échelle, avec un avis, légende au repos, ce qu'elle recoupe une
  // fois amenée au bord bas de la fenêtre — sans rien défiler quand elle y est
  // déjà)`.
  for (final (Size, MapScaleKind, bool, String, Set<String>) cas
      in <(Size, MapScaleKind, bool, String, Set<String>)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          true,
          'cachée',
          <String>{_controles, _designation, _attribution},
        ),
        (
          _petit,
          MapScaleKind.debit,
          true,
          'cachée',
          <String>{_controles, _designation, _attribution},
        ),
        (
          _grand,
          MapScaleKind.ecoulement,
          true,
          'cachée',
          <String>{_controles, _designation, _attribution},
        ),
        (
          _grand,
          MapScaleKind.debit,
          true,
          'cachée',
          <String>{_controles, _designation, _attribution},
        ),
        (
          _petit,
          MapScaleKind.ecoulement,
          false,
          'en partie',
          <String>{_controles, _designation, _attribution},
        ),
        (
          _petit,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{_controles, _designation, _attribution},
        ),
        // Le seul cas où la légende est entière au repos : rien à défiler.
        (
          _grand,
          MapScaleKind.ecoulement,
          false,
          'entière',
          <String>{_controles, _designation},
        ),
        (
          _grand,
          MapScaleKind.debit,
          false,
          'en partie',
          <String>{_controles, _designation, _attribution},
        ),
      ]) {
    testWidgets(
      'CONSTAT — à ${nom(cas.$1, 2, cas.$2)}${cas.$3 ? ', AVEC un avis' : ', SANS avis'}'
      ' : au repos la légende est ${cas.$4} ; amenée dans la fenêtre, elle '
      'recoupe ${cas.$5.join(', ')}',
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          cas.$1,
          textScale: 2,
          scale: cas.$2,
          avecAvis: cas.$3,
        );

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : même amenée dans la
        // fenêtre, la légende passe sous le bouton de désignation et les
        // contrôles (posés au-dessus de la colonne dans la pile).
        expect(
          etat(tester, find.byType(MapLegend)),
          cas.$4,
          reason:
              'au repos : fenêtre=${fenetre(tester)}, '
              'légende=${rectOf(tester, find.byType(MapLegend))}',
        );
        final double distance = adefiler(tester);
        if (distance > 0) {
          await defilerDuDoigt(tester, distance);
        }
        expect(
          recoupements(tester, find.byType(MapLegend), bas),
          cas.$5,
          reason:
              'après défilement : '
              'légende=${rectOf(tester, find.byType(MapLegend))}',
        );
      },
    );
  }

  // `(taille, échelle, ce que l'avis recoupe au repos, contrôle
  // d'avertissement et puces atteignables à leur centre)`. À 200 % l'avis
  // (677 px à 360 × 640) n'est jamais entier au repos, et son action
  // « Élargir la recherche » n'est atteignable dans aucun des quatre cas.
  for (final (Size, MapScaleKind, Set<String>, bool) cas
      in <(Size, MapScaleKind, Set<String>, bool)>[
        (
          _petit,
          MapScaleKind.ecoulement,
          <String>{_controles, _designation, _attribution},
          false,
        ),
        (
          _petit,
          MapScaleKind.debit,
          <String>{_controles, _designation, _attribution},
          false,
        ),
        // À 390 × 844 le contrôle et les puces ne sont atteignables qu'à 7 px
        // de la boîte du bouton de désignation (puces 96–238, bouton 245–731).
        (
          _grand,
          MapScaleKind.ecoulement,
          <String>{_controles, _designation, _attribution},
          true,
        ),
        (
          _grand,
          MapScaleKind.debit,
          <String>{_controles, _designation, _attribution},
          true,
        ),
      ]) {
    testWidgets(
      'CONSTAT — à ${nom(cas.$1, 2, cas.$2)}, AVEC un avis : l’avis, jamais '
      'entier au repos, recoupe ${cas.$3.join(', ')} et son action n’est pas '
      'atteignable ; le contrôle d’avertissement et les puces '
      '${cas.$4 ? 'sont atteignables' : 'sont recouverts par le bouton de '
                'désignation : leur centre n’est pas atteignable'}',
      (WidgetTester tester) async {
        await pumpOverlays(tester, cas.$1, textScale: 2, scale: cas.$2);

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu : à 200 %, le bouton de
        // désignation, posé au-dessus de la colonne du haut, la recouvre ;
        // à 360 × 640 il recouvre jusqu'au contrôle d'avertissement
        // (`BR-012` : le contrôle doit rester utilisable). Corriger ce test
        // À LA MAIN quand l'écran sera repris.
        final Finder lAvis = avis(cas.$2);
        expect(
          etat(tester, lAvis),
          'en partie',
          reason: 'avis=${rectOf(tester, lAvis)}, fenêtre=${fenetre(tester)}',
        );
        expect(
          recoupements(tester, lAvis, bas),
          cas.$3,
          reason: 'avis=${rectOf(tester, lAvis)}',
        );
        expect(
          find.byKey(widenSearchKey).hitTestable().evaluate(),
          isEmpty,
          reason: 'action=${rectOf(tester, find.byKey(widenSearchKey))}',
        );
        // Le centre du contrôle d'avertissement et celui de chaque puce : le
        // même constat pour les trois.
        final Map<String, Finder> atteignables = <String, Finder>{
          'WarningLink': find.byType(WarningLink),
          for (final MapScaleKind kind in MapScaleKind.values)
            'puce ${kind.name}': find.byKey(ValueKey<MapScaleKind>(kind)),
        };
        for (final MapEntry<String, Finder> e in atteignables.entries) {
          expect(
            e.value.hitTestable().evaluate().isNotEmpty,
            cas.$4,
            reason:
                '${e.key}=${rectOf(tester, e.value)}, bouton de désignation='
                '${rectOf(tester, find.byType(DesignateCenterControl))}',
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------
  // Fiche de 320 px ouverte : ce que la fiche recoupe en haut
  // ---------------------------------------------------------------------
  const String lienNom = 'WarningLink';
  const String pucesNom = 'MapScaleChips';
  const String legendeNom = 'MapLegend';
  const String avisNom = 'avis';
  // `(taille, police, échelle, ce que la fiche recoupe parmi les pièces du haut)`.
  //
  // ⚠️ Tenus de PEU, donc les premiers à basculer — leur bascule n'apprendrait
  // rien de plus :
  // - 360 × 640, 100 %, écoulement : la fiche (bas à 416) ne recoupe PAS la
  //   légende (haut à 418), à 2 px près ;
  // - 360 × 640, 100 %, débit : la fiche recoupe la légende de 17 px
  //   seulement.
  for (final (Size, double, MapScaleKind, Set<String>) cas
      in <(Size, double, MapScaleKind, Set<String>)>[
        (_petit, 1, MapScaleKind.ecoulement, <String>{pucesNom, avisNom}),
        (
          _petit,
          1,
          MapScaleKind.debit,
          <String>{pucesNom, avisNom, legendeNom},
        ),
        (
          _petit,
          2,
          MapScaleKind.ecoulement,
          <String>{lienNom, pucesNom, avisNom},
        ),
        (_petit, 2, MapScaleKind.debit, <String>{lienNom, pucesNom, avisNom}),
        (_grand, 1, MapScaleKind.ecoulement, <String>{avisNom, legendeNom}),
        (_grand, 1, MapScaleKind.debit, <String>{avisNom, legendeNom}),
        (
          _grand,
          2,
          MapScaleKind.ecoulement,
          <String>{lienNom, pucesNom, avisNom},
        ),
        (_grand, 2, MapScaleKind.debit, <String>{lienNom, pucesNom, avisNom}),
      ]) {
    testWidgets(
      'CONSTAT — fiche de 320 px à ${nom(cas.$1, cas.$2, cas.$3)} : la fiche '
      'recouvre ${cas.$4.join(', ')}',
      (WidgetTester tester) async {
        await pumpOverlays(
          tester,
          cas.$1,
          textScale: cas.$2,
          scale: cas.$3,
          avecFiche: true,
        );

        // ⚠️ FAIT CONSTATÉ, pas un invariant voulu (arbitrage du
        // 2026-10-03 : à ne pas corriger ici). Si une pièce cesse d'être
        // recouverte, corriger ce test À LA MAIN pour le dire.
        final Rect fiche = rectOf(tester, find.byKey(_ficheKey));
        final Map<String, Finder> haut = <String, Finder>{
          lienNom: find.byType(WarningLink),
          pucesNom: find.byType(MapScaleChips),
          avisNom: avis(cas.$3),
          legendeNom: find.byType(MapLegend),
        };
        final Set<String> recouvertes = <String>{
          for (final MapEntry<String, Finder> p in haut.entries)
            if (visible(tester, p.value)?.overlaps(fiche) ?? false) p.key,
        };
        expect(recouvertes, cas.$4, reason: 'fiche=$fiche');
      },
    );
  }
}
