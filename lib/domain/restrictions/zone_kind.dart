// Type d'une zone d'alerte secheresse — conception T2 § 2.7. Le sens des
// trois codes (`SUP`, `SOU`, `AEP`) vient du schema de la source ; un meme
// point peut relever de plusieurs types a la fois, chacun avec sa gravite et
// ses usages (Q5-B).
//
// sealed class et non enumeration : TypeZoneInconnu doit porter la valeur
// brute recue (BR-011). Il ne s'appelle pas `Inconnu`, deja pris par
// `flow_category.dart`.
//
// Aucun libelle ici : ils sont fixes par la conception d'ecran (C1 de T2),
// puis ajoutes a cote de la nomenclature, sur le modele de
// `droughtSeverityLabel`.

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
