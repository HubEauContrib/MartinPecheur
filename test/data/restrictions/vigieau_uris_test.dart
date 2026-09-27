// Verrouille l'URI de `/zones` (conception T2 § 4.3, AR-1) : un appel par
// point, `lat` et `lon` seulement — ni `profil` (le filtrage par profil se
// fait dans le domaine), ni `commune` (409, C-14). Les coordonnees sont
// ecrites a sept decimales, jamais en notation exponentielle : la meme
// chaine sert de cle de cache (D4 de T2), deux ecritures d'un meme point
// feraient deux entrees.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/vigieau_uris.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

void main() {
  group('zonesUri', () {
    test('hote, chemin et schema exacts', () {
      final Uri uri = zonesUri(GeoPoint(latitude: 46.2, longitude: 5.226));

      expect(uri.scheme, 'https');
      expect(uri.host, 'api.vigieau.beta.gouv.fr');
      expect(uri.path, '/api/zones');
    });

    test('parametres exactement lat et lon : ni profil, ni commune', () {
      final Uri uri = zonesUri(GeoPoint(latitude: 46.2, longitude: 5.226));

      expect(uri.queryParameters.keys.toSet(), <String>{'lat', 'lon'});
      expect(uri.queryParameters['lat'], '46.2000000');
      expect(uri.queryParameters['lon'], '5.2260000');
    });

    test('construite avec formatPointParameters : la meme chaine que la cle '
        'de cache', () {
      final GeoPoint point = GeoPoint(latitude: 42.9648, longitude: 1e-7);
      final ({String lat, String lon}) formatted = formatPointParameters(point);

      final Uri uri = zonesUri(point);

      expect(uri.queryParameters['lat'], formatted.lat);
      expect(uri.queryParameters['lon'], formatted.lon);
      expect(
        uri.toString(),
        'https://api.vigieau.beta.gouv.fr/api/zones'
        '?lat=42.9648000&lon=0.0000001',
      );
    });
  });

  group('formatPointParameters — sept decimales, jamais d exposant', () {
    String lon(double value) =>
        formatPointParameters(GeoPoint(latitude: 0, longitude: value)).lon;
    String lat(double value) =>
        formatPointParameters(GeoPoint(latitude: value, longitude: 0)).lat;

    test('1e-7 s ecrit 0.0000001, pas 1e-7', () {
      expect(lon(1e-7), '0.0000001');
    });

    test('46.2 s ecrit 46.2000000', () {
      expect(lat(46.2), '46.2000000');
    });

    test('-1e-7 s ecrit -0.0000001', () {
      expect(lon(-1e-7), '-0.0000001');
    });

    test('-1e-9 s ecrit 0.0000000, jamais -0.0000000 : deux cles pour un '
        'meme point', () {
      expect(lon(-1e-9), '0.0000000');
      expect(lon(-0.0), '0.0000000');
      expect(lon(0), '0.0000000');
    });

    test('bornes et valeurs negatives', () {
      expect(lat(-90), '-90.0000000');
      expect(lon(180), '180.0000000');
      expect(lon(-52.3), '-52.3000000');
    });

    test('aucune ecriture ne contient d exposant', () {
      for (final double value in <double>[1e-7, 1e-8, 5e-7, -3e-7, 1e-12]) {
        expect(lon(value), isNot(contains('e')), reason: '$value');
      }
    });
  });
}
