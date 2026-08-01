/** Délai de la première nouvelle tentative. */
export const BASE_DELAY_MS = 500;

/**
 * Plafond. Sans lui, la huitième tentative attendrait déjà plus d'une minute et
 * la vingtième plus de cent heures : l'exponentielle n'est pas décorative.
 */
export const MAX_DELAY_MS = 30_000;

/**
 * Délai avant la tentative `attempt` (0-indexée), en millisecondes.
 *
 * La gigue est **injectée** plutôt que lue depuis `Math.random()` : c'est ce qui
 * rend la fonction testable, et une fonction de backoff non testée est une
 * fonction dont on ignore le comportement au moment où elle compte le plus.
 *
 * Pourquoi une gigue (C-15) : Hub'Eau n'annonce aucun quota chiffré, et
 * l'application n'a pas de proxy pour mutualiser la charge de sa base
 * installée. Sans étalement, tous les appareils réessaient à la même seconde
 * après une panne et achèvent un service public gratuit au moment précis où il
 * se relève.
 */
export function delayForAttempt(attempt: number, jitter: () => number = Math.random): number {
  const exponential = Math.min(BASE_DELAY_MS * 2 ** attempt, MAX_DELAY_MS);
  // La gigue s'ajoute au délai, puis on replafonne : sans ce second plafond
  // elle ferait dépasser MAX_DELAY_MS de 100 %.
  return Math.min(exponential + jitter() * exponential, MAX_DELAY_MS);
}
