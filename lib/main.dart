import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/data/observations/http_hydro_observation_repository.dart';
import 'package:martinpecheur/data/onde/cached_onde_observation_repository.dart';
import 'package:martinpecheur/data/onde/http_onde_observation_repository.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_acknowledgement_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';
import 'package:martinpecheur/features/warnings/view/initial_warning_view.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';

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
// `Widget` dont elle ignore tout. `OndeSheetPanel` est câblé de la même
// façon depuis T1-U4, sur le MÊME dépôt ONDE décoré que la carte : une seule
// politique de cache, un seul cache.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // L'écran bloquant du premier lancement (`BR-012`, `UC-006`, tâche `W2`) :
  // `load()` est attendu ICI, AVANT `runApp` — un usager déjà acquitté ne
  // doit jamais voir le modal, pas même une image (révision du plan du
  // 2026-09-22). `WarningsViewModel` vaut `requiresAcknowledgement == true`
  // avant `load()` : sans cet appel préalable, l'écran clignoterait.
  final WarningsViewModel warningsViewModel = WarningsViewModel(
    acknowledgements: SharedPreferencesAcknowledgementRepository(),
    currentWarningVersion: warningTextVersion,
  );
  await warningsViewModel.load();

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
      warningsViewModel: warningsViewModel,
      mapViewModel: MapViewModel(
        stationPoints: stationPoints,
        observations: observations,
        onde: onde,
      ),
      stationSheetViewModel: StationSheetViewModel(
        observations: observations,
        stations: AssetStationRepository(stationsRead.stations),
      ),
      // Le MÊME dépôt ONDE décoré que celui du ViewModel de la carte : le
      // cache est une politique unique, partagée, jamais recopiée par
      // tranche (CLAUDE.md, invariants).
      ondeSheetViewModel: OndeSheetViewModel(onde: onde),
    ),
  );
}

// L'écran carte (T0-M4, complété par la fiche station de T1-U1 et la fiche
// d'un point ONDE de T1-U4) : fond IGN, attribution, marqueurs du viewport
// élargi, et la feuille de résumé au tap d'un marqueur. Les deux fiches ne
// sont jamais ouvertes ensemble — l'exclusivité est garantie par la racine
// de composition ci-dessous, pas par les échelles (relecture 2026-09-14).
//
// Le premier des quatre avertissements (`BR-012`, `UC-006`) est posé depuis
// la tâche `W2` : tant que `warningsViewModel.requiresAcknowledgement` est
// vrai, c'est [InitialWarningView] qui occupe `home`, et [MapView] n'est
// JAMAIS construit — ce n'est pas un `Visibility` ni une superposition, la
// carte et ses dépôts ne sont tout simplement pas atteints. Le contrôle
// d'avertissement partagé (`W3c`, `WarningLink`) remplace le bandeau (`W3`),
// son menu (`W3b`) et l'encart daté (`W4`) ; l'encart renforcé (`BR-013`)
// arrive en T2, `W5` n'en écrit que le texte.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({
    required this.warningsViewModel,
    required this.mapViewModel,
    required this.stationSheetViewModel,
    required this.ondeSheetViewModel,
    super.key,
  });

  /// Le ViewModel de l'écran bloquant du premier lancement, construit et
  /// déjà chargé (`load()` attendu) dans [main] — cette racine le possède
  /// au même titre que les trois autres.
  final WarningsViewModel warningsViewModel;

  /// Le ViewModel de la tranche carte, construit dans [main]. C'est cette
  /// racine qui le possède : il vit aussi longtemps que l'application, et la
  /// vue ne dispose pas un objet dont elle n'est pas propriétaire.
  final MapViewModel mapViewModel;

  /// Le ViewModel de la tranche fiche station, construit dans [main] et
  /// possédé par cette racine, au même titre que [mapViewModel].
  final StationSheetViewModel stationSheetViewModel;

  /// Le ViewModel de la tranche fiche ONDE, construit dans [main] et possédé
  /// par cette racine, au même titre que les deux autres.
  final OndeSheetViewModel ondeSheetViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      // `ListenableBuilder` sur `warningsViewModel` : tant que
      // `requiresAcknowledgement` est vrai, `home` vaut [InitialWarningView]
      // et [MapView] — donc `FlutterMap`, donc tout le reste de
      // l'application — n'est PAS construit (`BR-012`, tâche `W2`). Testé
      // sur la racine sans monter `FlutterMap` :
      // `test/main_test.dart`.
      home: ListenableBuilder(
        listenable: warningsViewModel,
        builder: (BuildContext context, Widget? child) {
          if (warningsViewModel.requiresAcknowledgement) {
            // C'est ce même `ListenableBuilder` qui reconstruit `home` vers
            // la carte dès que `requiresAcknowledgement` bascule à faux —
            // `InitialWarningView` n'a pas de callback à appeler pour cela
            // (YAGNI, CLAUDE.md).
            return InitialWarningView(viewModel: warningsViewModel);
          }
          return MapView(
            viewModel: mapViewModel,
            // `open` rend un `Future` que personne n'attend : l'état de la
            // fiche passe par le ViewModel, pas par ce futur. `unawaited`
            // le dit explicitement plutôt que de le laisser tomber en
            // silence.
            //
            // Les deux fiches ne sont jamais ouvertes ensemble : chaque
            // rappel ferme l'AUTRE fiche avant d'ouvrir la sienne. C'est
            // cette racine de composition qui garantit l'exclusivité — les
            // deux ViewModels s'ignorent l'un l'autre (règle
            // `feature-vers-feature`) et ne peuvent pas se fermer
            // eux-mêmes. Cette garantie n'est, elle, pas verrouillée par un
            // test — seule la garde d'acquittement l'est.
            onStationTap: (StationCode code) {
              ondeSheetViewModel.close();
              unawaited(stationSheetViewModel.open(code));
            },
            // Le panneau est un `ListenableBuilder` sur le ViewModel de la
            // fiche : il se reconstruit seul à chaque changement d'état,
            // sans reconstruire la carte ni ses 4 150 marqueurs.
            stationSheet: ListenableBuilder(
              listenable: stationSheetViewModel,
              builder: (BuildContext context, Widget? child) =>
                  StationSheetPanel(
                    state: stationSheetViewModel.state,
                    onClose: stationSheetViewModel.close,
                  ),
            ),
            // Même câblage pour la fiche ONDE (T1-U4) : la carte ne connaît
            // ni ce ViewModel ni sa tranche — elle reçoit un rappel de tap
            // et un `Widget` (règle `feature-vers-feature`). Symétrique du
            // rappel ci-dessus : ferme la fiche station avant d'ouvrir la
            // fiche ONDE.
            onOndeTap: (OndePoint point) {
              stationSheetViewModel.close();
              unawaited(ondeSheetViewModel.open(point));
            },
            ondeSheet: ListenableBuilder(
              listenable: ondeSheetViewModel,
              builder: (BuildContext context, Widget? child) => OndeSheetPanel(
                state: ondeSheetViewModel.state,
                onClose: ondeSheetViewModel.close,
              ),
            ),
            // `Échap` (`K2`) : ferme la fiche ouverte, qu'elle soit station
            // ou ONDE — cette racine est la seule à connaître les DEUX
            // ViewModels de fiche (règle `feature-vers-feature`), au même
            // titre qu'elle garantit déjà leur exclusivité mutuelle
            // ci-dessus. Fermer une fiche déjà fermée est sans effet
            // observable.
            onCloseSheets: () {
              stationSheetViewModel.close();
              ondeSheetViewModel.close();
            },
          );
        },
      ),
    );
  }
}
