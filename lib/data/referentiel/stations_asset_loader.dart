// Chargement de l'asset fige (ADR-003) : ce fichier est la seule couture
// Flutter du referentiel. L'analyse elle-meme (`parseStations`) reste dans
// `stations_asset.dart`, Dart pur, testable sans `AssetBundle` ni rendu.

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:martinpecheur/data/referentiel/stations_asset.dart';

/// Charge et analyse le referentiel des stations depuis l'asset fige a
/// [stationsAssetPath]. [bundle] permet d'injecter un `AssetBundle` de
/// test ; par defaut, [rootBundle].
Future<StationsReadResult> loadStationsFromAsset({AssetBundle? bundle}) async {
  final AssetBundle resolvedBundle = bundle ?? rootBundle;
  final String jsonText = await resolvedBundle.loadString(stationsAssetPath);
  return parseStations(jsonText);
}
