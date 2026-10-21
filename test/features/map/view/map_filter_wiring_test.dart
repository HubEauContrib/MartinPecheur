// Le bouton « Filtres » et la feuille « Filtres », branchés sur la carte
// (`F10b` de T3, `US-13`, `UC-007`, arbitrage 8 du cadrage de T3).
//
// Ici `MapView` est MONTÉE, avec son `MapViewModel` et des dépôts en
// mémoire : c'est le branchement qui est éprouvé — le bouton ouvre la feuille
// sur le filtre appliqué et l'échelle affichée, « Appliquer » pose le filtre
// sur le ViewModel, fermer autrement n'y touche pas, et le bouton dit le
// filtre actif pour l'échelle affichée, à tous les zooms. Le bouton seul et
// la feuille seule ont leurs fichiers (`map_entry_buttons_test.dart`,
// `map_filter_sheet_test.dart`) ; la disposition du groupe, les siens
// (`map_layout_invariants_test.dart`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_empty_states.dart';
import 'package:martinpecheur/features/map/view/map_entry_buttons.dart';
import 'package:martinpecheur/features/map/view/map_filter_sheet.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

import '../../../support/focus.dart';
import '../../../support/windows_platform.dart';

/// Le référentiel des stations, vide. [all] — la lecture que fait
/// `MapViewModel.departements` — est programmable : elle rend une liste vide,
/// lève ([allThrows]) ou attend ([allPending]).
final class _StationPoints implements StationPointRepository {
  bool allThrows = false;
  Completer<List<StationPoint>>? allPending;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() {
    if (allThrows) {
      return Future<List<StationPoint>>.error(
        StateError('référentiel illisible, simulé'),
      );
    }
    final Completer<List<StationPoint>>? pending = allPending;
    if (pending != null) {
      return pending.future;
    }
    return Future<List<StationPoint>>.value(const <StationPoint>[]);
  }
}

final class _NoHydroObservation implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

/// Rend toujours [observations], quelle que soit l'emprise.
final class _Onde implements OndeObservationRepository {
  _Onde(this.observations);

  final List<OndeObservation> observations;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => OndeSweep(observations: observations, unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

/// Un point ONDE sans rattachement administratif : un marqueur individuel à
/// tous les zooms, jamais fondu dans une pastille.
OndeObservation _observation(
  String suffix,
  FlowCategory category, {
  required double latitude,
  required double longitude,
}) {
  final OndePoint point = OndePoint(
    code: OndeStationCode('0417$suffix'),
    label: 'Point $suffix',
    latitude: latitude,
    longitude: longitude,
    waterCourseLabel: 'Cours $suffix',
    departement: null,
  );
  return OndeObservation(
    station: point.code,
    point: point,
    observedAt: DateTime.utc(2026, 9, 1),
    category: category,
    rawFlowCode: '1',
    officialLabel: 'Libellé',
    campaignCode: '1',
  );
}

/// Une observation « Eau qui coule » et une « À sec ».
List<OndeObservation> _ecoulementEtAssec() => <OndeObservation>[
  _observation('0001', const Ecoulement(), latitude: 46.7, longitude: 2.1),
  _observation('0002', const Assec(), latitude: 46.5, longitude: 2.3),
];

/// Deux observations « À sec » : décocher la case masque tous les lieux.
List<OndeObservation> _deuxAssecs() => <OndeObservation>[
  _observation('0001', const Assec(), latitude: 46.7, longitude: 2.1),
  _observation('0002', const Assec(), latitude: 46.5, longitude: 2.3),
];

final MapFilter _sansAssec = MapFilter.none.withCategory(
  const Assec(),
  shown: false,
);

Finder _marqueursOnde() => find.descendant(
  of: find.byType(MarkerLayer),
  matching: find.byType(OndeMarkerShape),
);

Finder _bouton() => find.byKey(mapFiltersButtonKey);

/// Le bouton « Filtres » est-il dans sa forme active ? La marque au coin ET
/// le libellé annoncé doivent s'accorder : la réponse est l'un ou l'autre
/// état, jamais un mélange.
bool _formeActive(WidgetTester tester) {
  final bool marque = find.byKey(mapFiltersActiveMarkKey).evaluate().isNotEmpty;
  final String libelle = tester.getSemantics(_bouton()).label;
  expect(
    libelle,
    marque ? mapFiltersActiveLabel : mapFiltersLabel,
    reason: 'la marque et le libellé annoncé ne disent pas la même chose',
  );
  return marque;
}

/// La taille minimale de la fenêtre Windows (`K3`).
void _fenetreMinimale(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 740);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Monte `MapView` sur un `MapViewModel` neuf et attend la fin du démarrage.
Future<MapViewModel> _pumpMap(
  WidgetTester tester, {
  required List<OndeObservation> observations,
  _StationPoints? stationPoints,
  Widget? stationSheet,
  Widget? ondeSheet,
}) async {
  _fenetreMinimale(tester);
  final MapViewModel viewModel = MapViewModel(
    stationPoints: stationPoints ?? _StationPoints(),
    observations: _NoHydroObservation(),
    onde: _Onde(observations),
  );
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: MapView(
        viewModel: viewModel,
        onStationTap: stationSheet == null ? null : (StationCode code) {},
        stationSheet: stationSheet,
        onOndeTap: ondeSheet == null ? null : (OndePoint point) {},
        ondeSheet: ondeSheet,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _ouvrirLaFeuille(WidgetTester tester) async {
  await _tap(tester, _bouton());
  expect(find.byKey(mapFilterSheetKey), findsOneWidget);
}

/// Amène le focus sur « Filtres » par Tab — une puce par échelle, puis le
/// bouton — et l'active par Entrée : c'est au clavier que le retour du focus
/// a un sens. Trois Tab avant la puce « Vigilance crues » (`L1` de T4,
/// 2026-10-15), quatre depuis.
Future<void> _ouvrirLaFeuilleAuClavier(WidgetTester tester) async {
  for (int i = 0; i < MapScaleKind.values.length + 1; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(
    focusedWithin(tester, _bouton()),
    isTrue,
    reason: 'le Tab qui suit les puces d’échelle doit arriver sur « Filtres »',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.byKey(mapFilterSheetKey), findsOneWidget);
}

void main() {
  group('MapView — le bouton « Filtres » ouvre la feuille (F10b de T3)', () {
    testWidgetsOnWindows('un tap sur « Filtres » ouvre la feuille ; décocher '
        '« À sec » puis « Appliquer » ne laisse qu’un marqueur ONDE sur deux, '
        'et le bouton passe à la forme active', (WidgetTester tester) async {
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
      );
      expect(_marqueursOnde(), findsNWidgets(2));
      expect(_formeActive(tester), isFalse);
      expect(find.byKey(mapFilterSheetKey), findsNothing);

      await _ouvrirLaFeuille(tester);
      expect(
        find.descendant(
          of: find.byKey(mapFilterSheetKey),
          matching: find.text(mapFilterSheetTitle),
        ),
        findsOneWidget,
      );

      await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
      await _tap(tester, find.byKey(mapFilterApplyKey));

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(viewModel.filter, _sansAssec);
      expect(_marqueursOnde(), findsOneWidget);
      expect(_formeActive(tester), isTrue);
    });

    testWidgetsOnWindows('la feuille s’ouvre sur le filtre appliqué : « À '
        'sec » y est décochée quand le filtre la masque', (
      WidgetTester tester,
    ) async {
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
      );
      viewModel.applyFilter(_sansAssec);
      await tester.pumpAndSettle();

      await _ouvrirLaFeuille(tester);

      final CheckboxListTile assec = tester.widget<CheckboxListTile>(
        find.byKey(mapFilterCategoryKey(const Assec())),
      );
      expect(assec.value, isFalse);
      final CheckboxListTile ecoulement = tester.widget<CheckboxListTile>(
        find.byKey(mapFilterCategoryKey(const Ecoulement())),
      );
      expect(ecoulement.value, isTrue);
    });

    testWidgetsOnWindows('sur l’écoulement la feuille porte six cases ; sur le '
        'débit, « Fraîcheur » et aucune case', (WidgetTester tester) async {
      await _pumpMap(tester, observations: _ecoulementEtAssec());

      await _ouvrirLaFeuille(tester);
      expect(
        find.byType(CheckboxListTile),
        findsNWidgets(filterableFlowCategories.length),
      );
      expect(filterableFlowCategories, hasLength(6));
      expect(find.text('Fraîcheur'), findsNothing);
      await _tap(tester, find.byKey(mapFilterCloseKey));

      await _tap(
        tester,
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      await _ouvrirLaFeuille(tester);
      expect(find.text('Fraîcheur'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      for (final DischargeFreshnessCriterion criterion
          in DischargeFreshnessCriterion.values) {
        expect(find.byKey(mapFilterFreshnessKey(criterion)), findsOneWidget);
      }
    });
  });

  group('MapView — le bouton dit le filtre actif pour l’échelle affichée, aux '
      'zooms 5, 8 et 10 (critère 11 ; aucune pastille n’est dessinée ici)', () {
    testWidgetsOnWindows('filtre « À sec » décochée : forme active sur '
        'l’écoulement aux zooms 5, 8 et 10 ; inactive sur le débit, où ce '
        'critère ne joue pas ; active de retour sur l’écoulement', (
      WidgetTester tester,
    ) async {
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
      );
      expect(_formeActive(tester), isFalse);

      viewModel.applyFilter(_sansAssec);
      await tester.pumpAndSettle();

      expect(viewModel.zoom, 5);
      expect(_formeActive(tester), isTrue, reason: 'zoom 5');

      for (int i = 0; i < 3; i++) {
        await _tap(tester, find.byKey(mapZoomInButtonKey));
      }
      expect(viewModel.zoom, 8);
      expect(_formeActive(tester), isTrue, reason: 'zoom 8');

      for (int i = 0; i < 2; i++) {
        await _tap(tester, find.byKey(mapZoomInButtonKey));
      }
      expect(viewModel.zoom, 10);
      expect(_formeActive(tester), isTrue, reason: 'zoom 10');

      await _tap(
        tester,
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
      );
      expect(viewModel.scale, MapScaleKind.debit);
      expect(viewModel.filter, _sansAssec);
      expect(_formeActive(tester), isFalse, reason: 'échelle débit');

      await _tap(
        tester,
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
      );
      expect(_formeActive(tester), isTrue, reason: 'retour à l’écoulement');
    });
  });

  group('MapView — fermer la feuille sans appliquer ne change rien', () {
    Future<void> verifierRienNAChange(
      WidgetTester tester,
      MapViewModel viewModel,
    ) async {
      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(viewModel.filter, MapFilter.none);
      expect(_marqueursOnde(), findsNWidgets(2));
      expect(_formeActive(tester), isFalse);
      expect(
        focusedWithin(tester, _bouton()),
        isTrue,
        reason: 'le focus doit revenir sur « Filtres »',
      );
    }

    testWidgetsOnWindows('une case décochée, puis Échap : le filtre reste '
        'MapFilter.none, les deux marqueurs restent, la forme reste inactive '
        'et le focus revient sur « Filtres »', (WidgetTester tester) async {
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
      );
      await _ouvrirLaFeuilleAuClavier(tester);
      await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await verifierRienNAChange(tester, viewModel);
    });

    testWidgetsOnWindows('une case décochée, puis « Fermer » : même constat', (
      WidgetTester tester,
    ) async {
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
      );
      await _ouvrirLaFeuilleAuClavier(tester);
      await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));

      await _tap(tester, find.byKey(mapFilterCloseKey));

      await verifierRienNAChange(tester, viewModel);
    });
  });

  group('MapView — une fiche ouverte reste ouverte quand le filtre masque '
      'son lieu (critère 14)', () {
    testWidgetsOnWindows('fiche station et fiche ONDE fournies : un filtre qui '
        'masque tous les lieux les laisse toutes deux dans l’arbre', (
      WidgetTester tester,
    ) async {
      const Key ficheStation = Key('fiche-station-de-test-F10b');
      const Key ficheOnde = Key('fiche-onde-de-test-F10b');
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _deuxAssecs(),
        stationSheet: const SizedBox(key: ficheStation, width: 200, height: 40),
        ondeSheet: const SizedBox(key: ficheOnde, width: 200, height: 40),
      );
      expect(find.byKey(ficheStation), findsOneWidget);
      expect(find.byKey(ficheOnde), findsOneWidget);

      await _ouvrirLaFeuille(tester);
      await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
      await _tap(tester, find.byKey(mapFilterApplyKey));

      expect(viewModel.filterHidesEverything, isTrue);
      expect(_marqueursOnde(), findsNothing);
      expect(find.text(filterHidesEverythingText), findsOneWidget);
      expect(find.byKey(ficheStation), findsOneWidget);
      expect(find.byKey(ficheOnde), findsOneWidget);
    });
  });

  group('MapView — la liste des départements de la feuille', () {
    testWidgetsOnWindows('référentiel illisible : la feuille s’ouvre et '
        'l’écrit, et la carte n’affiche aucun avis de panne', (
      WidgetTester tester,
    ) async {
      final _StationPoints stationPoints = _StationPoints()..allThrows = true;
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
        stationPoints: stationPoints,
      );

      await _ouvrirLaFeuille(tester);

      expect(find.text(mapFilterDepartementsUnreadableText), findsOneWidget);
      expect(find.byKey(mapFilterDepartementKey), findsNothing);
      expect(find.byType(SourceUnavailableNotice), findsNothing);
      expect(viewModel.error, isNull);

      await _tap(tester, find.byKey(mapFilterCloseKey));
      expect(find.byType(SourceUnavailableNotice), findsNothing);
    });

    testWidgetsOnWindows('la carte retirée de l’arbre pendant que la liste est '
        'attendue : aucune exception, aucune feuille', (
      WidgetTester tester,
    ) async {
      final Completer<List<StationPoint>> attente =
          Completer<List<StationPoint>>();
      final _StationPoints stationPoints = _StationPoints()
        ..allPending = attente;
      await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
        stationPoints: stationPoints,
      );

      await tester.tap(_bouton());
      await tester.pump();
      expect(find.byKey(mapFilterSheetKey), findsNothing);

      await tester.pumpWidget(const SizedBox());
      attente.complete(const <StationPoint>[]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(mapFilterSheetKey), findsNothing);
    });
  });

  // Tant que la liste des départements est attendue, aucune feuille ne barre
  // le bouton : un second appui ouvrait une SECONDE feuille par-dessus la
  // première. La première fermée par « Appliquer », la seconde restait, ouverte
  // sur le filtre d'avant, et son « Appliquer » écrasait le filtre appliqué.
  group('MapView — un second appui sur « Filtres » pendant que la feuille '
      's’ouvre n’en ouvre pas une seconde', () {
    testWidgetsOnWindows('deux taps pendant que la liste est attendue : une '
        'seule feuille ; « Appliquer » la ferme, pose le filtre, et le bouton '
        'ouvre de nouveau', (WidgetTester tester) async {
      final Completer<List<StationPoint>> attente =
          Completer<List<StationPoint>>();
      final _StationPoints stationPoints = _StationPoints()
        ..allPending = attente;
      final MapViewModel viewModel = await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
        stationPoints: stationPoints,
      );

      await tester.tap(_bouton());
      await tester.pump();
      await tester.tap(_bouton());
      await tester.pump();
      expect(find.byKey(mapFilterSheetKey), findsNothing);

      attente.complete(const <StationPoint>[]);
      await tester.pumpAndSettle();
      expect(find.byKey(mapFilterSheetKey), findsOneWidget);

      await _tap(tester, find.byKey(mapFilterCategoryKey(const Assec())));
      await _tap(tester, find.byKey(mapFilterApplyKey));

      expect(find.byKey(mapFilterSheetKey), findsNothing);
      expect(viewModel.filter, _sansAssec);

      // La garde est levée à la fermeture : le bouton ouvre de nouveau.
      await _ouvrirLaFeuille(tester);
    });

    testWidgetsOnWindows('Entrée répétée sur le bouton pendant que la liste '
        'est attendue : une seule feuille', (WidgetTester tester) async {
      final Completer<List<StationPoint>> attente =
          Completer<List<StationPoint>>();
      final _StationPoints stationPoints = _StationPoints()
        ..allPending = attente;
      await _pumpMap(
        tester,
        observations: _ecoulementEtAssec(),
        stationPoints: stationPoints,
      );
      // Une puce par échelle, puis « Filtres » (`L1` de T4, 2026-10-15 : trois
      // Tab avant).
      for (int i = 0; i < MapScaleKind.values.length + 1; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusedWithin(tester, _bouton()), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      attente.complete(const <StationPoint>[]);
      await tester.pumpAndSettle();
      expect(find.byKey(mapFilterSheetKey), findsOneWidget);
    });
  });
}
