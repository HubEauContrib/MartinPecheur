// Verrouille la forme du code station ONDE : huit caractères, jamais dix
// (T-04). OndeStationCode et StationCode (Hub'Eau hydrométrie, dix
// caractères) sont deux référentiels distincts qui ne se substituent jamais
// l'un à l'autre : un code de l'un ne doit jamais passer la validation de
// l'autre.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndeStationCode (T-04)', () {
    test("'K4520001' (huit caractères) est accepté", () {
      expect(OndeStationCode('K4520001').value, 'K4520001');
    });

    test("'K447001001' (dix caractères, forme StationCode) est refusé", () {
      expect(() => OndeStationCode('K447001001'), throwsArgumentError);
    });

    test("'K452000' (sept caractères) et 'K45200011' (neuf caractères) "
        'sont refusés', () {
      expect(() => OndeStationCode('K452000'), throwsArgumentError);
      expect(() => OndeStationCode('K45200011'), throwsArgumentError);
    });

    test("'K452-001' (huit caractères, mais un tiret) est refusé", () {
      expect(() => OndeStationCode('K452-001'), throwsArgumentError);
    });

    test("'k4520001' (minuscule) est refusé", () {
      expect(() => OndeStationCode('k4520001'), throwsArgumentError);
    });

    test('une chaîne vide est refusée', () {
      expect(() => OndeStationCode(''), throwsArgumentError);
    });

    test('deux codes de même valeur sont égaux et de même hashCode', () {
      final OndeStationCode a = OndeStationCode('K4520001');
      final OndeStationCode b = OndeStationCode('K4520001');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString rend la valeur telle que validée', () {
      expect(OndeStationCode('K4520001').toString(), 'K4520001');
    });
  });
}
