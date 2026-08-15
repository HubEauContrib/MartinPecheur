import type { Branded } from "../units/branded";

/**
 * Un code station fait **dix** caractères (`"K447001001"`). Un code site en
 * fait huit (`"K4470010"`), et l'interroger renvoie chaque mesure **en double**
 * (C-05, vérifié le 2026-08-01). Le type interdit de confondre les deux.
 */
export type StationCode = Branded<string, "code_station">;

/**
 * Code de département INSEE, **en chaîne**. `"01"` traité comme un nombre
 * deviendrait `1` et ne correspondrait plus à rien côté API. La Corse
 * (`"2A"`, `"2B"`) le rendrait de toute façon impossible.
 */
export type DepartementCode = Branded<string, "code_departement">;

const STATION_CODE_LENGTH = 10;

/**
 * Forme **mesurée** sur les 4 150 stations en service le 2026-08-15, et non
 * supposée : 3 974 codes en `A999999999` (une lettre puis neuf chiffres) et
 * 176 en `9999999999` (dix chiffres) — ces derniers sont ceux des DOM.
 *
 * ⚠️ Restreindre à `^[A-Z]\d{9}$`, qui décrit pourtant la forme la plus
 * fréquente, rejetterait ces 176 stations. C'est exactement le genre de règle
 * qu'on n'écrit pas d'après un échantillon.
 */
const STATION_CODE_PATTERN = /^[A-Z0-9]{10}$/;
/** Deux chiffres, `2A`/`2B`, ou trois chiffres pour l'outre-mer. */
const DEPARTEMENT_PATTERN = /^(\d{2}|2[AB]|\d{3})$/;

export function stationCode(value: string): StationCode {
  if (value.length !== STATION_CODE_LENGTH) {
    throw new RangeError(
      `Un code station fait dix caractères, reçu ${value.length} : « ${value} ». ` +
        `Un code site (huit caractères) produirait des mesures en double (C-05).`,
    );
  }
  if (!STATION_CODE_PATTERN.test(value)) {
    throw new RangeError(
      `Forme de code station invalide : « ${value} ». Attendu dix caractères ` +
        `en majuscules et chiffres. Une valeur de la bonne longueur mais de la ` +
        `mauvaise forme partirait vers Hub'Eau et reviendrait vide, ce que ` +
        `l'écran afficherait en « pas de donnée » (BR-007).`,
    );
  }
  return value as StationCode;
}

export function departementCode(value: string): DepartementCode {
  const normalized = value.toUpperCase();
  if (!DEPARTEMENT_PATTERN.test(normalized)) {
    throw new RangeError(
      `Code de département attendu sur deux chiffres, « 2A »/« 2B », ou trois ` +
        `chiffres pour l'outre-mer. Reçu : « ${value} ».`,
    );
  }
  return normalized as DepartementCode;
}

/**
 * Station hydrométrique du référentiel Hub'Eau.
 *
 * ⚠️ Les coordonnées viennent de `latitude_station`/`longitude_station` dans le
 * référentiel, mais de `latitude`/`longitude` dans `observations_tr` — deux
 * noms pour la même chose, constaté le 2026-08-01. Le domaine n'en connaît
 * qu'un : c'est au mapper d'absorber l'écart.
 */
export interface Station {
  readonly code: StationCode;
  readonly libelle: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly codeDepartement: DepartementCode;
  /** `null` quand le référentiel ne rattache la station à aucun cours d'eau. */
  readonly libelleCoursEau: string | null;
  readonly enService: boolean;
}
