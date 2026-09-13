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

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/geo/bounds.dart';
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

/// Attente réelle, utilisée quand aucun [delay] n'est injecté.
Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

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

  Object? _error;

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

  /// Rend [kind] active. Ne fait **rien** — pas même une notification — si
  /// [kind] est déjà l'échelle active : la vue n'a aucune raison de
  /// reconstruire ses marqueurs et sa légende pour un choix sans effet.
  ///
  /// Le passage à [MapScaleKind.ecoulement] recharge les observations ONDE
  /// de l'emprise courante : marqueurs et légende changent **ensemble**
  /// (BR-008, `UC-001 A6`). Ce rechargement est asynchrone et notifie à son
  /// tour quand il aboutit — `selectScale` reste synchrone pour que la
  /// légende bascule à l'instant du geste, sans attendre le réseau.
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
  }

  /// L'état d'affichage de [code] sur la carte. Une station dont aucune
  /// requête n'a encore abouti porte [NonChargee] — jamais [SansDonnee], et
  /// jamais un état par défaut (BR-007) : c'est cette distinction qui
  /// empêche un écran en cours de chargement de ressembler à une absence de
  /// donnée constatée.
  StationMapState stateOf(StationCode code) =>
      _states[code] ?? const NonChargee();

  /// Précharge le débit des [limit] stations visibles les plus proches du
  /// centre de l'emprise courante, en espaçant les requêtes de
  /// [preloadInterval].
  ///
  /// **Borné et annulable, jamais national** (`NFR-07`) : au-delà de [limit]
  /// stations, les autres gardent [NonChargee] jusqu'au tap, qui garantit sa
  /// propre requête (décision 4 du plan T1). Un [limit] nul ou négatif ne
  /// précharge rien.
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
  /// notification par état de station reçu**, et non une seule à la fin. La
  /// carte se remplit alors au fil des réponses plutôt qu'en un bloc après
  /// quatre secondes ; la vue reconstruit ses marqueurs, ce que `NFR-01`
  /// budgète déjà pour un geste de caméra.
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
      final StationMapState next = await _stateFor(target.code);

      if (_disposed || generation != _preloadGeneration) {
        return;
      }
      _states[target.code] = next;
      notifyListeners();
    }
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
  Future<StationMapState> _stateFor(StationCode code) async {
    try {
      final HydroObservation? observation = await _observations.findLatest(
        code,
        Grandeur.debit,
      );
      return observation == null
          ? const SansDonnee()
          : Chargee(observation.freshnessAt(_now()));
    } on Object catch (error) {
      return EnEchec(error);
    }
  }

  /// Arrête le préchargement en cours, s'il y en a un : la requête déjà
  /// partie se termine, mais aucune autre n'est émise et son résultat
  /// n'écrit plus rien. Appelé à chaque [loadFor], et appelable par la vue.
  void cancelPreload() {
    _preloadGeneration++;
  }

  /// Les [limit] stations visibles les plus proches du centre de l'emprise
  /// courante. Liste vide si aucune emprise n'a encore été chargée.
  List<StationPoint> _closestToCentre(int limit) {
    final Bounds? bounds = _lastRequestedBounds;
    if (bounds == null || _stations.isEmpty) {
      return const <StationPoint>[];
    }

    final double centreLatitude = (bounds.south + bounds.north) / 2;
    final double centreLongitude = (bounds.west + bounds.east) / 2;

    // Copie avant tri : `_stations` est une vue non modifiable, et la vue
    // affiche les marqueurs dans l'ordre du référentiel — le préchargement
    // ne réordonne pas ce que l'écran dessine.
    final List<StationPoint> sorted = List<StationPoint>.of(_stations);
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

  /// Charge les observations ONDE de [bounds] dans [_ondeObservations].
  /// Ne notifie pas : l'appelant décide du moment. Une panne est posée dans
  /// [error] (BR-007) et laisse les points de station intacts.
  Future<void> _loadOnde(Bounds bounds, int generation) async {
    try {
      final List<OndeObservation> response = await _onde.latestWithinBounds(
        bounds,
        since: _now().subtract(campagneAncienneApres),
      );
      if (_disposed || generation != _generation) {
        return;
      }
      _ondeObservations = UnmodifiableMapView<OndeStationCode, OndeObservation>(
        <OndeStationCode, OndeObservation>{
          for (final OndeObservation observation in response)
            observation.station: observation,
        },
      );
    } on Object catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _error = error;
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
