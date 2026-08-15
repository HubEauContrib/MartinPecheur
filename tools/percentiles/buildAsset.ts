import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

import {
  percentilesForFortnight,
  QUINZAINES_PAR_AN,
  type AnneeQuinzaine,
} from "./computePercentiles";

/**
 * Génération de l'asset de percentiles (`ADR-003`) — script d'outillage, HORS
 * application. L'asset est un **livrable versionné**, régénéré par `P4`.
 */

/**
 * Décimales conservées.
 *
 * ⚠️ **Ce n'est pas un réglage d'affichage, c'est la précision de la source.**
 * `obs_elab` rend des litres par seconde **entiers** ; convertis en m³/s
 * (`BR-002`), ils ont au plus trois décimales. L'interpolation des percentiles
 * en fabrique bien davantage — `5.333333333333333` — c'est-à-dire des chiffres
 * qui n'existent dans aucune mesure, et qui gonflent l'asset d'autant. Arrondir
 * ici **restaure** la précision réelle, il ne la dégrade pas.
 */
export const DECIMALES = 3;

/** codeStation → 24 échantillons, un par quinzaine calendaire. */
export type StationsParQuinzaine = ReadonlyMap<string, readonly (readonly AnneeQuinzaine[])[]>;

export interface AssetPercentiles {
  readonly genereLe: string;
  readonly source: string;
  readonly licence: string;
  /**
   * codeStation → 24 entrées. `null` = `Indetermine` (`BR-004`) — l'absence est
   * portée par le format, jamais comblée par un chiffre.
   */
  readonly stations: Record<string, readonly (readonly number[] | null)[]>;
}

function arrondir(valeur: number): number {
  const facteur = 10 ** DECIMALES;
  return Math.round(valeur * facteur) / facteur;
}

/**
 * Format compact : chaque quinzaine est un tableau `[p10, p25, p50, p75, p90]`
 * plutôt qu'un objet nommé. Sur 4 150 stations × 24 quinzaines, les noms de
 * clés répétés pèseraient plus que les valeurs elles-mêmes.
 *
 * ⚠️ `genereLe` est **injecté**. Sans horloge en paramètre, deux générations du
 * même jeu de données produiraient deux assets différents, et le diff git de ce
 * livrable versionné deviendrait illisible.
 */
export function buildAsset(
  parStationEtQuinzaine: StationsParQuinzaine,
  genereLe: Date,
): AssetPercentiles {
  const stations: Record<string, readonly (readonly number[] | null)[]> = {};

  for (const [code, quinzaines] of parStationEtQuinzaine) {
    stations[code] = Array.from({ length: QUINZAINES_PAR_AN }, (_, index) => {
      const resultat = percentilesForFortnight(quinzaines[index] ?? []);
      if (resultat.statut === "Indetermine") return null;
      return [resultat.p10, resultat.p25, resultat.p50, resultat.p75, resultat.p90].map(arrondir);
    });
  }

  return {
    genereLe: genereLe.toISOString(),
    // Attribution obligatoire en Licence Ouverte — une donnée du format, pas
    // une finition d'écran.
    source: "Hub'Eau — Office français de la biodiversité",
    licence: "Licence Ouverte Etalab",
    stations,
  };
}

/** Crée l'arborescence du chemin **reçu**, et pas un chemin codé en dur. */
export function writeAsset(asset: AssetPercentiles, chemin: string): void {
  mkdirSync(dirname(chemin), { recursive: true });
  writeFileSync(chemin, JSON.stringify(asset));
}
