// Les règles de changement du suivi (M3 de T5) : elles comparent deux niveaux
// PUBLIÉS, ou deux lectures des zones citées. Elles ne calculent aucun niveau
// (BR-015, BR-016).
//
// Les cas de sécheresse sont des cas construits, jamais observés en
// production — `VC-04` : ni un changement d'arrêté ni une zone nouvelle n'ont
// été vus. Ils vivent ici, jamais sous `test/fixtures/`.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_rules.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

const List<FloodVigilanceLevel> _recognised = <FloodVigilanceLevel>[
  Vert(),
  Jaune(),
  Orange(),
  Rouge(),
];

final DateTime _d1 = DateTime.utc(2026, 7, 1);
final DateTime _d2 = DateTime.utc(2026, 8, 15);
final DateTime _read1 = DateTime.utc(2026, 10, 20, 8);
final DateTime _read2 = DateTime.utc(2026, 10, 21, 8);

KnownZone _zone(
  String name,
  ZoneKind kind,
  DroughtSeverity severity, [
  DateTime? decreeValidFrom,
]) => KnownZone(
  name: name,
  kind: kind,
  severity: severity,
  decreeValidFrom: decreeValidFrom ?? _d1,
);

LastKnownZones _before(List<KnownZone> zones) =>
    LastKnownZones(readAt: _read1, zones: zones);

LastKnownZones _after(List<KnownZone> zones) =>
    LastKnownZones(readAt: _read2, zones: zones);

bool _due(
  FloodVigilanceLevel before,
  FloodVigilanceLevel after,
  FloodThreshold threshold,
) => floodNoticeDue(before: before, after: after, threshold: threshold);

void main() {
  group('publishedFloodRank et floodThresholdRank', () {
    test('vert 0, jaune 1, orange 2, rouge 3, inconnu sans rang', () {
      expect(publishedFloodRank(const Vert()), 0);
      expect(publishedFloodRank(const Jaune()), 1);
      expect(publishedFloodRank(const Orange()), 2);
      expect(publishedFloodRank(const Rouge()), 3);
      expect(publishedFloodRank(const NiveauCruesInconnu('x')), isNull);
      expect(publishedFloodRank(const NiveauCruesInconnu(null)), isNull);
    });

    test("publishedFloodRank n'a aucune valeur au-delà de 3", () {
      for (final FloodVigilanceLevel level in <FloodVigilanceLevel>[
        ..._recognised,
        const NiveauCruesInconnu(5),
      ]) {
        final int? rank = publishedFloodRank(level);
        if (rank != null) {
          expect(rank, inInclusiveRange(0, 3));
        }
      }
    });

    test('seuils : jaune 1, orange 2, rouge 3', () {
      expect(floodThresholdRank(FloodThreshold.jaune), 1);
      expect(floodThresholdRank(FloodThreshold.orange), 2);
      expect(floodThresholdRank(FloodThreshold.rouge), 3);
    });
  });

  group('floodNoticeDue', () {
    group('critère 11, seuil orange', () {
      test('jaune → orange, orange → rouge, rouge → orange, orange → jaune : '
          'un avis', () {
        expect(
          _due(const Jaune(), const Orange(), FloodThreshold.orange),
          isTrue,
        );
        expect(
          _due(const Orange(), const Rouge(), FloodThreshold.orange),
          isTrue,
        );
        expect(
          _due(const Rouge(), const Orange(), FloodThreshold.orange),
          isTrue,
        );
        expect(
          _due(const Orange(), const Jaune(), FloodThreshold.orange),
          isTrue,
        );
      });

      test("vert → jaune et jaune → vert : aucun avis", () {
        expect(
          _due(const Vert(), const Jaune(), FloodThreshold.orange),
          isFalse,
        );
        expect(
          _due(const Jaune(), const Vert(), FloodThreshold.orange),
          isFalse,
        );
      });
    });

    test('seuil jaune : vert → jaune donne un avis', () {
      expect(_due(const Vert(), const Jaune(), FloodThreshold.jaune), isTrue);
    });

    test("seuil rouge : orange → jaune n'en donne pas", () {
      expect(
        _due(const Orange(), const Jaune(), FloodThreshold.rouge),
        isFalse,
      );
    });

    test('niveaux égaux : aucun avis', () {
      for (final FloodThreshold threshold in FloodThreshold.values) {
        for (final FloodVigilanceLevel level in _recognised) {
          expect(_due(level, level, threshold), isFalse);
        }
      }
    });

    group('critère 12, niveau non reconnu', () {
      test('inconnu avant ou après, contre tout niveau reconnu, avec tout '
          'seuil : un avis', () {
        const FloodVigilanceLevel unknown = NiveauCruesInconnu('9');
        for (final FloodThreshold threshold in FloodThreshold.values) {
          for (final FloodVigilanceLevel level in _recognised) {
            expect(_due(unknown, level, threshold), isTrue);
            expect(_due(level, unknown, threshold), isTrue);
          }
        }
      });

      test('deux inconnus de même brut : aucun avis', () {
        for (final FloodThreshold threshold in FloodThreshold.values) {
          expect(
            _due(
              const NiveauCruesInconnu('9'),
              const NiveauCruesInconnu('9'),
              threshold,
            ),
            isFalse,
          );
          expect(
            _due(
              const NiveauCruesInconnu(<String, Object?>{'a': 1}),
              const NiveauCruesInconnu(<String, Object?>{'a': 1}),
              threshold,
            ),
            isFalse,
          );
        }
      });

      test('deux inconnus de bruts différents : un avis', () {
        for (final FloodThreshold threshold in FloodThreshold.values) {
          expect(
            _due(
              const NiveauCruesInconnu('9'),
              const NiveauCruesInconnu('8'),
              threshold,
            ),
            isTrue,
          );
        }
      });
    });
  });

  group('zoneKindRank', () {
    test('eaux superficielles 0, eaux souterraines 1, eau potable 2, '
        'type inconnu 3', () {
      expect(zoneKindRank(const EauxSuperficielles()), 0);
      expect(zoneKindRank(const EauxSouterraines()), 1);
      expect(zoneKindRank(const EauPotable()), 2);
      expect(zoneKindRank(const TypeZoneInconnu('X')), 3);
      expect(zoneKindRank(const TypeZoneInconnu(null)), 3);
    });
  });

  group('lastKnownZonesOf', () {
    AlertZone alertZone(String name, ZoneKind kind, DateTime validFrom) =>
        AlertZone(
          name: name,
          kind: kind,
          severity: const Alerte(),
          decree: RestrictionDecree(validFrom: validFrom),
          usages: const <RestrictedUsage>[],
        );

    test("respecte l'ordre de l'écran des restrictions", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final ZonesAtPoint zones = ZonesAtPoint(
        point: GeoPoint(latitude: 47.0, longitude: 1.0),
        retrievedAt: _read2,
        zones: <AlertZone>[
          alertZone('Inconnue', const TypeZoneInconnu('X'), _d1),
          alertZone('Potable', const EauPotable(), _d1),
          alertZone('Souterraine', const EauxSouterraines(), _d2),
          alertZone('Cher', const EauxSuperficielles(), _d1),
          alertZone('Loire', const EauxSuperficielles(), _d2),
        ],
      );

      final LastKnownZones known = lastKnownZonesOf(zones);

      expect(known.readAt, _read2);
      expect(known.zones, <KnownZone>[
        _zone('Cher', const EauxSuperficielles(), const Alerte(), _d1),
        _zone('Loire', const EauxSuperficielles(), const Alerte(), _d2),
        _zone('Souterraine', const EauxSouterraines(), const Alerte(), _d2),
        _zone('Potable', const EauPotable(), const Alerte(), _d1),
        _zone('Inconnue', const TypeZoneInconnu('X'), const Alerte(), _d1),
      ]);
    });

    test('aucune zone citée : une liste vide', () {
      final LastKnownZones known = lastKnownZonesOf(
        ZonesAtPoint(
          point: GeoPoint(latitude: 47.0, longitude: 1.0),
          retrievedAt: _read2,
          zones: const <AlertZone>[],
        ),
      );
      expect(known.zones, isEmpty);
      expect(known.readAt, _read2);
    });
  });

  group('droughtZoneChanges (critère 13)', () {
    test('gravité alerte → crise : un changement', () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Crise(), _d2),
        ]),
      );
      expect(changes, <DroughtZoneChange>[
        DroughtZoneChange(
          name: 'Loire',
          kind: const EauxSuperficielles(),
          before: const Alerte(),
          after: const Crise(),
          decreeValidFrom: _d2,
        ),
      ]);
    });

    test('zone nouvelle : before == null', () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(const <KnownZone>[]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Vigilance(), _d2),
        ]),
      );
      expect(changes, <DroughtZoneChange>[
        DroughtZoneChange(
          name: 'Loire',
          kind: const EauxSuperficielles(),
          before: null,
          after: const Vigilance(),
          decreeValidFrom: _d2,
        ),
      ]);
    });

    test('zone plus citée : after == null', () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
        after: _after(const <KnownZone>[]),
      );
      expect(changes, <DroughtZoneChange>[
        const DroughtZoneChange(
          name: 'Loire',
          kind: EauxSuperficielles(),
          before: Alerte(),
          after: null,
          decreeValidFrom: null,
        ),
      ]);
    });

    test("même gravité et nouvelle date d'arrêté : rien (R5)", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte(), _d2),
        ]),
      );
      expect(changes, isEmpty);
    });

    test('zone renommée : une disparition puis un ajout (R5)', () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire amont', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
      );
      expect(changes, <DroughtZoneChange>[
        const DroughtZoneChange(
          name: 'Loire amont',
          kind: EauxSuperficielles(),
          before: Alerte(),
          after: null,
          decreeValidFrom: null,
        ),
        DroughtZoneChange(
          name: 'Loire',
          kind: const EauxSuperficielles(),
          before: null,
          after: const Alerte(),
          decreeValidFrom: _d1,
        ),
      ]);
    });

    test("ordre : une zone d'eaux superficielles disparue passe avant une zone "
        "d'eaux souterraines nouvelle", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Cher', const EauxSuperficielles(), const Alerte(), _d1),
        ]),
        after: _after(<KnownZone>[
          _zone('Nappe', const EauxSouterraines(), const Crise(), _d2),
        ]),
      );
      expect(changes.map((DroughtZoneChange c) => c.name), <String>[
        'Cher',
        'Nappe',
      ]);
      expect(changes.first.after, isNull);
      expect(changes.last.before, isNull);
    });

    test("ordre : par type, puis l'ordre de after, les disparitions dans "
        "l'ordre de before", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Potable', const EauPotable(), const Alerte()),
          _zone('B', const EauxSuperficielles(), const Alerte()),
          _zone('A', const EauxSuperficielles(), const Alerte()),
          _zone('Gone2', const EauxSuperficielles(), const Alerte()),
          _zone('Gone1', const EauxSuperficielles(), const Alerte()),
        ]),
        after: _after(<KnownZone>[
          _zone('Inconnue', const TypeZoneInconnu('X'), const Alerte()),
          _zone('Potable', const EauPotable(), const Crise()),
          _zone('A', const EauxSuperficielles(), const Crise()),
          _zone('B', const EauxSuperficielles(), const Crise()),
        ]),
      );
      expect(changes.map((DroughtZoneChange c) => c.name), <String>[
        'Gone2',
        'Gone1',
        'A',
        'B',
        'Potable',
        'Inconnue',
      ]);
    });

    test("GraviteInconnue('x') → GraviteInconnue('y') : un changement", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone(
            'Loire',
            const EauxSuperficielles(),
            const GraviteInconnue('x'),
          ),
        ]),
        after: _after(<KnownZone>[
          _zone(
            'Loire',
            const EauxSuperficielles(),
            const GraviteInconnue('y'),
          ),
        ]),
      );
      expect(changes, hasLength(1));
      expect(changes.single.before, const GraviteInconnue('x'));
      expect(changes.single.after, const GraviteInconnue('y'));
    });

    test("GraviteInconnue de même brut : rien", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone(
            'Loire',
            const EauxSuperficielles(),
            const GraviteInconnue('x'),
          ),
        ]),
        after: _after(<KnownZone>[
          _zone(
            'Loire',
            const EauxSuperficielles(),
            const GraviteInconnue('x'),
          ),
        ]),
      );
      expect(changes, isEmpty);
    });

    test("deux zones de même nom et de même type s'apparient dans l'ordre", () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte()),
          _zone('Loire', const EauxSuperficielles(), const Vigilance()),
        ]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte()),
          _zone('Loire', const EauxSuperficielles(), const Crise()),
        ]),
      );
      expect(changes, <DroughtZoneChange>[
        DroughtZoneChange(
          name: 'Loire',
          kind: const EauxSuperficielles(),
          before: const Vigilance(),
          after: const Crise(),
          decreeValidFrom: _d1,
        ),
      ]);
    });

    test('même nom, autre type : deux zones distinctes', () {
      // Cas construit, jamais observé en production — `VC-04`.
      final List<DroughtZoneChange> changes = droughtZoneChanges(
        before: _before(<KnownZone>[
          _zone('Loire', const EauxSuperficielles(), const Alerte()),
        ]),
        after: _after(<KnownZone>[
          _zone('Loire', const EauxSouterraines(), const Alerte()),
        ]),
      );
      expect(changes, hasLength(2));
      expect(changes.first.kind, const EauxSuperficielles());
      expect(changes.first.after, isNull);
      expect(changes.last.kind, const EauxSouterraines());
      expect(changes.last.before, isNull);
    });

    test('aucune zone avant ni après : rien', () {
      expect(
        droughtZoneChanges(
          before: _before(const <KnownZone>[]),
          after: _after(const <KnownZone>[]),
        ),
        isEmpty,
      );
    });
  });

  group('DroughtZoneChange', () {
    test('égalité par valeur, gravités inconnues par leur brut', () {
      const DroughtZoneChange a = DroughtZoneChange(
        name: 'Loire',
        kind: TypeZoneInconnu('X'),
        before: GraviteInconnue('x'),
        after: null,
        decreeValidFrom: null,
      );
      const DroughtZoneChange b = DroughtZoneChange(
        name: 'Loire',
        kind: TypeZoneInconnu('X'),
        before: GraviteInconnue('x'),
        after: null,
        decreeValidFrom: null,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const DroughtZoneChange(
            name: 'Loire',
            kind: TypeZoneInconnu('Y'),
            before: GraviteInconnue('x'),
            after: null,
            decreeValidFrom: null,
          ),
        ),
      );
    });
  });
}
