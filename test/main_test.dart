// Verrouille la racine de composition (`lib/main.dart`, `MartinPecheurApp`)
// sur la garde de l'avertissement initial (`BR-012`, `UC-006`, tâche `W2`) :
// tant que `WarningsViewModel.requiresAcknowledgement` est vrai, la carte —
// donc `FlutterMap` — n'est PAS construite ; un usager déjà acquitté ne voit
// JAMAIS `InitialWarningView`, pas même une image, dès le tout premier
// `pump()`.
//
// Aucun test ici n'appelle `main()` : `main()` charge un asset, ouvre des
// clients HTTP et construit `SharedPreferencesAcknowledgementRepository`
// (`lib/data/…`), tout ce que ce fichier de test n'a pas à réaliser pour
// vérifier la garde. `MartinPecheurApp` est construit directement, avec des
// dépôts en mémoire — même style que
// `test/features/map/view/map_view_test.dart`.
//
// ⚠️ Ce fichier importe `lib/data/…` (les dépôts vides ci-dessous). C'est
// permis : `test/architecture/layers_test.dart` (règle `features-vers-data`)
// contraint `lib/`, pas `test/`.
import 'dart:async' show Completer;
import 'dart:io' show File;
import 'dart:ui' show Rect, Size;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart'
    show
        Checkbox,
        SelectableText,
        Element,
        Navigator,
        RenderObject,
        ScrollController,
        ScrollPosition,
        Scrollable,
        ScrollableState,
        Semantics,
        SingleChildScrollView,
        Text,
        ValueKey;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart'
    show Favorite, OndePointFavorite, StationFavorite;
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart'
    show floodBulletinUri, restrictionsPublicSiteUrl;
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/favorites/view/favorites_screen.dart';
import 'package:martinpecheur/features/favorites/view_model/favorites_view_model.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_sheet_panel.dart'
    show FloodSheetPanel, floodBulletinButtonKey;
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart'
    show
        DesignationBand,
        mapDesignateCenterButtonKey,
        mapDesignateCenterHintKey;
import 'package:martinpecheur/features/map/view/map_center_reticle.dart'
    show mapCenterReticleKey;
import 'package:martinpecheur/features/map/view/map_controls.dart'
    show mapRecenterButtonKey;
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart'
    show mapFavoritesButtonKey, mapFiltersActiveMarkKey, mapFiltersButtonKey;
import 'package:martinpecheur/features/map/view/map_reading_selector.dart'
    show mapDesignationChipKey;
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart'
    show OndeMarkerShape;
import 'package:martinpecheur/features/map/view/station_marker.dart'
    show compactMarkerSize, stationMarkerSize;
import 'package:martinpecheur/features/map/view_model/flood_layer_view_model.dart'
    show FloodLayerViewModel, LectureCruesNonDemandee;
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view/onde_summary_sheet.dart'
    show OndeSheetPanel, ondeCategoryTileKey;
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/data_sources_view.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart'
    show favoriteRemoveFailedText, favoriteStarButtonKey;
import 'package:martinpecheur/features/shared/sheet_frame.dart'
    show sheetFrameBodyKey, sheetFrameHeaderKey;
import 'package:martinpecheur/features/shared/warning_link.dart'
    show warningLinkKey, warningWindowRegionKey, warningWindowSourcesLinkKey;
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart'
    show StationSheetPanel;
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';
import 'package:martinpecheur/features/warnings/view/initial_warning_view.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';
import 'package:martinpecheur/main.dart';

import 'features/restrictions/zones_samples.dart';
import 'support/android_platform.dart';
import 'support/in_memory_favorite_repository.dart';
import 'support/in_memory_follow_up_repository.dart';
import 'support/windows_platform.dart';

/// Dépôts vides, juste assez pour CONSTRUIRE les trois autres ViewModels :
/// aucun de ces tests n'attend leur chargement, seule la garde
/// d'acquittement est vérifiée. Même doubles que
/// `test/features/map/view/map_view_test.dart`.
final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

final class _EmptyHydroObservationRepository
    implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

final class _EmptyOndeObservationRepository
    implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async =>
      const OndeSweep(observations: <OndeObservation>[], unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

final class _EmptyStationRepository implements StationRepository {
  @override
  Future<Station?> findByCode(StationCode code) async => null;
}

/// Une station du référentiel : celle des fixtures, `K447001001`.
final class _BloisStationRepository implements StationRepository {
  @override
  Future<Station?> findByCode(StationCode code) async => Station(
    code: code,
    label: 'La Loire à Blois',
    latitude: 47.584957074,
    longitude: 1.335147948,
    departement: DepartementCode('41'),
    riverLabel: 'la Loire',
    inService: true,
  );
}

/// Un référentiel qui ne répond pas : la fiche station reste « en cours ».
final class _PendingStationRepository implements StationRepository {
  @override
  Future<Station?> findByCode(StationCode code) => Completer<Station?>().future;
}

/// Une source ONDE dont l'historique ne répond pas : la fiche ONDE reste
/// « en cours ». Le balayage de la carte, lui, répond vide.
final class _PendingOndeObservationRepository
    implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async =>
      const OndeSweep(observations: <OndeObservation>[], unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) => Completer<List<OndeObservation>>().future;
}

/// Une source ONDE dont l'historique répond sans attente : trois campagnes
/// du point demandé, la plus récente en tête (`D5` d'Ergonomie, le symbole
/// fourni à la fiche ONDE).
final class _HistoryOndeObservationRepository
    implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async =>
      const OndeSweep(observations: <OndeObservation>[], unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async {
    final OndePoint point = OndePoint(
      code: station,
      label: 'LA RIVIERE AUX LOCHES A CHAON',
      latitude: 47.610620493,
      longitude: 2.173858157,
      waterCourseLabel: 'ruisseau la rivière aux loches',
      departement: null,
    );
    OndeObservation campagne(
      DateTime date,
      FlowCategory category,
      String code,
      String label,
    ) => OndeObservation(
      station: station,
      point: point,
      observedAt: date,
      category: category,
      rawFlowCode: code,
      officialLabel: label,
      campaignCode: '1',
    );
    return <OndeObservation>[
      campagne(DateTime.utc(2026, 9, 25), const Assec(), '3', 'Assec'),
      campagne(
        DateTime.utc(2026, 8, 25),
        const EcoulementNonVisible(),
        '2',
        'Ecoulement non visible',
      ),
      campagne(
        DateTime.utc(2026, 7, 25),
        const Ecoulement(),
        '1',
        'Ecoulement visible',
      ),
    ];
  }
}

/// Double de [AcknowledgementRepository], programmable en lecture — même
/// style que `test/features/warnings/view_model/warnings_view_model_test.dart`.
final class _AcknowledgementRepositoryDouble
    implements AcknowledgementRepository {
  _AcknowledgementRepositoryDouble({
    this.storedVersion,
    this.readError,
    this.writeError,
  });

  final String? storedVersion;

  /// Levée par [readAcknowledgedVersion] si non nulle — simule un stockage
  /// illisible (`WarningsViewModel.load()` rebloque sans planter).
  final Object? readError;

  /// Levée par [writeAcknowledgedVersion] si non nulle — simule un echec
  /// d'ecriture (`UC-006 A6`, arbitrage du 2026-09-22).
  final Object? writeError;

  @override
  Future<String?> readAcknowledgedVersion() async {
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return storedVersion;
  }

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
  }
}

/// Source de restrictions dont chaque reponse est tenue par un `Completer` :
/// un test decide quand (et si) la reponse arrive.
final class _PendingRestrictionSource implements RestrictionSource {
  final List<GeoPoint> requested = <GeoPoint>[];
  final List<Completer<ZonesAtPoint>> completers = <Completer<ZonesAtPoint>>[];

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) {
    requested.add(point);
    final Completer<ZonesAtPoint> completer = Completer<ZonesAtPoint>();
    completers.add(completer);
    return completer.future;
  }
}

final class _NeverOpensLinks implements ExternalLinkOpener {
  @override
  Future<bool> open(Uri uri) async => false;
}

RestrictionsViewModel _restrictions([RestrictionSource? source]) =>
    RestrictionsViewModel(
      source: source ?? _PendingRestrictionSource(),
      links: _NeverOpensLinks(),
    );

/// Source de vigilance crues qui compte ses appels et ne répond jamais : la
/// lecture Crues reste « en cours » si elle est demandée. Aucun appel réseau.
final class _CountingFloodSource implements FloodVigilanceSource {
  int calls = 0;

  @override
  Future<FloodVigilanceMap> current() {
    calls++;
    return Completer<FloodVigilanceMap>().future;
  }
}

/// Le retour de la route poussée, comme `WidgetTester.pageBack` — qui cherche
/// l'info-bulle anglaise « Back » — mais sur l'info-bulle française de la
/// racine (`L1` d'Ergonomie).
Future<void> _retour(WidgetTester tester) async {
  final Finder retour = find.byTooltip('Retour');
  expect(retour, findsOneWidget, reason: 'un seul retour à l\'écran');
  await tester.tap(retour);
}

/// La fiche tronçon de la racine, sur des dépôts en mémoire : comme la racine,
/// elle partage le dépôt des favoris de l'appelant (T5, `V1`).
FloodSheetViewModel _floodSheet({InMemoryFavoriteRepository? favorites}) =>
    FloodSheetViewModel(
      links: _NeverOpensLinks(),
      favorites: favorites ?? InMemoryFavoriteRepository(),
      followUps: InMemoryFollowUpRepository(),
    );

MartinPecheurApp _app(
  WarningsViewModel warningsViewModel, [
  RestrictionsViewModel? restrictionsViewModel,
  StationSheetViewModel? stationSheetViewModel,
  OndeSheetViewModel? ondeSheetViewModel,
  FavoritesViewModel? favoritesViewModel,
  MapViewModel? mapViewModel,
  FloodLayerViewModel? floodLayerViewModel,
  FloodSheetViewModel? floodSheetViewModel,
]) {
  // Comme la racine : UN dépôt des favoris, partagé par les deux fiches et
  // par l'écran « Favoris ».
  final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository();
  return MartinPecheurApp(
    warningsViewModel: warningsViewModel,
    floodLayerViewModel:
        floodLayerViewModel ??
        FloodLayerViewModel(source: _CountingFloodSource()),
    floodSheetViewModel:
        floodSheetViewModel ?? _floodSheet(favorites: favorites),
    restrictionsViewModel: restrictionsViewModel ?? _restrictions(),
    favoritesViewModel:
        favoritesViewModel ?? FavoritesViewModel(favorites: favorites),
    mapViewModel:
        mapViewModel ??
        MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        ),
    stationSheetViewModel:
        stationSheetViewModel ??
        StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _EmptyStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        ),
    ondeSheetViewModel:
        ondeSheetViewModel ??
        OndeSheetViewModel(
          onde: _EmptyOndeObservationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        ),
  );
}

/// Ce que les cas de `K4` tiennent de la racine montée : les deux VRAIS
/// ViewModels de fiche et le dépôt des favoris qu'ils partagent.
typedef _SheetsRoot = ({
  StationSheetViewModel station,
  OndeSheetViewModel onde,
  InMemoryFavoriteRepository favorites,
});

/// Ce que les cas de `S11` tiennent de la racine montée : les VRAIS
/// ViewModels, et le dépôt des favoris que trois d'entre eux partagent.
typedef _FavoritesRoot = ({
  InMemoryFavoriteRepository favorites,
  StationSheetViewModel station,
  OndeSheetViewModel onde,
  FavoritesViewModel list,
  MapViewModel map,
});

/// Ce que les cas de `F4` de T4 tiennent de la racine montée : les VRAIS
/// ViewModels, le dépôt des favoris partagé et la source de vigilance.
typedef _FloodRoot = ({
  InMemoryFavoriteRepository favorites,
  StationSheetViewModel station,
  OndeSheetViewModel onde,
  FavoritesViewModel list,
  MapViewModel map,
  FloodLayerViewModel floodLayer,
  FloodSheetViewModel floodSheet,
  _CountingFloodSource source,
});

/// Un tronçon construit pour ces tests (niveau vert, observé en production) :
/// la fiche tronçon ne lit que lui et la date de la carte, aucun réseau.
FloodSection _troncon(String code) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon de test $code',
  territoryCode: '8',
  level: const Vert(),
  lines: <List<GeoPoint>>[
    <GeoPoint>[
      GeoPoint(latitude: 47.4, longitude: 0.6),
      GeoPoint(latitude: 47.4, longitude: 0.8),
    ],
  ],
);

/// La date de la carte de vigilance des cas de `F4`.
final DateTime _floodDate = DateTime.utc(2026, 10, 14, 13, 55, 31);

/// Le défilement du corps de la fiche ouverte (`D5` d'Ergonomie) : celui du
/// cadre commun (`SheetFrame`), sous son en-tête épinglé. La zone des fiches
/// ne défile plus ; une seule fiche est ouverte à la fois. Le premier
/// défilement sous le corps est le sien (la fiche tronçon en porte d'autres,
/// plus bas).
Finder _sheetBodyScrollable() => find
    .descendant(
      of: find.byKey(sheetFrameBodyKey),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition _sheetBodyPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_sheetBodyScrollable()).position;

/// Fait défiler le corps de la fiche ouverte au bout et rend la position
/// atteinte ; l'en-tête, lui, reste en place (spec § 9, critère 10).
Future<double> _scrollSheetBodyToEnd(WidgetTester tester) async {
  final ScrollPosition position = _sheetBodyPosition(tester);
  expect(
    position.maxScrollExtent,
    greaterThan(0),
    reason: 'le corps de la fiche doit être plus haut que sa place',
  );
  final Rect header = tester.getRect(find.byKey(sheetFrameHeaderKey));
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
  expect(position.pixels, greaterThan(0), reason: 'défilée au bout');
  expect(
    tester.getRect(find.byKey(sheetFrameHeaderKey)),
    header,
    reason: 'l’en-tête reste en place quand le corps défile',
  );
  return position.pixels;
}

/// Le corps de la fiche [panel] est montré depuis son haut (position 0), et
/// son en-tête épinglé — qui porte « ⚠ Avertissement » — est entier dans
/// l'écran.
void _expectSheetShownFromTop(
  WidgetTester tester,
  Finder panel,
  double before,
) {
  expect(
    _sheetBodyPosition(tester).pixels,
    0,
    reason: 'la position de défilement est conservée (avant : $before)',
  );
  final Finder header = find.descendant(
    of: panel,
    matching: find.byKey(sheetFrameHeaderKey),
  );
  expect(header, findsOneWidget, reason: 'l’en-tête de la fiche ouverte');
  expect(
    find.descendant(of: header, matching: find.byKey(warningLinkKey)),
    findsOneWidget,
    reason: '« ⚠ Avertissement » dans l’en-tête',
  );
  final Rect rect = tester.getRect(header);
  final double screenHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(
    rect.top >= 0 && rect.bottom <= screenHeight,
    isTrue,
    reason: 'en-tête à $rect, écran de $screenHeight px de haut',
  );
}

/// Un point DANS la bande du bouton de désignation (`DesignationBand`), hors
/// de la pilule et de l'indice : à côté de la pilule, sinon à côté de
/// l'indice, sinon dans l'écart entre les deux. Calculé depuis les
/// rectangles mesurés, jamais par une constante — il ne peut pas retomber hors
/// de la bande, où la carte reçoit les gestes de toute façon et où le test ne
/// prouverait plus rien. Même calcul que `_pointDansLaBande` de
/// `test/features/map/view/map_designation_test.dart`.
Offset _pointDansLaBande(WidgetTester tester) {
  // La bande du bouton (`DesignationBand`, `D2` d’Ergonomie) : à gauche de la
  // colonne, étroite, la pilule peut en prendre toute la largeur ; le point
  // est alors à côté de l’indice, ou dans l’écart entre pilule et indice.
  final Rect bande = tester.getRect(find.byType(DesignationBand));
  final Rect bouton = tester.getRect(find.byKey(mapDesignateCenterButtonKey));
  final Rect indice = tester.getRect(find.byKey(mapDesignateCenterHintKey));
  final Offset p = bouton.left - bande.left >= 8
      ? Offset((bande.left + bouton.left) / 2, bouton.center.dy)
      : indice.left - bande.left >= 8
      ? Offset((bande.left + indice.left) / 2, indice.center.dy)
      : Offset(bande.center.dx, (bouton.bottom + indice.top) / 2);
  expect(
    bande.contains(p) && p.dx > bande.left,
    isTrue,
    reason: 'le point $p doit être DANS la bande $bande, pas sur son bord',
  );
  expect(bouton.contains(p), isFalse, reason: 'le point $p est dans $bouton');
  expect(indice.contains(p), isFalse, reason: 'le point $p est dans $indice');
  return p;
}

/// [cible] est-il atteint par le parcours des annonces depuis [racine] ? C'est
/// le parcours que Flutter suit pour bâtir l'arbre sémantique
/// (`visitChildrenForSemantics`) : une enveloppe qui exclut des annonces
/// (`ExcludeSemantics`, `Semantics(excludeSemantics: true)`) l'arrête.
bool _annonce(RenderObject racine, RenderObject cible) {
  bool atteint = false;
  void visiter(RenderObject noeud) {
    if (atteint) return;
    if (identical(noeud, cible)) {
      atteint = true;
      return;
    }
    noeud.visitChildrenForSemantics(visiter);
  }

  visiter(racine);
  return atteint;
}

void main() {
  // `main()` ne s'appelle pas ici (voir l'en-tête) : ce verrou-ci LIT le
  // texte de la racine. Le dépôt des favoris sérialise ses écritures par
  // instance ; une seconde instance, câblée à un autre ViewModel, croiserait
  // ses lire-puis-écrire avec la première et perdrait un favori (`S5` de T3).
  test('la racine ne construit qu une seule instance du depot des favoris, '
      'et la passe aux fiches station et ONDE', () {
    final String root = File('lib/main.dart').readAsStringSync();

    expect(
      RegExp(r'SharedPreferencesFavoriteRepository\(').allMatches(root),
      hasLength(1),
      reason: 'une seule construction, partagee par tous ses clients',
    );
    expect(
      root,
      contains(
        'final FavoriteRepository favorites = '
        'SharedPreferencesFavoriteRepository();',
      ),
    );
    expect(
      RegExp(
        // Sans traverser la construction d'un AUTRE ViewModel.
        r'StationSheetViewModel\((?:(?!ViewModel\()[^;])*?favorites: favorites,',
      ).hasMatch(root),
      isTrue,
      reason: 'la fiche station recoit CETTE instance',
    );
    expect(
      RegExp(
        r'OndeSheetViewModel\((?:(?!ViewModel\()[^;])*?favorites: favorites[,)]',
      ).hasMatch(root),
      isTrue,
      reason: 'la fiche ONDE recoit CETTE MEME instance',
    );
    expect(
      root,
      contains('favoritesViewModel: FavoritesViewModel(favorites: favorites)'),
      reason: 'l ecran « Favoris » recoit CETTE MEME instance (S11)',
    );
  });

  // `S7a` de T3 : l'étoile des fiches par la composition RÉELLE de
  // `MartinPecheurApp`. Un `MaterialApp` de banc ne prouverait pas que la
  // racine passe `favoriteStar` et `onToggleFavorite` aux deux panneaux.
  group("l'étoile de favori des fiches (S7a de T3) — composition reelle", () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    /// La taille minimale de la fenêtre Windows (800 x 740, `K3`) : la fiche
    /// ouverte doit y tenir, étoile comprise, sans débordement.
    void minimumWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    String? starLabel(WidgetTester tester) =>
        tester.getSemantics(find.byKey(favoriteStarButtonKey)).label;

    testWidgetsOnWindows(
      'fiche station Prete : l etoile est la ; un tap ajoute la station '
      'au depot et l etoile annonce « Retirer des favoris »',
      (WidgetTester tester) async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final StationSheetViewModel sheet = StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _BloisStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        minimumWindow(tester);
        await tester.pumpWidget(_app(await acknowledged(), null, sheet, null));
        expect(find.byKey(favoriteStarButtonKey), findsNothing);

        await sheet.open(StationCode('K447001001'));
        await tester.pump();

        expect(sheet.state, isA<Prete>());
        expect(find.byKey(favoriteStarButtonKey), findsOneWidget);
        expect(starLabel(tester), 'Ajouter aux favoris');

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();
        await tester.pump();

        expect(favorites.stored, hasLength(1));
        expect(favorites.stored.single, isA<StationFavorite>());
        expect(
          (favorites.stored.single as StationFavorite).code.value,
          'K447001001',
        );
        expect(starLabel(tester), 'Retirer des favoris');
      },
    );

    testWidgetsOnWindows(
      'fiche ONDE Prete : l etoile est la ; un tap ajoute le point au '
      'depot et l etoile annonce « Retirer des favoris »',
      (WidgetTester tester) async {
        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final OndeSheetViewModel sheet = OndeSheetViewModel(
          onde: _EmptyOndeObservationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        minimumWindow(tester);
        await tester.pumpWidget(_app(await acknowledged(), null, null, sheet));
        expect(find.byKey(favoriteStarButtonKey), findsNothing);

        await sheet.open(
          OndePoint(
            code: OndeStationCode('K4520001'),
            label: 'LA RIVIERE AUX LOCHES A CHAON',
            latitude: 47.610620493,
            longitude: 2.173858157,
            waterCourseLabel: 'ruisseau la rivière aux loches',
            departement: null,
          ),
        );
        await tester.pump();

        expect(sheet.state, isA<OndeSheetPrete>());
        expect(find.byKey(favoriteStarButtonKey), findsOneWidget);
        expect(starLabel(tester), 'Ajouter aux favoris');

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pump();
        await tester.pump();

        expect(favorites.stored, hasLength(1));
        expect(favorites.stored.single, isA<OndePointFavorite>());
        expect(starLabel(tester), 'Retirer des favoris');
      },
    );
  });

  // `D5` d'Ergonomie (spec § 6.3, `PD8`) : la fiche ONDE ne dessine aucun
  // symbole et n'importe pas la tranche carte (`feature-vers-feature`) ; la
  // racine de composition lui FOURNIT celui de la carte — en grand, dans la
  // tuile, le symbole du marqueur ; en petit, sur chaque ligne d'historique,
  // celui de la légende.
  group('le symbole d ecoulement fourni a la fiche ONDE (D5 d Ergonomie) — '
      'composition reelle', () {
    testWidgetsOnWindows(
      'fiche ONDE prete : un symbole de la carte dans la tuile, un symbole de '
      'legende par ligne d historique, chacun de la categorie de sa campagne',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final WarningsViewModel warnings = WarningsViewModel(
          acknowledgements: _AcknowledgementRepositoryDouble(
            storedVersion: warningTextVersion,
          ),
          currentWarningVersion: warningTextVersion,
        );
        await warnings.load();
        final OndeSheetViewModel onde = OndeSheetViewModel(
          onde: _HistoryOndeObservationRepository(),
          favorites: InMemoryFavoriteRepository(),
          followUps: InMemoryFollowUpRepository(),
        );
        await tester.pumpWidget(_app(warnings, null, null, onde));

        await onde.open(
          OndePoint(
            code: OndeStationCode('K4520001'),
            label: 'LA RIVIERE AUX LOCHES A CHAON',
            latitude: 47.610620493,
            longitude: 2.173858157,
            waterCourseLabel: 'ruisseau la rivière aux loches',
            departement: null,
          ),
        );
        await tester.pump();
        expect(onde.state, isA<OndeSheetPrete>());

        final Finder dansLaTuile = find.descendant(
          of: find.byKey(ondeCategoryTileKey),
          matching: find.byType(OndeMarkerShape),
        );
        expect(dansLaTuile, findsOneWidget);
        final OndeMarkerShape tuile = tester.widget<OndeMarkerShape>(
          dansLaTuile,
        );
        expect(tuile.category, isA<Assec>(), reason: 'la dernière campagne');
        expect(tuile.compact, isFalse, reason: 'le symbole de la carte');
        expect(tuile.observedAt, isNull, reason: 'un symbole, pas un lieu');
        expect(
          tester.getSize(dansLaTuile),
          const Size.square(stationMarkerSize),
          reason: 'la taille rendue du symbole de la carte',
        );

        final List<OndeMarkerShape> fiche = tester
            .widgetList<OndeMarkerShape>(
              find.descendant(
                of: find.byType(OndeSheetPanel),
                matching: find.byType(OndeMarkerShape),
              ),
            )
            .toList();
        final List<OndeMarkerShape> historique = <OndeMarkerShape>[
          for (final OndeMarkerShape s in fiche)
            if (!identical(s, tuile)) s,
        ];
        expect(historique, hasLength(3), reason: 'une par ligne d historique');
        expect(
          historique.every((OndeMarkerShape s) => s.compact),
          isTrue,
          reason: 'le symbole de légende, en petit',
        );
        for (final OndeMarkerShape s in historique) {
          expect(
            tester.getSize(find.byWidget(s)),
            const Size.square(compactMarkerSize),
            reason: 'la taille rendue du symbole de légende',
          );
        }
        expect(
          historique.map((OndeMarkerShape s) => s.category.runtimeType),
          <Type>[Assec, EcoulementNonVisible, Ecoulement],
        );
        // Le symbole n'est pas annoncé : le texte dit déjà la catégorie. Le
        // parcours des annonces, depuis la fiche, ne l'atteint pas — quelle
        // que soit l'enveloppe qui l'en exclut (relecture finale de la
        // branche, m9 : la racine ne pose plus la sienne, la fiche garde la
        // sienne). Le texte de la tuile, lui, est atteint : le parcours n'est
        // pas vide.
        final RenderObject panneau = tester.renderObject(
          find.byType(OndeSheetPanel),
        );
        expect(
          _annonce(
            panneau,
            tester.renderObject(
              find
                  .descendant(
                    of: find.byKey(ondeCategoryTileKey),
                    matching: find.byType(Text),
                  )
                  .first,
            ),
          ),
          isTrue,
          reason: 'le texte de la tuile n’est pas annoncé',
        );
        for (final Element symbole
            in find
                .descendant(
                  of: find.byType(OndeSheetPanel),
                  matching: find.byType(OndeMarkerShape),
                )
                .evaluate()) {
          expect(
            _annonce(panneau, symbole.renderObject!),
            isFalse,
            reason: 'le symbole ${symbole.widget} est annoncé',
          );
        }
      },
    );
  });

  // `K4` de T3 : toute ouverture de fiche montre la fiche depuis son haut. La
  // zone des fiches défile (2026-10-13) et sa position survivait au changement
  // de fiche quand la donnée arrive sans trame entre « en cours » et
  // « prête » (dépôt qui répond sans attente : la donnée en cache). Seule la
  // racine sait quand une fiche s'ouvre : c'est sa composition RÉELLE qui est
  // éprouvée, par les rappels de tap qu'elle passe à `MapView`.
  //
  // La police est celle de test (un glyphe vaut un em) : à 360 × 640 et 200 %,
  // les fiches prêtes y sont plus hautes que la carte, c'est tout ce qu'il
  // faut ici — aucun pixel n'est mesuré.
  group('une fiche s ouvre par le haut (K4 de T3) — composition reelle', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    // `_BloisStationRepository` répond pour tout code : le second est un
    // double de test, pas une station réelle.
    StationCode stationA() => StationCode('K447001001');
    StationCode stationB() => StationCode('K000000002');
    OndePoint chaon() => OndePoint(
      code: OndeStationCode('K4520001'),
      label: 'LA RIVIERE AUX LOCHES A CHAON',
      latitude: 47.610620493,
      longitude: 2.173858157,
      waterCourseLabel: 'ruisseau la rivière aux loches',
      departement: null,
    );

    /// Monte la racine sur un téléphone, 360 × 640, police à 200 %, avec les
    /// VRAIS ViewModels de fiche et des dépôts qui répondent sans attente.
    /// `D2` d’Ergonomie l’avait passée à 800 × 640 : la zone des fiches
    /// provisoire n’y recevait plus rien, en police de test (un carré d’un em
    /// par glyphe). `D5` la ramène au téléphone : la fiche y garde au moins
    /// son en-tête épinglé, et c’est son CORPS qui défile.
    Future<_SheetsRoot> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository();
      final StationSheetViewModel station = StationSheetViewModel(
        observations: _EmptyHydroObservationRepository(),
        stations: _BloisStationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final OndeSheetViewModel onde = OndeSheetViewModel(
        onde: _EmptyOndeObservationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      await tester.pumpWidget(_app(await acknowledged(), null, station, onde));
      return (station: station, onde: onde, favorites: favorites);
    }

    /// Le défilement du corps de la fiche ouverte (`D5` d'Ergonomie) : celui
    /// du cadre commun, sous l'en-tête épinglé — une seule fiche est ouverte.
    Finder sheetScrollable() => _sheetBodyScrollable();

    ScrollPosition sheetPosition(WidgetTester tester) =>
        tester.state<ScrollableState>(sheetScrollable()).position;

    /// Ouvre une fiche PAR LA RACINE — le rappel de tap qu'elle passe à
    /// `MapView` — et laisse le ViewModel aller au bout SANS trame : aucune
    /// image n'est dessinée entre « en cours » et « prête ».
    Future<void> openWithoutFrame(
      WidgetTester tester,
      void Function(MapView map) tap,
    ) async {
      tap(tester.widget<MapView>(find.byType(MapView)));
      await tester.idle();
    }

    /// Fait défiler le corps de la fiche ouverte au bout, vérifie que
    /// l'en-tête n'a pas bougé, et rend la position atteinte.
    Future<double> scrollToEnd(WidgetTester tester) =>
        _scrollSheetBodyToEnd(tester);

    /// Le corps de la fiche [panel] est montré depuis son haut (position 0),
    /// sous son en-tête épinglé, entier dans l'écran.
    void expectShownFromTop(WidgetTester tester, Finder panel, double before) =>
        _expectSheetShownFromTop(tester, panel, before);

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : station A defilee au bout, puis station '
      'B ouverte sans trame entre « en cours » et « prete » — a la premiere '
      'trame ou B est prete, la position du corps vaut 0 et l en-tete, qui '
      'porte « Avertissement », est a l ecran',
      (WidgetTester tester) async {
        final _SheetsRoot root = await pumpPhone(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        final double before = await scrollToEnd(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationB()),
        );
        final StationSheetState state = root.station.state;
        expect(state, isA<Prete>(), reason: 'B prête avant toute trame');
        expect((state as Prete).data.station.code, stationB());
        await tester.pump();

        expectShownFromTop(tester, find.byType(StationSheetPanel), before);
      },
    );

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : fiche station defilee au bout, puis un '
      'point ONDE ouvert sans trame — la fiche ONDE est montree depuis son '
      'haut',
      (WidgetTester tester) async {
        final _SheetsRoot root = await pumpPhone(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        final double before = await scrollToEnd(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onOndeTap!(chaon()),
        );
        expect(root.station.state, isA<Fermee>());
        expect(root.onde.state, isA<OndeSheetPrete>());
        await tester.pump();

        expectShownFromTop(tester, find.byType(OndeSheetPanel), before);
      },
    );

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : fiche ONDE defilee au bout, puis une '
      'station ouverte sans trame — la fiche station est montree depuis son '
      'haut',
      (WidgetTester tester) async {
        final _SheetsRoot root = await pumpPhone(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onOndeTap!(chaon()),
        );
        await tester.pump();
        final double before = await scrollToEnd(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        expect(root.onde.state, isA<OndeSheetFermee>());
        expect(root.station.state, isA<Prete>());
        await tester.pump();

        expectShownFromTop(tester, find.byType(StationSheetPanel), before);
      },
    );

    // Vert avant comme après `K4` : seule une OUVERTURE ramène la fiche en
    // haut.
    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : une bascule de favori sur une fiche '
      'defilee ne remet pas la position a 0',
      (WidgetTester tester) async {
        final _SheetsRoot root = await pumpPhone(tester);

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        final double before = await scrollToEnd(tester);

        // Par le ViewModel, non par l'étoile de la racine : elle a défilé hors
        // champ avec la fiche, et son câblage est tenu par les cas de `S7a`.
        await root.station.toggleFavorite();
        await tester.pump();

        expect(root.favorites.stored, hasLength(1), reason: 'bascule faite');
        expect(sheetPosition(tester).pixels, before);
      },
    );

    // La remise à zéro ne joue qu'au PASSAGE à « en cours ». Deux
    // notifications arrivent PENDANT cet état sans que la fiche change : la
    // réponse du dépôt des favoris quand la station est déjà en favori
    // (l'étoile pleine apparaît), et la bascule de cette étoile. La fenêtre
    // est courte et la police grande pour que la fiche « en cours » elle-même
    // dépasse et défile ; le référentiel ne répond pas, elle le reste.
    testWidgetsOnAndroid(
      'Android : 360 x 200, 300 % : fiche station « en cours » defilee — la '
      'reponse du depot des favoris, puis une bascule de favori, notifient '
      'sans changer d etat et ne remettent pas la position a 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[
            StationFavorite(
              code: stationA(),
              label: 'La Loire à Blois',
              addedAt: DateTime.utc(2026, 10, 14),
            ),
          ],
        );
        final Completer<void> favoritesAnswer = Completer<void>();
        favorites.readGate = favoritesAnswer;
        final StationSheetViewModel station = StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _PendingStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        int notifications = 0;
        station.addListener(() => notifications++);
        await tester.pumpWidget(_app(await acknowledged(), null, station));

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        expect(station.state, isA<EnCours>());
        expect(station.favoriteStar, isNull, reason: 'favoris pas encore lus');
        final double before = await scrollToEnd(tester);

        // La réponse du dépôt des favoris : l'étoile pleine apparaît.
        int seen = notifications;
        favoritesAnswer.complete();
        await tester.idle();
        await tester.pump();
        expect(station.state, isA<EnCours>());
        expect(station.favoriteStar?.filled, isTrue);
        expect(notifications, greaterThan(seen), reason: 'a notifié');
        expect(sheetPosition(tester).pixels, before);

        // La bascule de l'étoile pleine, active en « en cours » : un retrait.
        seen = notifications;
        await station.toggleFavorite();
        await tester.pump();
        expect(station.state, isA<EnCours>());
        expect(favorites.stored, isEmpty, reason: 'bascule faite');
        expect(notifications, greaterThan(seen), reason: 'a notifié');
        expect(sheetPosition(tester).pixels, before);
      },
    );

    // La bascule SEULE : les favoris sont lus avant le défilement, la seule
    // notification reçue ensuite pendant « en cours » est celle de la bascule.
    testWidgetsOnAndroid(
      'Android : 360 x 200, 300 % : fiche station « en cours » defilee, '
      'favoris deja lus — la bascule de l etoile pleine ne remet pas la '
      'position a 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[
            StationFavorite(
              code: stationA(),
              label: 'La Loire à Blois',
              addedAt: DateTime.utc(2026, 10, 14),
            ),
          ],
        );
        final StationSheetViewModel station = StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _PendingStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        await tester.pumpWidget(_app(await acknowledged(), null, station));

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        expect(station.state, isA<EnCours>());
        expect(station.favoriteStar?.filled, isTrue, reason: 'favoris lus');
        // À mi-course, pas au bout : depuis `F1` d'Ergonomie, l'étoile est sur
        // la rangée de l'en-tête du cadre commun ; retirée (« en cours », une
        // étoile de station n'existe que pleine), elle rend sa largeur à la
        // nature, qui se replie sur moins de lignes à 300 % : la fiche
        // raccourcit, et une position au bout serait rognée. À mi-course,
        // l'égalité stricte dit que la bascule ne déplace pas la position.
        await scrollToEnd(tester);
        final ScrollPosition position = sheetPosition(tester);
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pump();
        final double before = position.pixels;
        expect(before, greaterThan(0));

        int notifications = 0;
        station.addListener(() => notifications++);
        await station.toggleFavorite();
        await tester.pump();
        expect(station.state, isA<EnCours>());
        expect(favorites.stored, isEmpty, reason: 'bascule faite');
        expect(notifications, greaterThan(0), reason: 'a notifié');
        expect(sheetPosition(tester).pixels, before);
      },
    );

    // Le même fait pour la fiche ONDE, dont la garde est écrite à part : la
    // source ONDE ne répond pas, la fiche reste « en cours » ; le point est
    // déjà en favori et la réponse du dépôt des favoris fait apparaître
    // l'étoile pleine sans changer l'état.
    testWidgetsOnAndroid(
      'Android : 360 x 200, 300 % : fiche ONDE « en cours » defilee — la '
      'reponse du depot des favoris notifie sans changer d etat et ne remet '
      'pas la position a 0',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[
            OndePointFavorite(
              point: chaon(),
              addedAt: DateTime.utc(2026, 10, 14),
            ),
          ],
        );
        final Completer<void> favoritesAnswer = Completer<void>();
        favorites.readGate = favoritesAnswer;
        final OndeSheetViewModel onde = OndeSheetViewModel(
          onde: _PendingOndeObservationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        int notifications = 0;
        onde.addListener(() => notifications++);
        await tester.pumpWidget(_app(await acknowledged(), null, null, onde));

        await openWithoutFrame(
          tester,
          (MapView map) => map.onOndeTap!(chaon()),
        );
        await tester.pump();
        expect(onde.state, isA<OndeSheetEnCours>());
        expect(onde.favoriteStar, isNull, reason: 'favoris pas encore lus');
        final double before = await scrollToEnd(tester);

        final int seen = notifications;
        favoritesAnswer.complete();
        await tester.idle();
        await tester.pump();
        expect(onde.state, isA<OndeSheetEnCours>());
        expect(onde.favoriteStar?.filled, isTrue);
        expect(notifications, greaterThan(seen), reason: 'a notifié');
        expect(sheetPosition(tester).pixels, before);
      },
    );

    // La racine s'abonne à des ViewModels reçus par son constructeur : s'ils
    // changent, ses écoutes les suivent (`didUpdateWidget`).
    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : racine remontee avec d autres ViewModels '
      'de fiche — une ouverture sur les nouveaux ramene la fiche en haut',
      (WidgetTester tester) async {
        await pumpPhone(tester);

        final InMemoryFavoriteRepository favorites =
            InMemoryFavoriteRepository();
        final StationSheetViewModel station = StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _BloisStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        final OndeSheetViewModel onde = OndeSheetViewModel(
          onde: _EmptyOndeObservationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        final MartinPecheurApp first = tester.widget<MartinPecheurApp>(
          find.byType(MartinPecheurApp),
        );
        // La MÊME racine, aux deux ViewModels de fiche près.
        await tester.pumpWidget(
          MartinPecheurApp(
            warningsViewModel: first.warningsViewModel,
            mapViewModel: first.mapViewModel,
            restrictionsViewModel: first.restrictionsViewModel,
            favoritesViewModel: first.favoritesViewModel,
            floodLayerViewModel: first.floodLayerViewModel,
            floodSheetViewModel: first.floodSheetViewModel,
            stationSheetViewModel: station,
            ondeSheetViewModel: onde,
          ),
        );

        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationA()),
        );
        await tester.pump();
        expect(station.state, isA<Prete>(), reason: 'ouverte sur les nouveaux');
        final double before = await scrollToEnd(tester);

        // Une ouverture sur les NOUVEAUX ramène la fiche en haut.
        await openWithoutFrame(
          tester,
          (MapView map) => map.onStationTap!(stationB()),
        );
        expect(station.state, isA<Prete>());
        await tester.pump();
        expectShownFromTop(tester, find.byType(StationSheetPanel), before);

        await scrollToEnd(tester);
        await openWithoutFrame(
          tester,
          (MapView map) => map.onOndeTap!(chaon()),
        );
        expect(onde.state, isA<OndeSheetPrete>());
        await tester.pump();
        expectShownFromTop(tester, find.byType(OndeSheetPanel), before);
      },
    );
  });

  testWidgetsOnWindows(
    'requiresAcknowledgement vrai : InitialWarningView est affiche, '
    'MapView n\'est jamais construit',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);
    },
  );

  testWidgetsOnWindows('requiresAcknowledgement faux : MapView est affiche', (
    WidgetTester tester,
  ) async {
    final WarningsViewModel warningsViewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(
        storedVersion: warningTextVersion,
      ),
      currentWarningVersion: warningTextVersion,
    );
    await warningsViewModel.load();

    await tester.pumpWidget(_app(warningsViewModel));

    expect(find.byType(MapView), findsOneWidget);
    expect(find.byType(InitialWarningView), findsNothing);
  });

  testWidgetsOnWindows(
    'usager deja acquitte : InitialWarningView n\'est jamais rendu, pas '
    'meme une image — assertion des le tout premier pump',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      // `load()` est attendu AVANT `pumpWidget`, exactement comme
      // `main.dart` l'attend avant `runApp` : c'est ce qui évite le
      // clignotement (révision du plan du 2026-09-22).
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      // Assertion dès le PREMIER pump — pas de `pumpAndSettle` avant : si
      // le modal apparaissait ne serait-ce qu'une image, il serait déjà là
      // à cet instant précis.
      expect(find.byType(InitialWarningView), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
    },
  );

  testWidgetsOnWindows(
    'cocher puis presser le bouton bascule vers la carte sans redemarrer '
    'l\'app, MapView n\'est construit qu\'apres',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));
      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      await tester.tap(find.byKey(initialWarningButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(InitialWarningView), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
    },
  );

  testWidgetsOnWindows(
    'echec de lecture du stockage : le modal reste affiche, l\'app ne '
    'plante pas',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          readError: const FormatException('stockage illisible'),
        ),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      expect(tester.takeException(), isNull);
      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);
    },
  );

  testWidgetsOnWindows(
    'echec d\'ecriture de l\'acquittement (UC-006 A6) : le modal reste '
    'affiche, MapView n\'est jamais construit',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          writeError: const FormatException('ecriture ko'),
        ),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      await tester.tap(find.byKey(initialWarningButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);
    },
  );

  // `S1` (T2) : l'ecran « D'ou vient cette donnee ? » est une route poussee
  // par `Navigator.of(context)` — depuis le modal du premier lancement, qui
  // est le `home` de l'application, puis depuis la fenetre d'avertissement,
  // une route de dialogue. Ces tests passent par la VRAIE composition de
  // `MartinPecheurApp` : un `MaterialApp` de banc ne prouverait pas que le
  // `Navigator` est trouve ici.
  group("ecran des sources (S1) — composition reelle", () {
    Future<void> pumpUnacknowledged(WidgetTester tester) async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      await tester.pumpWidget(_app(viewModel));
    }

    testWidgetsOnWindows(
      'modal : le lien ouvre l ecran, rien n est acquitte, la '
      'carte n est toujours pas construite',
      (WidgetTester tester) async {
        await pumpUnacknowledged(tester);

        await tester.tap(find.byKey(initialWarningSourcesLinkKey));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DataSourcesView), findsOneWidget);
        expect(find.text(dataSourcesTitle), findsOneWidget);
        // Ni visible NI cachee sous la route : la carte n'existe pas.
        expect(find.byType(MapView, skipOffstage: false), findsNothing);
      },
    );

    for (final bool checked in <bool>[false, true]) {
      testWidgetsOnWindows(
        'modal, case ${checked ? 'cochee' : 'decochee'} : le retour '
        'rend le modal tel qu il etait laisse, toujours bloquant',
        (WidgetTester tester) async {
          await pumpUnacknowledged(tester);
          if (checked) {
            await tester.tap(find.byKey(initialWarningCheckboxKey));
            await tester.pump();
          }

          await tester.tap(find.byKey(initialWarningSourcesLinkKey));
          await tester.pumpAndSettle();
          await _retour(tester);
          await tester.pumpAndSettle();

          expect(find.byType(DataSourcesView), findsNothing);
          expect(find.byType(InitialWarningView), findsOneWidget);
          expect(find.byType(MapView, skipOffstage: false), findsNothing);
          expect(
            tester
                .widget<Checkbox>(find.byKey(initialWarningCheckboxKey))
                .value,
            checked,
          );
        },
      );
    }

    testWidgetsOnWindows(
      'apres acquittement : la fenetre d avertissement de la carte '
      'porte le lien, qui ouvre l ecran',
      (WidgetTester tester) async {
        final WarningsViewModel viewModel = WarningsViewModel(
          acknowledgements: _AcknowledgementRepositoryDouble(
            storedVersion: warningTextVersion,
          ),
          currentWarningVersion: warningTextVersion,
        );
        await viewModel.load();
        await tester.pumpWidget(_app(viewModel));

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(warningWindowSourcesLinkKey));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DataSourcesView), findsOneWidget);

        await _retour(tester);
        await tester.pumpAndSettle();
        expect(find.byType(DataSourcesView), findsNothing);
        expect(find.byKey(warningWindowRegionKey), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'de bout en bout : relire les sources depuis le modal, '
      'acquitter, puis les relire depuis la carte',
      (WidgetTester tester) async {
        await pumpUnacknowledged(tester);

        await tester.tap(find.byKey(initialWarningSourcesLinkKey));
        await tester.pumpAndSettle();
        await _retour(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(initialWarningCheckboxKey));
        await tester.pump();
        await tester.tap(find.byKey(initialWarningButtonKey));
        await tester.pumpAndSettle();
        expect(find.byType(MapView), findsOneWidget);

        await tester.tap(find.byKey(warningLinkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(warningWindowSourcesLinkKey));
        await tester.pumpAndSettle();

        expect(find.byType(DataSourcesView), findsOneWidget);
      },
    );
  });

  group('ecran des restrictions (E3)', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    /// Désigne le centre de la carte par le bouton, que le choix
    /// « Restrictions » du sélecteur fait apparaître (`E5`). [allumer] faux :
    /// le mode est DÉJÀ actif (retour d'une désignation) — rappuyer sur la
    /// puce l'éteindrait.
    Future<void> designate(WidgetTester tester, {bool allumer = true}) async {
      if (allumer) {
        await tester.tap(find.byKey(mapDesignationChipKey));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pumpAndSettle();
    }

    bool echelleSelectionnee(WidgetTester tester, MapScaleKind kind) => tester
        .widget<Semantics>(find.byKey(ValueKey<MapScaleKind>(kind)))
        .properties
        .selected!;

    testWidgetsOnWindows(
      'composition reelle, au lancement : la puce Restrictions est '
      'la, ni bouton, ni indice, ni reticule',
      (WidgetTester tester) async {
        await tester.pumpWidget(_app(await acknowledged()));

        expect(find.byKey(mapDesignationChipKey), findsOneWidget);
        expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
        expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
        expect(find.byKey(mapCenterReticleKey), findsNothing);
      },
    );

    // Les fiches fermées que `main.dart` fournit ne réservent aucune place :
    // la carte visible est l'écran entier. Depuis `D2` d'Ergonomie, la bande
    // du bouton est au bas de la carte visible, à gauche de la colonne du bas
    // (spec § 5.5) : le bouton n'est plus au centre de l'écran, mais la
    // colonne reste au bord droit de l'écran, la bande part du bord gauche, et
    // le réticule est au centre horizontal de l'écran entier (960). Une fiche
    // fermée qui réserverait sa place (un panneau de 380 px) déplacerait les
    // trois.
    testWidgetsOnWindows(
      'composition reelle : apres la puce, fiches fermees, la carte visible '
      'est l ecran entier — colonne au bord droit, bande du bouton depuis le '
      'bord gauche jusqu a la colonne, bouton et indice centres dans la '
      'bande, reticule au centre horizontal de l ecran (D2 d Ergonomie)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1032);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            await acknowledged(),
            _restrictions(_PendingRestrictionSource()),
          ),
        );
        await tester.tap(find.byKey(mapDesignationChipKey));
        await tester.pumpAndSettle();

        final Rect bande = tester.getRect(find.byType(DesignationBand));
        final Rect colonne = tester.getRect(find.byKey(mapRecenterButtonKey));
        expect(colonne.right, closeTo(1920 - 8, 1), reason: 'colonne au bord');
        expect(
          bande.left,
          closeTo(8, 1),
          reason: 'bande depuis le bord gauche',
        );
        expect(bande.right, lessThanOrEqualTo(colonne.left));
        expect(
          tester.getCenter(find.byKey(mapCenterReticleKey)).dx,
          closeTo(960, 1),
          reason: 'réticule au centre de la carte visible, l’écran entier',
        );
        expect(
          tester.getCenter(find.byKey(mapDesignateCenterButtonKey)).dx,
          closeTo(bande.center.dx, 1),
        );
        expect(
          tester.getCenter(find.byKey(mapDesignateCenterHintKey)).dx,
          closeTo(bande.center.dx, 1),
        );
      },
    );

    testWidgetsOnWindows('designation : la route de l ecran est poussee et le '
        'ViewModel interroge le point designe', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(find.byType(RestrictionsScreen), findsNothing);

      await designate(tester);

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
      expect(restrictions.state, isA<RestrictionsEnCours>());
    });

    testWidgetsOnWindows(
      'L1 : le bouton de retour de l ecran des restrictions s annonce '
      '« Retour »',
      (WidgetTester tester) async {
        await tester.pumpWidget(_app(await acknowledged(), _restrictions()));
        await designate(tester);

        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(find.byTooltip('Retour'), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'L1 : le menu du clic droit du texte sélectionnable de l ecran des '
      'restrictions est en français (racine réelle)',
      (WidgetTester tester) async {
        await tester.pumpWidget(_app(await acknowledged(), _restrictions()));
        await designate(tester);
        final Finder selectable = find.widgetWithText(
          SelectableText,
          restrictionsPublicSiteUrl,
        );
        await tester.ensureVisible(selectable);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(selectable),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Tout sélectionner'), findsOneWidget);
        expect(find.text('Select all'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'bouton de retour : route retiree, ViewModel ferme, carte '
      'de nouveau visible',
      (WidgetTester tester) async {
        final RestrictionsViewModel restrictions = _restrictions();
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        await designate(tester);

        await _retour(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsNothing);
        expect(restrictions.state, isA<RestrictionsFermees>());
        expect(find.byType(MapView), findsOneWidget);
      },
    );

    // Constat A de la revue : le futur de `push` se complete a l'appel de
    // `pop`, AVANT l'animation de sortie ; `close()` passait alors l'etat a
    // `RestrictionsFermees` et la route, encore montee, se vidait.
    testWidgetsOnWindows(
      'retour : pendant la sortie de la route, l ecran garde son '
      'dernier contenu, le ViewModel est deja ferme',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        await designate(tester);
        source.completers.single.complete(zonesAin());
        await tester.pumpAndSettle();
        expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);
        expect(find.byKey(restrictionsPointBannerKey), findsOneWidget);

        await _retour(tester);
        await tester.pump(const Duration(milliseconds: 50));

        // Le verrou contre une reponse tardive reste pose des le retrait...
        expect(restrictions.state, isA<RestrictionsFermees>());
        // ... mais la route, encore a l'ecran, n'est pas vide.
        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);
        expect(find.byKey(restrictionsPointBannerKey), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(RestrictionsScreen), findsNothing);
      },
    );

    // La route sortante est sous `IgnorePointer`, mais la carte DESSOUS recoit
    // les gestes : une nouvelle designation 50 ms apres le retour relance la
    // requete (le ViewModel quitte `RestrictionsFermees`) pendant que la
    // route sortante est encore a l'ecran. Elle ne doit pas se vider pour
    // autant : seule la NOUVELLE route montre « Recherche des zones… ».
    testWidgetsOnWindows(
      'retour puis nouvelle designation pendant la sortie : la '
      'route SORTANTE garde ses cartes de zone',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        await designate(tester);
        source.completers.single.complete(zonesAin());
        await tester.pumpAndSettle();
        expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);

        await _retour(tester);
        await tester.pump(const Duration(milliseconds: 50));
        expect(restrictions.state, isA<RestrictionsFermees>());
        // Le bouton de la carte, dessous, recoit l'appui (le mode est reste
        // actif au retour).
        await tester.tap(find.byKey(mapDesignateCenterButtonKey));
        await tester.pump();

        // La requete est bien repartie...
        expect(source.requested, hasLength(2));
        expect(restrictions.state, isA<RestrictionsEnCours>());
        // ... la nouvelle route cherche, et la SORTANTE garde ses cartes. La
        // nouvelle route est encore hors scene a sa premiere image : on compte
        // hors scene aussi.
        expect(
          find.byType(RestrictionsScreen, skipOffstage: false),
          findsNWidgets(2),
        );
        expect(
          find.byKey(restrictionsZoneCardKey(0), skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            "Recherche des zones d'alerte pour ce point…",
            skipOffstage: false,
          ),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(find.byKey(restrictionsZoneCardKey(0)), findsNothing);
        expect(
          find.text("Recherche des zones d'alerte pour ce point…"),
          findsOneWidget,
        );
      },
    );

    // `close()` vide `unopenedLink` du ViewModel des le retrait : la route
    // sortante doit garder, elle, l'avis qu'elle affichait.
    testWidgetsOnWindows(
      'retour : un avis de lien non ouvert reste affiche pendant la '
      'sortie de la route',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        await designate(tester);
        source.completers.single.complete(zonesAin());
        await tester.pumpAndSettle();

        // L'action de l'encart, par la composition reelle : `_NeverOpensLinks`
        // refuse, l'avis apparait.
        await tester.tap(find.text(reinforcedWarningActionLabel));
        await tester.pumpAndSettle();
        expect(restrictions.unopenedLink?.raw, restrictionsPublicSiteUrl);
        final Finder notice = find.textContaining(
          "Ce lien n'a pas pu être ouvert",
        );
        expect(notice, findsOneWidget);

        await _retour(tester);
        await tester.pump(const Duration(milliseconds: 50));

        expect(restrictions.state, isA<RestrictionsFermees>());
        expect(restrictions.unopenedLink, isNull);
        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(notice, findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(RestrictionsScreen), findsNothing);
      },
    );

    // Defaut 2, par la composition reelle : l'usager redescend, rappuie sur
    // l'action de l'encart, nouvel echec du meme lien ; l'avis revient dans
    // le champ. Rejoue en plateforme Windows, la premiere cible.
    testWidgetsOnWindows('second echec du site public : l avis, sorti du '
        'champ, est ramene dans le champ', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1266, 741);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      final Finder notice = find.textContaining(
        "Ce lien n'a pas pu être ouvert",
      );
      final Finder scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      await tester.tap(find.text(reinforcedWarningActionLabel));
      await tester.pumpAndSettle();
      final int first = restrictions.unopenedLink!.failureNumber;
      expect(notice, findsOneWidget);

      tester
          .state<ScrollableState>(scrollable)
          .position
          .jumpTo(
            tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          );
      await tester.pump();
      expect(
        tester.getRect(notice).bottom,
        lessThanOrEqualTo(tester.getRect(scrollable).top),
      );

      await tester.tap(find.text(reinforcedWarningActionLabel));
      await tester.pumpAndSettle();

      expect(restrictions.unopenedLink!.failureNumber, greaterThan(first));
      final Rect at = tester.getRect(notice);
      final Rect view = tester.getRect(scrollable);
      expect(at.top, greaterThanOrEqualTo(view.top), reason: '$at / $view');
      expect(at.bottom, lessThanOrEqualTo(view.bottom), reason: '$at / $view');
    });

    // La cible transmise au ViewModel par la composition reelle : `main.dart`
    // passe celle que la vue lui donne, il ne la fige pas. Un ouvreur qui
    // n'ouvre jamais, « Ouvrir l'arrete-cadre » : l'avis est dans la carte de
    // l'arrete-cadre, et nulle part ailleurs (pas dans celle de l'arrete). Dans
    // l'echantillon de l'Ain les deux adresses sont differentes (`decreeUrlAin`
    // et `frameworkUrlAin`, `test/features/restrictions/zones_samples.dart`) :
    // ce test ne joue pas une collision d'adresse, il verrouille la cible
    // transmise (`LinkTarget.frameworkDecree`).
    testWidgetsOnWindows('echec d ouverture de l arrete-cadre : l avis est '
        'dans la carte du CADRE, nulle part ailleurs, et la cible est '
        'frameworkDecree', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1266, 741);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      final Finder notice = find.textContaining(
        "Ce lien n'a pas pu être ouvert",
      );
      expect(notice, findsNothing);

      await tester.ensureVisible(find.text("Ouvrir l'arrêté-cadre"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ouvrir l'arrêté-cadre"));
      await tester.pumpAndSettle();

      expect(restrictions.unopenedLink?.target, LinkTarget.frameworkDecree);
      expect(restrictions.unopenedLink?.raw, frameworkUrlAin);
      expect(
        find.descendant(
          of: find.byKey(
            restrictionsDecreeCardKey(frameworkUrlAin, framework: true),
          ),
          matching: notice,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            restrictionsDecreeCardKey(decreeUrlAin, framework: false),
          ),
          matching: notice,
        ),
        findsNothing,
      );
      expect(notice, findsOneWidget);
    });

    testWidgetsOnWindows('Echap : route retiree, ViewModel ferme', (
      WidgetTester tester,
    ) async {
      final RestrictionsViewModel restrictions = _restrictions();
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(restrictions.state, isA<RestrictionsFermees>());
    });

    testWidgetsOnWindows(
      'retour pendant un chargement : la reponse tardive laisse '
      'le ViewModel ferme',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        await designate(tester);

        await _retour(tester);
        await tester.pumpAndSettle();
        source.completers.single.complete(
          ZonesAtPoint(
            point: source.requested.single,
            retrievedAt: DateTime.utc(2026, 9, 27, 11, 25),
            zones: const [],
          ),
        );
        await tester.pumpAndSettle();

        expect(restrictions.state, isA<RestrictionsFermees>());
      },
    );

    testWidgetsOnWindows(
      'deux designations sans retour : une seule route, etat du '
      'second point, un retour ramene a la carte ViewModel ferme',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));

        await tester.tap(find.byKey(mapDesignationChipKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(mapDesignateCenterButtonKey));
        await tester.pump();
        // La route couvre deja la carte : le second geste (appui long, clic
        // droit) arrive par le rappel de la carte, sans retour entre les deux.
        tester
            .widget<MapView>(find.byType(MapView, skipOffstage: false))
            .onPointDesignated!(GeoPoint(latitude: 45, longitude: 3));
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(source.requested, hasLength(2));
        final RestrictionsState state = restrictions.state;
        expect(state, isA<RestrictionsEnCours>());
        expect((state as RestrictionsEnCours).point, source.requested.last);
        await _retour(tester);
        await tester.pumpAndSettle();
        expect(find.byType(RestrictionsScreen), findsNothing);
        expect(find.byType(MapView), findsOneWidget);
        expect(restrictions.state, isA<RestrictionsFermees>());
      },
    );

    testWidgetsOnWindows(
      're-designation apres retour : une seule route, l etat '
      'est celui du second point',
      (WidgetTester tester) async {
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));

        await designate(tester);
        await _retour(tester);
        await tester.pumpAndSettle();
        // Le mode est resté actif au retour : le bouton est là, sans rappuyer
        // sur la puce.
        await designate(tester, allumer: false);

        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(source.requested, hasLength(2));
        final RestrictionsState state = restrictions.state;
        expect(state, isA<RestrictionsEnCours>());
        expect((state as RestrictionsEnCours).point, source.requested.last);

        await _retour(tester);
        await tester.pumpAndSettle();
        expect(find.byType(RestrictionsScreen), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'au retour de l ecran des restrictions, le mode est toujours '
      'actif (bouton present) et l echelle inchangee (E5)',
      (WidgetTester tester) async {
        final RestrictionsViewModel restrictions = _restrictions();
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        expect(echelleSelectionnee(tester, MapScaleKind.ecoulement), isTrue);

        await designate(tester);
        await _retour(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsNothing);
        expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
        expect(find.byKey(mapCenterReticleKey), findsOneWidget);
        expect(echelleSelectionnee(tester, MapScaleKind.ecoulement), isTrue);
        expect(echelleSelectionnee(tester, MapScaleKind.debit), isFalse);
      },
    );

    testWidgetsOnWindows(
      'une designation par appui long, hors mode, ouvre l ecran et '
      'laisse le mode eteint au retour (E5)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1032);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final _PendingRestrictionSource source = _PendingRestrictionSource();
        final RestrictionsViewModel restrictions = _restrictions(source);
        await tester.pumpWidget(_app(await acknowledged(), restrictions));
        expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);

        await tester.longPressAt(const Offset(1200, 500));
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(source.requested, hasLength(1));

        await _retour(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsNothing);
        expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
        expect(find.byKey(mapCenterReticleKey), findsNothing);
        expect(find.byKey(mapDesignationChipKey), findsOneWidget);
      },
    );

    // Windows est la première cible, et `flutter test` tourne par défaut en
    // Android : la désignation par appui long ET par clic droit, hors mode,
    // est rejouée par la composition RÉELLE, en plateforme Windows. C'est tout
    // ce que ces deux tests prouvent. Le point (1200, 500) est sur la carte
    // NUE, hors de tout défilement de surcouche (mesuré le 2026-10-06 : à
    // 1920 × 1032, hors mode, les deux colonnes du haut tiennent au-dessus de
    // y = 250) : ils ne disent RIEN de la `Scrollbar` automatique du bureau,
    // et resteraient verts si elle revenait. Ce verrou-là est porté par les
    // tests « dans la bande » ci-dessous et, pour les colonnes du haut, par
    // `test/features/map/view/map_designation_test.dart`.
    Future<void> designationHorsMode(
      WidgetTester tester,
      Future<void> Function(Offset at) geste,
    ) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);

      await geste(const Offset(1200, 500));
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));

      await _retour(tester);
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
    }

    testWidgetsOnWindows('Windows : une designation par appui long, hors '
        'mode, ouvre l ecran et laisse le mode eteint au retour (E5)', (
      WidgetTester tester,
    ) async {
      await designationHorsMode(tester, (Offset at) => tester.longPressAt(at));
    });

    testWidgetsOnWindows('Windows : une designation par clic droit, hors '
        'mode, ouvre l ecran et laisse le mode eteint au retour (E5)', (
      WidgetTester tester,
    ) async {
      await designationHorsMode(
        tester,
        (Offset at) => tester.tapAt(at, buttons: kSecondaryButton),
      );
    });

    // La bande du bouton de désignation est plus large que la pilule : un
    // appui long ou un clic droit posé DANS la bande, à côté de la pilule,
    // doit atteindre la carte dessous. Sur Windows, la `Scrollbar`
    // automatique de `MaterialScrollBehavior` enveloppait la bande, et son
    // `MouseRegion` opaque absorbait le geste sur toute la boîte. Verrou de
    // la composition réelle, à la taille minimale de la fenêtre (`K3`) : il
    // rougirait si `DesignationBand` perdait son retrait de la barre de
    // défilement, ou le `hitTestBehavior: deferToChild` de son défilement (la
    // bande, opaque, capterait le geste : aucune désignation, aucun écran).
    Future<_PendingRestrictionSource> dansLaBande(
      WidgetTester tester,
      Future<void> Function(Offset at) geste,
    ) async {
      tester.view.physicalSize = const Size(800, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);

      await geste(_pointDansLaBande(tester));
      await tester.pumpAndSettle();
      return source;
    }

    testWidgetsOnWindows('Windows, 800 x 740, mode Restrictions : un appui '
        'long dans la bande du bouton, a cote de la pilule, ouvre l ecran', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = await dansLaBande(
        tester,
        (Offset at) => tester.longPressAt(at),
      );

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
    });

    testWidgetsOnWindows('Windows, 800 x 740, mode Restrictions : un clic '
        'droit dans la bande du bouton, a cote de la pilule, ouvre l ecran', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = await dansLaBande(
        tester,
        (Offset at) => tester.tapAt(at, buttons: kSecondaryButton),
      );

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
    });
  });

  // `S11` de T3 : l'écran « Favoris » est une ROUTE poussée par la racine.
  // L'ouvrir ferme les deux fiches et relit le dépôt ; une garde empêche d'en
  // empiler deux ; ouvrir un favori retire la route et ouvre la bonne fiche,
  // sans toucher à la carte. Ces règles vivent dans `main.dart` : c'est sa
  // composition RÉELLE qui est éprouvée, avec UN dépôt en mémoire partagé par
  // les trois ViewModels de favoris.
  group('ecran des favoris (S11)', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    StationFavorite blois() => StationFavorite(
      code: StationCode('K447001001'),
      label: 'La Loire à Blois',
      addedAt: DateTime.utc(2026, 10, 14),
    );
    OndePoint chaon() => OndePoint(
      code: OndeStationCode('K4520001'),
      label: 'LA RIVIERE AUX LOCHES A CHAON',
      latitude: 47.610620493,
      longitude: 2.173858157,
      waterCourseLabel: 'ruisseau la rivière aux loches',
      departement: null,
    );
    OndePointFavorite chaonFavorite() =>
        OndePointFavorite(point: chaon(), addedAt: DateTime.utc(2026, 10, 13));

    /// La racine à la taille minimale de la fenêtre Windows (800 × 740, `K3`),
    /// usager acquitté, avec les VRAIS ViewModels sur UN dépôt des favoris.
    /// [stations] : le référentiel de la fiche station (vide par défaut, la
    /// fiche est alors « introuvable »).
    Future<_FavoritesRoot> pumpRoot(
      WidgetTester tester, {
      List<Favorite> initial = const <Favorite>[],
      StationRepository? stations,
    }) async {
      tester.view.physicalSize = const Size(800, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
        initial,
      );
      final StationSheetViewModel station = StationSheetViewModel(
        observations: _EmptyHydroObservationRepository(),
        stations: stations ?? _EmptyStationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final OndeSheetViewModel onde = OndeSheetViewModel(
        onde: _EmptyOndeObservationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final FavoritesViewModel list = FavoritesViewModel(favorites: favorites);
      final MapViewModel map = MapViewModel(
        stationPoints: _EmptyStationPointRepository(),
        observations: _EmptyHydroObservationRepository(),
        onde: _EmptyOndeObservationRepository(),
      );
      await tester.pumpWidget(
        _app(await acknowledged(), null, station, onde, list, map),
      );
      return (
        favorites: favorites,
        station: station,
        onde: onde,
        list: list,
        map: map,
      );
    }

    /// Le bouton « Favoris » de la carte, puis la route installée.
    Future<void> openFavorites(WidgetTester tester) async {
      await tester.tap(find.byKey(mapFavoritesButtonKey));
      await tester.pumpAndSettle();
    }

    MapView mapView(WidgetTester tester) =>
        tester.widget<MapView>(find.byType(MapView, skipOffstage: false));

    const ValueKey<String> firstRemove = ValueKey<String>('favorite-remove-0');

    testWidgetsOnWindows(
      'au lancement : le bouton « Favoris » est la, l ecran absent',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);

        expect(find.byKey(mapFavoritesButtonKey), findsOneWidget);
        expect(find.byType(FavoritesScreen), findsNothing);
        expect(root.list.state, isA<FavorisFermes>());
      },
    );

    testWidgetsOnWindows(
      'L1 : le bouton de retour de l ecran « Favoris » s annonce « Retour »',
      (WidgetTester tester) async {
        await pumpRoot(tester);

        await openFavorites(tester);

        expect(find.byTooltip('Retour'), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'ouvrir « Favoris » ferme la fiche station ouverte et montre l ecran',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);
        await root.station.open(StationCode('K447001001'));
        await tester.pump();
        expect(root.station.state, isA<Introuvable>());

        await openFavorites(tester);

        expect(find.byType(FavoritesScreen), findsOneWidget);
        expect(root.station.state, isA<Fermee>());
      },
    );

    testWidgetsOnWindows(
      'ouvrir « Favoris » ferme la fiche ONDE ouverte et montre l ecran',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);
        await root.onde.open(chaon());
        await tester.pump();
        expect(root.onde.state, isA<OndeSheetPrete>());

        await openFavorites(tester);

        expect(find.byType(FavoritesScreen), findsOneWidget);
        expect(root.onde.state, isA<OndeSheetFermee>());
      },
    );

    testWidgetsOnWindows(
      'chaque ouverture relit le depot : un favori ajoute entre deux '
      'ouvertures apparait a la seconde',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);

        int reads = root.favorites.readCalls;
        await openFavorites(tester);
        expect(root.favorites.readCalls, reads + 1);
        expect(find.text(favoritesEmptyText), findsOneWidget);
        expect(find.text('La Loire à Blois'), findsNothing);

        await _retour(tester);
        await tester.pumpAndSettle();
        await root.favorites.add(blois());

        reads = root.favorites.readCalls;
        await openFavorites(tester);
        expect(root.favorites.readCalls, reads + 1);
        expect(find.text('La Loire à Blois'), findsOneWidget);
      },
    );

    // Précédent de la route des restrictions : un second retrait fermerait le
    // ViewModel sous un écran encore affiché.
    testWidgetsOnWindows(
      'deux appels de onOpenFavorites dans la meme trame : une seule route, '
      'un seul retour ramene a la carte',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
        );

        final MapView map = mapView(tester);
        map.onOpenFavorites!();
        map.onOpenFavorites!();
        await tester.pumpAndSettle();

        expect(
          find.byType(FavoritesScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('La Loire à Blois'), findsOneWidget);

        await _retour(tester);
        await tester.pumpAndSettle();

        expect(find.byType(FavoritesScreen, skipOffstage: false), findsNothing);
        expect(find.byType(MapView), findsOneWidget);
        expect(root.list.state, isA<FavorisFermes>());
      },
    );

    testWidgetsOnWindows(
      'retour : le ViewModel est ferme des le retrait, la route sortante '
      'garde sa liste ; rouvrir donne une route, liste relue',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
        );
        await openFavorites(tester);
        expect(find.text('La Loire à Blois'), findsOneWidget);

        await _retour(tester);
        await tester.pump(const Duration(milliseconds: 50));

        expect(root.list.state, isA<FavorisFermes>());
        expect(find.byType(FavoritesScreen), findsOneWidget);
        expect(find.text('La Loire à Blois'), findsOneWidget);
        expect(find.text(favoritesNoMeasureNotice), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(FavoritesScreen), findsNothing);

        final int reads = root.favorites.readCalls;
        await openFavorites(tester);
        expect(
          find.byType(FavoritesScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(root.favorites.readCalls, reads + 1);
        expect(find.text('La Loire à Blois'), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'depot vide : la liste vide est dite ; le bouton de retour, puis '
      'Echap, retirent la route',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);

        await openFavorites(tester);
        expect(find.text(favoritesEmptyText), findsOneWidget);
        await _retour(tester);
        await tester.pumpAndSettle();
        expect(find.byType(FavoritesScreen), findsNothing);
        expect(find.byType(MapView), findsOneWidget);
        expect(root.list.state, isA<FavorisFermes>());

        await openFavorites(tester);
        expect(find.text(favoritesEmptyText), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(FavoritesScreen), findsNothing);
        expect(find.byType(MapView), findsOneWidget);
        expect(root.list.state, isA<FavorisFermes>());
      },
    );

    testWidgetsOnWindows(
      'ouvrir un favori station : la route est retiree, la fiche station '
      'porte son code, la fiche ONDE est fermee',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
          stations: _BloisStationRepository(),
        );
        await openFavorites(tester);

        await tester.tap(find.text('La Loire à Blois'));
        await tester.pumpAndSettle();

        expect(find.byType(FavoritesScreen), findsNothing);
        expect(root.list.state, isA<FavorisFermes>());
        final StationSheetState state = root.station.state;
        expect(state, isA<Prete>());
        expect((state as Prete).data.station.code.value, 'K447001001');
        expect(root.onde.state, isA<OndeSheetFermee>());
      },
    );

    // Arbitrage 6 du cadrage : ni la caméra, ni l'échelle ne bougent. Une
    // fiche ONDE s'ouvre donc aussi sur l'échelle débit.
    testWidgetsOnWindows(
      'ouvrir un favori ONDE sur l echelle debit : la fiche porte CE point, '
      'l echelle reste le debit, le zoom n a pas bouge',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[chaonFavorite()],
        );
        root.map.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();
        final double? zoom = root.map.zoom;
        expect(zoom, isNotNull, reason: 'la carte a rapporté son zoom');

        await openFavorites(tester);
        await tester.tap(find.text('LA RIVIERE AUX LOCHES A CHAON'));
        await tester.pumpAndSettle();

        expect(find.byType(FavoritesScreen), findsNothing);
        final OndeSheetState state = root.onde.state;
        expect(state, isA<OndeSheetPrete>());
        expect((state as OndeSheetPrete).data.point.code.value, 'K4520001');
        expect(
          state.data.point,
          same((root.favorites.stored.single as OndePointFavorite).point),
        );
        expect(root.map.scale, MapScaleKind.debit);
        expect(root.map.zoom, zoom);
        expect(root.station.state, isA<Fermee>());
      },
    );

    testWidgetsOnWindows(
      'une fiche ONDE ouverte, puis « Favoris », puis un favori station : '
      'seule la fiche station est ouverte',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
          stations: _BloisStationRepository(),
        );
        mapView(tester).onOndeTap!(chaon());
        await tester.pumpAndSettle();
        expect(root.onde.state, isA<OndeSheetPrete>());

        await openFavorites(tester);
        await tester.tap(find.text('La Loire à Blois'));
        await tester.pumpAndSettle();

        expect(root.station.state, isA<Prete>());
        expect(root.onde.state, isA<OndeSheetFermee>());
      },
    );

    testWidgetsOnWindows(
      'retirer un favori depuis la liste : la ligne disparait, le depot ne '
      'le porte plus, la route reste',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois(), chaonFavorite()],
        );
        await openFavorites(tester);

        await tester.tap(find.byKey(firstRemove));
        await tester.pumpAndSettle();

        expect(find.text('La Loire à Blois'), findsNothing);
        expect(find.text('LA RIVIERE AUX LOCHES A CHAON'), findsOneWidget);
        expect(root.favorites.stored, hasLength(1));
        expect(root.favorites.stored.single, isA<OndePointFavorite>());
        expect(find.byType(FavoritesScreen), findsOneWidget);
      },
    );

    testWidgetsOnWindows(
      'retrait en echec : « Le favori n a pas pu etre retire. », la ligne '
      'reste',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
        );
        await openFavorites(tester);
        root.favorites.writeError = StateError('ecriture ko');

        await tester.tap(find.byKey(firstRemove));
        await tester.pumpAndSettle();

        expect(favoriteRemoveFailedText, "Le favori n'a pas pu être retiré.");
        expect(find.text(favoriteRemoveFailedText), findsOneWidget);
        expect(find.text('La Loire à Blois'), findsOneWidget);
        expect(root.favorites.stored, hasLength(1));
      },
    );

    testWidgetsOnWindows(
      'liste illisible : elle est dite telle ; « Repartir d une liste vide » '
      'mene a la liste vide',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
        );
        root.favorites.readError = const FormatException('illisible');
        await openFavorites(tester);
        expect(find.text(favoritesUnreadableText), findsOneWidget);
        expect(find.text(favoritesEmptyText), findsNothing);

        // Le dépôt réel remplace la valeur illisible ; le double garde son
        // `readError` même après son propre `clear()` : on le remet à `null`,
        // comme le `clear()` du dépôt réel, qui remplace la valeur illisible.
        root.favorites.readError = null;
        await tester.tap(find.byKey(favoritesStartOverButtonKey));
        await tester.pumpAndSettle();

        expect(find.text(favoritesEmptyText), findsOneWidget);
        expect(find.text(favoritesUnreadableText), findsNothing);
        expect(root.favorites.stored, isEmpty);
      },
    );

    testWidgetsOnWindows(
      'liste illisible, remise a zero en echec : « La liste n a pas pu etre '
      'remplacee. », l avis de liste illisible reste',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois()],
        );
        root.favorites.readError = const FormatException('illisible');
        await openFavorites(tester);
        root.favorites.writeError = StateError('ecriture ko');

        await tester.tap(find.byKey(favoritesStartOverButtonKey));
        await tester.pumpAndSettle();

        expect(
          favoritesReplaceFailedText,
          "La liste n'a pas pu être remplacée.",
        );
        expect(find.text(favoritesReplaceFailedText), findsOneWidget);
        expect(find.text(favoritesUnreadableText), findsOneWidget);
        expect(root.favorites.stored, hasLength(1));
      },
    );

    // Critères 1 et 6, à la persistance près (`S3`).
    testWidgetsOnWindows(
      'de bout en bout : l etoile d une fiche station prete, la fiche '
      'fermee, puis « Favoris » — la ligne « La Loire a Blois » est la',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          stations: _BloisStationRepository(),
        );
        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.pumpAndSettle();
        expect(root.station.state, isA<Prete>());

        await tester.tap(find.byKey(favoriteStarButtonKey));
        await tester.pumpAndSettle();
        expect(root.favorites.stored, hasLength(1));
        mapView(tester).onCloseSheets!();
        await tester.pumpAndSettle();
        expect(root.station.state, isA<Fermee>());

        await openFavorites(tester);

        expect(find.text('La Loire à Blois'), findsOneWidget);
        expect(find.text(stationFavoriteKind), findsOneWidget);
      },
    );

    // Cadrage § 6.6 : le filtre est de session, l'aller-retour ne le touche
    // pas.
    testWidgetsOnWindows(
      'le filtre survit a l aller-retour par « Favoris » : meme filtre, '
      'bouton « Filtres » toujours en forme active',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(tester);
        const MapFilter filter = MapFilter(assec: false);
        root.map.applyFilter(filter);
        await tester.pumpAndSettle();
        expect(find.byKey(mapFiltersActiveMarkKey), findsOneWidget);

        await openFavorites(tester);
        await _retour(tester);
        await tester.pumpAndSettle();

        expect(root.map.filter, filter);
        expect(find.byKey(mapFiltersButtonKey), findsOneWidget);
        expect(find.byKey(mapFiltersActiveMarkKey), findsOneWidget);
      },
    );

    // Deux activations d'une ligne avant la trame suivante : la seconde ne
    // doit rien retirer — un second `pop()` retirerait la route de la CARTE.
    testWidgetsOnWindows(
      'deux appels de onOpen dans la meme trame : la route « Favoris » seule '
      'est retiree, la carte reste, la fiche du PREMIER favori est ouverte',
      (WidgetTester tester) async {
        final _FavoritesRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[blois(), chaonFavorite()],
          stations: _BloisStationRepository(),
        );
        await openFavorites(tester);

        final FavoritesScreen screen = tester.widget<FavoritesScreen>(
          find.byType(FavoritesScreen),
        );
        screen.onOpen(blois());
        screen.onOpen(chaonFavorite());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(FavoritesScreen), findsNothing);
        expect(find.byType(MapView), findsOneWidget);
        // Plus rien à retirer : la carte est la seule route.
        expect(
          Navigator.of(tester.element(find.byType(MapView))).canPop(),
          isFalse,
        );
        final StationSheetState state = root.station.state;
        expect(state, isA<Prete>());
        expect((state as Prete).data.station.code.value, 'K447001001');
        expect(root.onde.state, isA<OndeSheetFermee>());
        expect(root.list.state, isA<FavorisFermes>());
      },
    );

    // Ouvrir un favori passe par `open()` des ViewModels de fiche, hors d'une
    // phase de construction — la fiche d'un AUTRE lieu se montre donc aussi
    // depuis son haut. Non-régression, verte dès son écriture, et encore verte
    // SANS l'écoute de `K4` (contre-épreuve du 2026-10-14) : ouvrir « Favoris »
    // ferme les deux fiches, la zone des fiches se vide sous la route et sa
    // position retombe à 0 d'elle-même. Ce cas tient donc le résultat pour le
    // chemin des favoris, par quelque moyen que ce soit ; l'écoute de `K4` a
    // ses propres verrous, dans son groupe.
    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : station A defilee au bout, puis '
      '« Favoris », puis le favori d une AUTRE station — a la premiere trame '
      'ou sa fiche est prete, la position vaut 0',
      (WidgetTester tester) async {
        // Au téléphone, comme `pumpPhone` du groupe `K4` : `D5` d'Ergonomie
        // y ramène le cas, que `D2` avait passé à 800 × 640.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // `_BloisStationRepository` répond pour tout code : le second est un
        // double de test, pas une station réelle.
        final StationCode stationB = StationCode('K000000002');
        final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
          <Favorite>[
            StationFavorite(
              code: stationB,
              label: 'Station B',
              addedAt: DateTime.utc(2026, 10, 14),
            ),
          ],
        );
        final StationSheetViewModel station = StationSheetViewModel(
          observations: _EmptyHydroObservationRepository(),
          stations: _BloisStationRepository(),
          favorites: favorites,
          followUps: InMemoryFollowUpRepository(),
        );
        await tester.pumpWidget(
          _app(
            await acknowledged(),
            null,
            station,
            OndeSheetViewModel(
              onde: _EmptyOndeObservationRepository(),
              favorites: favorites,
              followUps: InMemoryFollowUpRepository(),
            ),
            FavoritesViewModel(favorites: favorites),
          ),
        );
        // Le corps de la fiche ouverte (`D5` d'Ergonomie).
        ScrollPosition sheetPosition() => _sheetBodyPosition(tester);

        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.pumpAndSettle();
        final double before = await _scrollSheetBodyToEnd(tester);

        mapView(tester).onOpenFavorites!();
        await tester.pumpAndSettle();
        expect(find.byType(FavoritesScreen), findsOneWidget);
        expect(station.state, isA<Fermee>());

        await tester.ensureVisible(find.text('Station B'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Station B'));
        await tester.idle();
        final StationSheetState state = station.state;
        expect(state, isA<Prete>(), reason: 'B prête avant toute trame');
        expect((state as Prete).data.station.code, stationB);
        await tester.pump();
        expect(
          sheetPosition().pixels,
          0,
          reason: 'première trame où B est prête (avant : $before)',
        );

        await tester.pumpAndSettle();
        expect(find.byType(FavoritesScreen), findsNothing);
        _expectSheetShownFromTop(
          tester,
          find.byType(StationSheetPanel),
          before,
        );
      },
    );

    testWidgetsOnWindows(
      'usager non acquitte : ni carte, ni bouton « Favoris », ni ecran',
      (WidgetTester tester) async {
        final WarningsViewModel warnings = WarningsViewModel(
          acknowledgements: _AcknowledgementRepositoryDouble(),
          currentWarningVersion: warningTextVersion,
        );
        await warnings.load();

        await tester.pumpWidget(_app(warnings));

        expect(find.byType(InitialWarningView), findsOneWidget);
        expect(find.byType(MapView, skipOffstage: false), findsNothing);
        expect(find.byKey(mapFavoritesButtonKey), findsNothing);
        expect(find.byType(FavoritesScreen), findsNothing);
      },
    );
  });

  // `F4` de T4 : la composition RÉELLE de la source Vigicrues, lue dans le
  // texte de la racine, sur le modèle du verrou du dépôt des favoris
  // ci-dessus. Décorée par son cache de 30 min, construite sur
  // `vigicruesJsonClient` — qui porte les 20 s (D4) — et jamais sur un
  // `JsonHttpClient` nu, qui garderait les 10 s par défaut.
  test('la racine compose la source de vigilance crues decoree par son cache, '
      'sur vigicruesJsonClient, et la passe a la lecture Crues', () {
    final String root = File('lib/main.dart').readAsStringSync();

    expect(
      RegExp(r'VigicruesFloodVigilanceSource\(').allMatches(root),
      hasLength(1),
      reason: 'la source n est nommee qu une fois',
    );
    expect(
      RegExp(r'CachedFloodVigilanceSource\(').allMatches(root),
      hasLength(1),
      reason: 'une seule construction du decorateur',
    );
    expect(
      RegExp(
        r'final FloodVigilanceSource floodVigilanceSource =\s*'
        r'CachedFloodVigilanceSource\(\s*'
        r'inner: VigicruesFloodVigilanceSource\(\s*'
        r'client: vigicruesJsonClient\(http\.Client\(\)\),?\s*'
        r'\),?\s*'
        r'\);',
      ).hasMatch(root),
      isTrue,
      reason:
          'le decorateur de cache enveloppe la source, construite sur '
          'vigicruesJsonClient',
    );
    expect(
      RegExp(r'VigicruesFloodVigilanceSource\(\s*client: JsonHttpClient\(')
          .hasMatch(root),
      isFalse,
      reason: 'un JsonHttpClient nu perdrait les 20 s',
    );
    expect(
      root,
      contains(
        'floodLayerViewModel: FloodLayerViewModel(source: floodVigilanceSource)',
      ),
    );
    expect(
      RegExp(
        r'floodSheetViewModel: FloodSheetViewModel\(\s*'
        r'links: const UrlLauncherExternalLinkOpener\(\),\s*'
        r'favorites: favorites,\s*'
        r'followUps: followUps,?\s*\)',
      ).hasMatch(root),
      isTrue,
      reason:
          'la fiche troncon ouvre le bulletin par l ouvreur de liens reel, et '
          'recoit les MEMES depots des favoris et du suivi que le reste',
    );
  });

  // `V1` de T5 : le dépôt des suivis sérialise ses lire-puis-écrire par
  // instance, comme celui des favoris ; une seconde instance perdrait un
  // réglage. UNE construction, passée à la fiche tronçon.
  test('la racine ne construit qu une seule instance du depot des suivis, '
      'et la passe a la fiche troncon', () {
    final String root = File('lib/main.dart').readAsStringSync();

    expect(
      RegExp(r'SharedPreferencesFollowUpRepository\(').allMatches(root),
      hasLength(1),
      reason: 'une seule construction, partagee par tous ses clients',
    );
    expect(
      root,
      contains(
        'final FollowUpRepository followUps = '
        'SharedPreferencesFollowUpRepository();',
      ),
    );
    expect(
      RegExp(
        // Sans traverser la construction d'un AUTRE ViewModel.
        r'FloodSheetViewModel\((?:(?!ViewModel\()[^;])*?followUps: followUps[,)]',
      ).hasMatch(root),
      isTrue,
      reason: 'la fiche troncon recoit CETTE instance',
    );
  });

  // `V2` de T5 : les fiches station et ONDE reçoivent la MÊME instance du
  // dépôt des suivis que la fiche tronçon.
  test('la racine passe la meme instance du depot des suivis aux fiches '
      'station et ONDE', () {
    final String root = File('lib/main.dart').readAsStringSync();

    for (final String viewModel in <String>[
      'StationSheetViewModel',
      'OndeSheetViewModel',
    ]) {
      expect(
        RegExp(
          // Sans traverser la construction d'un AUTRE ViewModel.
          viewModel + r'\((?:(?!ViewModel\()[^;])*?followUps: followUps[,)]',
        ).hasMatch(root),
        isTrue,
        reason: '$viewModel recoit CETTE instance',
      );
    }
  });

  // `F4` de T4, Review Focus 5 : jamais deux fiches ensemble. La racine ferme
  // la fiche tronçon à chaque autre entrée — fiche station, fiche ONDE,
  // `Échap`, désignation, « Favoris », ouverture d'un favori —, et quand
  // l'usager QUITTE la lecture Crues ; et l'inverse : le toucher d'un tronçon
  // ferme les deux autres fiches. Chaque entrée est éprouvée SEULE : la fiche
  // tronçon est ouverte par le rappel de la racine sur une échelle d'où
  // l'entrée éprouvée ne la quitte pas, pour que l'écoute du changement
  // d'échelle ne ferme rien à sa place.
  group('la lecture Crues et la fiche troncon (F4 de T4) — composition '
      'reelle', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    StationFavorite blois() => StationFavorite(
      code: StationCode('K447001001'),
      label: 'La Loire à Blois',
      addedAt: DateTime.utc(2026, 10, 14),
    );
    OndePoint chaon() => OndePoint(
      code: OndeStationCode('K4520001'),
      label: 'LA RIVIERE AUX LOCHES A CHAON',
      latitude: 47.610620493,
      longitude: 2.173858157,
      waterCourseLabel: 'ruisseau la rivière aux loches',
      departement: null,
    );

    /// La racine, par défaut à la taille minimale de la fenêtre Windows
    /// (800 × 740, `K3`), usager acquitté, avec les VRAIS ViewModels.
    Future<_FloodRoot> pumpRoot(
      WidgetTester tester, {
      List<Favorite> initial = const <Favorite>[],
      Size window = const Size(800, 740),
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository(
        initial,
      );
      final StationSheetViewModel station = StationSheetViewModel(
        observations: _EmptyHydroObservationRepository(),
        stations: _BloisStationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final OndeSheetViewModel onde = OndeSheetViewModel(
        onde: _EmptyOndeObservationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final FavoritesViewModel list = FavoritesViewModel(favorites: favorites);
      final MapViewModel map = MapViewModel(
        stationPoints: _EmptyStationPointRepository(),
        observations: _EmptyHydroObservationRepository(),
        onde: _EmptyOndeObservationRepository(),
      );
      final _CountingFloodSource source = _CountingFloodSource();
      final FloodLayerViewModel floodLayer = FloodLayerViewModel(
        source: source,
      );
      final FloodSheetViewModel floodSheet = _floodSheet();
      await tester.pumpWidget(
        _app(
          await acknowledged(),
          null,
          station,
          onde,
          list,
          map,
          floodLayer,
          floodSheet,
        ),
      );
      await tester.pumpAndSettle();
      return (
        favorites: favorites,
        station: station,
        onde: onde,
        list: list,
        map: map,
        floodLayer: floodLayer,
        floodSheet: floodSheet,
        source: source,
      );
    }

    MapView mapView(WidgetTester tester) =>
        tester.widget<MapView>(find.byType(MapView, skipOffstage: false));

    /// Touche un tronçon PAR LA RACINE : le rappel qu'elle passe à `MapView`.
    Future<void> touchSection(WidgetTester tester, String code) async {
      mapView(tester).onFloodSectionTap!(_troncon(code), _floodDate);
      await tester.pumpAndSettle();
    }

    Future<void> selectScaleChip(WidgetTester tester, MapScaleKind kind) async {
      await tester.tap(find.byKey(ValueKey<MapScaleKind>(kind)));
      await tester.pumpAndSettle();
    }

    void expectFloodSheetOpenOn(_FloodRoot root, String code) {
      final FloodSheetState state = root.floodSheet.state;
      expect(state, isA<FicheTronconOuverte>());
      expect((state as FicheTronconOuverte).section.code.value, code);
      expect(state.informationDate, _floodDate);
    }

    testWidgetsOnWindows(
      'au lancement : la lecture Crues est NonDemandee, la source n est pas '
      'appelee, aucune fiche troncon',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);

        expect(root.floodLayer.state, isA<LectureCruesNonDemandee>());
        expect(root.source.calls, 0, reason: 'aucun appel au lancement');
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
        expect(find.byType(FloodSheetPanel), findsOneWidget);
        expect(find.byKey(floodBulletinButtonKey), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'la puce « Vigilance crues » de la racine active la lecture : un seul '
      'appel a la source',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);

        await selectScaleChip(tester, MapScaleKind.crues);

        expect(root.map.scale, MapScaleKind.crues);
        expect(root.source.calls, 1);
      },
    );

    testWidgetsOnWindows(
      'toucher d un troncon : la fiche troncon s ouvre sur CE troncon et la '
      'date de la carte, son panneau est affiche',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await selectScaleChip(tester, MapScaleKind.crues);

        await touchSection(tester, 'LO1');

        expectFloodSheetOpenOn(root, 'LO1');
        expect(find.text('Tronçon de test LO1'), findsOneWidget);
        expect(find.byKey(floodBulletinButtonKey), findsOneWidget);
      },
    );

    // Review Focus 5, chaque entrée seule.
    testWidgetsOnWindows(
      'fiche troncon ouverte (echelle debit), puis tap d une station : la '
      'fiche troncon est Fermee, la fiche station ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        root.map.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.pumpAndSettle();

        expect(root.map.scale, MapScaleKind.debit);
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
        expect(root.station.state, isA<Prete>());
      },
    );

    testWidgetsOnWindows(
      'fiche troncon ouverte (echelle ecoulement), puis un point ONDE : la '
      'fiche troncon est Fermee, la fiche ONDE ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        mapView(tester).onOndeTap!(chaon());
        await tester.pumpAndSettle();

        expect(root.map.scale, MapScaleKind.ecoulement);
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
        expect(root.onde.state, isA<OndeSheetPrete>());
      },
    );

    testWidgetsOnWindows(
      'fiche troncon ouverte sur la lecture Crues, puis Echap : la fiche '
      'troncon est Fermee, l echelle reste la lecture Crues',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await selectScaleChip(tester, MapScaleKind.crues);
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        mapView(tester).onCloseSheets!();
        await tester.pumpAndSettle();

        expect(root.map.scale, MapScaleKind.crues);
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
        expect(find.byKey(floodBulletinButtonKey), findsNothing);
      },
    );

    testWidgetsOnWindows(
      'fiche troncon ouverte sur la lecture Crues, puis designation d un '
      'point : la fiche troncon est Fermee, l ecran des restrictions pousse',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await selectScaleChip(tester, MapScaleKind.crues);
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        mapView(tester)
            .onPointDesignated!(GeoPoint(latitude: 47.4, longitude: 0.7));
        await tester.pumpAndSettle();

        expect(find.byType(RestrictionsScreen), findsOneWidget);
        expect(root.map.scale, MapScaleKind.crues);
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
      },
    );

    testWidgetsOnWindows(
      'fiche troncon ouverte sur la lecture Crues, puis « Favoris » : la '
      'fiche troncon est Fermee, l ecran des favoris est montre',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await selectScaleChip(tester, MapScaleKind.crues);
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        await tester.tap(find.byKey(mapFavoritesButtonKey));
        await tester.pumpAndSettle();

        expect(find.byType(FavoritesScreen), findsOneWidget);
        expect(root.map.scale, MapScaleKind.crues);
        expect(root.floodSheet.state, isA<FicheTronconFermee>());
      },
    );

    // L'ouverture d'un favori, seule : la fiche tronçon est rouverte SOUS la
    // route « Favoris » (déjà poussée, qui l'avait fermée), puis le favori
    // est ouvert. Les deux sortes de favori, chacune par sa branche.
    // Arbitrage du commanditaire du 2026-10-15 (« Fiches Crues », réponse
    // « Fermer, et changer d'échelle ») : depuis la lecture Crues, le favori
    // passe d'abord sur sa lecture — Débit pour une station, Écoulement pour
    // un point ONDE —, puis sa fiche s'ouvre et le reste.
    for (final bool ondeFavorite in <bool>[false, true]) {
      testWidgetsOnWindows(
        'fiche troncon ouverte sous l ecran « Favoris », puis ouverture d un '
        'favori ${ondeFavorite ? 'ONDE' : 'station'} : la fiche troncon est '
        'Fermee, l echelle passe ${ondeFavorite ? 'a l ecoulement' : 'au debit'}'
        ', la fiche du favori est ouverte',
        (WidgetTester tester) async {
          final _FloodRoot root = await pumpRoot(
            tester,
            initial: <Favorite>[
              if (ondeFavorite)
                OndePointFavorite(
                  point: chaon(),
                  addedAt: DateTime.utc(2026, 10, 13),
                )
              else
                blois(),
            ],
          );
          await selectScaleChip(tester, MapScaleKind.crues);
          await tester.tap(find.byKey(mapFavoritesButtonKey));
          await tester.pumpAndSettle();
          await touchSection(tester, 'LO1');
          expectFloodSheetOpenOn(root, 'LO1');

          await tester.tap(
            find.text(
              ondeFavorite
                  ? 'LA RIVIERE AUX LOCHES A CHAON'
                  : 'La Loire à Blois',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(FavoritesScreen), findsNothing);
          expect(
            root.map.scale,
            ondeFavorite ? MapScaleKind.ecoulement : MapScaleKind.debit,
          );
          expect(root.floodSheet.state, isA<FicheTronconFermee>());
          if (ondeFavorite) {
            expect(root.onde.state, isA<OndeSheetPrete>());
            expect(root.station.state, isA<Fermee>());
          } else {
            expect(root.station.state, isA<Prete>());
            expect(root.onde.state, isA<OndeSheetFermee>());
          }
        },
      );
    }

    // Même arbitrage, l'autre sens : ENTRER sur la lecture Crues ferme les
    // fiches station et ONDE. Une fenêtre large : à 800 × 740, une fiche
    // ouverte couvre les puces de la colonne de gauche.
    testWidgetsOnWindows(
      'fiche station ouverte sur l echelle debit, puis la puce « Vigilance '
      'crues » : la fiche station est Fermee',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(
          tester,
          window: const Size(1920, 1032),
        );
        await selectScaleChip(tester, MapScaleKind.debit);
        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.pumpAndSettle();
        expect(root.station.state, isA<Prete>());

        await selectScaleChip(tester, MapScaleKind.crues);

        expect(root.map.scale, MapScaleKind.crues);
        expect(root.station.state, isA<Fermee>());
        expect(root.onde.state, isA<OndeSheetFermee>());
      },
    );

    testWidgetsOnWindows(
      'fiche ONDE ouverte sur l echelle ecoulement, puis la puce « Vigilance '
      'crues » : la fiche ONDE est Fermee',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(
          tester,
          window: const Size(1920, 1032),
        );
        mapView(tester).onOndeTap!(chaon());
        await tester.pumpAndSettle();
        expect(root.onde.state, isA<OndeSheetPrete>());

        await selectScaleChip(tester, MapScaleKind.crues);

        expect(root.map.scale, MapScaleKind.crues);
        expect(root.onde.state, isA<OndeSheetFermee>());
        expect(root.station.state, isA<Fermee>());
      },
    );

    // L'arbitrage 6 de T3 reste entier hors de la lecture Crues : sur le
    // débit, un favori ONDE s'ouvre sans changer d'échelle.
    testWidgetsOnWindows(
      'sur l echelle debit, ouverture d un favori ONDE : l echelle reste le '
      'debit, la fiche ONDE est ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(
          tester,
          initial: <Favorite>[
            OndePointFavorite(
              point: chaon(),
              addedAt: DateTime.utc(2026, 10, 13),
            ),
          ],
        );
        root.map.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(mapFavoritesButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.text('LA RIVIERE AUX LOCHES A CHAON'));
        await tester.pumpAndSettle();

        expect(root.map.scale, MapScaleKind.debit);
        expect(root.onde.state, isA<OndeSheetPrete>());
      },
    );

    // L'inverse : le toucher d'un tronçon ferme les deux autres fiches.
    testWidgetsOnWindows(
      'fiche station ouverte, puis toucher d un troncon : la fiche station '
      'est Fermee, la fiche troncon ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.pumpAndSettle();
        expect(root.station.state, isA<Prete>());

        await touchSection(tester, 'LO1');

        expect(root.station.state, isA<Fermee>());
        expectFloodSheetOpenOn(root, 'LO1');
      },
    );

    testWidgetsOnWindows(
      'fiche ONDE ouverte, puis toucher d un troncon : la fiche ONDE est '
      'Fermee, la fiche troncon ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        mapView(tester).onOndeTap!(chaon());
        await tester.pumpAndSettle();
        expect(root.onde.state, isA<OndeSheetPrete>());

        await touchSection(tester, 'LO1');

        expect(root.onde.state, isA<OndeSheetFermee>());
        expectFloodSheetOpenOn(root, 'LO1');
      },
    );

    // Quitter la lecture Crues ferme la fiche tronçon (D8), par la puce. Une
    // fenêtre large : à 800 × 740, la fiche tronçon ouverte, plus haute, couvre
    // la puce « Débit » de la colonne de gauche.
    for (final MapScaleKind other in <MapScaleKind>[
      MapScaleKind.ecoulement,
      MapScaleKind.debit,
    ]) {
      testWidgetsOnWindows(
        'fiche troncon ouverte sur la lecture Crues, puis la puce '
        '« ${mapScaleLabel(other)} » : la fiche troncon est Fermee',
        (WidgetTester tester) async {
          final _FloodRoot root = await pumpRoot(
            tester,
            window: const Size(1920, 1032),
          );
          await selectScaleChip(tester, MapScaleKind.crues);
          await touchSection(tester, 'LO1');
          expectFloodSheetOpenOn(root, 'LO1');

          await selectScaleChip(tester, other);

          expect(root.map.scale, other);
          expect(root.floodSheet.state, isA<FicheTronconFermee>());
          expect(find.byKey(floodBulletinButtonKey), findsNothing);
        },
      );
    }

    // L'écoute réagit au CHANGEMENT d'échelle, pas à chaque notification de
    // `MapViewModel` : un geste notifie sans changer d'échelle.
    testWidgetsOnWindows(
      'fiche troncon ouverte sur la lecture Crues, puis un geste qui notifie '
      'MapViewModel sans changer d echelle : la fiche reste ouverte',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(tester);
        await selectScaleChip(tester, MapScaleKind.crues);
        await touchSection(tester, 'LO1');
        expectFloodSheetOpenOn(root, 'LO1');

        int notifications = 0;
        void count() => notifications++;
        root.map.addListener(count);
        addTearDown(() => root.map.removeListener(count));
        await root.map.onGestureEnded(
          Bounds(west: 0, south: 46, east: 2, north: 48),
          zoom: 8,
        );
        await tester.pumpAndSettle();

        expect(notifications, greaterThan(0), reason: 'MapViewModel a notifie');
        expect(root.map.scale, MapScaleKind.crues);
        expectFloodSheetOpenOn(root, 'LO1');
      },
    );

    // La racine s'abonne à des ViewModels reçus par son constructeur : s'ils
    // changent, ses écoutes les suivent (`didUpdateWidget`).
    testWidgetsOnWindows(
      'racine remontee avec d autres ViewModels de carte et de fiche troncon '
      ': quitter la lecture Crues ferme la NOUVELLE fiche troncon',
      (WidgetTester tester) async {
        final _FloodRoot root = await pumpRoot(
          tester,
          window: const Size(1920, 1032),
        );
        final MapViewModel map = MapViewModel(
          stationPoints: _EmptyStationPointRepository(),
          observations: _EmptyHydroObservationRepository(),
          onde: _EmptyOndeObservationRepository(),
        );
        final FloodSheetViewModel floodSheet = _floodSheet();
        final MartinPecheurApp first = tester.widget<MartinPecheurApp>(
          find.byType(MartinPecheurApp),
        );
        // La MÊME racine, au ViewModel de carte et à celui de la fiche tronçon
        // près.
        await tester.pumpWidget(
          MartinPecheurApp(
            warningsViewModel: first.warningsViewModel,
            mapViewModel: map,
            stationSheetViewModel: first.stationSheetViewModel,
            ondeSheetViewModel: first.ondeSheetViewModel,
            restrictionsViewModel: first.restrictionsViewModel,
            favoritesViewModel: first.favoritesViewModel,
            floodLayerViewModel: first.floodLayerViewModel,
            floodSheetViewModel: floodSheet,
          ),
        );
        await tester.pumpAndSettle();

        await selectScaleChip(tester, MapScaleKind.crues);
        expect(map.scale, MapScaleKind.crues);
        await touchSection(tester, 'LO1');
        expect(floodSheet.state, isA<FicheTronconOuverte>());
        expect(root.floodSheet.state, isA<FicheTronconFermee>());

        await selectScaleChip(tester, MapScaleKind.ecoulement);

        expect(map.scale, MapScaleKind.ecoulement);
        expect(floodSheet.state, isA<FicheTronconFermee>());
      },
    );
  });

  // `F4` de T4 : le panneau de la fiche tronçon dans la zone des fiches, son
  // défilement réel (reporté par `F3`), et sa remise en haut à chaque
  // ouverture, comme les deux autres fiches (`K4` de T3). Un téléphone,
  // 360 × 640, police à 200 % : la fiche est plus haute que la carte.
  group('la fiche troncon dans la zone des fiches (F4 de T4) — composition '
      'reelle', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    /// Monte la racine sur un téléphone, 360 × 640 et 200 % par défaut
    /// (ramenée là par `D5` d’Ergonomie : voir `pumpPhone` du groupe `K4`),
    /// avec les VRAIS ViewModels de fiche.
    ///
    /// Les deux cas du BOUTON DU BULLETIN, en bas du corps, demandent un corps
    /// qui ait une fenêtre : à 360 × 640, en police de test (un carré d’un em
    /// par glyphe), la fiche n’y garde que son en-tête épinglé, à 200 % comme
    /// à 100 % — le corps cède au repli 2 —, et en Roboto à 200 % aussi
    /// (`ergonomie_replis_releves.dart`). Ils se montent donc sur l’autre
    /// téléphone garanti, 390 × 844, à 100 % ([size], [textScale]).
    Future<_SheetsRoot> pumpPhone(
      WidgetTester tester,
      FloodSheetViewModel floodSheet, {
      double textScale = 2,
      Size size = const Size(360, 640),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final InMemoryFavoriteRepository favorites = InMemoryFavoriteRepository();
      final StationSheetViewModel station = StationSheetViewModel(
        observations: _EmptyHydroObservationRepository(),
        stations: _BloisStationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      final OndeSheetViewModel onde = OndeSheetViewModel(
        onde: _EmptyOndeObservationRepository(),
        favorites: favorites,
        followUps: InMemoryFollowUpRepository(),
      );
      await tester.pumpWidget(
        _app(
          await acknowledged(),
          null,
          station,
          onde,
          null,
          null,
          null,
          floodSheet,
        ),
      );
      return (station: station, onde: onde, favorites: favorites);
    }

    MapView mapView(WidgetTester tester) =>
        tester.widget<MapView>(find.byType(MapView));

    /// Le défilement du corps de la fiche ouverte (`D5` d'Ergonomie).
    Finder sheetScrollable() => _sheetBodyScrollable();

    ScrollPosition sheetPosition(WidgetTester tester) =>
        _sheetBodyPosition(tester);

    Future<double> scrollToEnd(WidgetTester tester) =>
        _scrollSheetBodyToEnd(tester);

    void expectFloodSheetFromTop(WidgetTester tester, double before) =>
        _expectSheetShownFromTop(tester, find.byType(FloodSheetPanel), before);

    testWidgetsOnAndroid(
      'Android : 390 x 844, 100 % : le panneau de la fiche troncon est dans '
      'la zone des fiches ; son corps defile, sous le MEME controleur que la '
      'fiche station, jusqu a son bouton du bulletin',
      (WidgetTester tester) async {
        final FloodSheetViewModel floodSheet = _floodSheet();
        await pumpPhone(
          tester,
          floodSheet,
          textScale: 1,
          size: const Size(390, 844),
        );

        // `D5` d'Ergonomie : la zone ne défile plus, chaque fiche défile son
        // corps — sous le MÊME contrôleur, celui de la racine (`K4`).
        ScrollController? bodyController() => tester
            .widget<SingleChildScrollView>(find.byKey(sheetFrameBodyKey))
            .controller;
        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.idle();
        await tester.pump();
        final ScrollController? stationController = bodyController();
        expect(stationController, isNotNull);

        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();

        expect(floodSheet.state, isA<FicheTronconOuverte>());
        expect(
          find.descendant(
            of: find.byType(FloodSheetPanel),
            matching: find.byKey(sheetFrameBodyKey),
          ),
          findsOneWidget,
        );
        expect(bodyController(), same(stationController));
        expect(
          find.ancestor(
            of: find.byType(FloodSheetPanel),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
          reason: 'aucun défilement de zone autour du panneau',
        );
        await scrollToEnd(tester);
        // Au bout du défilement, le dernier élément du corps (l'adresse du
        // bulletin) est dans la fenêtre du corps — le bas du panneau, lui,
        // est le bas de la fenêtre quelle que soit la position.
        final Rect window = tester.getRect(sheetScrollable());
        final Rect last = tester.getRect(
          find.text(floodBulletinUri('8').toString()),
        );
        expect(
          last.top >= window.top && last.bottom <= window.bottom,
          isTrue,
          reason: 'adresse du bulletin à $last, fenêtre $window',
        );
        // Et le bouton du bulletin s'y amène en entier.
        await tester.ensureVisible(find.byKey(floodBulletinButtonKey));
        await tester.pumpAndSettle();
        final Rect button = tester.getRect(find.byKey(floodBulletinButtonKey));
        expect(
          button.top >= window.top && button.bottom <= window.bottom,
          isTrue,
          reason: 'bouton du bulletin à $button, fenêtre $window',
        );
      },
    );

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : troncon A defile au bout, puis troncon '
      'B — la fiche troncon est montree depuis son haut',
      (WidgetTester tester) async {
        final FloodSheetViewModel floodSheet = _floodSheet();
        await pumpPhone(tester, floodSheet);
        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();
        final double before = await scrollToEnd(tester);

        mapView(tester).onFloodSectionTap!(_troncon('LO2'), _floodDate);
        await tester.pump();

        expect(
          (floodSheet.state as FicheTronconOuverte).section.code.value,
          'LO2',
        );
        expectFloodSheetFromTop(tester, before);
      },
    );

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : le MEME troncon rouvert apres defilement '
      '— la fiche troncon est montree depuis son haut',
      (WidgetTester tester) async {
        final FloodSheetViewModel floodSheet = _floodSheet();
        await pumpPhone(tester, floodSheet);
        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();
        final double before = await scrollToEnd(tester);

        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();

        expectFloodSheetFromTop(tester, before);
      },
    );

    testWidgetsOnAndroid(
      'Android : 360 x 640, 200 % : fiche station defilee au bout, puis un '
      'troncon — la fiche troncon est montree depuis son haut',
      (WidgetTester tester) async {
        final FloodSheetViewModel floodSheet = _floodSheet();
        final _SheetsRoot root = await pumpPhone(tester, floodSheet);
        mapView(tester).onStationTap!(StationCode('K447001001'));
        await tester.idle();
        await tester.pump();
        final double before = await scrollToEnd(tester);

        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();

        expect(root.station.state, isA<Fermee>());
        expectFloodSheetFromTop(tester, before);
      },
    );

    // Seule une OUVERTURE ramène la fiche en haut : l'échec d'ouverture du
    // bulletin rend un nouvel état ouvert (l'avis se réannonce), qui n'est
    // pas une ouverture. Le ramener en haut le cacherait — l'avis se ramène
    // lui-même dans le champ après la trame : la position est donc suivie à
    // chaque changement, pour qu'aucun passage par 0 n'échappe.
    testWidgetsOnAndroid(
      'Android : 390 x 844, 100 % : l echec d ouverture du bulletin, en bas '
      'de la fiche defilee, ne la ramene jamais en haut',
      (WidgetTester tester) async {
        final FloodSheetViewModel floodSheet = _floodSheet();
        await pumpPhone(
          tester,
          floodSheet,
          textScale: 1,
          size: const Size(390, 844),
        );
        mapView(tester).onFloodSectionTap!(_troncon('LO1'), _floodDate);
        await tester.pump();
        await scrollToEnd(tester);
        // Le bouton, en bas du corps, amené en entier dans la fenêtre du corps
        // (au téléphone, elle est plus basse que le bouton et l'adresse qui le
        // suit) : la position reste loin du haut.
        await tester.ensureVisible(find.byKey(floodBulletinButtonKey));
        await tester.pumpAndSettle();
        expect(sheetPosition(tester).pixels, greaterThan(0));

        final ScrollPosition position = sheetPosition(tester);
        final List<double> seen = <double>[];
        void record() => seen.add(position.pixels);
        position.addListener(record);
        addTearDown(() => position.removeListener(record));

        await tester.tap(find.byKey(floodBulletinButtonKey));
        await tester.pump();
        await tester.pump();

        expect(
          (floodSheet.state as FicheTronconOuverte).unopenedBulletinCount,
          1,
          reason: 'le bulletin n a pas pu etre ouvert',
        );
        expect(seen, isNot(contains(0)), reason: 'positions : $seen');
        expect(position.pixels, greaterThan(0));
      },
    );
  });
}
