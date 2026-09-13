// Verrouille le filtre de viewport : la marge proportionnelle (et non un
// nombre de degrés fixe), le rejet d'une marge négative (BR-007), les bornes
// incluses, l'ordre préservé, et le comportement sur les 4 150 points du
// référentiel réel.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/map/viewport_filter.dart';

StationPoint _pointAt(
  double latitude,
  double longitude, {
  String code = 'A000000001',
  String label = 'station',
}) => StationPoint(
  code: StationCode(code),
  label: label,
  latitude: latitude,
  longitude: longitude,
);

void main() {
  group('stationsWithinViewport — emprise de référence (50/40/10/0)', () {
    // Élargie d'une marge par défaut de 0.5 : hauteur 10 → 35 à 55,
    // largeur 10 → -5 à 15.
    test('un point au centre de l\'emprise est retenu', () {
      final List<StationPoint> result = stationsWithinViewport(
        <StationPoint>[_pointAt(45, 5)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
      );

      expect(result, hasLength(1));
    });

    test("un point loin au-delà de la marge est ecarte", () {
      final List<StationPoint> result = stationsWithinViewport(
        <StationPoint>[_pointAt(60, 5)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
      );

      expect(result, isEmpty);
    });

    test('un point hors emprise mais dans la marge proportionnelle est '
        'retenu', () {
      final List<StationPoint> result = stationsWithinViewport(
        <StationPoint>[_pointAt(53, -3)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
      );

      expect(result, hasLength(1));
    });

    test('marge nulle : les bornes de l\'emprise sont incluses, un point '
        'juste au-dela est ecarte', () {
      final List<StationPoint> withinBound = stationsWithinViewport(
        <StationPoint>[_pointAt(50, 10)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
        margin: 0,
      );
      final List<StationPoint> beyondBound = stationsWithinViewport(
        <StationPoint>[_pointAt(50.1, 10)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
        margin: 0,
      );

      expect(withinBound, hasLength(1));
      expect(beyondBound, isEmpty);
    });
  });

  test('la marge est proportionnelle : sur une emprise etroite, elle ne '
      'couvre qu\'une fraction de degre', () {
    final List<StationPoint> withinMargin = stationsWithinViewport(
      <StationPoint>[_pointAt(46.4, 5)],
      north: 46,
      south: 45,
      east: 6,
      west: 5,
    );
    final List<StationPoint> beyondMargin = stationsWithinViewport(
      <StationPoint>[_pointAt(47.0, 5)],
      north: 46,
      south: 45,
      east: 6,
      west: 5,
    );

    expect(withinMargin, hasLength(1));
    expect(beyondMargin, isEmpty);
  });

  test("l'ordre d'origine est preserve", () {
    final List<StationPoint> result = stationsWithinViewport(
      <StationPoint>[
        _pointAt(45, 5, code: 'AAAAAAAAAA'),
        _pointAt(80, 5, code: 'BBBBBBBBBB'),
        _pointAt(41, 1, code: 'CCCCCCCCCC'),
      ],
      north: 50,
      south: 40,
      east: 10,
      west: 0,
    );

    expect(result.map((StationPoint point) => point.code.value), <String>[
      'AAAAAAAAAA',
      'CCCCCCCCCC',
    ]);
  });

  test('une liste vide renvoie une liste vide', () {
    final List<StationPoint> result = stationsWithinViewport(
      <StationPoint>[],
      north: 50,
      south: 40,
      east: 10,
      west: 0,
    );

    expect(result, isEmpty);
  });

  test('une marge negative leve une ArgumentError — elle retrecirait '
      "l'emprise et les marqueurs disparaitraient avant de sortir de "
      "l'ecran (BR-007)", () {
    expect(
      () => stationsWithinViewport(
        <StationPoint>[_pointAt(45, 5)],
        north: 50,
        south: 40,
        east: 10,
        west: 0,
        margin: -0.1,
      ),
      throwsArgumentError,
    );
  });

  test('sur les 4 150 points du referentiel reel, une emprise etroite en '
      'retient strictement moins que le total, et au moins un', () {
    final String jsonText = File('assets/referentiel/stations.json')
        .readAsStringSync();
    final StationsReadResult referentiel = parseStations(jsonText);

    final List<StationPoint> result = stationsWithinViewport(
      referentiel.points,
      north: 48,
      south: 47,
      east: 2,
      west: 1,
    );

    expect(result, isNotEmpty);
    expect(result.length, lessThan(referentiel.points.length));
  });
}
