// Verrouille le contrat **verbatim** du code station ONDE (T-14, constaté le
// 2026-09-14 sur la page nationale : 147 codes distincts hors `^[A-Z0-9]{8}$`,
// dont `A721 3011` à espace intérieur). La forme à huit caractères de `T-04`
// est vraie sur la Loire et fausse à l'échelle nationale : elle ne peut donc
// plus servir de garde-fou. Ce qui sépare ONDE d'Hub'Eau hydrométrie n'est
// plus la forme mais le **type** — `OndeStationCode` et `StationCode` sont
// deux classes distinctes, jamais convertibles l'une en l'autre.
//
// L'espace est significatif pour l'API (T-14) : `?code_station=A721%203011`
// et `?code_station=A7213011` rendent deux historiques différents. Aucun
// `trim`, aucune suppression d'espace, aucune normalisation de casse.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

void main() {
  group('OndeStationCode — toute chaîne non blanche, verbatim (T-14)', () {
    test("'K4520001' (la forme Loire de T-04) est accepté", () {
      expect(OndeStationCode('K4520001').value, 'K4520001');
    });

    test("'A721 3011' (espace intérieur, neuf caractères) est accepté "
        'verbatim', () {
      expect(OndeStationCode('A721 3011').value, 'A721 3011');
    });

    test("'S224' (quatre caractères) est accepté verbatim", () {
      expect(OndeStationCode('S224').value, 'S224');
    });

    test("' O968 5312 ' (espaces de bord) est accepté sans trim : les "
        "espaces de bord font partie du code tel que l'API le rend", () {
      expect(OndeStationCode(' O968 5312 ').value, ' O968 5312 ');
    });

    test("'K447001001' (dix caractères, forme StationCode) est accepté comme "
        'chaîne : la séparation des deux référentiels tient au type, plus à '
        'la forme', () {
      expect(OndeStationCode('K447001001').value, 'K447001001');
    });

    test("'k4520001' (minuscule) est accepté sans normalisation de casse", () {
      expect(OndeStationCode('k4520001').value, 'k4520001');
    });

    test("'A721 3011' et 'A7213011' sont deux codes distincts — l'espace est "
        "significatif pour l'API (T-14)", () {
      expect(
        OndeStationCode('A721 3011') == OndeStationCode('A7213011'),
        isFalse,
      );
    });

    test('une chaîne vide est refusée', () {
      expect(() => OndeStationCode(''), throwsArgumentError);
    });

    test("une chaîne entièrement blanche ('  ') est refusée", () {
      expect(() => OndeStationCode('  '), throwsArgumentError);
    });

    test(
      "une chaîne blanche non composée d'espaces ('\\t\\n') est refusée",
      () {
        expect(() => OndeStationCode('\t\n'), throwsArgumentError);
      },
    );

    test('deux codes de même valeur sont égaux et de même hashCode', () {
      final OndeStationCode a = OndeStationCode('A721 3011');
      final OndeStationCode b = OndeStationCode('A721 3011');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString rend la valeur telle quelle, espaces compris', () {
      expect(OndeStationCode('A721 3011').toString(), 'A721 3011');
    });
  });
}
