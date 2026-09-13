// Verrouille la forme du code station ONDE : huit caracteres, jamais dix
// (T-04). OndeStationCode et StationCode (Hub'Eau hydrometrie, dix
// caracteres) sont deux referentiels distincts qui ne se substituent jamais
// l'un a l'autre : un code de l'un ne doit jamais passer la validation de
// l'autre.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndeStationCode (T-04)', () {
    test("'K4520001' (huit caracteres) est accepte", () {
      expect(OndeStationCode('K4520001').value, 'K4520001');
    });

    test("'K447001001' (dix caracteres, forme StationCode) est refuse", () {
      expect(() => OndeStationCode('K447001001'), throwsArgumentError);
    });

    test("'k4520001' (minuscule) est refuse", () {
      expect(() => OndeStationCode('k4520001'), throwsArgumentError);
    });

    test('une chaine vide est refusee', () {
      expect(() => OndeStationCode(''), throwsArgumentError);
    });

    test('deux codes de meme valeur sont egaux et de meme hashCode', () {
      final OndeStationCode a = OndeStationCode('K4520001');
      final OndeStationCode b = OndeStationCode('K4520001');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString rend la valeur telle que validee', () {
      expect(OndeStationCode('K4520001').toString(), 'K4520001');
    });
  });
}
