// Le lieu suivi (M2 de T5) : ce que l'usager choisit d'être prévenu de relire.
// Type clos à trois branches (BR-011) : un tronçon de vigilance, une station
// ou un point ONDE. Les deux dernières relèvent de la sécheresse
// ([DroughtPlace]). Un lieu est toujours déduit d'un favori : son identité, son
// code, jamais une mesure.
//
// Dart pur : aucune dépendance d'infrastructure.

import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Un lieu suivi. Trois branches, closes.
sealed class FollowedPlace {
  const FollowedPlace();
}

/// Un tronçon de vigilance crues suivi, par son code publié.
final class FloodSectionPlace extends FollowedPlace {
  const FloodSectionPlace(this.code);

  final FloodSectionCode code;

  @override
  bool operator ==(Object other) =>
      other is FloodSectionPlace && other.code == code;

  @override
  int get hashCode => Object.hash(FloodSectionPlace, code);
}

/// Un lieu suivi pour les restrictions de sécheresse : une station ou un point
/// ONDE. Deux branches, closes.
sealed class DroughtPlace extends FollowedPlace {
  const DroughtPlace();
}

/// Une station hydrométrique suivie.
final class StationPlace extends DroughtPlace {
  const StationPlace(this.code);

  final StationCode code;

  @override
  bool operator ==(Object other) => other is StationPlace && other.code == code;

  @override
  int get hashCode => Object.hash(StationPlace, code);
}

/// Un point ONDE suivi.
final class OndePointPlace extends DroughtPlace {
  const OndePointPlace(this.code);

  final OndeStationCode code;

  @override
  bool operator ==(Object other) =>
      other is OndePointPlace && other.code == code;

  @override
  int get hashCode => Object.hash(OndePointPlace, code);
}

/// Le lieu suivi que désigne [favorite], ou `null` pour une entrée illisible
/// (elle n'a pas de code sûr).
FollowedPlace? followedPlaceOf(Favorite favorite) => switch (favorite) {
  StationFavorite(:final StationCode code) => StationPlace(code),
  OndePointFavorite(:final point) => OndePointPlace(point.code),
  FloodSectionFavorite(:final FloodSectionCode code) => FloodSectionPlace(code),
  UnreadableFavorite() => null,
};
