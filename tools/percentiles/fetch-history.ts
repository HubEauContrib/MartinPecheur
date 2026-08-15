/**
 * Aspiration de l'historique `obs_elab` — script d'outillage, HORS application
 * (ADR-003). Il tourne au poste de travail pour produire l'asset de
 * percentiles ; il n'est jamais embarqué dans le binaire.
 *
 * Deux pièges d'API, tous deux vérifiés par appel réel :
 *
 * - `obs_elab` n'accepte **aucun** paramètre `sort` : il est ignoré en silence
 *   et la réponse commence en 1900. `date_debut_obs_elab` est la seule façon de
 *   borner la fenêtre (`C-04`, reconstaté le 2026-08-15 : sans lui, la première
 *   date renvoyée est `1900-01-01`, sur 44 696 observations pour `K447001001`).
 * - `size` plafonne à 10000 — au-delà, HTTP 400 `ValidatePageSize`. La
 *   pagination se fait par curseur `next`, pas par `page`.
 */

const BASE_URL = "https://hubeau.eaufrance.fr/api/v2/hydrometrie/obs_elab";

/** Plafond constaté le 2026-07-31 ; au-delà l'API rend 400. */
const TAILLE_DE_PAGE = 10000;

/**
 * Une station par seconde. 4 150 stations ≈ 70 minutes : lent est le
 * comportement correct ici. Hub'Eau n'annonce ni SLA ni quota chiffré
 * (`C-15`), donc rien ne nous arrêterait — c'est précisément pour ça qu'on
 * s'arrête nous-mêmes.
 */
export const INTERVALLE_MINIMUM_MS = 1000;

/** Une page de réponse `obs_elab`, réduite à ce que l'aspiration utilise. */
export interface PageObsElab<T> {
  readonly data: readonly T[];
  /** Curseur vers la page suivante, `null` sur la dernière. */
  readonly next: string | null;
}

export type GetJson<T> = (url: string) => Promise<PageObsElab<T>>;

/** Attente injectée plutôt que codée en dur : sans ça, le test dure 70 minutes. */
export type Attendre = (ms: number) => Promise<void>;

export function buildHistoryUrl(codeStation: string, debut: string): string {
  const params = new URLSearchParams({
    code_entite: codeStation, // code à dix caractères uniquement (C-05)
    grandeur_hydro_elab: "QmnJ",
    date_debut_obs_elab: debut, // sans lui, la réponse démarre en 1900 (C-04)
    size: String(TAILLE_DE_PAGE),
  });
  return `${BASE_URL}?${params.toString()}`;
}

/**
 * Aspire l'historique de chaque station, page par page.
 *
 * Une station en erreur est **omise du résultat, sans interrompre le lot** :
 * sur 4 150 stations, perdre plus d'une heure d'aspiration pour un 500
 * passager n'aurait pas de sens. L'appelant compare les tailles pour savoir
 * ce qui manque.
 */
export async function fetchAllStations<T>(
  codes: readonly string[],
  debut: string,
  getJson: GetJson<T>,
  attendre: Attendre = (ms) => new Promise<void>((r) => setTimeout(r, ms)),
): Promise<Map<string, T[]>> {
  const parStation = new Map<string, T[]>();

  for (const [index, code] of codes.entries()) {
    // Le throttle sépare deux appels, pas plus : après la toute dernière
    // station il n'y a plus rien à protéger.
    if (index > 0) await attendre(INTERVALLE_MINIMUM_MS);

    try {
      const lignes: T[] = [];
      let url: string | null = buildHistoryUrl(code, debut);

      const vues = new Set<string>();

      while (url !== null) {
        // Un curseur qui ne progresse pas ferait boucler indéfiniment, à un
        // appel par seconde et pour toujours. Le `try/catch` ne rattraperait
        // rien : une boucle infinie ne lève pas. Sur un script conçu pour
        // tourner 70 minutes sans surveillance, la panne serait invisible.
        if (vues.has(url)) {
          console.error(`${code} : curseur de pagination qui se répète, station interrompue`);
          break;
        }
        vues.add(url);

        const page: PageObsElab<T> = await getJson(url);
        lignes.push(...page.data);
        url = page.next; // pagination par curseur, jamais par page+size

        // Inutile d'attendre après la dernière page : le throttle protège
        // l'API entre deux appels, pas après le dernier.
        if (url !== null) await attendre(INTERVALLE_MINIMUM_MS);
      }

      parStation.set(code, lignes);
    } catch (erreur) {
      // Signalé, pas avalé : l'aspiration continue, mais on doit savoir.
      console.error(`${code} : échec — ${erreur instanceof Error ? erreur.message : erreur}`);
    }
  }

  return parStation;
}
