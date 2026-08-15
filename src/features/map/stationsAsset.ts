import type { Feature, FeatureCollection, Point } from "geojson";

/**
 * Accès au référentiel figé par `S4` — **4 150 stations, 6 604 249 octets**.
 *
 * ⚠️ **Chargé par `require`, délibérément, et pas par `import`.** Le
 * `tsconfig` d'Expo active `resolveJsonModule` : un `import` ferait inférer à
 * TypeScript le type littéral des 4 150 entités, et `tsc` s'y étranglerait.
 * Le `require` typé explicitement coupe cette inférence — le fichier reste
 * bundlé par Metro exactement de la même façon.
 *
 * ⚠️ **L'extension `.json` n'est pas cosmétique.** Vérifié dans
 * `metro-transform-worker/src/index.js:474` : Metro décide qu'un module est du
 * JSON **uniquement** sur ce suffixe. Renommer ce fichier en `.geojson`
 * casserait le bundle, sans que `tsc` ni les tests le voient.
 *
 * 💭 **Ceci est un dispositif de T0, pas la voie de production.** Embarquer
 * 6,6 Mo dans le bundle et les analyser au démarrage est précisément ce que
 * `NV-5` doit mesurer. En T1, le référentiel viendra de SQLite (`S5`).
 */

/** Propriétés du référentiel réellement utilisées ici. */
export interface StationProperties {
  readonly code_station: string;
  readonly libelle_station?: string;
}

export type StationFeature = Feature<Point, StationProperties>;
export type StationCollection = FeatureCollection<Point, StationProperties>;

// eslint-disable-next-line @typescript-eslint/no-require-imports
export const stationCollection = require("../../../assets/referentiel/stations.json") as StationCollection;

/** Bornes larges du domaine français, DOM compris. Un filet, pas une frontière. */
const BORNES = { ouest: -62, est: 56, sud: -22, nord: 52 } as const;

export interface StationsSummary {
  readonly entites: number;
  readonly codesDistincts: number;
  readonly longueursDeCode: readonly number[];
  readonly sansGeometrie: number;
  readonly nonPonctuelles: number;
  readonly horsBornes: number;
}

/**
 * Fonction **pure** : elle prend la collection en paramètre plutôt que de lire
 * le module. C'est ce qui la rend testable sur des cas construits le jour où
 * une régression apparaîtra.
 *
 * Chacun des compteurs correspond à une panne qui **ne lève aucune erreur** :
 * une géométrie absente, une géométrie non ponctuelle ou des coordonnées
 * interverties produisent une carte qui s'affiche — vide, ou centrée au large
 * de la Somalie.
 */
export function summarizeStations(collection: StationCollection): StationsSummary {
  const codes = new Set<string>();
  const longueurs = new Set<number>();
  let sansGeometrie = 0;
  let nonPonctuelles = 0;
  let horsBornes = 0;

  for (const entite of collection.features) {
    const code = entite.properties.code_station;
    codes.add(code);
    longueurs.add(code.length);

    if (entite.geometry === null || entite.geometry === undefined) {
      sansGeometrie += 1;
      continue;
    }
    if (entite.geometry.type !== "Point") {
      nonPonctuelles += 1;
      continue;
    }

    const [longitude, latitude] = entite.geometry.coordinates;
    if (
      longitude === undefined ||
      latitude === undefined ||
      longitude < BORNES.ouest ||
      longitude > BORNES.est ||
      latitude < BORNES.sud ||
      latitude > BORNES.nord
    ) {
      horsBornes += 1;
    }
  }

  return {
    entites: collection.features.length,
    codesDistincts: codes.size,
    longueursDeCode: [...longueurs].sort((a, b) => a - b),
    sansGeometrie,
    nonPonctuelles,
    horsBornes,
  };
}
