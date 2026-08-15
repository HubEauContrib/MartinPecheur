import { toCubicMetresPerSecond } from "../../src/domain/units/conversions";
import { litresPerSecond } from "../../src/domain/units/quantities";

import { fortnightIndex, QUINZAINES_PAR_AN, type AnneeQuinzaine } from "./computePercentiles";

/**
 * Passage des lignes brutes d'`obs_elab` aux échantillons par quinzaine — le
 * maillon entre `P1` (aspiration) et `P3` (asset).
 *
 * Champs **relevés par appel réel le 2026-08-15** sur `K447001001`, et non
 * d'après la documentation :
 *
 * ```
 * date_obs_elab     : "2025-07-01"   (date seule, pas un instant)
 * resultat_obs_elab : 68296          (entier, LITRES par seconde → 68,296 m³/s)
 * ```
 */

/** Sous-ensemble d'une ligne `obs_elab` réellement utilisé ici. */
export interface ObsElabRow {
  readonly code_station: string;
  readonly date_obs_elab: string;
  /** ⚠️ En **litres par seconde** (`C-02`). Jamais publié tel quel. */
  readonly resultat_obs_elab: number | null;
}

/**
 * Range les relevés d'une station dans ses 24 quinzaines calendaires, en
 * convertissant les unités **une seule fois**, ici (`BR-002`).
 *
 * La conversion passe par `domain/units/conversions`, seul endroit du projet
 * qui divise par 1000. Ce module n'en connaît pas le facteur.
 *
 * ⚠️ **Une date illisible interrompt le lot.** Ce script tourne des heures sans
 * surveillance : un relevé silencieusement rangé dans la mauvaise quinzaine ne
 * se verrait jamais, et fausserait un percentile publié.
 */
export function groupByFortnight(lignes: readonly ObsElabRow[]): (readonly AnneeQuinzaine[])[] {
  const quinzaines: AnneeQuinzaine[][] = Array.from({ length: QUINZAINES_PAR_AN }, () => []);

  for (const ligne of lignes) {
    // `null` signifie « la station n'a pas transmis » — ce n'est pas un zéro,
    // et un zéro est un assec bien réel (BR-007). Les deux ne se confondent pas.
    const valeurM3S = toCubicMetresPerSecond(
      ligne.resultat_obs_elab === null ? null : litresPerSecond(ligne.resultat_obs_elab),
    );
    if (valeurM3S === null) continue;

    const date = new Date(ligne.date_obs_elab);
    if (Number.isNaN(date.getTime())) {
      throw new RangeError(
        `Relevé illisible : date « ${ligne.date_obs_elab} » sur ${ligne.code_station}.`,
      );
    }

    // L'année vient de la date de MESURE, jamais de `date_prod` : celle-ci vaut
    // 2026 sur des relevés de 2025, et les confondre ramènerait trente années
    // d'historique à une seule (BR-004).
    quinzaines[fortnightIndex(date)]?.push({ annee: date.getUTCFullYear(), valeurM3S });
  }

  return quinzaines;
}
