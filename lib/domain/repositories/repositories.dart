// Les depots restent betes : ils lisent, ils n'orchestrent pas, et ils ne
// decident pas de la politique de cache — cela reste au seul decorateur
// CachePolicy (couche application). Un ecran n'appelle jamais un depot : il
// envoie une Query ou une Command, un handler orchestre.
//
// Bounds refuse une emprise inversee a la construction : west >= east ou
// south >= north ne leverait aucune erreur reseau, la carte s'afficherait
// simplement vide, ce que l'ecran presenterait comme « aucune station »
// (BR-007) — un faux negatif silencieux plutot qu'une erreur explicite.
// L'antimeridien (longitude proche de +180/-180) n'est pas traite : aucune
// emprise francaise ne le franchit.

import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Emprise rectangulaire en degres decimaux, WGS 84.
///
/// Une classe et non un `extension type` : comme [StationCode], elle
/// **valide**. Jamais `const` : la validation a la construction l'interdit.
final class Bounds {
  /// Valide que [west] < [east] et [south] < [north]. Leve une
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

  /// Bord ouest, en degres decimaux (negatif a l'ouest de Greenwich).
  final double west;

  /// Bord sud, en degres decimaux.
  final double south;

  /// Bord est, en degres decimaux.
  final double east;

  /// Bord nord, en degres decimaux.
  final double north;
}

/// Depot du referentiel des stations. Lit, ne decide de rien : ni cache, ni
/// orchestration.
abstract interface class StationRepository {
  /// La station de code [code], ou `null` si aucune station ne porte ce
  /// code (BR-007) — jamais une erreur pour une absence attendue.
  Future<Station?> findByCode(StationCode code);

  /// Les stations dont les coordonnees tombent dans [bounds]. Filtre a la
  /// source : jamais charger les 4 150 stations du referentiel pour filtrer
  /// ensuite en memoire.
  Future<List<Station>> findWithinBounds(Bounds bounds);

  /// Les stations du departement [code].
  Future<List<Station>> findByDepartement(DepartementCode code);
}

/// Depot des observations hydrometriques. Lit la derniere observation
/// connue, ne calcule ni fraicheur ni conversion — deja faites en amont
/// (mapper, BR-002).
abstract interface class HydroObservationRepository {
  /// La derniere observation connue pour [station] et [grandeur].
  /// [grandeur] est obligatoire : une hauteur et un debit ne sont jamais
  /// confondus.
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur);
}
