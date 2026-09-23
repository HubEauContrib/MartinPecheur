// OndePoint est une classe immuable simple, sans validation propre (la
// validation vit dans OndeStationCode, et pour le département dans
// DepartementCode à la lecture). Ce test vérifie seulement que les champs se
// portent et se lisent, y compris les absences (BR-007). Les valeurs
// « relevées » proviennent de la fixture réelle
// `test/fixtures/onde/observations_station_K4520001_2026-09-13.json`
// (station K4520001, LA RIVIERE AUX LOCHES A CHAON) — jamais inventées, et
// jamais copiées d'une autre station (T-04). Depuis ADR-015, `departement`
// porte un `AdministrativeArea` (code + libellé) et non plus un
// `DepartementCode` nu ; `region` s'y ajoute, même type.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndePoint', () {
    test('porte les champs relevés sur K4520001', () {
      final OndePoint point = OndePoint(
        code: OndeStationCode('K4520001'),
        label: 'LA RIVIERE AUX LOCHES A CHAON',
        latitude: 47.610620493,
        longitude: 2.173858157,
        waterCourseLabel: 'ruisseau la rivière aux loches',
        departement: const AdministrativeArea(
          code: '41',
          label: 'Loir-et-Cher',
        ),
        region: const AdministrativeArea(
          code: '24',
          label: 'Centre-Val de Loire',
        ),
      );

      expect(point.code, OndeStationCode('K4520001'));
      expect(point.label, 'LA RIVIERE AUX LOCHES A CHAON');
      expect(point.latitude, 47.610620493);
      expect(point.longitude, 2.173858157);
      expect(point.waterCourseLabel, 'ruisseau la rivière aux loches');
      expect(
        point.departement,
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
      );
      expect(
        point.region,
        const AdministrativeArea(code: '24', label: 'Centre-Val de Loire'),
      );
    });

    test('waterCourseLabel, departement et region sont nullables — une '
        'absence, jamais une chaîne vide (BR-007)', () {
      final OndePoint point = OndePoint(
        code: OndeStationCode('K4520001'),
        label: "Station sans cours d'eau connu",
        latitude: 47.5,
        longitude: 1.3,
        waterCourseLabel: null,
        departement: null,
      );

      expect(point.waterCourseLabel, isNull);
      expect(point.departement, isNull);
      expect(point.region, isNull);
    });
  });
}
