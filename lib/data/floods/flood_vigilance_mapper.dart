// Le SEUL point de conversion entre le GeoJSON national de Vigicrues
// (`InfoVigiCru.geojson`) et le domaine de la vigilance crues (T4, cadrage
// § 6 ; faits de la source : `docs/sources/vigicrues.md`, `VC-03` a `VC-05`).
// Aucun nom de champ de l'API n'en sort : la vue ne recoit que des
// [FloodSection] et une [FloodVigilanceMap] datee.
//
// Deux regimes, jamais confondus :
// - TOUT OU RIEN pour la racine, `features` et la date de l'information
//   (`DtHrInfoVigiCru`) : sans eux, aucune carte de vigilance ne se dit juste
//   (BR-001 : jamais de valeur sans sa date). La reponse entiere leve
//   [VigilanceIllisible].
// - ENTITE PAR ENTITE pour les troncons : une entite sans code (`CdEntCru`),
//   sans nom (`lbentcru`), sans territoire (`cdensup_1`, le bulletin ne
//   s'ouvrirait pas) ou sans trace `MultiLineString` lisible est ecartee et
//   COMPTEE dans `skippedEntities` ; les autres restent. Une entite cassee ne
//   doit pas cacher 336 vigilances publiees (precedent : les entites ecartees
//   et comptees de l'asset des stations, `stations_asset.dart`).
//
// Un niveau (`NivInfViCr`) absent ou non reconnu n'ecarte rien : il devient
// [NiveauCruesInconnu] avec la valeur brute (BR-011). Champs inconnus
// ignores ; la `bbox` declaree n'est pas lue (fausse, `VC-03`) ;
// `RefInfoVigiCru` n'est pas lu.
//
// Rien d'autre que [VigilanceIllisible] ne s'echappe : ni `TypeError`, ni
// `FormatException`, ni l'`ArgumentError` de [GeoPoint] ou de
// [FloodSection] — chaque valeur est verifiee avant construction.
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// Fuseau explicite en fin de date : `Z` ou un decalage `±HH:MM`.
final RegExp _explicitZone = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

/// Convertit le corps decode de `InfoVigiCru.geojson` en [FloodVigilanceMap].
///
/// Leve [VigilanceIllisible] (diagnostic : ce qui manque) si la racine n'est
/// pas un objet `FeatureCollection`, si `features` est absent ou n'est pas
/// une liste, ou si la date de l'information est absente ou illisible. Ne
/// leve jamais rien d'autre.
FloodVigilanceMap mapFloodVigilance(Object? json) {
  if (json is! Map<String, Object?>) {
    throw VigilanceIllisible(
      'racine : un objet FeatureCollection est attendu, recu '
      '${_describe(json)}',
    );
  }
  final Object? type = json['type'];
  if (type != 'FeatureCollection') {
    throw VigilanceIllisible(
      'racine.type : FeatureCollection est attendu, recu ${_describe(type)}',
    );
  }
  final Object? features = json['features'];
  if (features is! List<Object?>) {
    throw VigilanceIllisible(
      'racine.features : une liste est attendue, recu ${_describe(features)}',
    );
  }
  final DateTime informationDate = _informationDate(json['DtHrInfoVigiCru']);

  final List<FloodSection> sections = <FloodSection>[];
  int skipped = 0;
  for (final Object? feature in features) {
    final FloodSection? section = _section(feature);
    if (section == null) {
      skipped++;
    } else {
      sections.add(section);
    }
  }

  return FloodVigilanceMap(
    informationDate: informationDate,
    sections: sections,
    skippedEntities: skipped,
  );
}

/// Traduit le code publie d'un niveau (nomenclature Sandre n° 837, `VC-04`).
///
/// Seul un `int` de 1 a 4 est reconnu : un `double` `2.0`, une chaine `'2'`,
/// `null` ou toute autre valeur donne [NiveauCruesInconnu] avec la valeur
/// brute, telle que recue (BR-011). Le test de type precede le `switch` :
/// un motif constant `2` accepterait `2.0`, puisque `2 == 2.0` en Dart.
FloodVigilanceLevel floodLevelFromWire(Object? raw) {
  if (raw is! int) {
    return NiveauCruesInconnu(raw);
  }
  return switch (raw) {
    1 => const Vert(),
    2 => const Jaune(),
    3 => const Orange(),
    4 => const Rouge(),
    _ => NiveauCruesInconnu(raw),
  };
}

/// La date de l'information, en UTC. Lisible seulement si le SDK la
/// reconnait ET si elle porte un fuseau explicite : une date sans fuseau
/// serait lue par `DateTime.parse` en heure LOCALE du poste — une date
/// inventee, refusee (BR-001).
DateTime _informationDate(Object? raw) {
  if (raw is! String) {
    throw VigilanceIllisible(
      'racine.DtHrInfoVigiCru : une date est attendue, recu ${_describe(raw)}',
    );
  }
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null || !_explicitZone.hasMatch(raw)) {
    throw VigilanceIllisible(
      'racine.DtHrInfoVigiCru : une date ISO 8601 avec fuseau explicite '
      '(Z ou ±HH:MM) est attendue, recu ${_describe(raw)}',
    );
  }
  return parsed.toUtc();
}

/// Un troncon, ou `null` — jamais une exception — si l'entite est a ecarter.
FloodSection? _section(Object? feature) {
  if (feature is! Map<String, Object?>) {
    return null;
  }
  final Object? properties = feature['properties'];
  if (properties is! Map<String, Object?>) {
    return null;
  }
  final String? code = _nonEmptyText(properties['CdEntCru']);
  final String? name = _nonEmptyText(properties['lbentcru']);
  final String? territory = _nonEmptyText(properties['cdensup_1']);
  if (code == null || name == null || territory == null) {
    return null;
  }
  final List<List<GeoPoint>>? lines = _lines(feature['geometry']);
  if (lines == null) {
    return null;
  }
  return FloodSection(
    code: FloodSectionCode(code),
    name: name,
    territoryCode: territory,
    level: floodLevelFromWire(properties['NivInfViCr']),
    lines: lines,
  );
}

/// Texte non vide, tel que publie (ni `trim`, ni changement de casse) ;
/// `null` sinon.
String? _nonEmptyText(Object? raw) =>
    raw is String && raw.isNotEmpty ? raw : null;

/// Les lignes lisibles d'une geometrie `MultiLineString` ; `null` si la
/// geometrie n'en est pas une (un `LineString` est ecarte : jamais observe,
/// `VC-03`) ou s'il ne reste aucune ligne.
List<List<GeoPoint>>? _lines(Object? geometry) {
  if (geometry is! Map<String, Object?> ||
      geometry['type'] != 'MultiLineString') {
    return null;
  }
  final Object? coordinates = geometry['coordinates'];
  if (coordinates is! List<Object?>) {
    return null;
  }
  final List<List<GeoPoint>> lines = <List<GeoPoint>>[
    for (final Object? rawLine in coordinates) ?_line(rawLine),
  ];
  return lines.isEmpty ? null : lines;
}

/// Une ligne d'au moins deux points valides ; `null` — la ligne est
/// retiree — des qu'un point est illisible.
List<GeoPoint>? _line(Object? rawLine) {
  if (rawLine is! List<Object?> || rawLine.length < 2) {
    return null;
  }
  final List<GeoPoint> points = <GeoPoint>[];
  for (final Object? rawPoint in rawLine) {
    final GeoPoint? point = _point(rawPoint);
    if (point == null) {
      return null;
    }
    points.add(point);
  }
  return points;
}

/// Un point GeoJSON, ou `null` s'il n'est pas une liste d'au moins deux
/// nombres formant un [GeoPoint] valide.
GeoPoint? _point(Object? rawPoint) {
  if (rawPoint is! List<Object?> || rawPoint.length < 2) {
    return null;
  }
  // GeoJSON ordonne [longitude, latitude] : la seule inversion d'ordre de
  // cette source. La tenir a l'envers ne leverait rien sur la plupart des
  // points de France — le trace s'afficherait ailleurs, sans broncher.
  final Object? longitude = rawPoint[0];
  final Object? latitude = rawPoint[1];
  if (longitude is! num || latitude is! num) {
    return null;
  }
  try {
    return GeoPoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  } on ArgumentError {
    return null;
  }
}

/// Description courte d'une valeur recue, pour le diagnostic (jamais
/// affiche a l'usager).
String _describe(Object? value) => switch (value) {
  null => 'null',
  String() => 'le texte « $value »',
  _ => 'un ${value.runtimeType}',
};
