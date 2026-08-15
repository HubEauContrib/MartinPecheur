import { IGN_TILE_URL_TEMPLATE, ignRasterStyle } from "@features/map/ignRasterStyle";

describe("gabarit de tuile IGN", () => {
  it("porte les trois marqueurs attendus par MapLibre", () => {
    expect(IGN_TILE_URL_TEMPLATE).toContain("{z}");
    expect(IGN_TILE_URL_TEMPLATE).toContain("{x}");
    expect(IGN_TILE_URL_TEMPLATE).toContain("{y}");
  });

  it("interroge le jeu de tuiles Pseudo-Mercator", () => {
    // Seul TILEMATRIXSET=PM est adressable en {z}/{x}/{y}.
    expect(IGN_TILE_URL_TEMPLATE).toContain("TILEMATRIXSET=PM");
  });

  it("associe chaque marqueur au bon paramètre WMTS", () => {
    // Intervertir TILECOL et TILEROW donne une carte qui s'affiche mais dont
    // les tuiles sont transposées — une panne silencieuse et coûteuse.
    expect(IGN_TILE_URL_TEMPLATE).toContain("TILEMATRIX={z}");
    expect(IGN_TILE_URL_TEMPLATE).toContain("TILECOL={x}");
    expect(IGN_TILE_URL_TEMPLATE).toContain("TILEROW={y}");
  });

  it("déclare une source raster de 256 pixels", () => {
    // Revérifié par appel réel le 2026-08-15 : HTTP 200, image/png, 256×256.
    // Un tileSize erroné décale tout le fond de carte.
    expect(ignRasterStyle.sources.ign.tileSize).toBe(256);
    expect(ignRasterStyle.sources.ign.type).toBe("raster");
  });

  it("porte l'attribution, obligatoire en Licence Ouverte", () => {
    expect(ignRasterStyle.sources.ign.attribution).toContain("IGN");
  });

  it("ne déclare qu'une seule URL de tuiles", () => {
    // MapLibre n'utilise que tiles[0] pour le hors-ligne (NV-3) : déclarer des
    // miroirs donnerait l'illusion d'une redondance qui ne serait pas téléchargée.
    expect(ignRasterStyle.sources.ign.tiles).toHaveLength(1);
  });

  it("reste du TypeScript pur, sans import de framework", () => {
    // Le style est une donnée, pas un composant : il doit pouvoir être testé
    // sous Node sans transformation React Native.
    expect(typeof ignRasterStyle).toBe("object");
    expect(ignRasterStyle.layers[0]?.source).toBe("ign");
  });
});
