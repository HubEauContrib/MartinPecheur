import { cubicMetresPerSecond } from "@domain/units/quantities";

import { QUINZAINES_PAR_AN } from "../../../tools/percentiles/computePercentiles";
import { groupByFortnight, type ObsElabRow } from "../../../tools/percentiles/groupByFortnight";

/** Ligne réelle, relevée par appel le 2026-08-15 sur `K447001001`. */
const LIGNE_REELLE: ObsElabRow = {
  code_station: "K447001001",
  date_obs_elab: "2025-07-01",
  resultat_obs_elab: 68296,
};

describe("regroupement des relevés obs_elab par quinzaine", () => {
  it("rend toujours 24 quinzaines, même sans données", () => {
    expect(groupByFortnight([])).toHaveLength(QUINZAINES_PAR_AN);
  });

  it("convertit les litres par seconde en mètres cubes par seconde (BR-002, C-02)", () => {
    // 68296 l/s = 68,296 m³/s. Publier 68296 dans l'asset produirait un
    // percentile mille fois trop grand, et donc un classement faux.
    const quinzaines = groupByFortnight([LIGNE_REELLE]);

    expect(quinzaines[12]).toEqual([{ annee: 2025, valeurM3S: cubicMetresPerSecond(68.296) }]);
  });

  it("range chaque relevé dans sa quinzaine calendaire", () => {
    const quinzaines = groupByFortnight([
      { ...LIGNE_REELLE, date_obs_elab: "2025-01-15" },
      { ...LIGNE_REELLE, date_obs_elab: "2025-01-16" },
      { ...LIGNE_REELLE, date_obs_elab: "2025-12-31" },
    ]);

    expect(quinzaines[0]).toHaveLength(1);
    expect(quinzaines[1]).toHaveLength(1);
    expect(quinzaines[23]).toHaveLength(1);
  });

  it("lit l'année de la mesure, pas celle de la production", () => {
    // `date_prod` vaut 2026 sur des relevés de 2025 — la confondre avec la
    // date de mesure ferait compter une seule année là où il y en a trente.
    const quinzaines = groupByFortnight([
      { ...LIGNE_REELLE, date_obs_elab: "1995-07-03" },
      { ...LIGNE_REELLE, date_obs_elab: "2025-07-03" },
    ]);

    expect(quinzaines[12]?.map((r) => r.annee)).toEqual([1995, 2025]);
  });

  it("écarte une absence de mesure sans la transformer en zéro (BR-007)", () => {
    // Un zéro est un assec, un fait mesuré. `null` n'en est pas un.
    const quinzaines = groupByFortnight([
      { ...LIGNE_REELLE, resultat_obs_elab: null },
      { ...LIGNE_REELLE, resultat_obs_elab: 0 },
    ]);

    expect(quinzaines[12]).toEqual([{ annee: 2025, valeurM3S: cubicMetresPerSecond(0) }]);
  });

  it("refuse une date illisible plutôt que de la ranger n'importe où", () => {
    // Dans un script qui tourne des heures sans surveillance, une ligne rangée
    // dans la mauvaise quinzaine ne se verrait jamais.
    expect(() => groupByFortnight([{ ...LIGNE_REELLE, date_obs_elab: "pas-une-date" }])).toThrow(
      /date/i,
    );
  });
});
