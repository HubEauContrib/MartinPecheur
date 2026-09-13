// L'etat d'une station telle que dessinee sur la carte. Distinct de
// Freshness (`freshness.dart`, qui qualifie une observation deja recue) :
// StationMapState qualifie l'ECRAN — a-t-on seulement essaye de charger
// cette station ? — ce que Freshness ne sait pas dire. Sans NonChargee, un
// ecran qui n'a pas encore recu de reponse afficherait le meme etat qu'une
// absence de donnee constatee, ce que BR-007 interdit.
//
// sealed class et switch exhaustif (BR-011) : une sous-classe ajoutee sans
// branche dans stationMapStateLabel est une erreur de compilation.

import 'package:martinpecheur/domain/observation/freshness.dart';

/// Etat d'une station telle qu'affichee sur la carte, du point de vue du
/// chargement — jamais de la valeur mesuree elle-meme.
sealed class StationMapState {
  const StationMapState();
}

/// Aucune requete n'a encore abouti pour cette station : ni succes, ni
/// echec, ni absence constatee. Distinct de [SansDonnee] (BR-007) — c'est
/// cette distinction qui empeche un ecran en cours de chargement d'afficher
/// un etat par defaut.
final class NonChargee extends StationMapState {
  const NonChargee();

  @override
  bool operator ==(Object other) => other is NonChargee;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Une observation a ete recue pour cette station, avec sa [freshness].
final class Chargee extends StationMapState {
  const Chargee(this.freshness);

  /// Fraicheur de l'observation recue.
  final Freshness freshness;

  @override
  bool operator ==(Object other) =>
      other is Chargee && other.freshness == freshness;

  @override
  int get hashCode => freshness.hashCode;
}

/// La requete a abouti, mais aucune observation n'existe pour cette
/// station : un fait constate, jamais une erreur (BR-007).
final class SansDonnee extends StationMapState {
  const SansDonnee();

  @override
  bool operator ==(Object other) => other is SansDonnee;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// La requete a echoue. Porte la [cause] pour que l'ecran puisse nommer la
/// source defaillante (`UC-001 A4`).
final class EnEchec extends StationMapState {
  const EnEchec(this.cause);

  /// Cause de l'echec, telle que levee par le depot.
  final Object cause;

  @override
  bool operator ==(Object other) => other is EnEchec && other.cause == cause;

  @override
  int get hashCode => cause.hashCode;
}

/// Libelle affichable d'un [StationMapState]. `switch` exhaustif : une
/// sous-classe ajoutee sans branche ici est une erreur de compilation
/// (BR-011), pas un oubli silencieux a l'ecran.
///
/// [NonChargee] ne porte aucun libelle (chaine vide) : un chargement en
/// cours n'affiche pas de texte d'etat. [SansDonnee] porte le libelle de
/// repli exact de BR-007. Aucun mot banni (*suffisant, insuffisant, normal,
/// bon, sur*) n'apparait dans aucune branche (BR-003).
///
/// Les seuils affiches pour [Chargee] dérivent de [ancienneApres] et
/// [perimeeApres] (`freshness.dart`) — jamais recopiés en dur ici, sans
/// quoi une revision de BR-005 laisserait ce libelle mentir.
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
