// Le favori (S1 de T3) : un lieu que l'usager choisit de retrouver. L'application
// en garde l'IDENTITÉ copiée à l'ajout (nom, code, date d'ajout), jamais une
// mesure. Type clos à quatre branches (BR-011) : une entrée que cette version
// ne sait pas lire reste un favori, affiché et retirable par son texte brut.
//
// La clé d'un lieu est le COUPLE type et code : un code ONDE est une chaîne
// libre (`onde_station_code.dart`), rien n'interdit qu'il égale un code
// station.
//
// Dart pur : aucune dépendance d'infrastructure.

import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Un favori. Quatre branches, closes : station hydrométrique, point ONDE,
/// tronçon de vigilance,
/// entrée illisible.
sealed class Favorite {
  const Favorite();
}

/// Une station hydrométrique en favori : son code et son libellé copiés à
/// l'ajout. Sans coordonnées.
final class StationFavorite extends Favorite {
  /// Lève une [ArgumentError] si [addedAt] n'est pas en UTC ou si [label] est
  /// blanc.
  StationFavorite({
    required this.code,
    required this.label,
    required this.addedAt,
  }) {
    _requireUtc(addedAt);
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'libellé blanc');
    }
  }

  final StationCode code;
  final String label;

  /// Instant d'ajout, en UTC.
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is StationFavorite &&
      other.code == code &&
      other.label == label &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(code, label, addedAt);
}

/// Un point ONDE en favori : le point ENTIER, car la fiche s'ouvre avec lui.
final class OndePointFavorite extends Favorite {
  /// Lève une [ArgumentError] si [addedAt] n'est pas en UTC.
  OndePointFavorite({required this.point, required this.addedAt}) {
    _requireUtc(addedAt);
  }

  final OndePoint point;

  /// Instant d'ajout, en UTC.
  final DateTime addedAt;

  // `OndePoint` n'a pas d'`==` et n'en reçoit pas : ses sept champs sont
  // comparés un à un ici.
  @override
  bool operator ==(Object other) =>
      other is OndePointFavorite &&
      other.addedAt == addedAt &&
      other.point.code == point.code &&
      other.point.label == point.label &&
      other.point.latitude == point.latitude &&
      other.point.longitude == point.longitude &&
      other.point.waterCourseLabel == point.waterCourseLabel &&
      other.point.departement == point.departement &&
      other.point.region == point.region;

  @override
  int get hashCode => Object.hash(
    addedAt,
    point.code,
    point.label,
    point.latitude,
    point.longitude,
    point.waterCourseLabel,
    point.departement,
    point.region,
  );
}

/// Un tronçon de vigilance en favori (M1 de T5) : son code et le nom publié
/// AU MOMENT DE L'AJOUT. Le nom est une copie d'identité, jamais un état ; il
/// ne se rafraîchit pas.
final class FloodSectionFavorite extends Favorite {
  /// Lève une [ArgumentError] si [addedAt] n'est pas en UTC ou si [name] est
  /// blanc.
  FloodSectionFavorite({
    required this.code,
    required this.name,
    required this.addedAt,
  }) {
    _requireUtc(addedAt);
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'nom blanc');
    }
  }

  final FloodSectionCode code;

  /// Le nom publié du tronçon, copié à l'ajout.
  final String name;

  /// Instant d'ajout, en UTC.
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is FloodSectionFavorite &&
      other.code == code &&
      other.name == name &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(code, name, addedAt);
}

/// Une entrée stockée que cette version ne sait pas lire : gardée, affichée
/// par son [label] s'il est connu, retirable par son texte [raw].
final class UnreadableFavorite extends Favorite {
  const UnreadableFavorite({required this.raw, this.label});

  /// Le texte brut stocké.
  final String raw;
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is UnreadableFavorite && other.raw == raw && other.label == label;

  @override
  int get hashCode => Object.hash(raw, label);
}

/// Vrai si [a] et [b] désignent le même lieu : même type ET même code
/// (stations, points ONDE) ou même texte brut (illisibles). Deux types
/// différents ne désignent jamais le même lieu.
bool sameFavoritePlace(Favorite a, Favorite b) => switch ((a, b)) {
  (final StationFavorite x, final StationFavorite y) => x.code == y.code,
  (final OndePointFavorite x, final OndePointFavorite y) =>
    x.point.code == y.point.code,
  (final UnreadableFavorite x, final UnreadableFavorite y) => x.raw == y.raw,
  (final FloodSectionFavorite x, final FloodSectionFavorite y) =>
    x.code == y.code,
  (StationFavorite(), _) => false,
  (OndePointFavorite(), _) => false,
  (FloodSectionFavorite(), _) => false,
  (UnreadableFavorite(), _) => false,
};

/// Le favori station de code [code] dans [favorites], ou `null`.
StationFavorite? stationFavoriteIn(
  Iterable<Favorite> favorites,
  StationCode code,
) {
  for (final Favorite f in favorites) {
    if (f is StationFavorite && f.code == code) {
      return f;
    }
  }
  return null;
}

/// Le favori point ONDE de code [code] dans [favorites], ou `null`.
OndePointFavorite? ondePointFavoriteIn(
  Iterable<Favorite> favorites,
  OndeStationCode code,
) {
  for (final Favorite f in favorites) {
    if (f is OndePointFavorite && f.point.code == code) {
      return f;
    }
  }
  return null;
}

/// Le favori tronçon de code [code] dans [favorites], ou `null`.
FloodSectionFavorite? floodSectionFavoriteIn(
  Iterable<Favorite> favorites,
  FloodSectionCode code,
) {
  for (final Favorite f in favorites) {
    if (f is FloodSectionFavorite && f.code == code) {
      return f;
    }
  }
  return null;
}

void _requireUtc(DateTime addedAt) {
  if (!addedAt.isUtc) {
    throw ArgumentError.value(addedAt, 'addedAt', 'doit être en UTC');
  }
}
