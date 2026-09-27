// Le point désigné par l'usager sur la carte. Rangé sous `lib/domain/geo/` à
// côté de `bounds.dart` — même méthode : une classe, pas un `extension
// type`, parce qu'elle valide.
//
// Seule entrée géographique de T2 (Q1-A). Une paire de `double` nus ouvrirait
// la porte à une inversion latitude/longitude ; la validation à la
// construction rend impossible l'envoi de coordonnées hors plage à une
// source distante.
//
// Dart pur : ce fichier ne connaît ni carte, ni `latlong2`, ni `flutter_map`.

/// Point géographique désigné, en degrés décimaux, WGS 84.
///
/// Une classe et non un `extension type` : comme [Bounds][], elle **valide**.
/// Jamais `const` : la validation à la construction l'interdit.
final class GeoPoint {
  /// Valide que [latitude] est dans `[-90, 90]` et [longitude] dans
  /// `[-180, 180]`, bornes incluses, et qu'aucune des deux n'est `NaN` ni
  /// infinie. Lève une [ArgumentError] sinon. Aucun arrondi.
  factory GeoPoint({required double latitude, required double longitude}) {
    if (latitude.isNaN ||
        latitude.isInfinite ||
        latitude < -90 ||
        latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'doit etre finie et comprise entre -90 et 90',
      );
    }
    if (longitude.isNaN ||
        longitude.isInfinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'doit etre finie et comprise entre -180 et 180',
      );
    }

    return GeoPoint._(latitude: latitude, longitude: longitude);
  }

  const GeoPoint._({required this.latitude, required this.longitude});

  /// Latitude, en degrés décimaux.
  final double latitude;

  /// Longitude, en degrés décimaux.
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint(latitude: $latitude, longitude: $longitude)';
}
