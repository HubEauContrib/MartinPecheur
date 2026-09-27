// Relecture du 2026-09-23 (🟠 4) : l'inertie sans drapeau n'était vérifiée
// qu'indirectement (la constante `fluidityProbeEnabled`), jamais le
// câblage lui-même. `wireFluidityProbe` reçoit le booléen en paramètre —
// c'est ce qui rend les deux branches testables sans `--dart-define`.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/diagnostics/fluidity_wiring.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

void main() {
  // `wireFluidityProbe(enabled: true, …)` construit un `FrameTimingProbe`,
  // dont le constructeur par défaut lit `SchedulerBinding.instance` — ce
  // getter exige un binding déjà initialisé, même dans un test qui ne
  // monte aucun widget.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wireFluidityProbe', () {
    test('enabled: false — aucune sonde, aucun décorateur, le dépôt rendu '
        'EST celui reçu (identical), pas une copie ni un décorateur '
        'transparent', () {
      final _EmptyStationPointRepository original =
          _EmptyStationPointRepository();

      final FluidityWiring wiring = wireFluidityProbe(
        enabled: false,
        stationPoints: original,
      );

      expect(wiring.probe, isNull);
      expect(wiring.countingStationPoints, isNull);
      expect(
        identical(wiring.stationPoints, original),
        isTrue,
        reason:
            'une mutation « le drapeau est ignoré » ferait passer ce test '
            'au rouge : le dépôt serait décoré même désactivé',
      );
    });

    test('enabled: true — une sonde ET un décorateur sont construits, le '
        'décorateur enveloppe bien le dépôt reçu', () async {
      final _EmptyStationPointRepository original =
          _EmptyStationPointRepository();

      final FluidityWiring wiring = wireFluidityProbe(
        enabled: true,
        stationPoints: original,
      );

      expect(wiring.probe, isNotNull);
      expect(wiring.countingStationPoints, isNotNull);
      expect(
        identical(wiring.stationPoints, wiring.countingStationPoints),
        isTrue,
        reason:
            'le dépôt câblé dans MapViewModel doit être le MÊME objet '
            'que le décorateur, sinon le compteur de G2 ne verrait pas '
            'les appels que fait MapViewModel',
      );

      final Bounds bounds = Bounds(west: 0, south: 0, east: 1, north: 1);
      await wiring.stationPoints.withinBounds(bounds);
      expect(wiring.countingStationPoints!.withinBoundsCallCount, 1);
    });
  });
}
