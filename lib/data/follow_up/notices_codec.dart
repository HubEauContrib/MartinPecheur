// La forme stockée des avis reçus (D3 de T5) : UNE chaîne JSON,
// `{"version":1,"avis":[…]}`, le plus récent en tête. Chaque entrée porte son
// `type`, `recu_le` (ISO UTC) et `lu`, plus ses champs. Fonctions pures : ce
// fichier ne lit ni n'écrit aucun stockage, le dépôt le branche.
//
// Les mots stockés sont ceux du projet, jamais ceux d'une API : `vert`,
// `jaune`, `alerte-renforcee` (avec le tiret), `eaux-superficielles`,
// `troncon-absent`… Un niveau, une gravité ou un type de zone que cette
// version ne reconnaît pas s'écrit `{"inconnu":<brut>}` (ou
// `{"inconnue":<brut>}`), brut conservé : `5` et `"5"` restent distincts. Les
// mots des niveaux, gravités et types de zone sont ceux de
// `follow_up_codec.dart`.
//
// Deux échelles d'illisible, une seule règle (modèle : `follow_up_codec.dart`) :
// - l'ENTRÉE qui ne se lit pas devient un `UnreadableNotice`, gardé à sa place
//   et réécrit tel quel ;
// - la VALEUR qui ne se lit pas (pas du JSON, racine inattendue, version
//   absente ou future, `avis` qui n'est pas une liste) LÈVE
//   `ListeDAvisIllisible` : elle ne rend jamais une liste vide, qui se lirait
//   « aucun avis » et s'écraserait à la première écriture (BR-007).

import 'dart:convert';

import 'package:martinpecheur/data/follow_up/stored_words.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';

/// La version de la forme stockée que ce code écrit, et la plus haute qu'il
/// sait lire.
const int noticesFormatVersion = 1;

const String _typeFloodStarted = 'suivi-commence-crues';
const String _typeDroughtStarted = 'suivi-commence-secheresse';
const String _typeFloodChanged = 'crues-change';
const String _typeZoneChanged = 'zone-secheresse-change';
const String _typeCheckImpossible = 'verification-impossible';
const String _typeNotVerifiable = 'lieu-non-verifiable';

const String _reasonSectionAbsent = 'troncon-absent';
const String _reasonSectionMaybeUnreadable = 'troncon-peut-etre-illisible';
const String _reasonStationAbsent = 'station-absente';

/// Lit la valeur stockée [stored]. `null` (rien n'a jamais été écrit) rend une
/// liste vide. Une entrée illisible est rendue [UnreadableNotice], à sa place.
///
/// Lève [ListeDAvisIllisible] si [stored] n'est pas du JSON, si sa racine
/// n'est pas un objet, si `version` est absente, non entière, inférieure à 1
/// ou supérieure à [noticesFormatVersion], ou si `avis` n'est pas une liste —
/// jamais une liste vide dans ces cas.
List<ReceivedNotice> decodeNotices(String? stored) {
  if (stored == null) {
    return <ReceivedNotice>[];
  }

  final Object? root;
  try {
    root = jsonDecode(stored);
  } on FormatException catch (error) {
    throw ListeDAvisIllisible(
      "la valeur stockée n'est pas du JSON : ${error.message}",
    );
  }
  if (root is! Map<String, Object?>) {
    throw const ListeDAvisIllisible(
      "la racine de la valeur stockée n'est pas un objet",
    );
  }

  final Object? version = root['version'];
  if (version is! int) {
    throw const ListeDAvisIllisible('version absente ou non entière');
  }
  if (version < 1 || version > noticesFormatVersion) {
    throw ListeDAvisIllisible(
      'version $version hors de 1..$noticesFormatVersion',
    );
  }

  final Object? entries = root['avis'];
  if (entries is! List<Object?>) {
    throw const ListeDAvisIllisible("avis absent, ou qui n'est pas une liste");
  }

  return <ReceivedNotice>[
    for (final Object? entry in entries) _decodeEntry(entry),
  ];
}

/// Écrit [notices] dans la forme stockée, dans l'ordre reçu. Un
/// [UnreadableNotice] est réécrit tel quel, à sa place : son `raw` doit être
/// du JSON (c'est le cas de tout ce que rend [decodeNotices]), sinon une
/// [FormatException] est levée.
String encodeNotices(List<ReceivedNotice> notices) => jsonEncode(
  <String, Object?>{
    'version': noticesFormatVersion,
    'avis': <Object?>[for (final ReceivedNotice n in notices) _encodeEntry(n)],
  },
);

// ---------------------------------------------------------------------------
// Écriture

Map<String, Object?> _common(String type, ReadableNotice notice) =>
    <String, Object?>{
      'type': type,
      'recu_le': encodeStoredInstant(notice.receivedAt),
      'lu': notice.read,
    };

Object? _encodeEntry(ReceivedNotice notice) => switch (notice) {
  UnreadableNotice() => jsonDecode(notice.raw) as Object?,
  FloodFollowUpStarted() => <String, Object?>{
    ..._common(_typeFloodStarted, notice),
    'lieu': notice.placeLabel,
    'niveau': encodeStoredLevel(notice.level),
    'information': encodeStoredInstant(notice.informationDate),
    'seuil': encodeStoredThreshold(notice.threshold),
  },
  DroughtFollowUpStarted() => <String, Object?>{
    ..._common(_typeDroughtStarted, notice),
    'lieu': notice.placeLabel,
    'lu_le': encodeStoredInstant(notice.readAt),
    'zones': <Object?>[
      for (final KnownZone zone in notice.zones) encodeStoredZone(zone),
    ],
  },
  FloodLevelChanged() => <String, Object?>{
    ..._common(_typeFloodChanged, notice),
    'lieu': notice.placeLabel,
    'avant': encodeStoredLevel(notice.before),
    'apres': encodeStoredLevel(notice.after),
    'information': encodeStoredInstant(notice.informationDate),
  },
  DroughtZoneChanged() => <String, Object?>{
    ..._common(_typeZoneChanged, notice),
    'lieu': notice.placeLabel,
    'zone': notice.zoneName,
    'type_de_zone': encodeStoredZoneKind(notice.zoneKind),
    'avant': notice.before == null
        ? null
        : encodeStoredSeverity(notice.before!),
    'apres': notice.after == null ? null : encodeStoredSeverity(notice.after!),
    'arrete_depuis': notice.decreeValidFrom == null
        ? null
        : encodeStoredInstant(notice.decreeValidFrom!),
  },
  CheckImpossible() => <String, Object?>{
    ..._common(_typeCheckImpossible, notice),
    'source': switch (notice.source) {
      FollowUpSource.floods => 'crues',
      FollowUpSource.drought => 'secheresse',
    },
    'cause': switch (notice.cause) {
      CheckFailureCause.unreachable => 'injoignable',
      CheckFailureCause.refused => 'refusee',
      CheckFailureCause.unreadable => 'illisible',
    },
    'lieux': notice.placeLabels,
  },
  PlaceNotVerifiable() => <String, Object?>{
    ..._common(_typeNotVerifiable, notice),
    'lieu': notice.placeLabel,
    'raison': _encodeReason(notice.reason),
  },
};

Map<String, Object?> _encodeReason(NotVerifiableReason reason) =>
    switch (reason) {
      SectionAbsent() => <String, Object?>{
        'type': _reasonSectionAbsent,
        'information': encodeStoredInstant(reason.informationDate),
      },
      SectionMaybeUnreadable() => <String, Object?>{
        'type': _reasonSectionMaybeUnreadable,
        'information': encodeStoredInstant(reason.informationDate),
      },
      StationAbsent() => <String, Object?>{'type': _reasonStationAbsent},
    };

// ---------------------------------------------------------------------------
// Lecture

/// L'avis que porte [entry], ou l'entrée gardée telle quelle.
///
/// Lève [ListeDAvisIllisible] si l'entrée illisible ne peut pas être réécrite
/// telle quelle : un nombre hors plage (`1e999`) se décode en infini, que JSON
/// ne sait pas écrire. La garder serait mentir, la laisser tomber perdrait une
/// donnée : c'est l'échelle de la valeur.
ReceivedNotice _decodeEntry(Object? entry) {
  try {
    return _readEntry(entry);
  } on UnreadableStoredEntry {
    // Gardée telle quelle, ci-dessous.
  }

  final String raw;
  try {
    raw = jsonEncode(entry);
  } on JsonUnsupportedObjectError catch (error) {
    throw ListeDAvisIllisible(
      'une entrée illisible ne peut pas être réécrite telle quelle : '
      '${error.cause ?? error.unsupportedObject}',
    );
  }

  return UnreadableNotice(raw: raw);
}

ReadableNotice _readEntry(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const UnreadableStoredEntry();
  }
  final DateTime receivedAt = requireStoredInstant(entry['recu_le']);
  final Object? read = entry['lu'];
  if (read is! bool) {
    throw const UnreadableStoredEntry();
  }

  // Le type est une chaîne libre du stockage : tout ce qui n'est pas connu de
  // cette version — absent compris — est illisible.
  return switch (entry['type']) {
    _typeFloodStarted => FloodFollowUpStarted(
      placeLabel: requireStoredString(entry['lieu']),
      level: readStoredLevel(entry['niveau']),
      informationDate: requireStoredInstant(entry['information']),
      threshold: readStoredThreshold(entry['seuil']),
      receivedAt: receivedAt,
      read: read,
    ),
    _typeDroughtStarted => DroughtFollowUpStarted(
      placeLabel: requireStoredString(entry['lieu']),
      zones: _readZones(entry['zones']),
      readAt: requireStoredInstant(entry['lu_le']),
      receivedAt: receivedAt,
      read: read,
    ),
    _typeFloodChanged => FloodLevelChanged(
      placeLabel: requireStoredString(entry['lieu']),
      before: readStoredLevel(entry['avant']),
      after: readStoredLevel(entry['apres']),
      informationDate: requireStoredInstant(entry['information']),
      receivedAt: receivedAt,
      read: read,
    ),
    _typeZoneChanged => DroughtZoneChanged(
      placeLabel: requireStoredString(entry['lieu']),
      zoneName: requireStoredString(entry['zone']),
      zoneKind: readStoredZoneKind(entry['type_de_zone']),
      before: _readOptionalSeverity(entry, 'avant'),
      after: _readOptionalSeverity(entry, 'apres'),
      decreeValidFrom: _readOptionalInstant(entry, 'arrete_depuis'),
      receivedAt: receivedAt,
      read: read,
    ),
    _typeCheckImpossible => CheckImpossible(
      source: switch (entry['source']) {
        'crues' => FollowUpSource.floods,
        'secheresse' => FollowUpSource.drought,
        _ => throw const UnreadableStoredEntry(),
      },
      cause: switch (entry['cause']) {
        'injoignable' => CheckFailureCause.unreachable,
        'refusee' => CheckFailureCause.refused,
        'illisible' => CheckFailureCause.unreadable,
        _ => throw const UnreadableStoredEntry(),
      },
      placeLabels: _readLabels(entry['lieux']),
      receivedAt: receivedAt,
      read: read,
    ),
    _typeNotVerifiable => PlaceNotVerifiable(
      placeLabel: requireStoredString(entry['lieu']),
      reason: _readReason(entry['raison']),
      receivedAt: receivedAt,
      read: read,
    ),
    _ => throw const UnreadableStoredEntry(),
  };
}

NotVerifiableReason _readReason(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const UnreadableStoredEntry();
  }

  return switch (value['type']) {
    _reasonSectionAbsent => SectionAbsent(
      requireStoredInstant(value['information']),
    ),
    _reasonSectionMaybeUnreadable => SectionMaybeUnreadable(
      requireStoredInstant(value['information']),
    ),
    _reasonStationAbsent => const StationAbsent(),
    _ => throw const UnreadableStoredEntry(),
  };
}

List<KnownZone> _readZones(Object? value) {
  if (value is! List<Object?>) {
    throw const UnreadableStoredEntry();
  }

  return <KnownZone>[for (final Object? zone in value) readStoredZone(zone)];
}

List<String> _readLabels(Object? value) {
  if (value is! List<Object?>) {
    throw const UnreadableStoredEntry();
  }

  return <String>[
    for (final Object? label in value) requireStoredString(label),
  ];
}

/// Une gravité, ou `null` : la clé [key] doit être présente.
DroughtSeverity? _readOptionalSeverity(Map<String, Object?> entry, String key) {
  if (!entry.containsKey(key)) {
    throw const UnreadableStoredEntry();
  }
  final Object? value = entry[key];

  return value == null ? null : readStoredSeverity(value);
}

/// Un instant, ou `null` : la clé [key] doit être présente.
DateTime? _readOptionalInstant(Map<String, Object?> entry, String key) {
  if (!entry.containsKey(key)) {
    throw const UnreadableStoredEntry();
  }
  final Object? value = entry[key];

  return value == null ? null : requireStoredInstant(value);
}
