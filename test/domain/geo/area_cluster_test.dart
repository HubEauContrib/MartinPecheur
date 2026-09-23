// Verrouille clusterByArea (ADR-015) : la partition par zone administrative
// (BR-007 — jamais un élément perdu ni compté deux fois), le barycentre en
// moyenne arithmétique, l'emprise exacte (null quand elle est plate), et le
// libellé retenu (celui du premier membre). Les chiffres viennent de la
// fixture réelle `test/fixtures/onde/observations_bbox_loire_2026-09-13.json`
// et de l'asset réel `assets/referentiel/stations.json`, relevés le
// 2026-09-22 (voir le tableau de faits en tête du lot 4 bis du plan T1) —
// jamais inventés.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/mappers/onde_observation_mapper.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/nomenclature/flow_severity.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

({double latitude, double longitude}) _ondePosition(OndeObservation o) =>
    (latitude: o.point.latitude, longitude: o.point.longitude);

({double latitude, double longitude}) _stationPosition(StationPoint p) =>
    (latitude: p.latitude, longitude: p.longitude);

/// Les observations de la fixture bbox Loire, une par station — la plus
/// récente, comme le fait `HttpOndeObservationRepository.latestWithinBounds`
/// (pas recopié ici : c'est le test de ce dépôt qui verrouille cette
/// déduplication, ce test-ci part de son résultat).
List<OndeObservation> _observationsLoireUnePparStation() {
  final String contenu = File(
    'test/fixtures/onde/observations_bbox_loire_2026-09-13.json',
  ).readAsStringSync();
  final Map<String, dynamic> decode =
      jsonDecode(contenu) as Map<String, dynamic>;
  final List<dynamic> lignes = decode['data'] as List<dynamic>;

  final Map<String, OndeObservation> parStation = <String, OndeObservation>{};
  for (final dynamic ligne in lignes) {
    final OndeObservation observation = mapOndeObservation(
      ligne as Map<String, dynamic>,
    );
    final String code = observation.station.value;
    final OndeObservation? actuelle = parStation[code];
    if (actuelle == null ||
        observation.observedAt.isAfter(actuelle.observedAt)) {
      parStation[code] = observation;
    }
  }
  return parStation.values.toList();
}

void main() {
  group('clusterByArea — fixture réelle bbox Loire, 15 stations', () {
    late List<OndeObservation> observations;

    setUpAll(() {
      observations = _observationsLoireUnePparStation();
    });

    test('quinze observations, une par station', () {
      expect(observations, hasLength(15));
    });

    test(
      'niveau département : deux agrégats, 41 puis 45, par code croissant',
      () {
        final AreaClustering<OndeObservation> clustering =
            clusterByArea<OndeObservation>(
              observations,
              level: AreaLevel.departement,
              areaOf: (OndeObservation o) => o.point.departement,
              positionOf: _ondePosition,
            );

        expect(clustering.unassigned, isEmpty);
        expect(
          clustering.clusters.map(
            (AreaCluster<OndeObservation> c) => c.area.code,
          ),
          <String>['41', '45'],
        );

        final AreaCluster<OndeObservation> departement41 =
            clustering.clusters[0];
        expect(departement41.count, 13);
        expect(departement41.latitude, closeTo(47.507709, 1e-6));
        expect(departement41.longitude, closeTo(1.346744, 1e-6));
        expect(
          mostSevere(
            departement41.members.map((OndeObservation o) => o.category),
          ),
          const Assec(),
        );

        final AreaCluster<OndeObservation> departement45 =
            clustering.clusters[1];
        expect(departement45.count, 2);
        expect(departement45.latitude, closeTo(47.770521, 1e-6));
        expect(departement45.longitude, closeTo(1.754937, 1e-6));
      },
    );

    test(
      'niveau région : un seul agrégat, Centre-Val de Loire, 15 membres',
      () {
        final AreaClustering<OndeObservation> clustering =
            clusterByArea<OndeObservation>(
              observations,
              level: AreaLevel.region,
              areaOf: (OndeObservation o) => o.point.region,
              positionOf: _ondePosition,
            );

        expect(clustering.clusters, hasLength(1));
        final AreaCluster<OndeObservation> centre = clustering.clusters.single;
        expect(
          centre.area,
          const AdministrativeArea(code: '24', label: 'Centre-Val de Loire'),
        );
        expect(centre.count, 15);
        expect(centre.latitude, closeTo(47.542750, 1e-6));
        expect(centre.longitude, closeTo(1.401170, 1e-6));
      },
    );
  });

  group('clusterByArea — partition, jamais un élément perdu (BR-007)', () {
    test('deux membres de même code et de libellés différents : un seul '
        'agrégat, libellé du premier', () {
      final StationPoint premier = StationPoint(
        code: StationCode('K447001001'),
        label: 'Premier',
        latitude: 1,
        longitude: 1,
        departement: const AdministrativeArea(
          code: '41',
          label: 'Premier libellé',
        ),
      );
      final StationPoint second = StationPoint(
        code: StationCode('1011000101'),
        label: 'Second',
        latitude: 2,
        longitude: 2,
        departement: const AdministrativeArea(
          code: '41',
          label: 'Autre libellé',
        ),
      );

      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            <StationPoint>[premier, second],
            level: AreaLevel.departement,
            areaOf: (StationPoint p) => p.departement,
            positionOf: _stationPosition,
          );

      expect(clustering.clusters, hasLength(1));
      expect(clustering.clusters.single.area.label, 'Premier libellé');
      expect(clustering.clusters.single.count, 2);
    });

    test('un membre sans zone va dans unassigned, à sa position relative '
        "d'entrée", () {
      final StationPoint sansZone = StationPoint(
        code: StationCode('A021005050'),
        label: 'Le Rhin en Suisse',
        latitude: 47.5,
        longitude: 7.6,
      );
      final StationPoint avecZone = StationPoint(
        code: StationCode('K447001001'),
        label: 'Blois',
        latitude: 47.58,
        longitude: 1.33,
        departement: const AdministrativeArea(
          code: '41',
          label: 'Loir-et-Cher',
        ),
      );

      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            <StationPoint>[sansZone, avecZone],
            level: AreaLevel.departement,
            areaOf: (StationPoint p) => p.departement,
            positionOf: _stationPosition,
          );

      expect(clustering.unassigned, <StationPoint>[sansZone]);
      expect(clustering.clusters, hasLength(1));
    });

    test("l'ordre d'entrée de unassigned est préservé même entrelacé avec "
        'des membres rattachés — jamais réordonné, jamais rattaché à une '
        'zone voisine', () {
      final StationPoint sansZoneA = StationPoint(
        code: StationCode('A021005050'),
        label: 'Sans zone A',
        latitude: 47.5,
        longitude: 7.6,
      );
      final StationPoint avecZone = StationPoint(
        code: StationCode('K447001001'),
        label: 'Blois',
        latitude: 47.58,
        longitude: 1.33,
        departement: const AdministrativeArea(
          code: '41',
          label: 'Loir-et-Cher',
        ),
      );
      final StationPoint sansZoneB = StationPoint(
        code: StationCode('A040000101'),
        label: 'Sans zone B',
        latitude: 48,
        longitude: 8,
      );

      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            // Entrelacé : sans zone, avec zone, sans zone — jamais trié, ni
            // regroupé par proximité d'entrée.
            <StationPoint>[sansZoneA, avecZone, sansZoneB],
            level: AreaLevel.departement,
            areaOf: (StationPoint p) => p.departement,
            positionOf: _stationPosition,
          );

      expect(clustering.unassigned, <StationPoint>[sansZoneA, sansZoneB]);
    });
  });

  group('clusterByArea — tri par code croissant (ADR-015)', () {
    test("l'ordre d'entrée '45' puis '41' rend la sortie '41' puis '45' — "
        "les agrégats sont triés par code, jamais par ordre d'arrivée", () {
      final StationPoint departement45 = StationPoint(
        code: StationCode('1011000101'),
        label: 'Quarante-cinq',
        latitude: 47.77,
        longitude: 1.75,
        departement: const AdministrativeArea(code: '45', label: 'Loiret'),
      );
      final StationPoint departement41 = StationPoint(
        code: StationCode('K447001001'),
        label: 'Quarante-et-un',
        latitude: 47.58,
        longitude: 1.33,
        departement: const AdministrativeArea(
          code: '41',
          label: 'Loir-et-Cher',
        ),
      );

      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            // '45' entre EN PREMIER, '41' ensuite : si le tri disparaissait,
            // la sortie suivrait cet ordre d'entrée au lieu du code croissant.
            <StationPoint>[departement45, departement41],
            level: AreaLevel.departement,
            areaOf: (StationPoint p) => p.departement,
            positionOf: _stationPosition,
          );

      expect(
        clustering.clusters.map((AreaCluster<StationPoint> c) => c.area.code),
        <String>['41', '45'],
      );
    });
  });

  group('AreaCluster.bounds — emprise exacte, null quand elle est plate', () {
    AreaCluster<StationPoint> clusterDe(List<StationPoint> membres) {
      return clusterByArea<StationPoint>(
        membres,
        level: AreaLevel.departement,
        areaOf: (StationPoint p) => p.departement,
        positionOf: _stationPosition,
      ).clusters.single;
    }

    StationPoint pointA(double lat, double lon) => StationPoint(
      code: StationCode('K447001001'),
      label: 'A',
      latitude: lat,
      longitude: lon,
      departement: const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
    );

    StationPoint pointB(double lat, double lon) => StationPoint(
      code: StationCode('1011000101'),
      label: 'B',
      latitude: lat,
      longitude: lon,
      departement: const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
    );

    test('un membre unique : bounds null', () {
      expect(clusterDe(<StationPoint>[pointA(47, 1)]).bounds, isNull);
    });

    test('deux membres de même latitude : bounds null', () {
      expect(
        clusterDe(<StationPoint>[pointA(47, 1), pointB(47, 2)]).bounds,
        isNull,
      );
    });

    test('deux membres distincts : bounds égale aux min/max exacts, sans '
        'marge', () {
      final Bounds? bounds = clusterDe(<StationPoint>[
        pointA(47, 1),
        pointB(48, 2),
      ]).bounds;

      expect(bounds, isNotNull);
      expect(bounds!.west, 1);
      expect(bounds.east, 2);
      expect(bounds.south, 47);
      expect(bounds.north, 48);
    });
  });

  group('clusterByArea — asset réel (test lent)', () {
    late List<StationPoint> points;

    setUpAll(() {
      final String jsonText = File('assets/referentiel/stations.json')
          .readAsStringSync();
      points = parseStations(jsonText).points;
    });

    test(
      '4 150 points au départ (verrouillé ailleurs, rappel de contexte)',
      () {
        expect(points, hasLength(4150));
      },
    );

    test('niveau région : 18 agrégats, 37 unassigned', () {
      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            points,
            level: AreaLevel.region,
            areaOf: (StationPoint p) => p.region,
            positionOf: _stationPosition,
          );

      expect(clustering.clusters, hasLength(18));
      expect(clustering.unassigned, hasLength(37));

      final List<String> codes = clustering.clusters
          .map((AreaCluster<StationPoint> c) => c.area.code)
          .toList();
      expect(
        codes,
        List<String>.of(codes)..sort(),
        reason:
            'les 18 régions sont rendues par code croissant, quel que soit '
            "l'ordre de lecture de l'asset",
      );

      final AreaCluster<StationPoint> occitanie = clustering.clusters
          .firstWhere((AreaCluster<StationPoint> c) => c.area.code == '76');
      expect(occitanie.area.label, 'OCCITANIE');
      expect(occitanie.count, 753);
      expect(occitanie.latitude, closeTo(43.0786, 1e-4));
      expect(occitanie.longitude, closeTo(2.8731, 1e-4));

      final AreaCluster<StationPoint> laReunion = clustering.clusters
          .firstWhere((AreaCluster<StationPoint> c) => c.area.code == '04');
      expect(laReunion.count, 51);
      expect(laReunion.latitude, lessThan(0));

      final int sommeMembres = clustering.clusters.fold<int>(
        0,
        (int total, AreaCluster<StationPoint> c) => total + c.count,
      );
      expect(sommeMembres + clustering.unassigned.length, 4150);
    });

    test('niveau département : 101 agrégats, 37 unassigned', () {
      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            points,
            level: AreaLevel.departement,
            areaOf: (StationPoint p) => p.departement,
            positionOf: _stationPosition,
          );

      expect(clustering.clusters, hasLength(101));
      expect(clustering.unassigned, hasLength(37));

      final int sommeMembres = clustering.clusters.fold<int>(
        0,
        (int total, AreaCluster<StationPoint> c) => total + c.count,
      );
      expect(sommeMembres + clustering.unassigned.length, 4150);
    });

    test('le point transfrontalier A021005050 est bien dans unassigned', () {
      final AreaClustering<StationPoint> clustering =
          clusterByArea<StationPoint>(
            points,
            level: AreaLevel.region,
            areaOf: (StationPoint p) => p.region,
            positionOf: _stationPosition,
          );

      expect(
        clustering.unassigned
            .map((StationPoint p) => p.code.value)
            .contains('A021005050'),
        isTrue,
      );
    });
  });
}
