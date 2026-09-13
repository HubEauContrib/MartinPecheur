// La projection carte du referentiel. Elle vivait dans
// `data/referentiel/stations_asset.dart`, ce qui obligeait la carte et le
// filtre d'emprise a importer le module de lecture d'asset pour obtenir un
// type de donnees pur (R2, arbitrage 2026-09-13). C'est un type du domaine :
// un code, un libelle, deux coordonnees — rien de la provenance, ni asset ni
// reseau. Le module de lecture d'asset le CONSTRUIT ; il ne le possede pas.
//
// Dart pur : aucune dependance d'infrastructure (BR-002).

import 'package:martinpecheur/domain/station/station.dart';

/// Un point a dessiner sur la carte. Volontairement distinct de [Station] :
/// c'est une projection legere du referentiel — code, libelle, coordonnees —
/// pour la carte, qui n'a besoin de rien d'autre pour 4 150 marqueurs. Le
/// referentiel fige porte bien le departement, le cours d'eau et l'etat de
/// service : c'est [Station], pas [StationPoint], qui les transporte.
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
