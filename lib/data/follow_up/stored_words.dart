// Les mots de stockage partagés des suivis (D2) et des avis (D3 de T5) : un
// seul endroit pour la façon d'écrire et de lire un niveau, une gravité, un
// type de zone, une zone citée et un instant. Deux codecs qui les
// recopieraient pourraient diverger : un mot oublié d'un décodeur relirait,
// sans bruit, des entrées comme illisibles.
//
// Les mots sont ceux du projet, jamais ceux d'une API : `vert`, `jaune`,
// `alerte-renforcee` (avec le tiret), `eaux-superficielles`… Un niveau, une
// gravité ou un type de zone que cette version ne reconnaît pas s'écrit
// `{"inconnu":<brut>}` (ou `{"inconnue":<brut>}`), brut conservé : `5` et
// `"5"` restent distincts.
//
// Une lecture qui échoue lève [UnreadableStoredEntry] : chaque codec la
// traduit en entrée illisible, gardée telle quelle.

import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// Une entrée que cette version ne sait pas lire.
final class UnreadableStoredEntry implements Exception {
  const UnreadableStoredEntry();
}

/// Un instant, écrit en ISO 8601 UTC.
String encodeStoredInstant(DateTime instant) =>
    instant.toUtc().toIso8601String();

/// Un instant ISO 8601 portant son fuseau, rendu en UTC. Une date sans fuseau
/// serait lue à l'heure du poste : refusée (`null`).
DateTime? readStoredInstant(Object? value) {
  if (value is! String) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);

  return parsed != null && parsed.isUtc ? parsed : null;
}

DateTime requireStoredInstant(Object? value) =>
    readStoredInstant(value) ?? (throw const UnreadableStoredEntry());

String requireStoredString(Object? value) =>
    value is String ? value : throw const UnreadableStoredEntry();

FloodThreshold readStoredThreshold(Object? value) => switch (value) {
  'jaune' => FloodThreshold.jaune,
  'orange' => FloodThreshold.orange,
  'rouge' => FloodThreshold.rouge,
  _ => throw const UnreadableStoredEntry(),
};

/// Le seuil s'écrit par son nom : `jaune`, `orange`, `rouge`.
String encodeStoredThreshold(FloodThreshold threshold) => threshold.name;

Object? encodeStoredLevel(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'vert',
  Jaune() => 'jaune',
  Orange() => 'orange',
  Rouge() => 'rouge',
  NiveauCruesInconnu() => <String, Object?>{'inconnu': level.raw},
};

Object? encodeStoredSeverity(DroughtSeverity severity) => switch (severity) {
  Vigilance() => 'vigilance',
  Alerte() => 'alerte',
  AlerteRenforcee() => 'alerte-renforcee',
  Crise() => 'crise',
  GraviteInconnue() => <String, Object?>{'inconnue': severity.rawValue},
};

Object? encodeStoredZoneKind(ZoneKind kind) => switch (kind) {
  EauxSuperficielles() => 'eaux-superficielles',
  EauxSouterraines() => 'eaux-souterraines',
  EauPotable() => 'eau-potable',
  TypeZoneInconnu() => <String, Object?>{'inconnu': kind.rawValue},
};

/// Une zone citée : `nom`, `type_de_zone`, `gravite`, `arrete_depuis`.
Map<String, Object?> encodeStoredZone(KnownZone zone) => <String, Object?>{
  'nom': zone.name,
  'type_de_zone': encodeStoredZoneKind(zone.kind),
  'gravite': encodeStoredSeverity(zone.severity),
  'arrete_depuis': encodeStoredInstant(zone.decreeValidFrom),
};

KnownZone readStoredZone(Object? zone) {
  if (zone is! Map<String, Object?>) {
    throw const UnreadableStoredEntry();
  }

  return KnownZone(
    name: requireStoredString(zone['nom']),
    kind: readStoredZoneKind(zone['type_de_zone']),
    severity: readStoredSeverity(zone['gravite']),
    decreeValidFrom: requireStoredInstant(zone['arrete_depuis']),
  );
}

FloodVigilanceLevel readStoredLevel(Object? value) {
  if (value is Map<String, Object?> &&
      value.length == 1 &&
      value.containsKey('inconnu')) {
    return NiveauCruesInconnu(value['inconnu']);
  }

  return switch (value) {
    'vert' => const Vert(),
    'jaune' => const Jaune(),
    'orange' => const Orange(),
    'rouge' => const Rouge(),
    _ => throw const UnreadableStoredEntry(),
  };
}

DroughtSeverity readStoredSeverity(Object? value) {
  if (value is Map<String, Object?> &&
      value.length == 1 &&
      value.containsKey('inconnue')) {
    final Object? raw = value['inconnue'];
    if (raw != null && raw is! String) {
      throw const UnreadableStoredEntry();
    }

    return GraviteInconnue(raw as String?);
  }

  return switch (value) {
    'vigilance' => const Vigilance(),
    'alerte' => const Alerte(),
    'alerte-renforcee' => const AlerteRenforcee(),
    'crise' => const Crise(),
    _ => throw const UnreadableStoredEntry(),
  };
}

ZoneKind readStoredZoneKind(Object? value) {
  if (value is Map<String, Object?> &&
      value.length == 1 &&
      value.containsKey('inconnu')) {
    final Object? raw = value['inconnu'];
    if (raw != null && raw is! String) {
      throw const UnreadableStoredEntry();
    }

    return TypeZoneInconnu(raw as String?);
  }

  return switch (value) {
    'eaux-superficielles' => const EauxSuperficielles(),
    'eaux-souterraines' => const EauxSouterraines(),
    'eau-potable' => const EauPotable(),
    _ => throw const UnreadableStoredEntry(),
  };
}
