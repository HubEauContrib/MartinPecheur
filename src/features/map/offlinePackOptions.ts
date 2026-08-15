import type { OfflinePackCreateOptions } from "@maplibre/maplibre-react-native";

import { ignRasterStyle } from "./ignRasterStyle";

/**
 * Options d'un pack hors-ligne MapLibre — **du TypeScript pur**.
 *
 * Séparé de `offlinePack.ts` à dessein : ce module ne touche ni au natif ni à
 * React, donc il se teste sous Node dans le projet Jest `unit`. Ce qui reste
 * dans `offlinePack.ts` est l'appel lui-même, qui ne se teste qu'à l'exécution
 * sur appareil — c'est précisément l'objet du constat `M4`.
 *
 * Le type de retour est celui de la bibliothèque, importé en `import type`
 * (effacé à la compilation, donc sans aucun import de framework à l'exécution).
 * Une divergence avec l'API v11 devient une erreur `tsc`, pas une surprise au
 * lancement.
 */

export interface Bounds {
  readonly west: number;
  readonly south: number;
  readonly east: number;
  readonly north: number;
}

/**
 * Emprise du constat `M4` : le Loir-et-Cher, qui contient la station
 * `K447001001` déjà utilisée par les tests de conversion d'unités.
 */
export const LOIR_ET_CHER: Bounds = {
  west: 0.6,
  south: 47.2,
  east: 2.25,
  north: 48.1,
};

/** Plage de zoom du constat. Le volume qu'elle produit est à mesurer (`NV-4`). */
export const OFFLINE_MIN_ZOOM = 8;
export const OFFLINE_MAX_ZOOM = 14;

/**
 * Plafond de tuiles à poser **avant** de créer le pack.
 *
 * Lu dans `MLRNOfflineModule.kt` (`mapboxTileCountLimitExceeded`) : dépasser le
 * plafond n'échoue pas bruyamment — il émet une erreur et **interrompt** le
 * téléchargement, laissant un pack tronqué. Le défaut hérité de Mapbox est
 * 6000, et une emprise départementale en raster 256 px s'en approche (`NV-4`) :
 * une tuile de 256 px en produit quatre là où une vectorielle de 512 px en
 * produit une.
 *
 * Ce plafond n'est donc pas un réglage de confort : sans lui, `M4` mesurerait
 * un pack coupé au milieu et pourrait conclure à tort que `NV-1` est infirmé.
 */
export const OFFLINE_TILE_COUNT_LIMIT = 50_000;

/** Zoom maximal réellement servi par la source IGN déclarée. */
const ZOOM_MAX_SOURCE = ignRasterStyle.sources.ign.maxzoom;

/**
 * Schémas que le *file source* de MapLibre sait résoudre pour un style.
 *
 * ⚠️ `data:` en est volontairement absent. Constaté à l'exécution le
 * 2026-08-15 : avec une URI `data:`, la région passe bien à l'état `active`
 * mais reste à `tuiles=0` — le style n'est jamais lu, et **rien ne le signale**.
 */
const SCHEMAS_RESOLUBLES = ["https://", "http://", "file://", "asset://"];

/**
 * Construit les options de `OfflineManager.createPack`.
 *
 * ⚠️ **Les refus ci-dessous portent le constat.** Aucun d'eux ne fait échouer
 * MapLibre : une emprise inversée, un intervalle de zoom vide, un zoom hors de
 * portée de la source ou un style illisible produisent un pack **vide, sans
 * erreur**. `M4` conclurait alors que le hors-ligne raster ne fonctionne pas,
 * alors que c'est l'appel qui était fautif. Un zéro doit rester interprétable.
 *
 * `createdAt` est un paramètre : la fonction reste pure et son résultat
 * testable à l'octet près.
 */
export function buildOfflinePackOptions(
  bounds: Bounds,
  minZoom: number,
  maxZoom: number,
  styleUrl: string,
  createdAt: Date,
): OfflinePackCreateOptions {
  if (styleUrl.trimStart().startsWith("{")) {
    throw new TypeError(
      "mapStyle attend une URL de style, pas un style sérialisé — " +
        "constaté le 2026-08-15 (« Unable to parse resourceUrl {\"version\":8,… »).",
    );
  }
  if (!SCHEMAS_RESOLUBLES.some((schema) => styleUrl.startsWith(schema))) {
    throw new TypeError(
      `Schéma d'URL de style non résoluble par MapLibre : « ${styleUrl.slice(0, 30)} ». ` +
        `Attendu l'un de ${SCHEMAS_RESOLUBLES.join(", ")}. Une URI data: échoue en silence.`,
    );
  }
  if (bounds.west >= bounds.east) {
    throw new RangeError(
      `Emprise inversée : ouest ${bounds.west} doit être à l'ouest de est ${bounds.east}.`,
    );
  }
  if (bounds.south >= bounds.north) {
    throw new RangeError(
      `Emprise inversée : sud ${bounds.south} doit être au sud de nord ${bounds.north}.`,
    );
  }
  if (minZoom > maxZoom) {
    throw new RangeError(`Intervalle de zoom vide : ${minZoom} → ${maxZoom}.`);
  }
  if (maxZoom > ZOOM_MAX_SOURCE) {
    throw new RangeError(
      `Zoom ${maxZoom} au-delà de la source IGN, qui s'arrête à ${ZOOM_MAX_SOURCE}.`,
    );
  }

  return {
    mapStyle: styleUrl,
    // `LngLatBounds` est un quadruplet plat, dans cet ordre exactement.
    bounds: [bounds.west, bounds.south, bounds.east, bounds.north],
    minZoom,
    maxZoom,
    metadata: { source: "IGN Géoplateforme", creeLe: createdAt.toISOString() },
  };
}
