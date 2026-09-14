import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/data/observations/http_hydro_observation_repository.dart';
import 'package:martinpecheur/data/onde/cached_onde_observation_repository.dart';
import 'package:martinpecheur/data/onde/http_onde_observation_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

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
// `AssetStationRepository` (le dépôt des entités `Station` complètes) est
// câblé depuis T1-U1 : son premier appelant est arrivé, c'est
// `StationSheetViewModel`. Il lit `stationsRead.stations` — les entités
// complètes, un sous-ensemble de `points` — et non `points`, qui ne portent
// ni département ni cours d'eau.
//
// C'est aussi ici qu'est résolue la règle `feature-vers-feature`
// (`test/architecture/layers_test.dart`) : la tranche carte ne peut pas
// nommer la tranche fiche station. La racine de composition, elle, connaît
// les deux — elle assemble donc `StationSheetPanel` avec son ViewModel et
// l'INJECTE dans `MapView`, avec le rappel de tap. La carte affiche un
// `Widget` dont elle ignore tout.
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
      stationSheetViewModel: StationSheetViewModel(
        observations: observations,
        stations: AssetStationRepository(stationsRead.stations),
      ),
    ),
  );
}

// L'écran carte (T0-M4, complété par la fiche station de T1-U1) : fond IGN,
// attribution, stations en marqueurs du viewport élargi, et la feuille de
// résumé au tap d'un marqueur. Aucun des quatre avertissements (`BR-012`,
// `BR-013`) n'est encore posé — ils arrivent en T1, avant toute mise en
// production.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({
    required this.mapViewModel,
    required this.stationSheetViewModel,
    super.key,
  });

  /// Le ViewModel de la tranche carte, construit dans [main]. C'est cette
  /// racine qui le possède : il vit aussi longtemps que l'application, et la
  /// vue ne dispose pas un objet dont elle n'est pas propriétaire.
  final MapViewModel mapViewModel;

  /// Le ViewModel de la tranche fiche station, construit dans [main] et
  /// possédé par cette racine, au même titre que [mapViewModel].
  final StationSheetViewModel stationSheetViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      home: MapView(
        viewModel: mapViewModel,
        // `open` rend un `Future` que personne n'attend : l'état de la
        // fiche passe par le ViewModel, pas par ce futur. `unawaited` le
        // dit explicitement plutôt que de le laisser tomber en silence.
        onStationTap: (StationCode code) =>
            unawaited(stationSheetViewModel.open(code)),
        // Le panneau est un `ListenableBuilder` sur le ViewModel de la
        // fiche : il se reconstruit seul à chaque changement d'état, sans
        // reconstruire la carte ni ses 4 150 marqueurs.
        stationSheet: ListenableBuilder(
          listenable: stationSheetViewModel,
          builder: (BuildContext context, Widget? child) => StationSheetPanel(
            state: stationSheetViewModel.state,
            onClose: stationSheetViewModel.close,
          ),
        ),
      ),
    );
  }
}
