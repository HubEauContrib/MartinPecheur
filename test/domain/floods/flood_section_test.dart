import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

GeoPoint _p(double lat, double lon) => GeoPoint(latitude: lat, longitude: lon);

List<List<GeoPoint>> _lines() => <List<GeoPoint>>[
  <GeoPoint>[_p(45, 4), _p(45.1, 4.1)],
];

FloodSection _section({
  String code = 'BT5',
  String name = 'Tronçon test',
  String territory = '12',
  FloodVigilanceLevel level = const Vert(),
  List<List<GeoPoint>>? lines,
}) => FloodSection(
  code: FloodSectionCode(code),
  name: name,
  territoryCode: territory,
  level: level,
  lines: lines ?? _lines(),
);

void main() {
  group('FloodSectionCode', () {
    test('garde la valeur', () {
      expect(FloodSectionCode('BT5').value, 'BT5');
    });

    test('refuse une chaîne vide', () {
      expect(() => FloodSectionCode(''), throwsArgumentError);
    });

    test('est pris tel quel, sans trim', () {
      expect(FloodSectionCode(' BT5'), isNot(FloodSectionCode('BT5')));
      expect(FloodSectionCode('BT5'), FloodSectionCode('BT5'));
      expect(
        FloodSectionCode('BT5').hashCode,
        FloodSectionCode('BT5').hashCode,
      );
    });
  });

  group('FloodSection', () {
    test('construction valide', () {
      final FloodSection s = _section();
      expect(s.name, 'Tronçon test');
      expect(s.territoryCode, '12');
      expect(s.lines, hasLength(1));
    });

    test('refuse un nom vide', () {
      expect(() => _section(name: ''), throwsArgumentError);
    });

    test('refuse un territoire vide', () {
      expect(() => _section(territory: ''), throwsArgumentError);
    });

    test('refuse aucune ligne', () {
      expect(() => _section(lines: <List<GeoPoint>>[]), throwsArgumentError);
    });

    test('refuse une ligne d un seul point', () {
      expect(
        () => _section(
          lines: <List<GeoPoint>>[
            <GeoPoint>[_p(45, 4)],
          ],
        ),
        throwsArgumentError,
      );
    });

    test('les lignes et chaque ligne sont non modifiables', () {
      final FloodSection s = _section();
      expect(() => s.lines.add(<GeoPoint>[]), throwsUnsupportedError);
      expect(() => s.lines.first.add(_p(1, 1)), throwsUnsupportedError);
    });

    test('copie défensive de l entrée', () {
      final List<List<GeoPoint>> src = _lines();
      final FloodSection s = _section(lines: src);
      src.first.add(_p(46, 5));
      expect(s.lines.first, hasLength(2));
    });

    test('égalité sur le code seul', () {
      final FloodSection a = _section();
      final FloodSection b = _section(level: const Rouge(), name: 'Autre');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_section(code: 'BT6')));
    });

    test('toString sans les tracés', () {
      expect(_section().toString(), contains('BT5'));
      expect(_section().toString(), isNot(contains('latitude')));
    });
  });
}
