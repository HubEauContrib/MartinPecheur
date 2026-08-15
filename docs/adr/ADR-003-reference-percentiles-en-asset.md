# ADR-003 — Pré-calculer les percentiles dans un asset embarqué

- **Statut :** Accepté
- **Date :** 2026-07-30

## Contexte

L'ADR-002 impose un positionnement statistique du débit. La matière première existe et elle est excellente : `obs_elab` avec `grandeur_hydro_elab=QmnJ` remonte à **1900-01-01**, en `libelle_statut = "Donnée validée"`, `libelle_methode = "Expertisée"`, `libelle_qualification = "Bonne"`.

Mais Hub'Eau **n'expose aucun percentile**, et le référentiel compte **4 140 stations en service**. Deux contraintes s'opposent :

- calculer sur le téléphone pour toutes les stations est hors de portée, et martèlerait une API sans quota documenté, en fair-use ;
- le périmètre v1 exclut explicitement un backend.

## Décision

Un **script de build, exécuté hors application**, aspire `obs_elab/QmnJ` sur 30 ans pour les stations en service et pré-calcule **P10 / P25 / P50 / P75 / P90 par quinzaine calendaire**. Le résultat est embarqué comme **asset versionné**, livré avec l'application.

Aucun appel réseau au runtime pour cette donnée. **Ce n'est pas un backend** : c'est un artefact de build, versionné comme le code, régénéré à chaque release.

Une station comptant moins de **10 années** de relevés sur la quinzaine considérée est classée **« Indéterminé »**, jamais approximée.

## Conséquences

- ➕ La carte peut être colorée par niveau de débit — impossible avec un calcul à la demande.
- ➕ Aucune charge d'appel supplémentaire sur Hub'Eau depuis la base installée.
- ➕ Fonctionne hors ligne par construction.
- ➖ Coûts détaillés ci-dessous.

| Conséquence négative | Traitement |
|---|---|
| L'asset **vieillit entre deux releases** | Il porte sa date de génération, affichée dans « À propos » |
| Le script de build est un **livrable à maintenir** | Versionné, avec procédure de régénération documentée |
| Poids ajouté au binaire — ~~ordre de grandeur : quelques Mo~~ **Mesuré le 2026-08-15 sur 40 stations réelles : ~2,0 Mo bruts, ~0,73 Mo compressés** (voir ci-dessous) | JSON compact suffit — le format binaire n'est pas nécessaire |
| L'aspiration initiale est longue — **mesurée : ~1,7 s par station, soit ~2 h pour 4 150** | Job hors ligne, throttlé, exécuté rarement |

## Mesure du 2026-08-15 — échantillon réel de 40 stations

Chaîne complète exécutée (`tools/percentiles/build.ts`) sur **40 stations prélevées à pas
régulier** dans le référentiel — jamais les 40 premières, qui se suivent par code et donc par
bassin. Fenêtre : 30 ans, depuis le 1ᵉʳ janvier 1996.

| Mesure | Valeur constatée |
|---|---|
| Octets bruts | **19 155** pour 40 stations, soit **479 par station** |
| Octets gzip | **7 086**, soit **177 par station** |
| Durée d'aspiration | **67,4 s**, soit **1,69 s par station** |

> ⚠️ **Ce qui suit est une extrapolation, pas une mesure.** À 4 150 stations : **≈ 2,0 Mo bruts** et
> **≈ 0,73 Mo compressés**, pour **≈ 2 heures** d'aspiration. Le chiffre définitif demande la
> génération complète, qui n'a pas été lancée.

**Le poids ne pose pas de problème.** Un APK compresse ses assets : moins d'un mégaoctet ajouté au
binaire ne remet pas la décision en cause, et le **format binaire envisagé n'est pas nécessaire**.
Deux choix de format y contribuent, tous deux dans `tools/percentiles/buildAsset.ts` :

- les cinq percentiles sont un **tableau** `[p10, p25, p50, p75, p90]`, pas un objet nommé ;
- les valeurs sont **arrondies à trois décimales**. Ce n'est pas une perte : `obs_elab` rend des
  litres par seconde **entiers**, qui divisés par 1000 (`BR-002`) n'en produisent pas davantage.
  L'interpolation des percentiles, elle, fabriquait des `5.333333333333333` — des chiffres qui
  n'existent dans aucune mesure et qui gonflaient l'asset d'autant.

### 🚨 Ce que la mesure a révélé, et qui n'était pas prévu

| Constat sur l'échantillon | Chiffre |
|---|---|
| Quinzaines **`Indéterminé`** (`BR-004`) | **468 sur 960 — 48,8 %** |
| Stations **sans aucune quinzaine calculable** | **19 sur 40 — 47,5 %** |

Contre-épreuve faite sur une de ces stations, par appel direct : `4000000101` porte **1 336 relevés
`QmnJ` mais seulement 9 années distinctes** (2009–2020). `BR-004` la classe donc correctement, et
la chaîne n'est pas en cause.

> **`Indéterminé` n'est pas un cas limite : c'est près d'une station sur deux.** `ADR-002` fonde le
> positionnement statistique du débit sur cet asset ; pour la moitié des stations, ce
> positionnement **n'existera jamais**, à aucune période de l'année. `BR-004` prévoit l'état et son
> libellé, et la valeur en m³/s reste affichée — mais le cadrage produit n'anticipait pas cette
> proportion. **À porter au commanditaire**, avec `04-ui.md` : un état prévu pour l'exception devient
> l'affichage majoritaire.
>
> ⚠️ Le chiffre porte sur **40 stations**. Il demande confirmation sur la génération complète avant
> d'être traité comme définitif.

## Alternatives écartées

- **Calcul à la demande sur le téléphone** : une station consultée = une requête curseur, mise en cache. Simple, sans outillage. Mais la carte ne peut alors plus être colorée par niveau de débit — seulement par écoulement ONDE et gravité sécheresse. L'écart d'expérience a été jugé supérieur au coût de l'outillage.
- **Backend de calcul** : hors périmètre v1, explicitement exclu au cadrage.

## Si la décision est revue

Bascule vers le calcul à la demande : l'échelle 2 disparaît de la carte et ne subsiste que sur la fiche station. La table `ReferencePercentile` devient un cache alimenté par le réseau au lieu d'un asset en lecture seule. Le contrat de `NiveauDebitCalcule` est inchangé.
