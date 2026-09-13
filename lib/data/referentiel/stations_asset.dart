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
/// le referentiel fige n'apporte qu'un code, un libelle et des coordonnees —
/// jamais le departement, le cours d'eau ni l'etat de service.
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

/// Resultat de l'analyse du referentiel : les points exploitables, et le
/// nombre d'entites ecartees (BR-007).
final class StationsReadResult {
  const StationsReadResult({required this.points, required this.skipped});

  /// Points exploitables, dans l'ordre du fichier.
  final List<StationPoint> points;

  /// Nombre d'entites ecartees — code absent ou mal forme, geometrie ou
  /// coordonnees incompletes. Jamais un plantage silencieux (BR-007).
  final int skipped;
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

  for (final Object? feature in features) {
    final StationPoint? point = _parseFeature(feature);
    if (point == null) {
      skipped++;
    } else {
      points.add(point);
    }
  }

  return StationsReadResult(points: points, skipped: skipped);
}

/// Analyse une entite `Feature` isolee. Renvoie `null` — jamais une
/// exception — des que le code, la geometrie ou les coordonnees sont
/// incomplets (BR-007) : l'appelant compte ces `null` dans `skipped`.
StationPoint? _parseFeature(Object? feature) {
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

  return StationPoint(
    code: code,
    label: label,
    latitude: rawLatitude.toDouble(),
    longitude: rawLongitude.toDouble(),
  );
}
