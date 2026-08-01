/**
 * Le seul endroit du code qui décide ce qu'est un succès HTTP.
 *
 * Hub'Eau répond **206** sur une réponse paginée partielle et **200** quand
 * tout tient en une page — sur le **même endpoint**, selon `size` (C-06).
 * Constaté le 2026-08-01 : `referentiel/stations?size=10000` → 200,
 * `observations_tr?size=3` → 206, `ecoulement/observations?size=1000` → 206.
 *
 * `fetch` ne lève pas sur un 206 : un `if (status === 200)` passe donc la revue
 * de code et casse à la première pagination. C'est précisément le piège que
 * cette fonction existe pour fermer, une fois pour toutes.
 */
const SUCCESS = new Set([200, 206]);

export function isSuccess(status: number): boolean {
  return SUCCESS.has(status);
}

/**
 * Statuts transitoires, qui justifient une nouvelle tentative.
 *
 * `429` est possible : Hub'Eau n'annonce **aucun quota chiffré** (C-15), donc
 * on ne sait pas où est la limite. Les `5xx` sont transitoires par nature.
 *
 * Un `4xx` client ne l'est jamais : il vient de **notre** requête. Le rejouer
 * ne ferait que marteler un service public gratuit sans aucune chance de
 * succès — `400 ValidatePageSize` ne deviendra pas valide en insistant.
 */
export function isRetryable(status: number): boolean {
  return status === 429 || status >= 500;
}
