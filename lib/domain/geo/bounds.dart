// L'emprise rectangulaire, et rien d'autre. Rangée sous `lib/domain/geo/` à
// côté de `viewport_filter.dart` — et non plus dans
// `domain/repositories/repositories.dart` où elle vivait jusqu'à la relecture
// du 2026-09-13 : la vue construit une emprise à chaque relâchement de geste,
// et elle n'a aucune raison d'importer les contrats de dépôt pour cela. Un
// import est une dépendance, même quand on ne se sert que d'un type du
// fichier.
//
// Dart pur : ce fichier ne connaît ni carte, ni `latlong2`, ni `flutter_map`.
// L'antiméridien (longitude proche de +180/-180) n'est pas traité : aucune
// emprise française ne le franchit.

/// Emprise rectangulaire en degrés décimaux, WGS 84.
///
/// Une classe et non un `extension type` : comme `StationCode`, elle
/// **valide**. Jamais `const` : la validation à la construction l'interdit.
///
/// Elle refuse une emprise inversée à la construction — `west >= east` ou
/// `south >= north` ne lèverait aucune erreur réseau, la carte s'afficherait
/// simplement vide, ce que l'écran présenterait comme « aucune station »
/// (BR-007) : un faux négatif silencieux plutôt qu'une erreur explicite.
final class Bounds {
  /// Valide que [west] < [east] et [south] < [north]. Lève une
  /// [ArgumentError] sinon.
  factory Bounds({
    required double west,
    required double south,
    required double east,
    required double north,
  }) {
    if (west >= east) {
      throw ArgumentError.value(
        east,
        'east',
        'doit etre strictement superieur a west ($west)',
      );
    }
    if (south >= north) {
      throw ArgumentError.value(
        north,
        'north',
        'doit etre strictement superieur a south ($south)',
      );
    }

    return Bounds._(west: west, south: south, east: east, north: north);
  }

  const Bounds._({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  /// Bord ouest, en degrés décimaux (négatif à l'ouest de Greenwich).
  final double west;

  /// Bord sud, en degrés décimaux.
  final double south;

  /// Bord est, en degrés décimaux.
  final double east;

  /// Bord nord, en degrés décimaux.
  final double north;
}
