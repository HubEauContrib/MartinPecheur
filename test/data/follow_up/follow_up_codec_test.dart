// Verrouille la forme stockée des suivis (D2 de T5) : une chaîne JSON
// versionnée, des mots propres au projet, jamais ceux d'une API. Une entrée
// illisible est gardée à l'identique ; une racine illisible lève, elle ne se
// lit jamais comme « aucun suivi ».
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/follow_up/follow_up_codec.dart';
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

final DateTime _t0 = DateTime.utc(2026, 10, 21, 8, 30);
final DateTime _t1 = DateTime.utc(2026, 10, 20, 6);

FloodSectionPlace _section(String code) =>
    FloodSectionPlace(FloodSectionCode(code));

FloodFollowUp _flood(
  FloodThreshold threshold,
  FloodVigilanceLevel? level, {
  FailureSeries? series,
}) => FloodFollowUp(
  place: _section('LC135'),
  threshold: threshold,
  lastKnown: level == null
      ? null
      : LastKnownFloodLevel(level: level, informationDate: _t0),
  series: series,
);

KnownZone _zone(String name, ZoneKind kind, DroughtSeverity severity) =>
    KnownZone(name: name, kind: kind, severity: severity, decreeValidFrom: _t1);

/// Encode puis décode : l'aller-retour d'un livre.
FollowUpBook _roundTrip(FollowUpBook book) =>
    decodeFollowUps(encodeFollowUps(book));

void main() {
  group('decodeFollowUps', () {
    test('rien de stocké : un livre vide', () {
      final FollowUpBook book = decodeFollowUps(null);
      expect(book.followUps, isEmpty);
      expect(book.lastCheckAt, isNull);
    });

    test('la version écrite est 1', () {
      expect(followUpsFormatVersion, 1);
      final Map<String, Object?> root = jsonDecode(
        encodeFollowUps(FollowUpBook(followUps: <FollowUp>[])),
      ) as Map<String, Object?>;
      expect(root['version'], 1);
      expect(root['derniere_verification'], isNull);
      expect(root['suivis'], isEmpty);
    });
  });

  group('aller-retour', () {
    test('chaque seuil, chaque niveau connu, la série et la date', () {
      final List<FollowUp> followUps = <FollowUp>[
        for (final FloodThreshold t in FloodThreshold.values) _flood(t, null),
        _flood(FloodThreshold.jaune, const Vert()),
        _flood(FloodThreshold.jaune, const Jaune()),
        _flood(FloodThreshold.orange, const Orange()),
        _flood(FloodThreshold.rouge, const Rouge()),
        _flood(
          FloodThreshold.rouge,
          const Rouge(),
          series: FailureSeries.checkImpossible,
        ),
        _flood(FloodThreshold.rouge, null, series: FailureSeries.notVerifiable),
      ];
      final FollowUpBook back = _roundTrip(
        FollowUpBook(followUps: followUps, lastCheckAt: _t0),
      );
      expect(back.followUps, followUps);
      expect(back.lastCheckAt, _t0);
      expect(back.lastCheckAt!.isUtc, isTrue);
    });

    test('un niveau inconnu : les bruts 5 et "5" restent distincts', () {
      final FollowUp numeric = _flood(
        FloodThreshold.jaune,
        const NiveauCruesInconnu(5),
      );
      final FollowUp text = _flood(
        FloodThreshold.jaune,
        const NiveauCruesInconnu('5'),
      );
      final FollowUp none = _flood(
        FloodThreshold.jaune,
        const NiveauCruesInconnu(null),
      );
      final FollowUpBook back = _roundTrip(
        FollowUpBook(followUps: <FollowUp>[numeric, text, none]),
      );
      expect(back.followUps, <FollowUp>[numeric, text, none]);
      expect(back.followUps[0] == back.followUps[1], isFalse);
      final FloodFollowUp first = back.followUps[0] as FloodFollowUp;
      expect((first.lastKnown!.level as NiveauCruesInconnu).raw, isA<int>());
      final FloodFollowUp second = back.followUps[1] as FloodFollowUp;
      expect(
        (second.lastKnown!.level as NiveauCruesInconnu).raw,
        isA<String>(),
      );
    });

    test('un lieu station, un lieu ONDE (verbatim), les zones connues', () {
      final DroughtFollowUp station = DroughtFollowUp(
        place: StationPlace(StationCode('K447001001')),
        lastKnown: LastKnownZones(
          readAt: _t0,
          zones: <KnownZone>[
            _zone('Loire', const EauxSuperficielles(), const Vigilance()),
            _zone('Nappe', const EauxSouterraines(), const Alerte()),
            _zone('Réseau', const EauPotable(), const AlerteRenforcee()),
            _zone('Ailleurs', const EauxSuperficielles(), const Crise()),
          ],
        ),
        series: FailureSeries.checkImpossible,
      );
      final DroughtFollowUp onde = DroughtFollowUp(
        place: OndePointPlace(OndeStationCode(' O968 5312 ')),
        lastKnown: LastKnownZones(readAt: _t0, zones: const <KnownZone>[]),
      );
      final DroughtFollowUp bare = DroughtFollowUp(
        place: OndePointPlace(OndeStationCode('X1')),
      );
      final FollowUpBook back = _roundTrip(
        FollowUpBook(followUps: <FollowUp>[station, onde, bare]),
      );
      expect(back.followUps, <FollowUp>[station, onde, bare]);
      final DroughtFollowUp backOnde = back.followUps[1] as DroughtFollowUp;
      expect((backOnde.place as OndePointPlace).code.value, ' O968 5312 ');
    });

    test('gravité et type de zone inconnus, bruts nuls compris', () {
      final DroughtFollowUp follow = DroughtFollowUp(
        place: StationPlace(StationCode('K447001001')),
        lastKnown: LastKnownZones(
          readAt: _t0,
          zones: <KnownZone>[
            _zone(
              'A',
              const TypeZoneInconnu('mer'),
              const GraviteInconnue('x'),
            ),
            _zone(
              'B',
              const TypeZoneInconnu(null),
              const GraviteInconnue(null),
            ),
          ],
        ),
      );
      final FollowUpBook back = _roundTrip(
        FollowUpBook(followUps: <FollowUp>[follow]),
      );
      expect(back.followUps.single, follow);
      final List<KnownZone> zones =
          (back.followUps.single as DroughtFollowUp).lastKnown!.zones;
      expect((zones[0].kind as TypeZoneInconnu).rawValue, 'mer');
      expect((zones[1].severity as GraviteInconnue).rawValue, isNull);
    });
  });

  group('mots du stockage', () {
    test("mots propres au projet, aucun mot d'API", () {
      final String json = encodeFollowUps(
        FollowUpBook(
          followUps: <FollowUp>[
            _flood(FloodThreshold.orange, const Orange()),
            DroughtFollowUp(
              place: StationPlace(StationCode('K447001001')),
              lastKnown: LastKnownZones(
                readAt: _t0,
                zones: <KnownZone>[
                  _zone('Z', const EauPotable(), const AlerteRenforcee()),
                ],
              ),
            ),
          ],
          lastCheckAt: _t0,
        ),
      );
      expect(json, contains('"type":"crues"'));
      expect(json, contains('"type":"secheresse"'));
      expect(json, contains('"seuil":"orange"'));
      expect(json, contains('"alerte-renforcee"'));
      expect(json, contains('"eau-potable"'));
      expect(json, isNot(contains('alerte_renforcee')));
      expect(json, isNot(contains('NivInfViCr')));
      expect(json, isNot(contains('niveauGravite')));
    });

    test('les noms de série', () {
      final String json = encodeFollowUps(
        FollowUpBook(
          followUps: <FollowUp>[
            _flood(
              FloodThreshold.jaune,
              null,
              series: FailureSeries.checkImpossible,
            ),
            _flood(
              FloodThreshold.jaune,
              null,
              series: FailureSeries.notVerifiable,
            ),
          ],
        ),
      );
      expect(json, contains('"verification-impossible"'));
      expect(json, contains('"non-verifiable"'));
    });
  });

  group('entrée illisible', () {
    String root(List<String> entries) =>
        '{"version":1,"derniere_verification":null,'
        '"suivis":[${entries.join(',')}]}';

    const List<String> unreadable = <String>[
      '{"z":1}',
      '5',
      '"texte"',
      'null',
      '{"type":"inconnu","code":"LC135"}',
      '{"type":"crues","code":"LC135","seuil":"violet","dernier":null}',
      '{"type":"crues","code":"","seuil":"jaune"}',
      '{"type":"crues","code":"LC135","seuil":"jaune","serie":"autre"}',
      '{"type":"crues","code":"LC135","seuil":"jaune","dernier":'
          '{"niveau":"bleu","information":"2026-10-21T08:30:00.000Z"}}',
      '{"type":"crues","code":"LC135","seuil":"jaune","dernier":'
          '{"niveau":"vert","information":"2026-10-21T08:30:00.000"}}',
      '{"type":"secheresse","lieu":{"type":"station","code":"court"}}',
      '{"type":"secheresse","lieu":{"type":"autre","code":"K447001001"}}',
      '{"type":"secheresse","lieu":{"type":"onde","code":"  "}}',
    ];

    for (final String entry in unreadable) {
      test('gardée telle quelle, à sa place : $entry', () {
        final String stored = root(<String>[
          '{"type":"crues","code":"LC135","seuil":"jaune"}',
          entry,
        ]);
        final FollowUpBook book = decodeFollowUps(stored);
        expect(book.followUps, hasLength(2));
        expect(book.followUps.first, isA<FloodFollowUp>());
        expect(book.followUps.last, isA<UnreadableFollowUp>());
        expect(
          jsonDecode((book.followUps.last as UnreadableFollowUp).raw),
          jsonDecode(entry),
        );
        final Map<String, Object?> back =
            jsonDecode(encodeFollowUps(book)) as Map<String, Object?>;
        final List<Object?> entries = back['suivis']! as List<Object?>;
        expect(entries.last, jsonDecode(entry));
      });
    }

    test('une entrée à nombre hors plage lève, elle ne se perd pas', () {
      expect(
        () => decodeFollowUps(root(<String>['{"z":1e999}'])),
        throwsA(isA<SuiviIllisible>()),
      );
    });
  });

  group('racine illisible', () {
    const List<String> roots = <String>[
      'pas du json',
      '',
      '[]',
      '5',
      'null',
      '{}',
      '{"suivis":[]}',
      '{"version":"1","suivis":[]}',
      '{"version":1.5,"suivis":[]}',
      '{"version":0,"suivis":[]}',
      '{"version":2,"derniere_verification":null,"suivis":[]}',
      '{"version":1,"derniere_verification":null}',
      '{"version":1,"derniere_verification":null,"suivis":{}}',
      '{"version":1,"derniere_verification":5,"suivis":[]}',
      '{"version":1,"derniere_verification":"hier","suivis":[]}',
      '{"version":1,"derniere_verification":"2026-10-21T08:30:00","suivis":[]}',
    ];

    for (final String stored in roots) {
      test('lève SuiviIllisible : $stored', () {
        expect(() => decodeFollowUps(stored), throwsA(isA<SuiviIllisible>()));
      });
    }
  });
}
