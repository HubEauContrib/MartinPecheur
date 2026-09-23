// La projection carte du référentiel ONDE. Sur le même modèle que
// StationPoint (`lib/domain/station/station_point.dart`), mais pour le
// référentiel écoulement : un code, un libellé, deux coordonnées, plus le
// cours d'eau et le département quand la fiche station en a besoin. Dart
// pur : aucune dépendance d'infrastructure (CLAUDE.md, invariants
// d'architecture ; ADR-014).

import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

/// Un point du référentiel ONDE — station d'observation de l'écoulement.
/// Classe immuable simple : aucune validation propre au-delà de celle déjà
/// portée par [OndeStationCode] et, à la lecture, par `DepartementCode`
/// (`lib/domain/station/station.dart`).
final class OndePoint {
  const OndePoint({
    required this.code,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.waterCourseLabel,
    required this.departement,
    this.region,
  });

  /// Code de la station ONDE, à huit caractères.
  final OndeStationCode code;

  /// Libellé affichable de la station.
  final String label;

  /// Latitude en degrés décimaux, WGS 84.
  final double latitude;

  /// Longitude en degrés décimaux, WGS 84 (négative à l'ouest de
  /// Greenwich).
  final double longitude;

  /// Cours d'eau de la station. `null` signifie une absence — jamais une
  /// chaîne vide (BR-007).
  final String? waterCourseLabel;

  /// Département de la station (ADR-015) — code ET libellé désormais, le
  /// même type [AdministrativeArea] que [StationPoint.departement]. `null`
  /// signifie une absence — jamais une chaîne vide (BR-007). Le code reste
  /// validé par `DepartementCode` à la lecture (mapper), puis rangé ici
  /// comme `code`.
  final AdministrativeArea? departement;

  /// Région de la station (ADR-015). `null` signifie une absence — jamais
  /// une chaîne vide (BR-007).
  final AdministrativeArea? region;
}
