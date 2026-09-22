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
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
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

MartinPecheurApp _app(WarningsViewModel warningsViewModel) => MartinPecheurApp(
  warningsViewModel: warningsViewModel,
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
}
