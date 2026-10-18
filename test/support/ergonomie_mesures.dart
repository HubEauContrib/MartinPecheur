// La mesure des pièces de la carte (`S6` d'Ergonomie, porte de faisabilité de
// l'arbitrage 11) : chaque VRAIE pièce déjà livrée (`S1` à `S4`) est montée en
// Roboto, et ses hauteurs intrinsèques sont lues à la largeur qu'elle aura dans
// la mise en page (spec § 5.1) ; elles forment l'entrée de `allocateMapLayout`
// (`S5`). `S6` s'en sert pour vérifier qu'aux quatre tailles garanties rien de
// ce qui ne cède jamais ne déborde — sauf à 360 × 640 et 200 %, où la partie
// fixe du bloc défile là où l'ordre de repli ne suffit pas (arbitrage 13 du
// commanditaire, 2026-10-18) ; `D2` (I-g) et `D3`, pour savoir quels replis
// jouent à une configuration.
//
// Les hauteurs sont lues par `getMinIntrinsicHeight` / `getMaxIntrinsicHeight`
// À LA LARGEUR CALCULÉE, sur des pièces montées dans un arbre assez grand pour
// ne rien couper : c'est exactement ce que fera `RenderMapLayout` (`D1`), qui
// lit les intrinsèques de ses enfants aux largeurs de la carte visible avant
// de les poser. Les règles de largeur et de recouvrement de ce fichier sont
// donc celles que `D1` doit poser — mêmes nombres, mêmes écarts.
//
// Ce que ce fichier compose lui-même, faute de pièce encore livrée, et que
// `B1`, `D1` et `D2` doivent reproduire à l'identique (sinon les mesures
// d'ici ne décrivent plus l'écran) :
// - la PARTIE FIXE du bloc = sélecteur + en-tête, sans écart ni marge (`B1`) ;
// - l'AVIS nu, sans la marge haute de 8 que l'actuel `buildMapOverlays` pose ;
// - le BAS : en compact, la rangée « Favoris, Filtres … −, +, recentrer » puis
//   [margeDeSurcouche] puis l'attribution ; au-delà, la colonne actuelle de
//   `buildMapOverlays` (entrées, 8, contrôles, 8, attribution), à sa largeur
//   intrinsèque maximale BORNÉE à la carte visible moins deux marges (au-delà,
//   l'attribution passe à la ligne) ;
// - l'EN-TÊTE d'une fiche à étoile, mesuré au pire : avec l'avis d'échec
//   d'écriture du favori, épinglé sous lui (spec § 6.1 : il ne cède jamais) ;
// - les CORPS des fiches, pour leur hauteur entière seulement : une recopie
//   approchée des fiches actuelles (station, point ONDE, tronçon) — la hauteur
//   entière ne décide que du repli 2, jamais d'un débordement.
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
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
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

/// La nature d'une fiche de point ONDE (spec § 6.1, § 11.2).
const String _natureOnde = 'Point ONDE';

/// La bande du réticule : le réticule et sa marge, au-dessus et au-dessous
/// (spec § 5.6). La valeur que `D2` passe à `MapLayout.reticleBandHeight`.
const double _hauteurBandeReticule =
    mapCenterReticleSize + 2 * margeDeSurcouche;

// --- Les règles de largeur (spec § 5.1, § 5.5, § 6.5) ------------------------

/// La largeur de la carte visible : la fenêtre moins le panneau latéral quand
/// une fiche y est ouverte ; toute la fenêtre sinon (fiche du bas, ou aucune).
double _largeurCarteVisible(Size taille, {required bool ficheOuverte}) =>
    switch (mapLayoutWidthFor(taille.width)) {
      MapLayoutWidth.panel when ficheOuverte =>
        taille.width - mapSidePanelWidth,
      MapLayoutWidth.compact ||
      MapLayoutWidth.wide ||
      MapLayoutWidth.panel => taille.width,
    };

/// La largeur du bloc de lecture : toute la largeur moins deux marges en
/// compact ; au-delà, [mapReadingBlockMaxWidth] au plus dans la carte visible
/// moins deux marges.
double _largeurBloc(Size taille, {required bool ficheOuverte}) {
  final double visible = _largeurCarteVisible(
    taille,
    ficheOuverte: ficheOuverte,
  );
  return switch (mapLayoutWidthFor(taille.width)) {
    MapLayoutWidth.compact => visible - 2 * margeDeSurcouche,
    MapLayoutWidth.wide || MapLayoutWidth.panel => math.min(
      mapReadingBlockMaxWidth,
      visible - 2 * margeDeSurcouche,
    ),
  };
}

/// La largeur du bas : en compact, toute la largeur moins deux marges (la
/// rangée) ; au-delà, la largeur intrinsèque maximale de la colonne, badge
/// d'attribution compris ([largeurIntrinseque], mesurée), sans dépasser la
/// carte visible moins deux marges — au-delà, l'attribution passe à la ligne.
/// Cette borne est un ajout de `S6` : à 800 × 740 et 200 %, fiche ouverte, la
/// colonne sur une ligne (417,7) est plus large que la carte visible (420)
/// moins ses deux marges.
double _largeurBas(
  Size taille, {
  required bool ficheOuverte,
  required double largeurIntrinseque,
}) => switch (mapLayoutWidthFor(taille.width)) {
  MapLayoutWidth.compact => taille.width - 2 * margeDeSurcouche,
  MapLayoutWidth.wide || MapLayoutWidth.panel => math.min(
    largeurIntrinseque,
    _largeurCarteVisible(taille, ficheOuverte: ficheOuverte) -
        2 * margeDeSurcouche,
  ),
};

/// La largeur de la bande du bouton de désignation (spec § 5.5) : en compact,
/// au-dessus de la rangée, toute la largeur moins deux marges ; au-delà, à
/// gauche de la colonne — la carte visible moins la marge gauche, l'écart avec
/// la colonne, la colonne posée ([largeurColonne], celle de [_largeurBas]) et
/// sa marge droite. Elle peut être négative : la bande ne tient pas.
double _largeurBande(
  Size taille, {
  required bool ficheOuverte,
  required double largeurColonne,
}) {
  final double visible = _largeurCarteVisible(
    taille,
    ficheOuverte: ficheOuverte,
  );
  return switch (mapLayoutWidthFor(taille.width)) {
    MapLayoutWidth.compact => visible - 2 * margeDeSurcouche,
    MapLayoutWidth.wide ||
    MapLayoutWidth.panel => visible - 3 * margeDeSurcouche - largeurColonne,
  };
}

/// La largeur d'une fiche : toute la fenêtre en fiche du bas, le panneau
/// latéral au-delà (spec § 6.5).
double _largeurFiche(Size taille) => switch (mapLayoutWidthFor(taille.width)) {
  MapLayoutWidth.compact || MapLayoutWidth.wide => taille.width,
  MapLayoutWidth.panel => mapSidePanelWidth,
};

/// `MapLayoutInput.blockOverBottom` : toujours vrai en compact ; au-delà, vrai
/// quand le bloc et la colonne du bas se recouvrent en largeur, écart compris —
/// `8 + bloc + 8 > carte visible − 8 − colonne`.
bool _blocSurLeBas(
  Size taille, {
  required bool ficheOuverte,
  required double largeurColonne,
}) => switch (mapLayoutWidthFor(taille.width)) {
  MapLayoutWidth.compact => true,
  MapLayoutWidth.wide || MapLayoutWidth.panel =>
    margeDeSurcouche +
            _largeurBloc(taille, ficheOuverte: ficheOuverte) +
            margeDeSurcouche >
        _largeurCarteVisible(taille, ficheOuverte: ficheOuverte) -
            margeDeSurcouche -
            largeurColonne,
};

// --- Les mesures -------------------------------------------------------------

const Key _cleSelecteur = Key('mesure-selecteur');
const Key _cleEntete = Key('mesure-entete');
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
  _natureOnde => const _CorpsFicheOnde(),
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
}) async {
  final bool compact = switch (mapLayoutWidthFor(taille.width)) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  };
  final bool ficheOuverte = fiche != null;
  void rien() {}

  final Widget bas = compact
      ? Column(
          key: _cleBas,
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
          key: _cleBas,
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
                  key: _cleSelecteur,
                  child: MapReadingSelector(
                    scale: lecture,
                    onSelect: (MapScaleKind _) {},
                    designationMode: enMode,
                    onToggleDesignationMode: rien,
                  ),
                ),
                SizedBox(
                  key: _cleEntete,
                  child: MapLegendHeader(
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
                SizedBox(
                  key: _cleAvis,
                  child: NoDataInAreaNotice(onWiden: rien),
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
                    child: SheetFrame(
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

  final double bloc = _largeurBloc(taille, ficheOuverte: ficheOuverte);
  final double largeurDuBas = _largeurBas(
    taille,
    ficheOuverte: ficheOuverte,
    largeurIntrinseque: boite(_cleBas).getMaxIntrinsicWidth(double.infinity),
  );
  final double largeurDeLaBande = _largeurBande(
    taille,
    ficheOuverte: ficheOuverte,
    largeurColonne: largeurDuBas,
  );
  // `MapLayoutInput.bandFits` : toujours vrai en compact, où la bande passe
  // au-dessus de la rangée ; au-delà, la largeur laissée à côté de la colonne
  // doit atteindre la largeur intrinsèque minimale de la bande.
  final bool bandeTient =
      compact ||
      largeurDeLaBande >=
          boite(_cleBande).getMinIntrinsicWidth(double.infinity);
  final PieceHeights selecteur = deux(_cleSelecteur, bloc);
  final double entete = une(_cleEntete, bloc);
  return MapLayoutInput(
    available: taille.height - marge.vertical - 2 * margeDeSurcouche,
    width: mapLayoutWidthFor(taille.width),
    blockOverBottom: _blocSurLeBas(
      taille,
      ficheOuverte: ficheOuverte,
      largeurColonne: largeurDuBas,
    ),
    bandFits: bandeTient,
    designation: enMode,
    sheetOpen: ficheOuverte,
    blockFixed: PieceHeights(
      min: selecteur.min + entete,
      max: selecteur.max + entete,
    ),
    notices: avecAvis ? une(_cleAvis, bloc) : 0,
    legend: une(_cleLegende, bloc),
    bottom: une(_cleBas, largeurDuBas),
    // Une bande qui ne tient pas n'a pas de hauteur à dire : fiche ouverte,
    // `allocateMapLayout` la retire (repli 6 étendu, arbitrage 14).
    band: enMode && bandeTient
        ? deux(_cleBande, largeurDeLaBande)
        : PieceHeights.none,
    reticleBand: enMode ? _hauteurBandeReticule : 0,
    sheet: fiche == null
        ? PieceHeights.none
        : deux(_cleFiche, _largeurFiche(taille)),
    gap: margeDeSurcouche,
  );
}

// --- Les corps approchés des fiches ------------------------------------------
//
// Une recopie APPROCHÉE des fiches actuelles, sans leur ViewModel : elle ne
// sert qu'à leur hauteur entière (repli 2). Le contrôle « ⚠ Avertissement »,
// passé dans l'en-tête du cadre (`S3`), n'y est plus.

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
        Text(
          'Hauteur : 1,232 m — mesurée le 17/10/2026 à 14:30 — '
          '$hydrometrieSourceName',
        ),
        SizedBox(height: 8),
        Text('Statut : Donnée brute'),
        Text('Qualification : Non qualifiée'),
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
        const Text('Modalité officielle ONDE : Écoulement visible acceptable'),
        const Text('Campagne du 25/09/2026 — $ondeSourceName'),
        const SizedBox(height: 8),
        const Text(
          'Campagnes précédentes',
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
        const Text(
          'Les campagnes ONDE ont lieu une fois par mois, de mai à septembre.',
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
    );
  }
}
