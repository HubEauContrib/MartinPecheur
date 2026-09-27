// L'URI de `/zones` de VigiEau (conception T2 § 4.3). Un appel par point,
// `lat` et `lon` seulement :
// - ni `profil` : le filtrage par profil se fait dans le domaine sur les
//   quatre booleens `concerne*` (AR-1) — et la valeur du schema,
//   `collectivité` accentue, rend zero usage sans erreur ;
// - ni `commune` : `409` des qu'une commune porte plusieurs zones du meme
//   type (C-14).
// La signature n'offre ni l'un ni l'autre.
//
// Les coordonnees sont ecrites a sept decimales (environ 1 cm), jamais en
// notation exponentielle : `double.toString()` ecrit `1e-7` sous 10^-6, et la
// longitude passe pres de 0 en France (meridien de Greenwich). Le
// comportement du validateur de l'API sur un exposant n'est pas verifie : on
// ne l'expose pas. La MEME chaine sert de cle de cache (D4 de T2) — lecon
// N1 d'ONDE : deux fonctions n'ont pas a s'accorder sur « le meme point ».
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// Hote de l'API VigiEau, en version `0.1` (`docs/sources/vigieau.md`,
/// VG-01, constate le 2026-09-27).
const String _host = 'api.vigieau.beta.gouv.fr';

/// Chemin de `/zones`, sous le prefixe `/api`.
const String _zonesPath = '/api/zones';

/// Nombre de decimales des coordonnees : environ 1 cm.
const int _fractionDigits = 7;

/// `lat` et `lon` de [point], en notation decimale a sept decimales, sans
/// exposant. Un zero negatif (`-1e-9` arrondi) s'ecrit `0.0000000`, jamais
/// `-0.0000000` : un meme point n'a qu'une ecriture. Sert aussi de cle de
/// cache.
({String lat, String lon}) formatPointParameters(GeoPoint point) => (
  lat: _formatCoordinate(point.latitude),
  lon: _formatCoordinate(point.longitude),
);

/// `https://api.vigieau.beta.gouv.fr/api/zones?lat=…&lon=…`, construite
/// avec [formatPointParameters].
Uri zonesUri(GeoPoint point) {
  final ({String lat, String lon}) parameters = formatPointParameters(point);
  return Uri(
    scheme: 'https',
    host: _host,
    path: _zonesPath,
    queryParameters: <String, String>{
      'lat': parameters.lat,
      'lon': parameters.lon,
    },
  );
}

String _formatCoordinate(double value) {
  final String formatted = value.toStringAsFixed(_fractionDigits);
  // `toStringAsFixed` garde le signe d'une valeur negative arrondie a zero.
  return double.parse(formatted) == 0
      ? (0.0).toStringAsFixed(_fractionDigits)
      : formatted;
}
