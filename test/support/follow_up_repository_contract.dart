// Le contrat de FollowUpRepository (M2 de T5) : les cas que tout dépôt tient,
// le double en mémoire comme le dépôt réel (D2). Il ne dépend que du port.
//
// `createSeeded` est requis : le port ne sait pas écrire un suivi illisible, le
// dépôt réel le sème donc par sa chaîne brute, et le cas qui le garde ne doit
// pas disparaître sans bruit.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/station/station.dart';

final FloodSectionPlace _a = FloodSectionPlace(FloodSectionCode('LC135'));
final FloodSectionPlace _b = FloodSectionPlace(FloodSectionCode('LC200'));
final StationPlace _station = StationPlace(StationCode('K447001001'));
final OndePointPlace _onde = OndePointPlace(OndeStationCode('K4640001'));
final DateTime _t0 = DateTime.utc(2026, 10, 21, 8);
final DateTime _t1 = DateTime.utc(2026, 10, 21, 9);

LastKnownFloodLevel _level(FloodVigilanceLevel level) =>
    LastKnownFloodLevel(level: level, informationDate: _t0);

FloodFollowUp _flood(
  FloodSectionPlace place,
  FloodThreshold threshold, {
  LastKnownFloodLevel? lastKnown,
  FailureSeries? series,
}) => FloodFollowUp(
  place: place,
  threshold: threshold,
  lastKnown: lastKnown,
  series: series,
);

FollowUp? _find(FollowUpBook book, FollowedPlace place) =>
    followUpOf(book.followUps, place);

CheckRecord _record({
  DateTime? checkedAt,
  List<FollowUp> updated = const <FollowUp>[],
  List<FollowUp> orphans = const <FollowUp>[],
}) => CheckRecord(
  checkedAt: checkedAt ?? _t1,
  updated: updated,
  orphans: orphans,
);

/// Pose les cas du contrat. [createSeeded] rend un dépôt qui
/// contient déjà le livre donné (dont un suivi illisible, placé en tête).
void followUpRepositoryContract(
  Future<FollowUpRepository> Function() create, {
  required Future<FollowUpRepository> Function(FollowUpBook initial)
  createSeeded,
}) {
  group('contrat de FollowUpRepository', () {
    late FollowUpRepository repository;

    setUp(() async {
      repository = await create();
    });

    test('un livre vide au départ', () async {
      final FollowUpBook book = await repository.read();
      expect(book.followUps, isEmpty);
      expect(book.lastCheckAt, isNull);
    });

    test('followFlood crée le suivi', () async {
      await repository.followFlood(_a, FloodThreshold.orange);
      final FollowUpBook book = await repository.read();
      expect(book.followUps, <FollowUp>[_flood(_a, FloodThreshold.orange)]);
    });

    test('followFlood avec un autre seuil garde lastKnown et series', () async {
      await repository.followFlood(_a, FloodThreshold.jaune);
      await repository.recordCheck(
        _record(
          checkedAt: _t0,
          updated: <FollowUp>[
            _flood(
              _a,
              FloodThreshold.jaune,
              lastKnown: _level(const Orange()),
              series: FailureSeries.checkImpossible,
            ),
          ],
        ),
      );
      await repository.followFlood(_a, FloodThreshold.rouge);
      final FollowUpBook book = await repository.read();
      expect(book.followUps, hasLength(1));
      expect(
        book.followUps.single,
        _flood(
          _a,
          FloodThreshold.rouge,
          lastKnown: _level(const Orange()),
          series: FailureSeries.checkImpossible,
        ),
      );
    });

    test("followDrought deux fois ne crée qu'une entrée", () async {
      await repository.followDrought(_station);
      await repository.followDrought(_station);
      await repository.followDrought(_onde);
      final FollowUpBook book = await repository.read();
      expect(book.followUps, hasLength(2));
      expect(_find(book, _station), isA<DroughtFollowUp>());
      expect(_find(book, _onde), isA<DroughtFollowUp>());
    });

    test('unfollow retire le suivi, et sans effet si absent', () async {
      await repository.followFlood(_a, FloodThreshold.jaune);
      await repository.followDrought(_station);
      await repository.unfollow(_a);
      await repository.unfollow(_b);
      final FollowUpBook book = await repository.read();
      expect(_find(book, _a), isNull);
      expect(_find(book, _station), isNotNull);
    });

    group('recordCheck', () {
      test('reporte le dernier état et la série', () async {
        await repository.followFlood(_a, FloodThreshold.jaune);
        await repository.followDrought(_station);
        final LastKnownZones zones = LastKnownZones(
          readAt: _t0,
          zones: <KnownZone>[
            KnownZone(
              name: 'Loire',
              kind: const EauxSuperficielles(),
              severity: const Alerte(),
              decreeValidFrom: _t0,
            ),
          ],
        );
        await repository.recordCheck(
          _record(
            updated: <FollowUp>[
              _flood(
                _a,
                FloodThreshold.jaune,
                lastKnown: _level(const Jaune()),
              ),
              DroughtFollowUp(
                place: _station,
                lastKnown: zones,
                series: FailureSeries.notVerifiable,
              ),
            ],
          ),
        );
        final FollowUpBook book = await repository.read();
        expect(
          _find(book, _a),
          _flood(_a, FloodThreshold.jaune, lastKnown: _level(const Jaune())),
        );
        expect(
          _find(book, _station),
          DroughtFollowUp(
            place: _station,
            lastKnown: zones,
            series: FailureSeries.notVerifiable,
          ),
        );
      });

      test('garde le seuil stocké quand updated en porte un autre', () async {
        await repository.followFlood(_a, FloodThreshold.jaune);
        // L'usager passe au rouge pendant une vérification qui portait jaune.
        await repository.followFlood(_a, FloodThreshold.rouge);
        await repository.recordCheck(
          _record(
            updated: <FollowUp>[
              _flood(
                _a,
                FloodThreshold.jaune,
                lastKnown: _level(const Orange()),
              ),
            ],
          ),
        );
        expect(
          _find(await repository.read(), _a),
          _flood(_a, FloodThreshold.rouge, lastKnown: _level(const Orange())),
        );
      });

      test('ignore un lieu éteint entre-temps', () async {
        await repository.followFlood(_a, FloodThreshold.jaune);
        await repository.unfollow(_a);
        await repository.recordCheck(
          _record(
            updated: <FollowUp>[
              _flood(
                _a,
                FloodThreshold.jaune,
                lastKnown: _level(const Jaune()),
              ),
            ],
          ),
        );
        expect((await repository.read()).followUps, isEmpty);
      });

      test('retire un orphelin resté égal à sa lecture', () async {
        await repository.followFlood(_a, FloodThreshold.jaune);
        final FollowUpBook read = await repository.read();
        await repository.recordCheck(_record(orphans: read.followUps));
        expect((await repository.read()).followUps, isEmpty);
      });

      test('garde un orphelin remplacé par un suivi neuf', () async {
        await repository.followFlood(_a, FloodThreshold.jaune);
        await repository.recordCheck(
          _record(
            checkedAt: _t0,
            updated: <FollowUp>[
              _flood(
                _a,
                FloodThreshold.jaune,
                lastKnown: _level(const Jaune()),
              ),
            ],
          ),
        );
        final FollowUpBook read = await repository.read();
        // Pendant la vérification : le suivi est éteint, puis recréé à neuf.
        await repository.unfollow(_a);
        await repository.followFlood(_a, FloodThreshold.jaune);
        await repository.recordCheck(_record(orphans: read.followUps));
        expect((await repository.read()).followUps, <FollowUp>[
          _flood(_a, FloodThreshold.jaune),
        ]);
      });

      test('pose lastCheckAt', () async {
        await repository.recordCheck(_record());
        expect((await repository.read()).lastCheckAt, _t1);
      });
    });

    test('clear vide le livre', () async {
      await repository.followFlood(_a, FloodThreshold.jaune);
      await repository.recordCheck(_record());
      await repository.clear();
      final FollowUpBook book = await repository.read();
      expect(book.followUps, isEmpty);
      expect(book.lastCheckAt, isNull);
    });

    test(
      "un suivi illisible survit à followFlood d'un autre lieu, à l'identique",
      () async {
        final FollowUpRepository seeded = await createSeeded(
          FollowUpBook(
            followUps: <FollowUp>[const UnreadableFollowUp(raw: '{"z":1}')],
          ),
        );
        await seeded.followFlood(_a, FloodThreshold.jaune);
        final FollowUpBook book = await seeded.read();
        expect(book.followUps, hasLength(2));
        expect(book.followUps.first, const UnreadableFollowUp(raw: '{"z":1}'));
        expect(
          book.followUps.whereType<UnreadableFollowUp>().single,
          const UnreadableFollowUp(raw: '{"z":1}'),
        );
        expect(_find(book, _a), isNotNull);
      },
    );
  });
}
