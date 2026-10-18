import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/floods/cached_flood_vigilance_source.dart';
import 'package:martinpecheur/data/floods/vigicrues_endpoint.dart';
import 'package:martinpecheur/data/floods/vigicrues_flood_vigilance_source.dart';
import 'package:martinpecheur/data/http/hub_eau_client.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/data/links/url_launcher_external_link_opener.dart';
import 'package:martinpecheur/data/observations/cached_hydro_observation_repository.dart';
import 'package:martinpecheur/data/observations/http_hydro_observation_repository.dart';
import 'package:martinpecheur/data/onde/cached_onde_observation_repository.dart';
import 'package:martinpecheur/data/onde/http_onde_observation_repository.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_acknowledgement_repository.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_favorite_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/data/restrictions/cached_restriction_source.dart';
import 'package:martinpecheur/data/restrictions/vigieau_restriction_source.dart';
import 'package:martinpecheur/diagnostics/counting_station_point_repository.dart';
import 'package:martinpecheur/diagnostics/fluidity_probe_panel.dart';
import 'package:martinpecheur/diagnostics/fluidity_wiring.dart';
import 'package:martinpecheur/diagnostics/frame_timing_probe.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart'
    show DocumentLink;
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/favorites/view/favorites_screen.dart';
import 'package:martinpecheur/features/favorites/view_model/favorites_view_model.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
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
// tirage de gigue réel n'est injecté que dans les tests. Son délai d'attente
// par tentative (20 s, `hubEauRequestTimeout`) est fixé par `HubEauClient`
// lui-même ; VigiEau, sur `JsonHttpClient`, garde les 10 s de
// `defaultRequestTimeout` (arbitrage du 2026-10-06 au soir).
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
  final StationPointRepository referentielStationPoints =
      AssetStationPointRepository(stationsRead.points);

  // `NFR-01` (Task X3), relecture du 2026-09-23 (🟠 4) : le câblage est
  // extrait dans `wireFluidityProbe`, une fonction PURE testée avec le
  // booléen en paramètre — sans elle, l'inertie sans drapeau n'était
  // vérifiée qu'indirectement, jamais sur ce câblage lui-même. Sans
  // `--dart-define=FLUIDITY_PROBE=true`, `fluidityProbeEnabled` vaut
  // `false` et RIEN ne s'instancie — ni sonde, ni décorateur, ni rappel
  // enregistré auprès de `SchedulerBinding` (« la sonde est inerte sans
  // son drapeau », `CLAUDE.md`).
  final FluidityWiring fluidityWiring = wireFluidityProbe(
    enabled: fluidityProbeEnabled,
    stationPoints: referentielStationPoints,
  );
  final StationPointRepository stationPoints = fluidityWiring.stationPoints;

  final HubEauClient hubEau = HubEauClient(httpClient: http.Client());
  final HydroObservationRepository observations =
      CachedHydroObservationRepository(
        inner: HttpHydroObservationRepository(hubEau),
      );
  final OndeObservationRepository onde = CachedOndeObservationRepository(
    inner: HttpOndeObservationRepository(hubEau),
  );

  // VigiEau (T2, `E3`) : la source n'est nommée qu'ICI (confinement,
  // `test/data/restrictions/restriction_source_test.dart`), sur le transport
  // HTTP partagé `JsonHttpClient`, décorée par la politique de cache. Le
  // ViewModel est de session : le profil d'usager y est gardé (Q2).
  final RestrictionSource restrictionSource = CachedRestrictionSource(
    inner: VigieauRestrictionSource(
      client: JsonHttpClient(httpClient: http.Client()),
    ),
  );

  // Les favoris (T3, `S5`) : UNE SEULE instance du dépôt, passée à tous ceux
  // qui lisent ou écrivent la liste. Il sérialise ses lire-puis-écrire PAR
  // INSTANCE : deux instances croiseraient leurs écritures et perdraient un
  // favori. Verrou : `test/main_test.dart`.
  final FavoriteRepository favorites = SharedPreferencesFavoriteRepository();

  // Vigicrues (T4, `F4`) : la source n'est nommée qu'ICI, hors de
  // `lib/data/floods/` (confinement, `ADR-016` ;
  // `test/data/floods/flood_vocabulary_confinement_test.dart`), décorée par
  // son cache de session de 30 min. Son transport est `vigicruesJsonClient`,
  // qui porte le délai de 20 s par tentative (D4) — jamais un
  // `JsonHttpClient` nu, qui garderait les 10 s par défaut. Verrou :
  // `test/main_test.dart`.
  final FloodVigilanceSource floodVigilanceSource = CachedFloodVigilanceSource(
    inner: VigicruesFloodVigilanceSource(
      client: vigicruesJsonClient(http.Client()),
    ),
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
        favorites: favorites,
      ),
      // Le MÊME dépôt ONDE décoré que celui du ViewModel de la carte : le
      // cache est une politique unique, partagée, jamais recopiée par
      // tranche (CLAUDE.md, invariants).
      // Les favoris : la MÊME instance que celle de la fiche station.
      ondeSheetViewModel: OndeSheetViewModel(onde: onde, favorites: favorites),
      favoritesViewModel: FavoritesViewModel(favorites: favorites),
      // La lecture Crues reste `LectureCruesNonDemandee` au lancement : rien
      // n'est lu avant le choix de la puce « Vigilance crues ».
      floodLayerViewModel: FloodLayerViewModel(source: floodVigilanceSource),
      floodSheetViewModel: FloodSheetViewModel(
        links: const UrlLauncherExternalLinkOpener(),
      ),
      restrictionsViewModel: RestrictionsViewModel(
        source: restrictionSource,
        links: const UrlLauncherExternalLinkOpener(),
      ),
      fluidityProbe: fluidityWiring.probe,
      fluidityStationPoints: fluidityWiring.countingStationPoints,
    ),
  );
}

// L'écran carte (T0-M4, complété par la fiche station de T1-U1 et la fiche
// d'un point ONDE de T1-U4) : fond IGN, attribution, marqueurs du viewport
// élargi, et la feuille de résumé au tap d'un marqueur ; la fiche tronçon
// depuis T4 (`F4`). Les fiches ne sont jamais ouvertes ensemble —
// l'exclusivité est garantie par la racine de composition ci-dessous, pas
// par les échelles (relecture 2026-09-14).
//
// Le premier des quatre avertissements (`BR-012`, `UC-006`) est posé depuis
// la tâche `W2` : tant que `warningsViewModel.requiresAcknowledgement` est
// vrai, c'est [InitialWarningView] qui occupe `home`, et [MapView] n'est
// JAMAIS construit — ce n'est pas un `Visibility` ni une superposition, la
// carte et ses dépôts ne sont tout simplement pas atteints. Le contrôle
// d'avertissement partagé (`W3c`, `WarningLink`) remplace le bandeau (`W3`),
// son menu (`W3b`) et l'encart daté (`W4`) ; l'encart renforcé (`BR-013`)
// arrive en T2, `W5` n'en écrit que le texte.
class MartinPecheurApp extends StatefulWidget {
  const MartinPecheurApp({
    required this.warningsViewModel,
    required this.mapViewModel,
    required this.stationSheetViewModel,
    required this.ondeSheetViewModel,
    required this.restrictionsViewModel,
    required this.favoritesViewModel,
    required this.floodLayerViewModel,
    required this.floodSheetViewModel,
    this.fluidityProbe,
    this.fluidityStationPoints,
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

  /// Le ViewModel de l'écran des restrictions (T2, `E3`), possédé par cette
  /// racine : de session, il garde le profil d'usager. L'écran est une
  /// ROUTE poussée à la désignation d'un point ; son retrait la ferme.
  final RestrictionsViewModel restrictionsViewModel;

  /// Le ViewModel de l'écran « Favoris » (T3, `S11`), possédé par cette
  /// racine, sur la MÊME instance du dépôt que les deux fiches. L'écran est
  /// une ROUTE poussée par le bouton « Favoris » de la carte ; son retrait la
  /// ferme.
  final FavoritesViewModel favoritesViewModel;

  /// Le second ViewModel de l'écran carte (T4, `L2`, arbitrage 7) : la
  /// lecture Crues, possédée par cette racine au même titre que
  /// [mapViewModel]. Passé à `MapView`, qui le prévient ; aucun ViewModel
  /// n'importe l'autre.
  final FloodLayerViewModel floodLayerViewModel;

  /// Le ViewModel de la fiche tronçon (T4, `F1`), possédé par cette racine,
  /// au même titre que les deux autres fiches, et soumis à la même
  /// exclusivité.
  final FloodSheetViewModel floodSheetViewModel;

  /// `NFR-01` (Task X3) : `null` sans `--dart-define=FLUIDITY_PROBE=true`
  /// (« la sonde est inerte sans son drapeau », `CLAUDE.md`) — dans ce cas
  /// [FluidityProbePanel] n'est pas construit du tout, l'écran carte est
  /// rendu à l'identique de la production.
  final FrameTimingProbe? fluidityProbe;

  /// Le décorateur de comptage câblé par [main] derrière le même drapeau
  /// que [fluidityProbe] — `null` si et seulement si [fluidityProbe] l'est
  /// aussi (les deux sont posés ou retirés ensemble par [main]).
  final CountingStationPointRepository? fluidityStationPoints;

  @override
  State<MartinPecheurApp> createState() => _MartinPecheurAppState();
}

// L'état de la racine porte le contrôleur du défilement du CORPS des fiches —
// passé aux trois panneaux, dont le cadre défile son corps sous l'en-tête
// épinglé (`D5` d'Ergonomie) — et l'écoute qui le remet à zéro (`K4` de T3),
// et, depuis `F4` de T4, l'écoute qui ferme la fiche tronçon en quittant la
// lecture Crues.
//
// La règle : toute ouverture de fiche, d'où qu'elle vienne, montre la fiche
// depuis son haut. Sans cela, la position de défilement survit au changement
// de fiche quand la donnée est en cache — `open()` émet « en cours » puis
// « prête » sans trame entre les deux, et la nouvelle fiche s'ouvre sur son
// bas. `buildMapOverlays` ignore quand la fiche change, et les deux tranches
// de fiche s'ignorent (règle `feature-vers-feature`) : seule cette racine
// connaît les deux ViewModels. Elle écoute donc leur passage à « en cours »,
// que `open()` émet de façon SYNCHRONE, avant toute attente — un seul
// endroit pour toutes les entrées, le tap d'un marqueur comme les autres.
//
// Rien d'autre ne déplace la fiche. Un ViewModel de fiche notifie aussi sans
// changer d'état — la réponse du dépôt des favoris, une bascule de favori —,
// y compris PENDANT « en cours » (une station déjà en favori y porte une
// étoile pleine, active). L'écoute garde donc le dernier état vu de chaque
// ViewModel et ne remet à zéro que si l'état a CHANGÉ et qu'il est « en
// cours » : chaque `open()` construit une instance neuve de cet état, une
// réouverture du même lieu se voit donc aussi.
//
// La fiche tronçon (`F4` de T4) suit la même règle. Elle n'a pas d'état
// « en cours » — tout est déjà dans le tronçon touché — : une ouverture est
// le passage à un état ouvert NEUF, sans échec de lien compté. L'échec
// d'ouverture du bulletin rend lui aussi un état ouvert neuf (l'avis se
// réannonce), mais ce n'est pas une ouverture : la ramener en haut cacherait
// l'avis, posé en bas de la fiche.
//
// Une seconde écoute, sur [MapViewModel] (D8), ferme la fiche tronçon quand
// l'usager QUITTE la lecture Crues (cadrage § 8) — au changement d'échelle,
// pas à chaque notification : un geste, un préchargement notifient sans
// changer d'échelle et laissent la fiche ouverte. La dernière échelle vue est
// gardée, et comparée par `switch` exhaustif, jamais par `==` : une échelle
// ajoutée sans branche ne compile pas (`BR-011`).
class _MartinPecheurAppState extends State<MartinPecheurApp> {
  // Ce contrôleur peut porter deux positions le temps d'une trame (l'ancien
  // cadre et le nouveau) : n'y lire jamais `.position` ni `.offset`.
  final ScrollController _sheetScrollController = ScrollController();

  /// Le dernier état vu de chaque ViewModel de fiche, comparé par identité.
  late StationSheetState _lastStationSheetState;
  late OndeSheetState _lastOndeSheetState;
  late FloodSheetState _lastFloodSheetState;

  /// La dernière échelle vue de [MartinPecheurApp.mapViewModel].
  late MapScaleKind _lastScale;

  @override
  void initState() {
    super.initState();
    _lastStationSheetState = widget.stationSheetViewModel.state;
    _lastOndeSheetState = widget.ondeSheetViewModel.state;
    _lastFloodSheetState = widget.floodSheetViewModel.state;
    _lastScale = widget.mapViewModel.scale;
    widget.stationSheetViewModel.addListener(_onStationSheetChanged);
    widget.ondeSheetViewModel.addListener(_onOndeSheetChanged);
    widget.floodSheetViewModel.addListener(_onFloodSheetChanged);
    widget.mapViewModel.addListener(_onMapChanged);
  }

  @override
  void didUpdateWidget(MartinPecheurApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.stationSheetViewModel,
      widget.stationSheetViewModel,
    )) {
      oldWidget.stationSheetViewModel.removeListener(_onStationSheetChanged);
      _lastStationSheetState = widget.stationSheetViewModel.state;
      widget.stationSheetViewModel.addListener(_onStationSheetChanged);
    }
    if (!identical(oldWidget.ondeSheetViewModel, widget.ondeSheetViewModel)) {
      oldWidget.ondeSheetViewModel.removeListener(_onOndeSheetChanged);
      _lastOndeSheetState = widget.ondeSheetViewModel.state;
      widget.ondeSheetViewModel.addListener(_onOndeSheetChanged);
    }
    if (!identical(oldWidget.floodSheetViewModel, widget.floodSheetViewModel)) {
      oldWidget.floodSheetViewModel.removeListener(_onFloodSheetChanged);
      _lastFloodSheetState = widget.floodSheetViewModel.state;
      widget.floodSheetViewModel.addListener(_onFloodSheetChanged);
    }
    if (!identical(oldWidget.mapViewModel, widget.mapViewModel)) {
      oldWidget.mapViewModel.removeListener(_onMapChanged);
      _lastScale = widget.mapViewModel.scale;
      widget.mapViewModel.addListener(_onMapChanged);
    }
  }

  // Les ViewModels ne sont PAS disposés ici : ils sont construits dans
  // [main] et vivent aussi longtemps que l'application. Seuls les écoutes et
  // le contrôleur, créés par cet état, sont rendus.
  @override
  void dispose() {
    widget.stationSheetViewModel.removeListener(_onStationSheetChanged);
    widget.ondeSheetViewModel.removeListener(_onOndeSheetChanged);
    widget.floodSheetViewModel.removeListener(_onFloodSheetChanged);
    widget.mapViewModel.removeListener(_onMapChanged);
    _sheetScrollController.dispose();
    super.dispose();
  }

  void _onStationSheetChanged() {
    final StationSheetState state = widget.stationSheetViewModel.state;
    final bool opening =
        state is EnCours && !identical(state, _lastStationSheetState);
    _lastStationSheetState = state;
    if (opening) {
      _showSheetFromTop();
    }
  }

  void _onOndeSheetChanged() {
    final OndeSheetState state = widget.ondeSheetViewModel.state;
    final bool opening =
        state is OndeSheetEnCours && !identical(state, _lastOndeSheetState);
    _lastOndeSheetState = state;
    if (opening) {
      _showSheetFromTop();
    }
  }

  void _onFloodSheetChanged() {
    final FloodSheetState state = widget.floodSheetViewModel.state;
    final bool opening = switch (state) {
      FicheTronconOuverte(unopenedBulletinCount: 0) => !identical(
        state,
        _lastFloodSheetState,
      ),
      FicheTronconOuverte() => false,
      FicheTronconFermee() => false,
    };
    _lastFloodSheetState = state;
    if (opening) {
      _showSheetFromTop();
    }
  }

  void _onMapChanged() {
    final MapScaleKind scale = widget.mapViewModel.scale;
    final bool leftFloodReading = _leavesFloodReading(_lastScale, scale);
    final bool enteredFloodReading = _entersFloodReading(_lastScale, scale);
    _lastScale = scale;
    if (leftFloodReading) {
      widget.floodSheetViewModel.close();
    }
    // Arbitrage du commanditaire du 2026-10-15 (« Fiches Crues ») : entrer
    // sur la lecture Crues ferme les fiches station et ONDE.
    if (enteredFloodReading) {
      widget.stationSheetViewModel.close();
      widget.ondeSheetViewModel.close();
    }
  }

  /// Vrai si l'échelle passe de [MapScaleKind.crues] à une autre.
  static bool _leavesFloodReading(MapScaleKind before, MapScaleKind after) =>
      switch (before) {
        MapScaleKind.crues => switch (after) {
          MapScaleKind.crues => false,
          MapScaleKind.ecoulement => true,
          MapScaleKind.debit => true,
        },
        MapScaleKind.ecoulement => false,
        MapScaleKind.debit => false,
      };

  /// Vrai si l'échelle passe d'une autre à [MapScaleKind.crues] : le
  /// symétrique de [_leavesFloodReading].
  static bool _entersFloodReading(MapScaleKind before, MapScaleKind after) =>
      _leavesFloodReading(after, before);

  /// Sur la lecture Crues seulement, passe sur [reading] — la lecture du
  /// favori ouvert (arbitrage du commanditaire du 2026-10-15). Sur les deux
  /// autres échelles, rien ne change (arbitrage 6 du cadrage de T3).
  void _leaveFloodReadingFor(MapScaleKind reading) {
    switch (widget.mapViewModel.scale) {
      case MapScaleKind.crues:
        widget.mapViewModel.selectScale(reading);
      case MapScaleKind.ecoulement:
      case MapScaleKind.debit:
        break;
    }
  }

  /// Sans client, aucun corps de fiche n'est à l'écran (aucune fiche ouverte,
  /// ou l'avertissement initial non acquitté) : il n'y a rien à ramener, et
  /// le cadre de la fiche qui s'ouvre part de son haut. Passer à une fiche
  /// d'une autre nature recrée son cadre, qui part lui aussi de son haut ; deux
  /// fiches de même nature gardent le leur, d'où ce `jumpTo(0)`.
  void _showSheetFromTop() {
    if (_sheetScrollController.hasClients) {
      _sheetScrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WarningsViewModel warningsViewModel = widget.warningsViewModel;
    final MapViewModel mapViewModel = widget.mapViewModel;
    final StationSheetViewModel stationSheetViewModel =
        widget.stationSheetViewModel;
    final OndeSheetViewModel ondeSheetViewModel = widget.ondeSheetViewModel;
    final RestrictionsViewModel restrictionsViewModel =
        widget.restrictionsViewModel;
    final FavoritesViewModel favoritesViewModel = widget.favoritesViewModel;
    final FloodLayerViewModel floodLayerViewModel = widget.floodLayerViewModel;
    final FloodSheetViewModel floodSheetViewModel = widget.floodSheetViewModel;
    final FrameTimingProbe? fluidityProbe = widget.fluidityProbe;
    final CountingStationPointRepository? fluidityStationPoints =
        widget.fluidityStationPoints;
    return MaterialApp(
      title: 'MartinPêcheur',
      // Textes intégrés de Material en français (« Retour » du `BackButton`).
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('fr')],
      locale: const Locale('fr'),
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
          final Widget mapScreen = MapView(
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
            // eux-mêmes. Cette garantie est verrouillée par un test pour
            // l'ouverture d'un favori, qui passe par le même chemin (`S11` de
            // T3, `test/main_test.dart`), et pour les deux rappels de tap
            // ci-dessous (`K4` de T3).
            //
            // Depuis `F4` de T4, trois fiches : chaque entrée ferme aussi la
            // fiche tronçon, et le toucher d'un tronçon ferme les deux autres
            // (cadrage § 8, Review Focus 5, `test/main_test.dart`).
            onStationTap: (StationCode code) {
              ondeSheetViewModel.close();
              floodSheetViewModel.close();
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
                    favoriteStar: stationSheetViewModel.favoriteStar,
                    onToggleFavorite: () =>
                        unawaited(stationSheetViewModel.toggleFavorite()),
                    // `K4` de T3, `D5` d'Ergonomie : le corps du cadre défile
                    // sous ce contrôleur, remis à zéro à chaque ouverture.
                    bodyScrollController: _sheetScrollController,
                  ),
            ),
            // Même câblage pour la fiche ONDE (T1-U4) : la carte ne connaît
            // ni ce ViewModel ni sa tranche — elle reçoit un rappel de tap
            // et un `Widget` (règle `feature-vers-feature`). Symétrique du
            // rappel ci-dessus : ferme la fiche station avant d'ouvrir la
            // fiche ONDE.
            onOndeTap: (OndePoint point) {
              stationSheetViewModel.close();
              floodSheetViewModel.close();
              unawaited(ondeSheetViewModel.open(point));
            },
            ondeSheet: ListenableBuilder(
              listenable: ondeSheetViewModel,
              builder: (BuildContext context, Widget? child) => OndeSheetPanel(
                state: ondeSheetViewModel.state,
                onClose: ondeSheetViewModel.close,
                favoriteStar: ondeSheetViewModel.favoriteStar,
                onToggleFavorite: () =>
                    unawaited(ondeSheetViewModel.toggleFavorite()),
                // `D5` d'Ergonomie, spec § 6.3, `PD8` : le symbole de la
                // catégorie, FOURNI par cette racine — la fiche ONDE n'importe
                // pas la tranche carte (`feature-vers-feature`). En grand, dans
                // la tuile, le symbole du marqueur ; en petit, sur chaque
                // ligne d'historique, celui de la légende. Une campagne
                // récente (`CampaignAge.recente`) : la couleur de la catégorie,
                // jamais le gris d'une campagne ancienne, qu'aucun lieu ne
                // date ici (`observedAt: null`, comme la légende) ; exclu des
                // annonces, le texte de la fiche dit déjà la catégorie.
                categorySymbol:
                    (FlowCategory category, {required bool compact}) =>
                        ExcludeSemantics(
                          child: OndeMarkerShape(
                            category: category,
                            age: CampaignAge.recente,
                            observedAt: null,
                            compact: compact,
                          ),
                        ),
                bodyScrollController: _sheetScrollController,
              ),
            ),
            // La lecture Crues (T4, `M5`) et la fiche tronçon (`F4`) : le
            // ViewModel de la lecture, le rappel du toucher d'un tronçon et
            // le panneau vont ensemble (assert de `MapView`). Ouvrir la fiche
            // ne lit rien : le tronçon et la date de la carte lue suffisent
            // (cadrage § 8). Le panneau se pose dans la zone des fiches, sous
            // les deux autres.
            floodLayer: floodLayerViewModel,
            onFloodSectionTap: (FloodSection section, DateTime date) {
              stationSheetViewModel.close();
              ondeSheetViewModel.close();
              floodSheetViewModel.open(section, date);
            },
            floodSheet: ListenableBuilder(
              listenable: floodSheetViewModel,
              builder: (BuildContext context, Widget? child) => FloodSheetPanel(
                state: floodSheetViewModel.state,
                onClose: floodSheetViewModel.close,
                onOpenBulletin: () =>
                    unawaited(floodSheetViewModel.openBulletin()),
                bodyScrollController: _sheetScrollController,
              ),
            ),
            // `Échap` (`K2`) : ferme la fiche ouverte, qu'elle soit station,
            // ONDE ou tronçon — cette racine est la seule à connaître les
            // ViewModels de fiche (règle `feature-vers-feature`), au même
            // titre qu'elle garantit déjà leur exclusivité mutuelle
            // ci-dessus. Fermer une fiche déjà fermée est sans effet
            // observable.
            onCloseSheets: () {
              stationSheetViewModel.close();
              ondeSheetViewModel.close();
              floodSheetViewModel.close();
            },
            // Désignation d'un point (`E1`) : ferme les fiches, lance la
            // requête et pousse l'écran plein des restrictions (arbitrage
            // C1, Q-1). Le retrait de la route — bouton de retour, `Échap`,
            // retour Android — ferme le ViewModel : une réponse tardive
            // n'écrit alors plus rien. L'épingle reste tenue par la vue
            // carte (Q-2b).
            onPointDesignated: (GeoPoint point) {
              stationSheetViewModel.close();
              ondeSheetViewModel.close();
              floodSheetViewModel.close();
              // L'écran est ouvert tant que le ViewModel n'est pas fermé (il
              // ne l'est qu'au retrait de la route, ci-dessous) : une
              // nouvelle désignation ne fait alors que relancer la requête,
              // sans empiler une seconde route dont le retrait fermerait le
              // ViewModel sous l'écran encore affiché.
              final bool screenOpen =
                  restrictionsViewModel.state is! RestrictionsFermees;
              unawaited(restrictionsViewModel.open(point));
              if (screenOpen) {
                return;
              }
              // Ce que CETTE route affiche, retenu pour sa durée de vie : le
              // futur de `push` se complète à l'appel de `pop`, avant
              // l'animation de sortie. `close()` vide alors le ViewModel
              // (verrou contre une réponse tardive) pendant que la route est
              // encore à l'écran — elle garde, elle, ce qu'elle affichait.
              // `leaving` est posé au retrait, juste avant `close()` : dès
              // lors la route ne met plus rien à jour. La carte dessous reçoit
              // les gestes pendant la sortie : une nouvelle désignation
              // relance le ViewModel, et c'est la NOUVELLE route qui cherche —
              // pas celle qui s'en va.
              RestrictionsState shownState = restrictionsViewModel.state;
              UnopenedLink? shownUnopenedLink =
                  restrictionsViewModel.unopenedLink;
              bool leaving = false;
              unawaited(
                Navigator.of(context)
                    .push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => ListenableBuilder(
                          listenable: restrictionsViewModel,
                          builder: (BuildContext context, Widget? child) {
                            if (!leaving) {
                              shownState = restrictionsViewModel.state;
                              shownUnopenedLink =
                                  restrictionsViewModel.unopenedLink;
                            }
                            return RestrictionsScreen(
                              state: shownState,
                              profile: restrictionsViewModel.profile,
                              onChooseProfile:
                                  restrictionsViewModel.chooseProfile,
                              onRetry: () =>
                                  unawaited(restrictionsViewModel.retry()),
                              onOpenDocument:
                                  (DocumentLink link, LinkTarget target) =>
                                      unawaited(
                                        restrictionsViewModel.openDocument(
                                          link,
                                          target,
                                        ),
                                      ),
                              onOpenPublicSite: () => unawaited(
                                restrictionsViewModel.openPublicSite(),
                              ),
                              unopenedLink: shownUnopenedLink,
                            );
                          },
                        ),
                      ),
                    )
                    .then((_) {
                      leaving = true;
                      restrictionsViewModel.close();
                    }),
              );
            },
            // Le bouton « Favoris » (`S11` de T3) : ferme les fiches,
            // relit le dépôt et pousse l'écran plein des favoris. Même
            // construction que la route des restrictions ci-dessus : une
            // garde contre une seconde route, ce que la route montre retenu
            // pendant sa sortie, et son retrait qui ferme le ViewModel.
            onOpenFavorites: () {
              stationSheetViewModel.close();
              ondeSheetViewModel.close();
              floodSheetViewModel.close();
              // L'écran est ouvert tant que le ViewModel n'est pas fermé (il
              // ne l'est qu'au retrait de la route) : un second appel ne fait
              // alors que relire la liste, sans empiler une seconde route
              // dont le retrait fermerait le ViewModel sous l'écran encore
              // affiché. Lu AVANT `load()`, qui quitte « fermés » de façon
              // synchrone.
              final bool screenOpen =
                  favoritesViewModel.state is! FavorisFermes;
              unawaited(favoritesViewModel.load());
              if (screenOpen) {
                return;
              }
              FavoritesState shownState = favoritesViewModel.state;
              bool shownBusy = favoritesViewModel.busy;
              bool shownWriteFailed = favoritesViewModel.writeFailed;
              bool leaving = false;
              unawaited(
                Navigator.of(context)
                    .push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext routeContext) =>
                            ListenableBuilder(
                              listenable: favoritesViewModel,
                              builder: (BuildContext context, Widget? child) {
                                if (!leaving) {
                                  shownState = favoritesViewModel.state;
                                  shownBusy = favoritesViewModel.busy;
                                  shownWriteFailed =
                                      favoritesViewModel.writeFailed;
                                }
                                return FavoritesScreen(
                                  state: shownState,
                                  busy: shownBusy,
                                  writeFailed: shownWriteFailed,
                                  onRemove: (Favorite favorite) => unawaited(
                                    favoritesViewModel.remove(favorite),
                                  ),
                                  onStartOver: () =>
                                      unawaited(favoritesViewModel.startOver()),
                                  // Ouvrir un favori : la route se retire,
                                  // puis la fiche s'ouvre par le chemin d'un
                                  // tap de marqueur — l'autre fiche fermée
                                  // d'abord. Hors de la lecture Crues, AUCUN
                                  // appel à `mapViewModel` : ni la caméra, ni
                                  // l'échelle, ni le filtre ne changent
                                  // (arbitrage 6 du cadrage de T3), une fiche
                                  // ONDE s'ouvre donc aussi sur l'échelle
                                  // débit. Sur la lecture Crues seulement
                                  // (arbitrage du commanditaire du
                                  // 2026-10-15, « Fiches Crues »), le favori
                                  // passe d'abord sur sa lecture — Débit pour
                                  // une station, Écoulement pour un point
                                  // ONDE —, AVANT l'ouverture de sa fiche :
                                  // `_onMapChanged`, qui ferme les fiches à
                                  // l'entrée sur Crues, ne la referme donc
                                  // pas.
                                  onOpen: (Favorite favorite) {
                                    // Une seconde activation avant la trame
                                    // suivante ne retire rien : `pop()` rend
                                    // `isCurrent` faux de façon synchrone, et
                                    // un second `pop()` retirerait la route
                                    // de la CARTE.
                                    if (ModalRoute.of(routeContext)
                                            ?.isCurrent !=
                                        true) {
                                      return;
                                    }
                                    Navigator.of(routeContext).pop();
                                    switch (favorite) {
                                      case StationFavorite(
                                        :final StationCode code,
                                      ):
                                        _leaveFloodReadingFor(
                                          MapScaleKind.debit,
                                        );
                                        ondeSheetViewModel.close();
                                        floodSheetViewModel.close();
                                        unawaited(
                                          stationSheetViewModel.open(code),
                                        );
                                      case OndePointFavorite(
                                        :final OndePoint point,
                                      ):
                                        _leaveFloodReadingFor(
                                          MapScaleKind.ecoulement,
                                        );
                                        stationSheetViewModel.close();
                                        floodSheetViewModel.close();
                                        unawaited(
                                          ondeSheetViewModel.open(point),
                                        );
                                      // Une entrée non lisible ne s'ouvre pas
                                      // (`BR-011`) : l'écran ne la propose
                                      // d'ailleurs pas.
                                      case UnreadableFavorite():
                                        break;
                                    }
                                  },
                                );
                              },
                            ),
                      ),
                    )
                    .then((_) {
                      leaving = true;
                      favoritesViewModel.close();
                    }),
              );
            },
          );

          // `NFR-01` (Task X3) : le panneau ne se pose que si [main] a
          // câblé les deux, ce qu'il ne fait QUE derrière
          // `--dart-define=FLUIDITY_PROBE=true` — sans le drapeau, l'écran
          // carte reste `mapScreen` seul, identique à la production.
          final FrameTimingProbe? probe = fluidityProbe;
          final CountingStationPointRepository? probeStationPoints =
              fluidityStationPoints;
          if (probe == null || probeStationPoints == null) {
            return mapScreen;
          }
          return Stack(
            children: <Widget>[
              mapScreen,
              fluidityProbeOverlay(
                probe: probe,
                stationPoints: probeStationPoints,
              ),
            ],
          );
        },
      ),
    );
  }
}
