import { readFileSync } from "node:fs";
import { gzipSync } from "node:zlib";

import { isRetryable, isSuccess } from "../../src/data/http/httpStatus";
import { delayForAttempt } from "../../src/data/http/retry";

import { buildAsset, writeAsset } from "./buildAsset";
import { argument, selectionnerCodes } from "./cli";
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

/**
 * Tentatives par page. Une station perdue est une station **absente de
 * l'asset**, indiscernable au runtime d'une station inconnue : sur une passe de
 * deux heures face à un service sans SLA (`C-15`), un 500 passager ne doit pas
 * coûter une station.
 */
const TENTATIVES_MAX = 4;

const attendre = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

/**
 * Une page d'`obs_elab`, avec les mêmes règles de statut que l'application.
 *
 * ⚠️ **`isSuccess` et `isRetryable` viennent de `data/http`, ils ne sont pas
 * recopiés ici.** Le `status !== 200 && status !== 206` écrit à la main était
 * exactement le piège `C-06` que ce module central existe pour fermer une fois
 * pour toutes. Un `4xx` n'est jamais rejoué : il vient de notre requête.
 */
async function getJson(url: string): Promise<PageObsElab<ObsElabRow>> {
  let derniere = new Error(`Aucune tentative effectuée sur ${url}`);

  for (let tentative = 0; tentative < TENTATIVES_MAX; tentative += 1) {
    if (tentative > 0) await attendre(delayForAttempt(tentative - 1));

    const reponse = await fetch(url);
    if (isSuccess(reponse.status)) {
      return (await reponse.json()) as PageObsElab<ObsElabRow>;
    }

    derniere = new Error(`HTTP ${String(reponse.status)} sur ${url}`);
    if (!isRetryable(reponse.status)) break;
  }

  throw derniere;
}

async function principal(): Promise<void> {
  const limiteBrute = argument(process.argv, "limite");
  const sortie = argument(process.argv, "sortie") ?? "assets/percentiles/reference.json";

  const reference = JSON.parse(
    readFileSync("assets/referentiel/stations.json", "utf8"),
  ) as Reference;
  const tous = reference.features.map((entite) => entite.properties.code_station);
  const codes = selectionnerCodes(tous, limiteBrute);

  const debut = `${String(new Date().getUTCFullYear() - ANNEES_HISTORIQUE)}-01-01`;
  console.log(`Aspiration de ${String(codes.length)} stations depuis ${debut}…`);

  const depart = Date.now();
  const parStation = await fetchAllStations<ObsElabRow>(codes, debut, getJson);

  // ⚠️ **Le regroupement se fait station par station, sous `try`.**
  // `groupByFortnight` lève sur une date illisible — à raison, une ligne rangée
  // dans la mauvaise quinzaine fausserait un percentile publié. Mais lever
  // depuis un `map` global jetait les 4 149 autres stations *après* deux heures
  // d'aspiration, sans que rien ne soit écrit. Une station fautive se perd
  // seule, et se retrouve dans `manquantes`.
  const groupees = new Map<string, readonly (readonly AnneeQuinzaine[])[]>();
  const manquantes: string[] = [];

  for (const code of codes) {
    const lignes = parStation.get(code);
    // `fetchAllStations` omet du résultat toute station en erreur : c'est son
    // contrat, et c'est ici qu'on le rattrape.
    if (lignes === undefined) {
      manquantes.push(code);
      continue;
    }
    try {
      groupees.set(code, groupByFortnight(lignes));
    } catch (erreur) {
      console.error(
        `${code} : regroupement impossible — ${erreur instanceof Error ? erreur.message : String(erreur)}`,
      );
      manquantes.push(code);
    }
  }

  const asset = buildAsset(groupees, new Date());
  writeAsset(asset, sortie);

  const json = JSON.stringify(asset);
  const brut = Buffer.byteLength(json, "utf8");
  const compresse = gzipSync(json).length;
  const stations = Object.keys(asset.stations).length;
  const calculees = Object.values(asset.stations)
    .flat()
    .filter((quinzaine) => quinzaine !== null).length;

  // Des chiffres, pas des impressions. `demandees` et `manquantes` en font
  // partie : sans elles, un asset amputé de trente stations se lisait
  // exactement comme un asset complet.
  console.log(
    [
      `P3 demandees=${String(codes.length)}`,
      `stations=${String(stations)}`,
      `manquantes=${String(manquantes.length)}`,
      `quinzaines_calculees=${String(calculees)}`,
      `quinzaines_indeterminees=${String(stations * 24 - calculees)}`,
      `octets_bruts=${String(brut)}`,
      `octets_gzip=${String(compresse)}`,
      `octets_bruts_par_station=${String(Math.round(brut / Math.max(stations, 1)))}`,
      `octets_gzip_par_station=${String(Math.round(compresse / Math.max(stations, 1)))}`,
      `duree_ms=${String(Date.now() - depart)}`,
    ].join(" "),
  );

  if (manquantes.length > 0) {
    // Sortie non nulle, et l'asset reste écrit : deux heures d'aspiration ne se
    // jettent pas. Mais une station absente de l'asset est indiscernable, au
    // runtime, d'une station inconnue — ce fichier-là ne se commit pas tel quel.
    console.error(
      `\n🚨 ${String(manquantes.length)} station(s) absente(s) de ${sortie} : ${manquantes.join(", ")}`,
    );
    console.error("Asset INCOMPLET — ne pas le commiter. Relancer sur les codes manquants.");
    process.exitCode = 1;
  }
}

principal().catch((erreur: unknown) => {
  console.error(erreur);
  process.exitCode = 1;
});
