import {
  buildOfflinePackOptions,
  LOIR_ET_CHER,
  OFFLINE_MAX_ZOOM,
  OFFLINE_MIN_ZOOM,
  OFFLINE_TILE_COUNT_LIMIT,
} from "@features/map/offlinePackOptions";

const CREE_LE = new Date("2026-08-15T10:00:00Z");
const STYLE_URL = "https://exemple.test/style.json";

describe("emprise du constat M4", () => {
  it("couvre le Loir-et-Cher, qui contient la station K447001001", () => {
    // L'emprise du plan T0. Elle est nommée, pas recopiée à l'appel : le
    // chiffre consigné dans la documentation et celui exécuté sont le même.
    expect(LOIR_ET_CHER).toEqual({ west: 0.6, south: 47.2, east: 2.25, north: 48.1 });
  });

  it("descend jusqu'au zoom 14", () => {
    expect(OFFLINE_MIN_ZOOM).toBe(8);
    expect(OFFLINE_MAX_ZOOM).toBe(14);
  });

  it("relève le plafond de tuiles au-dessus du défaut MapLibre de 6000", () => {
    // Lu dans `MLRNOfflineModule.kt` : dépasser le plafond émet une erreur et
    // interrompt le téléchargement. Le défaut hérité de Mapbox est 6000, et une
    // emprise départementale en raster 256 px l'approche (NV-4). Sans ce
    // relèvement, `M4` mesurerait un pack tronqué et conclurait à tort.
    expect(OFFLINE_TILE_COUNT_LIMIT).toBeGreaterThan(6000);
  });
});

describe("options de pack hors-ligne (API v11)", () => {
  it("range les bornes dans l'ordre attendu par MapLibre", () => {
    // `LngLatBounds` est un quadruplet plat [ouest, sud, est, nord]. Une
    // permutation ne lève aucune erreur : elle télécharge une autre région,
    // ou rien du tout.
    const options = buildOfflinePackOptions(
      LOIR_ET_CHER,
      OFFLINE_MIN_ZOOM,
      OFFLINE_MAX_ZOOM,
      STYLE_URL,
      CREE_LE,
    );

    expect(options.bounds).toEqual([0.6, 47.2, 2.25, 48.1]);
  });

  it("passe les niveaux de zoom demandés", () => {
    const options = buildOfflinePackOptions(LOIR_ET_CHER, 8, 14, STYLE_URL, CREE_LE);

    expect(options.minZoom).toBe(8);
    expect(options.maxZoom).toBe(14);
  });

  it("transmet le style comme URL, pas comme style sérialisé", () => {
    // Constaté à l'exécution le 2026-08-15 : `mapStyle` alimente
    // `OfflineTilePyramidRegionDefinition(styleURL, …)`. Un style sérialisé y
    // produit « Unable to parse resourceUrl {"version":8,… ». Le plan T0
    // écrivait `JSON.stringify(style)` : il avait tort.
    const options = buildOfflinePackOptions(LOIR_ET_CHER, 8, 14, STYLE_URL, CREE_LE);

    expect(options.mapStyle).toBe(STYLE_URL);
  });

  it("refuse un style sérialisé passé à la place d'une URL", () => {
    expect(() =>
      buildOfflinePackOptions(LOIR_ET_CHER, 8, 14, '{"version":8,"sources":{}}', CREE_LE),
    ).toThrow(/URL/i);
  });

  it("refuse une URI data: — MapLibre ne la résout pas", () => {
    // Constaté le 2026-08-15 : avec une URI `data:`, la région passe bien à
    // l'état `active`, mais reste à `tuiles=0` — le style n'est jamais lu.
    // L'échec est silencieux, donc il doit être refusé ici.
    expect(() =>
      buildOfflinePackOptions(
        LOIR_ET_CHER,
        8,
        14,
        "data:application/json;charset=utf-8,%7B%7D",
        CREE_LE,
      ),
    ).toThrow(/data:/i);
  });

  it("accepte les schémas que le file source de MapLibre sait lire", () => {
    for (const url of [
      "https://exemple.test/style.json",
      "http://exemple.test/style.json",
      "file:///data/user/0/fr.martinpecheur.app/files/style.json",
      "asset://style.json",
    ]) {
      expect(buildOfflinePackOptions(LOIR_ET_CHER, 8, 14, url, CREE_LE).mapStyle).toBe(url);
    }
  });

  it("date le pack — l'horloge est un paramètre, jamais Date.now()", () => {
    const options = buildOfflinePackOptions(LOIR_ET_CHER, 8, 14, STYLE_URL, CREE_LE);

    expect(options.metadata).toEqual({
      source: "IGN Géoplateforme",
      creeLe: "2026-08-15T10:00:00.000Z",
    });
  });

  it("refuse une emprise inversée plutôt que de télécharger le vide", () => {
    // Ouest et est intervertis : MapLibre n'échoue pas, il ne télécharge rien.
    // Le constat de M4 conclurait alors à tort que le raster hors-ligne ne
    // fonctionne pas.
    expect(() =>
      buildOfflinePackOptions(
        { west: 2.25, south: 47.2, east: 0.6, north: 48.1 },
        8,
        14,
        STYLE_URL,
        CREE_LE,
      ),
    ).toThrow(/ouest.*est/i);

    expect(() =>
      buildOfflinePackOptions(
        { west: 0.6, south: 48.1, east: 2.25, north: 47.2 },
        8,
        14,
        STYLE_URL,
        CREE_LE,
      ),
    ).toThrow(/sud.*nord/i);
  });

  it("refuse un intervalle de zoom vide", () => {
    expect(() => buildOfflinePackOptions(LOIR_ET_CHER, 14, 8, STYLE_URL, CREE_LE)).toThrow(/zoom/i);
  });

  it("refuse un zoom que la source IGN ne sert pas", () => {
    // La source plafonne à 18. Demander 19 produit un pack sans les tuiles
    // attendues, sans que rien ne le signale.
    expect(() => buildOfflinePackOptions(LOIR_ET_CHER, 8, 19, STYLE_URL, CREE_LE)).toThrow(/18/);
  });
});
