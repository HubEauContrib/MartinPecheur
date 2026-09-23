// Un rattachement administratif — région ou département — porté par une
// station ou un point ONDE (ADR-015). Un seul type pour les deux niveaux :
// un code et un libellé, jamais plus. La région comme le département
// partagent ce type : ce n'est qu'au niveau demandé (`AreaLevel`,
// `lib/domain/geo/area_cluster.dart`) qu'ils se distinguent. Dart pur
// (CLAUDE.md, invariants d'architecture ; ADR-014).
//
// Une classe et non un `extension type` : comme `StationCode` ou `Bounds`,
// elle porte plusieurs champs — un `extension type` ne s'applique qu'à une
// unique valeur qui s'efface à l'exécution. Elle ne valide rien : le code de
// département reste validé par `DepartementCode` à la lecture (mapper,
// analyse de l'asset) avant d'être rangé ici comme `code` — cette classe ne
// fait que porter le couple une fois la valeur acceptée.

/// Une zone administrative — région ou département — identifiée par son
/// code et son libellé, tels que reçus de la source (asset ou API). Le
/// libellé est gardé tel quel : aucune correspondance de casse n'est faite
/// entre l'asset (capitales sans accent) et l'API ONDE (casse mixte).
final class AdministrativeArea {
  const AdministrativeArea({required this.code, required this.label});

  /// Code de la zone, tel que reçu (`code_region` ou `code_departement`).
  final String code;

  /// Libellé de la zone, tel que reçu — jamais recalculé.
  final String label;

  /// Égalité structurelle sur les deux champs : deux zones de même code
  /// mais de libellé différent (jamais rencontré sur le référentiel)
  /// resteraient distinctes — le libellé vient de la source, il n'est pas
  /// jugé ici.
  @override
  bool operator ==(Object other) =>
      other is AdministrativeArea && other.code == code && other.label == label;

  @override
  int get hashCode => Object.hash(code, label);

  @override
  String toString() => '$code ($label)';
}
