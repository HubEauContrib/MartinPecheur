// L'écran carte (T0-M4) : le fond IGN Géoplateforme, son attribution en
// toutes lettres — une condition d'usage de la donnée sous Licence Ouverte,
// jamais une finition (`04-ui.md` § 3) — et les stations du référentiel en
// marqueurs du viewport élargi. Les couches sont produites par
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
// Invariant d'architecture (arbitrage 2026-09-13) : l'écran n'appelle
// jamais le dépôt. Il envoie une [StationPointsWithinBoundsQuery] au [Bus]
// — isolé dans [MapStationsController], testable sans monter de widget ni
// de `FlutterMap` — et un gestionnaire, câblé dans `main.dart`, répond.
//
// État par `ValueNotifier` + `ListenableBuilder` (aucune dépendance
// ajoutée) : les stations du viewport courant ([MapStationsController]) et
// la caméra courante, mise à jour par `MapOptions.onPositionChanged`.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/map/ign_tile_template.dart';
import 'package:martinpecheur/features/map/viewport_filter.dart';

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

/// Emprise visible, en degrés décimaux WGS 84 — un enregistrement nommé, pas
/// le type de `flutter_map` (`LatLngBounds`) : [buildMapLayers] reste
/// appelable sans dépendre de la caméra ni d'aucune bibliothèque de carte,
/// et se teste avec de simples valeurs.
typedef VisibleBounds = ({
  double north,
  double south,
  double east,
  double west,
});

/// Convertit la caméra courante en [VisibleBounds]. Rend `null` en l'absence
/// de caméra — au premier rendu, avant le premier `onPositionChanged`.
VisibleBounds? _boundsOf(MapCamera? camera) {
  if (camera == null) {
    return null;
  }
  final LatLngBounds visible = camera.visibleBounds;
  return (
    north: visible.north,
    south: visible.south,
    east: visible.east,
    west: visible.west,
  );
}

/// Construit les couches de la carte, dans l'ordre où `FlutterMap` doit les
/// empiler — le fond de tuiles **premier**, les marqueurs ensuite. Fonction
/// pure, testable sans rendu ni accès réseau.
///
/// [visibleBounds] filtre [stations] à l'emprise stricte, **sans marge** —
/// la marge proportionnelle (`defaultViewportMargin`) est déjà appliquée en
/// amont, côté requête (`MapStationsController`, via
/// `StationPointsWithinBoundsQuery`) ; la réappliquer ici masquerait un bug
/// de marge côté requête plutôt que de le révéler. Ce filtre strict n'est
/// qu'un filet de sécurité pour l'affichage : il évite de dessiner
/// brièvement des stations d'un viewport précédent pendant qu'une réponse
/// plus fraîche est en vol. `null` (au premier rendu, ou pour un test qui
/// exerce [buildMapLayers] seule) laisse passer toutes les [stations] —
/// au zoom national la France entière est de toute façon visible.
///
/// [camera] n'est plus utilisé pour filtrer (ce rôle revient à
/// [visibleBounds]) ; il reste dans la signature pour ne pas la changer une
/// seconde fois et pour un futur usage (rotation, `04-ui.md`).
///
/// Une couche de marqueurs **vide n'est pas ajoutée** : au moins une station
/// visible est nécessaire pour que `MarkerLayer` apparaisse dans la liste.
List<Widget> buildMapLayers({
  required List<StationPoint> stations,
  required MapCamera? camera,
  VisibleBounds? visibleBounds,
}) {
  final List<StationPoint> visibleStations = visibleBounds == null
      ? stations
      : stationsWithinViewport(
          stations,
          north: visibleBounds.north,
          south: visibleBounds.south,
          east: visibleBounds.east,
          west: visibleBounds.west,
          margin: 0,
        );

  final List<Widget> layers = <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];

  if (visibleStations.isNotEmpty) {
    layers.add(
      MarkerLayer(
        markers: visibleStations
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

/// Isole l'envoi de [StationPointsWithinBoundsQuery] au [Bus] et l'état qui
/// en résulte — testable sans monter de widget ni de `FlutterMap`
/// (`MapScreen` ne fait que le brancher à `MapOptions.onPositionChanged`).
class MapStationsController {
  MapStationsController(this._bus);

  final Bus _bus;

  /// Les stations du viewport actuellement connu.
  final ValueNotifier<List<StationPoint>> stations =
      ValueNotifier<List<StationPoint>>(<StationPoint>[]);

  Bounds? _derniereEmpriseEnvoyee;

  /// Emprise de démarrage, avant tout geste de caméra : France
  /// métropolitaine. Documentée comme une emprise de démarrage — pas une
  /// valeur magique.
  static final Bounds startupBounds = Bounds(
    west: -5.5,
    south: 41,
    east: 10,
    north: 51.5,
  );

  /// Envoie la requête de démarrage ([startupBounds]).
  Future<void> loadInitial() => refresh(startupBounds);

  /// Envoie une [StationPointsWithinBoundsQuery] pour [bounds] et met à jour
  /// [stations], sauf si les quatre bords sont identiques à la dernière
  /// emprise envoyée — évite un aller-retour au bus à chaque trame de
  /// caméra.
  Future<void> refresh(Bounds bounds) async {
    final Bounds? derniere = _derniereEmpriseEnvoyee;
    if (derniere != null &&
        derniere.north == bounds.north &&
        derniere.south == bounds.south &&
        derniere.east == bounds.east &&
        derniere.west == bounds.west) {
      return;
    }

    _derniereEmpriseEnvoyee = bounds;
    final List<StationPoint> reponse = await _bus.send<List<StationPoint>>(
      StationPointsWithinBoundsQuery(bounds),
    );
    stations.value = reponse;
  }

  void dispose() {
    stations.dispose();
  }
}

/// Bandeau d'attribution IGN Géoplateforme, exigé par la Licence Ouverte.
/// Porte son propre fond opaque : un texte posé directement sur un fond de
/// carte quelconque ne tient aucun contraste (`04-ui.md` § 3). Sous-arbre
/// entièrement `const` — rien ici ne dépend de l'état de l'écran.
class IgnAttributionBadge extends StatelessWidget {
  const IgnAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(ignAttribution, style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// L'écran carte : fond IGN, attribution, et les marqueurs de stations dans
/// le viewport. N'appelle jamais de dépôt : il envoie ses requêtes au [Bus]
/// via [MapStationsController].
class MapScreen extends StatefulWidget {
  const MapScreen({required this.bus, super.key});

  /// Le registre de messages, câblé dans `main.dart` (dépôt → gestionnaire →
  /// registre → écran).
  final Bus bus;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapStationsController _controller = MapStationsController(
    widget.bus,
  );
  final ValueNotifier<MapCamera?> _camera = ValueNotifier<MapCamera?>(null);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadInitial());
  }

  Future<void> _handlePositionChanged(MapCamera camera, bool hasGesture) {
    _camera.value = camera;
    final LatLngBounds visible = camera.visibleBounds;
    return _controller.refresh(
      Bounds(
        west: visible.west,
        south: visible.south,
        east: visible.east,
        north: visible.north,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              _controller.stations,
              _camera,
            ]),
            builder: (BuildContext context, Widget? child) {
              return FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(
                    initialMapCenterLatitude,
                    initialMapCenterLongitude,
                  ),
                  initialZoom: initialMapZoom,
                  minZoom: minimumMapZoom,
                  maxZoom: maximumMapZoom,
                  onPositionChanged: (MapCamera camera, bool hasGesture) {
                    unawaited(_handlePositionChanged(camera, hasGesture));
                  },
                ),
                children: buildMapLayers(
                  stations: _controller.stations.value,
                  camera: _camera.value,
                  visibleBounds: _boundsOf(_camera.value),
                ),
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
