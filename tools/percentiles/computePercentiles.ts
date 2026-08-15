import { cubicMetresPerSecond, type CubicMetresPerSecond } from "../../src/domain/units/quantities";

/**
 * Percentiles de débit par quinzaine calendaire — script d'outillage, HORS
 * application (`ADR-003`). Il tourne au poste de travail pour produire l'asset
 * embarqué ; il n'est jamais appelé au runtime.
 *
 * ⚠️ **Les valeurs entrantes sont en m³/s, pas en l/s.** Le type *branded* le
 * garantit : `obs_elab` rend des litres par seconde (`C-02`), et la conversion
 * appartient à `domain/units/conversions`, seul endroit du projet qui divise
 * par 1000 (`BR-002`). L'appelant convertit ; ce module ne convertit rien.
 */

/** Deux quinzaines par mois, douze mois. */
export const QUINZAINES_PAR_AN = 24;

/** Seuil de `BR-004`. En dessous, aucun percentile n'est publié. */
const ANNEES_MINIMUM = 10;

/** Jour de bascule : le 16 ouvre la seconde quinzaine du mois. */
const PREMIER_JOUR_SECONDE_QUINZAINE = 16;

/**
 * Index de quinzaine calendaire, de 0 (1–15 janvier) à 23 (16–31 décembre).
 *
 * Le découpage est **calendaire, pas de durée égale** : la seconde quinzaine
 * de février fait 13 ou 14 jours, celle de janvier en fait 16. C'est voulu —
 * `BR-004` raisonne sur la quinzaine du calendrier, celle que l'usager
 * reconnaît, pas sur un intervalle glissant.
 *
 * ⚠️ **Lecture en UTC.** Les dates d'`obs_elab` sont des jours, pas des
 * instants : passer par le fuseau local ferait basculer un relevé du 15 au 16
 * selon la machine qui régénère l'asset.
 */
export function fortnightIndex(date: Date): number {
  const millisecondes = date.getTime();
  if (Number.isNaN(millisecondes)) {
    throw new RangeError("Index de quinzaine impossible : date invalide.");
  }

  const mois = date.getUTCMonth();
  const jour = date.getUTCDate();

  return mois * 2 + (jour >= PREMIER_JOUR_SECONDE_QUINZAINE ? 1 : 0);
}

/** Un relevé journalier, rattaché à son année. */
export interface AnneeQuinzaine {
  readonly annee: number;
  readonly valeurM3S: CubicMetresPerSecond;
}

export type PercentilesQuinzaine =
  | { readonly statut: "Indetermine" }
  | {
      readonly statut: "Calcule";
      /** Années **distinctes** représentées — c'est ce que compte `BR-004`. */
      readonly nbAnnees: number;
      /** Relevés retenus. Toujours ≥ `nbAnnees`, souvent bien davantage. */
      readonly nbReleves: number;
      readonly p10: CubicMetresPerSecond;
      readonly p25: CubicMetresPerSecond;
      readonly p50: CubicMetresPerSecond;
      readonly p75: CubicMetresPerSecond;
      readonly p90: CubicMetresPerSecond;
    };

/**
 * Interpolation linéaire entre les deux relevés encadrants.
 *
 * Le choix compte : une méthode qui « choisit » la valeur basse décalerait
 * tout le classement vers le sec, et ce produit n'a pas le droit de se tromper
 * dans ce sens. À reporter dans `ADR-003`.
 */
function percentile(triees: readonly number[], p: number): number {
  const rang = (triees.length - 1) * p;
  const bas = Math.floor(rang);
  const haut = Math.ceil(rang);
  const valeurBasse = triees[bas] ?? 0;
  if (bas === haut) return valeurBasse;
  return valeurBasse + (rang - bas) * ((triees[haut] ?? 0) - valeurBasse);
}

/**
 * ⚠️ **Le seuil de `BR-004` porte sur les années distinctes, pas sur le nombre
 * de relevés.** `QmnJ` est un débit journalier : une quinzaine sur dix ans
 * porte environ 150 valeurs. Compter les relevés franchirait le seuil avec
 * neuf années — et publierait un percentile que la règle interdit, sans que
 * rien ne le signale.
 *
 * Les percentiles, eux, sont calculés sur **tous** les relevés : c'est la
 * distribution du débit sur cette quinzaine qu'on décrit, et la réduire à une
 * valeur par année jetterait l'essentiel de l'échantillon.
 */
export function percentilesForFortnight(
  echantillon: readonly AnneeQuinzaine[],
): PercentilesQuinzaine {
  const annees = new Set(echantillon.map((releve) => releve.annee));
  if (annees.size < ANNEES_MINIMUM) return { statut: "Indetermine" };

  const triees = echantillon.map((releve) => releve.valeurM3S as number).sort((a, b) => a - b);

  return {
    statut: "Calcule",
    nbAnnees: annees.size,
    nbReleves: triees.length,
    p10: cubicMetresPerSecond(percentile(triees, 0.1)),
    p25: cubicMetresPerSecond(percentile(triees, 0.25)),
    p50: cubicMetresPerSecond(percentile(triees, 0.5)),
    p75: cubicMetresPerSecond(percentile(triees, 0.75)),
    p90: cubicMetresPerSecond(percentile(triees, 0.9)),
  };
}
