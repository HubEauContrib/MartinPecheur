// La projection carte du referentiel ONDE. Sur le meme modele que
// StationPoint (`lib/domain/station/station_point.dart`), mais pour le
// referentiel ecoulement : un code, un libelle, deux coordonnees, plus le
// cours d'eau et le departement quand la fiche station en a besoin. Dart
// pur : aucune dependance d'infrastructure (BR-002).

import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Un point du referentiel ONDE — station d'observation de l'ecoulement.
/// Classe immuable simple : aucune validation propre au-dela de celle deja
/// portee par [OndeStationCode] et [DepartementCode].
final class OndePoint {
  const OndePoint({
    required this.code,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.waterCourseLabel,
    required this.departement,
  });

  /// Code de la station ONDE, a huit caracteres.
  final OndeStationCode code;

  /// Libelle affichable de la station.
  final String label;

  /// Latitude en degres decimaux, WGS 84.
  final double latitude;

  /// Longitude en degres decimaux, WGS 84 (negative a l'ouest de
  /// Greenwich).
  final double longitude;

  /// Cours d'eau de la station. `null` signifie une absence — jamais une
  /// chaine vide (BR-007).
  final String? waterCourseLabel;

  /// Departement de la station. `null` signifie une absence — jamais une
  /// chaine vide (BR-007).
  final DepartementCode? departement;
}
