/**
 * Fond cartographique IGN Géoplateforme, en WMTS KVP.
 *
 * Vérifié par appel réel le 2026-07-31, **revérifié le 2026-08-15** :
 * HTTP 200, `image/png`, **256×256** sur `TILEMATRIXSET=PM`. `PM` est du
 * Pseudo-Mercator, le seul jeu de tuiles adressable en `{z}/{x}/{y}`.
 *
 * ⚠️ **Reste non vérifié à l'exécution (`NV-2`)** : que MapLibre laisse les `?`
 * et `&` intacts en expansant le gabarit. Une URL KVP n'est pas la forme
 * habituelle `/{z}/{x}/{y}.png` attendue par la plupart des styles. À constater
 * à la première carte affichée : si le fond reste vide, inspecter le trafic
 * réseau avant de soupçonner autre chose.
 *
 * Ce module est **du TypeScript pur** — une donnée de configuration, pas un
 * composant. Il se teste sous Node, sans transformation React Native.
 */

/**
 * Les trois marqueurs sont associés à leur paramètre WMTS et **cet ordre
 * compte** : intervertir `TILECOL` et `TILEROW` produit une carte qui
 * s'affiche, mais transposée. C'est une panne silencieuse.
 */
export const IGN_TILE_URL_TEMPLATE =
  "https://data.geopf.fr/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile" +
  "&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal&TILEMATRIXSET=PM" +
  "&FORMAT=image/png&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}";

/** Taille constatée de la tuile IGN. Une valeur erronée décale tout le fond. */
const TAILLE_TUILE = 256;

export interface RasterSource {
  readonly type: "raster";
  readonly tiles: readonly string[];
  readonly tileSize: number;
  readonly minzoom: number;
  readonly maxzoom: number;
  readonly attribution: string;
}

export interface RasterLayer {
  readonly id: string;
  readonly type: "raster";
  readonly source: string;
}

export interface IgnRasterStyle {
  readonly version: 8;
  readonly sources: { readonly ign: RasterSource };
  readonly layers: readonly RasterLayer[];
}

export const ignRasterStyle: IgnRasterStyle = {
  version: 8,
  sources: {
    ign: {
      type: "raster",
      // Une seule URL : MapLibre ne télécharge hors-ligne que `tiles[0]`
      // (`NV-3`). Déclarer des miroirs donnerait l'illusion d'une redondance
      // qui ne serait jamais téléchargée.
      tiles: [IGN_TILE_URL_TEMPLATE],
      tileSize: TAILLE_TUILE,
      minzoom: 0,
      maxzoom: 18,
      // Obligatoire en Licence Ouverte Etalab. ⚠️ La version exacte (1.0 ou
      // 2.0) n'est pas vérifiée — voir `project-state.md`.
      attribution: "© IGN Géoplateforme — Licence Ouverte",
    },
  },
  layers: [{ id: "ign-fond", type: "raster", source: "ign" }],
};
