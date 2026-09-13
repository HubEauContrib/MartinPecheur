// Le referentiel est un GeoJSON `FeatureCollection` fige, produit hors
// execution (ADR-003) : `parseStations` n'est qu'une analyse, jamais un
// appel reseau. ⚠️ L'ordre GeoJSON des coordonnees est [longitude,
// latitude] — le tenir a l'envers ne leve aucune erreur, un point de la
// Guadeloupe se retrouverait au large de la Somalie et la carte s'afficherait
// sans broncher. Toute entite ecartee est COMPTEE dans `skipped` (BR-007) :
// une station absente de la carte doit s'expliquer, jamais disparaitre en
// silence. L'analyse est separee du chargement (`stations_asset_loader.dart`,
// qui depend de Flutter) : `parseStations` reste testable sans `AssetBundle`
// ni rendu.

import 'dart:convert';

import 'package:martinpecheur/domain/station/station.dart';

/// Chemin de l'asset du referentiel, fige a la generation (ADR-003).
const String stationsAssetPath = 'assets/referentiel/stations.json';

/// Un point a dessiner sur la carte. Volontairement distinct de [Station] :
/// c'est une projection legere du referentiel — code, libelle, coordonnees —
/// pour la carte, qui n'a besoin de rien d'autre pour 4 150 marqueurs. Le
/// referentiel fige porte bien le departement, le cours d'eau et l'etat de
/// service (voir [_toStationEntity]) : c'est [Station], pas [StationPoint],
/// qui les transporte.
final class StationPoint {
  const StationPoint({
    required this.code,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  /// Code de la station.
  final StationCode code;

  /// Libelle affichable. Replie sur [code] si `libelle_station` est absent.
  final String label;

  /// Latitude en degres decimaux, WGS 84.
  final double latitude;

  /// Longitude en degres decimaux, WGS 84 (negative a l'ouest de Greenwich).
  final double longitude;
}

/// Resultat de l'analyse du referentiel : les points exploitables, les
/// entites [Station] completes, et les deux compteurs d'entites ecartees
/// (BR-007) — un seul parcours du JSON construit les quatre.
final class StationsReadResult {
  const StationsReadResult({
    required this.points,
    required this.skipped,
    required this.stations,
    required this.stationsSkipped,
  });

  /// Points exploitables, dans l'ordre du fichier.
  final List<StationPoint> points;

  /// Nombre d'entites ecartees au niveau du point — code absent ou mal
  /// forme, geometrie ou coordonnees incompletes. Jamais un plantage
  /// silencieux (BR-007).
  final int skipped;

  /// Entites [Station] completes, dans l'ordre du fichier. Un sous-ensemble
  /// de [points] : toute entite dont le departement ou l'etat de service
  /// est absent ou mal forme est ecartee ici sans etre inventee (BR-007) —
  /// jamais une valeur fabriquee de toutes pieces.
  final List<Station> stations;

  /// Nombre d'entites valides comme [StationPoint] mais ecartees de
  /// [stations] — departement ou `en_service` absent ou mal forme.
  final int stationsSkipped;
}

/// Analyse [jsonText], un GeoJSON `FeatureCollection` du referentiel des
/// stations. Leve une [FormatException] si [jsonText] n'est pas du JSON
/// valide, ou si l'objet decode ne porte pas de liste `features`. Une entite
/// dont le code, la geometrie ou les coordonnees sont incomplets est ecartee
/// et comptee dans `skipped`, jamais un plantage (BR-007).
StationsReadResult parseStations(String jsonText) {
  final Object? decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'le referentiel doit etre un objet FeatureCollection',
    );
  }

  final Object? features = decoded['features'];
  if (features is! List<dynamic>) {
    throw const FormatException(
      'le referentiel doit porter une liste `features`',
    );
  }

  final List<StationPoint> points = <StationPoint>[];
  int skipped = 0;
  final List<Station> stations = <Station>[];
  int stationsSkipped = 0;

  for (final Object? feature in features) {
    final _ParsedFeature? parsed = _parseFeature(feature);
    if (parsed == null) {
      skipped++;
      continue;
    }

    points.add(parsed.point);

    final Station? station = _toStationEntity(parsed);
    if (station == null) {
      stationsSkipped++;
    } else {
      stations.add(station);
    }
  }

  return StationsReadResult(
    points: points,
    skipped: skipped,
    stations: stations,
    stationsSkipped: stationsSkipped,
  );
}

/// Un point valide, avec ses proprietes brutes conservees pour construire
/// l'entite [Station] sans reparcourir le JSON (departement, cours d'eau,
/// etat de service).
final class _ParsedFeature {
  const _ParsedFeature(this.point, this.properties);

  final StationPoint point;
  final Map<String, dynamic> properties;
}

/// Analyse une entite `Feature` isolee. Renvoie `null` — jamais une
/// exception — des que le code, la geometrie ou les coordonnees sont
/// incomplets (BR-007) : l'appelant compte ces `null` dans `skipped`.
_ParsedFeature? _parseFeature(Object? feature) {
  if (feature is! Map<String, dynamic>) {
    return null;
  }

  final Object? properties = feature['properties'];
  if (properties is! Map<String, dynamic>) {
    return null;
  }

  final Object? geometry = feature['geometry'];
  if (geometry is! Map<String, dynamic>) {
    return null;
  }

  final Object? coordinates = geometry['coordinates'];
  if (coordinates is! List<dynamic> || coordinates.length < 2) {
    return null;
  }

  final Object? rawLongitude = coordinates[0];
  final Object? rawLatitude = coordinates[1];
  if (rawLongitude is! num || rawLatitude is! num) {
    return null;
  }

  final String? rawCode = properties['code_station'] as String?;
  if (rawCode == null) {
    return null;
  }

  final StationCode code;
  try {
    code = StationCode(rawCode);
  } on ArgumentError {
    return null;
  }

  final String label = properties['libelle_station'] as String? ?? code.value;

  return _ParsedFeature(
    StationPoint(
      code: code,
      label: label,
      latitude: rawLatitude.toDouble(),
      longitude: rawLongitude.toDouble(),
    ),
    properties,
  );
}

/// Construit l'entite [Station] complete a partir de [parsed]. Renvoie
/// `null` — jamais une valeur fabriquee — des que `code_departement` ou
/// `en_service` sont absents ou mal formes (BR-007) : l'appelant compte ces
/// `null` dans `stationsSkipped`. `libelle_cours_eau` absent ou vide rend un
/// `riverLabel` `null`, une absence honnete plutot qu'une chaine vide.
Station? _toStationEntity(_ParsedFeature parsed) {
  final Map<String, dynamic> properties = parsed.properties;

  final Object? rawDepartement = properties['code_departement'];
  if (rawDepartement is! String) {
    return null;
  }

  final DepartementCode departement;
  try {
    departement = DepartementCode(rawDepartement);
  } on ArgumentError {
    return null;
  }

  final Object? rawEnService = properties['en_service'];
  if (rawEnService is! bool) {
    return null;
  }

  final Object? rawRiverLabel = properties['libelle_cours_eau'];
  final String? riverLabel =
      (rawRiverLabel is String && rawRiverLabel.trim().isNotEmpty)
      ? rawRiverLabel
      : null;

  return Station(
    code: parsed.point.code,
    label: parsed.point.label,
    latitude: parsed.point.latitude,
    longitude: parsed.point.longitude,
    departement: departement,
    riverLabel: riverLabel,
    inService: rawEnService,
  );
}
