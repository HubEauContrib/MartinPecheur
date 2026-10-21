// Le suivi d'un lieu et ce que l'on en a lu la dernière fois (M2 de T5,
// BR-016). Trois branches closes (BR-011) : un suivi de crue, un suivi de
// sécheresse, une entrée que cette version ne sait pas lire (gardée à
// l'identique, jamais écrasée).
//
// Les « derniers états » sont ce que la dernière vérification a relevé de
// PUBLIÉ : un niveau et sa date, ou les zones citées et leur date de lecture.
// Ils servent à repérer un changement ; ce n'est jamais un calcul.
//
// Dart pur. `dart:convert` y est admis (voir [sameFloodLevel]).

import 'dart:convert';

import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/value_equality.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// La série d'échecs en cours pour un lieu : on ne dit l'échec qu'une fois par
/// série, au premier échec (BR-007 : il se dit, sans se répéter).
enum FailureSeries {
  /// La source n'a pas pu être lue.
  checkImpossible,

  /// Le lieu lui-même ne peut pas être vérifié (tronçon absent de la carte
  /// publiée, point hors des zones citées…).
  notVerifiable,
}

/// Le dernier niveau de vigilance lu pour un tronçon, avec la date de
/// l'information de vigilance.
final class LastKnownFloodLevel {
  const LastKnownFloodLevel({
    required this.level,
    required this.informationDate,
  });

  final FloodVigilanceLevel level;

  /// Date de l'information de vigilance publiée, en UTC.
  final DateTime informationDate;

  @override
  bool operator ==(Object other) =>
      other is LastKnownFloodLevel &&
      sameFloodLevel(other.level, level) &&
      other.informationDate == informationDate;

  @override
  int get hashCode => Object.hash(level.runtimeType, informationDate);
}

/// Une zone d'alerte citée à la dernière lecture : ce qui suffit à repérer un
/// changement de gravité ou d'arrêté.
final class KnownZone {
  const KnownZone({
    required this.name,
    required this.kind,
    required this.severity,
    required this.decreeValidFrom,
  });

  final String name;
  final ZoneKind kind;
  final DroughtSeverity severity;

  /// Date de début de validité de l'arrêté, en UTC.
  final DateTime decreeValidFrom;

  @override
  bool operator ==(Object other) =>
      other is KnownZone &&
      other.name == name &&
      sameZoneKind(other.kind, kind) &&
      sameDroughtSeverity(other.severity, severity) &&
      other.decreeValidFrom == decreeValidFrom;

  @override
  int get hashCode => Object.hash(
    name,
    kind.runtimeType,
    severity.runtimeType,
    decreeValidFrom,
  );
}

/// Les zones citées à la dernière lecture d'un lieu de sécheresse.
final class LastKnownZones {
  LastKnownZones({required this.readAt, required List<KnownZone> zones})
    : zones = List<KnownZone>.unmodifiable(zones);

  /// Instant de la lecture, en UTC.
  final DateTime readAt;
  final List<KnownZone> zones;

  @override
  bool operator ==(Object other) =>
      other is LastKnownZones &&
      other.readAt == readAt &&
      listEquals(other.zones, zones);

  @override
  int get hashCode => Object.hash(readAt, zones.length);
}

/// Un suivi. Trois branches, closes.
sealed class FollowUp {
  const FollowUp();
}

/// Le suivi d'un tronçon : un seuil, le dernier niveau lu, la série d'échecs.
final class FloodFollowUp extends FollowUp {
  const FloodFollowUp({
    required this.place,
    required this.threshold,
    this.lastKnown,
    this.series,
  });

  final FloodSectionPlace place;
  final FloodThreshold threshold;
  final LastKnownFloodLevel? lastKnown;
  final FailureSeries? series;

  @override
  bool operator ==(Object other) =>
      other is FloodFollowUp &&
      other.place == place &&
      other.threshold == threshold &&
      other.lastKnown == lastKnown &&
      other.series == series;

  @override
  int get hashCode => Object.hash(place, threshold, lastKnown, series);
}

/// Le suivi d'une station ou d'un point ONDE pour les restrictions : les
/// dernières zones lues, la série d'échecs.
final class DroughtFollowUp extends FollowUp {
  const DroughtFollowUp({required this.place, this.lastKnown, this.series});

  final DroughtPlace place;
  final LastKnownZones? lastKnown;
  final FailureSeries? series;

  @override
  bool operator ==(Object other) =>
      other is DroughtFollowUp &&
      other.place == place &&
      other.lastKnown == lastKnown &&
      other.series == series;

  @override
  int get hashCode => Object.hash(place, lastKnown, series);
}

/// Une entrée stockée que cette version ne sait pas lire : gardée telle
/// quelle ([raw]), jamais écrasée sauf par « Repartir sans lieu suivi ».
final class UnreadableFollowUp extends FollowUp {
  const UnreadableFollowUp({required this.raw});

  /// Le texte brut stocké.
  final String raw;

  @override
  bool operator ==(Object other) =>
      other is UnreadableFollowUp && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

/// Vrai si [a] et [b] sont le même niveau : même branche ; pour un niveau
/// inconnu, même brut.
///
/// `raw` est un `Object?` qui peut être une `Map` ou une `List`
/// (`flood_vigilance_level.dart`) : après un aller-retour JSON, deux telles
/// valeurs ne sont jamais `==`. Deux bruts sont donc égaux si leur encodage
/// JSON l'est. Un brut que `jsonEncode` refuse n'est égal qu'à lui-même.
bool sameFloodLevel(FloodVigilanceLevel a, FloodVigilanceLevel b) =>
    switch ((a, b)) {
      (Vert(), Vert()) => true,
      (Jaune(), Jaune()) => true,
      (Orange(), Orange()) => true,
      (Rouge(), Rouge()) => true,
      (
        NiveauCruesInconnu(raw: final Object? x),
        NiveauCruesInconnu(raw: final Object? y),
      ) =>
        _sameRaw(x, y),
      (Vert(), _) => false,
      (Jaune(), _) => false,
      (Orange(), _) => false,
      (Rouge(), _) => false,
      (NiveauCruesInconnu(), _) => false,
    };

// La comparaison par `jsonEncode` est sensible à l'ORDRE DES CLÉS d'une `Map`
// brute : deux Map de mêmes clés dans un autre ordre sont jugées différentes
// (règle du plan, assumée).
bool _sameRaw(Object? x, Object? y) {
  if (identical(x, y)) {
    return true;
  }
  try {
    return jsonEncode(x) == jsonEncode(y);
  } on Object {
    return false;
  }
}

/// Vrai si [a] et [b] sont la même gravité : même branche ; pour une gravité
/// inconnue, même `rawValue`.
bool sameDroughtSeverity(DroughtSeverity a, DroughtSeverity b) =>
    switch ((a, b)) {
      (Vigilance(), Vigilance()) => true,
      (Alerte(), Alerte()) => true,
      (AlerteRenforcee(), AlerteRenforcee()) => true,
      (Crise(), Crise()) => true,
      (
        GraviteInconnue(rawValue: final String? x),
        GraviteInconnue(rawValue: final String? y),
      ) =>
        x == y,
      (Vigilance(), _) => false,
      (Alerte(), _) => false,
      (AlerteRenforcee(), _) => false,
      (Crise(), _) => false,
      (GraviteInconnue(), _) => false,
    };

/// Vrai si [a] et [b] sont le même type de zone : même branche ; pour un type
/// inconnu, même `rawValue`.
bool sameZoneKind(ZoneKind a, ZoneKind b) => switch ((a, b)) {
  (EauxSuperficielles(), EauxSuperficielles()) => true,
  (EauxSouterraines(), EauxSouterraines()) => true,
  (EauPotable(), EauPotable()) => true,
  (
    TypeZoneInconnu(rawValue: final String? x),
    TypeZoneInconnu(rawValue: final String? y),
  ) =>
    x == y,
  (EauxSuperficielles(), _) => false,
  (EauxSouterraines(), _) => false,
  (EauPotable(), _) => false,
  (TypeZoneInconnu(), _) => false,
};

/// Le lieu que suit [followUp], ou `null` pour un suivi illisible.
FollowedPlace? placeOfFollowUp(FollowUp followUp) => switch (followUp) {
  FloodFollowUp(:final place) => place,
  DroughtFollowUp(:final place) => place,
  UnreadableFollowUp() => null,
};

/// Le suivi de [place] dans [followUps], ou `null`.
FollowUp? followUpOf(Iterable<FollowUp> followUps, FollowedPlace place) {
  for (final FollowUp followUp in followUps) {
    if (placeOfFollowUp(followUp) == place) {
      return followUp;
    }
  }
  return null;
}

/// Vrai s'il existe un suivi lisible dont le lieu est celui d'un favori.
bool followsAnyPlace(
  Iterable<Favorite> favorites,
  Iterable<FollowUp> followUps,
) {
  for (final Favorite favorite in favorites) {
    final FollowedPlace? place = followedPlaceOf(favorite);
    if (place != null && followUpOf(followUps, place) != null) {
      return true;
    }
  }
  return false;
}
