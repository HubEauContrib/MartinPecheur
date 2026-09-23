// Task X3 (`NFR-01`), révision du 2026-09-22 : `G2` compte aussi les appels
// au dépôt de points pendant le geste, pour instruire `NV-W6`. Le décorateur
// délègue CHAQUE appel au dépôt décoré (`withinBounds` ET `all()`, ajoutée
// pour `ADR-015`/`Z2`) et compte exactement `withinBounds` — c'est ce que
// `G2` rapporte, pas le total des deux méthodes (`docs/nfr.md § NV-W6`).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/diagnostics/counting_station_point_repository.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart' show StationCode;
import 'package:martinpecheur/domain/station/station_point.dart';

/// Un double en mémoire qui enregistre ce qu'on lui demande, pour vérifier
/// que le décorateur délègue fidèlement — même style que les doubles de
/// `test/main_test.dart`.
final class _RecordingStationPointRepository implements StationPointRepository {
  int withinBoundsCalls = 0;
  int allCalls = 0;
  final List<StationPoint> points;

  _RecordingStationPointRepository([this.points = const <StationPoint>[]]);

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    withinBoundsCalls++;
    return points;
  }

  @override
  Future<List<StationPoint>> all() async {
    allCalls++;
    return points;
  }
}

void main() {
  group('CountingStationPointRepository', () {
    late _RecordingStationPointRepository inner;
    late CountingStationPointRepository counting;

    setUp(() {
      inner = _RecordingStationPointRepository();
      counting = CountingStationPointRepository(inner);
    });

    test(
      'délègue withinBounds au dépôt décoré et compte chaque appel',
      () async {
        final Bounds bounds = Bounds(west: 0, south: 0, east: 1, north: 1);

        await counting.withinBounds(bounds);
        await counting.withinBounds(bounds);
        await counting.withinBounds(bounds, margin: 0.5);

        expect(inner.withinBoundsCalls, 3);
        expect(counting.withinBoundsCallCount, 3);
      },
    );

    test('délègue all() au dépôt décoré, mais ne le compte PAS dans '
        'withinBoundsCallCount — G2 rapporte les appels au viewport, pas '
        'ceux au référentiel entier', () async {
      await counting.all();
      await counting.all();

      expect(inner.allCalls, 2);
      expect(counting.withinBoundsCallCount, 0);
    });

    test('rend bien les points du dépôt décoré, inchangés', () async {
      final List<StationPoint> points = <StationPoint>[
        StationPoint(
          code: StationCode('K123456789'),
          label: 'Une station',
          latitude: 45,
          longitude: 1,
        ),
      ];
      final _RecordingStationPointRepository withPoints =
          _RecordingStationPointRepository(points);
      final CountingStationPointRepository decorated =
          CountingStationPointRepository(withPoints);
      final Bounds bounds = Bounds(west: 0, south: 0, east: 1, north: 1);

      expect(await decorated.withinBounds(bounds), points);
      expect(await decorated.all(), points);
    });

    test('withinBoundsCallCount démarre à zéro', () {
      expect(counting.withinBoundsCallCount, 0);
    });
  });
}
