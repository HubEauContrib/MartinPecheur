// La projection carte du referentiel. Elle vivait dans
// `data/referentiel/stations_asset.dart`, ce qui obligeait la carte et le
// filtre d'emprise a importer le module de lecture d'asset pour obtenir un
// type de donnees pur (R2, arbitrage 2026-09-13). C'est un type du domaine :
// un code, un libelle, deux coordonnees — rien de la provenance, ni asset ni
// reseau. Le module de lecture d'asset le CONSTRUIT ; il ne le possede pas.
//
// Dart pur : aucune dependance d'infrastructure (CLAUDE.md, invariants
// d'architecture ; ADR-014).

import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Un point a dessiner sur la carte. Volontairement distinct de [Station] :
/// c'est une projection legere du referentiel — code, libelle, coordonnees,
/// et depuis ADR-015 le rattachement administratif ([region]/[departement])
/// que le regroupement de la carte utilise sous le zoom 9. Le referentiel
/// fige porte bien le cours d'eau et l'etat de service : ce sont eux, pas la
/// zone administrative, que [Station] transporte et que [StationPoint] ne
/// transporte pas — porter tout [Station] dans chacun des 4 150 marqueurs ne
/// servirait aucun pixel au zoom national.
///
/// [region] et [departement] sont facultatifs : 37 stations sans
/// rattachement du referentiel n'en portent aucun (BR-007, jamais une
/// zone inventee) et restent malgre tout des [StationPoint] individuels sur
/// la carte, a tous les zooms.
final class StationPoint {
  const StationPoint({
    required this.code,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.region,
    this.departement,
  });

  /// Code de la station.
  final StationCode code;

  /// Libelle affichable. Replie sur [code] si `libelle_station` est absent.
  final String label;

  /// Latitude en degres decimaux, WGS 84.
  final double latitude;

  /// Longitude en degres decimaux, WGS 84 (negative a l'ouest de Greenwich).
  final double longitude;

  /// Region administrative de la station (ADR-015), ou `null` en l'absence
  /// de rattachement au referentiel — jamais une zone inventee (BR-007).
  final AdministrativeArea? region;

  /// Departement administratif de la station (ADR-015), meme regle
  /// d'absence que [region].
  final AdministrativeArea? departement;
}
