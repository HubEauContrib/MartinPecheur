// La forme stockée des favoris (S2 de T3) : UNE chaîne JSON,
// `{"version":1,"favoris":[…]}`, chaque entrée portant son `type`. Fonctions
// pures : ce fichier ne lit ni n'écrit aucun stockage, le dépôt le branche.
//
// Deux échelles d'illisible, une seule règle :
// - l'ENTRÉE qui ne se lit pas devient un `UnreadableFavorite`, gardé à sa
//   place dans la liste et réécrit tel quel — les autres entrées sont lues,
//   jamais tout ou rien (BR-011) ;
// - la VALEUR qui ne se lit pas (pas du JSON, racine inattendue, version
//   hors de ce que cette version connaît) LÈVE `ListeDeFavorisIllisible` :
//   elle ne rend jamais une liste vide, qui se lirait « aucun favori » et
//   s'écraserait à la première écriture (BR-007).
//
// Le code ONDE s'écrit verbatim, espaces compris : le rogner changerait la
// station interrogée (`onde_station_code.dart`, T-14).

import 'dart:convert';

import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// La version de la forme stockée que ce code écrit, et la plus haute qu'il
/// sait lire.
const int favoritesFormatVersion = 1;

const String _typeStation = 'station';
const String _typeOnde = 'onde';
const String _typeTroncon = 'troncon';

/// Lit la valeur stockée [stored]. `null` (rien n'a jamais été écrit) rend
/// une liste vide. Une entrée illisible est rendue [UnreadableFavorite], à sa
/// place ; deux entrées de même lieu sont rendues toutes les deux.
///
/// Lève [ListeDeFavorisIllisible] si [stored] n'est pas du JSON, si sa racine
/// n'est pas un objet, si `version` est absente, non entière, inférieure à 1
/// ou supérieure à [favoritesFormatVersion], ou si `favoris` n'est pas une
/// liste — jamais une liste vide dans ces cas.
List<Favorite> decodeFavorites(String? stored) {
  if (stored == null) {
    return <Favorite>[];
  }

  final Object? root;
  try {
    root = jsonDecode(stored);
  } on FormatException catch (error) {
    throw ListeDeFavorisIllisible(
      "la valeur stockée n'est pas du JSON : ${error.message}",
    );
  }
  if (root is! Map<String, Object?>) {
    throw const ListeDeFavorisIllisible(
      "la racine de la valeur stockée n'est pas un objet",
    );
  }

  final Object? version = root['version'];
  if (version is! int) {
    throw const ListeDeFavorisIllisible('version absente ou non entière');
  }
  if (version < 1 || version > favoritesFormatVersion) {
    throw ListeDeFavorisIllisible(
      'version $version hors de 1..$favoritesFormatVersion',
    );
  }

  final Object? entries = root['favoris'];
  if (entries is! List<Object?>) {
    throw const ListeDeFavorisIllisible(
      "favoris absent, ou qui n'est pas une liste",
    );
  }

  return <Favorite>[for (final Object? entry in entries) _decodeEntry(entry)];
}

/// Écrit [favorites] dans la forme stockée, dans l'ordre reçu. Un
/// [UnreadableFavorite] est réécrit tel quel, à sa place : son `raw` doit
/// être du JSON (c'est le cas de tout ce que rend [decodeFavorites]), sinon
/// une [FormatException] est levée.
String encodeFavorites(List<Favorite> favorites) =>
    jsonEncode(<String, Object?>{
      'version': favoritesFormatVersion,
      'favoris': <Object?>[
        for (final Favorite favorite in favorites) _encodeEntry(favorite),
      ],
    });

Object? _encodeEntry(Favorite favorite) => switch (favorite) {
  StationFavorite() => <String, Object?>{
    'type': _typeStation,
    'ajoute_le': favorite.addedAt.toIso8601String(),
    'code': favorite.code.value,
    'libelle': favorite.label,
  },
  OndePointFavorite() => <String, Object?>{
    'type': _typeOnde,
    'ajoute_le': favorite.addedAt.toIso8601String(),
    'point': <String, Object?>{
      // Verbatim : ni rogné, ni recasé.
      'code': favorite.point.code.value,
      'libelle': favorite.point.label,
      'latitude': favorite.point.latitude,
      'longitude': favorite.point.longitude,
      'cours_d_eau': favorite.point.waterCourseLabel,
      'departement': _encodeArea(favorite.point.departement),
      'region': _encodeArea(favorite.point.region),
    },
  },
  FloodSectionFavorite() => <String, Object?>{
    'type': _typeTroncon,
    'ajoute_le': favorite.addedAt.toIso8601String(),
    'code': favorite.code.value,
    'nom': favorite.name,
  },
  UnreadableFavorite() => jsonDecode(favorite.raw) as Object?,
};

Map<String, Object?>? _encodeArea(AdministrativeArea? area) => area == null
    ? null
    : <String, Object?>{'code': area.code, 'libelle': area.label};

/// Une entrée de la liste : le favori lu, ou l'entrée gardée telle quelle.
///
/// Lève [ListeDeFavorisIllisible] si l'entrée illisible ne peut pas être
/// réécrite telle quelle : un nombre hors plage (`1e999`) se décode en infini,
/// que JSON ne sait pas écrire. La garder serait mentir, la laisser tomber
/// perdrait une donnée : c'est l'échelle de la valeur.
Favorite _decodeEntry(Object? entry) {
  final Favorite? read = _readEntry(entry);
  if (read != null) {
    return read;
  }

  final String raw;
  try {
    raw = jsonEncode(entry);
  } on JsonUnsupportedObjectError catch (error) {
    throw ListeDeFavorisIllisible(
      'une entrée illisible ne peut pas être réécrite telle quelle : '
      '${error.cause ?? error.unsupportedObject}',
    );
  }

  return UnreadableFavorite(raw: raw, label: _labelOf(entry));
}

/// Le favori que porte [entry], ou `null` si elle ne se lit pas.
Favorite? _readEntry(Object? entry) {
  if (entry is! Map<String, Object?>) {
    return null;
  }
  final DateTime? addedAt = _readAddedAt(entry['ajoute_le']);
  if (addedAt == null) {
    return null;
  }

  // Le type est une chaîne libre du stockage : tout ce qui n'est pas connu
  // de cette version — absent compris — est illisible, jamais rabattu sur un
  // type connu.
  return switch (entry['type']) {
    _typeStation => _readStation(entry, addedAt),
    _typeOnde => _readOnde(entry['point'], addedAt),
    _typeTroncon => _readSection(entry, addedAt),
    _ => null,
  };
}

/// L'instant d'ajout : une chaîne ISO 8601 portant son fuseau, rendue en UTC.
/// Une date sans fuseau serait lue à l'heure du poste : refusée.
DateTime? _readAddedAt(Object? value) {
  if (value is! String) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);

  return parsed != null && parsed.isUtc ? parsed : null;
}

StationFavorite? _readStation(Map<String, Object?> entry, DateTime addedAt) {
  final Object? code = entry['code'];
  final Object? label = entry['libelle'];
  if (code is! String || label is! String || label.trim().isEmpty) {
    return null;
  }

  final StationCode stationCode;
  try {
    stationCode = StationCode(code);
  } on ArgumentError {
    return null;
  }

  return StationFavorite(code: stationCode, label: label, addedAt: addedAt);
}

FloodSectionFavorite? _readSection(
  Map<String, Object?> entry,
  DateTime addedAt,
) {
  final Object? code = entry['code'];
  final Object? name = entry['nom'];
  if (code is! String ||
      code.trim().isEmpty ||
      name is! String ||
      name.trim().isEmpty) {
    return null;
  }

  return FloodSectionFavorite(
    code: FloodSectionCode(code),
    name: name,
    addedAt: addedAt,
  );
}

OndePointFavorite? _readOnde(Object? point, DateTime addedAt) {
  if (point is! Map<String, Object?>) {
    return null;
  }
  final Object? code = point['code'];
  final Object? label = point['libelle'];
  final Object? latitude = point['latitude'];
  final Object? longitude = point['longitude'];
  final Object? waterCourseLabel = point['cours_d_eau'];
  if (code is! String ||
      code.trim().isEmpty ||
      label is! String ||
      latitude is! num ||
      !latitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude is! num ||
      !longitude.isFinite ||
      longitude < -180 ||
      longitude > 180 ||
      waterCourseLabel is! String?) {
    return null;
  }

  final ({AdministrativeArea? area})? departement = _readArea(
    point['departement'],
  );
  final ({AdministrativeArea? area})? region = _readArea(point['region']);
  if (departement == null || region == null) {
    return null;
  }

  return OndePointFavorite(
    point: OndePoint(
      code: OndeStationCode(code),
      label: label,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      waterCourseLabel: waterCourseLabel,
      departement: departement.area,
      region: region.area,
    ),
    addedAt: addedAt,
  );
}

/// Une zone administrative stockée : `null` JSON rend une absence
/// (`(area: null)`), un objet à `code` et `libelle` chaînes rend la zone ;
/// toute autre forme rend `null` — l'entrée est illisible.
({AdministrativeArea? area})? _readArea(Object? value) {
  if (value == null) {
    return (area: null);
  }
  if (value is! Map<String, Object?>) {
    return null;
  }
  final Object? code = value['code'];
  final Object? label = value['libelle'];
  if (code is! String || label is! String) {
    return null;
  }

  return (area: AdministrativeArea(code: code, label: label));
}

/// Le libellé d'une entrée illisible : son `libelle` de premier niveau s'il
/// est une chaîne non blanche, sinon celui de son `point`, sinon `null`.
String? _labelOf(Object? entry) {
  if (entry is! Map<String, Object?>) {
    return null;
  }
  final Object? point = entry['point'];

  return _nonBlank(entry['libelle']) ??
      _nonBlank(entry['nom']) ??
      (point is Map<String, Object?> ? _nonBlank(point['libelle']) : null);
}

String? _nonBlank(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
