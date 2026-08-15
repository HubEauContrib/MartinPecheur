import { cubicMetresPerSecond } from "@domain/units/quantities";

import {
  fortnightIndex,
  percentilesForFortnight,
  QUINZAINES_PAR_AN,
  type AnneeQuinzaine,
} from "../../../tools/percentiles/computePercentiles";

/** Une année entière de relevés journaliers sur une quinzaine : 15 valeurs. */
const anneeJournaliere = (annee: number, valeur: number): AnneeQuinzaine[] =>
  Array.from({ length: 15 }, () => ({ annee, valeurM3S: cubicMetresPerSecond(valeur) }));

const anneesJournalieres = (nb: number): AnneeQuinzaine[] =>
  Array.from({ length: nb }, (_, i) => anneeJournaliere(2000 + i, i + 1)).flat();

describe("quinzaine calendaire", () => {
  it("découpe l'année en 24 quinzaines", () => {
    expect(QUINZAINES_PAR_AN).toBe(24);
  });

  it("bascule au 16 du mois, pas au 15", () => {
    // La borne compte : un décalage d'un jour déplace un relevé d'étiage
    // d'une quinzaine à l'autre, et fausse les deux échantillons.
    expect(fortnightIndex(new Date("2026-01-01T00:00:00Z"))).toBe(0);
    expect(fortnightIndex(new Date("2026-01-15T23:59:59Z"))).toBe(0);
    expect(fortnightIndex(new Date("2026-01-16T00:00:00Z"))).toBe(1);
    expect(fortnightIndex(new Date("2026-01-31T00:00:00Z"))).toBe(1);
  });

  it("enchaîne les mois sans trou ni recouvrement", () => {
    expect(fortnightIndex(new Date("2026-02-01T00:00:00Z"))).toBe(2);
    expect(fortnightIndex(new Date("2026-12-16T00:00:00Z"))).toBe(23);
    expect(fortnightIndex(new Date("2026-12-31T00:00:00Z"))).toBe(23);
  });

  it("range le 29 février dans la seconde quinzaine de février", () => {
    // Une année bissextile ajoute un jour à la seconde quinzaine de février.
    // Elle ne crée pas de 25e quinzaine.
    expect(fortnightIndex(new Date("2024-02-29T00:00:00Z"))).toBe(3);
  });

  it("ne sort jamais de l'intervalle 0–23", () => {
    for (let jour = 0; jour < 366; jour += 1) {
      const date = new Date(Date.UTC(2024, 0, 1 + jour));
      const index = fortnightIndex(date);
      expect(index).toBeGreaterThanOrEqual(0);
      expect(index).toBeLessThan(QUINZAINES_PAR_AN);
    }
  });

  it("refuse une date invalide plutôt que de rendre NaN", () => {
    expect(() => fortnightIndex(new Date("pas une date"))).toThrow(/date/i);
  });
});

describe("percentiles par quinzaine (BR-004)", () => {
  it("compte les ANNÉES distinctes, pas les relevés", () => {
    // Le piège central de cette tâche. `QmnJ` est un débit journalier : une
    // quinzaine sur dix ans porte 150 valeurs, pas 10. Compter les relevés
    // ferait franchir le seuil de BR-004 avec neuf années seulement — un
    // percentile publié sur un échantillon que la règle interdit.
    const neufAnnees = anneesJournalieres(9);

    expect(neufAnnees).toHaveLength(135);
    expect(percentilesForFortnight(neufAnnees)).toEqual({ statut: "Indetermine" });
  });

  it("calcule à partir de dix années distinctes", () => {
    const resultat = percentilesForFortnight(anneesJournalieres(10));

    expect(resultat.statut).toBe("Calcule");
    if (resultat.statut !== "Calcule") throw new Error("attendu Calcule");
    expect(resultat.nbAnnees).toBe(10);
    expect(resultat.nbReleves).toBe(150);
  });

  it("ne compte pas deux fois une année répétée", () => {
    // Dix relevés d'une même année ne font pas dix années.
    expect(percentilesForFortnight(anneeJournaliere(2000, 5))).toEqual({
      statut: "Indetermine",
    });
  });

  it("rend Indetermine sur un échantillon vide", () => {
    expect(percentilesForFortnight([])).toEqual({ statut: "Indetermine" });
  });

  it("ordonne les percentiles", () => {
    const r = percentilesForFortnight(anneesJournalieres(30));
    if (r.statut !== "Calcule") throw new Error("attendu Calcule");

    expect(r.p10).toBeLessThanOrEqual(r.p25);
    expect(r.p25).toBeLessThanOrEqual(r.p50);
    expect(r.p50).toBeLessThanOrEqual(r.p75);
    expect(r.p75).toBeLessThanOrEqual(r.p90);
  });

  it("interpole entre deux relevés encadrants", () => {
    // Dix années, une valeur par année, de 1 à 10. La médiane tombe entre
    // 5 et 6 : elle vaut 5,5 et non 5. Un percentile qui « choisit » la valeur
    // basse décalerait tout le classement vers le sec.
    const serie: AnneeQuinzaine[] = Array.from({ length: 10 }, (_, i) => ({
      annee: 2000 + i,
      valeurM3S: cubicMetresPerSecond(i + 1),
    }));
    const r = percentilesForFortnight(serie);
    if (r.statut !== "Calcule") throw new Error("attendu Calcule");

    expect(r.p50).toBe(5.5);
  });

  it("garde un zéro mesuré, qui est un assec et non une absence (BR-007)", () => {
    const serie: AnneeQuinzaine[] = Array.from({ length: 12 }, (_, i) => ({
      annee: 2000 + i,
      valeurM3S: cubicMetresPerSecond(0),
    }));
    const r = percentilesForFortnight(serie);
    if (r.statut !== "Calcule") throw new Error("attendu Calcule");

    expect(r.p10).toBe(0);
    expect(r.p50).toBe(0);
  });
});
