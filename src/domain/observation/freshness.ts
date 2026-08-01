/**
 * Âge d'une observation hydrométrique temps réel (BR-005).
 *
 * Union close, sans valeur par défaut implicite (BR-011).
 */
export type Freshness = "Fraiche" | "Ancienne" | "Perimee";

/**
 * Seuils ABSOLUS fixés par BR-005 : 2 h puis 24 h.
 *
 * ⚠️ Ce ne sont pas des multiples du TTL de cache. `03-conception.md § 4.1`
 * évoque « 2 × TTL », mais il y décrit la fraîcheur du CACHE — une autre
 * question. Les confondre déclarerait périmée une observation de 40 minutes,
 * alors que BR-005 lui laisse 24 heures.
 */
export const ANCIENNE_APRES_MS = 2 * 60 * 60 * 1000;
export const PERIMEE_APRES_MS = 24 * 60 * 60 * 1000;

/**
 * Fonction pure : l'instant courant est un paramètre, jamais `Date.now()` lu à
 * l'intérieur. Ce sont les bornes qui portent la règle, et des bornes non
 * testables ne sont pas des bornes.
 *
 * `observedAt` est la date de MESURE (`date_obs`), jamais la date de
 * récupération — une donnée fraîchement téléchargée peut être vieille de neuf
 * jours, et c'est le cas en production (BR-001, BR-005).
 *
 * ⚠️ Ne s'applique pas aux observations ONDE : une campagne de trois semaines
 * y est normale, pas périmée. Voir BR-010.
 */
export function freshnessOf(observedAt: Date, now: Date): Freshness {
  const ageMs = now.getTime() - observedAt.getTime();

  // La borne appartient à l'état le plus sévère : on ne minimise jamais l'âge
  // d'une donnée sur laquelle un usager peut fonder une décision.
  if (ageMs >= PERIMEE_APRES_MS) return "Perimee";
  if (ageMs >= ANCIENNE_APRES_MS) return "Ancienne";
  return "Fraiche";
}
