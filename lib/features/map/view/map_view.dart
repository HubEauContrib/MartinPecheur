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
// `lib/features/shared/warning_link.dart`) : posé dans l'en-tête de la
// légende du bloc de lecture depuis `D2` d'Ergonomie (au-dessus de la légende
// avant), il ouvre en lecture seule la même fenêtre que celle des fiches
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
//   événements de **fin** de geste — sauf le changement de taille de la
//   carte, qui rejoue la contrainte de caméra ([_reapplyCameraConstraint]) :
//   il ne recharge rien lui-même, seul le recalage éventuel qui en découle
//   passe par [_afterCameraMove] et recharge alors l'emprise ; voir
//   [shouldRefreshOn]. La marge proportionnelle
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
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show floodWarningWindowText;
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart';
import 'package:martinpecheur/features/map/view/designated_point_pin.dart';
import 'package:martinpecheur/features/map/view/flood_section_label.dart';
import 'package:martinpecheur/features/map/view/flood_sections_layer.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_bottom.dart';
import 'package:martinpecheur/features/map/view/map_center_reticle.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_filter_sheet.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/map_reading_block.dart';
import 'package:martinpecheur/features/map/view/map_reading_selector.dart';
import 'package:martinpecheur/features/map/view/map_sheet_area.dart';
import 'package:martinpecheur/features/map/view/map_traversal_order.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show NoMinIntrinsicHeight;
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

// Le clavier (`K2`, 2026-09-23) : « tout ce qui se fait à la souris se fait
// au clavier » (`04-ui.md § 3`). `ZoomIntent`/`PanIntent` et [mapShortcuts]
// sont les signatures publiques attendues par le plan
// (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`,
// tâche K2) : des `Intent` de haut niveau, indépendants de `flutter_map`,
// que [_MapViewState] traduit ensuite en appels de caméra — les MÊMES
// [_handleZoomIn]/[_handleZoomOut] que `MapControls` (`K1`), et une nouvelle
// méthode symétrique pour le déplacement, [_MapViewState._handlePan].
// Aucun enchaînement n'est recopié : les deux origines de geste (souris,
// clavier) convergent vers [_MapViewState._afterCameraMove].

/// Demande un cran de zoom : `1` pour `+`/`=`, `-1` pour `−`. La valeur du
/// cran lui-même ([zoomStep], `map_controls.dart`) reste celle de `K1` —
/// [delta] ne porte que le SIGNE, jamais une amplitude différente de celle
/// du bouton `+`/`−` ou de la molette.
class ZoomIntent extends Intent {
  const ZoomIntent(this.delta);

  /// Positif pour zoomer, négatif pour dézoomer.
  final double delta;
}

/// Demande un déplacement de la caméra dans [direction] — un cran de
/// [keyboardPanFraction] de l'emprise visible, jamais un nombre de pixels :
/// la vue traduit, le déplacement lui-même reste proportionnel à ce qui est
/// affiché, quel que soit le zoom courant.
class PanIntent extends Intent {
  const PanIntent(this.direction);

  final AxisDirection direction;
}

/// Fraction de l'emprise visible que déplace un cran de flèche — nommée
/// plutôt qu'un nombre de pixels posé au hasard (`CLAUDE.md`, « jamais de
/// nombre magique ») : `0,25`, un quart d'écran par appui, assez pour
/// avancer sans jamais perdre le contexte affiché avant le geste.
const double keyboardPanFraction = 0.25;

/// Les raccourcis clavier de la carte : `+`/`=` avancent d'un cran de zoom,
/// `−` recule d'un cran, les quatre flèches déplacent la caméra. Une seule
/// source de vérité pour ces raccourcis — [_MapViewState.build] les pose via
/// `Shortcuts`, jamais recopiés ailleurs.
///
/// ⚠️ `Échap` (ferme la fiche ouverte) n'est PAS ici : cette carte n'a de
/// sens qu'à l'intérieur de [_MapViewState], qui seule sait comment fermer
/// une fiche (`MapView.onCloseSheets`) — [mapShortcuts] reste, lui, une
/// fonction PURE, testable sans widget, comme le veut l'étape 1 du plan.
// `CharacterActivator('+')`/`CharacterActivator('-')` et
// `numpadAdd`/`numpadSubtract` (relecture du commanditaire du 2026-09-23,
// 🟠 4) : `LogicalKeyboardKey.add`/`.equal`/`.minus` restent les touches
// PHYSIQUES du pavé principal — sur un clavier RÉEL (contrairement au
// simulateur de `flutter_test`, voir `map_keyboard_test.dart`), un clavier
// AZERTY produit le CARACTÈRE `+` avec Maj+`=`, ce que `SingleActivator`
// n'intercepte pas (il regarde la touche physique, pas le caractère rendu).
// `CharacterActivator` regarde le caractère produit, quel que soit
// l'agencement. Les touches du pavé NUMÉRIQUE (`numpadAdd`/
// `numpadSubtract`) sont, elles, des touches physiques DISTINCTES de `add`/
// `minus` (`hardware_keyboard.dart`, paquet Flutter installé) : aucune ne
// couvre l'autre.
Map<ShortcutActivator, Intent> mapShortcuts() => <ShortcutActivator, Intent>{
  const SingleActivator(LogicalKeyboardKey.add): const ZoomIntent(1),
  const SingleActivator(LogicalKeyboardKey.equal): const ZoomIntent(1),
  const SingleActivator(LogicalKeyboardKey.minus): const ZoomIntent(-1),
  const SingleActivator(LogicalKeyboardKey.numpadAdd): const ZoomIntent(1),
  const SingleActivator(LogicalKeyboardKey.numpadSubtract): const ZoomIntent(
    -1,
  ),
  const CharacterActivator('+'): const ZoomIntent(1),
  const CharacterActivator('-'): const ZoomIntent(-1),
  const SingleActivator(LogicalKeyboardKey.arrowUp): const PanIntent(
    AxisDirection.up,
  ),
  const SingleActivator(LogicalKeyboardKey.arrowDown): const PanIntent(
    AxisDirection.down,
  ),
  const SingleActivator(LogicalKeyboardKey.arrowLeft): const PanIntent(
    AxisDirection.left,
  ),
  const SingleActivator(LogicalKeyboardKey.arrowRight): const PanIntent(
    AxisDirection.right,
  ),
};

/// Ferme la ou les fiches ouvertes ([MapView.onCloseSheets]) — liée à
/// `Échap`. Privée : ni le plan ni aucun appelant hors de ce fichier n'a
/// besoin de la nommer, contrairement à [ZoomIntent]/[PanIntent].
class _CloseSheetsIntent extends Intent {
  const _CloseSheetsIntent();
}

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
/// tap (`BR-009`). [designatedPoint] pose l'épingle du point désigné
/// (`E1` de T2), au-dessus de tout le reste.
///
/// Lecture Crues (`M2` de T4, cadrage § 7.3 et § 7.4) : [floodLayer] est le
/// calque des traits (`buildFloodSectionsLayer`,
/// `flood_sections_layer.dart`), posé tel quel au-dessus des tuiles — c'est
/// l'appelant qui le garde d'un build à l'autre (Review Focus 1) ;
/// [floodLabels] sont les étiquettes, dans l'ordre de tabulation reçu
/// ([FloodLayerViewModel.labels]), posées dans la couche de marqueurs ;
/// [onFloodSectionTap] est appelé avec le code du tronçon dont l'étiquette
/// est touchée ou activée au clavier. Ni calque ni étiquette hors de
/// [MapScaleKind.crues] (`BR-008`). Ordre : tuiles, traits, marqueurs
/// (étiquettes sur la lecture Crues), épingle.
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
  GeoPoint? designatedPoint,
  Widget? floodLayer,
  List<FloodLabel> floodLabels = const <FloodLabel>[],
  void Function(FloodSectionCode code)? onFloodSectionTap,
}) {
  final List<Widget> layers = <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];

  // Le calque des traits, au-dessus des tuiles et sous tout marqueur : sur la
  // seule lecture Crues (`switch`, jamais une comparaison sur l'échelle).
  final Widget? traits = switch (scale) {
    MapScaleKind.crues => floodLayer,
    MapScaleKind.debit || MapScaleKind.ecoulement => null,
  };
  if (traits != null) {
    layers.add(traits);
  }

  // `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
  // sans branche ici ne compile pas — jamais une carte silencieusement vide.
  //
  // `focusOrderStartIndex: clusters.length` (arbitrage du commanditaire du
  // 2026-09-23, `K2`) : les marqueurs individuels suivent les pastilles
  // dans l'ordre de tabulation du groupe « carte » — leur indice de focus
  // continue donc APRÈS le dernier indice de pastille, jamais depuis 0 (ce
  // qui les ferait chevaucher).
  final List<Marker> individualMarkers = switch (scale) {
    MapScaleKind.ecoulement => _ondeMarkers(
      ondeObservations: ondeObservations,
      ageOf: ageOf,
      onOndeTap: onOndeTap,
      focusOrderStartIndex: clusters.length,
    ),
    MapScaleKind.debit => _stationMarkers(
      stations: stations,
      stateOf: stateOf,
      onStationTap: onStationTap,
      focusOrderStartIndex: clusters.length,
    ),
    // Lecture Crues (`M2` de T4) : ni station ni point ONDE (`BR-008`), les
    // seules étiquettes des tronçons.
    MapScaleKind.crues => _floodLabelMarkers(
      labels: floodLabels,
      onTap: onFloodSectionTap,
      focusOrderStartIndex: clusters.length,
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

  // L'épingle du point désigné (`E1` de T2) : dernière couche, au-dessus des
  // marqueurs, et inerte ([DesignatedPointPin]).
  final GeoPoint? pin = designatedPoint;
  if (pin != null) {
    layers.add(designatedPointLayer(pin));
  }

  return layers;
}

/// Les pastilles de zone administrative (`ADR-015`). [AreaClusterMarker] est
/// un widget de contenu pur (voir son en-tête) : c'est ici, comme pour
/// [_stationMarkers] et [_ondeMarkers], que le `GestureDetector` de
/// sélection est posé — sans second `Semantics` : la pastille porte déjà le
/// sien, préfixé par l'échelle (`BR-008`).
///
/// ⚠️ [KeyboardFocusRing] (arbitrage du commanditaire du 2026-09-23, `K2`) :
/// « carte » est un GROUPE de tabulation depuis cet arbitrage — Tab y entre
/// puis parcourt les pastilles (et les marqueurs individuels non rattachés,
/// [_stationMarkers]/[_ondeMarkers]) dans l'ordre où [clusters] les donne.
/// Cet ordre est décidé par `MapViewModel.orderedClusters` (distance
/// croissante au centre de l'emprise, code de zone en cas d'égalité) — cette
/// fonction ne trie RIEN, elle ne fait que rendre l'ordre reçu focalisable.
/// Entrée/Espace appellent [onSelect], exactement comme le tap.
List<Marker> _areaClusterMarkers({
  required List<MapAreaCluster> clusters,
  required void Function(MapAreaCluster cluster)? onSelect,
}) {
  final void Function(MapAreaCluster cluster)? handleSelect = onSelect;

  return <Marker>[
    for (final (int index, MapAreaCluster cluster) in clusters.indexed)
      Marker(
        // `key` (relecture du commanditaire du 2026-09-23, 🟠 3) :
        // `MarkerLayer` réconcilie ses enfants par CETTE clé — sans elle,
        // Flutter réconcilie par POSITION dans la liste, et un
        // réordonnancement (un geste qui change l'ordre déterministe du
        // groupe « carte ») ferait glisser l'état — dont le `FocusNode` de
        // [KeyboardFocusRing] — sur la pastille qui prend la même place,
        // pas sur celle qui a le focus. Niveau ET code : deux zones de
        // niveaux différents peuvent partager un même code administratif.
        key: ValueKey<String>('${cluster.level}-${cluster.area.code}'),
        point: LatLng(cluster.latitude, cluster.longitude),
        width: areaClusterMarkerSize,
        height: areaClusterMarkerSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handleSelect == null ? null : () => handleSelect(cluster),
          child: _carteFocusOrder(
            index,
            KeyboardFocusRing(
              onActivate: handleSelect == null
                  ? null
                  : () => handleSelect(cluster),
              canRequestFocus: handleSelect != null,
              child: AreaClusterMarker(cluster: cluster),
            ),
          ),
        ),
      ),
  ];
}

/// Pose l'ordre de tabulation d'un élément du groupe « carte », à [index]
/// dans l'ordre déjà décidé par le ViewModel (arbitrage du commanditaire du
/// 2026-09-23, `K2`).
///
/// Un `NumericFocusOrder` ENTIER, PAS une fraction de [mapTraversalOrderCarte]
/// (relecture du commanditaire du 2026-09-23, 🔴 1) : ce sous-groupe vit dans
/// son PROPRE `FocusTraversalGroup` ([_MapViewState.build], sur `FlutterMap`
/// tout entier), une échelle d'ordre INDÉPENDANTE de celle du groupe parent
/// — aucun nombre de marqueurs ne peut donc chevaucher [mapTraversalOrderSheet]
/// ou [mapTraversalOrderWarningLink], contrairement à l'ancien partage d'une
/// seule échelle par un pas de 0,001 (dépassé dès 500 marqueurs, une zone
/// dense en dépasse 1 400).
Widget _carteFocusOrder(int index, Widget child) => FocusTraversalOrder(
  order: NumericFocusOrder(index.toDouble()),
  child: child,
);

/// Les étiquettes des tronçons (`M2` de T4, cadrage § 7.4) : une par
/// [FloodLabel], à son ancre, [floodLabelWidth] sur la cible de la
/// plateforme. L'ordre de tabulation est celui de [labels], décidé par le
/// domaine (`floodLabelsFor` : distance au centre, puis code) ; cette
/// fonction ne trie rien. [focusOrderStartIndex] : voir [_stationMarkers].
List<Marker> _floodLabelMarkers({
  required List<FloodLabel> labels,
  required void Function(FloodSectionCode code)? onTap,
  int focusOrderStartIndex = 0,
}) {
  final void Function(FloodSectionCode code)? handleTap = onTap;

  return <Marker>[
    for (final (int index, FloodLabel label) in labels.indexed)
      Marker(
        // Même raison que [_stationMarkers] : le focus suit le tronçon, pas
        // la position dans la liste.
        key: ValueKey<String>(label.section.code.value),
        point: LatLng(label.anchor.latitude, label.anchor.longitude),
        width: floodLabelWidth,
        height: minimumTapTarget,
        child: _carteFocusOrder(
          focusOrderStartIndex + index,
          FloodSectionLabel(
            section: label.section,
            onActivate: handleTap == null
                ? null
                : () => handleTap(label.section.code),
          ),
        ),
      ),
  ];
}

/// Les marqueurs de l'échelle « débit » : une pastille par station.
///
/// [focusOrderStartIndex] (`K2`) : l'indice de focus du PREMIER marqueur de
/// cette liste dans le groupe « carte » — les pastilles ([_areaClusterMarkers])
/// occupent déjà les indices `0`..`focusOrderStartIndex - 1` ; sans ce
/// décalage, deux éléments du groupe partageraient le même ordre de
/// tabulation.
List<Marker> _stationMarkers({
  required List<StationPoint> stations,
  required StationMapState Function(StationCode code) stateOf,
  required void Function(StationCode code)? onStationTap,
  int focusOrderStartIndex = 0,
}) {
  // Copié dans un local `final` : la promotion de type survit ainsi dans la
  // fermeture construite pour chaque marqueur.
  final void Function(StationCode code)? handleTap = onStationTap;

  return <Marker>[
    for (final (int index, StationPoint station) in stations.indexed)
      Marker(
        // `key` (relecture du commanditaire du 2026-09-23, 🟠 3) : voir
        // [_areaClusterMarkers] — sans lui, un déplacement de caméra qui
        // change l'ensemble des stations visibles ferait glisser le focus
        // clavier (et l'état interne de [KeyboardFocusRing]) sur celle qui
        // prend la même POSITION dans la liste, pas sur celle qui l'avait.
        key: ValueKey<String>(station.code.value),
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
        child: _carteFocusOrder(
          focusOrderStartIndex + index,
          GestureDetector(
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
              // [KeyboardFocusRing] (`K2`, arbitrage du 2026-09-23) : SOUS
              // `Semantics`, comme les autres contrôles de la carte — la
              // clé du marqueur (posée par l'appelant via `Marker`, pas
              // ici) reste la racine du sous-arbre où le focus se trouve.
              // L'ordre dans lequel Tab atteint ces marqueurs vient de
              // `MapViewModel.orderedIndividualStations` : cette fonction
              // ne trie rien, elle rend l'ordre reçu focalisable.
              child: KeyboardFocusRing(
                onActivate: handleTap == null
                    ? null
                    : () => handleTap(station.code),
                canRequestFocus: handleTap != null,
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
        ),
      ),
  ];
}

/// Les marqueurs de l'échelle « écoulement » : un par observation ONDE,
/// posé sur le point que l'observation porte (`OndeObservation.point`, lu
/// sur la même ligne d'API — `T-09`), donc sans second appel au référentiel.
/// [focusOrderStartIndex] : voir [_stationMarkers].
List<Marker> _ondeMarkers({
  required Map<OndeStationCode, OndeObservation> ondeObservations,
  required CampaignAge Function(OndeObservation observation) ageOf,
  required void Function(OndePoint point)? onOndeTap,
  int focusOrderStartIndex = 0,
}) {
  final void Function(OndePoint point)? handleTap = onOndeTap;

  return <Marker>[
    for (final (int index, OndeObservation observation)
        in ondeObservations.values.indexed)
      Marker(
        // `key` (relecture du commanditaire du 2026-09-23, 🟠 3) : même
        // raison que [_stationMarkers].
        key: ValueKey<String>(observation.point.code.value),
        point: LatLng(observation.point.latitude, observation.point.longitude),
        width: minimumTapTarget,
        height: minimumTapTarget,
        child: _carteFocusOrder(
          focusOrderStartIndex + index,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleTap == null
                ? null
                : () => handleTap(observation.point),
            child: Semantics(
              button: true,
              label: _ondeSemanticLabel(observation, ageOf(observation)),
              // Même raison que pour une station : [OndeMarkerShape] porte
              // son propre `Semantics` pour la légende, le marqueur le
              // masque.
              excludeSemantics: true,
              // [KeyboardFocusRing] (`K2`) : même construction que
              // [_stationMarkers] — l'ordre de Tab vient de
              // `MapViewModel.orderedIndividualOndeObservations`.
              child: KeyboardFocusRing(
                onActivate: handleTap == null
                    ? null
                    : () => handleTap(observation.point),
                canRequestFocus: handleTap != null,
                child: Center(
                  child: SizedBox(
                    width: stationMarkerSize,
                    height: stationMarkerSize,
                    child: OndeMarkerShape(
                      category: observation.category,
                      age: ageOf(observation),
                      observedAt: observation.observedAt,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
  ];
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

/// Construit les surcouches de la carte, à poser PAR-DESSUS le `FlutterMap`
/// dans son `Stack`. Fonction pure, testable sans rendre de carte — même
/// esprit que [buildMapLayers], et pour la même raison : l'environnement de
/// test refuse le chargement de tuiles.
///
/// Depuis `D2` d'Ergonomie (cadrage du 2026-10-17, § 5 et § 6.5), elle rend
/// UNE mise en page, [MapLayout], qui pose dans la **carte visible** — l'écran
/// moins la fiche, dans la zone sûre de l'appareil — les pièces construites
/// par `S1` à `S4` et `B1`, sur trois largeurs ([mapLayoutWidthFor] : moins de
/// 600 px, de 600 à 799, 800 et plus), et répartit la hauteur dans l'ordre de
/// repli de l'arbitrage 11 ([allocateMapLayout]) :
/// 1. le **bloc de lecture**, en trois pièces posées sans écart, en tête de la
///    carte visible — toute sa largeur au téléphone, 480 px au plus en haut à
///    gauche au-delà :
///    - la partie fixe ([MapReadingBlockFixed]) : le **sélecteur**
///      ([MapReadingSelector]) — les trois lectures, puis, quand
///      [onToggleDesignationMode] est fourni, l'interrupteur « Restrictions »
///      (`E5` de T2, arbitrage du 2026-10-03) —, puis l'**en-tête**
///      « Légende · lecture » ([MapLegendHeader]) qui porte le contrôle
///      « ⚠ Avertissement » de la carte ([WarningLink], `W3c`), **toujours
///      présent**, fiche ouverte ou non (R4) ;
///    - les **avis** ([MapReadingBlockNotices]) — absence, hors couverture,
///      panne, lignes illisibles —, décidés par [mapNoticesFor] (`BR-007` :
///      jamais une carte muette), posés nus ;
///    - la **légende** ([MapReadingBlockLegend], [MapLegend] dans le bloc),
///      **toujours rendue**, quel que soit [error] (`BR-008`) ; elle défile
///      quand la place manque (premier repli, écart à `BR-008` accepté le
///      2026-10-12 et prolongé par l'arbitrage 11) ;
/// 2. le **bas de la carte** ([MapBottom]) : sous 600 px, une rangée
///    « Favoris », « Filtres » … −, +, recentrer, l'attribution IGN dessous ; à
///    partir de 600 px, la colonne des boutons d'entrée et des contrôles de
///    caméra, au bas à droite ; l'attribution, condition d'usage de la Licence
///    Ouverte (`04-ui.md` § 3), toujours ;
/// 3. **en mode** « Restrictions » ([onDesignateCenter] non nul) : la **bande
///    du bouton** de désignation ([DesignationBand]) au bas de la carte
///    visible, au-dessus de la rangée ou à gauche de la colonne, et le
///    **réticule** ([MapCenterReticle]) au centre horizontal de la carte
///    visible, à mi-hauteur entre la partie fixe du bloc et la bande ; au
///    repli 6, bande et réticule sont retirés — la bande est alors exclue du
///    focus, à l'écoute de [layoutReport] (le rapport arrive une trame après
///    la mise en page) ;
/// 4. la **fiche** — station ([stationSheet]), point ONDE ([ondeSheet]) et
///    tronçon ([floodSheet], T4), empilés dans cet ordre (`main.dart` n'en
///    ouvre qu'un à la fois ; fournis ensemble, ils s'empilent plutôt que de
///    se masquer, `BR-007`) — sous 800 px en **fiche du bas**, toute la
///    largeur, au bas de l'écran, son contenu dans la largeur de lecture
///    (R18) ; dès 800 px en **panneau latéral** de 380 px, à droite, sur toute
///    la hauteur, un filet à gauche. Leur fond blanc se prolonge sous la marge
///    système (spec § 6.5 : « au bas de l'écran ») ; le contenu reste dans la
///    zone sûre. **Provisoirement** (jusqu'à `D5`), la zone des fiches défile
///    elle-même, par [sheetScrollController] (`K4` de T3 : la racine de
///    composition la ramène en haut à chaque ouverture), et annonce une
///    hauteur repliée nulle ([NoMinIntrinsicHeight]) : c'est elle qui cède au
///    repli 2.
///
/// Aucune fiche ne se peint jamais sur le bloc ni sur le bas ; la carte, elle,
/// ne bouge pas quand une fiche s'ouvre ou se ferme (arbitrage 12) : cette
/// fonction ne touche pas à la caméra.
///
/// L'ordre de tabulation (`K2`, `K1` de T3, spec § 5.7) est porté par les
/// constantes `mapTraversalOrder*` : entrées du sélecteur, action de l'avis,
/// « Favoris », « Filtres », zoom et recentrer, bouton de désignation (en
/// mode), carte, fiche, « ⚠ Avertissement » de la carte en dernier.
///
/// [layoutReport] reçoit le rapport de la dernière mise en page
/// ([MapLayoutReport]) : la carte visible, le réticule, la répartition. C'est
/// l'appelant qui le possède et le dispose (`_MapViewState`).
///
/// [onToggleDesignationMode] (`E5` de T2, arbitrage du 2026-10-03) est
/// appelé par l'entrée « Restrictions » — en production,
/// `MapViewModel.toggleDesignationMode` ; `null` : aucune désignation n'est
/// câblée, l'entrée est absente. [onDesignateCenter] n'est non nul que
/// **dans le mode** : c'est lui qui fait exister le bouton, son indice et le
/// réticule, et l'entrée s'allume sur ce même fait
/// (`designationMode: onDesignateCenter != null`) — aucun second état ici.
///
/// [onSelect] est appelé avec la lecture demandée — en production,
/// `MapViewModel.selectScale`. [onWiden] l'est par l'action « Élargir la
/// recherche » de l'avis d'absence — en production,
/// `MapViewModel.widenSearch`. [onClearFilters] l'est par l'action « Effacer
/// les filtres » de l'avis des filtres — en production,
/// `MapViewModel.clearFilter`. Ces trois rappels sont **requis** : un
/// contrôle sans rappel serait mort à l'écran.
///
/// [stations], [ondeObservations], [ondeUnreadableRows] et
/// [filterHidesEverything] ne servent QU'À décider des avis : cette fonction
/// ne dessine aucun marqueur, c'est [buildMapLayers] qui s'en charge. Ces
/// quatre faits sont **requis**, sans valeur par défaut : un appelant qui en
/// oublie un ferait dire à l'écran « il n'y a rien ici » alors que la carte
/// dessine des marqueurs (`BR-007`).
///
/// Lecture Crues (`M5` de T4, cadrage § 7.1, § 7.5, § 7.7) — quatre
/// paramètres **optionnels** : [floodNotices] sont les avis de la lecture
/// (`floodNoticesFor`), passés à [mapNoticesFor], qui ne les rend que sur
/// [MapScaleKind.crues] ; [onRetryFlood] est l'action « Réessayer » de ses
/// avis d'échec ; [floodInformationDate] est la date de la carte de vigilance
/// lue, que la légende cite ; [floodSheet] est la fiche tronçon. Sur la
/// lecture Crues, la fenêtre « ⚠ Avertissement » ajoute
/// `floodWarningWindowText` sous le texte général (`BR-015`).
List<Widget> buildMapOverlays({
  required MapScaleKind scale,
  required void Function(MapScaleKind kind) onSelect,
  required VoidCallback onWiden,
  required Object? error,
  required List<StationPoint> stations,
  required Map<OndeStationCode, OndeObservation> ondeObservations,
  required int ondeUnreadableRows,
  // `F8` de T3 : `MapViewModel.filterHidesEverything` et
  // `MapViewModel.clearFilter`. Requis, comme les faits lus : un oubli ferait
  // dire « personne ne mesure ici » à une carte que le filtre a vidée.
  required bool filterHidesEverything,
  required VoidCallback onClearFilters,
  // `F10b` de T3 : `MapViewModel.filterActive` et l'ouverture de la feuille
  // « Filtres ». Requis : un bouton sans rappel serait mort à l'écran, et
  // un état oublié tairait qu'un filtre masque des lieux (`BR-007`).
  required bool filterActive,
  required VoidCallback onOpenFilters,
  // `K1`, 2026-09-23 — [onZoomIn]/[onZoomOut] sont **nuls** quand
  // `MapViewModel.canZoomIn`/`canZoomOut` disent qu'un cran de plus n'aurait
  // aucun effet ; [MapControls] rend alors le bouton correspondant
  // désactivé. [onRecenter], lui, a toujours un effet — non nul.
  required VoidCallback? onZoomIn,
  required VoidCallback? onZoomOut,
  required VoidCallback onRecenter,
  // `D2` d'Ergonomie : le rapport de la mise en page, possédé par l'appelant.
  required ValueNotifier<MapLayoutReport?> layoutReport,
  VoidCallback? onDesignateCenter,
  VoidCallback? onToggleDesignationMode,
  MapErrorSource? errorSource,
  Widget? stationSheet,
  Widget? ondeSheet,
  // `K4` de T3 : le contrôleur du défilement de la zone des fiches, tenu par
  // la racine de composition, qui remet la position à zéro à chaque
  // ouverture de fiche. `null` : le défilement garde son contrôleur interne.
  // `D5` le passe aux corps des fiches.
  ScrollController? sheetScrollController,
  // `S10` de T3 : l'ouverture de l'écran « Favoris », injectée par la racine
  // de composition. `null` : le bouton « Favoris » est absent du groupe des
  // boutons d'entrée.
  VoidCallback? onOpenFavorites,
  List<MapNotice> floodNotices = const <MapNotice>[],
  VoidCallback? onRetryFlood,
  DateTime? floodInformationDate,
  Widget? floodSheet,
}) {
  final Widget? sheet = stationSheet;
  final Widget? onde = ondeSheet;
  final Widget? flood = floodSheet;
  // Les panneaux de fiche fournis, dans l'ordre d'empilement : station, point
  // ONDE, tronçon. Sans écart entre eux : un panneau fermé vaut
  // `SizedBox.shrink`, et la mise en page ne tient la fiche pour OUVERTE que
  // si la zone a une hauteur (un écart la dirait ouverte, fiches fermées).
  final List<Widget> panels = <Widget>[?sheet, ?onde, ?flood];
  final VoidCallback? designate = onDesignateCenter;
  final List<MapNotice> notices = mapNoticesFor(
    scale: scale,
    hasStations: stations.isNotEmpty,
    hasOndeObservations: ondeObservations.isNotEmpty,
    error: error,
    errorSource: errorSource,
    ondeUnreadableRows: ondeUnreadableRows,
    filterHidesEverything: filterHidesEverything,
    floodNotices: floodNotices,
  );

  return <Widget>[
    // Une seule source de largeur : celle que la mise en page de la carte
    // reçoit (et pose), lue ici par un `LayoutBuilder` — personne n'interroge
    // les hauteurs intrinsèques de ce qui l'enveloppe.
    LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final EdgeInsets safeInsets = MediaQuery.paddingOf(context);
        final MapLayoutWidth width = mapLayoutWidthFor(constraints.maxWidth);
        final bool compact = switch (width) {
          MapLayoutWidth.compact => true,
          MapLayoutWidth.wide || MapLayoutWidth.panel => false,
        };
        final bool sidePanel = switch (width) {
          MapLayoutWidth.panel => true,
          MapLayoutWidth.compact || MapLayoutWidth.wide => false,
        };
        return MapLayout(
          padding: _overlayPadding,
          safeInsets: safeInsets,
          reticleBandHeight: mapCenterReticleSize + 2 * _overlayPadding,
          report: layoutReport,
          children: <Widget>[
            // La partie fixe du bloc : le sélecteur entier sous son rang de
            // tabulation ; le lien, plus profond, porte le sien (le dernier).
            // Le texte propre de la fenêtre « ⚠ Avertissement » : celui de la
            // crue sur la seule lecture Crues (cadrage § 7.7, `BR-015`) —
            // trois branches, sans joker.
            MapLayoutChild(
              slot: MapLayoutSlot.blockFixed,
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(mapTraversalOrderChips),
                child: MapReadingBlockFixed(
                  selector: MapReadingSelector(
                    scale: scale,
                    onSelect: onSelect,
                    designationMode: designate != null,
                    onToggleDesignationMode: onToggleDesignationMode,
                  ),
                  header: MapLegendHeader(
                    scale: scale,
                    warningLink: FocusTraversalOrder(
                      order: const NumericFocusOrder(
                        mapTraversalOrderWarningLink,
                      ),
                      child: WarningLink(
                        extraText: switch (scale) {
                          MapScaleKind.crues => floodWarningWindowText,
                          MapScaleKind.ecoulement => null,
                          MapScaleKind.debit => null,
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Les avis, nus, chacun sous le rang de tabulation des avis
            // (`K1` de T3) : leur action suit les entrées du sélecteur.
            MapLayoutChild(
              slot: MapLayoutSlot.blockNotices,
              child: MapReadingBlockNotices(
                notices: <Widget>[
                  for (final MapNotice notice in notices)
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(mapTraversalOrderNotices),
                      child: buildMapNotice(
                        notice,
                        onWiden: onWiden,
                        onClearFilters: onClearFilters,
                        onRetryFlood: onRetryFlood,
                      ),
                    ),
                ],
              ),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.blockLegend,
              child: MapReadingBlockLegend(
                legend: MapLegend(
                  scale: scale,
                  floodInformationDate: floodInformationDate,
                  inBlock: true,
                ),
              ),
            ),
            MapLayoutChild(
              slot: MapLayoutSlot.bottom,
              child: MapBottom(
                compact: compact,
                onOpenFilters: onOpenFilters,
                onOpenFavorites: onOpenFavorites,
                filterActive: filterActive,
                onZoomIn: onZoomIn,
                onZoomOut: onZoomOut,
                onRecenter: onRecenter,
              ),
            ),
            if (designate != null) ...<Widget>[
              // Repli 6 : la mise en page ne peint, ne touche ni n'annonce la
              // bande retirée, mais elle garde son nœud de focus ; le rapport
              // (une trame après) l'en exclut.
              MapLayoutChild(
                slot: MapLayoutSlot.band,
                child: ValueListenableBuilder<MapLayoutReport?>(
                  valueListenable: layoutReport,
                  builder:
                      (
                        BuildContext context,
                        MapLayoutReport? report,
                        Widget? band,
                      ) => ExcludeFocus(
                        excluding: report?.allocation.bandWithdrawn ?? false,
                        child: band!,
                      ),
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(mapTraversalOrderDesignate),
                    child: DesignationBand(onDesignate: designate),
                  ),
                ),
              ),
              const MapLayoutChild(
                slot: MapLayoutSlot.reticle,
                child: MapCenterReticle(),
              ),
            ],
            if (panels.isNotEmpty)
              MapLayoutChild(
                slot: MapLayoutSlot.sheet,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(mapTraversalOrderSheet),
                  child: MapSheetArea(
                    key: mapSheetAreaKey,
                    sidePanel: sidePanel,
                    // Le fond se prolonge sous les marges système qui bordent
                    // la fiche : le bas (et les côtés) pour la fiche du bas ; le
                    // haut, le bas et la droite pour le panneau.
                    extend: sidePanel
                        ? EdgeInsets.fromLTRB(
                            0,
                            safeInsets.top,
                            safeInsets.right,
                            safeInsets.bottom,
                          )
                        : EdgeInsets.fromLTRB(
                            safeInsets.left,
                            0,
                            safeInsets.right,
                            safeInsets.bottom,
                          ),
                    scrollController: sheetScrollController,
                    panels: panels,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  ];
}

// `buildMapScreen` (bandeau `W3` + menu `W3b`) est retirée par `W3c` : `_MapViewState.build` rend directement `mapAndOverlays`.

/// Marge d'une surcouche au bord de la carte visible, et écart entre deux
/// groupes de pièces, en pixels logiques.
const double _overlayPadding = 8;

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
  ///
  /// [floodLayer], [onFloodSectionTap] et [floodSheet] (`M5` de T4) vont
  /// ensemble, tous trois : une lecture Crues sans fiche ne s'ouvrirait
  /// jamais, une fiche sans lecture n'aurait aucun tronçon à montrer.
  const MapView({
    required this.viewModel,
    this.onStationTap,
    this.onOndeTap,
    this.stationSheet,
    this.ondeSheet,
    this.onCloseSheets,
    this.onPointDesignated,
    this.sheetScrollController,
    this.onOpenFavorites,
    this.floodLayer,
    this.onFloodSectionTap,
    this.floodSheet,
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
       ),
       assert(
         (floodLayer == null) == (onFloodSectionTap == null) &&
             (onFloodSectionTap == null) == (floodSheet == null),
         'floodLayer, onFloodSectionTap et floodSheet vont ensemble : une '
         "lecture sans fiche ne s'ouvre jamais, une fiche sans lecture "
         "n'affiche rien",
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
  /// Les deux panneaux ne sont jamais ouverts en même temps : `main.dart`
  /// ferme l'un avant d'ouvrir l'autre. Depuis T3 une fiche s'ouvre aussi
  /// depuis l'écran « Favoris » : une fiche ONDE peut donc être ouverte alors
  /// que l'échelle affichée est le débit, et inversement.
  final Widget? ondeSheet;

  /// Appelé par `Échap` (`K2`) pour fermer la fiche ouverte — station OU
  /// ONDE, jamais les deux à distinguer ici : `main.dart`, la racine de
  /// composition, ferme les deux ViewModels de fiche d'un coup
  /// (`stationSheetViewModel.close`, `ondeSheetViewModel.close`), au même
  /// titre qu'elle garantit déjà leur exclusivité mutuelle au tap
  /// (`onStationTap`/`onOndeTap` ci-dessus). Fermer une fiche déjà fermée
  /// est sans effet observable — `StationSheetViewModel.close`/
  /// `OndeSheetViewModel.close` réémettent le même état `Fermee`. `null` :
  /// aucune fiche n'est branchée, `Échap` n'a alors rien à fermer.
  final VoidCallback? onCloseSheets;

  /// Appelé avec le lieu désigné (`E1` de T2, conception § 2) : un appui
  /// long ou un clic droit sur la carte — le point que la caméra donne pour
  /// la position du geste, **hors mode comme en mode** —, ou le bouton
  /// « Restrictions au centre de la carte » — le centre de la caméra, qui
  /// n'existe que dans le mode de désignation (`E5`,
  /// `MapViewModel.designationMode`, allumé par le choix « Restrictions » du
  /// sélecteur). Injecté par `main.dart`, qui le branche sur la tranche
  /// restrictions : la carte ne la nomme pas (`feature-vers-feature`).
  /// `null` : les gestes sont sans effet, et ni la puce « Restrictions » ni
  /// le bouton n'existent.
  final void Function(GeoPoint point)? onPointDesignated;

  /// Le contrôleur du défilement de la zone des fiches (`K4` de T3), créé et
  /// possédé par `main.dart` : la racine de composition est la seule à savoir
  /// quand une fiche s'ouvre, et y remet la position à zéro. Cette vue le
  /// passe, elle ne le dispose pas. `null` : aucune remise à zéro, le
  /// défilement garde son contrôleur interne.
  final ScrollController? sheetScrollController;

  /// Appelé par un tap, Entrée ou Espace sur le bouton « Favoris » du groupe
  /// des boutons d'entrée (`S10` de T3, arbitrage 8 du cadrage) : ouvre
  /// l'écran des favoris. Injecté par `main.dart` : la carte ne connaît ni
  /// l'écran ni sa tranche (règle `feature-vers-feature`). `null` : le bouton
  /// est absent.
  final VoidCallback? onOpenFavorites;

  /// Le second ViewModel de l'écran (`L2` de T4, arbitrage 7, `ADR-014`
  /// amendé) : l'état de la lecture Crues, qui a son propre cycle de
  /// chargement. Construit et disposé par `main.dart`, comme [viewModel].
  /// C'est cette vue qui le prévient — puce « Vigilance crues », relâchement
  /// de geste sur cette lecture, « Réessayer » ; aucun ViewModel n'importe
  /// l'autre. `null` : la lecture Crues n'est pas branchée, la puce ne fait
  /// que changer d'échelle.
  final FloodLayerViewModel? floodLayer;

  /// Appelé avec le tronçon touché (trait ou étiquette) et la date de la
  /// carte de vigilance dont il vient. Injecté par `main.dart`, qui le
  /// branche sur la fiche tronçon : la carte ne nomme pas cette tranche
  /// (règle `feature-vers-feature`).
  final void Function(FloodSection section, DateTime informationDate)?
  onFloodSectionTap;

  /// Le panneau de la fiche tronçon, déjà composé par `main.dart`, affiché
  /// dans la zone des fiches, sous [stationSheet] et [ondeSheet].
  final Widget? floodSheet;

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
  ///
  /// `interactionOptions.keyboardOptions` (`K2`, 2026-09-23) : `flutter_map`
  /// pose, PAR DÉFAUT, son propre `Focus(debugLabel: 'FlutterMap',
  /// autofocus: true)` et son propre déplacement au clavier — lu dans le
  /// paquet installé, `lib/src/gestures/map_interactive_viewer.dart` l. 338
  /// et `lib/src/map/options/keyboard.dart`. Trois choses constatées par
  /// test avant d'être comprises, dans cet ordre : (1) son `autofocus`
  /// volait le focus au premier affichage, avant tout `Tab` ; (2) sans lui,
  /// `flutter_map` aurait déplacé la caméra à la fois par ses propres
  /// flèches ET par [PanIntent] — deux chemins pour un seul geste ; (3)
  /// même désactivé, ce `Focus` interne reste un `FocusNode` DISTINCT,
  /// focalisable — un second arrêt de tabulation pour « carte », que
  /// l'ordre déclaré n'en compte qu'UN. `focusNode: _mapFocusNode` fait
  /// donc réutiliser CE nœud par `flutter_map` lui-même : un seul
  /// `FocusNode` pour « carte », que ce fichier n'enveloppe plus d'un
  /// second `Focus` (voir le commentaire sur [_mapFocusNode] et la
  /// disparition de `KeyboardFocusRing` autour de `FlutterMap`).
  ///
  /// `cameraConstraint: containLatitude()` (arbitrage du commanditaire du
  /// 2026-10-06) : par défaut `flutter_map` 8.3.2 n'applique AUCUNE contrainte
  /// (`MapOptions.cameraConstraint` vaut `unconstrained()`), et la flèche Haut
  /// ou Bas ([_handlePan]) poussait sans borne le centre hors du monde : le
  /// point sous le réticule n'était plus celui que le bouton désignait, et la
  /// carte restait figée autant de flèches en sens inverse.
  /// `ContainCameraLatitude.constrain` (`camera_constraint.dart`, paquet
  /// installé) ramène le centre pour que les BORDS haut et bas de la caméra —
  /// sa boîte englobante quand la carte est pivotée — restent dans le monde,
  /// que la projection plafonne à 85,0511° (`crs.dart`). `moveRaw` et
  /// `rotateRaw` l'appliquent à tout déplacement, zoom et rotation. Deux
  /// limites, verrouillées par des tests de caractérisation :
  /// - le redimensionnement ne passe PAS par lui : `flutter_map` change la
  ///   taille de la caméra sans rejouer la contrainte, et agrandir la fenêtre
  ///   depuis la butée laisserait du vide au-delà du monde jusqu'au prochain
  ///   déplacement. Ce fichier la rejoue donc lui-même, une fois la taille
  ///   changée ([_reapplyCameraConstraint], sur `MapEventNonRotatedSizeChange`) ;
  /// - il REFUSE le déplacement quand le monde est plus bas que la fenêtre :
  ///   au zoom minimal 4 le monde fait 4 096 px de haut, plus que toute
  ///   fenêtre éprouvée (1 032 px pour la plus haute). Le recalage est alors
  ///   refusé de même, sans exception : la caméra reste telle quelle.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: const LatLng(
      initialMapCenterLatitude,
      initialMapCenterLongitude,
    ),
    initialZoom: initialMapZoom,
    minZoom: minimumMapZoom,
    maxZoom: maximumMapZoom,
    cameraConstraint: const CameraConstraint.containLatitude(),
    onMapEvent: _handleMapEvent,
    onLongPress: _handleLongPress,
    onSecondaryTap: _handleSecondaryTap,
    interactionOptions: InteractionOptions(
      keyboardOptions: KeyboardOptions(
        enableArrowKeysPanning: false,
        enableWASDPanning: false,
        enableQERotating: false,
        enableRFZooming: false,
        performLeapTriggerDuration: null,
        autofocus: false,
        focusNode: _mapFocusNode,
      ),
    ),
  );

  /// Le point désigné le plus récent (`E1` de T2, conception § 2, Q-2b (a)) :
  /// tenu ICI, par la vue carte, jusqu'à la désignation suivante — la
  /// carte connaît le point au moment même du geste, et l'état de l'écran
  /// des restrictions n'en porte plus après sa fermeture. `null` avant toute
  /// désignation.
  GeoPoint? _designatedPoint;

  /// Câblé à `MapOptions.onLongPress` — une référence de méthode, jamais une
  /// fermeture (égalité de `MapOptions`, `NFR-01`).
  void _handleLongPress(TapPosition position, LatLng point) =>
      _designate(point);

  /// Câblé à `MapOptions.onSecondaryTap` (clic droit) — même raison.
  void _handleSecondaryTap(TapPosition position, LatLng point) =>
      _designate(point);

  /// Bouton « Restrictions au centre de la carte » : le centre de la caméra.
  void _handleDesignateCenter() => _designate(_mapController.camera.center);

  /// Sans rappel, aucune désignation : ni appel, ni épingle.
  void _designate(LatLng point) {
    final void Function(GeoPoint point)? callback = widget.onPointDesignated;
    if (callback == null) {
      return;
    }

    // `GeoPoint` valide [-90, 90] et lève sinon. La caméra est contrainte au
    // monde (`_mapOptions.cameraConstraint`) : son centre reste dans la
    // projection, et un point d'écran est borné par elle. Aucune borne ici :
    // elle ferait d'une latitude invalide (`NaN` compris) un pôle désigné.
    final GeoPoint designated = GeoPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    setState(() => _designatedPoint = designated);
    callback(designated);
  }

  /// Ce que [build] écoute : [MapView.viewModel] et, s'il est branché,
  /// [MapView.floodLayer] (`M5` de T4). Construit en [initState] et refait en
  /// [didUpdateWidget] si l'un des deux change — jamais à chaque [build], où
  /// un `Listenable.merge` neuf ferait réabonner le `ListenableBuilder`.
  late Listenable _listenable;

  Listenable _mergedListenable() {
    final FloodLayerViewModel? flood = widget.floodLayer;
    return Listenable.merge(<Listenable>[widget.viewModel, ?flood]);
  }

  // Le calque des traits de la lecture Crues, en INSTANCE STABLE (Review
  // Focus 1, `M5` de T4). `PolylineLayer` vide ses caches de projection et
  // de simplification dans CHAQUE `didUpdateWidget`
  // (`lib/src/layer/shared/layer_projection_simplification/state.dart`,
  // l. 52-58, du paquet `flutter_map` 8.3.2 installé) ; or la carte se
  // reconstruit à chaque notification d'un des deux ViewModels (geste,
  // préchargement, fiche). Le widget rendu par `buildFloodSectionsLayer` est
  // donc gardé avec la carte de vigilance dont il vient et réemployé TEL QUEL
  // — même objet, que `Element.updateChild` court-circuite sans appeler
  // `didUpdateWidget` — tant que la carte est la même (`identical`) : les
  // points ne sont projetés qu'une fois par carte de vigilance (`NFR-01`).

  /// La carte de vigilance dont vient [_floodLayerWidget].
  FloodVigilanceMap? _floodLayerMap;

  /// Le calque rendu pour [_floodLayerMap], réemployé tel quel.
  Widget? _floodLayerWidget;

  /// Le notifieur de toucher du calque, un champ de l'état, disposé avec lui :
  /// le même d'une carte de vigilance à l'autre.
  final LayerHitNotifier<FloodSectionCode> _floodHitNotifier =
      ValueNotifier<LayerHitResult<FloodSectionCode>?>(null);

  /// Le calque de [map], depuis le cache s'il vient de la même carte.
  /// `onTap` reçoit une MÉTHODE de l'état ([_handleFloodSectionTap]), jamais
  /// une fermeture qui capturerait un `widget` périmé.
  Widget _floodLayerFor(FloodVigilanceMap map) {
    final Widget? cached = _floodLayerWidget;
    if (cached != null && identical(map, _floodLayerMap)) {
      return cached;
    }
    final Widget layer = buildFloodSectionsLayer(
      map: map,
      hitNotifier: _floodHitNotifier,
      onTap: _handleFloodSectionTap,
    );
    _floodLayerMap = map;
    _floodLayerWidget = layer;
    return layer;
  }

  @override
  void initState() {
    super.initState();
    _listenable = _mergedListenable();
    unawaited(widget.viewModel.start(zoom: initialMapZoom));
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel) ||
        !identical(oldWidget.floodLayer, widget.floodLayer)) {
      _listenable = _mergedListenable();
    }
  }

  /// Puce d'échelle (`M5` de T4, cadrage § 7.1) : change l'échelle, puis, sur
  /// la lecture Crues, prévient [MapView.floodLayer] — activation (premier
  /// chargement, ou relecture d'une carte déjà lue), puis l'emprise de la
  /// caméra. Pendant un chargement, ni l'un ni l'autre ne relance rien
  /// (Review Focus 2).
  void _handleScaleSelected(MapScaleKind kind) {
    widget.viewModel.selectScale(kind);
    final FloodLayerViewModel? flood = widget.floodLayer;
    switch (kind) {
      case MapScaleKind.crues:
        if (flood == null) {
          return;
        }
        unawaited(flood.activate());
        unawaited(
          flood.onViewportChanged(
            _boundsFromLatLngBounds(_mapController.camera.visibleBounds),
            individualLevel: widget.viewModel.level == null,
          ),
        );
      case MapScaleKind.debit:
      case MapScaleKind.ecoulement:
        return;
    }
  }

  /// Un geste terminé sur [bounds] : sur la seule lecture Crues, la vue
  /// prévient [MapView.floodLayer] après [MapViewModel.onGestureEnded] — le
  /// niveau individuel est lu sur [MapViewModel.level], que ce dernier vient
  /// de poser avant tout `await`. Sur les deux autres échelles, rien : aucun
  /// appel à la source de vigilance (critère 16).
  void _signalFloodViewport(Bounds bounds) {
    final FloodLayerViewModel? flood = widget.floodLayer;
    if (flood == null) {
      return;
    }
    switch (widget.viewModel.scale) {
      case MapScaleKind.crues:
        unawaited(
          flood.onViewportChanged(
            bounds,
            individualLevel: widget.viewModel.level == null,
          ),
        );
      case MapScaleKind.debit:
      case MapScaleKind.ecoulement:
        return;
    }
  }

  /// Toucher d'un trait ou d'une étiquette (clavier compris) : le tronçon de
  /// [code] sur la carte lue, et la date de cette carte.
  void _handleFloodSectionTap(FloodSectionCode code) {
    final FloodLayerViewModel? flood = widget.floodLayer;
    if (flood == null) {
      return;
    }
    final FloodSection? section = flood.sectionByCode(code);
    switch (flood.state) {
      case LectureCruesPrete(:final FloodVigilanceMap map) when section != null:
        widget.onFloodSectionTap?.call(section, map.informationDate);
      case LectureCruesPrete():
      case LectureCruesNonDemandee():
      case LectureCruesEnCours():
      case LectureCruesEnEchec():
        return;
    }
  }

  /// « Réessayer » des avis d'échec de la lecture Crues : le seul geste qui
  /// relance après un échec (arbitrage 10).
  void _handleRetryFlood() {
    final FloodLayerViewModel? flood = widget.floodLayer;
    if (flood != null) {
      unawaited(flood.retry());
    }
  }

  /// Câblé à `MapOptions.onMapEvent` : ne signale un geste terminé que pour
  /// les événements de fin de geste ([shouldRefreshOn]), jamais à chaque
  /// frame d'un glisser en cours. La vue ne fait plus que traduire
  /// l'événement `flutter_map` en emprise de domaine et le signaler au
  /// ViewModel ([MapViewModel.onGestureEnded], `H2`) : c'est lui qui décide
  /// de charger puis, le cas échéant, de précharger — l'enchaînement vivait
  /// ici, dans `_loadThenPreload`, et n'était couvert par aucun test.
  ///
  /// Seule exception : un changement de taille de la carte
  /// (`MapEventNonRotatedSizeChange`) rejoue la contrainte de caméra
  /// ([_reapplyCameraConstraint]) — il ne recharge rien lui-même, seul le
  /// recalage éventuel qui en découle passe par [_afterCameraMove]. Sans
  /// recalage, la lecture Crues est quand même prévenue de l'emprise à la
  /// nouvelle taille ([_signalFloodViewport], qui ne fait rien sur les deux
  /// autres échelles) : ses étiquettes et son avis « secteur sans tronçon »
  /// restaient ceux de l'ancienne emprise (relecture d'ensemble de T4).
  void _handleMapEvent(MapEvent event) {
    if (event is MapEventNonRotatedSizeChange) {
      if (!_reapplyCameraConstraint()) {
        _signalFloodViewport(
          _boundsFromLatLngBounds(_mapController.camera.visibleBounds),
        );
      }
      return;
    }

    if (!shouldRefreshOn(event)) {
      return;
    }

    final Bounds bounds = _boundsFromLatLngBounds(event.camera.visibleBounds);
    unawaited(widget.viewModel.onGestureEnded(bounds, zoom: event.camera.zoom));
    _signalFloodViewport(bounds);
  }

  /// Rejoue la contrainte de caméra après un changement de taille de la
  /// carte : `flutter_map` 8.3.2 ne l'applique qu'aux déplacements
  /// (`moveRaw`, `rotateRaw`) — `setNonRotatedSizeWithoutEmittingEvent`
  /// (`map_controller_impl.dart`) change la taille sans la rejouer, et
  /// agrandir la fenêtre depuis la butée nord ou sud laissait du vide au-delà
  /// du monde, où un appui long désignait une latitude hors de la projection.
  ///
  /// Appelée par [_handleMapEvent] sur `MapEventNonRotatedSizeChange`, que
  /// `FlutterMap` émet dans un `addPostFrameCallback` (`map/widget.dart`,
  /// `_updateAndEmitSizeIfConstraintsChanged`) : jamais pendant un `build` ni
  /// une mise en page, donc sans risque pour l'appel au contrôleur. Un
  /// déplacement vers le centre et le zoom COURANTS suffit : `moveRaw` rejoue
  /// `cameraConstraint.constrain` sur la caméra à sa nouvelle taille, et
  /// - la caméra est déjà dans le monde (la France est loin des pôles : la
  ///   quasi-totalité des cas) : `moveRaw` rend `false` sans rien émettre ni
  ///   changer — aucun rechargement (`NFR-01`), [_afterCameraMove] ne fait rien ;
  /// - la contrainte ramène le centre : `true`, et [_afterCameraMove] recharge
  ///   l'emprise résultante comme après tout déplacement de caméra ;
  /// - le monde est plus bas que la fenêtre (au zoom 4, plus de 4 096 px) :
  ///   `constrain` rend `null`, `moveRaw` rend `false` — le recalage est
  ///   refusé, sans exception, la caméra reste telle quelle.
  ///
  /// Le `MapEventMove` que ce déplacement émet à son tour repasse par
  /// [_handleMapEvent], qui l'ignore — ce n'est pas un changement de taille,
  /// et [shouldRefreshOn] répond `false` : pas de boucle.
  ///
  /// Rend `true` si la caméra a été recalée — [_afterCameraMove] a alors
  /// déjà signalé l'emprise résultante.
  bool _reapplyCameraConstraint() {
    final MapCamera camera = _mapController.camera;
    final bool moved = _mapController.move(camera.center, camera.zoom);
    _afterCameraMove(moved);
    return moved;
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

  /// Bouton « Filtres » (`F10b` de T3) : ouvre la feuille sur l'échelle
  /// affichée et le filtre appliqué, avec les départements du référentiel —
  /// `null` s'ils n'ont pas pu être lus, ce que la feuille écrit elle-même.
  /// « Appliquer » et « Effacer » passent par `MapViewModel.applyFilter` ;
  /// fermer autrement n'appelle rien. La vue ne décide de rien : elle
  /// branche.
  ///
  /// La lecture des départements est attendue : la vue a pu quitter l'arbre
  /// entre-temps, d'où le contrôle de `mounted` avant d'ouvrir.
  ///
  /// Un appui reçu pendant qu'une feuille s'ouvre ou est ouverte
  /// ([_filterSheetPending]) est ignoré : pendant l'attente rien ne barre
  /// encore le bouton, et un second appui ouvrait une seconde feuille sur la
  /// première — fermée après elle, ouverte sur le filtre d'avant, elle
  /// écrasait le filtre appliqué.
  Future<void> _handleOpenFilters() async {
    if (_filterSheetPending) {
      return;
    }
    _filterSheetPending = true;
    try {
      final List<AdministrativeArea>? departements = await widget.viewModel
          .departements();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => MapFilterSheet(
          scale: widget.viewModel.scale,
          initialFilter: widget.viewModel.filter,
          departements: departements,
          onApply: widget.viewModel.applyFilter,
        ),
      );
    } finally {
      _filterSheetPending = false;
    }
  }

  /// Vrai du premier appui sur « Filtres » à la fermeture de la feuille.
  bool _filterSheetPending = false;

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
    final Bounds bounds = _boundsFromLatLngBounds(camera.visibleBounds);
    unawaited(widget.viewModel.onGestureEnded(bounds, zoom: camera.zoom));
    _signalFloodViewport(bounds);
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

  /// Le nœud de focus DE SECOURS de « carte », troisième arrêt de l'ordre
  /// de tabulation déclaré (`mapTraversalOrderCarte`, `K2`) — atteint par
  /// Tab UNIQUEMENT quand rien n'est dessiné (`skipTraversal`, [build]) :
  /// chaque marqueur ou pastille réellement dessiné(e) porte, LUI, son
  /// PROPRE `FocusNode` ([KeyboardFocusRing], dans son propre
  /// `FocusTraversalGroup` — voir [build] et [_carteFocusOrder]). Ce nœud-ci
  /// garde `MapView` interactive au clavier même quand aucun marqueur n'est
  /// encore chargé (`04-ui.md § 3`, « chips → contrôles de zoom → carte →
  /// lien »).
  ///
  /// Passé à `_mapOptions.interactionOptions.keyboardOptions.focusNode` :
  /// `flutter_map` construit son PROPRE `Focus` interne (paquet installé,
  /// `map_interactive_viewer.dart`), et lui donner ce nœud ÉVITE d'en
  /// ajouter un second — voir le commentaire de [_mapOptions]. C'est aussi
  /// pourquoi ce fichier ne l'enveloppe plus d'un `KeyboardFocusRing` : le
  /// contour de focus visible de « carte » vient d'un simple
  /// `AnimatedBuilder` sur ce même nœud (un `FocusNode` est déjà un
  /// `Listenable`), dans [build].
  final FocusNode _mapFocusNode = FocusNode(debugLabel: 'carte');

  /// Le rapport de la dernière mise en page des surcouches (`D2` d'Ergonomie,
  /// [MapLayout]) : la carte visible, le réticule, la répartition. Tenu ici,
  /// disposé avec l'état ; `D3` et `D4` le lisent pour désigner, zoomer et
  /// cadrer dans la carte visible.
  final ValueNotifier<MapLayoutReport?> _layoutReport =
      ValueNotifier<MapLayoutReport?>(null);

  /// Bouton `+`/`=`/`−` au clavier ([ZoomIntent], `K2`) : réutilise
  /// EXACTEMENT [_handleZoomIn]/[_handleZoomOut] — aucun enchaînement
  /// recopié, la souris et le clavier convergent vers le même chemin
  /// ([_afterCameraMove]).
  void _handleZoomIntent(ZoomIntent intent) {
    if (intent.delta > 0) {
      _handleZoomIn();
    } else {
      _handleZoomOut();
    }
  }

  /// Les quatre flèches ([PanIntent], `K2`) : déplace le CENTRE de la
  /// caméra d'une fraction ([keyboardPanFraction]) de l'emprise visible,
  /// dans [PanIntent.direction] — jamais un nombre de pixels, jamais de
  /// géométrie recalculée hors de cette méthode. Même chemin que tout autre
  /// déplacement de caméra : [_afterCameraMove], avec l'emprise et le zoom
  /// **résultants**.
  void _handlePan(AxisDirection direction) {
    final MapCamera camera = _mapController.camera;
    final LatLngBounds bounds = camera.visibleBounds;
    final double latitudeStep =
        (bounds.north - bounds.south) * keyboardPanFraction;
    final double longitudeStep =
        (bounds.east - bounds.west) * keyboardPanFraction;

    // `switch` exhaustif sur `AxisDirection` (quatre valeurs) : une
    // direction ajoutée sans branche ici ne compile pas (`BR-011`, même
    // discipline que pour `ClusterZoomTarget`).
    final LatLng target = switch (direction) {
      AxisDirection.up => LatLng(
        camera.center.latitude + latitudeStep,
        camera.center.longitude,
      ),
      AxisDirection.down => LatLng(
        camera.center.latitude - latitudeStep,
        camera.center.longitude,
      ),
      AxisDirection.left => LatLng(
        camera.center.latitude,
        camera.center.longitude - longitudeStep,
      ),
      AxisDirection.right => LatLng(
        camera.center.latitude,
        camera.center.longitude + longitudeStep,
      ),
    };

    _afterCameraMove(_mapController.move(target, camera.zoom));
  }

  @override
  void dispose() {
    _mapController.dispose();
    _mapFocusNode.dispose();
    _floodHitNotifier.dispose();
    _layoutReport.dispose();
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
    //
    // Depuis `M5` de T4, il écoute aussi [MapView.floodLayer] ([_listenable]) :
    // l'état de la lecture Crues (avis, traits, étiquettes, date de la
    // légende) a son propre cycle de chargement.
    return Scaffold(
      body: ListenableBuilder(
        listenable: _listenable,
        builder: (BuildContext context, Widget? child) {
          final FloodLayerViewModel? flood = widget.floodLayer;
          // La carte de vigilance lue, sur la seule lecture Crues à l'état
          // `Prete` : c'est d'elle que viennent les traits et la date de la
          // légende.
          final FloodVigilanceMap? floodMap = switch (widget.viewModel.scale) {
            MapScaleKind.crues => switch (flood?.state) {
              LectureCruesPrete(:final FloodVigilanceMap map) => map,
              LectureCruesNonDemandee() => null,
              LectureCruesEnCours() => null,
              LectureCruesEnEchec() => null,
              null => null,
            },
            MapScaleKind.debit => null,
            MapScaleKind.ecoulement => null,
          };
          // Arbitrage du commanditaire du 2026-09-23 (`K2`) : « carte »
          // devient un GROUPE de tabulation — Tab y parcourt les pastilles
          // OU les marqueurs individuels (plus les individuels non
          // rattachés sous le zoom 9), dans l'ordre DÉTERMINISTE que
          // `MapViewModel` décide (`orderedClusters`/
          // `orderedIndividualStations`/`orderedIndividualOndeObservations`
          // — distance croissante au centre de l'emprise, code croissant en
          // cas d'égalité, même règle que le préchargement). Cette vue ne
          // calcule aucune géométrie : elle affiche l'ordre reçu, et
          // `MarkerLayer` en hérite pour son propre rendu — c'est aussi cet
          // ordre que Tab suit, par un `NumericFocusOrder` ENTIER posé
          // explicitement sur chaque élément ([_carteFocusOrder]), PAS par
          // la règle de repli de `OrderedTraversalPolicy`
          // (`ReadingOrderTraversalPolicy`, qui trie par POSITION À
          // L'ÉCRAN — relecture du commanditaire du 2026-09-23, 🔴 1 :
          // c'est elle qui départageait, à tort, deux éléments de même
          // ordre par leur position géographique plutôt que par la liste
          // reçue).
          //
          // ⚠️ Un seul `switch` sur [MapScaleKind] décide QUELLE liste
          // individuelle compte (`BR-008` : une seule famille de marqueurs à
          // la fois) — le même que celui de [buildMapLayers], jamais
          // recopié à la légère : les deux DOIVENT s'accorder sur ce qui
          // est dessiné, sous peine d'un nœud de focus qui pointerait sur
          // un marqueur absent de l'écran.
          final List<MapAreaCluster> clusters =
              widget.viewModel.orderedClusters;
          final List<StationPoint> orderedStations =
              widget.viewModel.orderedIndividualStations;
          final List<OndeObservation> orderedOnde =
              widget.viewModel.orderedIndividualOndeObservations;
          final bool carteADuContenuFocalisable =
              switch (widget.viewModel.scale) {
                MapScaleKind.debit =>
                  clusters.isNotEmpty || orderedStations.isNotEmpty,
                MapScaleKind.ecoulement =>
                  clusters.isNotEmpty || orderedOnde.isNotEmpty,
                // Les étiquettes des tronçons (`M5` de T4), seules
                // focalisables sur cette lecture.
                MapScaleKind.crues => flood?.labels.isNotEmpty ?? false,
              };
          // NFR-01 : cette bascule ne crée AUCUN `FocusNode` supplémentaire
          // — elle règle un champ mutable du nœud interne de `flutter_map`
          // (voir le commentaire de `_mapOptions`). Les `FocusNode` des
          // marqueurs, eux, sont créés par [KeyboardFocusRing] UNIQUEMENT
          // pour ce que [buildMapLayers] dessine réellement (l'emprise
          // courante, jamais l'asset entier de 4 150 stations) — voir
          // `_stationMarkers`/`_ondeMarkers`/`_areaClusterMarkers`.
          _mapFocusNode.skipTraversal = carteADuContenuFocalisable;

          // `Shortcuts`/`Actions`/`FocusTraversalGroup` (`K2`) : les
          // raccourcis et l'ordre de tabulation ne couvrent QUE cet écran —
          // un `TextField` posé À CÔTÉ de `MapView` (hors de ce sous-arbre,
          // comme le harnais de test de `map_keyboard_test.dart`) ne les
          // reçoit jamais, sans code de garde supplémentaire : l'événement
          // clavier ne remonte que la chaîne d'ancêtres du nœud focalisé, et
          // ce `Shortcuts` n'en fait pas partie.
          return Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              ...mapShortcuts(),
              const SingleActivator(LogicalKeyboardKey.escape):
                  const _CloseSheetsIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ZoomIntent: CallbackAction<ZoomIntent>(
                  onInvoke: (ZoomIntent intent) {
                    _handleZoomIntent(intent);
                    return null;
                  },
                ),
                PanIntent: CallbackAction<PanIntent>(
                  onInvoke: (PanIntent intent) {
                    _handlePan(intent.direction);
                    return null;
                  },
                ),
                _CloseSheetsIntent: CallbackAction<_CloseSheetsIntent>(
                  onInvoke: (_CloseSheetsIntent intent) {
                    widget.onCloseSheets?.call();
                    return null;
                  },
                ),
              },
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  children: <Widget>[
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(mapTraversalOrderCarte),
                      // `_mapFocusNode` reste le `FocusNode` interne de
                      // `flutter_map` (voir le commentaire de
                      // `_mapOptions.interactionOptions.keyboardOptions`) —
                      // mais désormais SAUTÉ par Tab dès qu'un marqueur ou
                      // une pastille est dessiné(e) ([skipTraversal],
                      // calculé ci-dessus) : Tab entre alors DIRECTEMENT sur
                      // le premier élément du groupe, sans arrêt
                      // intermédiaire vide. Sans contenu (emprise sans rien
                      // à dessiner), ce nœud reste le seul arrêt de
                      // « carte » — c'est ce qui garde `MapView` interactive
                      // au clavier même quand rien n'y est encore chargé.
                      //
                      // `FocusTraversalGroup(policy: OrderedTraversalPolicy())`
                      // (relecture du commanditaire du 2026-09-23, 🔴 1) :
                      // `FlutterMap` porte sa PROPRE échelle d'ordre, séparée
                      // de celle du groupe parent — les `NumericFocusOrder`
                      // ENTIERS posés par [_carteFocusOrder] sur chaque
                      // marqueur (`0`, `1`, `2`, …) ne peuvent alors jamais
                      // chevaucher [mapTraversalOrderSheet] (3,5) ni
                      // [mapTraversalOrderWarningLink] (4), quel que soit le
                      // nombre de marqueurs dessinés — contrairement à
                      // l'ancien partage d'une seule échelle avec un pas de
                      // 0,001, dépassé par une zone dense de plus de 500
                      // marqueurs (jusqu'à 1 487 constatés à 1920×1080 au
                      // zoom individuel).
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: AnimatedBuilder(
                          animation: _mapFocusNode,
                          builder: (BuildContext context, Widget? child) =>
                              DecoratedBox(
                                // `position: DecorationPosition.foreground`
                                // (relecture du commanditaire du
                                // 2026-09-23, 🔴 2) : par défaut,
                                // `DecoratedBox` peint sa décoration EN
                                // ARRIÈRE-PLAN de [child] — ici recouverte
                                // par les tuiles IGN, opaques, qui rendent
                                // le contour invisible. En premier plan, il
                                // se peint PAR-DESSUS.
                                position: DecorationPosition.foreground,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    // `hasPrimaryFocus`, pas `hasFocus`
                                    // (relecture du commanditaire du
                                    // 2026-09-23, 🟢 6) : `hasFocus` reste
                                    // vrai tant qu'un DESCENDANT porte le
                                    // focus — un marqueur focalisé aurait
                                    // ainsi allumé CE contour en même temps
                                    // que le sien. `hasPrimaryFocus` ne
                                    // s'allume que si ce nœud précis, et
                                    // aucun autre, porte le focus.
                                    color: _mapFocusNode.hasPrimaryFocus
                                        ? focusRingColor
                                        : Colors.transparent,
                                    width: focusRingWidth,
                                  ),
                                ),
                                child: child,
                              ),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: _mapOptions,
                            children: buildMapLayers(
                              scale: widget.viewModel.scale,
                              // Marqueurs individuels de l'emprise
                              // courante — vide au niveau régroupé — dans
                              // l'ordre déterministe calculé ci-dessus.
                              stations: orderedStations,
                              ondeObservations: _byCode(orderedOnde),
                              ageOf: widget.viewModel.ondeAgeOf,
                              onStationTap: widget.onStationTap,
                              onOndeTap: widget.onOndeTap,
                              stateOf: widget.viewModel.stateOf,
                              clusters: clusters,
                              onClusterSelect: _handleClusterSelect,
                              designatedPoint: _designatedPoint,
                              // Le calque en instance stable (voir
                              // [_floodLayerFor]) ; les étiquettes dans
                              // l'ordre de tabulation du domaine.
                              floodLayer: floodMap == null
                                  ? null
                                  : _floodLayerFor(floodMap),
                              floodLabels:
                                  flood?.labels ?? const <FloodLabel>[],
                              onFloodSectionTap: flood == null
                                  ? null
                                  : _handleFloodSectionTap,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...buildMapOverlays(
                      scale: widget.viewModel.scale,
                      onSelect: _handleScaleSelected,
                      onWiden: _handleWiden,
                      error: widget.viewModel.error,
                      errorSource: widget.viewModel.errorSource,
                      stations: widget.viewModel.stations,
                      ondeObservations: widget.viewModel.ondeObservations,
                      ondeUnreadableRows: widget.viewModel.ondeUnreadableRows,
                      filterHidesEverything:
                          widget.viewModel.filterHidesEverything,
                      onClearFilters: widget.viewModel.clearFilter,
                      filterActive: widget.viewModel.filterActive,
                      onOpenFilters: _handleOpenFilters,
                      onZoomIn: widget.viewModel.canZoomIn
                          ? _handleZoomIn
                          : null,
                      onZoomOut: widget.viewModel.canZoomOut
                          ? _handleZoomOut
                          : null,
                      onRecenter: _handleRecenter,
                      onDesignateCenter:
                          widget.onPointDesignated != null &&
                              widget.viewModel.designationMode
                          ? _handleDesignateCenter
                          : null,
                      onToggleDesignationMode: widget.onPointDesignated == null
                          ? null
                          : widget.viewModel.toggleDesignationMode,
                      stationSheet: widget.stationSheet,
                      ondeSheet: widget.ondeSheet,
                      sheetScrollController: widget.sheetScrollController,
                      onOpenFavorites: widget.onOpenFavorites,
                      floodNotices: flood == null
                          ? const <MapNotice>[]
                          : floodNoticesFor(
                              state: flood.state,
                              anySectionInBounds: flood.anySectionInBounds,
                            ),
                      onRetryFlood: flood == null ? null : _handleRetryFlood,
                      floodInformationDate: floodMap?.informationDate,
                      floodSheet: widget.floodSheet,
                      layoutReport: _layoutReport,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
