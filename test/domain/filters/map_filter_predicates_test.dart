import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/filters/map_filter_predicates.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

const AdministrativeArea _loirEtCher = AdministrativeArea(
  code: '41',
  label: 'Loir-et-Cher',
);

StationPoint _station(AdministrativeArea? departement) => StationPoint(
  code: StationCode('K447001001'),
  label: 'Station',
  latitude: 47.6,
  longitude: 2.1,
  departement: departement,
);

OndeObservation _onde(AdministrativeArea? departement, FlowCategory category) =>
    OndeObservation(
      station: OndeStationCode('K4520001'),
      point: OndePoint(
        code: OndeStationCode('K4520001'),
        label: 'Point',
        latitude: 47.6,
        longitude: 2.1,
        waterCourseLabel: null,
        departement: departement,
      ),
      observedAt: DateTime.utc(2026, 9, 13),
      category: category,
      rawFlowCode: null,
      officialLabel: null,
      campaignCode: null,
    );

void main() {
  const MapFilter none = MapFilter.none;
  const MapFilter in41 = MapFilter(departementCode: '41');

  group('filterKeepsDepartement', () {
    test('filtre none : vrai pour null et pour tout code', () {
      expect(filterKeepsDepartement(none, null), isTrue);
      expect(filterKeepsDepartement(none, _loirEtCher), isTrue);
    });

    test('filtre 41 : compare le code exact', () {
      expect(filterKeepsDepartement(in41, _loirEtCher), isTrue);
      expect(
        filterKeepsDepartement(
          in41,
          const AdministrativeArea(code: '41', label: 'LOIR-ET-CHER'),
        ),
        isTrue,
      );
      expect(
        filterKeepsDepartement(
          in41,
          const AdministrativeArea(code: '37', label: 'Indre-et-Loire'),
        ),
        isFalse,
      );
      expect(
        filterKeepsDepartement(
          in41,
          const AdministrativeArea(code: ' 41', label: 'Loir-et-Cher'),
        ),
        isFalse,
      );
    });

    test('filtre 41 : sans rattachement, gardé', () {
      expect(filterKeepsDepartement(in41, null), isTrue);
    });
  });

  group('filterKeepsOndeObservation', () {
    test('none garde tout', () {
      expect(
        filterKeepsOndeObservation(none, _onde(_loirEtCher, Assec())),
        isTrue,
      );
    });

    test('catégorie décochée : masquée', () {
      expect(
        filterKeepsOndeObservation(
          const MapFilter(assec: false),
          _onde(_loirEtCher, Assec()),
        ),
        isFalse,
      );
    });

    test('autre département : masquée même catégorie cochée', () {
      expect(
        filterKeepsOndeObservation(
          const MapFilter(departementCode: '37'),
          _onde(_loirEtCher, Assec()),
        ),
        isFalse,
      );
    });

    test('sans département : gardée si la catégorie est cochée', () {
      expect(filterKeepsOndeObservation(in41, _onde(null, Assec())), isTrue);
    });

    test('sans département : masquée si la catégorie est décochée', () {
      expect(
        filterKeepsOndeObservation(
          const MapFilter(departementCode: '41', assec: false),
          _onde(null, Assec()),
        ),
        isFalse,
      );
    });

    test('inconnu décoché : Inconnu masqué, NonObserve gardé', () {
      const MapFilter noUnknown = MapFilter(inconnu: false);
      expect(
        filterKeepsOndeObservation(noUnknown, _onde(_loirEtCher, Inconnu('9'))),
        isFalse,
      );
      expect(
        filterKeepsOndeObservation(
          noUnknown,
          _onde(_loirEtCher, Inconnu(null)),
        ),
        isFalse,
      );
      expect(
        filterKeepsOndeObservation(noUnknown, _onde(_loirEtCher, NonObserve())),
        isTrue,
      );
    });
  });

  group('filterKeepsStationPoint', () {
    test('la fraîcheur n\'y entre pas', () {
      expect(
        filterKeepsStationPoint(
          const MapFilter(
            dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
          ),
          _station(_loirEtCher),
        ),
        isTrue,
      );
    });

    test('le département seul décide', () {
      expect(filterKeepsStationPoint(in41, _station(_loirEtCher)), isTrue);
      expect(
        filterKeepsStationPoint(
          const MapFilter(departementCode: '37'),
          _station(_loirEtCher),
        ),
        isFalse,
      );
      expect(filterKeepsStationPoint(in41, _station(null)), isTrue);
    });
  });

  group('filterKeepsStation', () {
    const MapFilter f2h = MapFilter(
      dischargeFreshness: DischargeFreshnessCriterion.moinsDe2h,
    );
    const MapFilter f24h = MapFilter(
      dischargeFreshness: DischargeFreshnessCriterion.moinsDe24h,
    );
    final StationPoint station = _station(_loirEtCher);

    test('critère moinsDe2h', () {
      expect(
        filterKeepsStation(f2h, station, const Chargee(Freshness.fraiche)),
        isTrue,
      );
      expect(
        filterKeepsStation(f2h, station, const Chargee(Freshness.ancienne)),
        isFalse,
      );
      expect(
        filterKeepsStation(f2h, station, const Chargee(Freshness.perimee)),
        isFalse,
      );
      expect(filterKeepsStation(f2h, station, const NonChargee()), isTrue);
      expect(filterKeepsStation(f2h, station, EnEchec(Exception('x'))), isTrue);
      expect(filterKeepsStation(f2h, station, const SansDonnee()), isTrue);
    });

    test('critère moinsDe24h', () {
      expect(
        filterKeepsStation(f24h, station, const Chargee(Freshness.ancienne)),
        isTrue,
      );
      expect(
        filterKeepsStation(f24h, station, const Chargee(Freshness.perimee)),
        isFalse,
      );
    });

    test('critère toutes : tout est gardé', () {
      for (final Freshness f in Freshness.values) {
        expect(filterKeepsStation(none, station, Chargee(f)), isTrue);
      }
      expect(filterKeepsStation(none, station, const NonChargee()), isTrue);
    });

    test('département connu et autre, NonChargee : masquée', () {
      expect(
        filterKeepsStation(
          const MapFilter(departementCode: '37'),
          station,
          const NonChargee(),
        ),
        isFalse,
      );
    });

    test('sans département, Chargee(perimee) sous moinsDe24h : masquée', () {
      expect(
        filterKeepsStation(
          f24h,
          _station(null),
          const Chargee(Freshness.perimee),
        ),
        isFalse,
      );
    });

    group('bornes de BR-005', () {
      final DateTime now = DateTime.utc(2026, 9, 13, 10);
      const Duration oneSecond = Duration(seconds: 1);

      StationMapState at(DateTime measuredAt) =>
          Chargee(freshnessOf(measuredAt: measuredAt, now: now));

      test('moinsDe2h : la borne pile est exclue', () {
        expect(
          filterKeepsStation(f2h, station, at(now.subtract(ancienneApres))),
          isFalse,
        );
      });

      test('moinsDe2h : une seconde avant la borne est admise', () {
        expect(
          filterKeepsStation(
            f2h,
            station,
            at(now.subtract(ancienneApres - oneSecond)),
          ),
          isTrue,
        );
      });

      test('moinsDe24h : la borne pile est exclue', () {
        expect(
          filterKeepsStation(f24h, station, at(now.subtract(perimeeApres))),
          isFalse,
        );
      });

      test('moinsDe24h : une seconde avant la borne est admise', () {
        expect(
          filterKeepsStation(
            f24h,
            station,
            at(now.subtract(perimeeApres - oneSecond)),
          ),
          isTrue,
        );
      });

      test('mesure dans le futur : admise sous moinsDe2h', () {
        expect(
          filterKeepsStation(
            f2h,
            station,
            at(now.add(const Duration(minutes: 5))),
          ),
          isTrue,
        );
      });
    });
  });

  group('departementsOf', () {
    test('distincts par code, triés, libellé du premier rencontré', () {
      final List<AdministrativeArea> result = departementsOf(<StationPoint>[
        _station(const AdministrativeArea(code: '41', label: 'LOIR-ET-CHER')),
        _station(const AdministrativeArea(code: '01', label: 'AIN')),
        _station(const AdministrativeArea(code: '41', label: 'Loir-et-Cher')),
        _station(null),
        _station(const AdministrativeArea(code: '2A', label: 'CORSE-DU-SUD')),
        _station(const AdministrativeArea(code: '29', label: 'FINISTERE')),
        _station(const AdministrativeArea(code: '971', label: 'GUADELOUPE')),
      ]);

      expect(result.map((AdministrativeArea a) => a.code).toList(), <String>[
        '01',
        '29',
        '2A',
        '41',
        '971',
      ]);
      expect(
        result.firstWhere((AdministrativeArea a) => a.code == '41').label,
        'LOIR-ET-CHER',
      );
    });

    test('entrée vide : liste vide', () {
      expect(departementsOf(const <StationPoint>[]), isEmpty);
    });

    test('liste non modifiable', () {
      final List<AdministrativeArea> result = departementsOf(<StationPoint>[
        _station(_loirEtCher),
      ]);
      expect(() => result.add(_loirEtCher), throwsUnsupportedError);
    });
  });
}
