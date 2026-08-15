# 01 — Analyse

> Vérifications d'API réalisées le **2026-07-30** par appels HTTP réels sur les endpoints de production.
> Toute valeur non vérifiée est signalée comme telle. Aucun chiffre n'est estimé.

## 1. Personas, par priorité

| # | Persona | Question qu'il se pose | Donnée qui y répond | Fréquence d'usage |
|---|---|---|---|---|
| P1 | **Citoyen riverain** | « Ma rivière est-elle basse ? Suis-je concerné par des restrictions ? » | ONDE + débit + VigiEau | Ponctuelle, saisonnière (été) |
| P2 | **Agriculteur / irrigant** | « Qu'est-ce qui est interdit sur ma parcelle, aujourd'hui ? » | VigiEau `zones` (profil `exploitation`) + PDF de l'arrêté | Quotidienne en période de crise |
| P3 | **Pêcheur** | « Ce cours d'eau est-il en assec ? Quel est le niveau ? » | ONDE + débit + température (si station) | Hebdomadaire en saison |
| P4 | **Usager de loisir** | « Y a-t-il assez d'eau pour naviguer ? » | Débit + historique | Occasionnelle, avant sortie |
| P5 | **Élu / agent de collectivité** | « Quel est l'état d'ensemble de mon territoire ? » | Vue départementale agrégée | Hebdomadaire |

**P1 et P2 dimensionnent le produit.** P2 est le seul persona dont une décision a des conséquences juridiques — d'où l'avertissement renforcé (`BR-013`).

## 2. Parcours par persona

| Persona | Parcours nominal | Écran d'atterrissage |
|---|---|---|
| P1 | Ouverture → carte centrée sur position → tap marqueur proche → fiche | Carte |
| P2 | Ouverture → onglet Sécheresse → zone géolocalisée → liste des usages restreints → PDF arrêté | Sécheresse |
| P3 | Ouverture → recherche cours d'eau → filtre « à sec / faible » → fiche point ONDE | Carte + filtres |
| P4 | Ouverture → favori station → courbe 30 j → positionnement historique | Détail station |
| P5 | Ouverture → filtre département → vue agrégée → export/partage | Carte filtrée |

## 3. Sources retenues

| Source | Base URL | Rôle | Priorité |
|---|---|---|---|
| Hydrométrie **v2** | `https://hubeau.eaufrance.fr/api/v2/hydrometrie` | Débit et hauteur mesurés | P1 |
| Écoulement ONDE v1 | `https://hubeau.eaufrance.fr/api/v1/ecoulement` | Assecs, écoulement observé | P2 |
| VigiEau | `https://api.vigieau.beta.gouv.fr/api` | Restrictions et arrêtés | P1 |
| data.gouv « Donnée Sécheresse VigiEau » | exports quotidiens CSV/GeoJSON/PMTiles | Repli si l'API VigiEau rompt | P3 |

### 3.1 Endpoints et champs utiles

| Endpoint | Champs exploités | Pagination |
|---|---|---|
| `/v2/hydrometrie/referentiel/stations` | `code_station`, `libelle_station`, `longitude_station`, `latitude_station`, `code_departement`, `libelle_cours_eau`, `en_service` | `page`+`size` |
| `/v2/hydrometrie/observations_tr` | `code_station`, `grandeur_hydro`, `date_obs`, `resultat_obs`, `code_statut`, `libelle_statut`, `code_qualification_obs`, `libelle_qualification_obs` | **`cursor`** |
| `/v2/hydrometrie/obs_elab` | `resultat_obs_elab`, `date_obs_elab`, `grandeur_hydro_elab` (`QmnJ`) | **`cursor`** |
| `/v1/ecoulement/observations` | `code_station`, `libelle_station`, `latitude`, `longitude`, `code_ecoulement`, `libelle_ecoulement`, `date_observation`, `code_campagne`, `libelle_cours_eau` | `page`+`size` |
| `/v1/ecoulement/campagnes` | `code_campagne`, `date_campagne`, `libelle_type_campagne` | `page`+`size` |
| VigiEau `/zones?lat=&lon=&profil=` | `niveauGravite`, `type`, `arrete.dateDebutValidite`, `arrete.cheminFichier`, `usages[]` | — |
| VigiEau `/departements` | `code`, `niveauGraviteSupMax` | — |

## 4. Contraintes d'API — les pièges vérifiés

| # | Contrainte | Impact | Parade |
|---|---|---|---|
| C-01 | **Hydrométrie v1 arrêtée le 05/05/2025.** `/api/v1/hydrometrie/api-docs` → HTTP 403 | Bloquant | Cibler `/api/v2/` exclusivement |
| C-02 | **Débit en litres/seconde, hauteur en millimètres** | Erreur d'un facteur 1000 | Diviser par 1000 dans le mapper, jamais dans la vue. Test unitaire obligatoire |
| C-03 | `observations_tr` : fenêtre glissante **1 mois maximum** | Pas d'historique long ici | Historique via `obs_elab` |
| C-04 | `obs_elab` **n'a pas de paramètre `sort`** — il est ignoré silencieusement et renvoie 1900 | Graphe vide ou aberrant | Toujours passer `date_debut_obs_elab` |
| C-05 | Interroger un **code site** (8 car.) renvoie chaque mesure **en double**, dont une ligne à `code_station = null` | Doublons à l'écran | N'interroger que des **codes station** (10 car.) |
| C-06 | **HTTP 206** = succès partiel, renvoyé dès qu'il reste des résultats | Client qui n'accepte que 200 casse | Traiter 200 **et** 206 comme succès |
| C-07 | `page * size` ≤ **20 000** (HTTP 400 `ValidatePageDepth` au-delà) | Pagination profonde impossible | Segmenter par département ; curseur là où il existe |
| C-08 | `size` ≤ **20 000** (HTTP 400 `ValidatePageSize`) | — | Plafonner côté client |
| C-09 | **Pas de `bbox` ni `distance`** sur `referentiel/stations` et `/sites` | Pas de « stations autour de moi » directe | Précharger le référentiel (6 454 lignes) au premier lancement |
| C-10 | Codes ONDE = **chaînes** (`"1a"`, `"1f"`), libellés de campagne en **minuscules** (`"usuelle"`) | Parsing en entier échoue | Typer en `string`, comparer en minuscules |
| C-11 | `code_methode_obs = 8` (« Calculée ») **existe en production mais pas dans la doc** | `switch` exhaustif lève | Branche `default` obligatoire sur toute nomenclature |
| C-12 | **Aucun quota documenté, aucun header `X-RateLimit-*`** côté Hub'Eau ; CGU en fair-use non chiffré | Risque de blocage à l'échelle | Throttle client, cache agressif, jamais de dump national |
| C-13 | VigiEau : `X-RateLimit-Limit: 300` présent ; **fenêtre non déterminée** | Inconnue | Throttle prudent, backoff sur 429 |
| C-14 | VigiEau `?commune=` → **HTTP 409** si la commune a plusieurs zones | Écran en erreur | Toujours utiliser `lat`/`lon` |
| C-15 | **Aucun SLA.** CGU : mise à disposition « sans garantie sur leur disponibilité » | Indisponibilité normale | Mode dégradé obligatoire, pas optionnel |
| C-16 | VigiEau en **version `0.1`** sur `beta.gouv.fr` | Rupture possible sans préavis | Interface d'abstraction + repli data.gouv |
| C-17 | Paramètre `fields` qualifié d'**expérimental** par la spec | Réponse inattendue | Utilisable pour alléger, avec repli sans `fields` |

## 5. Fraîcheur et couverture — mesurées

| Donnée | Couverture vérifiée | Fraîcheur mesurée |
|---|---|---|
| Stations hydrométriques | **6 454** au total, dont **4 150 en service** au 2026-08-15 *(4 140 au 2026-07-31 — le référentiel bouge lentement mais il bouge)* | Référentiel quasi-statique |
| `observations_tr` | Variable selon la station | Annoncée à 5 min. **Mesurée : 7 min sur une station, 9 jours sur une autre** |
| `obs_elab` (`QmnJ`) | Historique depuis **1900-01-01**, statut « Donnée validée » | **Latence 10 à 11 jours** |
| Stations ONDE | **3 548**, France hexagonale + Corse. **Aucune en DOM** (974 → 0 station) | Publication ~2 jours après observation |
| Campagnes ONDE | Depuis **2012-01-25**, 9 989 campagnes | **~1 par mois, de mai à septembre uniquement** |
| VigiEau | 101 départements | Quotidienne |

> **La fraîcheur du « temps réel » est station-dépendante.** Elle ne peut jamais être supposée : la date de mesure est affichée avec la valeur, sans exception (`BR-001`).

## 6. Sources écartées, avec motif

| Source | Motif |
|---|---|
| **Qualité eau potable** | Décrit l'eau **du robinet après traitement**, par unité de distribution. Afficher « eau conforme » sur une fiche rivière induirait un contresens sur la baignade. Écartée. Réintégrable un jour en écran séparé et explicitement nommé |
| **Qualité des cours d'eau v2** | Latence mesurée ~5 mois entre prélèvement et disponibilité ; paramètres bruts illisibles sans grille SEQ-Eau. Chantier à part entière |
| **Hydrobiologie** | Indices non interprétables sans grille de classes (ex. « Score de la métrique nombre d'espèces rhéophiles », résultat `5.885454`, unité `X`). Fréquence annuelle |
| **État piscicole** | Quelques opérations par station et par décennie. Contenu éditorial, pas un état courant |
| **Indicateurs services publics** | Performance des services d'eau et d'assainissement (prix du m³, rendement réseau). Hors sujet. API en **v0** |
| **Température des cours d'eau** | **Conservée en option, priorité basse.** 869 stations au référentiel mais réseau largement résiduel ; `sort=desc` non fiable ; une date à `2026-11-03` (futur) observée. Pertinente pour P3 uniquement, jamais comme donnée principale |
| **Propluvia** | Remplacé par VigiEau. Ne pas implémenter |

## 7. Licence et attribution

Hub'Eau : **Licence Ouverte Etalab** (version non précisée sur la page des CGU — *non vérifié*), réutilisation commerciale autorisée, **citation de l'auteur obligatoire**.
VigiEau / data.gouv : **Licence Ouverte 2.0**.
→ Écran « À propos » avec attribution explicite des deux sources, plus celle du fond de carte.

## 8. Fond de carte IGN — vérifié à l'exécution

| Fait | Constat | Date |
|---|---|---|
| Tuile WMTS `GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2` en `TILEMATRIXSET=PM` | **HTTP 200**, `image/png`, **256×256**, 80 838 octets | 2026-07-31, reconstaté le **2026-08-15** |
| **`NV-2` — l'URL KVP survit-elle au *templating* de MapLibre ?** | ✅ **OUI.** Le gabarit `…?SERVICE=WMTS&…&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}` est expansé sans que les `?` ni les `&` soient altérés. **Constaté sur émulateur Android : le fond de carte s'affiche.** | **2026-08-15** |

> C'était l'inconnue qui portait tout le fond cartographique. Une URL KVP n'est pas la forme
> `/{z}/{x}/{y}.png` qu'attendent la plupart des styles, et rien ne garantissait *a priori* que
> MapLibre ne réencoderait pas les séparateurs de requête. **Il ne le fait pas.**

**Avertissements observés à l'exécution, tous deux bénins** (relevés par `adb logcat`, 2026-08-15) :

| Message | Nature |
|---|---|
| `MapLibre Native [WARN] [Mbgl-HttpRequest] Request failed due to a permanent error: stream was reset: CANCEL` | MapLibre **annule** les requêtes de tuiles devenues inutiles quand la vue se stabilise. « permanent error » est son vocabulaire interne pour « ne pas rejouer », pas un échec du serveur IGN |
| `Cannot connect to Expo CLI` · `Failed to open DevTools` | Metro n'était pas lancé ; l'application tournait sur le bundle embarqué. Sans effet sur le produit |

⚠️ **Ce qui reste non vérifié :** la tenue de ~4 150 marqueurs sur un Android d'entrée de gamme
(`NV-5`, tâche `M5`). Pour le hors-ligne, voir la section 9 : `M4` a été exécutée, et son résultat
est négatif.

## 9. Pack hors-ligne — exécuté le 2026-08-15, résultat négatif

Environnement : émulateur `sdk_gphone64_x86_64`, **API 36** · `@maplibre/maplibre-react-native@11.3.6`
(**dernière version publiée**) · `expo@57.0.13` · `react-native@0.86.2`.

| Fait | Constat | Date |
|---|---|---|
| **`OfflineManager.createPack` tue le processus** | `SIGABRT` ~0,7 s après la création du pack — `std::regex_error` non rattrapée (« invalid range in a {} expression »), fil `DatabaseFileSource`, dans `libmaplibre.so`. **4 essais sur 4** | **2026-08-15** |
| Le défaut n'est **ni l'IGN ni le raster** | Reproduit avec `https://demotiles.maplibre.org/style.json`, qui est **vectoriel** | **2026-08-15** |
| Le défaut n'est **pas une base corrompue** | Reproduit après `adb shell pm clear`, base vierge | **2026-08-15** |
| `mapStyle` est une **URL**, pas un style sérialisé | Un style sérialisé donne `Unable to parse resourceUrl {"version":8,…`. Côté Android : `OfflineTilePyramidRegionDefinition(styleURL, …)` | **2026-08-15** |
| Une URI **`data:`** n'est pas résolue | La région passe `active` et reste à `tuiles=0`, **sans erreur** — échec silencieux | **2026-08-15** |
| Plafond de tuiles par défaut : **6000** | Le dépasser **interrompt** le téléchargement et laisse un pack tronqué (`MLRNOfflineModule.kt:525`) | **2026-08-15** |

> **`NV-1` n'est ni confirmé, ni infirmé.** Le plantage survient **avant** qu'une seule tuile soit
> téléchargée : on sait que le chemin qui mène au hors-ligne raster plante, on ne sait toujours pas
> si le hors-ligne raster lui-même fonctionne. `NV-3`, `NV-4` et `NV-6` restent bloqués par le même
> défaut — **aucun octet, aucune tuile n'a pu être mesuré**.

**Portée du constat :** un seul environnement, un émulateur `x86_64`. Ni `arm64` réel, ni iOS.
Arbitrage : [`ADR-012`](adr/ADR-012-hors-ligne-cartographique-bloque.md).
