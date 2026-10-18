// La mesure des pièces de la carte (`S6` d'Ergonomie, porte de faisabilité de
// l'arbitrage 11) : chaque VRAIE pièce déjà livrée (`S1` à `S4`) est montée en
// Roboto, et ses hauteurs intrinsèques sont lues à la largeur qu'elle aura dans
// la mise en page (spec § 5.1) ; elles forment l'entrée de `allocateMapLayout`
// (`S5`). `S6` s'en sert pour vérifier qu'aux quatre tailles garanties rien de
// ce qui ne cède jamais ne déborde — sauf là où la partie fixe du bloc défile
// (arbitrages 13, 18 et 19 du commanditaire, 2026-10-18) ; `D2` (I-g) et
// `D3`, pour savoir quels replis jouent à une configuration.
//
// Les hauteurs sont lues par `getMinIntrinsicHeight` / `getMaxIntrinsicHeight`
// À LA LARGEUR CALCULÉE, sur des pièces montées dans un arbre assez grand pour
// ne rien couper : c'est exactement ce que fera `RenderMapLayout` (`D1`), qui
// lit les intrinsèques de ses enfants aux largeurs de la carte visible avant
// de les poser. Les règles de largeur et de recouvrement sont celles de
// `mapLayoutWidths` (`lib/`, `D1`), que les deux appellent — une seule source.
//
// La PARTIE FIXE du bloc est la vraie pièce, `MapReadingBlockFixed` (`B1`) :
// ses hauteurs intrinsèques sont celles du sélecteur plus l'en-tête, sans écart
// ni marge — celles que `S6` a mesurées avant elle, et qu'un test de `B1`
// verrouille.
//
// Le BAS est le vrai bas de la carte, `MapBottom` (`D2`) — la rangée en
// compact, la colonne au-delà, l'attribution dessous —, celui que
// `buildMapOverlays` pose : la mesure ne peut plus dériver de l'écran. L'AVIS
// est mesuré nu, comme le bloc le pose (`MapReadingBlockNotices`) ; l'appelant
// peut passer celui que la carte pose pour sa lecture (`avis`).
//
// Ce que ce fichier compose lui-même quand l'appelant ne fournit pas la vraie
// fiche ([mesurerPieces] sans `ficheReelle`) :
// - l'EN-TÊTE d'une fiche à étoile, mesuré au pire : avec l'avis d'échec
//   d'écriture du favori, épinglé sous lui (spec § 6.1 : il ne cède jamais) ;
// - les CORPS des fiches : une recopie approchée des fiches (station, point
//   ONDE, tronçon), pour leur hauteur entière (repli 2) et leur mesure mise
//   en avant (arbitrage 18, `D7`).
//
// La hauteur MISE EN AVANT de la fiche (`D7`) se lit par
// `sheetFeaturedHeightOf`, comme la pose la lit ; le PLANCHER de la partie
// fixe est la cible tactile de la plateforme du test (`minimumTapTarget`,
// arbitrage 19).
// `D5` a constaté l'écart : le corps approché de la station est plus bas que
// la vraie fiche de `F1` (ses tuiles) ; 21 configurations sur 432 de
// `ergonomie_budget_test.dart` jouent le repli 2 avec la vraie, pas avec lui.
// La porte (`ergonomie_budget_test.dart`) et I-g
// (`map_layout_invariants_test.dart`) mesurent donc les VRAIES fiches, par
// `ficheReelle` ; les corps approchés ne servent plus qu'aux appelants qui
// n'en passent pas (`map_layout_test.dart`).
//
// dart:io n'est pas employé ici ; la police vient de `chargerRoboto`, que
// l'appelant charge dans son `setUpAll`.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show floodWarningWindowText;
import 'package:martinpecheur/features/flood_sheet/view/flood_warning_card.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/map_bottom.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart'
    show ondeHistoriqueTitre, ondeModalitePrefix, ondeSheetNature;
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart'
    show ondeSeasonNotice;
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart'
    show readingColumnWidth;
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

import 'layout_sizes.dart';

/// La fiche station de Blois : nature, code, étoile (spec § 6.1).
const ({String nature, bool etoile}) ficheStation = (
  nature: 'Station hydrométrique · K447001001',
  etoile: true,
);

/// La fiche tronçon : nature seule, sans code ni étoile (spec § 6.4, avant T5).
const ({String nature, bool etoile}) ficheTroncon = (
  nature: 'Tronçon $floodSourceName',
  etoile: false,
);

/// La fiche d'un point ONDE : « Point ONDE », sans code, avec étoile (spec
/// § 6.1, § 11.2). Décision 3 de `D7` : elle entre dans la matrice de la
/// porte, son en-tête et sa mesure mise en avant dépassant ceux de la station
/// à 200 %.
const ({String nature, bool etoile}) ficheOnde = (
  nature: ondeSheetNature,
  etoile: true,
);

/// La bande du réticule : le réticule et sa marge, au-dessus et au-dessous
/// (spec § 5.6). La valeur que `D2` passe à `MapLayout.reticleBandHeight`.
const double _hauteurBandeReticule =
    mapCenterReticleSize + 2 * margeDeSurcouche;

// --- Les mesures -------------------------------------------------------------

const Key _cleFixe = Key('mesure-partie-fixe');
const Key _cleAvis = Key('mesure-avis');
const Key _cleLegende = Key('mesure-legende');
const Key _cleBas = Key('mesure-bas');
const Key _cleBande = Key('mesure-bande');
const Key _cleFiche = Key('mesure-fiche');

/// Date fixe de la carte de vigilance citée par la légende Crues : la légende
/// la plus haute est celle qui la cite (arbitrage 9 de T4).
final DateTime _dateVigilance = DateTime.utc(2026, 10, 17, 14, 30);

Duration _utc(DateTime instant) => Duration.zero;

/// Le corps approché de la fiche de nature [nature] : tronçon, point ONDE, et
/// station pour toute autre nature.
Widget _corpsApproche(String nature) => switch (nature) {
  ondeSheetNature => const _CorpsFicheOnde(),
  _ when nature == ficheTroncon.nature => const _CorpsFicheTroncon(),
  _ => const _CorpsFicheStation(),
};

/// Monte chaque pièce de la configuration seule, lit ses hauteurs
/// intrinsèques à sa largeur et rend l'entrée de `allocateMapLayout`.
///
/// La plateforme est celle que le test a fixée (`testWidgetsOnWindows`,
/// `testWidgetsOnAndroid`) : elle décide de la cible tactile (44 ou 48) et de
/// la typographie. [fiche] nulle : aucune fiche ouverte ; sinon, seule CETTE
/// fiche est mesurée — un `SheetFrame` de sa nature, son étoile si elle en
/// porte une (avec l'avis d'échec d'écriture, le pire en-tête), et un corps
/// approché choisi par sa nature (station, point ONDE, tronçon).
///
/// [avis] : l'avis mesuré, nu — par défaut l'avis d'absence de l'écoulement
/// (`NoDataInAreaNotice`) ; `D2` (I-g) y passe l'avis que la carte pose pour
/// la lecture éprouvée, pour que la mesure décrive l'écran.
///
/// [ficheReelle] (`D5`) : la VRAIE fiche à mesurer à la place du cadre
/// composé ici — le panneau même que l'écran éprouvé pose (I-g, fiche
/// ouverte). [fiche] reste requise : elle dit qu'une fiche est ouverte.
///
/// ⚠️ Elle REMPLACE l'arbre monté (`pumpWidget`) et pose, le temps de la
/// mesure, une vue de 2 400 × 4 000 : à appeler AVANT de monter l'écran
/// éprouvé, jamais après. Elle rétablit, en sortant, la taille et la densité
/// de la vue qu'elle a trouvées.
Future<MapLayoutInput> mesurerPieces(
  WidgetTester tester, {
  required Size taille,
  required double echelle,
  required MapScaleKind lecture,
  required bool enMode,
  required ({String nature, bool etoile})? fiche,
  required bool avecAvis,
  required EdgeInsets marge,
  Widget? avis,
  Widget? ficheReelle,
}) async {
  final Size vueTrouvee = tester.view.physicalSize;
  final double densiteTrouvee = tester.view.devicePixelRatio;
  // Une surface assez grande pour que rien ne déborde à la pose : seules les
  // intrinsèques comptent, lues ensuite à la largeur de chaque pièce.
  tester.view.physicalSize = const Size(2400, 4000);
  tester.view.devicePixelRatio = 1;
  try {
    return await _mesurer(
      tester,
      taille: taille,
      echelle: echelle,
      lecture: lecture,
      enMode: enMode,
      fiche: fiche,
      avecAvis: avecAvis,
      marge: marge,
      avis: avis,
      ficheReelle: ficheReelle,
    );
  } finally {
    tester.view.physicalSize = vueTrouvee;
    tester.view.devicePixelRatio = densiteTrouvee;
  }
}

Future<MapLayoutInput> _mesurer(
  WidgetTester tester, {
  required Size taille,
  required double echelle,
  required MapScaleKind lecture,
  required bool enMode,
  required ({String nature, bool etoile})? fiche,
  required bool avecAvis,
  required EdgeInsets marge,
  required Widget? avis,
  required Widget? ficheReelle,
}) async {
  assert(
    ficheReelle == null || fiche != null,
    'une fiche réelle à mesurer est une fiche ouverte : fiche requise',
  );
  final bool compact = switch (mapLayoutWidthFor(taille.width)) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  };
  final bool ficheOuverte = fiche != null;
  void rien() {}

  // Le VRAI bas de la carte (`D2`) : celui que `buildMapOverlays` pose.
  final Widget bas = SizedBox(
    key: _cleBas,
    child: MapBottom(
      compact: compact,
      onOpenFilters: rien,
      onOpenFavorites: rien,
      filterActive: false,
      onZoomIn: rien,
      onZoomOut: rien,
      onRecenter: rien,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: taille,
          textScaler: TextScaler.linear(echelle),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  key: _cleFixe,
                  child: MapReadingBlockFixed(
                    selector: MapReadingSelector(
                      scale: lecture,
                      onSelect: (MapScaleKind _) {},
                      designationMode: enMode,
                      onToggleDesignationMode: rien,
                    ),
                    header: MapLegendHeader(
                      scale: lecture,
                      warningLink: WarningLink(
                        extraText: switch (lecture) {
                          MapScaleKind.crues => floodWarningWindowText,
                          MapScaleKind.ecoulement => null,
                          MapScaleKind.debit => null,
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  key: _cleAvis,
                  child: avis ?? NoDataInAreaNotice(onWiden: rien),
                ),
                SizedBox(
                  key: _cleLegende,
                  child: MapLegend(
                    scale: lecture,
                    inBlock: true,
                    floodInformationDate: _dateVigilance,
                    utcOffsetOf: _utc,
                  ),
                ),
                bas,
                SizedBox(
                  key: _cleBande,
                  child: DesignationBand(onDesignate: rien),
                ),
                if (fiche != null)
                  SizedBox(
                    key: _cleFiche,
                    // La vraie fiche quand l'appelant la fournit (`D5`, I-g) ;
                    // sinon le cadre composé ici, au pire en-tête.
                    child:
                        ficheReelle ??
                        SheetFrame(
                          nature: fiche.nature,
                          closeButtonKey: const Key('mesure-fermer'),
                          onClose: rien,
                          // L'en-tête le plus haut : l'avis d'échec d'écriture
                          // du favori s'épingle sous lui (spec § 6.1). Étoile vide :
                          // l'avis d'un ajout en échec, le plus long des deux.
                          favoriteStar: fiche.etoile
                              ? const FavoriteStar(
                                  filled: false,
                                  enabled: true,
                                  writeFailed: true,
                                )
                              : null,
                          onToggleFavorite: fiche.etoile ? rien : null,
                          body: _corpsApproche(fiche.nature),
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  RenderBox boite(Key cle) => tester.renderObject<RenderBox>(find.byKey(cle));
  PieceHeights deux(Key cle, double largeur) => PieceHeights(
    min: boite(cle).getMinIntrinsicHeight(largeur),
    max: boite(cle).getMaxIntrinsicHeight(largeur),
  );
  double une(Key cle, double largeur) {
    final PieceHeights h = deux(cle, largeur);
    expect(
      h.min,
      moreOrLessEquals(h.max),
      reason: '$cle : une pièce qui ne se replie pas dit min = max',
    );
    return h.max;
  }

  // Les largeurs : la même fonction que `RenderMapLayout` (`D1`), seule source
  // des règles de largeur (spec § 5.1, § 5.5, § 6.5).
  final MapLayoutWidths largeurs = mapLayoutWidths(
    width: taille.width,
    sheetOpen: ficheOuverte,
    bottomMaxIntrinsicWidth: boite(_cleBas)
        .getMaxIntrinsicWidth(double.infinity),
    bandMinIntrinsicWidth: boite(_cleBande)
        .getMinIntrinsicWidth(double.infinity),
    padding: margeDeSurcouche,
    reticleWidth: mapCenterReticleSize,
  );
  // La largeur où la zone des fiches pose la fiche (`MapSheetArea`) : celle
  // du panneau, ou celle de la fiche du bas plafonnée à la largeur de lecture
  // (R18) — `M6` de la relecture de `D5`.
  final double largeurFiche = switch (largeurs.width) {
    MapLayoutWidth.panel => largeurs.sheet,
    MapLayoutWidth.compact ||
    MapLayoutWidth.wide => math.min(largeurs.sheet, readingColumnWidth),
  };
  return MapLayoutInput(
    available: mapLayoutAvailableHeight(
      safeHeight: taille.height - marge.vertical,
      width: largeurs.width,
      sheetOpen: ficheOuverte,
      padding: margeDeSurcouche,
    ),
    width: largeurs.width,
    blockOverBottom: largeurs.blockOverBottom,
    bandFits: largeurs.bandFits,
    reticleUnderBlock: largeurs.reticleUnderBlock,
    designation: enMode,
    sheetOpen: ficheOuverte,
    blockFixed: deux(_cleFixe, largeurs.block),
    notices: avecAvis ? une(_cleAvis, largeurs.block) : 0,
    legend: une(_cleLegende, largeurs.block),
    // Le bas : la rangée ne cède jamais (min = max) ; la colonne dit sa
    // hauteur repliée — l'attribution et son écart, sous ses boutons qui
    // défilent (arbitrage 24, `D8`).
    bottom: compact
        ? PieceHeights.fixed(une(_cleBas, largeurs.bottom))
        : deux(_cleBas, largeurs.bottom),
    // Une bande qui ne tient pas n'a pas de hauteur à dire : fiche ouverte,
    // `allocateMapLayout` la retire (repli 6 étendu, arbitrage 14).
    band: enMode && largeurs.bandFits
        ? deux(_cleBande, largeurs.band)
        : PieceHeights.none,
    reticleBand: enMode ? _hauteurBandeReticule : 0,
    sheet: fiche == null ? PieceHeights.none : deux(_cleFiche, largeurFiche),
    // Le plancher de la partie fixe : la cible tactile de la plateforme du
    // test (arbitrage 19), comme la pose la lit.
    blockFixedFloor: minimumTapTarget,
    // La hauteur mise en avant de la fiche (arbitrage 18), lue comme la pose
    // la lit : au travers de l'enveloppe de mesure, sur le cadre.
    sheetFeatured: fiche == null
        ? 0
        : sheetFeaturedHeightOf(boite(_cleFiche), largeurFiche),
    // La première rangée de l'en-tête (arbitrage 24, `D8`), lue comme la pose
    // la lit.
    sheetFirstRow: fiche == null
        ? 0
        : sheetFirstRowHeightOf(boite(_cleFiche), largeurFiche),
    gap: margeDeSurcouche,
  );
}

// --- Les corps approchés des fiches ------------------------------------------
//
// Une recopie APPROCHÉE des fiches actuelles, sans leur ViewModel : elle ne
// sert qu'à leur hauteur entière (repli 2) et, depuis `D7`, à leur mesure
// mise en avant (arbitrage 18) — ce qui suit cette mesure est enveloppé dans
// `NoMinIntrinsicHeight`, comme dans la vraie fiche. Le contrôle
// « ⚠ Avertissement », passé dans l'en-tête du cadre (`S3`), n'y est plus.

/// Le corps de la fiche station de Blois, dans l'ordre de
/// `station_summary_sheet.dart` : libellé, cours d'eau, département, débit et
/// hauteur datés et sourcés, statut, qualification.
class _CorpsFicheStation extends StatelessWidget {
  const _CorpsFicheStation();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'La Loire à Blois',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text('La Loire'),
        Text('Département 41'),
        SizedBox(height: 8),
        Text(
          'Débit : 47,8 m³/s — mesuré le 17/10/2026 à 14:30 — '
          '$hydrometrieSourceName',
        ),
        // La mesure mise en avant s'arrête au débit.
        NoMinIntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Hauteur : 1,232 m — mesurée le 17/10/2026 à 14:30 — '
                '$hydrometrieSourceName',
              ),
              SizedBox(height: 8),
              Text('Statut : Donnée brute'),
              Text('Qualification : Non qualifiée'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le corps de la fiche d'un point ONDE, dans l'ordre de
/// `onde_summary_sheet.dart` : libellé, cours d'eau, département, catégorie,
/// modalité officielle, campagne datée, quatre campagnes précédentes, rappel
/// de rythme.
class _CorpsFicheOnde extends StatelessWidget {
  const _CorpsFicheOnde();

  @override
  Widget build(BuildContext context) {
    final String categorie = flowCategoryLabel(const Ecoulement());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Le Cosson à Vineuil',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Text('Le Cosson'),
        const Text('Département 41'),
        const SizedBox(height: 8),
        Text(categorie, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text(
          '$ondeModalitePrefix'
          'Écoulement visible acceptable',
        ),
        const Text('Campagne du 25/09/2026 — $ondeSourceName'),
        // La mesure mise en avant s'arrête à la campagne datée.
        NoMinIntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              const Text(
                ondeHistoriqueTitre,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final String date in <String>[
                '25/08/2026',
                '25/07/2026',
                '25/06/2026',
                '25/05/2026',
              ])
                Text('$date — $categorie'),
              const SizedBox(height: 8),
              // Le vrai rappel de rythme (mineur différé de `S6`).
              const Text(ondeSeasonNotice),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le corps de la fiche tronçon, dans l'ordre de `flood_sheet_panel.dart` :
/// nom, encart de crue (le vrai), niveau, définition citée, date, bulletin.
class _CorpsFicheTroncon extends StatelessWidget {
  const _CorpsFicheTroncon();

  @override
  Widget build(BuildContext context) {
    const FloodVigilanceLevel niveau = Jaune();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Loire blésoise',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const FloodWarningCard(),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const FloodLevelGauge(level: niveau, size: 26),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                floodVigilanceTitle(niveau),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // La mesure mise en avant s'arrête au niveau.
        NoMinIntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Text('« ${publishedFloodLegend(niveau)} »'),
              const SizedBox(height: 4),
              Text('« ${publishedFloodExplanation(niveau)} »'),
              const SizedBox(height: 4),
              const Text('— $floodSourceName'),
              const SizedBox(height: 8),
              const Text(
                'Information de vigilance du 17/10/2026 à 14:30 — '
                '$floodAttribution',
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumTapTarget),
                child: const Text('Lire le bulletin sur $floodPublicSiteLabel'),
              ),
              const SizedBox(height: 4),
              const Text('$floodPublicSiteUrl/'),
            ],
          ),
        ),
      ],
    );
  }
}
