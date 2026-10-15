import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_section_rules.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

GeoPoint p(double lon, double lat) => GeoPoint(latitude: lat, longitude: lon);

FloodSection section(
  String code,
  List<List<GeoPoint>> lines, {
  FloodVigilanceLevel level = const Vert(),
}) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: '8',
  level: level,
  lines: lines,
);

List<String> codes(List<(FloodSection, GeoPoint)> labels) =>
    labels.map(((FloodSection, GeoPoint) e) => e.$1.code.value).toList();

// Emprise de 10 x 10 degrés : centre (5, 5).
final Bounds box = Bounds(west: 0, south: 0, east: 10, north: 10);

// Le point est-il sur un segment du trace (distance <= 1e-9) ?
bool onTrace(FloodSection s, GeoPoint q) {
  for (final List<GeoPoint> line in s.lines) {
    for (int i = 0; i < line.length - 1; i++) {
      final double ax = line[i].longitude;
      final double ay = line[i].latitude;
      final double dx = line[i + 1].longitude - ax;
      final double dy = line[i + 1].latitude - ay;
      final double len = dx * dx + dy * dy;
      double t = ((q.longitude - ax) * dx + (q.latitude - ay) * dy) / len;
      t = t < 0 ? 0 : (t > 1 ? 1 : t);
      final double ex = ax + t * dx - q.longitude;
      final double ey = ay + t * dy - q.latitude;
      if (ex * ex + ey * ey <= 1e-18) {
        return true;
      }
    }
  }

  return false;
}

void main() {
  group('floodSectionLabelled', () {
    final FloodSection vert = section('V', <List<GeoPoint>>[
      <GeoPoint>[p(1, 1), p(2, 2)],
    ]);

    FloodSection at(FloodVigilanceLevel level) => section('X', <List<GeoPoint>>[
      <GeoPoint>[p(1, 1), p(2, 2)],
    ], level: level);

    test("un vert n'est étiqueté qu'au niveau individuel", () {
      expect(floodSectionLabelled(vert, individualLevel: false), isFalse);
      expect(floodSectionLabelled(vert, individualLevel: true), isTrue);
    });

    test('jaune, orange, rouge, inconnu : toujours étiquetés', () {
      // Orange et rouge : cas construits, niveaux jamais observés en
      // production (VC-04).
      for (final FloodVigilanceLevel level in <FloodVigilanceLevel>[
        const Jaune(),
        const Orange(),
        const Rouge(),
        const NiveauCruesInconnu(null),
      ]) {
        for (final bool individual in <bool>[false, true]) {
          expect(
            floodSectionLabelled(at(level), individualLevel: individual),
            isTrue,
          );
        }
      }
    });
  });

  group('floodSectionTouches', () {
    test('un point sur le bord ouest exact', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(0, 5), p(-3, 5)],
      ]);
      expect(floodSectionTouches(s, box), isTrue);
    });

    test('un segment qui traverse de part en part sans sommet dedans', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-5, 5), p(15, 5)],
      ]);
      expect(floodSectionTouches(s, box), isTrue);
    });

    test("un segment qui frôle un coin de l'extérieur", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-1, 9.5), p(1, 11.5)],
      ]);
      expect(floodSectionTouches(s, box), isFalse);
    });

    test('un segment parallèle à un bord, dehors', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-5, 12), p(15, 12)],
      ]);
      expect(floodSectionTouches(s, box), isFalse);
    });

    test('échelle réelle : sommets à 2 km, emprise de 500 m', () {
      final Bounds small = Bounds(
        west: 2.0,
        south: 48.0,
        east: 2.0045,
        north: 48.0045,
      );
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(1.991, 48.002), p(2.009, 48.002)],
      ]);
      expect(floodSectionTouches(s, small), isTrue);
    });

    test("un segment le long d'un bord, dessus", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-2, 10), p(12, 10)],
      ]);
      expect(floodSectionTouches(s, box), isTrue);
    });

    test('un tronçon entièrement hors emprise', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(20, 20), p(30, 30)],
        <GeoPoint>[p(-20, 5), p(-10, 5)],
      ]);
      expect(floodSectionTouches(s, box), isFalse);
    });
  });

  group('floodLabelAnchor', () {
    test("un segment horizontal par le centre : l'ancre est le centre", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-5, 5), p(15, 5)],
      ]);
      expect(floodLabelAnchor(s, box), p(5, 5));
    });

    test('un segment au-dessus du centre : la longitude du centre', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-5, 8), p(15, 8)],
      ]);
      expect(floodLabelAnchor(s, box), p(5, 8));
    });

    test("un segment qui s'arrête avant le centre : son extrémité", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-5, 5), p(2, 5)],
      ]);
      expect(floodLabelAnchor(s, box), p(2, 5));
    });

    test("aucun segment dans l'emprise : null", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(20, 20), p(30, 30)],
      ]);
      expect(floodLabelAnchor(s, box), isNull);
    });

    test('deux segments à égale distance : le premier', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(4, 2), p(6, 2)],
        <GeoPoint>[p(4, 8), p(6, 8)],
      ]);
      expect(floodLabelAnchor(s, box), p(5, 2));
    });

    test('deux lignes, la plus proche du centre dans la seconde', () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(4, 1), p(6, 1)],
        <GeoPoint>[p(4, 6), p(6, 6)],
      ]);
      expect(floodLabelAnchor(s, box), p(5, 6));
    });

    test(
      'un segment découpé : projection sur le morceau, pas sur le segment',
      () {
        final Bounds flat = Bounds(west: 0, south: 0, east: 10, north: 1);
        final FloodSection s = section('A', <List<GeoPoint>>[
          <GeoPoint>[p(-5, -5), p(5, 5)],
        ]);
        expect(floodLabelAnchor(s, flat), p(1, 1));
      },
    );

    test('un segment réduit à un point : dedans, dehors', () {
      final FloodSection dedans = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(3, 4), p(3, 4)],
      ]);
      final FloodSection dehors = section('B', <List<GeoPoint>>[
        <GeoPoint>[p(30, 4), p(30, 4)],
      ]);
      expect(floodSectionTouches(dedans, box), isTrue);
      expect(floodLabelAnchor(dedans, box), p(3, 4));
      expect(floodSectionTouches(dehors, box), isFalse);
      expect(floodLabelAnchor(dehors, box), isNull);
    });

    test("l'ancre est toujours dans l'emprise (grille de 20 emprises)", () {
      final FloodSection s = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(-50, -40), p(60, 55), p(-30, 80)],
        <GeoPoint>[p(70, -20), p(-60, 30)],
      ]);
      int withAnchor = 0;
      for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 4; j++) {
          final double west = -40.0 + i * 17;
          final double south = -30.0 + j * 23;
          final Bounds b = Bounds(
            west: west,
            south: south,
            east: west + 6 + i,
            north: south + 5 + j,
          );
          final GeoPoint? anchor = floodLabelAnchor(s, b);
          expect(anchor != null, floodSectionTouches(s, b));
          if (anchor != null) {
            withAnchor++;
            expect(anchor.longitude, inInclusiveRange(b.west, b.east));
            expect(anchor.latitude, inInclusiveRange(b.south, b.north));
            expect(onTrace(s, anchor), isTrue);
          }
        }
      }
      expect(withAnchor, greaterThan(0));
    });
  });

  group('floodSectionsInDrawingOrder', () {
    test(
      'stabilité probante : 40 tronçons de même rang gardent leur ordre',
      () {
        final List<FloodSection> same = <FloodSection>[
          for (int i = 0; i < 40; i++)
            section('S${i.toString().padLeft(2, '0')}', <List<GeoPoint>>[
              <GeoPoint>[p(1, 1), p(2, 2)],
            ]),
        ];
        final List<FloodSection> reversed = same.reversed.toList();
        expect(floodSectionsInDrawingOrder(same), same);
        expect(floodSectionsInDrawingOrder(reversed), reversed);
      },
    );

    test('tri stable par rang croissant', () {
      final List<List<GeoPoint>> line = <List<GeoPoint>>[
        <GeoPoint>[p(1, 1), p(2, 2)],
      ];
      // Rouge : cas construit, niveau jamais observé en production (VC-04).
      final FloodSection a = section('A', line, level: const Rouge());
      final FloodSection b = section('B', line);
      final FloodSection c = section(
        'C',
        line,
        level: const NiveauCruesInconnu(9),
      );
      final FloodSection d = section('D', line, level: const Jaune());
      final FloodSection e = section('E', line);
      final List<FloodSection> out = floodSectionsInDrawingOrder(<FloodSection>[
        a,
        b,
        c,
        d,
        e,
      ]);
      expect(out, <FloodSection>[b, e, d, a, c]);
      expect(() => out.add(a), throwsUnsupportedError);
    });
  });

  group('floodLabelsFor', () {
    final FloodSection vertProche = section('Z', <List<GeoPoint>>[
      <GeoPoint>[p(4, 5), p(6, 5)],
    ]);
    // Orange : cas construit, niveau jamais observé en production (VC-04).
    final FloodSection orangeLoin = section('A', <List<GeoPoint>>[
      <GeoPoint>[p(1, 1), p(2, 1)],
    ], level: const Orange());

    test('sous le niveau individuel : seul le non vert', () {
      final List<(FloodSection, GeoPoint)> out = floodLabelsFor(
        <FloodSection>[vertProche, orangeLoin],
        box,
        individualLevel: false,
      );
      expect(out, <(FloodSection, GeoPoint)>[(orangeLoin, p(2, 1))]);
    });

    test("au niveau individuel : les deux, le plus proche d'abord", () {
      final List<(FloodSection, GeoPoint)> out = floodLabelsFor(
        <FloodSection>[orangeLoin, vertProche],
        box,
        individualLevel: true,
      );
      expect(codes(out), <String>['Z', 'A']);
      expect(() => out.add(out.first), throwsUnsupportedError);
    });

    test('égalité de distance : par code', () {
      final FloodSection b = section('B', <List<GeoPoint>>[
        <GeoPoint>[p(1, 5), p(2, 5)],
      ], level: const Jaune());
      final FloodSection a = section('A', <List<GeoPoint>>[
        <GeoPoint>[p(8, 5), p(9, 5)],
      ], level: const Jaune());
      // Ancres (2, 5) et (8, 5) : à 3 du centre chacune.
      final List<(FloodSection, GeoPoint)> out = floodLabelsFor(
        <FloodSection>[b, a],
        box,
        individualLevel: false,
      );
      expect(codes(out), <String>['A', 'B']);
    });

    test('un orange hors emprise est absent', () {
      final FloodSection hors = section('H', <List<GeoPoint>>[
        <GeoPoint>[p(20, 20), p(30, 30)],
      ], level: const Orange());
      expect(
        floodLabelsFor(<FloodSection>[hors], box, individualLevel: true),
        isEmpty,
      );
    });
  });
}
