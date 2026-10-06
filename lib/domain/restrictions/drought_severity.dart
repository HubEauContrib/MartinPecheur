// Echelle 3 de `04-ui.md` § 2 : la gravite d'une zone d'alerte secheresse,
// decision prefectorale — jamais fondue avec l'ecoulement ni le debit
// (BR-008). Conception T2 § 2.7.
//
// sealed class et non enumeration : GraviteInconnue doit porter la valeur
// brute recue (BR-011), ce qu'une valeur d'enum ne sait pas faire. Elle ne
// s'appelle pas `Inconnu` : ce nom est deja pris par `flow_category.dart`,
// et deux classes homonymes rendraient ambigu tout fichier qui importe les
// deux echelles.
//
// ⚠️ Aucun rang de severite n'est expose : T2 ne compare jamais deux zones
// (Q6-A). Un rang inviterait a resumer un point par « sa » zone la plus
// severe, alors que chaque zone regit ses propres usages (YAGNI, jusqu'a
// BR-009 en echelle 3).

/// Gravite d'une zone d'alerte secheresse, telle que decidee par arrete.
sealed class DroughtSeverity {
  const DroughtSeverity();
}

/// Vigilance.
final class Vigilance extends DroughtSeverity {
  const Vigilance();

  @override
  bool operator ==(Object other) => other is Vigilance;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Alerte.
final class Alerte extends DroughtSeverity {
  const Alerte();

  @override
  bool operator ==(Object other) => other is Alerte;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Alerte renforcee.
final class AlerteRenforcee extends DroughtSeverity {
  const AlerteRenforcee();

  @override
  bool operator ==(Object other) => other is AlerteRenforcee;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Crise.
final class Crise extends DroughtSeverity {
  const Crise();

  @override
  bool operator ==(Object other) => other is Crise;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Gravite absente ou non reconnue. Porte la valeur brute [rawValue], telle
/// que recue — jamais normalisee (BR-011). N'a aucune position sur
/// [droughtSeverityScale] : elle ne prend ni la teinte ni la forme d'un
/// niveau connu.
final class GraviteInconnue extends DroughtSeverity {
  const GraviteInconnue(this.rawValue);

  /// La valeur telle que recue de la source, sans `trim` ni changement de
  /// casse. `null` si aucune gravite n'a ete transmise.
  final String? rawValue;

  @override
  bool operator ==(Object other) =>
      other is GraviteInconnue && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => 'GraviteInconnue($rawValue)';
}

/// L'echelle complete, dans l'ordre du schema de la source et de `04-ui.md`
/// § 2. [GraviteInconnue] n'y figure pas. La vue y repere la position d'une
/// zone par egalite.
const List<DroughtSeverity> droughtSeverityScale = <DroughtSeverity>[
  Vigilance(),
  Alerte(),
  AlerteRenforcee(),
  Crise(),
];

/// Libelle affichable d'une [DroughtSeverity] — le SEUL du projet pour cette
/// echelle : colonne « Libelle carte » de l'echelle 3, `04-ui.md` § 2. Un
/// concept, un mot (`glossary.md`).
///
/// `switch` exhaustif : une sous-classe ajoutee sans branche ici est une
/// erreur de compilation (BR-011), pas un oubli silencieux a l'ecran.
String droughtSeverityLabel(DroughtSeverity severity) => switch (severity) {
  Vigilance() => 'Vigilance',
  Alerte() => 'Alerte',
  AlerteRenforcee() => 'Alerte renforcée',
  Crise() => 'Crise',
  GraviteInconnue() => 'Non renseigné',
};
