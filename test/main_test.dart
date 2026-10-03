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
import 'dart:ui' show Size;

import 'package:flutter/material.dart' show Checkbox;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart'
    show mapDesignateCenterButtonKey, mapDesignateCenterHintKey;
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/data_sources_view.dart';
import 'package:martinpecheur/features/shared/warning_link.dart'
    show warningLinkKey, warningWindowRegionKey, warningWindowSourcesLinkKey;
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';
import 'package:martinpecheur/features/warnings/view/initial_warning_view.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';
import 'package:martinpecheur/main.dart';

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

MartinPecheurApp _app(
  WarningsViewModel warningsViewModel, [
  RestrictionsViewModel? restrictionsViewModel,
]) => MartinPecheurApp(
  warningsViewModel: warningsViewModel,
  restrictionsViewModel: restrictionsViewModel ?? _restrictions(),
  mapViewModel: MapViewModel(
    stationPoints: _EmptyStationPointRepository(),
    observations: _EmptyHydroObservationRepository(),
    onde: _EmptyOndeObservationRepository(),
  ),
  stationSheetViewModel: StationSheetViewModel(
    observations: _EmptyHydroObservationRepository(),
    stations: _EmptyStationRepository(),
  ),
  ondeSheetViewModel: OndeSheetViewModel(
    onde: _EmptyOndeObservationRepository(),
  ),
);

void main() {
  testWidgets('requiresAcknowledgement vrai : InitialWarningView est affiche, '
      'MapView n\'est jamais construit', (WidgetTester tester) async {
    final WarningsViewModel warningsViewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(),
      currentWarningVersion: warningTextVersion,
    );
    await warningsViewModel.load();

    await tester.pumpWidget(_app(warningsViewModel));

    expect(find.byType(InitialWarningView), findsOneWidget);
    expect(find.byType(MapView), findsNothing);
  });

  testWidgets('requiresAcknowledgement faux : MapView est affiche', (
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

  testWidgets(
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

  testWidgets(
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

  testWidgets(
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

  testWidgets(
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
    Future<_AcknowledgementRepositoryDouble> pumpUnacknowledged(
      WidgetTester tester,
    ) async {
      final _AcknowledgementRepositoryDouble repository =
          _AcknowledgementRepositoryDouble();
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: repository,
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      await tester.pumpWidget(_app(viewModel));
      return repository;
    }

    testWidgets('modal : le lien ouvre l ecran, rien n est acquitte, la '
        'carte n est toujours pas construite', (WidgetTester tester) async {
      await pumpUnacknowledged(tester);

      await tester.tap(find.byKey(initialWarningSourcesLinkKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataSourcesView), findsOneWidget);
      expect(find.text(dataSourcesTitle), findsOneWidget);
      // Ni visible NI cachee sous la route : la carte n'existe pas.
      expect(find.byType(MapView, skipOffstage: false), findsNothing);
    });

    for (final bool checked in <bool>[false, true]) {
      testWidgets('modal, case ${checked ? 'cochee' : 'decochee'} : le retour '
          'rend le modal tel qu il etait laisse, toujours bloquant', (
        WidgetTester tester,
      ) async {
        await pumpUnacknowledged(tester);
        if (checked) {
          await tester.tap(find.byKey(initialWarningCheckboxKey));
          await tester.pump();
        }

        await tester.tap(find.byKey(initialWarningSourcesLinkKey));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(DataSourcesView), findsNothing);
        expect(find.byType(InitialWarningView), findsOneWidget);
        expect(find.byType(MapView, skipOffstage: false), findsNothing);
        expect(
          tester.widget<Checkbox>(find.byKey(initialWarningCheckboxKey)).value,
          checked,
        );
      });
    }

    testWidgets('apres acquittement : la fenetre d avertissement de la carte '
        'porte le lien, qui ouvre l ecran', (WidgetTester tester) async {
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

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DataSourcesView), findsNothing);
      expect(find.byKey(warningWindowRegionKey), findsOneWidget);
    });

    testWidgets('de bout en bout : relire les sources depuis le modal, '
        'acquitter, puis les relire depuis la carte', (
      WidgetTester tester,
    ) async {
      await pumpUnacknowledged(tester);

      await tester.tap(find.byKey(initialWarningSourcesLinkKey));
      await tester.pumpAndSettle();
      await tester.pageBack();
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
    });
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

    Future<void> designate(WidgetTester tester) async {
      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('composition reelle : le bouton et son indice sont centres '
        'sur la carte (fiches fermees)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(await acknowledged(), _restrictions(_PendingRestrictionSource())),
      );

      expect(
        tester.getCenter(find.byKey(mapDesignateCenterButtonKey)).dx,
        closeTo(960, 1),
      );
      expect(
        tester.getCenter(find.byKey(mapDesignateCenterHintKey)).dx,
        closeTo(960, 1),
      );
    });

    testWidgets('designation : la route de l ecran est poussee et le '
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

    testWidgets('bouton de retour : route retiree, ViewModel ferme, carte '
        'de nouveau visible', (WidgetTester tester) async {
      final RestrictionsViewModel restrictions = _restrictions();
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(restrictions.state, isA<RestrictionsFermees>());
      expect(find.byType(MapView), findsOneWidget);
    });

    testWidgets('Echap : route retiree, ViewModel ferme', (
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

    testWidgets('retour pendant un chargement : la reponse tardive laisse '
        'le ViewModel ferme', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.pageBack();
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
    });

    testWidgets('deux designations sans retour : une seule route, etat du '
        'second point, un retour ramene a la carte ViewModel ferme', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));

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
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
      expect(restrictions.state, isA<RestrictionsFermees>());
    });

    testWidgets('re-designation apres retour : une seule route, l etat '
        'est celui du second point', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));

      await designate(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await designate(tester);

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(2));
      final RestrictionsState state = restrictions.state;
      expect(state, isA<RestrictionsEnCours>());
      expect((state as RestrictionsEnCours).point, source.requested.last);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
    });
  });
}
