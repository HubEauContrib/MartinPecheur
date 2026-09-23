// Verrouille le depot des points de carte : il applique le filtre d'emprise
// du domaine (`stationsWithinViewport`) avec sa marge proportionnelle, et il
// transmet une marge explicite. Il remplace le gestionnaire
// `StationPointsWithinBoundsQuery` de T0 (R3/R4, arbitrage 2026-09-13) : le
// ViewModel appelle ce depot directement, de facon typee, au lieu d'envoyer
// un message a un registre.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

StationPoint _blois() => StationPoint(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  latitude: 47.584957074,
  longitude: 1.335147948,
);

StationPoint _guadeloupe() => StationPoint(
  code: StationCode('1011000101'),
  label: 'Grande Rivière à Goyaves',
  latitude: 16.189402,
  longitude: -61.658989,
);

void main() {
  late AssetStationPointRepository repository;

  setUp(() {
    repository = AssetStationPointRepository(<StationPoint>[
      _blois(),
      _guadeloupe(),
    ]);
  });

  test("rend les points de l'emprise, et eux seuls", () async {
    final List<StationPoint> resultat = await repository.withinBounds(
      Bounds(west: 1, south: 47, east: 2, north: 48),
    );

    expect(resultat.map((StationPoint point) => point.code.value), <String>[
      'K447001001',
    ]);
  });

  test('applique la marge par defaut du filtre (defaultViewportMargin) : '
      "Blois hors de l'emprise stricte mais dans la marge de 0,5 est tout "
      'de meme retenu', () async {
    // Emprise stricte 1° x 1° qui exclut Blois (lat 47,58 > north 47,2 ;
    // lon 1,335 > east 1) mais que la marge de 0,5 (moitie de la
    // hauteur/largeur) elargit assez pour l'inclure (north + 0,5 = 47,7 ;
    // east + 0,5 = 1,5).
    final List<StationPoint> resultat = await repository.withinBounds(
      Bounds(west: 0, south: 46.2, east: 1, north: 47.2),
    );

    expect(resultat.map((StationPoint point) => point.code.value), <String>[
      'K447001001',
    ]);
  });

  test('une marge explicite de zero exclut Blois : la marge est bien '
      'transmise au filtre, jamais recalculee ici', () async {
    final List<StationPoint> resultat = await repository.withinBounds(
      Bounds(west: 0, south: 46.2, east: 1, north: 47.2),
      margin: 0,
    );

    expect(resultat, isEmpty);
  });

  test(
    'un depot vide rend une liste vide, jamais une erreur (BR-007)',
    () async {
      final AssetStationPointRepository vide = AssetStationPointRepository(
        const <StationPoint>[],
      );

      expect(
        await vide.withinBounds(Bounds(west: 1, south: 47, east: 2, north: 48)),
        isEmpty,
      );
    },
  );

  group('all() — ADR-015 : le regroupement porte sur l\'asset entier', () {
    test('rend tous les points, sans filtre d\'emprise', () async {
      final List<StationPoint> resultat = await repository.all();

      expect(resultat.map((StationPoint p) => p.code.value), <String>[
        'K447001001',
        '1011000101',
      ]);
    });

    test('une tentative d\'ecriture dans la liste rendue leve '
        'UnsupportedError — la vue n\'est pas modifiable', () async {
      final List<StationPoint> resultat = await repository.all();

      expect(() => resultat.add(_blois()), throwsUnsupportedError);
    });

    test('deux appels rendent des listes de meme contenu', () async {
      final List<StationPoint> premier = await repository.all();
      final List<StationPoint> second = await repository.all();

      expect(
        premier.map((StationPoint p) => p.code.value),
        second.map((StationPoint p) => p.code.value),
      );
    });

    test('sur l\'extrait reel : 2 points', () async {
      final StationsReadResult extrait = parseStations(
        File('test/fixtures/referentiel/stations_extrait_2026-09-13.json')
            .readAsStringSync(),
      );
      final AssetStationPointRepository depot = AssetStationPointRepository(
        extrait.points,
      );

      expect(await depot.all(), hasLength(2));
    });

    test('sur l\'asset reel (test lent) : 4 150 points, le premier et le '
        'dernier identiques a ceux de parseStations(...).points', () async {
      final StationsReadResult reel = parseStations(
        File('assets/referentiel/stations.json').readAsStringSync(),
      );
      final AssetStationPointRepository depot = AssetStationPointRepository(
        reel.points,
      );

      final List<StationPoint> tous = await depot.all();

      expect(tous, hasLength(4150));
      expect(tous.first.code, reel.points.first.code);
      expect(tous.last.code, reel.points.last.code);
    });
  });
}
