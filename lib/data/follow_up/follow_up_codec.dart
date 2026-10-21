// La forme stockée des suivis (D2 de T5) : UNE chaîne JSON,
// `{"version":1,"derniere_verification":<ISO UTC>|null,"suivis":[…]}`, chaque
// entrée portant son `type` (`crues` ou `secheresse`). Fonctions pures : ce
// fichier ne lit ni n'écrit aucun stockage, le dépôt le branche.
//
// Les mots stockés sont ceux du projet, jamais ceux d'une API : `jaune`,
// `alerte-renforcee` (avec le tiret), `eaux-superficielles`,
// `verification-impossible`… Un niveau, une gravité ou un type de zone que
// cette version ne reconnaît pas s'écrit `{"inconnu":<brut>}` (ou
// `{"inconnue":<brut>}`), brut conservé : `5` et `"5"` restent distincts.
//
// Deux échelles d'illisible, une seule règle (modèle : `favorites_codec.dart`) :
// - l'ENTRÉE qui ne se lit pas devient un `UnreadableFollowUp`, gardé à sa
//   place et réécrit tel quel ;
// - la VALEUR qui ne se lit pas (pas du JSON, racine inattendue, version
//   absente ou future, `suivis` qui n'est pas une liste) LÈVE `SuiviIllisible` :
//   elle ne rend jamais un livre vide, qui se lirait « aucun lieu suivi » et
//   s'écraserait à la première écriture (BR-007).
//
// Le code ONDE s'écrit verbatim, espaces compris.

import 'dart:convert';

import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// La version de la forme stockée que ce code écrit, et la plus haute qu'il
/// sait lire.
const int followUpsFormatVersion = 1;

const String _typeFlood = 'crues';
const String _typeDrought = 'secheresse';
const String _placeStation = 'station';
const String _placeOnde = 'onde';

/// Lit la valeur stockée [stored]. `null` (rien n'a jamais été écrit) rend un
/// livre vide. Une entrée illisible est rendue [UnreadableFollowUp], à sa
/// place.
///
/// Lève [SuiviIllisible] si [stored] n'est pas du JSON, si sa racine n'est pas
/// un objet, si `version` est absente, non entière, inférieure à 1 ou
/// supérieure à [followUpsFormatVersion], si `suivis` n'est pas une liste, ou
/// si `derniere_verification` n'est ni nulle ni un instant UTC — jamais un
/// livre vide dans ces cas.
FollowUpBook decodeFollowUps(String? stored) {
  if (stored == null) {
    return FollowUpBook(followUps: <FollowUp>[]);
  }

  final Object? root;
  try {
    root = jsonDecode(stored);
  } on FormatException catch (error) {
    throw SuiviIllisible(
      "la valeur stockée n'est pas du JSON : ${error.message}",
    );
  }
  if (root is! Map<String, Object?>) {
    throw const SuiviIllisible(
      "la racine de la valeur stockée n'est pas un objet",
    );
  }

  final Object? version = root['version'];
  if (version is! int) {
    throw const SuiviIllisible('version absente ou non entière');
  }
  if (version < 1 || version > followUpsFormatVersion) {
    throw SuiviIllisible('version $version hors de 1..$followUpsFormatVersion');
  }

  final Object? entries = root['suivis'];
  if (entries is! List<Object?>) {
    throw const SuiviIllisible("suivis absent, ou qui n'est pas une liste");
  }

  final Object? lastCheck = root['derniere_verification'];
  DateTime? lastCheckAt;
  if (lastCheck != null) {
    lastCheckAt = _readInstant(lastCheck);
    if (lastCheckAt == null) {
      throw const SuiviIllisible(
        "derniere_verification n'est pas un instant UTC",
      );
    }
  }

  return FollowUpBook(
    followUps: <FollowUp>[
      for (final Object? entry in entries) _decodeEntry(entry),
    ],
    lastCheckAt: lastCheckAt,
  );
}

/// Écrit [book] dans la forme stockée, dans l'ordre reçu. Un
/// [UnreadableFollowUp] est réécrit tel quel, à sa place : son `raw` doit être
/// du JSON (c'est le cas de tout ce que rend [decodeFollowUps]), sinon une
/// [FormatException] est levée.
String encodeFollowUps(FollowUpBook book) => jsonEncode(<String, Object?>{
  'version': followUpsFormatVersion,
  'derniere_verification': book.lastCheckAt?.toUtc().toIso8601String(),
  'suivis': <Object?>[
    for (final FollowUp followUp in book.followUps) _encodeEntry(followUp),
  ],
});

// ---------------------------------------------------------------------------
// Écriture

Object? _encodeEntry(FollowUp followUp) => switch (followUp) {
  FloodFollowUp() => <String, Object?>{
    'type': _typeFlood,
    'code': followUp.place.code.value,
    'seuil': followUp.threshold.name,
    'dernier': followUp.lastKnown == null
        ? null
        : <String, Object?>{
            'niveau': _encodeLevel(followUp.lastKnown!.level),
            'information': _encodeInstant(followUp.lastKnown!.informationDate),
          },
    'serie': _encodeSeries(followUp.series),
  },
  DroughtFollowUp() => <String, Object?>{
    'type': _typeDrought,
    'lieu': _encodeDroughtPlace(followUp.place),
    'dernier': followUp.lastKnown == null
        ? null
        : <String, Object?>{
            'lu_le': _encodeInstant(followUp.lastKnown!.readAt),
            'zones': <Object?>[
              for (final KnownZone zone in followUp.lastKnown!.zones)
                <String, Object?>{
                  'nom': zone.name,
                  'type_de_zone': _encodeZoneKind(zone.kind),
                  'gravite': _encodeSeverity(zone.severity),
                  'arrete_depuis': _encodeInstant(zone.decreeValidFrom),
                },
            ],
          },
    'serie': _encodeSeries(followUp.series),
  },
  UnreadableFollowUp() => jsonDecode(followUp.raw) as Object?,
};

String _encodeInstant(DateTime instant) => instant.toUtc().toIso8601String();

Map<String, Object?> _encodeDroughtPlace(DroughtPlace place) => switch (place) {
  // Verbatim : ni rogné, ni recasé.
  StationPlace() => <String, Object?>{
    'type': _placeStation,
    'code': place.code.value,
  },
  OndePointPlace() => <String, Object?>{
    'type': _placeOnde,
    'code': place.code.value,
  },
};

Object? _encodeLevel(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'vert',
  Jaune() => 'jaune',
  Orange() => 'orange',
  Rouge() => 'rouge',
  NiveauCruesInconnu() => <String, Object?>{'inconnu': level.raw},
};

Object? _encodeSeverity(DroughtSeverity severity) => switch (severity) {
  Vigilance() => 'vigilance',
  Alerte() => 'alerte',
  AlerteRenforcee() => 'alerte-renforcee',
  Crise() => 'crise',
  GraviteInconnue() => <String, Object?>{'inconnue': severity.rawValue},
};

Object? _encodeZoneKind(ZoneKind kind) => switch (kind) {
  EauxSuperficielles() => 'eaux-superficielles',
  EauxSouterraines() => 'eaux-souterraines',
  EauPotable() => 'eau-potable',
  TypeZoneInconnu() => <String, Object?>{'inconnu': kind.rawValue},
};

String? _encodeSeries(FailureSeries? series) => switch (series) {
  null => null,
  FailureSeries.checkImpossible => 'verification-impossible',
  FailureSeries.notVerifiable => 'non-verifiable',
};

// ---------------------------------------------------------------------------
// Lecture

/// Une entrée que cette version ne sait pas lire.
final class _Unreadable implements Exception {
  const _Unreadable();
}

/// Le suivi que porte [entry], ou l'entrée gardée telle quelle.
///
/// Lève [SuiviIllisible] si l'entrée illisible ne peut pas être réécrite telle
/// quelle : un nombre hors plage (`1e999`) se décode en infini, que JSON ne
/// sait pas écrire. La garder serait mentir, la laisser tomber perdrait une
/// donnée : c'est l'échelle de la valeur.
FollowUp _decodeEntry(Object? entry) {
  try {
    return _readEntry(entry);
  } on _Unreadable {
    // Gardée telle quelle, ci-dessous.
  } on ArgumentError {
    // Un code que son type refuse : l'entrée est illisible.
  }

  final String raw;
  try {
    raw = jsonEncode(entry);
  } on JsonUnsupportedObjectError catch (error) {
    throw SuiviIllisible(
      'une entrée illisible ne peut pas être réécrite telle quelle : '
      '${error.cause ?? error.unsupportedObject}',
    );
  }

  return UnreadableFollowUp(raw: raw);
}

FollowUp _readEntry(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const _Unreadable();
  }
  // Le type est une chaîne libre du stockage : tout ce qui n'est pas connu de
  // cette version — absent compris — est illisible.
  return switch (entry['type']) {
    _typeFlood => _readFlood(entry),
    _typeDrought => _readDrought(entry),
    _ => throw const _Unreadable(),
  };
}

FloodFollowUp _readFlood(Map<String, Object?> entry) {
  final Object? code = entry['code'];
  if (code is! String) {
    throw const _Unreadable();
  }
  final FloodThreshold threshold = switch (entry['seuil']) {
    'jaune' => FloodThreshold.jaune,
    'orange' => FloodThreshold.orange,
    'rouge' => FloodThreshold.rouge,
    _ => throw const _Unreadable(),
  };

  final Object? last = entry['dernier'];
  LastKnownFloodLevel? lastKnown;
  if (last != null) {
    if (last is! Map<String, Object?> || !last.containsKey('niveau')) {
      throw const _Unreadable();
    }
    lastKnown = LastKnownFloodLevel(
      level: _readLevel(last['niveau']),
      informationDate: _requireInstant(last['information']),
    );
  }

  return FloodFollowUp(
    place: FloodSectionPlace(FloodSectionCode(code)),
    threshold: threshold,
    lastKnown: lastKnown,
    series: _readSeries(entry['serie']),
  );
}

DroughtFollowUp _readDrought(Map<String, Object?> entry) {
  final Object? place = entry['lieu'];
  if (place is! Map<String, Object?>) {
    throw const _Unreadable();
  }
  final Object? code = place['code'];
  if (code is! String) {
    throw const _Unreadable();
  }
  final DroughtPlace droughtPlace = switch (place['type']) {
    _placeStation => StationPlace(StationCode(code)),
    _placeOnde => OndePointPlace(OndeStationCode(code)),
    _ => throw const _Unreadable(),
  };

  final Object? last = entry['dernier'];
  LastKnownZones? lastKnown;
  if (last != null) {
    if (last is! Map<String, Object?>) {
      throw const _Unreadable();
    }
    final Object? zones = last['zones'];
    if (zones is! List<Object?>) {
      throw const _Unreadable();
    }
    lastKnown = LastKnownZones(
      readAt: _requireInstant(last['lu_le']),
      zones: <KnownZone>[for (final Object? zone in zones) _readZone(zone)],
    );
  }

  return DroughtFollowUp(
    place: droughtPlace,
    lastKnown: lastKnown,
    series: _readSeries(entry['serie']),
  );
}

KnownZone _readZone(Object? zone) {
  if (zone is! Map<String, Object?>) {
    throw const _Unreadable();
  }
  final Object? name = zone['nom'];
  if (name is! String) {
    throw const _Unreadable();
  }

  return KnownZone(
    name: name,
    kind: _readZoneKind(zone['type_de_zone']),
    severity: _readSeverity(zone['gravite']),
    decreeValidFrom: _requireInstant(zone['arrete_depuis']),
  );
}

FloodVigilanceLevel _readLevel(Object? value) {
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
    _ => throw const _Unreadable(),
  };
}

DroughtSeverity _readSeverity(Object? value) {
  if (value is Map<String, Object?> &&
      value.length == 1 &&
      value.containsKey('inconnue')) {
    final Object? raw = value['inconnue'];
    if (raw != null && raw is! String) {
      throw const _Unreadable();
    }

    return GraviteInconnue(raw as String?);
  }

  return switch (value) {
    'vigilance' => const Vigilance(),
    'alerte' => const Alerte(),
    'alerte-renforcee' => const AlerteRenforcee(),
    'crise' => const Crise(),
    _ => throw const _Unreadable(),
  };
}

ZoneKind _readZoneKind(Object? value) {
  if (value is Map<String, Object?> &&
      value.length == 1 &&
      value.containsKey('inconnu')) {
    final Object? raw = value['inconnu'];
    if (raw != null && raw is! String) {
      throw const _Unreadable();
    }

    return TypeZoneInconnu(raw as String?);
  }

  return switch (value) {
    'eaux-superficielles' => const EauxSuperficielles(),
    'eaux-souterraines' => const EauxSouterraines(),
    'eau-potable' => const EauPotable(),
    _ => throw const _Unreadable(),
  };
}

FailureSeries? _readSeries(Object? value) => switch (value) {
  null => null,
  'verification-impossible' => FailureSeries.checkImpossible,
  'non-verifiable' => FailureSeries.notVerifiable,
  _ => throw const _Unreadable(),
};

/// Un instant ISO 8601 portant son fuseau, rendu en UTC. Une date sans fuseau
/// serait lue à l'heure du poste : refusée.
DateTime? _readInstant(Object? value) {
  if (value is! String) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);

  return parsed != null && parsed.isUtc ? parsed : null;
}

DateTime _requireInstant(Object? value) =>
    _readInstant(value) ?? (throw const _Unreadable());
