// Le referentiel est un GeoJSON `FeatureCollection` fige, produit hors
// execution (ADR-003) : `parseStations` n'est qu'une analyse, jamais un
// appel reseau. Ce module CONSTRUIT des [StationPoint] et des [Station] ; il
// ne les possede pas — les deux types vivent sous `lib/domain/station/`
// (R2, arbitrage 2026-09-13).
//
// ⚠️ L'ordre GeoJSON des coordonnees est [longitude,
// latitude] — le tenir a l'envers ne leve aucune erreur, un point de la
// Guadeloupe se retrouverait au large de la Somalie et la carte s'afficherait
// sans broncher. Toute entite ecartee est COMPTEE dans `skipped` (BR-007) :
// une station absente de la carte doit s'expliquer, jamais disparaitre en
// silence. L'analyse est separee du chargement (`stations_asset_loader.dart`,
// qui depend de Flutter) : `parseStations` reste testable sans `AssetBundle`
// ni rendu.

import 'dart:convert';

import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Chemin de l'asset du referentiel, fige a la generation (ADR-003).
const String stationsAssetPath = 'assets/referentiel/stations.json';

/// Code de projection pour lequel `latitude_station`/`longitude_station` (et
/// `geometry.coordinates`, qui les recopie) sont INVERSEES dans le
/// referentiel (`C-18`). Fait constate le 2026-09-23 : 54 stations
/// metropolitaines portent `code_projection: 31` ; verifie par appel reel le
/// 2026-09-23 a 12:38:59 UTC sur `H000000201` et `H004000101`
/// (`/v2/hydrometrie/referentiel/stations?code_station=H000000201,H004000101
/// &fields=...&format=json`, HTTP 200, `api_version` 2.0.1) — pour les deux,
/// `coordonnee_x_station`/`coordonnee_y_station` sont justes (x = longitude,
/// y = latitude), `docs/sources/hubeau-hydrometrie.md` § « Référentiel
/// figé ». Arbitrage du commanditaire (2026-09-23) : pour ce seul code, lire
/// X/Y plutot que `geometry.coordinates`. Aucune autre heuristique — un 55e
/// cas hors projection 31 (`J543211003`) reste un point ouvert, non traite.
const int _swappedLatLonProjectionCode = 31;

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

  final ({num latitude, num longitude}) position = _positionOf(
    properties,
    fallbackLatitude: rawLatitude,
    fallbackLongitude: rawLongitude,
  );

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
      latitude: position.latitude.toDouble(),
      longitude: position.longitude.toDouble(),
      region: _regionOf(properties),
      departement: _departementAreaOf(properties),
    ),
    properties,
  );
}

/// Position d'une station (`C-18`) : sous `code_projection ==
/// [_swappedLatLonProjectionCode]` et quand `coordonnee_x_station`/
/// `coordonnee_y_station` sont des nombres, longitude = X, latitude = Y —
/// `geometry.coordinates` est alors inversee et ne doit pas etre lue. Sinon
/// (autre projection, ou X/Y absents/mal formes), repli sur
/// [fallbackLatitude]/[fallbackLongitude] issues de `geometry.coordinates`,
/// comme avant `C-18`. Aucune autre heuristique : pas de permutation « si
/// incoherent ».
({num latitude, num longitude}) _positionOf(
  Map<String, dynamic> properties, {
  required num fallbackLatitude,
  required num fallbackLongitude,
}) {
  final Object? codeProjection = properties['code_projection'];
  if (codeProjection == _swappedLatLonProjectionCode) {
    final Object? x = properties['coordonnee_x_station'];
    final Object? y = properties['coordonnee_y_station'];
    if (x is num && y is num) {
      return (latitude: y, longitude: x);
    }
  }
  return (latitude: fallbackLatitude, longitude: fallbackLongitude);
}

/// Analyse la région administrative (`code_region`/`libelle_region`,
/// ADR-015). Rend `null` — jamais une erreur, jamais un point écarté
/// (BR-007) — dès que `code_region` est absent, vide ou non textuel : les 37
/// stations sans rattachement du référentiel (33 transfrontalières, deux à
/// Boulogne-sur-Mer, deux en Corse) n'en portent aucune. Aucun type dédié ne
/// valide le code région (à la différence de [DepartementCode]) : c'est une
/// chaîne libre, comme le référentiel la porte. `libelle_region` absent ou
/// vide replie le libellé sur le code, comme `libelle_station`.
AdministrativeArea? _regionOf(Map<String, dynamic> properties) {
  final Object? rawCode = properties['code_region'];
  if (rawCode is! String || rawCode.trim().isEmpty) {
    return null;
  }
  final Object? rawLabel = properties['libelle_region'];
  final String label = (rawLabel is String && rawLabel.trim().isNotEmpty)
      ? rawLabel
      : rawCode;
  return AdministrativeArea(code: rawCode, label: label);
}

/// Analyse le département administratif (ADR-015), sous forme
/// d'[AdministrativeArea] — code ET libellé, à la différence de
/// [_toStationEntity] qui ne porte que le [DepartementCode] validé. Le code
/// reste validé par [DepartementCode] à la lecture, puis rangé comme `code`
/// ; un code absent, vide ou mal formé rend `null` — jamais une erreur,
/// jamais un point écarté (BR-007) : contrairement à [Station], un
/// [StationPoint] reste dessiné sur la carte sans département connu.
/// `libelle_departement` absent ou vide replie le libellé sur le code.
AdministrativeArea? _departementAreaOf(Map<String, dynamic> properties) {
  final Object? rawCode = properties['code_departement'];
  if (rawCode is! String) {
    return null;
  }

  final DepartementCode code;
  try {
    code = DepartementCode(rawCode);
  } on ArgumentError {
    return null;
  }

  final Object? rawLabel = properties['libelle_departement'];
  final String label = (rawLabel is String && rawLabel.trim().isNotEmpty)
      ? rawLabel
      : code.value;
  return AdministrativeArea(code: code.value, label: label);
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
