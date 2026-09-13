// L'état d'une station telle que dessinée sur la carte. Distinct de
// Freshness (`freshness.dart`, qui qualifie une observation déjà reçue) :
// StationMapState qualifie l'ÉCRAN — a-t-on seulement essayé de charger
// cette station ? — ce que Freshness ne sait pas dire. Sans NonChargee, un
// écran qui n'a pas encore reçu de réponse afficherait le même état qu'une
// absence de donnée constatée, ce que BR-007 interdit.
//
// sealed class et switch exhaustif (BR-011) : une sous-classe ajoutée sans
// branche dans stationMapStateLabel est une erreur de compilation.

import 'package:martinpecheur/domain/observation/freshness.dart';

/// État d'une station telle qu'affichée sur la carte, du point de vue du
/// chargement — jamais de la valeur mesurée elle-même.
sealed class StationMapState {
  const StationMapState();
}

/// Aucune requête n'a encore abouti pour cette station : ni succès, ni
/// échec, ni absence constatée. Distinct de [SansDonnee] (BR-007) — c'est
/// cette distinction qui empêche un écran en cours de chargement d'afficher
/// un état par défaut.
final class NonChargee extends StationMapState {
  const NonChargee();

  @override
  bool operator ==(Object other) => other is NonChargee;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Une observation a été reçue pour cette station, avec sa [freshness].
final class Chargee extends StationMapState {
  const Chargee(this.freshness);

  /// Fraîcheur de l'observation reçue.
  final Freshness freshness;

  @override
  bool operator ==(Object other) =>
      other is Chargee && other.freshness == freshness;

  @override
  int get hashCode => freshness.hashCode;
}

/// La requête a abouti, mais aucune observation n'existe pour cette
/// station : un fait constaté, jamais une erreur (BR-007).
final class SansDonnee extends StationMapState {
  const SansDonnee();

  @override
  bool operator ==(Object other) => other is SansDonnee;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// La requête a échoué. Porte la [cause] pour que l'écran puisse nommer la
/// source défaillante (`UC-001 A4`).
final class EnEchec extends StationMapState {
  const EnEchec(this.cause);

  /// Cause de l'échec, telle que levée par le dépôt.
  final Object cause;

  @override
  bool operator ==(Object other) => other is EnEchec && other.cause == cause;

  @override
  int get hashCode => cause.hashCode;
}

/// Libellé affichable d'un [StationMapState]. `switch` exhaustif : une
/// sous-classe ajoutée sans branche ici est une erreur de compilation
/// (BR-011), pas un oubli silencieux à l'écran.
///
/// [NonChargee] ne porte aucun libellé (chaîne vide) : un chargement en
/// cours n'affiche pas de texte d'état. [SansDonnee] porte le libellé de
/// repli exact de BR-007. Aucun mot banni (*suffisant, insuffisant, normal,
/// bon, sûr*) n'apparaît dans aucune branche (BR-003).
///
/// Les seuils affichés pour [Chargee] dérivent de [ancienneApres] et
/// [perimeeApres] (`freshness.dart`) — jamais recopiés en dur ici, sans
/// quoi une révision de BR-005 laisserait ce libellé mentir. `Duration.
/// inHours` tronque vers zéro : si l'une de ces bornes devenait un jour une
/// durée non ronde en heures (90 min, par exemple), le libellé afficherait
/// « 1 h » et non « 1,5 h ». Les valeurs actuelles (2 h, 24 h) sont rondes,
/// donc sans perte — mais la troncature reste implicite dans `inHours` et
/// n'est pas revérifiée ici à chaque appel.
String stationMapStateLabel(StationMapState state) => switch (state) {
  NonChargee() => '',
  Chargee(freshness: Freshness.fraiche) => '',
  Chargee(freshness: Freshness.ancienne) =>
    'Dernière mesure il y a plus de ${ancienneApres.inHours} h',
  Chargee(freshness: Freshness.perimee) =>
    'Dernière mesure il y a plus de ${perimeeApres.inHours} h',
  SansDonnee() => 'Aucune donnée disponible ici.',
  EnEchec() => 'Donnée indisponible pour le moment.',
};
