// Verrouille ZonesAtPoint : la reponse datee au point, et la partition
// surfaceWaterZones / otherZones sans perte ni tri par severite (Q5-B,
// conception T2 § 5). retrievedAt voyage avec la reponse (§ 2.3) et doit
// etre en UTC, comme les autres instants du domaine.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

GeoPoint _point() => GeoPoint(latitude: 47.584957074, longitude: 1.335147948);

DateTime _retrievedAt() => DateTime.utc(2026, 9, 27, 11, 45);

RestrictionDecree _decree() =>
    RestrictionDecree(validFrom: DateTime.utc(2026, 6, 25));

AlertZone _zone(String name, ZoneKind kind, {DroughtSeverity? severity}) =>
    AlertZone(
      name: name,
      kind: kind,
      severity: severity ?? const Vigilance(),
      decree: _decree(),
      usages: const <RestrictedUsage>[],
    );

void main() {
  group('ZonesAtPoint — champs', () {
    test('point, retrievedAt et zones sont portes tels quels', () {
      final AlertZone zone = _zone('Zone 3', const EauxSuperficielles());
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[zone],
      );

      expect(reponse.point, _point());
      expect(reponse.retrievedAt, _retrievedAt());
      expect(reponse.zones, <AlertZone>[zone]);
    });

    test('zones n est pas modifiable', () {
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: const <AlertZone>[],
      );

      expect(
        () => reponse.zones.add(_zone('x', const EauPotable())),
        throwsUnsupportedError,
      );
    });

    test('retrievedAt local leve ArgumentError', () {
      expect(
        () => ZonesAtPoint(
          point: _point(),
          retrievedAt: DateTime(2026, 9, 27, 11, 45),
          zones: const <AlertZone>[],
        ),
        throwsArgumentError,
      );
    });

    test('zones vide rend deux listes vides', () {
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: const <AlertZone>[],
      );

      expect(reponse.surfaceWaterZones, isEmpty);
      expect(reponse.otherZones, isEmpty);
    });
  });

  group('Egalite structurelle — dans les deux sens', () {
    test('deux ZonesAtPoint aux memes champs sont egales', () {
      final AlertZone zone = _zone('sup', const EauxSuperficielles());
      ZonesAtPoint reponse() => ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[zone],
      );

      expect(reponse(), reponse());
      expect(reponse(), reponse()); // sens inverse, meme relation d egalite
      expect(reponse().hashCode, reponse().hashCode);
    });

    test(
      'un point different rend les deux reponses inegales, dans les deux sens',
      () {
        final AlertZone zone = _zone('sup', const EauxSuperficielles());
        final ZonesAtPoint a = ZonesAtPoint(
          point: _point(),
          retrievedAt: _retrievedAt(),
          zones: <AlertZone>[zone],
        );
        final ZonesAtPoint b = ZonesAtPoint(
          point: GeoPoint(latitude: 0, longitude: 0),
          retrievedAt: _retrievedAt(),
          zones: <AlertZone>[zone],
        );

        expect(a, isNot(b));
        expect(b, isNot(a));
      },
    );

    test('un retrievedAt different rend les deux reponses inegales, dans les deux sens', () {
      final ZonesAtPoint a = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: const <AlertZone>[],
      );
      final ZonesAtPoint b = ZonesAtPoint(
        point: _point(),
        retrievedAt: DateTime.utc(2026, 9, 27, 12),
        zones: const <AlertZone>[],
      );

      expect(a, isNot(b));
      expect(b, isNot(a));
    });

    test('un ordre de zones different rend les deux reponses inegales, dans les deux sens', () {
      final AlertZone sou = _zone('sou', const EauxSouterraines());
      final AlertZone sup = _zone('sup', const EauxSuperficielles());
      final ZonesAtPoint a = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[sou, sup],
      );
      final ZonesAtPoint b = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[sup, sou],
      );

      expect(a, isNot(b));
      expect(b, isNot(a));
    });

    test(
      'une zone en plus rend les deux reponses inegales, dans les deux sens',
      () {
        final AlertZone sou = _zone('sou', const EauxSouterraines());
        final AlertZone sup = _zone('sup', const EauxSuperficielles());
        final ZonesAtPoint a = ZonesAtPoint(
          point: _point(),
          retrievedAt: _retrievedAt(),
          zones: <AlertZone>[sou],
        );
        final ZonesAtPoint b = ZonesAtPoint(
          point: _point(),
          retrievedAt: _retrievedAt(),
          zones: <AlertZone>[sou, sup],
        );

        expect(a, isNot(b));
        expect(b, isNot(a));
      },
    );
  });

  group('Partition (Q5-B) — surfaceWaterZones / otherZones', () {
    test('SOU, SUP, AEP : SUP isole, SOU puis AEP dans otherZones', () {
      final AlertZone sou = _zone('sou', const EauxSouterraines());
      final AlertZone sup = _zone('sup', const EauxSuperficielles());
      final AlertZone aep = _zone('aep', const EauPotable());
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[sou, sup, aep],
      );

      expect(reponse.surfaceWaterZones, <AlertZone>[sup]);
      expect(reponse.otherZones, <AlertZone>[sou, aep]);
    });

    test('AEP puis SUP (ordre d Ariege) : otherZones == [AEP]', () {
      final AlertZone aep = _zone('aep', const EauPotable());
      final AlertZone sup = _zone('sup', const EauxSuperficielles());
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[aep, sup],
      );

      expect(reponse.surfaceWaterZones, <AlertZone>[sup]);
      expect(reponse.otherZones, <AlertZone>[aep]);
    });

    test('AEP, TypeZoneInconnu, SOU, SUP1, SUP2 : ordre fixe SOU puis AEP puis '
        'inconnu dans otherZones, sans tri par severite', () {
      final AlertZone aep = _zone('aep', const EauPotable());
      final AlertZone inconnue = _zone('x', const TypeZoneInconnu('X'));
      final AlertZone sou = _zone('sou', const EauxSouterraines());
      final AlertZone sup1 = _zone('sup1', const EauxSuperficielles());
      final AlertZone sup2 = _zone('sup2', const EauxSuperficielles());
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[aep, inconnue, sou, sup1, sup2],
      );

      expect(reponse.surfaceWaterZones, <AlertZone>[sup1, sup2]);
      expect(reponse.otherZones, <AlertZone>[sou, aep, inconnue]);
    });

    test('deux SOU gardent l ordre source', () {
      final AlertZone souA = _zone('sou-a', const EauxSouterraines());
      final AlertZone souB = _zone('sou-b', const EauxSouterraines());
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[souB, souA],
      );

      expect(reponse.otherZones, <AlertZone>[souB, souA]);
    });

    test('SOU en crise puis AEP en vigilance : ordre SOU, AEP — aucun tri par severite', () {
      final AlertZone sou = _zone(
        'sou',
        const EauxSouterraines(),
        severity: const Crise(),
      );
      final AlertZone aep = _zone(
        'aep',
        const EauPotable(),
        severity: const Vigilance(),
      );
      final ZonesAtPoint reponse = ZonesAtPoint(
        point: _point(),
        retrievedAt: _retrievedAt(),
        zones: <AlertZone>[sou, aep],
      );

      expect(reponse.otherZones, <AlertZone>[sou, aep]);
    });

    test('sans perte : les 120 permutations de 5 zones melangees se partagent sans rien perdre', () {
      final List<AlertZone> zones = <AlertZone>[
        _zone('sou', const EauxSouterraines()),
        _zone('sup', const EauxSuperficielles()),
        _zone('aep', const EauPotable()),
        _zone('inconnue', const TypeZoneInconnu('X')),
        _zone('sup2', const EauxSuperficielles()),
      ];

      for (final List<AlertZone> permutation in _permutations(zones)) {
        final ZonesAtPoint reponse = ZonesAtPoint(
          point: _point(),
          retrievedAt: _retrievedAt(),
          zones: permutation,
        );

        final List<AlertZone> toutes = <AlertZone>[
          ...reponse.surfaceWaterZones,
          ...reponse.otherZones,
        ];

        expect(
          reponse.surfaceWaterZones.length + reponse.otherZones.length,
          zones.length,
        );
        for (final AlertZone zone in zones) {
          expect(
            toutes.where((AlertZone z) => identical(z, zone)),
            hasLength(1),
          );
        }
      }
    });
  });
}

/// Toutes les permutations de [items] (120 pour 5 elements). Petite liste,
/// generation naive acceptable pour un test.
List<List<T>> _permutations<T>(List<T> items) {
  if (items.length <= 1) {
    return <List<T>>[List<T>.of(items)];
  }

  final List<List<T>> result = <List<T>>[];
  for (int i = 0; i < items.length; i++) {
    final List<T> reste = List<T>.of(items)..removeAt(i);
    for (final List<T> sousPermutation in _permutations(reste)) {
      result.add(<T>[items[i], ...sousPermutation]);
    }
  }
  return result;
}
