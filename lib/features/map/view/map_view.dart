// La vue de la tranche carte (MVVM, ADR-014) : le fond IGN Géoplateforme,
// son attribution en toutes lettres — une condition d'usage de la donnée sous
// Licence Ouverte, jamais une finition (`04-ui.md` § 3) — et les stations du
// référentiel en marqueurs du viewport élargi. Les couches sont produites par
// [buildMapLayers], une fonction PURE : rendre un `FlutterMap` dans un test
// déclenche des chargements de tuiles que l'environnement de test refuse.
//
// ⚠️ Au zoom national, la France entière est visible : les 4 150 stations
// sont TOUTES dessinées — c'est le prix réel de l'approche par défaut
// (`F2c`, aucun clustering tant qu'aucune mesure ne le réhabilite), pas un
// défaut caché. La pastille ([StationMarkerDot]) est une forme décorée
// (`DecoratedBox` cercle), jamais un glyphe de police : un glyphe coûterait
// une passe de texte par marqueur, inutile pour 4 150 occurrences.
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

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
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

/// Taille d'une pastille de station, en pixels logiques. Volontairement
/// petite : ce n'est **pas** une cible tactile (`04-ui.md` § 3 exige
/// 44 × 44 pt) — le tap arrive en T1, avec un halo de zone de tap séparé du
/// rendu visuel.
const double stationMarkerSize = 12;

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
/// Ne refiltre pas [stations] à une emprise : le filtre fait foi côté dépôt
/// (`StationPointRepository`, marge `defaultViewportMargin` comprise) — le
/// dupliquer ici masquerait un bug de marge plutôt que de le révéler, et un
/// filtre à marge nulle supprimerait purement et simplement les marqueurs de
/// la marge que le dépôt vient de rapporter. [buildMapLayers] dessine
/// exactement ce que le ViewModel lui donne.
///
/// Une couche de marqueurs **vide n'est pas ajoutée** : au moins une station
/// visible est nécessaire pour que `MarkerLayer` apparaisse dans la liste.
List<Widget> buildMapLayers({required List<StationPoint> stations}) {
  final List<Widget> layers = <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];

  if (stations.isNotEmpty) {
    layers.add(
      MarkerLayer(
        markers: stations
            .map(
              (StationPoint station) => Marker(
                // ⚠️ GeoJSON range les coordonnées [longitude, latitude] ;
                // `LatLng` prend la latitude EN PREMIER. `StationPoint` a
                // déjà absorbé cet écart à l'analyse (stations_asset.dart) —
                // ici, `station.latitude`/`station.longitude` sont déjà dans
                // l'ordre attendu par `LatLng`.
                point: LatLng(station.latitude, station.longitude),
                width: stationMarkerSize,
                height: stationMarkerSize,
                child: const StationMarkerDot(),
              ),
            )
            .toList(),
      ),
    );
  }

  return layers;
}

/// Pastille de station, volontairement pauvre : une forme décorée
/// (`DecoratedBox` cercle), jamais un glyphe de police — un glyphe coûterait
/// une passe de texte par marqueur, inutile pour 4 150 occurrences.
///
/// Une seule couleur, invariable : en T0 la couleur ne porte **aucun état**
/// (`BR-007`, `BR-008`) — les trois échelles d'état (écoulement, débit,
/// sécheresse) arrivent en T1, chacune avec sa propre palette (`04-ui.md`
/// § 2). Le contour de 2 px est exigé par `04-ui.md` § 3 (halo de marqueur),
/// pour rester visible quel que soit le fond de carte.
class StationMarkerDot extends StatelessWidget {
  const StationMarkerDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.indigo,
        // Halo blanc fixe : `04-ui.md` § 3 distingue blanc sur fond sombre
        // et noir sur fond clair — cette adaptation au fond de carte arrive
        // avec les états en T1. En T0, une seule couleur de contour, comme
        // une seule couleur de remplissage.
        border: Border.fromBorderSide(
          BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

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
  const MapView({required this.viewModel, super.key});

  /// Le ViewModel de la tranche carte, construit dans `main.dart`
  /// (asset → dépôts → ViewModel → vue). La vue ne le **possède pas** :
  /// c'est la racine de composition qui le crée et qui le disposera — cette
  /// vue ne doit pas disposer un objet dont elle n'est pas propriétaire.
  final MapViewModel viewModel;

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
    unawaited(widget.viewModel.loadInitial());
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
      widget.viewModel.loadFor(
        Bounds(
          west: visible.west,
          south: visible.south,
          east: visible.east,
          north: visible.north,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          ListenableBuilder(
            listenable: widget.viewModel,
            builder: (BuildContext context, Widget? child) {
              final Object? error = widget.viewModel.error;
              return Stack(
                children: <Widget>[
                  FlutterMap(
                    options: _mapOptions,
                    children: buildMapLayers(
                      stations: widget.viewModel.stations,
                    ),
                  ),
                  if (error != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: MapErrorBanner(error: error),
                    ),
                ],
              );
            },
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: IgnAttributionBadge(),
            ),
          ),
        ],
      ),
    );
  }
}
