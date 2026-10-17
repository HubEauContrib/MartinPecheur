import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

FloodSection _section(String code) => FloodSection(
  code: FloodSectionCode(code),
  name: 'Tronçon $code',
  territoryCode: '12',
  level: const Vert(),
  lines: <List<GeoPoint>>[
    <GeoPoint>[
      GeoPoint(latitude: 45, longitude: 4),
      GeoPoint(latitude: 45.1, longitude: 4.1),
    ],
  ],
);

void main() {
  final DateTime date = DateTime.utc(2026, 10, 14, 13, 55, 31);

  test('refuse une date locale', () {
    expect(
      () => FloodVigilanceMap(
        informationDate: DateTime(2026, 10, 14, 15, 55),
        sections: <FloodSection>[],
        skippedEntities: 0,
      ),
      throwsArgumentError,
    );
  });

  test('accepte une date UTC', () {
    final FloodVigilanceMap m = FloodVigilanceMap(
      informationDate: date,
      sections: <FloodSection>[],
      skippedEntities: 0,
    );
    expect(m.informationDate, date);
  });

  test('refuse un nombre négatif d entités écartées', () {
    expect(
      () => FloodVigilanceMap(
        informationDate: date,
        sections: <FloodSection>[],
        skippedEntities: -1,
      ),
      throwsArgumentError,
    );
  });

  test('sections non modifiables', () {
    final FloodVigilanceMap m = FloodVigilanceMap(
      informationDate: date,
      sections: <FloodSection>[_section('A')],
      skippedEntities: 2,
    );
    expect(m.skippedEntities, 2);
    expect(() => m.sections.add(_section('B')), throwsUnsupportedError);
  });

  test('sectionByCode trouve ou rend null', () {
    final FloodVigilanceMap m = FloodVigilanceMap(
      informationDate: date,
      sections: <FloodSection>[_section('A'), _section('B')],
      skippedEntities: 0,
    );
    expect(m.sectionByCode(FloodSectionCode('B'))?.name, 'Tronçon B');
    expect(m.sectionByCode(FloodSectionCode('Z')), isNull);
  });
}
