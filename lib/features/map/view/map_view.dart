// La vue de la tranche carte (MVVM, ADR-014) : le fond IGN Géoplateforme,
// son attribution en toutes lettres — une condition d'usage de la donnée sous
// Licence Ouverte, jamais une finition (`04-ui.md` § 3) — et les stations du
// référentiel en marqueurs du viewport élargi. Les couches sont produites par
// [buildMapLayers], une fonction PURE : rendre un `FlutterMap` dans un test
// déclenche des chargements de tuiles que l'environnement de test refuse.
//
// Les **surcouches** — légende, bandeau d'erreur, panneau de fiche,
// attribution — sont produites de la même façon, par [buildMapOverlays]
// (relecture du 2026-09-14). Leur câblage n'était couvert par aucun test tant
// qu'il vivait dans `build` : ce qui garantit qu'une légende est TOUJOURS
// rendue, même en erreur (`BR-008`), tenait au fait que personne n'avait
// touché à ce `Stack`. Les deux fonctions pures rendent l'écran entier
// vérifiable sans monter de carte.
//
// ⚠️ Au zoom national, les 4 150 zones de tap de 44 pt se chevauchent, et le
// marqueur qui reçoit le tap est le plus tardif dans l'ordre de l'asset, pas
// le plus proche du doigt — écart assumé pour T1, acté sous `U1` dans le plan
// (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`).
//
// ⚠️ Au zoom national, la France entière est visible : les 4 150 stations
// sont TOUTES dessinées — c'est le prix réel de l'approche par défaut
// (`F2c`, aucun clustering tant qu'aucune mesure ne le réhabilite), pas un
// défaut caché. La pastille ([StationMarkerDot], `station_marker.dart`) est
// une forme DESSINÉE, jamais un glyphe de police : un glyphe coûterait une
// passe de texte par marqueur, inutile pour 4 150 occurrences.
//
// La pastille porte désormais l'état de sa station (T1-U2) : la couleur ne
// distingue rien — en T1 tout est « Indéterminé » (`BR-004`, aucun
// percentile avant `ADR-003`) — ce sont le motif et le libellé annoncé qui
// séparent une mesure fraîche d'une absence constatée (`04-ui.md` § 3).
// [MapLegend] nomme l'échelle active en permanence, jamais repliée
// (`BR-008`) : sans elle, une teinte réutilisée d'une échelle à l'autre
// rendrait la carte ambiguë.
//
// La vue ne fait que **brancher** : elle observe [MapViewModel], traduit les
// événements de `flutter_map` en emprises de domaine, et n'appelle aucun
// dépôt. C'est le ViewModel qui appelle le dépôt, directement et de façon
// typée (R3, arbitrage 2026-09-13 — le registre de messages et ses
// gestionnaires ont disparu).
//
// Relecture M3/M4 (2026-09-13), deux défauts corrigés et toujours en vigueur :
// - `MapOptions` était reconstruite à chaque `build` avec des fermetures
//   inline : `MapOptions ==` (paquet flutter_map 8.3.2,
//   `lib/src/map/options/options.dart`) compare chaque callback par égalité
//   de fonction, et deux fermetures inline ne sont jamais égales même à
//   code identique. `flutter_map` remplaçait donc l'état de son contrôleur
//   à chaque frame (NFR-01). [_mapOptions] est un champ `late final`,
//   construit une seule fois, avec un tear-off de méthode
//   (`_handleMapEvent`) — un tear-off d'une méthode d'instance reste égal à
//   lui-même d'un accès à l'autre.
// - la requête d'emprise partait à chaque frame d'un glisser : dix frames
//   faisaient dix requêtes et reconstruisaient dix fois les 4 150 marqueurs.
//   `onPositionChanged` n'est plus câblé du tout : la requête part sur
//   [_handleMapEvent], câblé à `MapOptions.onMapEvent`, uniquement pour les
//   événements de **fin** de geste — voir [shouldRefreshOn]. La marge
//   proportionnelle
//   `defaultViewportMargin` (`lib/domain/geo/viewport_filter.dart`) couvre le
//   déplacement entre-temps.
//
// Une erreur de lecture n'est pas avalée : [MapViewModel.error] la porte, et
// la vue affiche [MapErrorBanner] au lieu d'une carte muette (`BR-007`).
//
// ⚠️ La fiche station est **injectée**, pas importée (T1-U1). La règle
// `feature-vers-feature` de `test/architecture/layers_test.dart` interdit à
// une tranche d'en citer une autre : `features/map/` ne peut donc nommer ni
// `features/station_sheet/view/…`, ni son ViewModel. [MapView] reçoit donc
// le panneau déjà composé ([MapView.stationSheet], un `Widget`) et le rappel
// de tap ([MapView.onStationTap], un `void Function(StationCode)`) ; c'est
// `main.dart`, la racine de composition — le seul fichier exempté de ces
// règles — qui assemble `StationSheetPanel` avec son ViewModel et les passe
// ici. La carte reste ignorante de ce qu'elle affiche par-dessus elle : elle
// **branche**, elle ne décide pas.
//
// Un `Widget` déjà construit suffit, et un `WidgetBuilder` n'apporterait
// rien : le panneau injecté est un `ListenableBuilder` sur le ViewModel de
// la fiche, qui se reconstruit tout seul quand la fiche change d'état — la
// carte, elle, n'a aucune raison d'être reconstruite pour cela.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLatitude = 46.6;

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLongitude = 2.2;

/// Zoom initial — la France métropolitaine tient à l'écran.
const double initialMapZoom = 5;

/// Zoom minimal — en dessous, la France n'emplit plus l'écran.
const double minimumMapZoom = 4;

/// Zoom maximal — aligné sur le niveau natif maximal du plan IGN
/// ([ignMaxNativeZoom]) : au-delà, le serveur n'a rien à offrir de plus fin.
const double maximumMapZoom = ignMaxNativeZoom * 1.0;

/// État par défaut de [buildMapLayers.stateOf] : aucune requête n'a abouti
/// pour cette station. Une fonction de premier niveau, et non une fermeture
/// `(_) => const NonChargee()` — seul un tear-off de fonction de premier
/// niveau est une expression constante, donc utilisable comme valeur par
/// défaut d'un paramètre.
StationMapState _alwaysUnloaded(StationCode code) => const NonChargee();

/// Décide si [event] doit déclencher un nouveau chargement d'emprise.
/// Fonction pure, testable sans widget ni `FlutterMap` — construite avec les
/// constructeurs de `MapEvent` du paquet, ou testée par son type runtime.
///
/// Elle vit du côté **vue** et non du ViewModel : son seul paramètre est un
/// type de `flutter_map`, et un ViewModel ne connaît pas la bibliothèque de
/// carte (ADR-014). C'est la vue qui traduit un événement de geste en
/// emprise de domaine.
///
/// Seuls les événements de **fin** de geste répondent `true` : ce sont les
/// classes `…End` du paquet flutter_map 8.3.2
/// (`lib/src/gestures/map_events.dart`) — [MapEventMoveEnd] (ligne 219, fin
/// d'un glisser), [MapEventFlingAnimationEnd] (ligne 262, fin d'un fling),
/// [MapEventDoubleTapZoomEnd] (ligne 306, fin d'un double-tap) et
/// [MapEventRotateEnd] (ligne 342, fin d'une rotation) — plus
/// [MapEventScrollWheelZoom] (ligne 283) : le paquet ne lui connaît pas de
/// variante `…End`, chaque cran de molette y est déjà un geste complet et
/// discret. Un événement intermédiaire (`MapEventMove`, émis à chaque frame
/// d'un glisser en cours) répond `false` : la marge proportionnelle
/// `defaultViewportMargin` (`lib/domain/geo/viewport_filter.dart`) couvre déjà
/// le déplacement jusqu'au prochain relâcher — charger à chaque frame
/// reconstruirait les 4 150 marqueurs pour rien (NFR-01).
bool shouldRefreshOn(MapEvent event) =>
    event is MapEventMoveEnd ||
    event is MapEventFlingAnimationEnd ||
    event is MapEventScrollWheelZoom ||
    event is MapEventDoubleTapZoomEnd ||
    event is MapEventRotateEnd;

/// Décide si l'échelle [scale] justifie de précharger le débit des stations
/// visibles. Fonction pure, testable sans widget — extraite pour cela : la
/// décision vit sinon dans `_loadThenPreload`, qu'aucun test ne peut
/// atteindre sans monter un `FlutterMap`.
///
/// **Seule l'échelle « débit » précharge** (relecture du 2026-09-14). Sur
/// l'échelle « écoulement », qui est celle du démarrage (`UC-001 § 3`),
/// `buildMapLayers` ne dessine **aucun** marqueur de station : précharger y
/// enverrait jusqu'à vingt requêtes Hub'Eau par relâchement de geste pour
/// des marqueurs que personne ne voit. L'API n'a ni SLA ni quota chiffré
/// (`C-15`), et `NFR-07` interdit précisément le travail réseau sans
/// destinataire à l'écran.
///
/// `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
/// sans branche ici ne compile pas — jamais un préchargement décidé par
/// défaut.
bool shouldPreloadOn(MapScaleKind scale) => switch (scale) {
  MapScaleKind.ecoulement => false,
  MapScaleKind.debit => true,
};

/// Construit les couches de la carte, dans l'ordre où `FlutterMap` doit les
/// empiler — le fond de tuiles **premier**, les marqueurs ensuite. Fonction
/// pure, testable sans rendu ni accès réseau.
///
/// ⚠️ **Une seule famille de marqueurs à la fois** (`BR-008`, `UC-001 A6`) :
/// [scale] décide, et le `switch` sur elle est exhaustif — l'échelle
/// « écoulement » dessine **uniquement** les points ONDE, l'échelle
/// « débit » **uniquement** les stations. Jamais les deux : les trois
/// échelles du produit réutilisent délibérément les mêmes teintes, et deux
/// familles superposées rendraient la carte illisible. C'est aussi pourquoi
/// [scale] est **requise** et n'a pas de valeur par défaut : contrairement à
/// [stateOf], aucune valeur n'est neutre ici — choisir l'échelle est une
/// décision de l'écran, jamais un défaut de cette fonction.
///
/// Ne refiltre pas [stations] à une emprise : le filtre fait foi côté dépôt
/// (`StationPointRepository`, marge `defaultViewportMargin` comprise) — le
/// dupliquer ici masquerait un bug de marge plutôt que de le révéler, et un
/// filtre à marge nulle supprimerait purement et simplement les marqueurs de
/// la marge que le dépôt vient de rapporter. [buildMapLayers] dessine
/// exactement ce que le ViewModel lui donne. Il en va de même des
/// [ondeObservations], déjà regroupées par station côté dépôt.
///
/// Une couche de marqueurs **vide n'est pas ajoutée** : au moins un marqueur
/// est nécessaire pour que `MarkerLayer` apparaisse dans la liste. Une
/// emprise sans aucune observation ONDE ne dessine donc rien — et ne plante
/// pas. ⚠️ Elle ne **dit** rien non plus : le message qui nomme le périmètre
/// réel du réseau hors couverture (`UC-001 A5`, `BR-007`) est une surcouche,
/// posée en `U6`.
///
/// [onStationTap] est appelé avec le code de la station tapée,
/// [onOndeTap] avec le point ONDE tapé. Nommés et **optionnels** : le
/// `Marker` existe déjà sans eux — la carte de T0 n'était pas interactive —
/// et un appelant qui ne veut pas de tap n'a rien à fournir. Sans rappel, le
/// marqueur reste inerte : `GestureDetector` sans `onTap` ne participe pas
/// au test de toucher, même en [HitTestBehavior.opaque].
///
/// [stateOf] rend l'état d'affichage d'une station — en production,
/// `MapViewModel.stateOf`. Il a une **valeur par défaut**
/// ([_alwaysUnloaded], donc [NonChargee] partout) plutôt que d'être requis :
/// une carte qui ne sait rien de ses stations est exactement ce que décrit
/// [NonChargee] (`BR-007`), et les appelants qui n'affichent pas d'état —
/// les tests de tuiles, de tap et de taille — n'ont pas à fabriquer une
/// fonction pour le dire.
///
/// [now] donne l'instant de lecture, dont dépend l'âge de chaque campagne
/// ONDE (`campaignAgeOf`, `BR-010`). **Injecté** plutôt que lu de l'horloge
/// du poste : c'est ce qui rend la bascule des 60 jours testable. Il est
/// appelé **une seule fois** par construction de couches, et ramené en UTC :
/// deux marqueurs de la même carte doivent dater du même instant, et
/// `campaignAgeOf` exige que `now` soit dans le fuseau de `observedAt` —
/// l'UTC, que le mapper rend (`T-08`).
List<Widget> buildMapLayers({
  required MapScaleKind scale,
  required List<StationPoint> stations,
  Map<OndeStationCode, OndeObservation> ondeObservations =
      const <OndeStationCode, OndeObservation>{},
  DateTime Function() now = DateTime.now,
  void Function(StationCode code)? onStationTap,
  void Function(OndePoint point)? onOndeTap,
  StationMapState Function(StationCode code) stateOf = _alwaysUnloaded,
}) {
  final List<Widget> layers = <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];

  // `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
  // sans branche ici ne compile pas — jamais une carte silencieusement vide.
  final List<Marker> markers = switch (scale) {
    MapScaleKind.ecoulement => _ondeMarkers(
      ondeObservations: ondeObservations,
      now: now().toUtc(),
      onOndeTap: onOndeTap,
    ),
    MapScaleKind.debit => _stationMarkers(
      stations: stations,
      stateOf: stateOf,
      onStationTap: onStationTap,
    ),
  };

  if (markers.isNotEmpty) {
    layers.add(MarkerLayer(markers: markers));
  }

  return layers;
}

/// Les marqueurs de l'échelle « débit » : une pastille par station.
List<Marker> _stationMarkers({
  required List<StationPoint> stations,
  required StationMapState Function(StationCode code) stateOf,
  required void Function(StationCode code)? onStationTap,
}) {
  // Copié dans un local `final` : la promotion de type survit ainsi dans la
  // fermeture construite pour chaque marqueur.
  final void Function(StationCode code)? handleTap = onStationTap;

  return stations
      .map(
        (StationPoint station) => Marker(
          // ⚠️ GeoJSON range les coordonnées [longitude, latitude] ;
          // `LatLng` prend la latitude EN PREMIER. `StationPoint` a déjà
          // absorbé cet écart à l'analyse (stations_asset.dart) — ici,
          // `station.latitude`/`station.longitude` sont déjà dans l'ordre
          // attendu par `LatLng`.
          point: LatLng(station.latitude, station.longitude),
          // Le marqueur mesure la ZONE DE TAP (44 pt, `04-ui.md` § 3) ; la
          // pastille de 12 px reste centrée dedans. Les deux tailles sont
          // distinctes à dessein : ce qui se voit et ce qui se touche n'ont
          // pas la même exigence.
          width: stationMarkerTapTarget,
          height: stationMarkerTapTarget,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleTap == null ? null : () => handleTap(station.code),
            child: Semantics(
              button: true,
              label: _stationSemanticLabel(station, stateOf(station.code)),
              // ⚠️ `excludeSemantics` : [StationMarkerDot] porte son PROPRE
              // `Semantics` — c'est ce qui rend la pastille annonçable telle
              // quelle en légende, où elle n'a pas de station à nommer. Sur
              // la carte, le marqueur reprend l'annonce pour y joindre
              // l'échelle et le nom de la station, et masque celle de la
              // pastille : un marqueur, un seul nœud sémantique. Sans cela
              // chaque station en porterait deux, et le lecteur d'écran
              // annoncerait l'état deux fois.
              excludeSemantics: true,
              child: Center(
                child: SizedBox(
                  width: stationMarkerSize,
                  height: stationMarkerSize,
                  child: StationMarkerDot(state: stateOf(station.code)),
                ),
              ),
            ),
          ),
        ),
      )
      .toList();
}

/// Les marqueurs de l'échelle « écoulement » : un par observation ONDE,
/// posé sur le point que l'observation porte (`OndeObservation.point`, lu
/// sur la même ligne d'API — `T-09`), donc sans second appel au référentiel.
List<Marker> _ondeMarkers({
  required Map<OndeStationCode, OndeObservation> ondeObservations,
  required DateTime now,
  required void Function(OndePoint point)? onOndeTap,
}) {
  final void Function(OndePoint point)? handleTap = onOndeTap;

  return ondeObservations.values.map((OndeObservation observation) {
    final OndePoint point = observation.point;
    final CampaignAge age = campaignAgeOf(
      observedAt: observation.observedAt,
      now: now,
    );

    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: stationMarkerTapTarget,
      height: stationMarkerTapTarget,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap == null ? null : () => handleTap(point),
        child: Semantics(
          button: true,
          label: _ondeSemanticLabel(observation, age),
          // Même raison que pour une station : [OndeMarkerShape] porte son
          // propre `Semantics` pour la légende, le marqueur le masque.
          excludeSemantics: true,
          child: Center(
            child: SizedBox(
              width: stationMarkerSize,
              height: stationMarkerSize,
              child: OndeMarkerShape(
                category: observation.category,
                age: age,
                observedAt: observation.observedAt,
              ),
            ),
          ),
        ),
      ),
    );
  }).toList();
}

/// L'annonce d'un marqueur de station au lecteur d'écran : l'**échelle
/// active** en tête, le **nom de la station**, puis son libellé d'état quand
/// il y en a un.
///
/// « Débit relatif à l'historique : La Loire à Blois » pour une mesure
/// fraîche ou une station pas encore chargée — ni l'une ni l'autre n'ont
/// d'état à annoncer (`BR-005`, `BR-007`) — et « …, Aucune donnée
/// disponible ici. » quand l'état parle. `04-ui.md` § 3 donne l'annonce
/// attendue : elle **nomme la station**, un marqueur muet ne dit pas où l'on
/// est.
///
/// Le préfixe d'échelle est la dette actée en `U2`, réglée en `U3` : les
/// trois échelles du produit réutilisent les mêmes teintes, et une annonce
/// qui ne dit pas laquelle est active est ambiguë (`BR-008`). Il vient de
/// `mapScaleLabel`, jamais d'une recopie locale — et cette fonction est
/// appelée depuis la seule branche `debit` du `switch` de [buildMapLayers],
/// d'où l'échelle en dur.
///
/// Le libellé d'état vient du domaine (`stationMapStateLabel`), jamais d'une
/// recopie locale.
String _stationSemanticLabel(StationPoint station, StationMapState state) {
  final String prefix = '${mapScaleLabel(MapScaleKind.debit)} : ';
  final String stateLabel = stationMapStateLabel(state);
  return stateLabel.isEmpty
      ? '$prefix${station.label}'
      : '$prefix${station.label}, $stateLabel';
}

/// L'annonce d'un marqueur ONDE : l'échelle active, la catégorie, le point,
/// et la date de sa campagne — **toujours**, `BR-010` ouvrant sur « tout
/// point ONDE affiche la date de sa dernière campagne ».
///
/// « Écoulement : À sec — Ruisseau des Fées, campagne du 25/08/2026,
/// observation visuelle ponctuelle » (`BR-008`, `BR-010`, `04-ui.md` § 3).
/// L'assemblage lui-même vit dans `onde_marker.dart` ([ondeMarkerLabel]) :
/// la légende annonce la même catégorie sans point ni échelle, et les deux
/// formulations ne doivent pas pouvoir diverger.
String _ondeSemanticLabel(OndeObservation observation, CampaignAge age) {
  final String prefix = '${mapScaleLabel(MapScaleKind.ecoulement)} : ';
  final String label = ondeMarkerLabel(
    category: observation.category,
    age: age,
    observedAt: observation.observedAt,
    pointLabel: observation.point.label,
  );
  return '$prefix$label';
}

/// Construit les surcouches de la carte, dans l'ordre où elles doivent être
/// empilées PAR-DESSUS le `FlutterMap`. Fonction pure, testable sans rendre
/// de carte — même esprit que [buildMapLayers], et pour la même raison :
/// l'environnement de test refuse le chargement de tuiles.
///
/// Dans l'ordre :
/// 1. **la légende, toujours** (`MapLegend`, en haut à droite) — `BR-008` en
///    fait une pièce obligatoire : les trois échelles du produit réutilisent
///    les mêmes teintes, et c'est elle qui nomme celle qui est active. Elle
///    est rendue quel que soit [error] : une carte en panne reste une carte
///    qu'on lit ;
/// 2. les **puces de bascule d'échelle** ([MapScaleChips]), toujours, en
///    haut à gauche — y compris en erreur : une carte en panne reste une
///    carte dont on change l'échelle (`BR-007`, `UC-001 A6`) ;
/// 3. le **bandeau d'erreur**, seulement si [error] n'est pas nul
///    (`BR-007` : jamais une carte muette). Posé **sous** les puces, dans la
///    même colonne : la largeur de cette colonne est bornée, elle réserve
///    toute la place de la légende et n'empiète jamais dessus ;
/// 4. le **panneau de fiche**, s'il est fourni, en bas à gauche ;
/// 5. l'**attribution IGN**, toujours, en bas à droite — une condition
///    d'usage de la Licence Ouverte, jamais une finition (`04-ui.md` § 3).
///
/// [onSelect] est appelé avec l'échelle demandée par un tap de puce — en
/// production, `MapViewModel.selectScale`. **Requis** : des puces sans
/// rappel seraient un contrôle mort à l'écran.
List<Widget> buildMapOverlays({
  required MapScaleKind scale,
  required void Function(MapScaleKind kind) onSelect,
  required Object? error,
  Widget? stationSheet,
}) {
  final Object? bannerError = error;
  final Widget? sheet = stationSheet;

  return <Widget>[
    Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(_overlayPadding),
        child: MapLegend(scale: scale),
      ),
    ),
    Align(
      alignment: Alignment.topLeft,
      child: Padding(
        // La marge de droite réserve toute la place de la légende, plus les
        // deux marges qui l'encadrent : ni les puces ni le bandeau ne
        // peuvent passer dessous (`BR-008`).
        padding: const EdgeInsets.fromLTRB(
          _overlayPadding,
          _overlayPadding,
          legendMaxWidth + 2 * _overlayPadding,
          _overlayPadding,
        ),
        // Une colonne, et non deux `Align` superposés : le bandeau d'erreur
        // se pose SOUS les puces plutôt que par-dessus, quelle que soit la
        // hauteur qu'il prend en enveloppant son texte.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MapScaleChips(scale: scale, onSelect: onSelect),
            if (bannerError != null)
              Padding(
                padding: const EdgeInsets.only(top: _overlayPadding),
                child: MapErrorBanner(error: bannerError),
              ),
          ],
        ),
      ),
    ),
    if (sheet != null)
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          // Marge basse plus épaisse : elle dégage le bandeau d'attribution
          // IGN, qui reste lisible en toutes circonstances (Licence
          // Ouverte, `04-ui.md` § 3).
          padding: const EdgeInsets.fromLTRB(
            _overlayPadding,
            _overlayPadding,
            _overlayPadding,
            _sheetBottomPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
            child: sheet,
          ),
        ),
      ),
    const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.all(_overlayPadding),
        child: IgnAttributionBadge(),
      ),
    ),
  ];
}

/// Marge d'une surcouche au bord de la carte, en pixels logiques.
const double _overlayPadding = 8;

/// Marge basse du panneau de fiche : elle dégage l'attribution IGN.
const double _sheetBottomPadding = 32;

/// Largeur maximale du panneau de fiche, en pixels logiques.
const double _sheetMaxWidth = 420;

/// Les puces de bascule d'échelle, en haut à gauche de la carte : une par
/// valeur de [MapScaleKind], celle de [scale] marquée active.
///
/// `BR-008` et `UC-001 A6` : changer d'échelle change **marqueurs et légende
/// ensemble**, et une seule échelle est active à la fois. Ce widget ne
/// décide rien — il appelle [onSelect], et c'est le ViewModel qui bascule
/// (et qui ignore une demande sans effet).
///
/// Les libellés viennent de `mapScaleLabel`, jamais d'une recopie locale :
/// la légende nomme l'échelle active avec exactement les mêmes mots.
class MapScaleChips extends StatelessWidget {
  const MapScaleChips({required this.scale, required this.onSelect, super.key});

  /// L'échelle active, lue sur `MapViewModel.scale`.
  final MapScaleKind scale;

  /// Appelé avec l'échelle demandée. En production,
  /// `MapViewModel.selectScale`.
  final void Function(MapScaleKind kind) onSelect;

  @override
  Widget build(BuildContext context) {
    // `Wrap` et non `Row` : « Débit relatif à l'historique » est un libellé
    // long, et les deux puces ne tiennent pas côte à côte sur un écran
    // étroit — ni sur un large, une fois réservée la place de la légende.
    // Une `Row` déborderait ; `Wrap` les empile.
    //
    // ⚠️ Le `Wrap` ne replie qu'ENTRE les puces, jamais dans l'une d'elles :
    // ce qui tient la typographie dynamique jusqu'à 200 % (`04-ui.md` § 3)
    // est, à l'intérieur de chaque puce, le `ConstrainedBox(minWidth: 44)`
    // — un plancher, pas un plafond — et le retour à la ligne du `Text`,
    // qu'aucune contrainte de hauteur ne bride.
    return Wrap(
      spacing: _overlayPadding,
      runSpacing: _overlayPadding,
      children: <Widget>[
        for (final MapScaleKind kind in MapScaleKind.values)
          _MapScaleChip(
            kind: kind,
            selected: kind == scale,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

/// Une puce. Construite à la main plutôt qu'avec un `ChoiceChip` de
/// Material pour deux raisons, dans cet ordre :
/// 1. la **cible tactile** de 44 pt (`04-ui.md` § 3) est ici une contrainte
///    explicite, pas la densité que le thème veut bien accorder ;
/// 2. l'état sélectionné est porté par `Semantics(selected:)` **en plus** du
///    rendu : « aucune information n'est portée par la seule couleur »
///    (`04-ui.md` § 3) vaut aussi pour un contrôle.
///
/// ⚠️ Le noir et le blanc employés ici ne codent **aucun état de l'eau** :
/// `04-ui.md` § 2 ne régit que les teintes d'état, et une puce de filtre
/// n'en est pas une. Ce sont les mêmes neutres que l'attribution IGN et le
/// bandeau d'erreur de ce fichier.
class _MapScaleChip extends StatelessWidget {
  const _MapScaleChip({
    required this.kind,
    required this.selected,
    required this.onSelect,
  });

  final MapScaleKind kind;
  final bool selected;
  final void Function(MapScaleKind kind) onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // La clé est posée sur le nœud sémantique, donc sur la boîte entière :
      // c'est elle que les tests tapent et mesurent.
      key: ValueKey<MapScaleKind>(kind),
      button: true,
      selected: selected,
      label: mapScaleLabel(kind),
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(kind),
        child: ConstrainedBox(
          // 44 × 44 pt au minimum (`04-ui.md` § 3). La puce s'élargit avec
          // son texte, elle ne rétrécit jamais en deçà.
          constraints: const BoxConstraints(
            minWidth: stationMarkerTapTarget,
            minHeight: stationMarkerTapTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.white,
              border: Border.all(color: Colors.black),
              borderRadius: const BorderRadius.all(
                Radius.circular(stationMarkerTapTarget / 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _chipHorizontalPadding,
                vertical: _chipVerticalPadding,
              ),
              // `Align` à facteurs 1 : la boîte se dimensionne sur son
              // texte, et c'est le `ConstrainedBox` au-dessus qui impose le
              // plancher de 44 pt.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  mapScaleLabel(kind),
                  style: TextStyle(
                    fontSize: _chipFontSize,
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marge horizontale d'une puce, en pixels logiques.
const double _chipHorizontalPadding = 12;

/// Marge verticale d'une puce, en pixels logiques.
const double _chipVerticalPadding = 8;

/// Taille de texte d'une puce, en pixels logiques.
const double _chipFontSize = 12;

/// Bandeau d'erreur minimal (`BR-007`) : affiché à la place d'une carte
/// muette quand le dépôt n'a pas pu répondre — panne de lecture de l'asset
/// aujourd'hui, panne réseau en T1. Widget séparé, testable sans monter de
/// `FlutterMap` (même contrainte que [IgnAttributionBadge]).
class MapErrorBanner extends StatelessWidget {
  const MapErrorBanner({required this.error, super.key});

  /// L'erreur à afficher. Son `toString()` est montré tel quel : ce n'est
  /// pas un message pensé pour l'utilisateur final, mais T0 n'a rien de
  /// mieux tant que les avertissements (`BR-012`, `BR-013`) ne sont pas
  /// arrivés.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.red),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          "Les stations n'ont pas pu être chargées : $error",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Bandeau d'attribution IGN Géoplateforme, exigé par la Licence Ouverte.
/// Porte son propre fond opaque : un texte posé directement sur un fond de
/// carte quelconque ne tient aucun contraste (`04-ui.md` § 3). Entièrement
/// `const` : rien ici ne dépend de l'état de l'écran.
class IgnAttributionBadge extends StatelessWidget {
  const IgnAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(ignAttribution, style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// L'écran carte : fond IGN, attribution, et les marqueurs de stations du
/// viewport. N'appelle aucun dépôt — il observe [viewModel] et lui demande
/// des emprises.
class MapView extends StatefulWidget {
  /// [onStationTap] et [stationSheet] restent **optionnels** — la carte de
  /// T0 n'était pas interactive, et ses tests les omettent toujours — mais
  /// ils ne sont pas indépendants : une fiche sans tap ne s'ouvrirait
  /// jamais, un tap sans fiche n'afficherait rien. L'assert fait échouer
  /// tout de suite un câblage à moitié fait, plutôt que de laisser un écran
  /// silencieusement inerte.
  ///
  /// ⚠️ [onOndeTap], lui, est accepté **seul** et sans assert de couplage :
  /// la fiche ONDE n'existe pas encore (`U4`). Il n'est pas câblé par
  /// `main.dart` en `U3` — la carte sait déjà appeler un rappel de tap sur
  /// un point ONDE, il n'y a simplement rien à ouvrir au bout.
  const MapView({
    required this.viewModel,
    this.onStationTap,
    this.onOndeTap,
    this.stationSheet,
    this.now = DateTime.now,
    super.key,
  }) : assert(
         (onStationTap == null) == (stationSheet == null),
         'onStationTap et stationSheet vont ensemble : une fiche sans tap '
         "ne s'ouvre jamais, un tap sans fiche n'affiche rien",
       );

  /// Le ViewModel de la tranche carte, construit dans `main.dart`
  /// (asset → dépôts → ViewModel → vue). La vue ne le **possède pas** :
  /// c'est la racine de composition qui le crée et qui le disposera — cette
  /// vue ne doit pas disposer un objet dont elle n'est pas propriétaire.
  final MapViewModel viewModel;

  /// Appelé avec le code de la station tapée. Injecté par `main.dart`, qui
  /// le branche sur `StationSheetViewModel.open` : la carte ne connaît ni ce
  /// ViewModel ni sa tranche (règle `feature-vers-feature`).
  final void Function(StationCode code)? onStationTap;

  /// Appelé avec le point ONDE tapé. Injecté de la même façon, et pour la
  /// même raison : `features/map/` ne peut pas nommer `features/onde_sheet/`
  /// (règle `feature-vers-feature`). **Pas encore câblé** — c'est `U4` qui
  /// pose la fiche ONDE et le branche sur son ViewModel.
  final void Function(OndePoint point)? onOndeTap;

  /// L'instant de lecture, dont dépend l'âge de chaque campagne ONDE
  /// (`BR-010`). Par défaut l'horloge du poste ; un test le fixe pour
  /// éprouver la bascule des 60 jours sans dépendre de la date du jour.
  ///
  /// `DateTime.now` et non `() => DateTime.now()` : un tear-off de
  /// constructeur est une expression constante, une fermeture ne l'est pas —
  /// et ce constructeur est `const`.
  final DateTime Function() now;

  /// Le panneau de la fiche station, déjà composé avec son ViewModel par
  /// `main.dart`, et affiché en bas de la carte. `null` tant qu'aucune fiche
  /// n'est branchée — la carte reste alors ce qu'elle était en T0.
  ///
  /// La fiche ne se ferme que par son propre bouton (et par
  /// `StationSheetViewModel.close`) : un tap sur la carte hors marqueur ne
  /// la ferme pas.
  final Widget? stationSheet;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// Construites une seule fois : `MapOptions ==` (paquet flutter_map
  /// 8.3.2, `options.dart`) compare chaque callback par égalité de
  /// fonction, et les tear-offs de méthodes d'instance ci-dessous restent
  /// égaux d'un accès à l'autre — contrairement à des fermetures inline
  /// recréées à chaque `build`, qui auraient fait remplacer l'état interne
  /// du contrôleur `flutter_map` à chaque frame (NFR-01).
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: const LatLng(
      initialMapCenterLatitude,
      initialMapCenterLongitude,
    ),
    initialZoom: initialMapZoom,
    minZoom: minimumMapZoom,
    maxZoom: maximumMapZoom,
    onMapEvent: _handleMapEvent,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadThenPreload(widget.viewModel.loadInitial()));
  }

  /// Câblé à `MapOptions.onMapEvent` : ne déclenche un chargement que pour
  /// les événements de fin de geste ([shouldRefreshOn]), jamais à chaque
  /// frame d'un glisser en cours.
  void _handleMapEvent(MapEvent event) {
    if (!shouldRefreshOn(event)) {
      return;
    }

    final LatLngBounds visible = event.camera.visibleBounds;
    unawaited(
      _loadThenPreload(
        widget.viewModel.loadFor(
          Bounds(
            west: visible.west,
            south: visible.south,
            east: visible.east,
            north: visible.north,
          ),
        ),
      ),
    );
  }

  /// Enchaîne un chargement de points et — **sur la seule échelle
  /// « débit »** ([shouldPreloadOn]) — le préchargement du débit des
  /// stations visibles.
  ///
  /// C'est bien la **vue** qui déclenche le préchargement : `loadFor` annule
  /// celui qui tourne (une emprise quittée n'a plus de valeur, `NFR-07`,
  /// `C-15`) mais n'en relance aucun de lui-même, pour qu'un écran qui n'en
  /// veut pas n'ait pas à l'annuler (V2). Le branchement était explicitement
  /// laissé à `U2`.
  ///
  /// ⚠️ La garde d'échelle est la correction du 2026-09-14 : sur l'échelle
  /// « écoulement », active au démarrage, aucun marqueur de station n'est
  /// dessiné, et vingt requêtes hydrométrie par relâchement de geste
  /// partaient pour des marqueurs invisibles (`C-15`, `NFR-07`). L'échelle
  /// est relue **après** le chargement, jamais avant : l'usager a pu
  /// basculer entre-temps.
  ///
  /// L'attente est nécessaire : `preloadVisibleStations` choisit les vingt
  /// stations les plus proches du centre de l'emprise **déjà chargée**. La
  /// lancer avant que les points soient là ne précharge rien.
  ///
  /// La relancer à chaque fin de geste ne coûte rien quand rien n'a changé :
  /// le ViewModel **saute les stations dont l'état est déjà connu** et ne
  /// notifie qu'à un changement effectif. Un relâchement de geste sur la
  /// même emprise ne fait donc ni requête ni reconstruction des 4 150
  /// marqueurs (`NFR-01`) ; et la borne de vingt portant sur les requêtes et
  /// non sur les stations regardées, un second geste sur la même emprise
  /// précharge les **vingt suivantes**, de proche en proche.
  Future<void> _loadThenPreload(Future<void> load) async {
    await load;

    if (!shouldPreloadOn(widget.viewModel.scale)) {
      return;
    }

    await widget.viewModel.preloadVisibleStations();
  }

  /// Bascule d'échelle demandée par une puce ([MapScaleChips]) : le ViewModel
  /// bascule, puis — si la nouvelle échelle le justifie ([shouldPreloadOn]) —
  /// le préchargement part **ici**, parce que c'est à cet instant que les
  /// stations deviennent visibles. Sans cela, passer à « Débit » n'aurait
  /// préchargé qu'au relâchement de geste suivant.
  ///
  /// `selectScale` est synchrone (le rechargement ONDE qu'il déclenche
  /// éventuellement notifie de son côté) : rien à attendre avant le
  /// préchargement, qui ne dépend que des points déjà chargés.
  void _handleScaleSelected(MapScaleKind kind) {
    widget.viewModel.selectScale(kind);

    if (!shouldPreloadOn(kind)) {
      return;
    }

    unawaited(widget.viewModel.preloadVisibleStations());
  }

  @override
  Widget build(BuildContext context) {
    // Tout est DANS le `ListenableBuilder` : la légende doit basculer avec
    // l'échelle à l'instant du geste (`BR-008`, `UC-001 A6`), et le bandeau
    // d'erreur apparaître dès que le ViewModel le pose. Le panneau de fiche,
    // lui, est une instance de widget CONSTANTE d'une reconstruction à
    // l'autre (`widget.stationSheet`) : `Element.updateChild` court-circuite
    // sur un widget identique, le replacer ici ne le reconstruit donc pas —
    // il porte son propre `ListenableBuilder` sur le ViewModel de la fiche.
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              FlutterMap(
                options: _mapOptions,
                children: buildMapLayers(
                  scale: widget.viewModel.scale,
                  stations: widget.viewModel.stations,
                  ondeObservations: widget.viewModel.ondeObservations,
                  now: widget.now,
                  onStationTap: widget.onStationTap,
                  onOndeTap: widget.onOndeTap,
                  stateOf: widget.viewModel.stateOf,
                ),
              ),
              ...buildMapOverlays(
                scale: widget.viewModel.scale,
                onSelect: _handleScaleSelected,
                error: widget.viewModel.error,
                stationSheet: widget.stationSheet,
              ),
            ],
          );
        },
      ),
    );
  }
}
