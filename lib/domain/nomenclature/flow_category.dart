// C-10, reproduit le 2026-09-13 sur 300 observations du departement 41 :
// code_ecoulement est une CHAINE — '1a' 116, '1f' 95, '2' 24, '3' 65. Les
// codes '1' et '4' (releves le 2026-08-01 sur huit departements) n'y
// apparaissent pas : la nomenclature les accepte sans les exiger.
//
// sealed class et non enumeration : Inconnu doit porter la valeur brute
// recue (BR-011), ce qu'une valeur d'enum ne sait pas faire. NonObserve
// (fait de terrain constate) et Inconnu (notre ignorance) restent distincts
// (BR-007) — ADR-006 les regroupe uniquement a l'affichage.

/// Categorie d'ecoulement observee sur une station ONDE.
sealed class FlowCategory {
  const FlowCategory();
}

/// Ecoulement visible — codes `1` et `1a`.
final class Ecoulement extends FlowCategory {
  const Ecoulement();

  @override
  bool operator ==(Object other) => other is Ecoulement;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Ecoulement faible — code `1f`. Signal precurseur d'un assec a venir.
final class EcoulementFaible extends FlowCategory {
  const EcoulementFaible();

  @override
  bool operator ==(Object other) => other is EcoulementFaible;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Ecoulement non visible — code `2`. Des flaques persistent, mais plus
/// d'ecoulement.
final class EcoulementNonVisible extends FlowCategory {
  const EcoulementNonVisible();

  @override
  bool operator ==(Object other) => other is EcoulementNonVisible;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Assec — code `3`. Lit a sec.
final class Assec extends FlowCategory {
  const Assec();

  @override
  bool operator ==(Object other) => other is Assec;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Non observe — code `4`. Un fait de terrain (observation impossible),
/// jamais confondu avec [Inconnu] qui est notre propre ignorance d'un code
/// (BR-007).
final class NonObserve extends FlowCategory {
  const NonObserve();

  @override
  bool operator ==(Object other) => other is NonObserve;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Code absent ou non reconnu. Porte la valeur brute [rawCode], telle que
/// recue — jamais normalisee (BR-011) : c'est ce qui distingue cette classe
/// d'une enumeration classique.
final class Inconnu extends FlowCategory {
  const Inconnu(this.rawCode);

  /// La valeur telle que recue de l'API, sans `trim` ni changement de
  /// casse. `null` si aucun code n'a ete transmis.
  final String? rawCode;

  @override
  bool operator ==(Object other) =>
      other is Inconnu && other.rawCode == rawCode;

  @override
  int get hashCode => rawCode.hashCode;

  @override
  String toString() => 'Inconnu($rawCode)';
}

/// Traduit un `code_ecoulement` de l'API ONDE en [FlowCategory]. Ne leve
/// jamais : un code non reconnu devient [Inconnu] plutot que de faire
/// echouer l'appelant. La comparaison se fait apres `trim` et passage en
/// minuscules, mais [Inconnu.rawCode] conserve la valeur recue, non
/// normalisee.
FlowCategory flowCategoryFromCode(String? code) {
  final String? normalized = code?.trim().toLowerCase();

  switch (normalized) {
    case '1':
    case '1a':
      return const Ecoulement();
    case '1f':
      return const EcoulementFaible();
    case '2':
      return const EcoulementNonVisible();
    case '3':
      return const Assec();
    case '4':
      return const NonObserve();
    default:
      return Inconnu(code);
  }
}

/// Libelle affichable d'une [FlowCategory]. `switch` exhaustif : une
/// sous-classe ajoutee sans branche ici est une erreur de compilation
/// (BR-011), pas un oubli silencieux a l'ecran.
String flowCategoryLabel(FlowCategory category) => switch (category) {
  Ecoulement() => 'Écoulement visible',
  EcoulementFaible() => 'Écoulement faible',
  EcoulementNonVisible() => 'Eau stagnante',
  Assec() => 'À sec',
  NonObserve() => 'Observation impossible',
  Inconnu() => 'Non renseigné',
};
