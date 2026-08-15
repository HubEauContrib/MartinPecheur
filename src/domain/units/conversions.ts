import {
  cubicMetresPerSecond,
  metres,
  type CubicMetresPerSecond,
  type LitresPerSecond,
  type Metres,
  type Millimetres,
} from "./quantities";

/**
 * Hub'Eau renvoie le débit en litres par seconde et la hauteur en millimètres,
 * contrairement à ce que sa documentation laisse croire (C-02, vérifié le
 * 2026-07-30 : `53000.0` valait 53 m³/s).
 *
 * Ce facteur ne doit apparaître NULLE PART ailleurs dans le code. Une double
 * conversion est aussi fausse qu'une conversion oubliée, et bien plus difficile
 * à repérer (BR-002).
 */
const PER_THOUSAND = 1000;

function divide(value: number): number {
  if (!Number.isFinite(value)) {
    throw new RangeError(
      `Conversion impossible : la valeur doit être finie, reçu ${String(value)}.`,
    );
  }
  return value / PER_THOUSAND;
}

/**
 * `null` et `undefined` en entrée donnent `null` en sortie. L'absence de mesure
 * n'est jamais remplacée par zéro : un zéro est un fait mesuré — un assec —,
 * une absence n'en est pas un (BR-007).
 *
 * Une valeur non finie lève plutôt que de rendre `null` : NaN n'est pas « pas
 * de donnée », c'est un bug. Le confondre avec une absence afficherait « la
 * station n'a pas transmis » alors que le code est cassé.
 */
export function toCubicMetresPerSecond(
  value: LitresPerSecond | null | undefined,
): CubicMetresPerSecond | null {
  if (value === null || value === undefined) return null;
  return cubicMetresPerSecond(divide(value));
}

export function toMetres(value: Millimetres | null | undefined): Metres | null {
  if (value === null || value === undefined) return null;
  return metres(divide(value));
}
