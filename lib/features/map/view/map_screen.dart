// L'écran carte (T0-M4/M5) : le fond IGN Géoplateforme, son attribution en
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
// Relecture M3/M4 (2026-09-13) — deux défauts corrigés :
// - `MapOptions` était reconstruite à chaque `build` avec des fermetures
//   inline : `MapOptions ==` (paquet flutter_map 8.3.2,
//   `lib/src/map/options/options.dart`) compare chaque callback par égalité
//   de fonction, et deux fermetures inline ne sont jamais égales même à
//   code identique. `flutter_map` remplaçait donc l'état de son contrôleur
//   à chaque frame (NFR-01). `_mapOptions` est maintenant un champ
//   `late final`, construit une seule fois, avec des tear-offs de méthodes
//   (`_handlePositionChanged`, `_handleMapEvent`) — un tear-off d'une
//   méthode d'instance reste égal à lui-même d'un accès à l'autre.
// - `onPositionChanged` envoyait une requête au bus à chaque frame d'un
//   glisser : un déplacement de dix frames faisait dix requêtes et
//   reconstruisait dix fois les 4 150 marqueurs. `onPositionChanged` ne
//   fait plus que mettre à jour [_camera] (gardé pour un futur usage —
//   rotation, `04-ui.md` — mais délibérément absent du `Listenable.merge`
//   de [build] : rien ne le lit pour le rendu, l'y inclure reconstruirait
//   la carte à chaque frame pour rien). La requête part sur
//   [_handleMapEvent], câblé à `MapOptions.onMapEvent`, uniquement pour les
//   événements de **fin** de geste — voir [shouldRefreshOn]. La marge
//   proportionnelle `defaultViewportMargin` (`viewport_filter.dart`) fait
//   le travail entre-temps : les marqueurs déjà chargés couvrent le
//   déplacement jusqu'au prochain relâcher.
//
// Une erreur du bus (bus sans gestionnaire, gestionnaire qui lève) n'est
// plus avalée : [MapStationsController.error] la porte, et l'écran affiche
// [MapErrorBanner] au lieu d'une carte muette (`BR-007`).
//
// État par `ValueNotifier` + `ListenableBuilder` (aucune dépendance
// ajoutée) : les stations du viewport courant et l'erreur éventuelle
// ([MapStationsController]), la caméra courante à part ([_camera]).

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/map/ign_tile_template.dart';

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

/// Décide si [event] doit déclencher une nouvelle requête d'emprise.
/// Fonction pure, testable sans widget ni `FlutterMap` — construite avec les
/// constructeurs de `MapEvent` du paquet, ou testée par son type runtime.
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
/// `defaultViewportMargin` (`viewport_filter.dart`) couvre déjà le
/// déplacement jusqu'au prochain relâcher — envoyer une requête à chaque
/// frame reconstruirait les 4 150 marqueurs pour rien (NFR-01).
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
/// Ne refiltre plus [stations] à une emprise : le filtre fait foi côté
/// requête (`MapStationsController`, via `StationPointsWithinBoundsQuery`,
/// marge `defaultViewportMargin` comprise) — le dupliquer ici masquerait un
/// bug de marge côté requête plutôt que de le révéler, et un filtre à marge
/// nulle ici (l'ancien comportement) supprimait purement et simplement les
/// marqueurs de la marge que la requête venait de rapporter.
/// [buildMapLayers] dessine exactement ce que le contrôleur lui donne.
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

/// Isole l'envoi de [StationPointsWithinBoundsQuery] au [Bus] et l'état qui
/// en résulte — testable sans monter de widget ni de `FlutterMap`
/// (`MapScreen` ne fait que le brancher à `MapOptions`).
class MapStationsController {
  MapStationsController(this._bus);

  final Bus _bus;

  /// Les stations du viewport actuellement connu.
  final ValueNotifier<List<StationPoint>> stations =
      ValueNotifier<List<StationPoint>>(<StationPoint>[]);

  /// La dernière erreur survenue en interrogeant le bus, ou `null` en
  /// l'absence d'erreur. L'écran l'affiche dans [MapErrorBanner] au lieu
  /// d'une carte muette (`BR-007`) : le bus n'avale aucune erreur (voir
  /// `bus.dart`), [refresh] ne doit pas non plus l'avaler en silence.
  final ValueNotifier<Object?> error = ValueNotifier<Object?>(null);

  /// Levé par [dispose] : une réponse qui arrive après que l'écran a été
  /// démonté ne doit plus toucher [stations] ni [error] — les deux
  /// `ValueNotifier` sont alors déjà disposés, et leur écrire lèverait une
  /// assertion (« A ValueNotifier was used after being disposed »).
  bool _disposed = false;

  Bounds? _lastRequestedBounds;

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
  /// emprise envoyée — évite un aller-retour au bus à chaque relâcher qui ne
  /// change rien. Une erreur du bus (aucun gestionnaire, gestionnaire qui
  /// lève) est capturée et posée dans [error] plutôt que de remonter : les
  /// deux appels en tir-et-oublie (`unawaited`, dans `MapScreen`) qui
  /// passent par [refresh] ne doivent jamais planter l'application pour une
  /// panne réseau (`BR-007`) — ni, si l'écran a déjà été démonté, toucher
  /// des `ValueNotifier` disposés ([_disposed]).
  Future<void> refresh(Bounds bounds) async {
    final Bounds? derniere = _lastRequestedBounds;
    if (derniere != null &&
        derniere.north == bounds.north &&
        derniere.south == bounds.south &&
        derniere.east == bounds.east &&
        derniere.west == bounds.west) {
      return;
    }

    _lastRequestedBounds = bounds;
    await _bus
        .send<List<StationPoint>>(StationPointsWithinBoundsQuery(bounds))
        .then((List<StationPoint> reponse) {
          if (_disposed) {
            return;
          }
          stations.value = reponse;
          error.value = null;
        })
        .catchError((Object erreur) {
          if (_disposed) {
            return;
          }
          error.value = erreur;
        });
  }

  void dispose() {
    _disposed = true;
    stations.dispose();
    error.dispose();
  }
}

/// Bandeau d'erreur minimal (`BR-007`) : affiché à la place d'une carte
/// muette quand le bus n'a pas pu répondre — bus sans gestionnaire,
/// gestionnaire qui lève, panne réseau à venir en T1. Widget séparé,
/// testable sans monter de `FlutterMap` (même contrainte que
/// [IgnAttributionBadge]).
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

  /// La caméra courante, mise à jour à chaque `onPositionChanged` — gardée
  /// pour un futur usage (rotation, `04-ui.md`), mais délibérément absente
  /// du `Listenable.merge` de [build] : rien n'en dépend pour le rendu, l'y
  /// inclure reconstruirait les 4 150 marqueurs à chaque frame d'un geste
  /// pour rien (le défaut corrigé par la relecture M3/M4, voir l'en-tête du
  /// fichier).
  final ValueNotifier<MapCamera?> _camera = ValueNotifier<MapCamera?>(null);

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
    onPositionChanged: _handlePositionChanged,
    onMapEvent: _handleMapEvent,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadInitial());
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    _camera.value = camera;
  }

  /// Câblé à `MapOptions.onMapEvent` : ne déclenche une requête d'emprise
  /// que pour les événements de fin de geste ([shouldRefreshOn]), jamais à
  /// chaque frame d'un glisser en cours.
  void _handleMapEvent(MapEvent event) {
    if (!shouldRefreshOn(event)) {
      return;
    }

    final LatLngBounds visible = event.camera.visibleBounds;
    unawaited(
      _controller.refresh(
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
              _controller.error,
            ]),
            builder: (BuildContext context, Widget? child) {
              final Object? error = _controller.error.value;
              return Stack(
                children: <Widget>[
                  FlutterMap(
                    options: _mapOptions,
                    children: buildMapLayers(
                      stations: _controller.stations.value,
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
