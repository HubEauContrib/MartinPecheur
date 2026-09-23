// Le ViewModel de la tranche carte (MVVM, ADR-014, arbitrage 2026-09-13) :
// il appelle ses trois dépôts DIRECTEMENT et de façon typée, et porte l'état
// que la vue observe — les points à dessiner, l'échelle active, l'état de
// chaque station, les observations d'écoulement, et l'erreur éventuelle. Il
// remplace le contrôleur d'écran, le registre de messages et ses
// gestionnaires (`lib/application/`, retiré en R4) : le registre perdait le
// type à l'envoi (un transtypage final vers le type de réponse, donc
// `TypeError` à l'exécution là où le projet exige une erreur de compilation)
// sans rien découpler pour une seule forme de lecture.
//
// ⚠️ Un ViewModel ne connaît aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Il ne connaît pas davantage
// `lib/data/` : ses trois dépendances sont les INTERFACES de dépôt déclarées
// dans `lib/domain/repositories/repositories.dart`, et `main.dart` — seule
// racine de composition — y injecte les implémentations concrètes. Le verrou
// est `test/architecture/layers_test.dart` (règles `view-model-sans-widget`
// et `features-vers-data`).
//
// Il ne connaît pas non plus la bibliothèque de carte : son seul vocabulaire
// géographique est [Bounds], des `double` — jamais un `MapCamera` ni un
// `LatLng`. La vue traduit, le ViewModel reste testable sans monter de
// `FlutterMap`.
//
// Le hasard et l'horloge sont injectés, jamais lus : [now] et [delay] sont
// des paramètres du constructeur. C'est ce qui rend les bornes de BR-005
// testables à la valeur exacte, et le test du préchargement instantané au
// lieu de quatre secondes de mur.

import 'dart:async' show unawaited;
import 'dart:collection' show UnmodifiableListView, UnmodifiableMapView;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/nomenclature/flow_severity.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

/// Nombre maximal de stations préchargées après un geste de carte, faute
/// d'instruction contraire (décision 4 du plan T1). Ni 50, ni « toutes les
/// visibles » : aucune des APIs du projet ne publie de quota chiffré
/// (`C-15`), et `NFR-07` interdit d'en faire l'hypothèse. Le tap sur un
/// marqueur, lui, garantit toujours sa requête — c'est la fiche station qui
/// la porte, pas ce préchargement.
const int defaultPreloadLimit = 20;

/// Attente entre deux requêtes du préchargement (décision 4 du plan T1).
/// Étalement volontaire : vingt requêtes lâchées d'un bloc ressemblent à une
/// rafale côté serveur, exactement ce qu'un throttle client doit éviter
/// (`C-15`).
const Duration preloadInterval = Duration(milliseconds: 200);

/// Âge au-delà duquel un état [Chargee] ou [SansDonnee] redonne droit à une
/// requête de préchargement : sans lui, une session laissée ouverte
/// garderait pour toujours la première lecture de chaque station. Aligné sur
/// le TTL de `observations_tr` (vingt minutes) : une requête plus tôt ne
/// ferait que relire le cache du dépôt.
const Duration stationStateRefreshAfter = Duration(minutes: 20);

/// Sous ce zoom, la carte regroupe ses marqueurs par région (`ADR-015`).
/// Constante nommée, ajustable après constat d'écran — jamais un nombre posé
/// dans un `if` (`MapViewModel.levelFor`).
const double regionClustersBelowZoom = 7;

/// À partir de ce zoom, la carte revient aux marqueurs individuels
/// (`ADR-015`, `F2c` inchangé) ; entre [regionClustersBelowZoom] et ce seuil,
/// le regroupement se fait par département.
const double individualMarkersFromZoom = 9;

/// Un agrégat de zone administrative, prêt à dessiner (`ADR-015`) : la
/// projection carte d'un `AreaCluster` du domaine, propre à une échelle. Sur
/// l'échelle [MapScaleKind.debit], [severest] et [severestAge] sont **nuls**
/// — sans percentile (`ADR-003`, hors T1), toute station est `Indéterminé`
/// et le classement de `BR-009` n'a rien à départager (compte seul).
final class MapAreaCluster {
  const MapAreaCluster({
    required this.scale,
    required this.level,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.bounds,
    required this.severest,
    required this.severestAge,
  });

  /// L'échelle dont cet agrégat porte les membres — une seule à la fois
  /// (BR-008).
  final MapScaleKind scale;

  /// Le niveau administratif de cet agrégat.
  final AreaLevel level;

  /// La zone administrative de cet agrégat.
  final AdministrativeArea area;

  /// Latitude du barycentre des membres.
  final double latitude;

  /// Longitude du barycentre des membres.
  final double longitude;

  /// Le nombre de membres de cet agrégat. Sur l'échelle écoulement, c'est le
  /// compte des points ONDE **chargés** pour l'emprise courante ; sur
  /// l'échelle débit, c'est le compte sur l'asset **entier** (`ADR-015`).
  final int count;

  /// L'emprise exacte des membres, `null` si elle est plate (un seul
  /// membre, ou membres alignés en latitude ou en longitude).
  final Bounds? bounds;

  /// La catégorie d'écoulement la plus sévère des membres (`BR-009`), `null`
  /// sur l'échelle débit.
  final FlowCategory? severest;

  /// L'âge de campagne (`BR-010`) du membre le plus récent de la catégorie
  /// [severest], `null` sur l'échelle débit.
  final CampaignAge? severestAge;
}

/// Où la caméra doit se poser après la sélection d'un [MapAreaCluster]
/// (`ADR-015`) : sur l'emprise de ses membres quand elle existe, sinon
/// centrée sur son barycentre au niveau individuel — la sélection montre
/// toujours ses membres, jamais une caméra immobile.
///
/// `sealed class` fermée (`BR-011`) : la vue (`K1`, `Z4`) traite les deux cas
/// par un `switch` exhaustif.
sealed class ClusterZoomTarget {
  const ClusterZoomTarget();
}

/// Cale la caméra sur [bounds] — l'emprise exacte des membres de l'agrégat.
final class CoverBounds extends ClusterZoomTarget {
  const CoverBounds(this.bounds);

  final Bounds bounds;
}

/// Centre la caméra sur le point donné, au zoom [zoom] — utilisé quand
/// l'agrégat n'a qu'un membre (emprise plate, `AreaCluster.bounds` nul).
final class CentreOn extends ClusterZoomTarget {
  const CentreOn({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;
}

/// Attente réelle, utilisée quand aucun [delay] n'est injecté.
Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// La source dont la lecture a échoué, quand [MapViewModel.error] n'est pas
/// nul. C'est le **ViewModel** qui la dit : la vue ne doit ni inspecter le
/// type d'une exception, ni lire un message pour deviner qui est tombé —
/// `HubEauFailure` vit sous `lib/data/`, et aucun fichier de `lib/features/`
/// n'a le droit de l'importer (`layers_test.dart`, règle
/// `features-vers-data`). Sans cette énumération, « le service Hub'Eau
/// écoulement ONDE n'a pas répondu » ne serait pas écrivable sans casser une
/// frontière de couches.
///
/// ⚠️ **Deux valeurs, pas trois.** L'hydrométrie n'y figure pas, et c'est
/// délibéré : une panne de débit ne passe jamais par [MapViewModel.error],
/// elle devient un [EnEchec] **par station** ([MapViewModel.stateOf],
/// `UC-001 A4`) — les autres stations gardent leur état. Une valeur
/// `hydrometrie` que rien ne poserait serait une branche morte, et un
/// `switch` exhaustif obligerait la vue à inventer un texte pour un cas
/// impossible (YAGNI).
enum MapErrorSource {
  /// Le référentiel embarqué des stations (`AssetStationPointRepository`) :
  /// l'asset n'a pas pu être lu.
  referentiel,

  /// Les observations d'écoulement ONDE (Hub'Eau écoulement).
  ecoulement,
}

/// L'état de l'écran carte et le seul chemin par lequel il est chargé.
final class MapViewModel extends ChangeNotifier {
  /// [now] et [delay] sont injectables pour rendre les tests déterministes
  /// et instantanés ; en production ils valent `DateTime.now` et
  /// `Future.delayed`.
  ///
  /// Les trois dépôts sont déclarés en paramètres de champ privés
  /// (`this._stationPoints`) : Dart en dérive les noms publics
  /// `stationPoints`, `observations` et `onde`, comme le fait déjà
  /// `StationSheetViewModel`. [now] et [delay], eux, ont besoin d'un repli
  /// et restent des paramètres ordinaires.
  MapViewModel({
    required this._stationPoints,
    required this._observations,
    required this._onde,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? _wait;

  final StationPointRepository _stationPoints;
  final HydroObservationRepository _observations;
  final OndeObservationRepository _onde;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  /// Emprise de démarrage, avant tout geste de caméra : France
  /// métropolitaine. Une emprise de démarrage nommée — pas une valeur
  /// magique posée au milieu d'un `initState`.
  static final Bounds startupBounds = Bounds(
    west: -5.5,
    south: 41,
    east: 10,
    north: 51.5,
  );

  List<StationPoint> _stations = const <StationPoint>[];

  /// Les points du viewport actuellement connu, dans l'ordre du
  /// référentiel. Jamais `null` : une absence de donnée est une liste vide
  /// (BR-007).
  ///
  /// Vue **immuable** : la vue lit cet état, elle ne le modifie pas. Un
  /// [UnmodifiableListView] et non `List.unmodifiable` — le second **recopie**
  /// la liste, donc jusqu'à 4 150 éléments à chaque relâchement de geste, là
  /// où la vue n'a besoin que de se voir refuser l'écriture (NFR-01).
  List<StationPoint> get stations => _stations;

  /// Tous les points du référentiel, lus **une seule fois** au premier
  /// besoin (`_refreshClusterDataIfNeeded`) et gardés en mémoire — `null`
  /// tant qu'aucun regroupement de stations n'a encore été demandé.
  /// `ADR-015` : le regroupement des stations porte sur l'asset entier, pas
  /// sur l'emprise, pour que le compte et le barycentre d'une pastille
  /// soient vrais quel que soit le bord de l'écran.
  List<StationPoint>? _allStations;

  AreaLevel? _level;

  /// Le niveau de regroupement administratif actif, décidé par le dernier
  /// zoom transmis à [start] ou [onGestureEnded] ([levelFor]) : `null` tant
  /// qu'aucun des deux n'a encore été appelé — c'est alors le niveau
  /// individuel, comme avant `ADR-015`.
  AreaLevel? get level => _level;

  /// Le niveau de regroupement pour [zoom] (`ADR-015`) : région sous
  /// [regionClustersBelowZoom], département de ce seuil à
  /// [individualMarkersFromZoom] exclu, `null` (niveau individuel) à partir
  /// de [individualMarkersFromZoom]. Fonction pure — elle ne lit ni n'écrit
  /// aucun champ de ce ViewModel. La borne appartient toujours au niveau le
  /// plus fin.
  AreaLevel? levelFor(double zoom) {
    if (zoom < regionClustersBelowZoom) {
      return AreaLevel.region;
    }
    if (zoom < individualMarkersFromZoom) {
      return AreaLevel.departement;
    }
    return null;
  }

  /// Les agrégats de zone administrative à dessiner (`ADR-015`) — **vide**
  /// au niveau individuel ([level] nul). Une seule échelle à la fois
  /// (BR-008) : sur [MapScaleKind.debit], calculés sur [StationPointRepository.all]
  /// (l'asset entier) ; sur [MapScaleKind.ecoulement], sur les observations
  /// ONDE **chargées** pour l'emprise ([ondeObservations]).
  List<MapAreaCluster> get clusters {
    final AreaLevel? level = _level;
    if (level == null) {
      return const <MapAreaCluster>[];
    }
    return switch (_scale) {
      MapScaleKind.debit => _stationMapClusters(level),
      MapScaleKind.ecoulement => _ondeMapClusters(level),
    };
  }

  /// Les stations à dessiner individuellement : au niveau individuel,
  /// **toutes** les stations de l'emprise ([stations]) ; sous le zoom 9,
  /// **seulement** celles sans zone au niveau courant ([level]) — un point
  /// sans région reste affiché, jamais rattaché à une zone voisine
  /// (BR-007).
  ///
  /// ⚠️ Toujours filtrées sur [stations] (l'emprise **courante**), jamais
  /// sur l'asset entier ([_allStations]) — même si le regroupement des
  /// [clusters] porte, lui, sur l'asset entier (`ADR-015`). Le plan est
  /// explicite : « les marqueurs individuels restent ceux de l'emprise,
  /// dans les deux échelles ». Une station sans rattachement mais hors de
  /// l'emprise courante n'a rien à faire sur cet écran (relecture avec
  /// mutations : l'asset entier peut porter des stations non rattachées
  /// que `withinBounds` ne renvoie pas).
  List<StationPoint> get individualStations {
    final AreaLevel? level = _level;
    if (level == null) {
      return _stations;
    }
    return _stations
        .where((StationPoint point) => _stationAreaOf(level, point) == null)
        .toList(growable: false);
  }

  /// Les observations ONDE à dessiner individuellement, même règle que
  /// [individualStations].
  List<OndeObservation> get individualOndeObservations {
    final AreaLevel? level = _level;
    if (level == null) {
      return _ondeObservations.values.toList(growable: false);
    }
    return _ondeClustering(level).unassigned;
  }

  /// La zone administrative de [point] au niveau [level] — région ou
  /// département, seule différence entre les deux niveaux (`ADR-015`).
  AdministrativeArea? _stationAreaOf(AreaLevel level, StationPoint point) =>
      level == AreaLevel.region ? point.region : point.departement;

  /// Le partitionnement des stations au niveau [level], sur l'asset entier
  /// ([_allStations]) — `null` tant qu'il n'a pas encore été chargé
  /// ([_refreshClusterDataIfNeeded]).
  AreaClustering<StationPoint>? _stationClustering(AreaLevel level) {
    final List<StationPoint>? all = _allStations;
    if (all == null) {
      return null;
    }
    return clusterByArea<StationPoint>(
      all,
      level: level,
      areaOf: (StationPoint point) => _stationAreaOf(level, point),
      positionOf: (StationPoint point) =>
          (latitude: point.latitude, longitude: point.longitude),
    );
  }

  /// Le partitionnement des observations ONDE **chargées pour l'emprise**
  /// au niveau [level].
  AreaClustering<OndeObservation> _ondeClustering(AreaLevel level) {
    return clusterByArea<OndeObservation>(
      _ondeObservations.values,
      level: level,
      areaOf: (OndeObservation observation) => level == AreaLevel.region
          ? observation.point.region
          : observation.point.departement,
      positionOf: (OndeObservation observation) => (
        latitude: observation.point.latitude,
        longitude: observation.point.longitude,
      ),
    );
  }

  List<MapAreaCluster> _stationMapClusters(AreaLevel level) {
    final AreaClustering<StationPoint>? clustering = _stationClustering(level);
    if (clustering == null) {
      return const <MapAreaCluster>[];
    }
    return <MapAreaCluster>[
      for (final AreaCluster<StationPoint> cluster in clustering.clusters)
        MapAreaCluster(
          scale: MapScaleKind.debit,
          level: level,
          area: cluster.area,
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          count: cluster.count,
          bounds: cluster.bounds,
          // Sans percentile (ADR-003, hors T1), toute station est
          // « Indéterminé » (BR-004) : le classement de BR-009 n'a rien à
          // départager, la pastille porte le compte seul.
          severest: null,
          severestAge: null,
        ),
    ];
  }

  List<MapAreaCluster> _ondeMapClusters(AreaLevel level) {
    final AreaClustering<OndeObservation> clustering = _ondeClustering(level);
    return <MapAreaCluster>[
      for (final AreaCluster<OndeObservation> cluster in clustering.clusters)
        MapAreaCluster(
          scale: MapScaleKind.ecoulement,
          level: level,
          area: cluster.area,
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          count: cluster.count,
          bounds: cluster.bounds,
          severest: mostSevere(
            cluster.members.map((OndeObservation o) => o.category),
          ),
          severestAge: _severestAgeOf(cluster.members),
        ),
    ];
  }

  /// L'âge (`ondeAgeOf`, `BR-010`) du membre le plus récent portant la
  /// catégorie la plus sévère de [members] — jamais la moyenne, jamais le
  /// dernier lu (`BR-009`).
  CampaignAge _severestAgeOf(List<OndeObservation> members) {
    final FlowCategory severest = mostSevere(
      members.map((OndeObservation o) => o.category),
    );
    OndeObservation? latest;
    for (final OndeObservation member in members) {
      if (member.category != severest) {
        continue;
      }
      if (latest == null || member.observedAt.isAfter(latest.observedAt)) {
        latest = member;
      }
    }
    return ondeAgeOf(latest!);
  }

  /// Où poser la caméra après la sélection de [cluster] (`ADR-015`) :
  /// [CoverBounds] quand l'emprise de ses membres n'est pas plate, sinon
  /// [CentreOn] son barycentre au niveau individuel — la sélection montre
  /// toujours ses membres, jamais une caméra immobile.
  ClusterZoomTarget zoomTargetFor(MapAreaCluster cluster) {
    final Bounds? bounds = cluster.bounds;
    if (bounds != null) {
      return CoverBounds(bounds);
    }
    return CentreOn(
      latitude: cluster.latitude,
      longitude: cluster.longitude,
      zoom: individualMarkersFromZoom,
    );
  }

  Object? _error;

  MapErrorSource? _errorSource;

  /// Quelle source a échoué, quand [error] n'est pas nul ; `null` sinon.
  /// Toujours posée **en même temps** que [error], et effacée avec elle :
  /// une erreur sans source serait un message qui ne nomme personne, ce que
  /// `BR-007` refuse (« message par source »).
  MapErrorSource? get errorSource => _errorSource;

  /// La dernière erreur survenue en interrogeant un dépôt, ou `null`. La vue
  /// l'affiche plutôt que de présenter une carte muette (BR-007) : ni les
  /// dépôts ni ce ViewModel n'avalent une panne en silence. Une panne ONDE y
  /// figure au même titre qu'une panne du référentiel, et les points de
  /// station restent affichés — les autres sources continuent de
  /// fonctionner (`UC-001 A4`).
  Object? get error => _error;

  MapScaleKind _scale = MapScaleKind.ecoulement;

  /// Échelle de lecture active, **une seule à la fois** (BR-008).
  /// L'écoulement est active par défaut (`UC-001 § 3`).
  MapScaleKind get scale => _scale;

  final Map<StationCode, StationMapState> _states =
      <StationCode, StationMapState>{};

  /// L'observation de chaque station [Chargee] : sa fraîcheur est recalculée
  /// à chaque lecture de [stateOf], jamais figée à l'instant du chargement
  /// (BR-005).
  final Map<StationCode, HydroObservation> _latestObservations =
      <StationCode, HydroObservation>{};

  /// L'instant où l'état de chaque station a été posé, pour
  /// [stationStateRefreshAfter].
  final Map<StationCode, DateTime> _stateSetAt = <StationCode, DateTime>{};

  Map<OndeStationCode, OndeObservation> _ondeObservations =
      UnmodifiableMapView<OndeStationCode, OndeObservation>(
        <OndeStationCode, OndeObservation>{},
      );

  /// Les dernières observations d'écoulement connues pour l'emprise
  /// courante, **une par station** — la clé est `observation.station`, le
  /// regroupement étant déjà fait par le dépôt. Vue non modifiable, pour la
  /// même raison que [stations].
  ///
  /// Alimentée seulement sur l'échelle [MapScaleKind.ecoulement] (BR-008).
  /// Un passage à [MapScaleKind.debit] ne la vide pas : ce qui est déjà
  /// connu reste en mémoire pour que le retour à l'écoulement ait quelque
  /// chose à dessiner pendant que le rechargement tourne. C'est [scale], et
  /// elle seule, qui dit à la vue quelle échelle dessiner.
  Map<OndeStationCode, OndeObservation> get ondeObservations =>
      _ondeObservations;

  int _ondeUnreadableRows = 0;

  /// Nombre de lignes ONDE que la source a rendues sans qu'on sache les
  /// lire, **pour l'emprise courante** (`OndeSweep.unreadableRows`, `T-14`).
  /// Zéro tant qu'aucun balayage n'a abouti, et zéro dès qu'une emprise
  /// propre répond : ce chiffre décrit ce que l'usager regarde, jamais le
  /// cumul de la session — c'est ce qui le rend affichable (« N points
  /// d'observation non lisibles sur cette emprise », BR-007).
  ///
  /// Alimenté seulement sur l'échelle [MapScaleKind.ecoulement], comme
  /// [ondeObservations] : sur [MapScaleKind.debit], aucun appel ONDE n'est
  /// émis (BR-008), et il n'y a donc rien à expliquer.
  int get ondeUnreadableRows => _ondeUnreadableRows;

  /// Levé par [dispose] : une réponse d'un dépôt qui arrive après coup ne
  /// doit plus toucher l'état ni appeler `notifyListeners` — un
  /// `ChangeNotifier` disposé lève une assertion si on le notifie.
  bool _disposed = false;

  Bounds? _lastRequestedBounds;

  /// Numéro du dernier chargement demandé. Incrémenté à chaque [loadFor] et
  /// comparé au retour du dépôt : une réponse dont le numéro n'est plus le
  /// dernier appartient à une emprise abandonnée et n'écrit rien.
  ///
  /// Sans ce jeton, deux gestes rapprochés sur des emprises différentes
  /// laissent l'écran sur la réponse qui arrive en **dernier**, pas sur
  /// l'emprise demandée en dernier : la carte affiche alors les marqueurs
  /// d'une région que l'usager a quittée.
  int _generation = 0;

  /// Jeton propre au préchargement, distinct de [_generation] : [cancelPreload]
  /// doit pouvoir arrêter une boucle de requêtes **sans** invalider le
  /// chargement de points en cours.
  int _preloadGeneration = 0;

  /// Charge l'emprise de démarrage ([startupBounds]).
  Future<void> loadInitial() => loadFor(startupBounds);

  /// Point d'entrée du démarrage de l'écran (`H2`, 2026-09-22) : charge
  /// l'emprise de démarrage, puis — si l'échelle active le justifie
  /// ([shouldPreloadOn], **relue après** le chargement, jamais avant, car
  /// l'usager a pu basculer d'échelle pendant l'attente réseau) — précharge
  /// les stations visibles.
  ///
  /// Cet enchaînement vivait dans `_loadThenPreload`, côté vue
  /// (`map_view.dart`), et n'était couvert par aucun test : « inatteignable
  /// sans monter un `FlutterMap` ». Il vit ici pour que `K1`/`K2` le
  /// réutilisent sans le recopier.
  ///
  /// [zoom] fixe le [level] de démarrage (`ADR-015`, `Z3`) : la vue ne fait
  /// que le transmettre (`camera.zoom`, ou [initialMapZoom] au tout premier
  /// appel) — ce ViewModel ne connaît pas `flutter_map`, [zoom] est un
  /// `double` comme l'emprise est un [Bounds]. **Le préchargement n'a lieu
  /// qu'au niveau individuel** ([shouldPreloadOn] ET [level] nul, relus
  /// **après** le chargement) : une pastille ne montre aucun état de
  /// station, précharger sous le zoom 9 serait du travail réseau sans
  /// destinataire (`NFR-07`).
  ///
  /// N'appelle **pas** [_refreshClusterDataIfNeeded] : l'échelle de
  /// démarrage est toujours [MapScaleKind.ecoulement] (`UC-001 § 3`), qui
  /// n'a jamais besoin de l'asset entier — seul le regroupement des
  /// STATIONS (échelle débit) en dépend. Aucun test ne justifie cet appel
  /// ici (YAGNI, relecture avec mutations) : le premier geste ou le premier
  /// passage à l'échelle débit s'en chargera, via [onGestureEnded] ou
  /// [selectScale].
  Future<void> start({required double zoom}) async {
    _updateLevel(zoom);
    await loadInitial();
    if (shouldPreloadOn(_scale) && _level == null) {
      await preloadVisibleStations();
    }
  }

  /// Signalé par la vue à la fin d'un geste de caméra terminé sur [bounds],
  /// au zoom [zoom] (`H2`, 2026-09-22 ; [zoom] ajouté en `Z3`) : charge
  /// cette emprise, puis déclenche le préchargement dans les mêmes
  /// conditions que [start]. La vue ne décide plus rien — elle signale
  /// « geste terminé + emprise + zoom ».
  ///
  /// ⚠️ **Aucun retour anticipé sur emprise et niveau inchangés** (relecture
  /// avec mutations, régression de `Z3` sur `H2`) : le plan ne le demande
  /// pas, et [loadFor] refuse déjà, de lui-même, une emprise identique à la
  /// dernière demandée. Court-circuiter ici en plus empêchait un geste sur
  /// la MÊME emprise de relancer [preloadVisibleStations] — donc de
  /// retenter une station [EnEchec] ou de rafraîchir une station devenue
  /// périmée ([stationStateRefreshAfter]) — ce que `H2` garantissait.
  ///
  /// Un changement de **niveau** ([levelFor]) notifie même quand l'emprise
  /// est inchangée (`ADR-015`) : [loadFor] ne le ferait pas de lui-même,
  /// puisqu'il refuse une emprise identique à la dernière demandée — mais
  /// une pastille qui cède la place aux marqueurs individuels (ou
  /// l'inverse) est un changement à l'écran, pas un chargement réseau.
  ///
  /// ⚠️ La notification du changement de niveau ne suffit pas à elle seule
  /// (relecture avec mutations) : quand l'emprise change **en même temps**
  /// que le niveau, [_refreshClusterDataIfNeeded] peut poser [_allStations]
  /// ou [error] **après** la notification de [loadFor] — sans notification
  /// à elle, la dernière valeur connue de l'écran resterait « pas encore
  /// calculable », carte vide ou erreur muette, jusqu'au geste suivant.
  /// [_refreshClusterDataIfNeeded] rend donc un `bool` : `true` s'il vient
  /// de poser [_allStations] ou [error], et ce ViewModel notifie alors,
  /// qu'il y ait déjà eu une notification de [loadFor] ou non.
  Future<void> onGestureEnded(Bounds bounds, {required double zoom}) async {
    final AreaLevel? previousLevel = _level;
    _updateLevel(zoom);
    final bool levelChanged = _level != previousLevel;
    final bool boundsChanged = _lastRequestedBounds != bounds;

    if (boundsChanged) {
      await loadFor(bounds);
    }

    final bool clusterDataChanged = await _refreshClusterDataIfNeeded();

    if (!_disposed &&
        (clusterDataChanged || (!boundsChanged && levelChanged))) {
      notifyListeners();
    }

    if (shouldPreloadOn(_scale) && _level == null) {
      await preloadVisibleStations();
    }
  }

  /// Met à jour [level] pour [zoom] ([levelFor]). Appelé au tout début de
  /// [start] et [onGestureEnded], avant tout `await` : c'est ce qui rend
  /// [clusters] et [individualStations] cohérents avec le geste qui vient
  /// d'arriver, même si le réseau met du temps à répondre.
  void _updateLevel(double zoom) {
    _level = levelFor(zoom);
  }

  /// Charge l'asset entier ([StationPointRepository.all]) si le niveau
  /// courant et l'échelle active en ont besoin, et si ce n'est pas déjà
  /// fait — **une seule fois**, gardé en mémoire ([_allStations]) tant que
  /// l'application tourne (`ADR-015`). Ne fait rien au niveau individuel ni
  /// sur l'échelle écoulement : seul le regroupement des STATIONS porte sur
  /// l'asset entier, celui des observations ONDE porte sur les points déjà
  /// chargés pour l'emprise ([_ondeObservations]).
  ///
  /// Une panne est posée dans [error] avec la source [MapErrorSource.referentiel]
  /// — comme un échec de [StationPointRepository.withinBounds] — et
  /// n'est **pas** mise en cache : le prochain appel retente.
  ///
  /// Rend `true` quand cet appel vient de poser [_allStations] ou [error] —
  /// c'est-à-dire chaque fois qu'il a réellement tenté l'appel réseau, ce
  /// bloc n'étant traversé qu'une fois par succès (`_allStations` non nul
  /// ensuite empêche tout nouvel essai) — `false` sinon (rien à faire, ou
  /// [dispose] survenu entre-temps). L'appelant ([onGestureEnded]) s'en sert
  /// pour notifier même quand [loadFor] a déjà notifié pour l'emprise
  /// seule : sans cela, un geste qui change emprise ET niveau en même temps
  /// laisserait la dernière notification connue de l'écran en retard d'un
  /// tour (carte vide ou erreur muette jusqu'au geste suivant).
  Future<bool> _refreshClusterDataIfNeeded() async {
    if (_level == null ||
        _scale != MapScaleKind.debit ||
        _allStations != null) {
      return false;
    }
    try {
      final List<StationPoint> response = await _stationPoints.all();
      if (_disposed) {
        return false;
      }
      _allStations = response;
      if (_errorSource == MapErrorSource.referentiel) {
        _error = null;
        _errorSource = null;
      }
      return true;
    } on Object catch (error) {
      if (_disposed) {
        return false;
      }
      _error = error;
      _errorSource = MapErrorSource.referentiel;
      return true;
    }
  }

  /// Charge les points de [bounds] et notifie la vue, sauf si l'emprise est
  /// identique à la dernière emprise demandée ([Bounds.==], structurelle sur
  /// les quatre bords) — un relâchement de geste qui ne change rien ne vaut
  /// pas un aller-retour au dépôt ni une reconstruction de 4 150 marqueurs.
  ///
  /// Sur l'échelle [MapScaleKind.ecoulement], charge aussi les observations
  /// ONDE de l'emprise, avec `since = now - `[campagneAncienneApres] : la
  /// carte ne remonte jamais plus loin qu'une campagne récente (BR-010,
  /// `T-03`). Sur l'échelle [MapScaleKind.debit], **aucun** appel ONDE
  /// n'est émis (BR-008).
  ///
  /// Un geste annule le préchargement en cours ([cancelPreload]) : les
  /// requêtes d'une emprise que l'usager a quittée n'ont plus de valeur et
  /// consomment un quota qui n'est pas documenté (`NFR-07`, `C-15`). C'est
  /// la **vue** qui relance ensuite [preloadVisibleStations] : `loadFor` ne
  /// déclenche pas de préchargement de lui-même, pour qu'un écran qui n'en
  /// veut pas n'ait pas à l'annuler.
  ///
  /// Une erreur d'un dépôt est posée dans [error] plutôt que de remonter :
  /// les appels en tir-et-oublie de la vue ne doivent jamais faire tomber
  /// l'application pour une panne de lecture (BR-007).
  ///
  /// Notifie **dès que** les points de station sont posés — succès ou échec
  /// — et non à la toute fin : les points viennent d'un asset local,
  /// instantané, quand l'ONDE est un aller-retour réseau pouvant durer
  /// jusqu'à quatre tentatives avec recul (30 s max). Retarder l'affichage
  /// des marqueurs derrière l'ONDE violerait `UC-001 § 4`. L'ONDE, sur
  /// l'échelle [MapScaleKind.ecoulement], notifie à son tour quand elle
  /// répond — une granularité unique dans ce fichier, « au fil de l'eau »,
  /// déjà celle de [selectScale]/[_reloadOndeForScale] et du préchargement.
  Future<void> loadFor(Bounds bounds) async {
    final Bounds? previous = _lastRequestedBounds;
    if (previous == bounds) {
      return;
    }

    _lastRequestedBounds = bounds;
    final int generation = ++_generation;
    cancelPreload();

    try {
      final List<StationPoint> response = await _stationPoints.withinBounds(
        bounds,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _stations = UnmodifiableListView<StationPoint>(response);
      _error = null;
      _errorSource = null;
    } on Object catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      // Une emprise qui a échoué n'est pas une emprise chargée : on oublie
      // qu'elle a été demandée, sinon la garde ci-dessus refuserait le
      // nouvel essai et l'écran resterait en erreur jusqu'à ce que l'usager
      // déplace la carte.
      _lastRequestedBounds = null;
      _error = error;
      _errorSource = MapErrorSource.referentiel;
      notifyListeners();
      return;
    }

    notifyListeners();

    if (_scale == MapScaleKind.ecoulement) {
      await _loadOnde(bounds, generation);
      if (_disposed || generation != _generation) {
        return;
      }
      notifyListeners();
    }
  }

  /// Élargit la recherche : recharge une emprise **deux fois plus haute et
  /// deux fois plus large** que la dernière emprise demandée, centrée au
  /// même endroit (`UC-001 A2` — l'action « Élargir la recherche »
  /// accompagne le message d'absence de `BR-007`).
  ///
  /// Le calcul vit ici et non dans la vue : un widget branche et affiche, il
  /// ne décide pas d'une géométrie. La vue n'a qu'un rappel à poser sur son
  /// bouton.
  ///
  /// ⚠️ **La caméra ne bouge pas.** Ce ViewModel ne pilote pas `flutter_map`
  /// — il n'en connaît pas le vocabulaire (ADR-014) : l'emprise chargée
  /// s'élargit, les marqueurs hors écran restent hors écran jusqu'au prochain
  /// geste de l'usager. Le déplacement de caméra est reporté à `K1`, avec les
  /// contrôles de zoom.
  ///
  /// Ne demande **rien** tant qu'aucune emprise n'a abouti : il n'y a alors
  /// rien à élargir. Les bords sont bornés au domaine des coordonnées
  /// (±90° en latitude, ±180° en longitude) — une emprise déjà mondiale est
  /// son propre élargissement, et [loadFor] la refuse comme inchangée.
  Future<void> widenSearch() {
    final Bounds? bounds = _lastRequestedBounds;
    if (bounds == null) {
      return Future<void>.value();
    }

    // Une demi-hauteur de chaque côté double la hauteur ; idem en largeur.
    final double halfHeight = (bounds.north - bounds.south) / 2;
    final double halfWidth = (bounds.east - bounds.west) / 2;

    return loadFor(
      Bounds(
        west: math.max(-180, bounds.west - halfWidth),
        south: math.max(-90, bounds.south - halfHeight),
        east: math.min(180, bounds.east + halfWidth),
        north: math.min(90, bounds.north + halfHeight),
      ),
    );
  }

  /// Rend [kind] active. Ne fait **rien** — pas même une notification — si
  /// [kind] est déjà l'échelle active : la vue n'a aucune raison de
  /// reconstruire ses marqueurs et sa légende pour un choix sans effet.
  ///
  /// Le passage à [MapScaleKind.ecoulement] recharge les observations ONDE
  /// de l'emprise courante : marqueurs et légende changent **ensemble**
  /// (BR-008, `UC-001 A6`). Ce rechargement est asynchrone et notifie à son
  /// tour quand il aboutit — `selectScale` reste synchrone pour que la
  /// légende bascule à l'instant du geste, sans attendre le réseau.
  ///
  /// Le passage à [MapScaleKind.debit] lance lui-même le préchargement
  /// ([shouldPreloadOn], `H2`) — c'est à cet instant que les stations
  /// deviennent visibles, et non au relâchement de geste suivant. Ce
  /// branchement vivait dans `_handleScaleSelected`, côté vue.
  void selectScale(MapScaleKind kind) {
    if (kind == _scale) {
      return;
    }

    _scale = kind;
    notifyListeners();

    final Bounds? bounds = _lastRequestedBounds;
    if (kind == MapScaleKind.ecoulement && bounds != null) {
      unawaited(_reloadOndeForScale(bounds));
    }

    if (kind == MapScaleKind.debit && _level != null) {
      unawaited(_refreshClusterDataThenNotify());
    }

    if (shouldPreloadOn(kind) && _level == null) {
      unawaited(preloadVisibleStations());
    }
  }

  /// Charge l'asset entier si le passage à l'échelle débit en a besoin
  /// ([_refreshClusterDataIfNeeded]), puis notifie : [selectScale] reste
  /// synchrone, ce chargement est en tir-et-oublie comme le rechargement
  /// ONDE de [_reloadOndeForScale].
  Future<void> _refreshClusterDataThenNotify() async {
    await _refreshClusterDataIfNeeded();
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// L'âge de la campagne de [observation] (`BR-010`), sur l'horloge
  /// **déjà injectée** de ce ViewModel ([_now]), ramenée en UTC comme le
  /// faisait la vue (`campaignAgeOf` exige que `now` soit dans le fuseau
  /// d'`observedAt`, l'UTC que le mapper rend — `T-08`). **Déplacée** de
  /// `map_view.dart` (`H2`, 2026-09-22) : c'est ce ViewModel qui possède
  /// l'horloge, la vue n'en lit plus aucune.
  CampaignAge ondeAgeOf(OndeObservation observation) =>
      campaignAgeOf(observedAt: observation.observedAt, now: _now().toUtc());

  /// L'état d'affichage de [code] sur la carte. Une station dont aucune
  /// requête n'a encore abouti porte [NonChargee] — jamais [SansDonnee], et
  /// jamais un état par défaut (BR-007) : c'est cette distinction qui
  /// empêche un écran en cours de chargement de ressembler à une absence de
  /// donnée constatée.
  ///
  /// La fraîcheur d'un [Chargee] est calculée à l'instant de la lecture, sur
  /// l'horloge injectée : une mesure fraîche au chargement vieillit à
  /// l'écran sans nouvelle requête (BR-005).
  StationMapState stateOf(StationCode code) {
    final HydroObservation? observation = _latestObservations[code];
    if (observation != null) {
      return Chargee(observation.freshnessAt(_now()));
    }
    return _states[code] ?? const NonChargee();
  }

  /// Précharge le débit des [limit] stations visibles les plus proches du
  /// centre de l'emprise courante, en espaçant les requêtes de
  /// [preloadInterval].
  ///
  /// **Borné et annulable, jamais national** (`NFR-07`) : au-delà de [limit]
  /// stations, les autres gardent [NonChargee] jusqu'au tap, qui garantit sa
  /// propre requête (décision 4 du plan T1). Un [limit] nul ou négatif ne
  /// précharge rien.
  ///
  /// **Les états déjà connus sont sautés** ([_needsPreload]) : une station
  /// [Chargee] ou [SansDonnee] ne vaut pas une seconde requête, une station
  /// [EnEchec] est **retentée** — une panne passe, un fait constaté non — et
  /// une station [NonChargee] est chargée. Sans ce filtre, la vue relançant
  /// le préchargement après un geste dont l'emprise n'a pas changé
  /// réécrivait vingt états identiques et notifiait vingt fois, donc vingt
  /// reconstructions des 4 150 marqueurs (`NFR-01`) ; et deux gestes
  /// rapprochés affamaient les dernières stations, toujours recommencées par
  /// les mêmes vingt premières.
  ///
  /// ⚠️ [limit] borne donc les **requêtes**, pas les stations regardées : un
  /// second appel sur la même emprise repart des vingt plus proches **parmi
  /// les non chargées**, et la carte se remplit de proche en proche.
  ///
  /// **Ordre de sélection**, déterministe et testable : distance euclidienne
  /// en **degrés** au centre de l'emprise (`(south+north)/2`,
  /// `(west+east)/2`), puis code station croissant en cas d'égalité — jamais
  /// l'ordre du référentiel, sinon deux exécutions ne prendraient pas les
  /// mêmes stations. Le degré n'est pas isotrope (un degré de longitude
  /// mesure moins qu'un degré de latitude à 47° N) : c'est assumé, il s'agit
  /// de choisir vingt stations plausibles au centre de l'écran, pas de
  /// mesurer une distance géodésique.
  ///
  /// **Granularité des notifications** (le plan la laissait libre) : **une
  /// notification par changement d'état effectif**, et non une seule à la
  /// fin. La carte se remplit alors au fil des réponses plutôt qu'en un bloc
  /// après quatre secondes ; la vue reconstruit ses marqueurs, ce que
  /// `NFR-01` budgète déjà pour un geste de caméra. Un état reçu **égal** à
  /// celui déjà porté — un [EnEchec] retenté qui échoue de la même façon —
  /// ne notifie pas : rien n'a changé à l'écran.
  ///
  /// Ne lève jamais : une panne sur une station devient [EnEchec] pour
  /// **cette** station, et les autres gardent leur état (`UC-001 A4`).
  Future<void> preloadVisibleStations({int limit = defaultPreloadLimit}) async {
    if (limit <= 0) {
      return;
    }

    final int generation = ++_preloadGeneration;
    final List<StationPoint> targets = _closestToCentre(limit);

    for (int index = 0; index < targets.length; index++) {
      if (_disposed || generation != _preloadGeneration) {
        return;
      }

      // L'attente sépare deux requêtes ; elle ne retarde pas la première.
      if (index > 0) {
        await _delay(preloadInterval);
        if (_disposed || generation != _preloadGeneration) {
          return;
        }
      }

      final StationPoint target = targets[index];
      final (StationMapState next, HydroObservation? observation) =
          await _stateFor(target.code);

      if (_disposed || generation != _preloadGeneration) {
        return;
      }
      final StationMapState previous = stateOf(target.code);
      _states[target.code] = next;
      _stateSetAt[target.code] = _now();
      if (observation == null) {
        _latestObservations.remove(target.code);
      } else {
        _latestObservations[target.code] = observation;
      }
      if (stateOf(target.code) != previous) {
        notifyListeners();
      }
    }
  }

  /// Une station mérite-t-elle une requête de préchargement ?
  ///
  /// `switch` exhaustif sur la `sealed class` du domaine (`BR-011`) : un état
  /// ajouté à [StationMapState] sans branche ici est une erreur de
  /// compilation, jamais une station silencieusement jamais rechargée.
  ///
  /// [EnEchec] est le seul état déjà connu qui redonne droit à une requête :
  /// une panne de source est transitoire (`UC-001 A4`), là où [SansDonnee]
  /// est un **fait constaté** (`BR-007`) et [Chargee] une valeur en main.
  ///
  /// [Chargee] et [SansDonnee] redeviennent éligibles passé
  /// [stationStateRefreshAfter] : une session longue relit la source au
  /// lieu de garder sa première lecture.
  bool _needsPreload(StationCode code) => switch (stateOf(code)) {
    NonChargee() || EnEchec() => true,
    Chargee() || SansDonnee() => _isOutdated(code),
  };

  bool _isOutdated(StationCode code) {
    final DateTime? setAt = _stateSetAt[code];
    return setAt == null ||
        _now().difference(setAt) >= stationStateRefreshAfter;
  }

  /// L'état d'une station, lu au dépôt. Ne lève jamais : une panne devient
  /// [EnEchec] pour cette station seule (`UC-001 A4`), une absence devient
  /// [SansDonnee] — jamais [NonChargee], qui dit « pas encore essayé »
  /// (BR-007).
  ///
  /// Une méthode à part, et non un `try` dans la boucle de
  /// [preloadVisibleStations] : une variable `final` affectée dans les deux
  /// branches d'un `try`/`catch` n'est pas reconnue comme certainement
  /// affectée par l'analyseur Dart.
  ///
  /// Rend aussi l'observation lue, pour que [stateOf] recalcule sa fraîcheur
  /// à chaque lecture.
  Future<(StationMapState, HydroObservation?)> _stateFor(
    StationCode code,
  ) async {
    try {
      final HydroObservation? observation = await _observations.findLatest(
        code,
        Grandeur.debit,
      );
      return observation == null
          ? (const SansDonnee(), null)
          : (Chargee(observation.freshnessAt(_now())), observation);
    } on Object catch (error) {
      return (EnEchec(error), null);
    }
  }

  // L'état de visibilité du bandeau (afficher/fermer/réafficher) est retiré par `W3c` : `WarningLink` ne porte aucun état de session.

  /// Arrête le préchargement en cours, s'il y en a un : la requête déjà
  /// partie se termine, mais aucune autre n'est émise et son résultat
  /// n'écrit plus rien. Appelé à chaque [loadFor], et appelable par la vue.
  void cancelPreload() {
    _preloadGeneration++;
  }

  /// Les [limit] stations visibles les plus proches du centre de l'emprise
  /// courante, **parmi celles qui valent encore une requête**
  /// ([_needsPreload]). Liste vide si aucune emprise n'a encore été chargée.
  List<StationPoint> _closestToCentre(int limit) {
    final Bounds? bounds = _lastRequestedBounds;
    if (bounds == null || _stations.isEmpty) {
      return const <StationPoint>[];
    }

    final double centreLatitude = (bounds.south + bounds.north) / 2;
    final double centreLongitude = (bounds.west + bounds.east) / 2;

    // Copie avant tri : `_stations` est une vue non modifiable, et la vue
    // affiche les marqueurs dans l'ordre du référentiel — le préchargement
    // ne réordonne pas ce que l'écran dessine. Le filtre est posé AVANT le
    // tri : trier 4 150 points pour en écarter ensuite les vingt premiers
    // ferait payer deux fois la même comparaison.
    final List<StationPoint> sorted = _stations
        .where((StationPoint point) => _needsPreload(point.code))
        .toList();
    sorted.sort((StationPoint a, StationPoint b) {
      final int byDistance = _squaredDegreesTo(
        a,
        centreLatitude,
        centreLongitude,
      ).compareTo(_squaredDegreesTo(b, centreLatitude, centreLongitude));
      if (byDistance != 0) {
        return byDistance;
      }
      return a.code.value.compareTo(b.code.value);
    });

    return sorted.take(limit).toList(growable: false);
  }

  /// Carré de la distance en degrés de [point] au centre donné. Le carré
  /// suffit : il ordonne comme la distance, sans racine carrée.
  double _squaredDegreesTo(
    StationPoint point,
    double latitude,
    double longitude,
  ) {
    final double deltaLatitude = point.latitude - latitude;
    final double deltaLongitude = point.longitude - longitude;
    return deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude;
  }

  /// Charge les observations ONDE de [bounds] dans [_ondeObservations], et
  /// le nombre de lignes illisibles du balayage dans [ondeUnreadableRows].
  /// Ne notifie pas : l'appelant décide du moment. Une panne est posée dans
  /// [error] avec sa source ([MapErrorSource.ecoulement], BR-007) et laisse
  /// les points de station intacts.
  ///
  /// Un balayage qui aboutit **efface l'erreur d'écoulement** qu'un balayage
  /// précédent avait posée — et elle seule : voir la garde ci-dessous.
  ///
  /// Une panne ne touche ni [ondeObservations] ni [ondeUnreadableRows] : les
  /// deux décrivent le dernier balayage ABOUTI, et le compte doit rester
  /// d'accord avec les observations qu'il explique. Les dissocier ferait
  /// afficher « N points non lisibles » à côté de marqueurs venus d'un autre
  /// balayage.
  Future<void> _loadOnde(Bounds bounds, int generation) async {
    try {
      final OndeSweep response = await _onde.latestWithinBounds(
        bounds,
        since: _now().subtract(campagneAncienneApres),
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _ondeObservations = UnmodifiableMapView<OndeStationCode, OndeObservation>(
        <OndeStationCode, OndeObservation>{
          for (final OndeObservation observation in response.observations)
            observation.station: observation,
        },
      );
      _ondeUnreadableRows = response.unreadableRows;
      // Un balayage qui aboutit DÉMENT la panne qu'il remplace : sans cette
      // remise à zéro, l'avis « Hub'Eau écoulement ONDE n'a pas répondu »
      // resterait affiché par-dessus des marqueurs revenus — et comme « une
      // panne parle seule » (`mapNoticesFor`), il masquerait à lui seul tout
      // autre avis d'absence (`BR-007`).
      //
      // ⚠️ **Seule une erreur d'écoulement est effacée.** Une panne du
      // référentiel n'est pas démentie par une lecture ONDE réussie : les
      // deux sources sont indépendantes, et l'effacer ici rendrait la carte
      // muette sur un asset illisible. En pratique l'état « erreur
      // référentiel + balayage ONDE » n'est pas atteignable — un `loadFor`
      // en échec oublie son emprise, et `selectScale` n'a alors plus
      // d'emprise à recharger —, mais la garde dit ce que cette méthode a
      // le droit d'effacer, plutôt que de dépendre de cette coïncidence.
      if (_errorSource == MapErrorSource.ecoulement) {
        _error = null;
        _errorSource = null;
      }
    } on Object catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _error = error;
      _errorSource = MapErrorSource.ecoulement;
    }
  }

  /// Rechargement ONDE déclenché par un changement d'échelle. Reprend le
  /// jeton de chargement **courant** sans l'incrémenter : l'emprise n'a pas
  /// changé, mais un `loadFor` survenu entre-temps doit rendre cette réponse
  /// caduque.
  Future<void> _reloadOndeForScale(Bounds bounds) async {
    final int generation = _generation;
    await _loadOnde(bounds, generation);
    if (_disposed || generation != _generation) {
      return;
    }
    notifyListeners();
  }

  /// Annule le préchargement en cours avant de couper court : une attente de
  /// 200 ms encore en vol ([preloadInterval]) ne doit pas survivre à ce
  /// ViewModel.
  @override
  void dispose() {
    cancelPreload();
    _disposed = true;
    super.dispose();
  }
}
