// Les avis reçus (M3 de T5, PD3) : un avis illisible à part, et six branches
// lisibles, chacune d'une seule échelle (BR-008). Égalités par valeur ; un
// niveau ou une gravité inconnus s'égalent par leur brut.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

final DateTime _info = DateTime.utc(2026, 10, 21, 6);
final DateTime _received = DateTime.utc(2026, 10, 21, 8);
final DateTime _decree = DateTime.utc(2026, 7, 1);

List<ReadableNotice> _oneOfEach() => <ReadableNotice>[
  FloodFollowUpStarted(
    placeLabel: 'Loire à Orléans',
    level: const Jaune(),
    informationDate: _info,
    threshold: FloodThreshold.orange,
    receivedAt: _received,
  ),
  DroughtFollowUpStarted(
    placeLabel: 'Station K447001001',
    zones: <KnownZone>[
      KnownZone(
        name: 'Loire',
        kind: const EauxSuperficielles(),
        severity: const Alerte(),
        decreeValidFrom: _decree,
      ),
    ],
    readAt: _received,
    receivedAt: _received,
  ),
  FloodLevelChanged(
    placeLabel: 'Loire à Orléans',
    before: const Jaune(),
    after: const Orange(),
    informationDate: _info,
    receivedAt: _received,
  ),
  DroughtZoneChanged(
    placeLabel: 'Station K447001001',
    zoneName: 'Loire',
    zoneKind: const EauxSuperficielles(),
    before: const Alerte(),
    after: const Crise(),
    decreeValidFrom: _decree,
    receivedAt: _received,
  ),
  CheckImpossible(
    source: FollowUpSource.floods,
    cause: CheckFailureCause.unreachable,
    placeLabels: <String>['Loire à Orléans'],
    receivedAt: _received,
  ),
  PlaceNotVerifiable(
    placeLabel: 'Loire à Orléans',
    reason: SectionAbsent(_info),
    receivedAt: _received,
  ),
];

void main() {
  group('ReadableNotice', () {
    test('six branches, non lues par défaut, datées de leur réception', () {
      final List<ReadableNotice> notices = _oneOfEach();
      expect(notices, hasLength(6));
      for (final ReadableNotice notice in notices) {
        expect(notice.read, isFalse);
        expect(notice.receivedAt, _received);
      }
    });

    test('asRead rend la même valeur, lue', () {
      for (final ReadableNotice notice in _oneOfEach()) {
        final ReadableNotice read = notice.asRead();
        expect(read.read, isTrue);
        expect(read.runtimeType, notice.runtimeType);
        expect(read.receivedAt, notice.receivedAt);
        expect(read, isNot(notice));
        expect(read.asRead(), read);
      }
    });

    test('égalité par valeur, branche par branche', () {
      final List<ReadableNotice> a = _oneOfEach();
      final List<ReadableNotice> b = _oneOfEach();
      for (int i = 0; i < a.length; i++) {
        expect(a[i], b[i]);
        expect(a[i].hashCode, b[i].hashCode);
        for (int j = 0; j < b.length; j++) {
          if (i != j) {
            expect(a[i], isNot(b[j]));
          }
        }
      }
    });

    test('un niveau inconnu à brut Map s’égale par son encodage', () {
      FloodLevelChanged changed(Object? raw) => FloodLevelChanged(
        placeLabel: 'Loire à Orléans',
        before: const Jaune(),
        after: NiveauCruesInconnu(raw),
        informationDate: _info,
        receivedAt: _received,
      );
      expect(
        changed(<String, Object?>{'a': 1}),
        changed(<String, Object?>{'a': 1}),
      );
      expect(
        changed(<String, Object?>{'a': 1}),
        isNot(changed(<String, Object?>{'a': 2})),
      );
    });

    test('une zone nouvelle ou plus citée porte ses null', () {
      final DroughtZoneChanged gone = DroughtZoneChanged(
        placeLabel: 'Station K447001001',
        zoneName: 'Loire',
        zoneKind: const EauxSuperficielles(),
        before: const Alerte(),
        after: null,
        decreeValidFrom: null,
        receivedAt: _received,
      );
      expect(gone.after, isNull);
      expect(gone.decreeValidFrom, isNull);
      expect(gone.asRead().after, isNull);
      final DroughtZoneChanged added = DroughtZoneChanged(
        placeLabel: 'Station K447001001',
        zoneName: 'Loire',
        zoneKind: const EauxSuperficielles(),
        before: null,
        after: const Alerte(),
        decreeValidFrom: _decree,
        receivedAt: _received,
      );
      expect(added.before, isNull);
      expect(added, isNot(gone));
    });

    test('les listes portées ne se modifient pas', () {
      final List<String> labels = <String>['A'];
      final CheckImpossible notice = CheckImpossible(
        source: FollowUpSource.drought,
        cause: CheckFailureCause.refused,
        placeLabels: labels,
        receivedAt: _received,
      );
      labels.add('B');
      expect(notice.placeLabels, <String>['A']);
      expect(() => notice.placeLabels.add('C'), throwsUnsupportedError);

      final DroughtFollowUpStarted started = DroughtFollowUpStarted(
        placeLabel: 'Station K447001001',
        zones: <KnownZone>[],
        readAt: _received,
        receivedAt: _received,
      );
      expect(started.zones, isEmpty);
      expect(
        () => started.zones.add(
          KnownZone(
            name: 'Loire',
            kind: const EauxSuperficielles(),
            severity: const Alerte(),
            decreeValidFrom: _decree,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('NotVerifiableReason', () {
    test('trois branches, égales par valeur', () {
      expect(SectionAbsent(_info), SectionAbsent(_info));
      expect(SectionMaybeUnreadable(_info), SectionMaybeUnreadable(_info));
      expect(const StationAbsent(), const StationAbsent());
      expect(SectionAbsent(_info), isNot(SectionMaybeUnreadable(_info)));
      expect(SectionAbsent(_info), isNot(SectionAbsent(_received)));
      expect(SectionAbsent(_info).hashCode, SectionAbsent(_info).hashCode);
    });
  });

  group('UnreadableNotice', () {
    test('garde son brut, égal par lui', () {
      const UnreadableNotice a = UnreadableNotice(raw: '{"z":1}');
      expect(a.raw, '{"z":1}');
      expect(a, const UnreadableNotice(raw: '{"z":1}'));
      expect(a.hashCode, const UnreadableNotice(raw: '{"z":1}').hashCode);
      expect(a, isNot(const UnreadableNotice(raw: '{"z":2}')));
    });

    test("n'est pas un avis lisible", () {
      const ReceivedNotice notice = UnreadableNotice(raw: 'x');
      expect(notice, isNot(isA<ReadableNotice>()));
    });
  });
}
