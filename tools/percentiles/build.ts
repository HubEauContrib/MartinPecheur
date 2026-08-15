import { readFileSync } from "node:fs";
import { gzipSync } from "node:zlib";

import { buildAsset, writeAsset } from "./buildAsset";
import type { AnneeQuinzaine } from "./computePercentiles";
import { fetchAllStations, type PageObsElab } from "./fetch-history";
import { groupByFortnight, type ObsElabRow } from "./groupByFortnight";

/**
 * Chaîne complète de génération de l'asset de percentiles (`ADR-003`) —
 * aspiration, regroupement, calcul, écriture, **mesure**.
 *
 * ```bash
 * npx tsx tools/percentiles/build.ts --limite 25 --sortie echantillon.json
 * npx tsx tools/percentiles/build.ts                   # les 4 150 stations
 * ```
 *
 * ⚠️ **`tsx`, pas `node`.** Le plan T0 écrivait `node --experimental-strip-types`.
 * Node sait bien retirer les types, mais il exécute alors le fichier en **ESM**,
 * où la résolution sans extension n'existe pas : il faudrait écrire
 * `./buildAsset.ts` partout, forme que `ts-jest` refuse de son côté
 * (`allowImportingTsExtensions` exige `noEmit`, et `ts-jest` émet). Les deux
 * contraintes portent sur les mêmes fichiers et sont inconciliables. `tsx`
 * lève l'impasse.
 *
 * ⚠️ **Sans `--limite`, ce script tourne plusieurs heures.** 4 150 stations à
 * un appel par seconde, deux pages chacune. C'est délibéré : Hub'Eau n'annonce
 * ni SLA ni quota chiffré (`C-15`), donc rien ne nous arrêterait — c'est
 * précisément pour cela qu'on s'arrête nous-mêmes.
 */

/** `ADR-003` : trente ans d'historique. */
const ANNEES_HISTORIQUE = 30;

interface Reference {
  readonly features: readonly { readonly properties: { readonly code_station: string } }[];
}

function argument(nom: string): string | undefined {
  const index = process.argv.indexOf(`--${nom}`);
  return index === -1 ? undefined : process.argv[index + 1];
}

async function getJson(url: string): Promise<PageObsElab<ObsElabRow>> {
  const reponse = await fetch(url);
  // 200 ET 206 sont des succès (`C-06`) — constaté à nouveau le 2026-08-15 :
  // une fenêtre de 30 ans rend 206.
  if (reponse.status !== 200 && reponse.status !== 206) {
    throw new Error(`HTTP ${String(reponse.status)} sur ${url}`);
  }
  return (await reponse.json()) as PageObsElab<ObsElabRow>;
}

async function principal(): Promise<void> {
  const limiteBrute = argument("limite");
  const sortie = argument("sortie") ?? "assets/percentiles/reference.json";

  const reference = JSON.parse(
    readFileSync("assets/referentiel/stations.json", "utf8"),
  ) as Reference;
  const tous = reference.features.map((entite) => entite.properties.code_station);

  // ⚠️ Échantillonnage **à pas régulier**, jamais les N premières. Le
  // référentiel est ordonné par code, donc par bassin : les premières stations
  // sont voisines, et mesurer sur elles décrirait un bassin, pas la France.
  const codes =
    limiteBrute === undefined
      ? tous
      : (() => {
          const limite = Math.min(Number(limiteBrute), tous.length);
          const pas = Math.max(Math.floor(tous.length / limite), 1);
          return Array.from({ length: limite }, (_, i) => tous[i * pas]).filter(
            (code): code is string => code !== undefined,
          );
        })();

  const debut = `${String(new Date().getUTCFullYear() - ANNEES_HISTORIQUE)}-01-01`;
  console.log(`Aspiration de ${String(codes.length)} stations depuis ${debut}…`);

  const depart = Date.now();
  const parStation = await fetchAllStations<ObsElabRow>(codes, debut, getJson);

  const groupees = new Map<string, readonly (readonly AnneeQuinzaine[])[]>(
    [...parStation].map(([code, lignes]) => [code, groupByFortnight(lignes)]),
  );

  const asset = buildAsset(groupees, new Date());
  writeAsset(asset, sortie);

  const json = JSON.stringify(asset);
  const brut = Buffer.byteLength(json, "utf8");
  const compresse = gzipSync(json).length;
  const stations = Object.keys(asset.stations).length;
  const calculees = Object.values(asset.stations)
    .flat()
    .filter((quinzaine) => quinzaine !== null).length;

  // Des chiffres, pas des impressions.
  console.log(
    [
      `P3 stations=${String(stations)}`,
      `quinzaines_calculees=${String(calculees)}`,
      `quinzaines_indeterminees=${String(stations * 24 - calculees)}`,
      `octets_bruts=${String(brut)}`,
      `octets_gzip=${String(compresse)}`,
      `octets_bruts_par_station=${String(Math.round(brut / Math.max(stations, 1)))}`,
      `octets_gzip_par_station=${String(Math.round(compresse / Math.max(stations, 1)))}`,
      `duree_ms=${String(Date.now() - depart)}`,
    ].join(" "),
  );
}

principal().catch((erreur: unknown) => {
  console.error(erreur);
  process.exitCode = 1;
});
