// Type d'une zone d'alerte secheresse — conception T2 § 2.7. Le sens des
// trois codes (`SUP`, `SOU`, `AEP`) vient du schema de la source ; un meme
// point peut relever de plusieurs types a la fois, chacun avec sa gravite et
// ses usages (Q5-B).
//
// sealed class et non enumeration : TypeZoneInconnu doit porter la valeur
// brute recue (BR-011). Il ne s'appelle pas `Inconnu`, deja pris par
// `flow_category.dart`.
//
// Les libelles sont ceux de la conception d'ecran (C1 de T2, Q-5a, arbitre
// le 2026-09-27), ajoutes par E2 a cote de la nomenclature, sur le modele de
// `droughtSeverityLabel` : `zoneKindLabel`.

/// Type de ressource en eau que couvre une zone d'alerte.
sealed class ZoneKind {
  const ZoneKind();
}

/// Eaux superficielles — code `SUP`.
final class EauxSuperficielles extends ZoneKind {
  const EauxSuperficielles();

  @override
  bool operator ==(Object other) => other is EauxSuperficielles;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Eaux souterraines — code `SOU`.
final class EauxSouterraines extends ZoneKind {
  const EauxSouterraines();

  @override
  bool operator ==(Object other) => other is EauxSouterraines;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Eau potable — code `AEP`.
final class EauPotable extends ZoneKind {
  const EauPotable();

  @override
  bool operator ==(Object other) => other is EauPotable;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Type absent ou non reconnu. Porte la valeur brute [rawValue], telle que
/// recue — jamais normalisee (BR-011).
final class TypeZoneInconnu extends ZoneKind {
  const TypeZoneInconnu(this.rawValue);

  /// La valeur telle que recue de la source, sans `trim` ni changement de
  /// casse. `null` si aucun type n'a ete transmis.
  final String? rawValue;

  @override
  bool operator ==(Object other) =>
      other is TypeZoneInconnu && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => 'TypeZoneInconnu($rawValue)';
}

/// Libelle affichable d'un [ZoneKind] — le SEUL du projet (Q-5a de C1).
/// Un type inconnu rend un libelle fixe : sa valeur brute n'est jamais
/// affichee (BR-011).
///
/// `switch` exhaustif : une branche ajoutee sans libelle ici est une erreur
/// de compilation (BR-011), pas un oubli silencieux a l'ecran.
String zoneKindLabel(ZoneKind kind) => switch (kind) {
  EauxSuperficielles() => 'Eaux superficielles',
  EauxSouterraines() => 'Eaux souterraines',
  EauPotable() => 'Eau potable',
  TypeZoneInconnu() => 'Type de zone non renseigné',
};
