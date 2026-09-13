import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/data/observations/http_hydro_observation_repository.dart';
import 'package:martinpecheur/data/onde/cached_onde_observation_repository.dart';
import 'package:martinpecheur/data/onde/http_onde_observation_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

// La racine de composition, et elle seule (MVVM, ADR-014, arbitrage
// 2026-09-13) : asset et HTTP → dépôts → décorateurs de cache → ViewModel →
// vue. Aucune bibliothèque d'injection — un câblage explicite se lit de haut
// en bas et ne cache aucune résolution à l'exécution.
//
// C'est le SEUL fichier autorisé à nommer une implémentation concrète de
// dépôt : `features/` ne connaît que les interfaces de
// `domain/repositories/repositories.dart` (`layers_test.dart`, règle
// `features-vers-data`, dont `main.dart` est explicitement exempté).
//
// Les deux dépôts réseau sont câblés DÉCORÉS, jamais nus : la politique de
// cache vit dans un seul composant (CLAUDE.md, invariants) et c'est ici
// qu'on la pose. `HubEauClient` est partagé par les deux — il sert tous les
// endpoints Hub'Eau, hydrométrie v2 et écoulement ONDE v1, et recréer un
// second client recopierait sa logique de rejeu. Ses paramètres `sleep`,
// `jitter` et `maxAttempts` gardent leurs valeurs par défaut, celles de
// production documentées dans `hub_eau_client.dart` et `retry.dart` : le
// tirage de gigue réel n'est injecté que dans les tests.
//
// Le référentiel est chargé une fois, avant `runApp`. La vue n'appelle jamais
// un dépôt : elle observe son ViewModel, qui appelle les dépôts directement
// et de façon typée.
//
// `AssetStationRepository` (le dépôt des entités `Station` complètes) n'est
// délibérément pas câblé ici : aucun écran ne le consomme encore. Son premier
// appelant sera la fiche station (T1, tâche U1) ; le câbler d'avance mettrait
// dans la racine de composition un objet que rien ne lit.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final StationsReadResult stationsRead = await loadStationsFromAsset();
  final StationPointRepository stationPoints = AssetStationPointRepository(
    stationsRead.points,
  );

  final HubEauClient hubEau = HubEauClient(httpClient: http.Client());
  final HydroObservationRepository observations =
      CachedHydroObservationRepository(
        inner: HttpHydroObservationRepository(hubEau),
      );
  final OndeObservationRepository onde = CachedOndeObservationRepository(
    inner: HttpOndeObservationRepository(hubEau),
  );

  runApp(
    MartinPecheurApp(
      mapViewModel: MapViewModel(
        stationPoints: stationPoints,
        observations: observations,
        onde: onde,
      ),
    ),
  );
}

// L'écran carte (T0-M4) : fond IGN, attribution, et les stations en
// marqueurs du viewport élargi. Aucun des quatre avertissements (`BR-012`,
// `BR-013`) n'est encore posé — ils arrivent en T1, avant toute mise en
// production.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({required this.mapViewModel, super.key});

  /// Le ViewModel de la tranche carte, construit dans [main]. C'est cette
  /// racine qui le possède : il vit aussi longtemps que l'application, et la
  /// vue ne dispose pas un objet dont elle n'est pas propriétaire.
  final MapViewModel mapViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      home: MapView(viewModel: mapViewModel),
    );
  }
}
