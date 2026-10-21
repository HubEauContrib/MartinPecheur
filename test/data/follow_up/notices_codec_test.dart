// Verrouille la forme stockée des avis reçus (D3 de T5) : une chaîne JSON
// versionnée, des mots propres au projet, jamais ceux d'une API. Une entrée
// illisible est gardée à l'identique ; une racine illisible lève, elle ne se
// lit jamais comme « aucun avis ».
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/follow_up/notices_codec.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 21, 8, 30);
final DateTime _t1 = DateTime.utc(2026, 10, 20, 6);

List<ReceivedNotice> _roundTrip(List<ReceivedNotice> notices) =>
    decodeNotices(encodeNotices(notices));

List<Object?> _entries(String stored) =>
    (jsonDecode(stored) as Map<String, Object?>)['avis']! as List<Object?>;

Map<String, Object?> _entry(ReceivedNotice notice) =>
    _entries(encodeNotices(<ReceivedNotice>[notice])).single!
        as Map<String, Object?>;

String _root(List<String> entries) =>
    '{"version":1,"avis":[${entries.join(',')}]}';

void main() {
  group('decodeNotices', () {
    test('rien de stocké : une liste vide', () {
      expect(decodeNotices(null), isEmpty);
    });

    test('la version écrite est 1, sous la racine avis', () {
      expect(noticesFormatVersion, 1);
      final Map<String, Object?> root = jsonDecode(
        encodeNotices(const <ReceivedNotice>[]),
      ) as Map<String, Object?>;
      expect(root, <String, Object?>{'version': 1, 'avis': <Object?>[]});
    });

    group('une racine illisible lève ListeDAvisIllisible', () {
      const List<String> roots = <String>[
        'pas du json',
        '[]',
        '"avis"',
        '{"avis":[]}',
        '{"version":"1","avis":[]}',
        '{"version":0,"avis":[]}',
        '{"version":2,"avis":[]}',
        '{"version":1}',
        '{"version":1,"avis":{}}',
      ];
      for (final String stored in roots) {
        test(stored, () {
          expect(
            () => decodeNotices(stored),
            throwsA(isA<ListeDAvisIllisible>()),
          );
        });
      }
    });
  });

  group('aller-retour des six branches', () {
    final List<ReadableNotice> notices = <ReadableNotice>[
      FloodFollowUpStarted(
        placeLabel: 'La Seine à Paris',
        level: const Orange(),
        informationDate: _t0,
        threshold: FloodThreshold.jaune,
        receivedAt: _t0,
      ),
      DroughtFollowUpStarted(
        placeLabel: 'Station K447001001',
        zones: <KnownZone>[
          KnownZone(
            name: 'Seine amont',
            kind: const EauxSuperficielles(),
            severity: const AlerteRenforcee(),
            decreeValidFrom: _t1,
          ),
          KnownZone(
            name: 'Nappe',
            kind: const EauxSouterraines(),
            severity: const Crise(),
            decreeValidFrom: _t1,
          ),
        ],
        readAt: _t0,
        receivedAt: _t0,
        read: true,
      ),
      DroughtFollowUpStarted(
        placeLabel: 'Point ONDE',
        zones: const <KnownZone>[],
        readAt: _t0,
        receivedAt: _t0,
      ),
      FloodLevelChanged(
        placeLabel: 'La Seine à Paris',
        before: const Jaune(),
        after: const Rouge(),
        informationDate: _t0,
        receivedAt: _t0,
      ),
      DroughtZoneChanged(
        placeLabel: 'Station K447001001',
        zoneName: 'Seine amont',
        zoneKind: const EauPotable(),
        before: const Vigilance(),
        after: const Alerte(),
        decreeValidFrom: _t1,
        receivedAt: _t0,
      ),
      DroughtZoneChanged(
        placeLabel: 'Station K447001001',
        zoneName: 'Seine amont',
        zoneKind: const EauxSuperficielles(),
        before: null,
        after: const AlerteRenforcee(),
        decreeValidFrom: _t1,
        receivedAt: _t0,
      ),
      DroughtZoneChanged(
        placeLabel: 'Station K447001001',
        zoneName: 'Seine amont',
        zoneKind: const EauxSuperficielles(),
        before: const Crise(),
        after: null,
        decreeValidFrom: null,
        receivedAt: _t0,
      ),
      CheckImpossible(
        source: FollowUpSource.floods,
        cause: CheckFailureCause.refused,
        placeLabels: const <String>['A', 'B'],
        receivedAt: _t0,
      ),
      PlaceNotVerifiable(
        placeLabel: 'La Seine à Paris',
        reason: SectionAbsent(_t1),
        receivedAt: _t0,
      ),
      PlaceNotVerifiable(
        placeLabel: 'La Seine à Paris',
        reason: SectionMaybeUnreadable(_t1),
        receivedAt: _t0,
        read: true,
      ),
      PlaceNotVerifiable(
        placeLabel: 'Station K447001001',
        reason: const StationAbsent(),
        receivedAt: _t0,
      ),
    ];

    test('chaque avis revient égal à lui-même, dans l\'ordre', () {
      expect(_roundTrip(notices), notices);
    });

    test('chaque seuil, source, cause et raison fait l\'aller-retour', () {
      final List<ReadableNotice> every = <ReadableNotice>[
        for (final FloodThreshold threshold in FloodThreshold.values)
          FloodFollowUpStarted(
            placeLabel: 'T',
            level: const Vert(),
            informationDate: _t0,
            threshold: threshold,
            receivedAt: _t0,
          ),
        for (final FollowUpSource source in FollowUpSource.values)
          for (final CheckFailureCause cause in CheckFailureCause.values)
            CheckImpossible(
              source: source,
              cause: cause,
              placeLabels: const <String>['A'],
              receivedAt: _t0,
            ),
        for (final NotVerifiableReason reason in <NotVerifiableReason>[
          SectionAbsent(_t1),
          SectionMaybeUnreadable(_t1),
          const StationAbsent(),
        ])
          PlaceNotVerifiable(placeLabel: 'T', reason: reason, receivedAt: _t0),
      ];
      expect(_roundTrip(every), every);
    });

    test('les inconnus gardent leur brut', () {
      final List<ReadableNotice> unknowns = <ReadableNotice>[
        FloodLevelChanged(
          placeLabel: 'T',
          before: const NiveauCruesInconnu(5),
          after: const NiveauCruesInconnu('5'),
          informationDate: _t0,
          receivedAt: _t0,
        ),
        DroughtZoneChanged(
          placeLabel: 'T',
          zoneName: 'Z',
          zoneKind: const TypeZoneInconnu('x'),
          before: const GraviteInconnue(null),
          after: const GraviteInconnue('super'),
          decreeValidFrom: _t1,
          receivedAt: _t0,
        ),
        FloodFollowUpStarted(
          placeLabel: 'T',
          level: const NiveauCruesInconnu(null),
          informationDate: _t0,
          threshold: FloodThreshold.rouge,
          receivedAt: _t0,
        ),
      ];
      final List<ReceivedNotice> back = _roundTrip(unknowns);
      expect(back, unknowns);
      final FloodLevelChanged changed = back.first as FloodLevelChanged;
      expect((changed.before as NiveauCruesInconnu).raw, 5);
      expect((changed.after as NiveauCruesInconnu).raw, '5');
    });

    test('les types stockés sont les mots du projet', () {
      expect(
        <Object?>[
          for (final ReadableNotice notice in notices) _entry(notice)['type'],
        ],
        <String>[
          'suivi-commence-crues',
          'suivi-commence-secheresse',
          'suivi-commence-secheresse',
          'crues-change',
          'zone-secheresse-change',
          'zone-secheresse-change',
          'zone-secheresse-change',
          'verification-impossible',
          'lieu-non-verifiable',
          'lieu-non-verifiable',
          'lieu-non-verifiable',
        ],
      );
    });

    test('chaque entrée porte recu_le (UTC) et lu', () {
      final Map<String, Object?> entry = _entry(notices[1]);
      expect(entry['recu_le'], '2026-10-21T08:30:00.000Z');
      expect(entry['lu'], isTrue);
      expect(_entry(notices.first)['lu'], isFalse);
    });

    test('source, cause et raison s\'écrivent en mots du projet', () {
      final CheckImpossible impossible = CheckImpossible(
        source: FollowUpSource.drought,
        cause: CheckFailureCause.unreadable,
        placeLabels: const <String>['A'],
        receivedAt: _t0,
      );
      expect(_entry(impossible)['source'], 'secheresse');
      expect(_entry(impossible)['cause'], 'illisible');
      final CheckImpossible unreachable = CheckImpossible(
        source: FollowUpSource.floods,
        cause: CheckFailureCause.unreachable,
        placeLabels: const <String>[],
        receivedAt: _t0,
      );
      expect(_entry(unreachable)['source'], 'crues');
      expect(_entry(unreachable)['cause'], 'injoignable');
      expect(_entry(notices[7])['cause'], 'refusee');

      String reasonOf(NotVerifiableReason reason) => jsonEncode(
        _entry(
          PlaceNotVerifiable(placeLabel: 'T', reason: reason, receivedAt: _t0),
        ),
      );
      expect(reasonOf(SectionAbsent(_t1)), contains('troncon-absent'));
      expect(
        reasonOf(SectionMaybeUnreadable(_t1)),
        contains('troncon-peut-etre-illisible'),
      );
      expect(reasonOf(const StationAbsent()), contains('station-absente'));
    });

    test('aucun mot d\'API dans le JSON écrit', () {
      final String written = encodeNotices(notices);
      expect(written, contains('alerte-renforcee'));
      expect(written, isNot(contains('alerte_renforcee')));
      expect(written, isNot(contains('NivInfViCr')));
      expect(written, isNot(contains('niveauGravite')));
    });
  });

  group('une entrée illisible est gardée à sa place', () {
    final List<String> unreadables = <String>[
      '{"z":[1,2,{"a":null}]}',
      '5',
      '"texte"',
      '[]',
      'null',
      '{"type":"inconnu-de-cette-version","recu_le":"2026-10-21T08:30:00.000Z",'
          '"lu":false}',
      '{"type":"crues-change","recu_le":"2026-10-21T08:30:00.000Z","lu":false}',
      '{"type":"crues-change","recu_le":"2026-10-21T08:30:00","lu":false,'
          '"lieu":"T","avant":"jaune","apres":"rouge",'
          '"information":"2026-10-21T08:30:00.000Z"}',
      '{"type":"crues-change","lu":false,"lieu":"T","avant":"jaune",'
          '"apres":"rouge","information":"2026-10-21T08:30:00.000Z"}',
      '{"type":"crues-change","recu_le":"2026-10-21T08:30:00.000Z","lu":"non",'
          '"lieu":"T","avant":"jaune","apres":"rouge",'
          '"information":"2026-10-21T08:30:00.000Z"}',
      '{"type":"crues-change","recu_le":"2026-10-21T08:30:00.000Z","lu":false,'
          '"lieu":"T","avant":"bleu","apres":"rouge",'
          '"information":"2026-10-21T08:30:00.000Z"}',
      '{"type":"verification-impossible","recu_le":"2026-10-21T08:30:00.000Z",'
          '"lu":false,"source":"meteo","cause":"refusee","lieux":[]}',
      '{"type":"lieu-non-verifiable","recu_le":"2026-10-21T08:30:00.000Z",'
          '"lu":false,"lieu":"T","raison":{"type":"autre"}}',
    ];

    for (final String raw in unreadables) {
      test(raw, () {
        final List<ReceivedNotice> notices = decodeNotices(
          _root(<String>[raw]),
        );
        expect(notices, <ReceivedNotice>[
          UnreadableNotice(raw: jsonEncode(jsonDecode(raw))),
        ]);
        expect(
          jsonDecode(encodeNotices(notices)),
          jsonDecode(_root(<String>[raw])),
        );
      });
    }

    test('au milieu d\'une liste lisible, à sa place', () {
      final ReadableNotice first = PlaceNotVerifiable(
        placeLabel: 'A',
        reason: const StationAbsent(),
        receivedAt: _t0,
      );
      final ReadableNotice last = PlaceNotVerifiable(
        placeLabel: 'B',
        reason: const StationAbsent(),
        receivedAt: _t1,
      );
      const UnreadableNotice unreadable = UnreadableNotice(raw: '{"z":1}');
      expect(
        _roundTrip(<ReceivedNotice>[first, unreadable, last]),
        <ReceivedNotice>[first, unreadable, last],
      );
    });
  });
}
