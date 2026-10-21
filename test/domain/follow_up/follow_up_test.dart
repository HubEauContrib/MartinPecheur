// Le suivi d'un lieu, ses derniers états et leurs égalités (M2 de T5).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/station/station.dart';

final DateTime _t = DateTime.utc(2026, 10, 21, 8);
final StationPlace _station = StationPlace(StationCode('K447001001'));
final FloodSectionPlace _section = FloodSectionPlace(FloodSectionCode('LC135'));

StationFavorite _stationFavorite() => StationFavorite(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  addedAt: _t,
);

void main() {
  group('sameFloodLevel', () {
    test('même branche, même niveau', () {
      expect(sameFloodLevel(const Jaune(), const Jaune()), isTrue);
      expect(sameFloodLevel(const Jaune(), const Orange()), isFalse);
      expect(
        sameFloodLevel(const Vert(), const NiveauCruesInconnu(5)),
        isFalse,
      );
    });

    test('deux inconnus de même brut sont égaux', () {
      expect(
        sameFloodLevel(
          const NiveauCruesInconnu(5),
          const NiveauCruesInconnu(5),
        ),
        isTrue,
      );
      expect(
        sameFloodLevel(
          const NiveauCruesInconnu(null),
          const NiveauCruesInconnu(null),
        ),
        isTrue,
      );
    });

    test("'5' et 5 ne sont pas le même brut", () {
      expect(
        sameFloodLevel(
          const NiveauCruesInconnu('5'),
          const NiveauCruesInconnu(5),
        ),
        isFalse,
      );
    });

    test('deux Map ou List construites séparément sont égales', () {
      expect(
        sameFloodLevel(
          NiveauCruesInconnu(<String, Object?>{'a': 1}),
          NiveauCruesInconnu(<String, Object?>{'a': 1}),
        ),
        isTrue,
      );
      expect(
        sameFloodLevel(
          NiveauCruesInconnu(<Object?>[1, 2]),
          NiveauCruesInconnu(<Object?>[1, 2]),
        ),
        isTrue,
      );
      expect(
        sameFloodLevel(
          NiveauCruesInconnu(<String, Object?>{'a': 1}),
          NiveauCruesInconnu(<String, Object?>{'a': 2}),
        ),
        isFalse,
      );
    });

    test("un brut que jsonEncode refuse n'est égal qu'à lui-même", () {
      final Object opaque = Object();
      expect(
        sameFloodLevel(NiveauCruesInconnu(opaque), NiveauCruesInconnu(opaque)),
        isTrue,
      );
      expect(
        sameFloodLevel(
          NiveauCruesInconnu(opaque),
          NiveauCruesInconnu(Object()),
        ),
        isFalse,
      );
    });
  });

  group('sameDroughtSeverity et sameZoneKind', () {
    test("même branche, même rawValue pour l'inconnu", () {
      expect(sameDroughtSeverity(const Alerte(), const Alerte()), isTrue);
      expect(sameDroughtSeverity(const Alerte(), const Crise()), isFalse);
      expect(
        sameDroughtSeverity(
          const GraviteInconnue('x'),
          const GraviteInconnue('x'),
        ),
        isTrue,
      );
      expect(
        sameDroughtSeverity(
          const GraviteInconnue('x'),
          const GraviteInconnue(null),
        ),
        isFalse,
      );
      expect(
        sameZoneKind(const EauxSuperficielles(), const EauxSuperficielles()),
        isTrue,
      );
      expect(
        sameZoneKind(const EauxSuperficielles(), const EauPotable()),
        isFalse,
      );
      expect(
        sameZoneKind(const TypeZoneInconnu('y'), const TypeZoneInconnu('y')),
        isTrue,
      );
      expect(
        sameZoneKind(const TypeZoneInconnu('y'), const TypeZoneInconnu('z')),
        isFalse,
      );
    });
  });

  group('derniers états', () {
    test('LastKnownFloodLevel est égal par valeur, brut compris', () {
      final LastKnownFloodLevel a = LastKnownFloodLevel(
        level: NiveauCruesInconnu(<String, Object?>{'a': 1}),
        informationDate: _t,
      );
      final LastKnownFloodLevel b = LastKnownFloodLevel(
        level: NiveauCruesInconnu(<String, Object?>{'a': 1}),
        informationDate: _t,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          LastKnownFloodLevel(
            level: NiveauCruesInconnu(<String, Object?>{'a': 1}),
            informationDate: _t.add(const Duration(hours: 1)),
          ),
        ),
      );
    });

    test('KnownZone est égal par valeur', () {
      KnownZone zone({DroughtSeverity severity = const Alerte()}) => KnownZone(
        name: 'Loire',
        kind: const EauxSuperficielles(),
        severity: severity,
        decreeValidFrom: _t,
      );
      expect(zone(), zone());
      expect(zone().hashCode, zone().hashCode);
      expect(zone(), isNot(zone(severity: const Crise())));
    });

    test('LastKnownZones : liste non modifiable, égalité par valeur', () {
      final List<KnownZone> source = <KnownZone>[
        KnownZone(
          name: 'Loire',
          kind: const EauxSuperficielles(),
          severity: const Alerte(),
          decreeValidFrom: _t,
        ),
      ];
      final LastKnownZones a = LastKnownZones(readAt: _t, zones: source);
      source.clear();
      expect(a.zones, hasLength(1));
      expect(() => a.zones.add(a.zones.first), throwsUnsupportedError);
      expect(a, LastKnownZones(readAt: _t, zones: a.zones.toList()));
      expect(a, isNot(LastKnownZones(readAt: _t, zones: <KnownZone>[])));
    });
  });

  group('FollowUp', () {
    test('trois branches, égales par valeur', () {
      const FollowUp unreadable = UnreadableFollowUp(raw: 'x');
      expect(unreadable, const UnreadableFollowUp(raw: 'x'));
      expect(unreadable, isNot(const UnreadableFollowUp(raw: 'y')));
      expect(
        FloodFollowUp(place: _section, threshold: FloodThreshold.jaune),
        FloodFollowUp(place: _section, threshold: FloodThreshold.jaune),
      );
      expect(
        FloodFollowUp(place: _section, threshold: FloodThreshold.jaune),
        isNot(FloodFollowUp(place: _section, threshold: FloodThreshold.rouge)),
      );
      expect(
        DroughtFollowUp(place: _station, series: FailureSeries.notVerifiable),
        DroughtFollowUp(place: _station, series: FailureSeries.notVerifiable),
      );
      expect(
        DroughtFollowUp(place: _station),
        isNot(
          DroughtFollowUp(
            place: _station,
            series: FailureSeries.checkImpossible,
          ),
        ),
      );
    });

    test('placeOfFollowUp : le lieu, null pour un suivi illisible', () {
      expect(
        placeOfFollowUp(
          FloodFollowUp(place: _section, threshold: FloodThreshold.orange),
        ),
        _section,
      );
      expect(placeOfFollowUp(DroughtFollowUp(place: _station)), _station);
      expect(placeOfFollowUp(const UnreadableFollowUp(raw: 'x')), isNull);
    });

    test("followUpOf trouve le suivi d'un lieu", () {
      final FollowUp flood = FloodFollowUp(
        place: _section,
        threshold: FloodThreshold.rouge,
      );
      final FollowUp drought = DroughtFollowUp(place: _station);
      final List<FollowUp> all = <FollowUp>[
        const UnreadableFollowUp(raw: 'x'),
        flood,
        drought,
      ];
      expect(followUpOf(all, _section), flood);
      expect(followUpOf(all, _station), drought);
      expect(
        followUpOf(all, FloodSectionPlace(FloodSectionCode('AUTRE'))),
        isNull,
      );
    });
  });

  group('followsAnyPlace', () {
    test('un suivi sans favori est faux', () {
      expect(
        followsAnyPlace(<Favorite>[], <FollowUp>[
          DroughtFollowUp(place: _station),
        ]),
        isFalse,
      );
    });

    test('un favori sans suivi est faux', () {
      expect(
        followsAnyPlace(<Favorite>[_stationFavorite()], <FollowUp>[]),
        isFalse,
      );
    });

    test('un suivi illisible est faux', () {
      expect(
        followsAnyPlace(
          <Favorite>[_stationFavorite()],
          <FollowUp>[const UnreadableFollowUp(raw: 'x')],
        ),
        isFalse,
      );
    });

    test('une station suivie et en favori est vraie', () {
      expect(
        followsAnyPlace(
          <Favorite>[_stationFavorite()],
          <FollowUp>[DroughtFollowUp(place: _station)],
        ),
        isTrue,
      );
    });
  });
}
