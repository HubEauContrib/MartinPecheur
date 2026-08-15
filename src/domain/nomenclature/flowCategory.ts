/**
 * Catégories d'affichage de l'écoulement ONDE (ADR-006).
 *
 * Quatre catégories de carte — `Ecoulement`, `EcoulementFaible`,
 * `EcoulementNonVisible`, `Assec` — plus deux états qui ne sont PAS des
 * synonymes :
 *
 *  - `NonObserve` : l'observateur s'est déplacé et n'a pas pu observer
 *    (code `4`, « Observation impossible »). C'est un fait de terrain.
 *  - `Inconnu`    : nous ne savons pas lire la donnée — code absent ou non
 *    répertorié. C'est notre ignorance à nous (BR-011).
 *
 * Les fondre ferait passer notre ignorance pour une observation, ce que le
 * produit s'interdit (BR-007). ADR-006 les regroupe à l'affichage ; le domaine,
 * lui, les garde distincts pour que rien ne soit perdu.
 */
export type FlowCategory =
  | "Ecoulement"
  | "EcoulementFaible"
  | "EcoulementNonVisible"
  | "Assec"
  | "NonObserve"
  | "Inconnu";

/**
 * Les six codes constatés en production le 2026-08-01, sur 7 000 observations
 * de `/v1/ecoulement/observations` réparties sur 8 départements :
 *   "1" 1475 · "1a" 2877 · "1f" 1148 · "2" 405 · "3" 1042 · "4" 23
 *
 * Ce sont des chaînes, pas des entiers (C-10).
 */
const BY_CODE: Readonly<Record<string, FlowCategory>> = {
  "1": "Ecoulement",
  "1a": "Ecoulement",
  "1f": "EcoulementFaible",
  "2": "EcoulementNonVisible",
  "3": "Assec",
  "4": "NonObserve",
};

/**
 * `code_ecoulement` vaut `null` sur une part non négligeable des observations —
 * 30 sur 7 000 le 2026-08-01, soit **plus** que le code `4` lui-même. Ce n'est
 * donc pas un cas défensif hypothétique : c'est un cas nominal.
 *
 * Un code non répertorié ne fait pas échouer la lecture non plus. Perdre
 * l'observation serait pire que de nommer notre ignorance.
 */
export function flowCategoryFromOndeCode(code: string | null | undefined): FlowCategory {
  if (code === null || code === undefined) return "Inconnu";
  return BY_CODE[code.trim().toLowerCase()] ?? "Inconnu";
}
