// Verrouille la forme mesurée du code station (C-05) et la forme du code
// département en chaîne. C-05 reproduit le 2026-09-13 : le code site
// K4470010 (8 car.) renvoie chaque mesure en double, dont une ligne à
// code_station null — count 430 contre 216 pour le code station.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/station/station.dart';

void main() {
  group('StationCode (C-05)', () {
    test("'K447001001' est accepté — forme la plus fréquente", () {
      expect(StationCode('K447001001').value, 'K447001001');
    });

    test("'1011000101' est accepté — dix chiffres, forme des DOM", () {
      expect(StationCode('1011000101').value, '1011000101');
    });

    test("'K4470010' (8 car.) est refusé — c'est le code site de C-05", () {
      expect(() => StationCode('K4470010'), throwsArgumentError);
    });

    test('une chaîne vide ou de onze caractères est refusée', () {
      expect(() => StationCode(''), throwsArgumentError);
      expect(() => StationCode('K4470010012'), throwsArgumentError);
    });

    test("dix caractères mais mauvaise forme ('k447-01001', 'k447001001') "
        'sont refusés', () {
      expect(() => StationCode('k447-01001'), throwsArgumentError);
      expect(() => StationCode('k447001001'), throwsArgumentError);
    });

    test('deux codes de même valeur sont égaux et de même hashCode', () {
      final StationCode a = StationCode('K447001001');
      final StationCode b = StationCode('K447001001');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('DepartementCode', () {
    test("'41' reste '41', '2a' devient '2A', '2B' reste '2B', "
        "'971' reste '971'", () {
      expect(DepartementCode('41').value, '41');
      expect(DepartementCode('2a').value, '2A');
      expect(DepartementCode('2B').value, '2B');
      expect(DepartementCode('971').value, '971');
    });

    test("'1' (un seul chiffre) et 'ZZ' sont refusés", () {
      expect(() => DepartementCode('1'), throwsArgumentError);
      expect(() => DepartementCode('ZZ'), throwsArgumentError);
    });
  });

  group('Station', () {
    test('porte les champs du référentiel — K447001001, relevés le '
        '2026-09-13', () {
      final Station station = Station(
        code: StationCode('K447001001'),
        label: 'Le Loir à Vaas',
        latitude: 47.584957074,
        longitude: 1.335147948,
        departement: DepartementCode('41'),
        riverLabel: 'Le Loir',
        inService: true,
      );

      expect(station.code, StationCode('K447001001'));
      expect(station.latitude, 47.584957074);
      expect(station.longitude, 1.335147948);
      expect(station.departement, DepartementCode('41'));
      expect(station.inService, true);
    });

    test('sans cours d\'eau, riverLabel est null — jamais une chaîne vide '
        '(BR-007)', () {
      final Station station = Station(
        code: StationCode('1011000101'),
        label: 'Station DOM',
        latitude: 16.189402,
        longitude: -61.658989,
        departement: DepartementCode('971'),
        riverLabel: null,
        inService: true,
      );

      expect(station.riverLabel, isNull);
    });
  });
}
