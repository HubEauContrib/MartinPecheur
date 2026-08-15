import { cubicMetresPerSecond } from "@domain/units/quantities";

import { buildAsset, DECIMALES, type StationsParQuinzaine } from "../../../tools/percentiles/buildAsset";
import { QUINZAINES_PAR_AN, type AnneeQuinzaine } from "../../../tools/percentiles/computePercentiles";

const GENERE_LE = new Date("2026-08-15T10:00:00Z");

/** `nb` années distinctes, une valeur par année, croissantes depuis `depart`. */
const annees = (nb: number, depart = 1): AnneeQuinzaine[] =>
  Array.from({ length: nb }, (_, i) => ({
    annee: 2000 + i,
    valeurM3S: cubicMetresPerSecond(depart + i),
  }));

/** Une station dont seule la quinzaine `index` est renseignée. */
const stationAvec = (index: number, echantillon: AnneeQuinzaine[]): StationsParQuinzaine =>
  new Map([
    [
      "K447001001",
      Array.from({ length: QUINZAINES_PAR_AN }, (_, i) => (i === index ? echantillon : [])),
    ],
  ]);

describe("asset de percentiles (ADR-003)", () => {
  it("rend 24 quinzaines par station, toujours", () => {
    const asset = buildAsset(stationAvec(0, annees(12)), GENERE_LE);

    expect(asset.stations["K447001001"]).toHaveLength(QUINZAINES_PAR_AN);
  });

  it("écrit null là où BR-004 dit Indetermine, jamais un chiffre inventé", () => {
    // Neuf années : sous le seuil. Le format doit porter l'absence, pas la
    // combler — un percentile inventé serait un faux signal sur une donnée
    // que l'usager traiterait comme une alerte.
    const asset = buildAsset(stationAvec(3, annees(9)), GENERE_LE);

    expect(asset.stations["K447001001"]?.[3]).toBeNull();
    expect(asset.stations["K447001001"]?.[0]).toBeNull();
  });

  it("range les cinq percentiles dans un tableau, pas dans un objet nommé", () => {
    // Sur 4 150 stations × 24 quinzaines, les clés répétées pèseraient plus
    // que les valeurs.
    const quinzaine = buildAsset(stationAvec(5, annees(12)), GENERE_LE).stations["K447001001"]?.[5];

    expect(Array.isArray(quinzaine)).toBe(true);
    expect(quinzaine).toHaveLength(5);
  });

  it("arrondit à la précision réelle de la source", () => {
    // `obs_elab` rend des litres par seconde ENTIERS : convertis, ils ont au
    // plus trois décimales. L'interpolation en fabrique davantage
    // (5,333333333333333) — des chiffres qui n'existent pas dans la mesure et
    // qui gonflent l'asset. Arrondir ici restaure la précision de la source,
    // il ne la dégrade pas.
    expect(DECIMALES).toBe(3);

    const echantillon: AnneeQuinzaine[] = Array.from({ length: 12 }, (_, i) => ({
      annee: 2000 + i,
      valeurM3S: cubicMetresPerSecond(i / 3),
    }));
    const quinzaine = buildAsset(stationAvec(0, echantillon), GENERE_LE).stations["K447001001"]?.[0];

    for (const valeur of quinzaine ?? []) {
      expect(String(valeur)).toMatch(/^\d+(\.\d{1,3})?$/);
    }
  });

  it("date la génération depuis l'horloge reçue, jamais Date.now()", () => {
    // Sans horloge injectée, deux générations du même jeu de données
    // produiraient deux assets différents — et un diff git illisible.
    const asset = buildAsset(stationAvec(0, annees(12)), GENERE_LE);

    expect(asset.genereLe).toBe("2026-08-15T10:00:00.000Z");
  });

  it("porte l'attribution, obligatoire en Licence Ouverte", () => {
    const asset = buildAsset(stationAvec(0, annees(12)), GENERE_LE);

    expect(asset.source).toContain("Hub'Eau");
    expect(asset.licence).toContain("Licence Ouverte");
  });

  it("traite une station sans aucune donnée sans la faire disparaître", () => {
    // Une station absente de l'asset et une station à 24 nulls ne disent pas
    // la même chose. La seconde dit « connue, mais sans historique ».
    const vide: StationsParQuinzaine = new Map([["K447001001", []]]);
    const asset = buildAsset(vide, GENERE_LE);

    expect(asset.stations["K447001001"]).toHaveLength(QUINZAINES_PAR_AN);
    expect(asset.stations["K447001001"]?.every((q) => q === null)).toBe(true);
  });
});
