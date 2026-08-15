import { buildHistoryUrl, fetchAllStations } from "../../../tools/percentiles/fetch-history";

describe("URL d'aspiration de l'historique obs_elab", () => {
  const url = buildHistoryUrl("K447001001", "1995-01-01");
  const params = new URL(url).searchParams;

  it("interroge bien obs_elab en v2", () => {
    // L'API v1 est arrêtée depuis le 05/05/2025 et rend 403 (C-01).
    expect(url.startsWith("https://hubeau.eaufrance.fr/api/v2/hydrometrie/obs_elab?")).toBe(true);
  });

  it("borne la fenêtre par date_debut_obs_elab (C-04)", () => {
    // Vérifié par appel réel le 2026-08-15 : sans ce paramètre, la réponse
    // démarre au 1900-01-01. `sort` n'existe pas sur obs_elab, il est ignoré
    // en silence — date_debut_obs_elab est la SEULE façon de borner.
    expect(params.get("date_debut_obs_elab")).toBe("1995-01-01");
  });

  it("demande le débit moyen journalier", () => {
    expect(params.get("grandeur_hydro_elab")).toBe("QmnJ");
  });

  it("ne dépasse pas le plafond de pagination", () => {
    // size=20000 rend HTTP 400 ValidatePageSize (constaté le 2026-07-31).
    expect(Number(params.get("size"))).toBeLessThanOrEqual(10000);
  });

  it("n'interroge qu'un code station à dix caractères (C-05)", () => {
    // Un code site à huit caractères renverrait chaque mesure en double.
    expect(params.get("code_entite")).toHaveLength(10);
  });
});

describe("aspiration de toutes les stations", () => {
  it("suit la pagination par curseur jusqu'à épuisement", async () => {
    const pages: Record<string, { data: number[]; next: string | null }> = {
      "page-1": { data: [1, 2], next: "page-2" },
      "page-2": { data: [3], next: null },
    };
    const getJson = jest.fn(async (url: string) =>
      url.startsWith("page-") ? pages[url]! : pages["page-1"]!,
    );

    const resultat = await fetchAllStations(["K447001001"], "1995-01-01", getJson, async () => {});

    expect(resultat.get("K447001001")).toEqual([1, 2, 3]);
    expect(getJson).toHaveBeenCalledTimes(2);
  });

  it("attend entre deux appels — Hub'Eau n'annonce aucun quota (C-15)", async () => {
    // Sans throttle, aspirer 30 ans sur 4150 stations serait un abus d'un
    // service public gratuit, et rien côté API ne nous arrêterait.
    const attentes: number[] = [];
    const getJson = jest.fn(async () => ({ data: [1], next: null }));

    await fetchAllStations(["K447001001", "K447001002"], "1995-01-01", getJson, async (ms) => {
      attentes.push(ms);
    });

    expect(attentes.length).toBeGreaterThanOrEqual(2);
    expect(attentes.every((ms) => ms >= 1000)).toBe(true);
  });

  it("n'abandonne pas tout le lot quand une station échoue", async () => {
    // 4150 stations : perdre 70 minutes d'aspiration pour une station en
    // erreur serait absurde. On note l'échec et on continue.
    const getJson = jest.fn(async (url: string) => {
      if (url.includes("K447001002")) throw new Error("Hub'Eau a répondu 500");
      return { data: [1], next: null };
    });

    const resultat = await fetchAllStations(
      ["K447001001", "K447001002", "K447001003"],
      "1995-01-01",
      getJson,
      async () => {},
    );

    expect(resultat.get("K447001001")).toEqual([1]);
    expect(resultat.has("K447001002")).toBe(false);
    expect(resultat.get("K447001003")).toEqual([1]);
  });
});
