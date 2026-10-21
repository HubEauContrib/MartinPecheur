// La vérification des lieux suivis (M4 de T5, BR-016) : elle relit les lieux
// suivis, compare des niveaux PUBLIÉS, produit les avis, dit l'impossible, et
// écrit les avis d'abord, puis les derniers états (PD13).
//
// Les niveaux 2 à 4 et les changements d'arrêté sont des cas construits,
// jamais observés en production — `VC-04`. Ils vivent ici, jamais sous
// `test/fixtures/`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_check.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/station/station.dart';

import '../../support/in_memory_favorite_repository.dart';
import '../../support/in_memory_follow_up_repository.dart';
import '../../support/in_memory_notice_repository.dart';

// L'horloge injectée rend une heure LOCALE : la vérification la passe en UTC.
final DateTime _clockValue = DateTime(2026, 10, 21, 12, 30);
final DateTime _now = _clockValue.toUtc();
final DateTime _added = DateTime.utc(2026, 10, 1);
final DateTime _info1 = DateTime.utc(2026, 10, 20, 6);
final DateTime _info2 = DateTime.utc(2026, 10, 21, 6);
final DateTime _retrieved = DateTime.utc(2026, 10, 21, 10, 15);
final DateTime _read1 = DateTime.utc(2026, 10, 20, 9);
final DateTime _decree1 = DateTime.utc(2026, 7, 1);
final DateTime _decree2 = DateTime.utc(2026, 9, 15);

// Les lieux.
final FloodSectionCode _f1Code = FloodSectionCode('AG1');
final FloodSectionCode _f2Code = FloodSectionCode('AG2');
final FloodSectionPlace _f1Place = FloodSectionPlace(_f1Code);
final FloodSectionPlace _f2Place = FloodSectionPlace(_f2Code);
final FloodSectionFavorite _f1 = FloodSectionFavorite(
  code: _f1Code,
  name: 'Garonne amont',
  addedAt: _added,
);
final FloodSectionFavorite _f2 = FloodSectionFavorite(
  code: _f2Code,
  name: 'Garonne aval',
  addedAt: _added,
);

final StationCode _sCode = StationCode('K447001010');
final StationCode _tCode = StationCode('O972001001');
final StationPlace _sPlace = StationPlace(_sCode);
final StationPlace _tPlace = StationPlace(_tCode);
final StationFavorite _s = StationFavorite(
  code: _sCode,
  label: 'La Loire à Blois',
  addedAt: _added,
);
final StationFavorite _t = StationFavorite(
  code: _tCode,
  label: 'La Garonne à Toulouse',
  addedAt: _added,
);
final GeoPoint _sPoint = GeoPoint(latitude: 47.58, longitude: 1.33);
final GeoPoint _tPoint = GeoPoint(latitude: 43.6, longitude: 1.43);
final Station _sStation = _station(_sCode, 'La Loire à Blois', _sPoint);
final Station _tStation = _station(_tCode, 'La Garonne à Toulouse', _tPoint);

final OndeStationCode _oCode = OndeStationCode('M3110001');
final OndePointPlace _oPlace = OndePointPlace(_oCode);
final GeoPoint _oPoint = GeoPoint(latitude: 47.79, longitude: 1.07);
final OndePointFavorite _o = OndePointFavorite(
  point: OndePoint(
    code: _oCode,
    label: 'Le Loir à Vendôme',
    latitude: 47.79,
    longitude: 1.07,
    waterCourseLabel: 'Le Loir',
    departement: null,
  ),
  addedAt: _added,
);

Station _station(StationCode code, String label, GeoPoint point) => Station(
  code: code,
  label: label,
  latitude: point.latitude,
  longitude: point.longitude,
  departement: DepartementCode('41'),
  riverLabel: null,
  inService: true,
);

FloodSection _section(FloodSectionCode code, FloodVigilanceLevel level) =>
    FloodSection(
      code: code,
      name: 'Nom publié ${code.value}',
      territoryCode: '10',
      level: level,
      lines: <List<GeoPoint>>[
        <GeoPoint>[
          GeoPoint(latitude: 44, longitude: 1),
          GeoPoint(latitude: 44.1, longitude: 1.1),
        ],
      ],
    );

FloodVigilanceMap _map(
  List<FloodSection> sections, {
  int skipped = 0,
  DateTime? at,
}) => FloodVigilanceMap(
  informationDate: at ?? _info2,
  sections: sections,
  skippedEntities: skipped,
);

AlertZone _alertZone(
  String name,
  ZoneKind kind,
  DroughtSeverity severity, [
  DateTime? decree,
]) => AlertZone(
  name: name,
  kind: kind,
  severity: severity,
  decree: RestrictionDecree(validFrom: decree ?? _decree1),
  usages: <RestrictedUsage>[],
);

KnownZone _known(
  String name,
  ZoneKind kind,
  DroughtSeverity severity, [
  DateTime? decree,
]) => KnownZone(
  name: name,
  kind: kind,
  severity: severity,
  decreeValidFrom: decree ?? _decree1,
);

/// La source des crues, qui compte ses appels ; retenue par [gate].
final class _FloodSource implements FloodVigilanceSource {
  FloodVigilanceMap? map;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<FloodVigilanceMap> current() async {
    calls++;
    await gate?.future;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return map!;
  }
}

/// La source des restrictions, qui compte ses appels point par point. Une
/// réponse est une liste de zones, ou l'échec à lever.
final class _RestrictionSource implements RestrictionSource {
  final Map<GeoPoint, Object> responses = <GeoPoint, Object>{};
  final List<GeoPoint> calls = <GeoPoint>[];
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) async {
    calls.add(point);
    _inFlight++;
    if (_inFlight > maxInFlight) {
      maxInFlight = _inFlight;
    }
    // Laisse courir un éventuel appel parallèle : il se verrait dans
    // `maxInFlight`.
    await Future<void>.delayed(Duration.zero);
    _inFlight--;
    final Object? response = responses[point];
    if (response is List<AlertZone>) {
      return ZonesAtPoint(
        point: point,
        retrievedAt: _retrieved,
        zones: response,
      );
    }
    throw response ?? StateError('aucune réponse pour $point');
  }
}

final class _Stations implements StationRepository {
  _Stations(this.byCode);

  final Map<StationCode, Station> byCode;
  int calls = 0;

  @override
  Future<Station?> findByCode(StationCode code) async {
    calls++;
    return byCode[code];
  }
}

/// Tout ce qu'une vérification touche, avec des doubles en mémoire.
final class _Fixture {
  _Fixture({
    List<Favorite> favorites = const <Favorite>[],
    List<FollowUp> followUps = const <FollowUp>[],
    Map<StationCode, Station>? stations,
  }) : favorites = InMemoryFavoriteRepository(favorites),
       followUps = InMemoryFollowUpRepository(
         FollowUpBook(followUps: followUps),
       ),
       stations = _Stations(
         stations ??
             <StationCode, Station>{_sCode: _sStation, _tCode: _tStation},
       );

  final InMemoryFavoriteRepository favorites;
  final InMemoryFollowUpRepository followUps;
  final InMemoryNoticeRepository notices = InMemoryNoticeRepository();
  final _FloodSource floods = _FloodSource();
  final _RestrictionSource restrictions = _RestrictionSource();
  final _Stations stations;
  int clockCalls = 0;

  late final FollowUpCheck check = FollowUpCheck(
    favorites: favorites,
    followUps: followUps,
    notices: notices,
    floods: floods,
    restrictions: restrictions,
    stations: stations,
    now: () {
      clockCalls++;
      return _clockValue;
    },
  );

  /// Les avis stockés, dans l'ordre (le plus récent en tête).
  List<ReceivedNotice> get storedNotices => notices.stored;

  FollowUp? storedFollowUp(FollowedPlace place) =>
      followUpOf(followUps.stored.followUps, place);

  int get writes => followUps.writeCalls + notices.writeCalls;
}

void main() {
  group('Critères 7 et 8 — aucun appel sans lieu suivi', () {
    test(
      'sans favori ni suivi : NothingFollowed, zéro appel, rien écrit',
      () async {
        final _Fixture f = _Fixture();
        expect(await f.check.run(), const NothingFollowed());
        expect(f.floods.calls, 0);
        expect(f.restrictions.calls, isEmpty);
        expect(f.stations.calls, 0);
        expect(f.writes, 0);
        expect(f.followUps.recordedChecks, isEmpty);
      },
    );

    test('des favoris sans suivi : NothingFollowed, zéro appel', () async {
      final _Fixture f = _Fixture(favorites: <Favorite>[_f1, _s, _o]);
      expect(await f.check.run(), const NothingFollowed());
      expect(f.floods.calls, 0);
      expect(f.restrictions.calls, isEmpty);
      expect(f.writes, 0);
    });

    test('stations suivies seules : la vigilance crues jamais lue ; les points '
        "un à un, dans l'ordre des favoris", () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_t, _f1, _s],
        followUps: <FollowUp>[
          DroughtFollowUp(place: _sPlace),
          DroughtFollowUp(place: _tPlace),
        ],
      );
      f.restrictions.responses[_sPoint] = <AlertZone>[];
      f.restrictions.responses[_tPoint] = <AlertZone>[];
      await f.check.run();
      expect(f.floods.calls, 0);
      expect(f.restrictions.calls, <GeoPoint>[_tPoint, _sPoint]);
      expect(f.restrictions.maxInFlight, 1);
    });

    test('un tronçon suivi seul : les restrictions jamais lues', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1, _s, _o],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.orange),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
      await f.check.run();
      expect(f.floods.calls, 1);
      expect(f.restrictions.calls, isEmpty);
      expect(f.stations.calls, 0);
    });
  });

  group('Critère 10 — « Suivi commencé » à la première lecture', () {
    test("un tronçon : le niveau publié lu, daté de l'information, sous le "
        'nom du favori ; le dernier état est enregistré', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
        ],
      );
      // Cas construit, jamais observé en production — `VC-04`.
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Rouge())]);
      expect(await f.check.run(), const CheckDone(1));
      // Aucune règle de changement ne s'applique : un seul avis.
      expect(f.storedNotices, <ReceivedNotice>[
        FloodFollowUpStarted(
          placeLabel: 'Garonne amont',
          level: const Rouge(),
          informationDate: _info2,
          threshold: FloodThreshold.jaune,
          receivedAt: _now,
        ),
      ]);
      expect(
        f.storedFollowUp(_f1Place),
        FloodFollowUp(
          place: _f1Place,
          threshold: FloodThreshold.jaune,
          lastKnown: LastKnownFloodLevel(
            level: const Rouge(),
            informationDate: _info2,
          ),
        ),
      );
    });

    test(
      'une station : les zones citées, eaux superficielles en tête',
      () async {
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_s],
          followUps: <FollowUp>[DroughtFollowUp(place: _sPlace)],
        );
        // Cas construit, jamais observé en production — `VC-04`.
        f.restrictions.responses[_sPoint] = <AlertZone>[
          _alertZone(
            'Nappe de Beauce',
            const EauxSouterraines(),
            const Alerte(),
          ),
          _alertZone('Loire amont', const EauxSuperficielles(), const Crise()),
        ];
        expect(await f.check.run(), const CheckDone(1));
        expect(f.storedNotices, <ReceivedNotice>[
          DroughtFollowUpStarted(
            placeLabel: 'La Loire à Blois',
            zones: <KnownZone>[
              _known('Loire amont', const EauxSuperficielles(), const Crise()),
              _known(
                'Nappe de Beauce',
                const EauxSouterraines(),
                const Alerte(),
              ),
            ],
            readAt: _retrieved,
            receivedAt: _now,
          ),
        ]);
        final DroughtFollowUp stored =
            f.storedFollowUp(_sPlace)! as DroughtFollowUp;
        expect(stored.series, isNull);
        expect(stored.lastKnown!.readAt, _retrieved);
        expect(stored.lastKnown!.zones, hasLength(2));
      },
    );

    test("une station sans zone : l'avis porte une liste vide", () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_s],
        followUps: <FollowUp>[DroughtFollowUp(place: _sPlace)],
      );
      f.restrictions.responses[_sPoint] = <AlertZone>[];
      expect(await f.check.run(), const CheckDone(1));
      expect(f.storedNotices, <ReceivedNotice>[
        DroughtFollowUpStarted(
          placeLabel: 'La Loire à Blois',
          zones: <KnownZone>[],
          readAt: _retrieved,
          receivedAt: _now,
        ),
      ]);
    });

    test(
      'un point ONDE : interrogé à ses coordonnées, sous son libellé',
      () async {
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_o],
          followUps: <FollowUp>[DroughtFollowUp(place: _oPlace)],
        );
        f.restrictions.responses[_oPoint] = <AlertZone>[];
        expect(await f.check.run(), const CheckDone(1));
        expect(f.restrictions.calls, <GeoPoint>[_oPoint]);
        expect(f.stations.calls, 0);
        expect(
          (f.storedNotices.single as DroughtFollowUpStarted).placeLabel,
          'Le Loir à Vendôme',
        );
      },
    );
  });

  group('Critères 11 et 12 — changement de vigilance', () {
    _Fixture floodFixture(
      FloodVigilanceLevel before,
      FloodThreshold threshold,
    ) => _Fixture(
      favorites: <Favorite>[_f1],
      followUps: <FollowUp>[
        FloodFollowUp(
          place: _f1Place,
          threshold: threshold,
          lastKnown: LastKnownFloodLevel(
            level: before,
            informationDate: _info1,
          ),
        ),
      ],
    );

    test(
      "jaune → orange avec un seuil orange : un avis daté de l'information",
      () async {
        // Cas construit, jamais observé en production — `VC-04`.
        final _Fixture f = floodFixture(const Jaune(), FloodThreshold.orange);
        f.floods.map = _map(<FloodSection>[_section(_f1Code, const Orange())]);
        expect(await f.check.run(), const CheckDone(1));
        expect(f.storedNotices, <ReceivedNotice>[
          FloodLevelChanged(
            placeLabel: 'Garonne amont',
            before: const Jaune(),
            after: const Orange(),
            informationDate: _info2,
            receivedAt: _now,
          ),
        ]);
        expect(
          (f.storedFollowUp(_f1Place)! as FloodFollowUp).lastKnown,
          LastKnownFloodLevel(level: const Orange(), informationDate: _info2),
        );
      },
    );

    test("vert → jaune avec un seuil orange : aucun avis, mais le dernier état "
        'devient le niveau lu', () async {
      final _Fixture f = floodFixture(const Vert(), FloodThreshold.orange);
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
      expect(await f.check.run(), const CheckDone(0));
      expect(f.storedNotices, isEmpty);
      expect(
        (f.storedFollowUp(_f1Place)! as FloodFollowUp).lastKnown,
        LastKnownFloodLevel(level: const Jaune(), informationDate: _info2),
      );
    });

    test('un niveau non reconnu donne un avis', () async {
      final _Fixture f = floodFixture(const Vert(), FloodThreshold.rouge);
      f.floods.map = _map(<FloodSection>[
        _section(_f1Code, const NiveauCruesInconnu(7)),
      ]);
      expect(await f.check.run(), const CheckDone(1));
      expect(f.storedNotices.single, isA<FloodLevelChanged>());
    });
  });

  group('Critère 13 — changement de zones', () {
    test('une gravité changée et une zone nouvelle : des avis nommés, '
        'eaux superficielles en tête, dans leur ordre', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_s],
        followUps: <FollowUp>[
          DroughtFollowUp(
            place: _sPlace,
            lastKnown: LastKnownZones(
              readAt: _read1,
              zones: <KnownZone>[
                _known(
                  'Loire amont',
                  const EauxSuperficielles(),
                  const Vigilance(),
                ),
                _known(
                  'Nappe de Beauce',
                  const EauxSouterraines(),
                  const Alerte(),
                ),
              ],
            ),
          ),
        ],
      );
      // Cas construit, jamais observé en production — `VC-04`.
      f.restrictions.responses[_sPoint] = <AlertZone>[
        _alertZone(
          'Nappe de Beauce',
          const EauxSouterraines(),
          const Crise(),
          _decree2,
        ),
        _alertZone(
          'Loire amont',
          const EauxSuperficielles(),
          const Alerte(),
          _decree2,
        ),
        _alertZone(
          'Cosson',
          const EauxSuperficielles(),
          const Vigilance(),
          _decree2,
        ),
      ];
      expect(await f.check.run(), const CheckDone(3));
      expect(f.storedNotices, <ReceivedNotice>[
        DroughtZoneChanged(
          placeLabel: 'La Loire à Blois',
          zoneName: 'Loire amont',
          zoneKind: const EauxSuperficielles(),
          before: const Vigilance(),
          after: const Alerte(),
          decreeValidFrom: _decree2,
          receivedAt: _now,
        ),
        DroughtZoneChanged(
          placeLabel: 'La Loire à Blois',
          zoneName: 'Cosson',
          zoneKind: const EauxSuperficielles(),
          before: null,
          after: const Vigilance(),
          decreeValidFrom: _decree2,
          receivedAt: _now,
        ),
        DroughtZoneChanged(
          placeLabel: 'La Loire à Blois',
          zoneName: 'Nappe de Beauce',
          zoneKind: const EauxSouterraines(),
          before: const Alerte(),
          after: const Crise(),
          decreeValidFrom: _decree2,
          receivedAt: _now,
        ),
      ]);
      expect(
        (f.storedFollowUp(_sPlace)! as DroughtFollowUp).lastKnown!.zones,
        hasLength(3),
      );
    });
  });

  group('Critère 14 — vérification impossible', () {
    _Fixture twoSections({FailureSeries? series}) => _Fixture(
      favorites: <Favorite>[_f2, _f1],
      followUps: <FollowUp>[
        FloodFollowUp(
          place: _f1Place,
          threshold: FloodThreshold.orange,
          lastKnown: LastKnownFloodLevel(
            level: const Jaune(),
            informationDate: _info1,
          ),
          series: series,
        ),
        FloodFollowUp(
          place: _f2Place,
          threshold: FloodThreshold.rouge,
          series: series,
        ),
      ],
    );

    test("vigilance injoignable, deux tronçons : UN avis qui nomme les deux, "
        "dans l'ordre des favoris", () async {
      final _Fixture f = twoSections();
      f.floods.error = const VigilanceInjoignable('réseau');
      expect(await f.check.run(), const CheckDone(1));
      expect(f.storedNotices, <ReceivedNotice>[
        CheckImpossible(
          source: FollowUpSource.floods,
          cause: CheckFailureCause.unreachable,
          placeLabels: <String>['Garonne aval', 'Garonne amont'],
          receivedAt: _now,
        ),
      ]);
      for (final FloodSectionPlace place in <FloodSectionPlace>[
        _f1Place,
        _f2Place,
      ]) {
        expect(
          (f.storedFollowUp(place)! as FloodFollowUp).series,
          FailureSeries.checkImpossible,
        );
      }
    });

    test('à la vérification suivante, même échec : aucun avis', () async {
      final _Fixture f = twoSections();
      f.floods.error = const VigilanceInjoignable('réseau');
      await f.check.run();
      expect(await f.check.run(), const CheckDone(0));
      expect(f.storedNotices, hasLength(1));
    });

    test('après un succès puis un échec : un avis', () async {
      final _Fixture f = twoSections(series: FailureSeries.checkImpossible);
      f.floods.map = _map(<FloodSection>[
        _section(_f1Code, const Jaune()),
        _section(_f2Code, const Jaune()),
      ]);
      await f.check.run();
      expect(
        (f.storedFollowUp(_f1Place)! as FloodFollowUp).series,
        isNull,
        reason: 'la lecture réussie ferme la série',
      );
      f.floods.error = const VigilanceRefusee(statusCode: 403, diagnostic: 'x');
      expect(await f.check.run(), const CheckDone(1));
      expect(
        f.storedNotices.first,
        CheckImpossible(
          source: FollowUpSource.floods,
          cause: CheckFailureCause.refused,
          placeLabels: <String>['Garonne aval', 'Garonne amont'],
          receivedAt: _now,
        ),
      );
    });

    test('les causes de la vigilance : refusée, illisible, et toute autre '
        'exception illisible', () async {
      final Map<Object, CheckFailureCause> cases = <Object, CheckFailureCause>{
        const VigilanceRefusee(statusCode: 400, diagnostic: 'x'):
            CheckFailureCause.refused,
        const VigilanceIllisible('x'): CheckFailureCause.unreadable,
        StateError('imprévu'): CheckFailureCause.unreadable,
      };
      for (final MapEntry<Object, CheckFailureCause> entry in cases.entries) {
        final _Fixture f = twoSections();
        f.floods.error = entry.key;
        expect(await f.check.run(), const CheckDone(1));
        expect(
          (f.storedNotices.single as CheckImpossible).cause,
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test(
      'le point A refusé, le point B répond : B est lu ; un avis nomme A seul',
      () async {
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_s, _t],
          followUps: <FollowUp>[
            DroughtFollowUp(place: _sPlace),
            DroughtFollowUp(place: _tPlace),
          ],
        );
        f.restrictions.responses[_sPoint] = const RequeteRefusee(
          statusCode: 409,
          diagnostic: 'x',
        );
        f.restrictions.responses[_tPoint] = <AlertZone>[];
        expect(await f.check.run(), const CheckDone(2));
        expect(f.restrictions.calls, <GeoPoint>[_sPoint, _tPoint]);
        expect(f.storedNotices, <ReceivedNotice>[
          CheckImpossible(
            source: FollowUpSource.drought,
            cause: CheckFailureCause.refused,
            placeLabels: <String>['La Loire à Blois'],
            receivedAt: _now,
          ),
          DroughtFollowUpStarted(
            placeLabel: 'La Garonne à Toulouse',
            zones: <KnownZone>[],
            readAt: _retrieved,
            receivedAt: _now,
          ),
        ]);
        expect(
          (f.storedFollowUp(_sPlace)! as DroughtFollowUp).series,
          FailureSeries.checkImpossible,
        );
        expect((f.storedFollowUp(_tPlace)! as DroughtFollowUp).series, isNull);
      },
    );

    test('trois causes dans la même vérification : un avis par cause, '
        'injoignable, refusée, illisible (PD4)', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_o, _t, _s],
        followUps: <FollowUp>[
          DroughtFollowUp(place: _sPlace),
          DroughtFollowUp(place: _tPlace),
          DroughtFollowUp(place: _oPlace),
        ],
      );
      f.restrictions.responses[_oPoint] = const ReponseIllisible('x');
      f.restrictions.responses[_tPoint] = const RequeteRefusee(
        statusCode: 400,
        diagnostic: 'x',
      );
      f.restrictions.responses[_sPoint] = const SourceInjoignable('x');
      expect(await f.check.run(), const CheckDone(3));
      expect(f.storedNotices, <ReceivedNotice>[
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreachable,
          placeLabels: <String>['La Loire à Blois'],
          receivedAt: _now,
        ),
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.refused,
          placeLabels: <String>['La Garonne à Toulouse'],
          receivedAt: _now,
        ),
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreadable,
          placeLabels: <String>['Le Loir à Vendôme'],
          receivedAt: _now,
        ),
      ]);
    });

    test('A injoignable et B refusé : deux avis (PD4)', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_t, _s],
        followUps: <FollowUp>[
          DroughtFollowUp(place: _sPlace),
          DroughtFollowUp(place: _tPlace),
        ],
      );
      f.restrictions.responses[_sPoint] = const SourceInjoignable('x');
      f.restrictions.responses[_tPoint] = const RequeteRefusee(
        statusCode: 404,
        diagnostic: 'x',
      );
      expect(await f.check.run(), const CheckDone(2));
      expect(f.storedNotices, <ReceivedNotice>[
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreachable,
          placeLabels: <String>['La Loire à Blois'],
          receivedAt: _now,
        ),
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.refused,
          placeLabels: <String>['La Garonne à Toulouse'],
          receivedAt: _now,
        ),
      ]);
    });

    test('toute autre exception de la source des restrictions est '
        'illisible', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_o],
        followUps: <FollowUp>[DroughtFollowUp(place: _oPlace)],
      );
      f.restrictions.responses[_oPoint] = StateError('imprévu');
      expect(await f.check.run(), const CheckDone(1));
      expect(
        f.storedNotices.single,
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreadable,
          placeLabels: <String>['Le Loir à Vendôme'],
          receivedAt: _now,
        ),
      );
    });

    test("le dernier état ne change pas pendant un échec ; la série continue "
        'sans avis', () async {
      final LastKnownZones known = LastKnownZones(
        readAt: _read1,
        zones: <KnownZone>[
          _known('Loire amont', const EauxSuperficielles(), const Alerte()),
        ],
      );
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_s],
        followUps: <FollowUp>[
          DroughtFollowUp(place: _sPlace, lastKnown: known),
        ],
      );
      f.restrictions.responses[_sPoint] = const SourceInjoignable('x');
      expect(await f.check.run(), const CheckDone(1));
      expect(
        f.storedFollowUp(_sPlace),
        DroughtFollowUp(
          place: _sPlace,
          lastKnown: known,
          series: FailureSeries.checkImpossible,
        ),
      );
      expect(await f.check.run(), const CheckDone(0));
      expect((f.storedFollowUp(_sPlace)! as DroughtFollowUp).lastKnown, known);
    });
  });

  group('Critère 15 — lieu non vérifiable', () {
    test(
      'un tronçon absent de la carte : SectionAbsent, une seule fois par série',
      () async {
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_f1],
          followUps: <FollowUp>[
            FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
          ],
        );
        f.floods.map = _map(<FloodSection>[_section(_f2Code, const Vert())]);
        expect(await f.check.run(), const CheckDone(1));
        expect(f.storedNotices, <ReceivedNotice>[
          PlaceNotVerifiable(
            placeLabel: 'Garonne amont',
            reason: SectionAbsent(_info2),
            receivedAt: _now,
          ),
        ]);
        expect(
          f.storedFollowUp(_f1Place),
          FloodFollowUp(
            place: _f1Place,
            threshold: FloodThreshold.jaune,
            series: FailureSeries.notVerifiable,
          ),
        );
        expect(await f.check.run(), const CheckDone(0));
      },
    );

    test('avec des entités écartées : SectionMaybeUnreadable, sans toucher au '
        'dernier état', () async {
      final LastKnownFloodLevel known = LastKnownFloodLevel(
        level: const Jaune(),
        informationDate: _info1,
      );
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(
            place: _f1Place,
            threshold: FloodThreshold.jaune,
            lastKnown: known,
          ),
        ],
      );
      f.floods.map = _map(<FloodSection>[], skipped: 2);
      expect(await f.check.run(), const CheckDone(1));
      expect(
        (f.storedNotices.single as PlaceNotVerifiable).reason,
        SectionMaybeUnreadable(_info2),
      );
      expect((f.storedFollowUp(_f1Place)! as FloodFollowUp).lastKnown, known);
    });

    test('une station absente du référentiel : StationAbsent, une fois par '
        'série, sans appel de la source', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_s],
        followUps: <FollowUp>[DroughtFollowUp(place: _sPlace)],
        stations: <StationCode, Station>{},
      );
      expect(await f.check.run(), const CheckDone(1));
      expect(f.storedNotices, <ReceivedNotice>[
        PlaceNotVerifiable(
          placeLabel: 'La Loire à Blois',
          reason: const StationAbsent(),
          receivedAt: _now,
        ),
      ]);
      expect(f.restrictions.calls, isEmpty);
      expect(
        (f.storedFollowUp(_sPlace)! as DroughtFollowUp).series,
        FailureSeries.notVerifiable,
      );
      expect(await f.check.run(), const CheckDone(0));
    });
  });

  group('Critère 15 bis — stockage illisible', () {
    Future<void> expectBlocked(_Fixture f) async {
      expect(await f.check.run(), const CheckBlockedByUnreadableStorage());
      expect(f.floods.calls, 0);
      expect(f.restrictions.calls, isEmpty);
      expect(f.stations.calls, 0);
      expect(f.followUps.writeCalls, 0);
      expect(f.notices.writeCalls, 0);
      expect(f.favorites.writeCalls, 0);
    }

    _Fixture followed() => _Fixture(
      favorites: <Favorite>[_f1, _s],
      followUps: <FollowUp>[
        FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
        DroughtFollowUp(place: _sPlace),
      ],
    );

    test('suivi illisible', () async {
      final _Fixture f = followed();
      f.followUps.readError = const SuiviIllisible('x');
      await expectBlocked(f);
    });

    test('avis illisibles', () async {
      final _Fixture f = followed();
      f.notices.readError = const ListeDAvisIllisible('x');
      await expectBlocked(f);
    });

    test('favoris illisibles (Q1)', () async {
      final _Fixture f = followed();
      f.favorites.readError = const ListeDeFavorisIllisible('x');
      await expectBlocked(f);
    });
  });

  group('Orphelins', () {
    test(
      "le suivi d'un favori retiré est passé dans orphans, tel qu'il a été lu",
      () async {
        final FollowUp orphan = FloodFollowUp(
          place: _f2Place,
          threshold: FloodThreshold.rouge,
          lastKnown: LastKnownFloodLevel(
            level: const Vert(),
            informationDate: _info1,
          ),
        );
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_f1],
          followUps: <FollowUp>[
            FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
            orphan,
          ],
        );
        f.floods.map = _map(<FloodSection>[_section(_f1Code, const Vert())]);
        await f.check.run();
        expect(f.followUps.recordedChecks.single.orphans, <FollowUp>[orphan]);
        expect(f.storedFollowUp(_f2Place), isNull);
      },
    );

    test('pour seul suivi un orphelin : NothingFollowed, aucun appel, '
        "l'orphelin retiré", () async {
      final FollowUp orphan = DroughtFollowUp(place: _sPlace);
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[orphan],
      );
      expect(await f.check.run(), const NothingFollowed());
      expect(f.floods.calls, 0);
      expect(f.restrictions.calls, isEmpty);
      final CheckRecord record = f.followUps.recordedChecks.single;
      expect(record.checkedAt, _now);
      expect(record.updated, isEmpty);
      expect(record.orphans, <FollowUp>[orphan]);
      expect(f.followUps.stored.followUps, isEmpty);
      expect(f.notices.writeCalls, 0);
    });

    test(
      "le retrait de l'orphelin en échec : NothingFollowed reste rendu",
      () async {
        final _Fixture f = _Fixture(
          followUps: <FollowUp>[DroughtFollowUp(place: _sPlace)],
        );
        f.followUps.writeError = const EcritureDuSuiviEnEchec('plein');
        expect(await f.check.run(), const NothingFollowed());
      },
    );

    test('un suivi illisible est ignoré et gardé', () async {
      const FollowUp unreadable = UnreadableFollowUp(raw: '{"v":99}');
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          unreadable,
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Vert())]);
      expect(await f.check.run(), const CheckDone(1));
      expect(f.followUps.recordedChecks.single.orphans, isEmpty);
      expect(f.followUps.stored.followUps.first, unreadable);
    });
  });

  test(
    'point ONDE hors plage, cas construit en contournant le codec : CheckDone, '
    "et l'avis de ce lieu est « Vérification impossible », illisible",
    () async {
      final OndePointFavorite outOfRange = OndePointFavorite(
        point: OndePoint(
          code: _oCode,
          label: 'Point hors plage',
          latitude: 120,
          longitude: 1.07,
          waterCourseLabel: null,
          departement: null,
        ),
        addedAt: _added,
      );
      final _Fixture f = _Fixture(
        favorites: <Favorite>[outOfRange, _s],
        followUps: <FollowUp>[
          DroughtFollowUp(place: _oPlace),
          DroughtFollowUp(place: _sPlace),
        ],
      );
      f.restrictions.responses[_sPoint] = <AlertZone>[];
      expect(await f.check.run(), const CheckDone(2));
      expect(f.restrictions.calls, <GeoPoint>[_sPoint]);
      expect(
        f.storedNotices.first,
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreadable,
          placeLabels: <String>['Point hors plage'],
          receivedAt: _now,
        ),
      );
    },
  );

  group('Point 8 — ordre des avis', () {
    test("le bloc crues, puis le bloc sécheresse ; « Vérification impossible » "
        "en tête de bloc, puis les lieux dans l'ordre des favoris", () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_t, _f1, _o, _f2],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f2Place, threshold: FloodThreshold.jaune),
          DroughtFollowUp(place: _oPlace),
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
          DroughtFollowUp(place: _tPlace),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f2Code, const Vert())]);
      f.restrictions.responses[_tPoint] = <AlertZone>[];
      f.restrictions.responses[_oPoint] = const SourceInjoignable('x');
      expect(await f.check.run(), const CheckDone(4));
      expect(f.storedNotices, <ReceivedNotice>[
        PlaceNotVerifiable(
          placeLabel: 'Garonne amont',
          reason: SectionAbsent(_info2),
          receivedAt: _now,
        ),
        FloodFollowUpStarted(
          placeLabel: 'Garonne aval',
          level: const Vert(),
          informationDate: _info2,
          threshold: FloodThreshold.jaune,
          receivedAt: _now,
        ),
        CheckImpossible(
          source: FollowUpSource.drought,
          cause: CheckFailureCause.unreachable,
          placeLabels: <String>['Le Loir à Vendôme'],
          receivedAt: _now,
        ),
        DroughtFollowUpStarted(
          placeLabel: 'La Garonne à Toulouse',
          zones: <KnownZone>[],
          readAt: _retrieved,
          receivedAt: _now,
        ),
      ]);
    });
  });

  group('Point 9 — écritures, les avis d’abord (PD13)', () {
    _Fixture oneSection() {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
      return f;
    }

    test("les derniers états ne s'écrivent qu'après les avis", () async {
      final _Fixture f = oneSection();
      final Completer<void> gate = Completer<void>();
      f.notices.writeGate = gate;
      final Future<CheckOutcome> outcome = f.check.run();
      await pumpEventQueue();
      expect(f.notices.writeCalls, 1);
      expect(f.followUps.writeCalls, 0);
      gate.complete();
      expect(await outcome, const CheckDone(1));
      expect(f.followUps.recordedChecks, hasLength(1));
    });

    test(
      'recordCheck en échec après des avis écrits : CheckNotRecorded(n)',
      () async {
        final _Fixture f = oneSection();
        f.followUps.writeError = const EcritureDuSuiviEnEchec('plein');
        expect(await f.check.run(), const CheckNotRecorded(1));
        expect(f.storedNotices, hasLength(1));
        expect(f.followUps.recordedChecks, isEmpty);
      },
    );

    test(
      'Review Focus 3 : les avis en échec donnent CheckNotRecorded(0), rien '
      "d'enregistré ; la vérification suivante redonne les mêmes avis",
      () async {
        final _Fixture f = oneSection();
        f.notices.writeError = const EcritureDAvisEnEchec('plein');
        expect(await f.check.run(), const CheckNotRecorded(0));
        expect(f.followUps.recordedChecks, isEmpty);
        expect(f.followUps.writeCalls, 0);
        expect(f.storedNotices, isEmpty);

        f.notices.writeError = null;
        expect(await f.check.run(), const CheckDone(1));
        expect(f.storedNotices, <ReceivedNotice>[
          FloodFollowUpStarted(
            placeLabel: 'Garonne amont',
            level: const Jaune(),
            informationDate: _info2,
            threshold: FloodThreshold.jaune,
            receivedAt: _now,
          ),
        ]);
      },
    );

    test('aucun avis : rien écrit côté avis, recordCheck posé', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(
            place: _f1Place,
            threshold: FloodThreshold.rouge,
            lastKnown: LastKnownFloodLevel(
              level: const Vert(),
              informationDate: _info1,
            ),
          ),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Vert())]);
      expect(await f.check.run(), const CheckDone(0));
      expect(f.notices.writeCalls, 0);
      expect(f.followUps.stored.lastCheckAt, _now);
    });
  });

  group('Review Focus 1 — réglage changé pendant la vérification', () {
    test("le seuil passe d'orange à rouge pendant que la source est retenue : "
        'le seuil stocké reste rouge', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(
            place: _f1Place,
            threshold: FloodThreshold.orange,
            lastKnown: LastKnownFloodLevel(
              level: const Jaune(),
              informationDate: _info1,
            ),
          ),
        ],
      );
      final Completer<void> gate = Completer<void>();
      f.floods
        ..gate = gate
        ..map = _map(<FloodSection>[_section(_f1Code, const Orange())]);
      final Future<CheckOutcome> outcome = f.check.run();
      await pumpEventQueue();
      expect(f.floods.calls, 1);
      await f.followUps.followFlood(_f1Place, FloodThreshold.rouge);
      gate.complete();
      await outcome;
      final FloodFollowUp stored = f.storedFollowUp(_f1Place)! as FloodFollowUp;
      expect(stored.threshold, FloodThreshold.rouge);
      expect(
        stored.lastKnown,
        LastKnownFloodLevel(level: const Orange(), informationDate: _info2),
      );
    });

    test('un suivi éteint pendant la vérification ne ressuscite pas', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.orange),
        ],
      );
      final Completer<void> gate = Completer<void>();
      f.floods
        ..gate = gate
        ..map = _map(<FloodSection>[_section(_f1Code, const Orange())]);
      final Future<CheckOutcome> outcome = f.check.run();
      await pumpEventQueue();
      await f.followUps.unfollow(_f1Place);
      gate.complete();
      expect(await outcome, const CheckDone(1));
      expect(f.followUps.stored.followUps, isEmpty);
    });
  });

  group('Review Focus 2 — une seule vérification à la fois', () {
    test(
      'trois run() successifs, la source retenue : un appel, le même Future ; '
      'une fois libérée, un nouveau run() relance',
      () async {
        final _Fixture f = _Fixture(
          favorites: <Favorite>[_f1],
          followUps: <FollowUp>[
            FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
          ],
        );
        final Completer<void> gate = Completer<void>();
        f.floods
          ..gate = gate
          ..map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
        final Future<CheckOutcome> first = f.check.run();
        final Future<CheckOutcome> second = f.check.run();
        await pumpEventQueue();
        final Future<CheckOutcome> third = f.check.run();
        expect(identical(first, second), isTrue);
        expect(identical(first, third), isTrue);
        expect(f.floods.calls, 1);
        gate.complete();
        expect(await first, const CheckDone(1));
        expect(f.storedNotices, hasLength(1));

        expect(await f.check.run(), const CheckDone(0));
        expect(f.floods.calls, 2);
      },
    );

    test('la garde se libère aussi après un stockage illisible', () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
        ],
      );
      f.notices.readError = const ListeDAvisIllisible('x');
      expect(await f.check.run(), const CheckBlockedByUnreadableStorage());
      f.notices.readError = null;
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
      expect(await f.check.run(), const CheckDone(1));
    });
  });

  test(
    'Review Focus 5 : vigilance injoignable, « Vérification impossible », et '
    'le dernier état connu ne change pas',
    () async {
      final LastKnownFloodLevel known = LastKnownFloodLevel(
        level: const Orange(),
        informationDate: _info1,
      );
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1],
        followUps: <FollowUp>[
          FloodFollowUp(
            place: _f1Place,
            threshold: FloodThreshold.orange,
            lastKnown: known,
          ),
        ],
      );
      f.floods.error = const VigilanceInjoignable('délai');
      expect(await f.check.run(), const CheckDone(1));
      expect(f.storedNotices.single, isA<CheckImpossible>());
      expect(
        f.storedFollowUp(_f1Place),
        FloodFollowUp(
          place: _f1Place,
          threshold: FloodThreshold.orange,
          lastKnown: known,
          series: FailureSeries.checkImpossible,
        ),
      );
    },
  );

  test(
    "l'horloge est lue une fois ; receivedAt et checkedAt valent son instant, "
    'en UTC',
    () async {
      final _Fixture f = _Fixture(
        favorites: <Favorite>[_f1, _s, _t],
        followUps: <FollowUp>[
          FloodFollowUp(place: _f1Place, threshold: FloodThreshold.jaune),
          DroughtFollowUp(place: _sPlace),
          DroughtFollowUp(place: _tPlace),
        ],
      );
      f.floods.map = _map(<FloodSection>[_section(_f1Code, const Jaune())]);
      f.restrictions.responses[_sPoint] = <AlertZone>[];
      f.restrictions.responses[_tPoint] = const SourceInjoignable('x');
      expect(await f.check.run(), const CheckDone(3));
      expect(f.clockCalls, 1);
      for (final ReceivedNotice notice in f.storedNotices) {
        final DateTime receivedAt = (notice as ReadableNotice).receivedAt;
        expect(receivedAt, _now);
        expect(receivedAt.isUtc, isTrue);
      }
      expect(f.followUps.recordedChecks.single.checkedAt, _now);
      expect(f.followUps.recordedChecks.single.checkedAt.isUtc, isTrue);
    },
  );

  group('CheckOutcome', () {
    test('égalité par valeur', () {
      expect(const CheckDone(2), const CheckDone(2));
      expect(const CheckDone(2), isNot(const CheckDone(3)));
      expect(const CheckNotRecorded(0), const CheckNotRecorded(0));
      expect(const CheckNotRecorded(0), isNot(const CheckDone(0)));
      expect(const NothingFollowed(), const NothingFollowed());
      expect(
        const CheckBlockedByUnreadableStorage(),
        const CheckBlockedByUnreadableStorage(),
      );
      expect(const CheckDone(2).hashCode, const CheckDone(2).hashCode);
    });
  });
}
