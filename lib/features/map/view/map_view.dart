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
// ⚠️ Arbitrage du commanditaire du 2026-09-23 (`W3c`, « trop de bandeaux à
// l'écran ») : le bandeau permanent de la carte (`W3`) et son menu de
// réaffichage (`W3b`) sont RETIRÉS — la fonction qui les empilait au-dessus
// de la carte disparaît avec eux. À leur place, un seul contrôle partagé
// ([WarningLink],
// `lib/features/shared/warning_link.dart`) : posé au-dessus de la légende,
// il ouvre en lecture seule la même fenêtre que celle des fiches
// (`station_summary_sheet.dart`, `onde_summary_sheet.dart`).
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
// la vue affiche un avis au lieu d'une carte muette (`BR-007`).
//
// ⚠️ Depuis `U6`, cet avis **nomme sa source** : `MapErrorBanner` — un
// bandeau rouge portant `error.toString()` — est retiré, car `BR-007`
// exige un « message par source », et un `toString()` n'en nomme aucune.
// Ce qu'il faut dire et quand le dire vit dans `map_empty_states.dart`
// ([mapNoticesFor], une fonction pure) ; [buildMapOverlays] se contente
// d'appeler cette décision et de rendre ce qu'elle rend. La source, elle,
// vient du ViewModel ([MapViewModel.errorSource]) : la vue ne peut pas
// inspecter une `HubEauFailure`, qui vit sous `lib/data/`.
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
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view/ign_attribution_badge.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_scale_chips.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

// API de caméra lue dans le paquet installé `flutter_map` 8.3.2 avant
// d'être écrite (étape 3 de la tâche Z4, jamais de mémoire) :
// - `MapController.fitCamera(CameraFit cameraFit)` —
//   `lib/src/map/controller/map_controller.dart` l. 126 du paquet installé ;
// - `MapController.move(LatLng center, double zoom, {…})` — même fichier,
//   l. 57 ;
// - `CameraFit.bounds({required LatLngBounds bounds, …})` —
//   `lib/src/map/camera/camera_fit.dart` l. 21 ;
// - `LatLngBounds(LatLng corner1, LatLng corner2)` — deux coins opposés,
//   quel que soit l'ordre — `lib/src/geo/latlng_bounds.dart`.
// [_MapViewState._handleClusterSelect] n'applique que ce que
// `MapViewModel.zoomTargetFor` (Z3) a déjà décidé : aucune géométrie n'est
// calculée ici.

/// Traduit l'emprise visible d'une caméra `flutter_map` en [Bounds] de
/// domaine — la SEULE conversion du fichier, partagée par [_handleMapEvent]
/// (fin d'un geste de carte) et [_MapViewState._handleClusterSelect] (fin
/// d'une sélection de pastille, relecture du coordinateur) : les deux
/// signalent la même chose au ViewModel, « voici où la caméra se trouve
/// maintenant », et ne doivent pas pouvoir diverger sur la façon de le dire.
Bounds _boundsFromLatLngBounds(LatLngBounds bounds) => Bounds(
  west: bounds.west,
  south: bounds.south,
  east: bounds.east,
  north: bounds.north,
);

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLatitude = 46.6;

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLongitude = 2.2;

/// Zoom initial — la France métropolitaine tient à l'écran.
const double initialMapZoom = 5;

// `minimumMapZoom` et `maximumMapZoom` (importées ci-dessus, avec
// `ignMaxNativeZoom`) vivent dans
// `features/map/view_model/map_zoom_bounds.dart`, Dart pur (`K1`,
// relecture du coordinateur du 2026-09-23) : `MapViewModel` doit pouvoir
// décider si `+`/`−` restent actifs (`canZoomIn`/`canZoomOut`) sans importer
// un fichier de `features/map/view/`. `MapOptions.minZoom`/`maxZoom`,
// ci-dessous, restent la SEULE consommatrice de ces bornes côté caméra — les
// redéfinir ici en ferait deux sources de vérité, ce que cette tâche
// s'interdit précisément.

/// État par défaut de [buildMapLayers.stateOf] : aucune requête n'a abouti
/// pour cette station. Une fonction de premier niveau, et non une fermeture
/// `(_) => const NonChargee()` — seul un tear-off de fonction de premier
/// niveau est une expression constante, donc utilisable comme valeur par
/// défaut d'un paramètre.
StationMapState _alwaysUnloaded(StationCode code) => const NonChargee();

/// Reclasse [observations] par code de station — la forme que
/// [buildMapLayers] attend ([_ondeMarkers] les indexe déjà ainsi côté
/// dépôt). `MapViewModel.individualOndeObservations` (Z3) rend une `List`,
/// filtrée des points déjà couverts par une pastille (`ADR-015`) : cette
/// fonction ne fait que reprendre la forme, aucun filtre supplémentaire.
Map<OndeStationCode, OndeObservation> _byCode(
  List<OndeObservation> observations,
) => <OndeStationCode, OndeObservation>{
  for (final OndeObservation observation in observations)
    observation.point.code: observation,
};

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
/// [ageOf] rend l'âge de campagne (`BR-010`) d'une observation ONDE — en
/// production, `MapViewModel.ondeAgeOf`, sur l'horloge **déjà injectée** du
/// ViewModel. **Déplacé** depuis un paramètre `now` (`H2`, 2026-09-22) : le
/// calcul de l'âge — conversion en UTC comprise — vit désormais dans le
/// ViewModel, qui possède l'horloge ; cette vue ne fait plus qu'appeler
/// [ageOf] par observation.
///
/// **Requis, sans valeur par défaut** (correction du 2026-09-23) :
/// contrairement à [stateOf], aucune valeur n'est neutre ici — un repli
/// constant (« toujours récente ») serait un mensonge silencieux sur une
/// campagne vieille de plus de 60 jours (`BR-010`). Un appelant qui n'a pas
/// d'âge à donner doit le dire explicitement, jamais hériter d'un défaut.
/// [clusters] porte les pastilles de zone administrative (`ADR-015`, Z4),
/// dessinées **avant** les marqueurs individuels — vide au niveau
/// individuel ([MapViewModel.clusters]). [onClusterSelect] est appelé avec
/// la pastille tapée ; en production, il applique
/// `MapViewModel.zoomTargetFor` à la caméra (`_MapViewState`) et **n'ouvre
/// aucune fiche** — `onStationTap`/`onOndeTap` ne sont jamais atteints par ce
/// tap (`BR-009`).
List<Widget> buildMapLayers({
  required MapScaleKind scale,
  required List<StationPoint> stations,
  Map<OndeStationCode, OndeObservation> ondeObservations =
      const <OndeStationCode, OndeObservation>{},
  required CampaignAge Function(OndeObservation observation) ageOf,
  void Function(StationCode code)? onStationTap,
  void Function(OndePoint point)? onOndeTap,
  StationMapState Function(StationCode code) stateOf = _alwaysUnloaded,
  List<MapAreaCluster> clusters = const <MapAreaCluster>[],
  void Function(MapAreaCluster cluster)? onClusterSelect,
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
  final List<Marker> individualMarkers = switch (scale) {
    MapScaleKind.ecoulement => _ondeMarkers(
      ondeObservations: ondeObservations,
      ageOf: ageOf,
      onOndeTap: onOndeTap,
    ),
    MapScaleKind.debit => _stationMarkers(
      stations: stations,
      stateOf: stateOf,
      onStationTap: onStationTap,
    ),
  };

  // Les pastilles d'abord, puis les individuels (plan T1, tâche Z4) : au
  // niveau individuel, `clusters` est vide et cette liste ne change rien.
  final List<Marker> markers = <Marker>[
    ..._areaClusterMarkers(clusters: clusters, onSelect: onClusterSelect),
    ...individualMarkers,
  ];

  if (markers.isNotEmpty) {
    layers.add(MarkerLayer(markers: markers));
  }

  return layers;
}

/// Les pastilles de zone administrative (`ADR-015`). [AreaClusterMarker] est
/// un widget de contenu pur (voir son en-tête) : c'est ici, comme pour
/// [_stationMarkers] et [_ondeMarkers], que le `GestureDetector` de
/// sélection est posé — sans second `Semantics` : la pastille porte déjà le
/// sien, préfixé par l'échelle (`BR-008`).
List<Marker> _areaClusterMarkers({
  required List<MapAreaCluster> clusters,
  required void Function(MapAreaCluster cluster)? onSelect,
}) {
  final void Function(MapAreaCluster cluster)? handleSelect = onSelect;

  return clusters
      .map(
        (MapAreaCluster cluster) => Marker(
          point: LatLng(cluster.latitude, cluster.longitude),
          width: areaClusterMarkerSize,
          height: areaClusterMarkerSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleSelect == null ? null : () => handleSelect(cluster),
            child: AreaClusterMarker(cluster: cluster),
          ),
        ),
      )
      .toList();
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
          width: minimumTapTarget,
          height: minimumTapTarget,
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
              // annoncerait l'état deux fois. L'action de tap, elle, reste :
              // le `GestureDetector` est ici l'ANCÊTRE de ce `Semantics`, pas
              // son descendant, et `excludeSemantics` ne masque que les
              // descendants (relecture du 2026-09-23).
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
  required CampaignAge Function(OndeObservation observation) ageOf,
  required void Function(OndePoint point)? onOndeTap,
}) {
  final void Function(OndePoint point)? handleTap = onOndeTap;

  return ondeObservations.values.map((OndeObservation observation) {
    final OndePoint point = observation.point;
    final CampaignAge age = ageOf(observation);

    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: minimumTapTarget,
      height: minimumTapTarget,
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
/// 1. **le contrôle d'avertissement, toujours** ([WarningLink], en haut à
///    droite, au-dessus de la légende, `W3c`) — remplace le bouton de menu
///    (`W3b`) et le bandeau permanent (`W3`), tous deux retirés par
///    l'arbitrage du commanditaire du 2026-09-23 ;
/// 1bis. **la légende, toujours** (`MapLegend`, sous le contrôle, dans
///    la même colonne — jamais recouverte, par construction) — `BR-008` en
///    fait une pièce obligatoire : les trois échelles du produit réutilisent
///    les mêmes teintes, et c'est elle qui nomme celle qui est active. Elle
///    est rendue quel que soit [error] : une carte en panne reste une carte
///    qu'on lit ;
/// 2. les **puces de bascule d'échelle** ([MapScaleChips]), toujours, en
///    haut à gauche — y compris en erreur : une carte en panne reste une
///    carte dont on change l'échelle (`BR-007`, `UC-001 A6`) ;
/// 3. les **avis** — absence, hors couverture, panne, lignes illisibles —,
///    décidés par [mapNoticesFor] (`BR-007` : jamais une carte muette, jamais
///    un état par défaut). Posés **sous** les puces, dans la même colonne :
///    la largeur de cette colonne est bornée, elle réserve toute la place de
///    la légende et n'empiète jamais dessus ;
/// 4. les **panneaux de fiche** — station ([stationSheet]) et point ONDE
///    ([ondeSheet]) —, chacun s'il est fourni, en bas à gauche et dans cet
///    ordre. Les deux dépendent d'échelles différentes et ne sont jamais
///    ouverts ensemble en production ; fournis ensemble, ils s'empilent
///    plutôt que de se masquer (`BR-007`) ;
/// 5. les **boutons de zoom et de recentrage** ([MapControls], `K1`), en bas
///    à droite, AU-DESSUS de l'attribution — jamais l'inverse, l'attribution
///    reste la dernière chose qu'un empilement pourrait masquer ;
/// 6. l'**attribution IGN**, toujours, tout en bas à droite — une condition
///    d'usage de la Licence Ouverte, jamais une finition (`04-ui.md` § 3).
///
/// [onSelect] est appelé avec l'échelle demandée par un tap de puce — en
/// production, `MapViewModel.selectScale`. [onWiden] l'est par l'action
/// « Élargir la recherche » de l'avis d'absence — en production,
/// `MapViewModel.widenSearch`. Les deux sont **requis** : un contrôle sans
/// rappel serait mort à l'écran.
///
/// [stations], [ondeObservations] et [ondeUnreadableRows] ne servent QU'À
/// décider des avis : cette fonction ne dessine aucun marqueur, c'est
/// [buildMapLayers] qui s'en charge. Elle n'en lit d'ailleurs que le vide ou
/// le non-vide — la décision elle-même est [mapNoticesFor], pure et testable
/// sans widget.
///
/// Les trois sont **requis**, sans valeur par défaut : un appelant qui en
/// oublie un ferait dire à l'écran « il n'y a rien ici » alors que la carte
/// dessine des marqueurs. Un oubli doit être une erreur de compilation, pas
/// une affirmation fausse à l'usager (`BR-007`).
List<Widget> buildMapOverlays({
  required MapScaleKind scale,
  required void Function(MapScaleKind kind) onSelect,
  required VoidCallback onWiden,
  required Object? error,
  required List<StationPoint> stations,
  required Map<OndeStationCode, OndeObservation> ondeObservations,
  required int ondeUnreadableRows,
  // `K1`, 2026-09-23 — [onZoomIn]/[onZoomOut] sont **nuls** quand
  // `MapViewModel.canZoomIn`/`canZoomOut` disent qu'un cran de plus n'aurait
  // aucun effet ; [MapControls] rend alors le bouton correspondant
  // désactivé. [onRecenter], lui, a toujours un effet — non nul.
  required VoidCallback? onZoomIn,
  required VoidCallback? onZoomOut,
  required VoidCallback onRecenter,
  MapErrorSource? errorSource,
  Widget? stationSheet,
  Widget? ondeSheet,
}) {
  final Widget? sheet = stationSheet;
  final Widget? onde = ondeSheet;
  final List<MapNotice> notices = mapNoticesFor(
    scale: scale,
    hasStations: stations.isNotEmpty,
    hasOndeObservations: ondeObservations.isNotEmpty,
    error: error,
    errorSource: errorSource,
    ondeUnreadableRows: ondeUnreadableRows,
  );

  return <Widget>[
    Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(_overlayPadding),
        // Une colonne, comme celle des puces à gauche : le contrôle
        // d'avertissement et la légende ne peuvent alors PAS se chevaucher,
        // par construction (`W3c`). `SingleChildScrollView` plutôt qu'un
        // `Column` nu : sur une hauteur d'écran courte (paysage, écran
        // divisé), le contrôle ET la légende « écoulement » (six niveaux)
        // peuvent dépasser l'espace vertical restant — un défilement local
        // vaut mieux qu'un `RenderFlex` débordant hors écran, jamais
        // constaté par l'usager.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const WarningLink(),
              const SizedBox(height: _overlayPadding),
              MapLegend(scale: scale),
            ],
          ),
        ),
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
            for (final MapNotice notice in notices)
              Padding(
                padding: const EdgeInsets.only(top: _overlayPadding),
                child: buildMapNotice(notice, onWiden: onWiden),
              ),
          ],
        ),
      ),
    ),
    if (sheet != null || onde != null)
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          // Marge basse plus épaisse : elle dégage le bandeau d'attribution
          // IGN, qui reste lisible en toutes circonstances (Licence
          // Ouverte, `04-ui.md` § 3).
          //
          // Marge DROITE réservée à la colonne des boutons de zoom
          // (arbitrage du coordinateur du 2026-09-23, « décaler la
          // fiche ») : sur un écran étroit, le panneau de fiche s'étend
          // sur toute la largeur disponible — sans cette réserve, il
          // passerait SOUS `MapControls`, posés en bas à droite. Même
          // schéma que la réserve de la légende pour les puces d'échelle,
          // plus haut dans cette fonction.
          padding: const EdgeInsets.fromLTRB(
            _overlayPadding,
            _overlayPadding,
            _sheetRightPadding,
            _sheetBottomPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
            // Les deux fiches partagent le MÊME emplacement : elles ne sont
            // jamais ouvertes ensemble, mais cette garantie vient de la
            // racine de composition (`main.dart` : chaque rappel de tap
            // ferme l'autre fiche avant d'ouvrir la sienne), pas des
            // échelles (relecture 2026-09-14). Une `Column` plutôt qu'une
            // superposition tout de même : si les deux panneaux arrivaient
            // ensemble, aucun n'écraserait l'autre — un panneau masqué
            // serait pire qu'un panneau de trop (`BR-007`). L'ordre est
            // fixé — station au-dessus, ONDE en dessous — pour que
            // l'empilement soit une décision testée et non un hasard de
            // `Stack`.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ?sheet,
                if (sheet != null && onde != null)
                  const SizedBox(height: _overlayPadding),
                ?onde,
              ],
            ),
          ),
        ),
      ),
    Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(_overlayPadding),
        // Une colonne, comme celle du contrôle d'avertissement et de la
        // légende en haut à droite (`K1`) : les boutons de zoom et
        // l'attribution IGN ne peuvent alors PAS se chevaucher, par
        // construction.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            MapControls(
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onRecenter: onRecenter,
            ),
            const SizedBox(height: _overlayPadding),
            const IgnAttributionBadge(),
          ],
        ),
      ),
    ),
  ];
}

// `buildMapScreen` (bandeau `W3` + menu `W3b`) est retirée par `W3c` : `_MapViewState.build` rend directement `mapAndOverlays`.

/// Marge d'une surcouche au bord de la carte, en pixels logiques.
const double _overlayPadding = 8;

/// Marge basse du panneau de fiche : elle dégage l'attribution IGN.
const double _sheetBottomPadding = 32;

/// Largeur maximale du panneau de fiche, en pixels logiques.
const double _sheetMaxWidth = 420;

/// Largeur de la colonne des boutons de zoom ([MapControls]), en pixels
/// logiques : chaque bouton mesure [minimumTapTarget]
/// (`lib/features/shared/tap_target.dart`), et la colonne les empile avec
/// `CrossAxisAlignment.end` — sa largeur ne dépasse donc jamais celle d'un
/// bouton. Nommée plutôt que recopiée : c'est ce que [_sheetRightPadding]
/// doit réserver pour que la fiche ne passe jamais sous ces boutons
/// (arbitrage du coordinateur du 2026-09-23, « décaler la fiche »).
const double _mapControlsColumnWidth = minimumTapTarget;

/// Marge droite que le panneau de fiche réserve pour ne jamais passer sous
/// la colonne des boutons de zoom, posée en bas à droite : la largeur de
/// cette colonne ([_mapControlsColumnWidth]), plus la marge qui l'entoure
/// des deux côtés ([_overlayPadding], comme partout ailleurs dans ce
/// fichier). Dérivée de [minimumTapTarget], jamais un nombre posé au hasard.
const double _sheetRightPadding = _mapControlsColumnWidth + 2 * _overlayPadding;

// `MapScaleChips`/`_MapScaleChip` (`map_scale_chips.dart`) et
// `IgnAttributionBadge` (`ign_attribution_badge.dart`) sont **extraits** de
// ce fichier par `K1` (2026-09-23), au même titre que `MapControls`
// (`map_controls.dart`) : aucun changement de comportement, seuls les
// imports ci-dessus changent.

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
  /// [onOndeTap] et [ondeSheet] sont couplés de la même façon depuis `U4` :
  /// la fiche ONDE existe et se branche au tap d'un marqueur d'écoulement.
  const MapView({
    required this.viewModel,
    this.onStationTap,
    this.onOndeTap,
    this.stationSheet,
    this.ondeSheet,
    super.key,
  }) : assert(
         (onStationTap == null) == (stationSheet == null),
         'onStationTap et stationSheet vont ensemble : une fiche sans tap '
         "ne s'ouvre jamais, un tap sans fiche n'affiche rien",
       ),
       assert(
         (onOndeTap == null) == (ondeSheet == null),
         "onOndeTap et ondeSheet vont ensemble : une fiche sans tap ne s'ouvre "
         "jamais, un tap sans fiche n'affiche rien",
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
  /// (règle `feature-vers-feature`). `main.dart` le branche sur
  /// `OndeSheetViewModel.open` depuis `U4`.
  final void Function(OndePoint point)? onOndeTap;

  /// Le panneau de la fiche station, déjà composé avec son ViewModel par
  /// `main.dart`, et affiché en bas de la carte. `null` tant qu'aucune fiche
  /// n'est branchée — la carte reste alors ce qu'elle était en T0.
  ///
  /// La fiche ne se ferme que par son propre bouton (et par
  /// `StationSheetViewModel.close`) : un tap sur la carte hors marqueur ne
  /// la ferme pas.
  final Widget? stationSheet;

  /// Le panneau de la fiche d'un point ONDE, déjà composé avec son ViewModel
  /// par `main.dart`, et affiché au même endroit que [stationSheet]. `null`
  /// tant qu'aucune fiche ONDE n'est branchée.
  ///
  /// Les deux panneaux ne sont jamais ouverts en même temps en production :
  /// ils dépendent d'échelles différentes, et un seul jeu de marqueurs est
  /// tapable à la fois.
  final Widget? ondeSheet;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// Le contrôleur de caméra `flutter_map` (Z4) : c'est lui que
  /// [_handleClusterSelect] pilote pour appliquer la cible calculée par
  /// `MapViewModel.zoomTargetFor` (Z3) — jamais de géométrie recalculée ici.
  final MapController _mapController = MapController();

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
    unawaited(widget.viewModel.start(zoom: initialMapZoom));
  }

  /// Câblé à `MapOptions.onMapEvent` : ne signale un geste terminé que pour
  /// les événements de fin de geste ([shouldRefreshOn]), jamais à chaque
  /// frame d'un glisser en cours. La vue ne fait plus que traduire
  /// l'événement `flutter_map` en emprise de domaine et le signaler au
  /// ViewModel ([MapViewModel.onGestureEnded], `H2`) : c'est lui qui décide
  /// de charger puis, le cas échéant, de précharger — l'enchaînement vivait
  /// ici, dans `_loadThenPreload`, et n'était couvert par aucun test.
  void _handleMapEvent(MapEvent event) {
    if (!shouldRefreshOn(event)) {
      return;
    }

    unawaited(
      widget.viewModel.onGestureEnded(
        _boundsFromLatLngBounds(event.camera.visibleBounds),
        zoom: event.camera.zoom,
      ),
    );
  }

  /// « Élargir la recherche » : le ViewModel recharge une emprise deux fois
  /// plus haute et deux fois plus large, autour du même centre. La vue ne
  /// calcule aucune géométrie — elle branche.
  ///
  /// ⚠️ **La caméra ne bouge pas** : `flutter_map` reste où l'usager l'a
  /// laissé, seule l'emprise INTERROGÉE s'élargit. Les marqueurs qui entrent
  /// dans la réponse mais pas dans l'écran restent hors champ jusqu'au
  /// prochain geste. Écart assumé pour `U6` et acté au plan : le
  /// déplacement de caméra arrive en `K1`, avec les contrôles de zoom.
  ///
  /// `unawaited` : le résultat du chargement passe par le ViewModel, jamais
  /// par ce futur — comme les autres appels en tir-et-oublie de cette vue.
  void _handleWiden() {
    unawaited(widget.viewModel.widenSearch());
  }

  /// Applique la cible calculée par `MapViewModel.zoomTargetFor` (Z3) —
  /// aucune géométrie n'est décidée ici, seulement traduite vers l'API du
  /// contrôleur `flutter_map` (voir la note de lecture en tête de fichier).
  /// `switch` exhaustif sur [ClusterZoomTarget] (`sealed class`, `BR-011`) :
  /// une variante ajoutée sans branche ici ne compile pas.
  ///
  /// ⚠️ **Relecture du coordinateur** : `fitCamera`/`move` déplacent la
  /// caméra en émettant un `MapEventMove` de source `mapController`
  /// (`map_events.dart` l. 134-145, via `moveRaw`,
  /// `map_controller_impl.dart` l. 142-178, du paquet installé) — un
  /// événement que [shouldRefreshOn] ignore délibérément (un `MapEventMove`
  /// est aussi émis à CHAQUE frame d'un glisser en cours, `NFR-01`).
  /// [MapViewModel.onGestureEnded] n'était donc **jamais** rappelé après
  /// une sélection de pastille : `level` restait bloqué au niveau d'origine
  /// malgré une caméra qui avait bougé. Cette méthode appelle donc
  /// explicitement [MapViewModel.onGestureEnded] avec l'emprise et le zoom
  /// **résultants** ([_mapController.camera], lu APRÈS le déplacement) —
  /// jamais [shouldRefreshOn] ni [_handleMapEvent], qui restent réservés
  /// aux gestes de la carte elle-même.
  ///
  /// `fitCamera`/`move` rendent `false` quand le déplacement demandé
  /// n'avait aucun effet (cible égale à la position courante, ou
  /// contrainte de caméra qui le refuse) : rien à signaler alors, la caméra
  /// n'a pas bougé.
  void _handleClusterSelect(MapAreaCluster cluster) {
    final bool moved = switch (widget.viewModel.zoomTargetFor(cluster)) {
      CoverBounds(bounds: final Bounds bounds, minZoom: final double minZoom) =>
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(bounds.south, bounds.west),
              LatLng(bounds.north, bounds.east),
            ),
            minZoom: minZoom,
          ),
        ),
      CentreOn(
        latitude: final double lat,
        longitude: final double lon,
        zoom: final double zoom,
      ) =>
        _mapController.move(LatLng(lat, lon), zoom),
    };

    _afterCameraMove(moved);
  }

  /// Signale au ViewModel un déplacement de caméra qui vient d'aboutir —
  /// avec l'emprise et le zoom **résultants** ([_mapController.camera], lu
  /// APRÈS le déplacement), jamais une géométrie recalculée ici. Factorisée
  /// par `K1` (2026-09-23) : [_handleClusterSelect] (sélection d'une
  /// pastille, `Z4`) et les trois handlers de [MapControls] ci-dessous
  /// partagent EXACTEMENT ce mécanisme — aucun enchaînement recopié.
  ///
  /// [moved] est le retour de `MapController.move`/`fitCamera` : `false`
  /// quand le déplacement demandé n'avait aucun effet (cible égale à la
  /// position courante, ou contrainte de caméra qui le refuse) — rien à
  /// signaler alors, la caméra n'a pas bougé (même relecture que
  /// [_handleClusterSelect] avant cette factorisation).
  void _afterCameraMove(bool moved) {
    if (!moved) {
      return;
    }

    final MapCamera camera = _mapController.camera;
    unawaited(
      widget.viewModel.onGestureEnded(
        _boundsFromLatLngBounds(camera.visibleBounds),
        zoom: camera.zoom,
      ),
    );
  }

  /// Bouton `+` de [MapControls] (`K1`) : un cran de [zoomStep] au même
  /// centre — jamais construit quand `MapViewModel.canZoomIn` est faux
  /// (voir [buildMapOverlays]).
  void _handleZoomIn() {
    final MapCamera camera = _mapController.camera;
    _afterCameraMove(
      _mapController.move(camera.center, camera.zoom + zoomStep),
    );
  }

  /// Bouton `−` de [MapControls] (`K1`) : symétrique de [_handleZoomIn].
  void _handleZoomOut() {
    final MapCamera camera = _mapController.camera;
    _afterCameraMove(
      _mapController.move(camera.center, camera.zoom - zoomStep),
    );
  }

  /// Bouton de recentrage de [MapControls] (`K1`) : ramène la caméra à
  /// l'emprise de démarrage — même centre et même zoom qu'au lancement de
  /// l'écran (`initialMapCenterLatitude`/`Longitude`, [initialMapZoom]).
  void _handleRecenter() {
    _afterCameraMove(
      _mapController.move(
        const LatLng(initialMapCenterLatitude, initialMapCenterLongitude),
        initialMapZoom,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
                mapController: _mapController,
                options: _mapOptions,
                children: buildMapLayers(
                  scale: widget.viewModel.scale,
                  // Marqueurs individuels de l'emprise courante — vide au
                  // niveau régroupé, `individualStations`/
                  // `individualOndeObservations` filtrant déjà ce qui est
                  // couvert par une pastille (`ADR-015`, Z3).
                  stations: widget.viewModel.individualStations,
                  ondeObservations: _byCode(
                    widget.viewModel.individualOndeObservations,
                  ),
                  ageOf: widget.viewModel.ondeAgeOf,
                  onStationTap: widget.onStationTap,
                  onOndeTap: widget.onOndeTap,
                  stateOf: widget.viewModel.stateOf,
                  clusters: widget.viewModel.clusters,
                  onClusterSelect: _handleClusterSelect,
                ),
              ),
              ...buildMapOverlays(
                scale: widget.viewModel.scale,
                onSelect: widget.viewModel.selectScale,
                onWiden: _handleWiden,
                error: widget.viewModel.error,
                errorSource: widget.viewModel.errorSource,
                stations: widget.viewModel.stations,
                ondeObservations: widget.viewModel.ondeObservations,
                ondeUnreadableRows: widget.viewModel.ondeUnreadableRows,
                onZoomIn: widget.viewModel.canZoomIn ? _handleZoomIn : null,
                onZoomOut: widget.viewModel.canZoomOut ? _handleZoomOut : null,
                onRecenter: _handleRecenter,
                stationSheet: widget.stationSheet,
                ondeSheet: widget.ondeSheet,
              ),
            ],
          );
        },
      ),
    );
  }
}
