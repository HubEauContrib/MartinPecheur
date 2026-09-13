// OndePoint est une classe immuable simple, sans validation propre (la
// validation vit dans OndeStationCode et DepartementCode) : ce test verifie
// seulement que les champs se portent et se lisent, y compris les absences
// (BR-007).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

void main() {
  group('OndePoint', () {
    test('porte les champs relevés sur K4520001', () {
      final OndePoint point = OndePoint(
        code: OndeStationCode('K4520001'),
        label: 'Le Loir a Vaas',
        latitude: 47.584957074,
        longitude: 1.335147948,
        waterCourseLabel: 'Le Loir',
        departement: DepartementCode('41'),
      );

      expect(point.code, OndeStationCode('K4520001'));
      expect(point.label, 'Le Loir a Vaas');
      expect(point.latitude, 47.584957074);
      expect(point.longitude, 1.335147948);
      expect(point.waterCourseLabel, 'Le Loir');
      expect(point.departement, DepartementCode('41'));
    });

    test('waterCourseLabel et departement sont nullables — une absence, '
        'jamais une chaine vide (BR-007)', () {
      final OndePoint point = OndePoint(
        code: OndeStationCode('K4520001'),
        label: 'Station sans cours d\'eau connu',
        latitude: 47.5,
        longitude: 1.3,
        waterCourseLabel: null,
        departement: null,
      );

      expect(point.waterCourseLabel, isNull);
      expect(point.departement, isNull);
    });
  });
}
