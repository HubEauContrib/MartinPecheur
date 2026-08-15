# Asset de percentiles — régénération

L'asset `assets/percentiles/reference.json` est un **livrable versionné** ([`ADR-003`](../../docs/adr/ADR-003-reference-percentiles-en-asset.md)).
Il n'apparaît pas tout seul : il se régénère par la procédure ci-dessous, et le résultat se commit.

## Régénérer

Un seul point d'entrée. Il enchaîne aspiration, regroupement par quinzaine, calcul, écriture et
**mesure** :

```bash
npx tsx tools/percentiles/build.ts
```

Sur un échantillon, pour vérifier la chaîne sans attendre deux heures — les stations sont prélevées
**à pas régulier** dans le référentiel, jamais les N premières :

```bash
npx tsx tools/percentiles/build.ts --limite 40 --sortie echantillon.json
```

> ⚠️ **`tsx`, et non `node --experimental-strip-types`.** Node sait retirer les types, mais il
> exécute alors le fichier en **ESM**, où la résolution sans extension n'existe pas : il faudrait
> écrire `./buildAsset.ts` partout — forme que `ts-jest` refuse de son côté, car
> `allowImportingTsExtensions` exige `noEmit` et `ts-jest` émet. Les deux contraintes portent sur
> les mêmes fichiers. Constaté le 2026-08-15.

## Chiffres constatés — 2026-08-15

Sur **40 stations réelles**, fenêtre de 30 ans depuis le 1ᵉʳ janvier 1996 :

| Mesure | Constat |
|---|---|
| Durée | **67,4 s**, soit **1,69 s par station** |
| Octets bruts | **19 155**, soit **479 par station** |
| Octets gzip | **7 086**, soit **177 par station** |
| Quinzaines `Indéterminé` | **468 sur 960 — 48,8 %** |
| Stations sans aucune quinzaine calculable | **19 sur 40 — 47,5 %** |

**Extrapolation à 4 150 stations, clairement signalée comme telle :** ≈ 2,0 Mo bruts, ≈ 0,73 Mo
compressés, ≈ 2 heures d'aspiration.

**Date de la dernière génération complète :** *aucune à ce jour.* Seul l'échantillon de 40 stations
a été produit. `assets/percentiles/reference.json` **n'existe pas encore** — le générer demande la
passe complète de ~2 heures.

## Ce que l'asset ne contient pas

Une quinzaine comptant moins de **dix années distinctes** vaut `null`, pas un percentile approché
([`BR-004`](../../docs/br/BR-004-historique-insuffisant-indetermine.md)). **Ne jamais combler ces
trous par interpolation** : ce serait fabriquer une statistique.

⚠️ **Le seuil porte sur les années, pas sur les relevés.** `QmnJ` est un débit **journalier** : une
quinzaine sur dix ans porte environ 150 valeurs. Compter les relevés franchirait le seuil avec neuf
années seulement, sans que rien ne le signale.

## Pièges d'API, tous vérifiés par appel réel

| # | Piège |
|---|---|
| `C-01` | L'API hydrométrie **v1 est arrêtée** — seule la **v2** répond |
| `C-02` | `resultat_obs_elab` est en **litres par seconde**, entier. `68296` = 68,296 m³/s. La conversion vit dans `domain/units/conversions`, une seule fois (`BR-002`) |
| `C-04` | `obs_elab` **n'a pas de `sort`** : il est ignoré en silence et la réponse démarre en 1900. `date_debut_obs_elab` est la seule borne qui fonctionne |
| `C-05` | N'interroger que des **codes station** (10 caractères) — un code site en rend chaque mesure en double |
| `C-06` | **HTTP 206 est un succès.** Constaté à nouveau le 2026-08-15 sur une fenêtre de 30 ans |
| — | `size` plafonne à **10000** ; au-delà, HTTP 400 `ValidatePageSize`. La pagination se fait par curseur `next` |
| `C-15` | **Aucun SLA, aucun quota chiffré.** Le throttle d'une seconde entre deux appels est à nous, pas à l'API. Ne pas le retirer pour aller plus vite |

## Attribution — obligatoire

L'asset est une **œuvre dérivée** de l'historique Hub'Eau, sous **Licence Ouverte Etalab**. La
licence MIT du dépôt ne l'éteint pas. L'écran « À propos » doit porter :

> Source : Hub'Eau — Office français de la biodiversité. Données sous Licence Ouverte.
> Dernière mise à jour : *(date de génération de l'asset, portée par le champ `genereLe`)*.
