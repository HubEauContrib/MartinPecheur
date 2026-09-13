// Le ViewModel de la tranche carte (MVVM, ADR-014, arbitrage 2026-09-13) :
// il appelle [StationPointRepository] DIRECTEMENT et de facon typee, et
// porte l'etat que la vue observe — les points a dessiner et l'erreur
// eventuelle. Il remplace `MapStationsController` + `Bus` + `handlers.dart` :
// le registre perdait le type a l'envoi (`response as R`, donc `TypeError` a
// l'execution la ou le projet exige une erreur de compilation) sans rien
// decoupler pour une seule forme de lecture.
//
// ⚠️ Un ViewModel ne connait aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Le verrou est
// `test/architecture/layers_test.dart` (R5).
//
// Il ne connait pas non plus la bibliotheque de carte : [camera] est un
// enregistrement de `double`, pas un `MapCamera` — la vue traduit, le
// ViewModel reste testable sans monter de `FlutterMap`.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Ce que la vue sait de la camera, sans aucun type de bibliotheque de
/// carte : l'emprise visible en degres decimaux (WGS 84), le zoom et la
/// rotation.
typedef MapViewport = ({
  double north,
  double south,
  double east,
  double west,
  double zoom,
  double rotation,
});

/// L'etat de l'ecran carte et le seul chemin par lequel il est charge.
final class MapViewModel extends ChangeNotifier {
  MapViewModel(this._stationPoints);

  final StationPointRepository _stationPoints;

  /// Emprise de demarrage, avant tout geste de camera : France
  /// metropolitaine. Une emprise de demarrage nommee — pas une valeur
  /// magique posee au milieu d'un `initState`.
  static final Bounds startupBounds = Bounds(
    west: -5.5,
    south: 41,
    east: 10,
    north: 51.5,
  );

  List<StationPoint> _stations = const <StationPoint>[];

  /// Les points du viewport actuellement connu, dans l'ordre du
  /// referentiel. Jamais `null` : une absence de donnee est une liste vide
  /// (BR-007).
  List<StationPoint> get stations => _stations;

  Object? _error;

  /// La derniere erreur survenue en interrogeant le depot, ou `null`. La vue
  /// l'affiche plutot que de presenter une carte muette (BR-007) : ni le
  /// depot ni ce ViewModel n'avalent une panne en silence.
  Object? get error => _error;

  /// La derniere camera connue, posee par la vue a chaque changement de
  /// position.
  ///
  /// ⚠️ **Y ecrire ne notifie personne, deliberement** (correctif de la
  /// relecture M3/M4) : la position change a chaque frame d'un glisser, et
  /// notifier reconstruirait les 4 150 marqueurs par frame pour une valeur
  /// que rien ne lit encore pour le rendu (NFR-01). Elle est gardee pour un
  /// usage a venir — rotation, `04-ui.md`. Le jour ou un rendu en depend, ce
  /// sera avec son propre `Listenable`, pas en notifiant celui-ci.
  MapViewport? camera;

  /// Leve par [dispose] : une reponse du depot qui arrive apres coup ne doit
  /// plus toucher l'etat ni appeler `notifyListeners` — un `ChangeNotifier`
  /// dispose leve une assertion si on le notifie.
  bool _disposed = false;

  Bounds? _lastRequestedBounds;

  /// Charge l'emprise de demarrage ([startupBounds]).
  Future<void> loadInitial() => loadFor(startupBounds);

  /// Charge les points de [bounds] et notifie la vue, sauf si les **quatre
  /// bords** sont identiques a la derniere emprise demandee — un relachement
  /// de geste qui ne change rien ne vaut pas un aller-retour au depot ni une
  /// reconstruction de 4 150 marqueurs.
  ///
  /// Une erreur du depot est posee dans [error] plutot que de remonter : les
  /// appels en tir-et-oublie de la vue ne doivent jamais faire tomber
  /// l'application pour une panne de lecture (BR-007).
  Future<void> loadFor(Bounds bounds) async {
    final Bounds? derniere = _lastRequestedBounds;
    if (derniere != null &&
        derniere.north == bounds.north &&
        derniere.south == bounds.south &&
        derniere.east == bounds.east &&
        derniere.west == bounds.west) {
      return;
    }

    _lastRequestedBounds = bounds;

    try {
      final List<StationPoint> reponse = await _stationPoints.withinBounds(
        bounds,
      );
      if (_disposed) {
        return;
      }
      _stations = reponse;
      _error = null;
    } on Object catch (erreur) {
      if (_disposed) {
        return;
      }
      _error = erreur;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
