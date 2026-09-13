// Le ViewModel de la tranche carte (MVVM, ADR-014, arbitrage 2026-09-13) :
// il appelle [StationPointRepository] DIRECTEMENT et de façon typée, et
// porte l'état que la vue observe — les points à dessiner et l'erreur
// éventuelle. Il remplace le contrôleur d'écran, le registre de messages et
// ses gestionnaires (`lib/application/`, retiré en R4) : le registre perdait
// le type à l'envoi (un transtypage final vers le type de réponse, donc
// `TypeError` à l'exécution là où le projet exige une erreur de compilation)
// sans rien découpler pour une seule forme de lecture.
//
// ⚠️ Un ViewModel ne connaît aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Le verrou est
// `test/architecture/layers_test.dart` (R5).
//
// Il ne connaît pas non plus la bibliothèque de carte : son seul vocabulaire
// géographique est [Bounds], des `double` — jamais un `MapCamera` ni un
// `LatLng`. La vue traduit, le ViewModel reste testable sans monter de
// `FlutterMap`.

import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// L'état de l'écran carte et le seul chemin par lequel il est chargé.
final class MapViewModel extends ChangeNotifier {
  MapViewModel(this._stationPoints);

  final StationPointRepository _stationPoints;

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

  /// La dernière erreur survenue en interrogeant le dépôt, ou `null`. La vue
  /// l'affiche plutôt que de présenter une carte muette (BR-007) : ni le
  /// dépôt ni ce ViewModel n'avalent une panne en silence.
  Object? get error => _error;

  /// Levé par [dispose] : une réponse du dépôt qui arrive après coup ne doit
  /// plus toucher l'état ni appeler `notifyListeners` — un `ChangeNotifier`
  /// disposé lève une assertion si on le notifie.
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

  /// Charge l'emprise de démarrage ([startupBounds]).
  Future<void> loadInitial() => loadFor(startupBounds);

  /// Charge les points de [bounds] et notifie la vue, sauf si les **quatre
  /// bords** sont identiques à la dernière emprise demandée — un relâchement
  /// de geste qui ne change rien ne vaut pas un aller-retour au dépôt ni une
  /// reconstruction de 4 150 marqueurs.
  ///
  /// Une erreur du dépôt est posée dans [error] plutôt que de remonter : les
  /// appels en tir-et-oublie de la vue ne doivent jamais faire tomber
  /// l'application pour une panne de lecture (BR-007).
  Future<void> loadFor(Bounds bounds) async {
    final Bounds? previous = _lastRequestedBounds;
    if (previous != null &&
        previous.north == bounds.north &&
        previous.south == bounds.south &&
        previous.east == bounds.east &&
        previous.west == bounds.west) {
      return;
    }

    _lastRequestedBounds = bounds;
    final int generation = ++_generation;

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
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
