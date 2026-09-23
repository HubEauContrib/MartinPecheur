// BR-009 : le symbole d'une pastille de zone (ADR-015) porte l'état le plus
// sévère de ses membres, jamais une moyenne ni le dernier lu. L'ordre de
// sévérité — Assec > EcoulementNonVisible > EcoulementFaible > Ecoulement —
// est celui de BR-009. NonObserve (fait de terrain constaté) et Inconnu
// (notre ignorance d'un code) restent hors de ce classement (BR-007) : ils
// ne l'emportent que faute de catégorie observée, et NonObserve l'emporte
// alors sur Inconnu — un fait de terrain avant notre propre ignorance.
//
// `switch` exhaustif sur la `sealed class` (BR-011) : une sous-classe
// ajoutée sans branche ici est une erreur de compilation, pas un classement
// silencieusement faux.

import 'package:martinpecheur/domain/nomenclature/flow_category.dart';

/// Rang de sévérité d'une [FlowCategory] OBSERVÉE, du plus au moins sévère
/// (BR-009). `null` pour [NonObserve] et [Inconnu] : elles n'ont pas de
/// rang, [mostSevere] les traite à part.
int? _severityRank(FlowCategory category) => switch (category) {
  Assec() => 0,
  EcoulementNonVisible() => 1,
  EcoulementFaible() => 2,
  Ecoulement() => 3,
  NonObserve() => null,
  Inconnu() => null,
};

/// La catégorie la plus sévère de [categories] (BR-009).
///
/// [NonObserve] et [Inconnu] ne participent pas au classement : elles ne
/// l'emportent que si AUCUNE catégorie observée n'est présente dans
/// [categories], et alors [NonObserve] l'emporte sur [Inconnu] (BR-007 —
/// un fait de terrain constaté prime sur notre ignorance d'un code). Le
/// résultat ne dépend jamais de l'ordre de [categories] pour les catégories
/// OBSERVÉES, ni pour le choix entre [NonObserve] et [Inconnu] : seul le
/// départage ENTRE PLUSIEURS [Inconnu] distincts (des `rawCode` différents)
/// retient le premier rencontré dans [categories], puisque rien d'autre ne
/// les distingue.
///
/// Lève une [ArgumentError] si [categories] est vide : il n'y a alors rien à
/// classer, et rendre une valeur par défaut inventerait un état (`ADR-002`,
/// jamais un seuil ni un état fabriqué).
FlowCategory mostSevere(Iterable<FlowCategory> categories) {
  final List<FlowCategory> liste = categories.toList();
  if (liste.isEmpty) {
    throw ArgumentError.value(
      liste,
      'categories',
      'ne doit pas être vide — rien à classer',
    );
  }

  FlowCategory? plusSevere;
  int? rangPlusSevere;
  FlowCategory? premierNonObserve;
  FlowCategory? premierInconnu;

  for (final FlowCategory categorie in liste) {
    final int? rang = _severityRank(categorie);
    if (rang == null) {
      if (categorie is NonObserve) {
        premierNonObserve ??= categorie;
      } else {
        premierInconnu ??= categorie;
      }
      continue;
    }
    if (rangPlusSevere == null || rang < rangPlusSevere) {
      rangPlusSevere = rang;
      plusSevere = categorie;
    }
  }

  if (plusSevere != null) {
    return plusSevere;
  }
  if (premierNonObserve != null) {
    return premierNonObserve;
  }
  return premierInconnu!;
}
