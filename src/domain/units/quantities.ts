import type { Branded } from "./branded";

/**
 * Unités brutes des APIs Hub'Eau. Elles ne sont pas celles que la documentation
 * laisse croire : le débit arrive en l/s et la hauteur en mm (C-02, vérifié le
 * 2026-07-30). Aucune valeur portant ces types n'atteint jamais la vue.
 */
export type LitresPerSecond = Branded<number, "l/s">;
export type Millimetres = Branded<number, "mm">;

/** Unités du produit — les seules affichables (BR-002). */
export type CubicMetresPerSecond = Branded<number, "m3/s">;
export type Metres = Branded<number, "m">;

/**
 * Constructeurs. Ils ne valident rien : ils *nomment* l'unité d'un nombre au
 * moment où on la connaît, c'est-à-dire au bord de l'application, dans le
 * mapper. Passé ce point, l'unité voyage avec la valeur et le compilateur
 * interdit de les confondre.
 */
export const litresPerSecond = (value: number): LitresPerSecond => value as LitresPerSecond;
export const millimetres = (value: number): Millimetres => value as Millimetres;
export const cubicMetresPerSecond = (value: number): CubicMetresPerSecond =>
  value as CubicMetresPerSecond;
export const metres = (value: number): Metres => value as Metres;
