// Verrouille GeoPoint, le point désigné par l'usager sur la carte (T2, M1) —
// seule entrée géographique de T2 (Q1-A). Une paire de `double` nus ouvrirait
// la porte à une inversion latitude/longitude ; la validation à la
// construction rend le `400` de VigiEau impossible (VG-10).

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

void main() {
  group('GeoPoint', () {
    test('accepte un point valide', () {
      final GeoPoint point = GeoPoint(latitude: 46.2051, longitude: 5.2256);

      expect(point.latitude, 46.2051);
      expect(point.longitude, 5.2256);
    });

    test('accepte les bornes, incluses', () {
      expect(() => GeoPoint(latitude: 90, longitude: 180), returnsNormally);
      expect(() => GeoPoint(latitude: -90, longitude: -180), returnsNormally);
    });

    test('une latitude au-dela de 90 est refusee a la construction', () {
      expect(
        () => GeoPoint(latitude: 90.0000001, longitude: 0),
        throwsArgumentError,
      );
    });

    test('une longitude au-dela de -180 est refusee a la construction', () {
      expect(
        () => GeoPoint(latitude: 0, longitude: -180.0000001),
        throwsArgumentError,
      );
    });

    test('double.nan est refuse sur chaque coordonnee', () {
      expect(
        () => GeoPoint(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: double.nan),
        throwsArgumentError,
      );
    });

    test('double.infinity est refuse sur chaque coordonnee', () {
      expect(
        () => GeoPoint(latitude: double.infinity, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => GeoPoint(latitude: 0, longitude: double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('aucun arrondi : la valeur est rendue a l identique', () {
      final GeoPoint point = GeoPoint(
        latitude: 46.20512345678,
        longitude: 5.2256,
      );

      expect(point.latitude, 46.20512345678);
    });

    test('deux points aux memes coordonnees sont egaux, et partagent le '
        'meme hashCode', () {
      final GeoPoint a = GeoPoint(latitude: 46.2051, longitude: 5.2256);
      final GeoPoint b = GeoPoint(latitude: 46.2051, longitude: 5.2256);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('latitude et longitude ne sont pas interchangeables', () {
      final GeoPoint a = GeoPoint(latitude: 1, longitude: 2);
      final GeoPoint b = GeoPoint(latitude: 2, longitude: 1);

      expect(a, isNot(b));
    });
  });
}
