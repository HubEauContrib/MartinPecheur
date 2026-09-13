// L'observation hydrometrique brute, deja convertie (BR-002) : discharge et
// level portent un type d'unite, jamais un double nu. null veut dire que la
// station n'a pas transmis cette grandeur (BR-007) — un zero mesure est un
// assec, pas une absence. measuredAt est la date de MESURE (BR-001) :
// freshnessAt recoit l'instant, l'entite ne lit jamais l'horloge elle-meme.

import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

/// Grandeur portee par une observation hydrometrique. `inconnu` est une
/// branche a part entiere (BR-011) : assimiler un code inconnu a [debit]
/// afficherait des metres comme des m³/s.
enum Grandeur {
  /// Hauteur d'eau — code API `H`.
  hauteur,

  /// Debit — code API `Q`.
  debit,

  /// Code absent ou non reconnu.
  inconnu,
}

/// Traduit le code `grandeur_hydro` de l'API en [Grandeur]. La casse n'est
/// pas normalisee : `H`/`Q` sont des codes, un `q` minuscule est une valeur
/// inconnue, pas une variante de `Q`.
Grandeur grandeurFromCode(String? code) {
  switch (code) {
    case 'H':
      return Grandeur.hauteur;
    case 'Q':
      return Grandeur.debit;
    default:
      return Grandeur.inconnu;
  }
}

/// Qualification d'une observation, transportee telle quelle (BR-006) :
/// aucun champ n'est interprete ni filtre ici, l'affichage en decide.
final class Qualification {
  const Qualification({
    required this.statusCode,
    required this.statusLabel,
    required this.qualificationCode,
    required this.qualificationLabel,
  });

  /// Code de statut de l'observation (ex. pre-validee, validee). `null` si
  /// absent.
  final int? statusCode;

  /// Libelle du statut. `null` si absent.
  final String? statusLabel;

  /// Code de qualification de l'observation (ex. bonne, incertaine). `null`
  /// si absent.
  final int? qualificationCode;

  /// Libelle de la qualification. `null` si absent.
  final String? qualificationLabel;
}

/// Une observation hydrometrique, deja convertie et toujours datee.
final class HydroObservation {
  const HydroObservation({
    required this.station,
    required this.measuredAt,
    required this.grandeur,
    required this.discharge,
    required this.level,
    required this.qualification,
  });

  /// Station a l'origine de la mesure.
  final StationCode station;

  /// Date de la MESURE, jamais de la recuperation (BR-001).
  final DateTime measuredAt;

  /// Grandeur portee par cette observation.
  final Grandeur grandeur;

  /// Debit converti (m³/s). `null` si la station n'a pas transmis cette
  /// grandeur (BR-007) — jamais zero.
  final CubicMetresPerSecond? discharge;

  /// Hauteur convertie (m). `null` si la station n'a pas transmis cette
  /// grandeur (BR-007) — jamais zero. Traverse sans controle de signe.
  final Metres? level;

  /// Qualification associee a la mesure.
  final Qualification qualification;

  /// Fraicheur de cette observation vue a l'instant [now]. Delegue a
  /// [freshnessOf] sur [measuredAt] : cette methode ne lit jamais
  /// l'horloge elle-meme.
  Freshness freshnessAt(DateTime now) =>
      freshnessOf(measuredAt: measuredAt, now: now);
}
