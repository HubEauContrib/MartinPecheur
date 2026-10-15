# 02 — Spécifications

## 1. Arbitrage central — « le débit est-il suffisant ? »

### 1.1 Constat

**Aucune API publique n'expose de seuil de référence par station.** Vérifié le 2026-07-30 :

| Piste | Résultat |
|---|---|
| Hub'Eau hydrométrie v2 | 4 ressources au total (`referentiel/sites`, `referentiel/stations`, `observations_tr`, `obs_elab`). **Aucun seuil, aucun percentile, aucun DOE, aucun DCR** |
| HydroPortail | Calcule module, QMNA5, VCN3 — **aucune API REST publique** (`/api-docs`, `/rest/hydro/stations` → HTTP 404). Export manuel uniquement |
| SANDRE | `referentiels/v1/zar.json` → HTTP 404 |
| VigiEau | Renvoie le **niveau de gravité administratif** par zone, jamais le débit-seuil qui l'a déclenché, et sans rattachement à une station |

Les DOE et DCR sont fixés dans les SDAGE et les arrêtés-cadres préfectoraux, **publiés en PDF non structuré**.

### 1.2 Options examinées

| Option | Faisabilité | Retenue |
|---|---|---|
| **(a)** Comparaison à l'historique de la station (percentiles, même période) | Possible : `obs_elab/QmnJ` remonte à **1900** en données validées. Mais le calcul ne peut pas se faire sur mobile pour 4 140 stations | ✅ **Oui**, sous la forme 1.3 |
| **(b)** Intégration d'une source externe de seuils réglementaires | **Impossible** : la source n'existe pas sous forme exploitable | ❌ Non — pas par choix, par absence de source |
| **(c)** Affichage brut sans qualification, avec contexte historique | Toujours possible | ✅ **Oui**, comme socle et comme repli |

### 1.3 Décision — [`ADR-002`](adr/ADR-002-qualification-du-debit.md)

> **Le produit ne répond jamais à la question « le débit est-il suffisant ? ». Il répond à deux autres questions, qu'il ne mélange jamais.**

| Question posée | Réponse du produit | Nature | Source |
|---|---|---|---|
| « Ce débit est-il **inhabituel pour la saison** ? » | Positionnement en percentile face au même jour calendaire des 30 dernières années | **Statistique** | `obs_elab/QmnJ` pré-agrégé |
| « Qu'est-ce qui est **interdit chez moi** ? » | Niveau de gravité et liste des usages restreints, avec le PDF de l'arrêté | **Réglementaire** | VigiEau |

**Mise en œuvre.** Un script de build, exécuté hors application, aspire `obs_elab/QmnJ` sur 30 ans pour les stations en service et pré-calcule P10/P25/P50/P75/P90 **par quinzaine calendaire**. Le résultat est embarqué comme **asset versionné** avec l'app. Aucun backend au runtime.

**Vocabulaire imposé.** Les mots **« suffisant », « insuffisant », « normal », « bon », « sûr »** sont bannis de toute l'interface pour qualifier un débit. Formulation retenue : *« Débit bas — plus faible que d'habitude à cette période de l'année. »*

### 1.4 Limites de la décision — à porter dans l'interface

| # | Limite | Où elle est dite |
|---|---|---|
| L-01 | Un percentile **n'est pas un seuil réglementaire**. Il ne dit rien de ce qui est autorisé | Sous-texte permanent de l'indicateur |
| L-02 | L'historique inclut des décennies déjà influencées par les prélèvements et les ouvrages. **La référence n'est pas un état naturel** | Écran « D'où vient cette donnée ? » |
| L-03 | Le changement climatique déplace la référence : **un débit « dans la normale » sur 30 ans peut être écologiquement dégradé**. La statistique mesure l'inhabituel, pas le tolérable | Écran « D'où vient cette donnée ? » |
| L-04 | Les stations à historique court sont classées **« Indéterminé »**, jamais approximées. Seuil : **10 années** de données sur la quinzaine considérée | Badge sur la fiche |
| L-05 | L'asset **vieillit entre deux releases**. Il porte sa date de génération, affichée dans « À propos » | À propos |
| L-06 | Aucune donnée ne reflète les **lâchers ou manœuvres de barrages** | Les 4 avertissements |

### 1.5 Décisions connexes

| # | Décision | Motif |
|---|---|---|
| [ADR-004](adr/ADR-004-integration-vigieau.md) | **VigiEau intégré en v1**, derrière une interface d'abstraction, ~~avec repli sur les exports data.gouv~~ **repli data.gouv différé** (Q3-B du cadrage de T2, arbitré par le commanditaire le 2026-09-27 ; `ADR-004` amendé) : une rupture donne un échec nommé et un lien vers le site public | Sans lui, le besoin de P2 et P5 n'est pas couvert. L'API est en `0.1` : le risque est isolé dans une seule couche |
| [ADR-006](adr/ADR-006-onde-quatre-categories.md) | **ONDE affiché en 4 catégories**, la modalité officielle restant visible sur la fiche | Le brief annonçait 3 modalités ; il y en a 6. « Écoulement visible faible » (7 879 observations depuis 2025) est le principal signal précurseur d'assèchement et ne doit pas être fondu dans « visible » |
| [ADR-007](adr/ADR-007-ecarter-qualite-eau.md) | **Qualité de l'eau écartée de la v1** | Voir 01-analyse § 6. Le seul jeu disponible décrit l'eau du robinet |
| [BR-007](br/BR-007-absence-de-donnee-jamais-neutre.md) | **Aucune coloration de marqueur sans donnée.** L'absence est un état affiché, jamais un état neutre | Un marqueur vert par défaut serait un mensonge |

## 2. Règles métier

Chaque règle vit dans son propre fichier sous [`br/`](br/), avec sa justification, ses cas
limites et le test qui la prouve. **Ce tableau est un index, pas la source.**

| # | Règle | Contexte |
|---|---|---|
| [BR-001](br/BR-001-date-de-mesure-obligatoire.md) | Aucune valeur n'est affichée sans sa date de mesure | Transverse |
| [BR-002](br/BR-002-debit-en-metres-cubes-par-seconde.md) | Le débit est affiché en m³/s, la hauteur en mètres | Hydrometrie |
| [BR-003](br/BR-003-jamais-qualifier-un-debit-de-suffisant.md) | Un débit n'est jamais qualifié de « suffisant » | Hydrometrie |
| [BR-004](br/BR-004-historique-insuffisant-indetermine.md) | Historique de moins de 10 ans : « Indéterminé » | Hydrometrie |
| [BR-005](br/BR-005-donnee-perimee-signalee.md) | Une donnée périmée est signalée et atténuée | Hydrometrie · Carte |
| [BR-006](br/BR-006-statut-de-qualification-toujours-affiche.md) | Le statut de qualification est toujours affiché | Hydrometrie |
| [BR-007](br/BR-007-absence-de-donnee-jamais-neutre.md) | L'absence de donnée n'est jamais un état neutre | Carte |
| [BR-008](br/BR-008-une-seule-echelle-a-la-fois.md) | Une seule échelle d'état est active à la fois | Carte |
| [BR-009](br/BR-009-cluster-porte-l-etat-le-plus-severe.md) | Un cluster porte l'état le plus sévère qu'il contient | Carte |
| [BR-010](br/BR-010-age-de-campagne-onde-affiche.md) | L'âge de la campagne ONDE est toujours affiché | Ecoulement |
| [BR-011](br/BR-011-nomenclature-tolerante-a-l-inconnu.md) | Toute nomenclature tolère une valeur inconnue | Transverse |
| [BR-012](br/BR-012-acquittement-au-premier-lancement.md) | Acquittement explicite au premier lancement | Avertissement |
| [BR-013](br/BR-013-avertissement-renforce-sur-ecrans-ressource.md) | Avertissement renforcé sur les écrans de ressource | Avertissement |
| [BR-014](br/BR-014-aucun-verbe-d-instruction.md) | Aucun verbe d'instruction sur un usage de l'eau | Transverse |

Les contraintes purement techniques — codes ONDE en chaînes, HTTP 206 en succès, codes
station plutôt que site — ne sont **pas** des règles métier. Elles figurent au tableau
`C-xx` de [`01-analyse.md § 4`](01-analyse.md).

## 3. User stories — MoSCoW

### Must

| ID | Persona | Story |
|---|---|---|
| US-01 | Tous | Au premier lancement, je vois un avertissement bloquant que je dois **acquitter explicitement** avant d'accéder à l'app |
| US-02 | Tous | Sur la carte, un **bandeau d'avertissement permanent** reste visible à tous les niveaux de zoom · ⚠️ **Amendé le 2026-09-23 (`W3c`, arbitrage du commanditaire)** : un contrôle **« ⚠ Avertissement »** reste présent à tous les niveaux de zoom et ouvre le texte de l'avertissement initial ; plus de bandeau (`04-ui.md § 4-5`) |
| US-03 | P1, P3 | Je vois sur une carte les stations et points d'observation autour de moi, colorés par état |
| US-04 | P1, P3 | En tapant un point ONDE, je vois s'il est **à sec**, avec la **date de la campagne** |
| US-05 | P4 | En tapant une station, je vois le **débit en m³/s** et **l'heure de la mesure** |
| US-06 | Tous | Chaque fiche porte un avertissement sur la nature de la donnée, **avec sa date** |
| US-07 | P2, P5 | Je consulte le **niveau de gravité sécheresse** de ma zone et la **liste des usages restreints** |
| US-08 | P2 | J'accède au **PDF de l'arrêté préfectoral** en vigueur |
| US-09 | P2, P5 | Tout écran sécheresse porte l'**avertissement renforcé** |
| US-10 | Tous | Sans réseau, je retrouve la **dernière carte consultée**, avec l'âge des données affiché |

### Should

| ID | Persona | Story |
|---|---|---|
| US-11 | P4 | Je vois la **courbe d'évolution du débit** sur 7 / 30 / 90 jours · 🔄 **Tranche ultérieure, non nommée** (arbitrage 1 du 2026-10-12, T3 « le titre seul » : le plan de T1 la renvoyait à T3) |
| US-12 | P4 | Je vois si le débit est **inhabituel pour la saison** (percentile), avec ses limites explicitées |
| US-13 | P3, P5 | Je **filtre** par type de donnée, état, département et fraîcheur · ✅ **Codé en T3** ([`UC-007`](use-cases/UC-007-filtrer-la-carte.md), [`filtres.feature`](acceptance/filtres.feature)), vérifié par test, **non constaté à l'écran** (la porte de T3, Windows et Android, est due). ⚠️ **Précisé le 2026-10-12 (cadrage de T3, § 6)** : **« type de donnée » est l'échelle**, choisie par les puces d'échelle ([`BR-008`](br/BR-008-une-seule-echelle-a-la-fois.md)), pas par la feuille « Filtres » ; **les états** portent sur l'écoulement seul (six catégories) — jamais sur un débit ([`BR-003`](br/BR-003-jamais-qualifier-un-debit-de-suffisant.md)) ; **le département** vaut pour les deux échelles ; **la fraîcheur** porte sur le débit seul — Toutes · Moins de 2 h · Moins de 24 h, les bornes de [`BR-005`](br/BR-005-donnee-perimee-signalee.md) —, aucun critère sur l'écoulement, la carte ne montrant que les campagnes des 60 derniers jours ([`BR-010`](br/BR-010-age-de-campagne-onde-affiche.md), arbitrage 5). Un lieu masqué par un filtre n'est pas une absence de donnée ([`BR-007`](br/BR-007-absence-de-donnee-jamais-neutre.md)) |
| US-14 | P1, P3 | J'enregistre des **favoris** et les retrouve en liste · ✅ **Codé en T3** ([`UC-008`](use-cases/UC-008-suivre-un-lieu-en-favori.md), [`favoris.feature`](acceptance/favoris.feature)), vérifié par test, **non constaté à l'écran** (la porte de T3 est due). Une station hydrométrique ou un point ONDE, par l'étoile de sa fiche ; la liste ne montre que l'identité du lieu, **aucune mesure** ; ouvrir un favori ouvre sa fiche, la carte ne bouge pas (arbitrage 6) ; stockage local, sans compte ([`ADR-011`](adr/ADR-011-stockage-local.md), amendé le 2026-10-12) |
| US-15 | P3 | Je consulte l'**historique des campagnes** d'un point ONDE |
| US-16 | Tous | Je recherche une **station ou un cours d'eau** par son nom · 🔄 **Tranche ultérieure, non nommée** (arbitrage 1 du 2026-10-12, T3 « le titre seul ») |
| US-21 | Tous | Je lis sur la carte et dans la fiche d'un tronçon le **niveau de vigilance crues** publié par Vigicrues, daté et attribué · 🔄 **T4** ([UC-009](use-cases/UC-009-consulter-la-vigilance-crues.md), [crues.feature](acceptance/crues.feature)). L'application relaie, elle ne calcule aucun niveau ([BR-015](br/BR-015-relayer-la-vigilance-crues-ne-rien-predire.md)) |

### Could

| ID | Persona | Story |
|---|---|---|
| US-17 | P5 | Je consulte une **vue départementale agrégée** |
| US-18 | P3 | Je vois la **température de l'eau** si une station en mesure à proximité |
| US-19 | Tous | Je **partage** une fiche |
| US-20 | Tous | Je choisis la **zone à télécharger** pour le hors-ligne |

### Won't (v1)

Compte utilisateur · notifications push · prévision ou modélisation hydrologique · qualité de l'eau · backend · alertes personnalisées · saisie d'observations par les usagers.

> ⚠️ **Amendé le 2026-10-03 (arbitrage du commanditaire).** « Alertes personnalisées » quitte
> cette liste pour la tranche **T5** : des avis sur les lieux suivis, portés au besoin par des
> **notifications locales**, sans serveur ni compte. « Notifications push » **y reste** au sens
> d'un envoi par serveur, puisque « backend » y reste. « Prévision ou modélisation
> hydrologique » **y reste** aussi : la tranche **T4** relaie la vigilance crues publiée par
> Vigicrues, citée et attribuée, sans rien prévoir ni déduire d'un débit. « Compte utilisateur »
> y reste.
> 🔄 Tranches prévues, non cadrées en détail :
> [`superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md`](superpowers/specs/2026-10-03-cadrage-t4-t5-crues-design.md).

## 4. Cas limites

| Situation | Détection | Comportement |
|---|---|---|
| **Hors ligne** | `Connectivity.NetworkAccess` | Carte servie depuis le cache, bandeau persistant « Mode hors-ligne — données du JJ/MM à HH:MM », rafraîchissement désactivé |
| **Aucune station dans la zone — échelle écoulement** | Résultat vide sur la bbox, stations ET points ONDE lus (échelle écoulement) | « Il n'y a ni station de mesure ni point d'observation dans le secteur affiché. Ce n'est pas un signe que tout va bien : c'est simplement que personne ne mesure ici. » + action « Élargir la recherche » |
| **Aucune station de mesure dans la zone — échelle débit** | Résultat vide sur la bbox pour les stations, échelle débit active ; l'ONDE n'est pas interrogée (`BR-008`) | « Il n'y a aucune station de mesure dans le secteur affiché. Cela ne dit rien de l'état des cours d'eau : le débit n'est simplement pas mesuré ici. » + action « Élargir la recherche » |
| **Zone hors couverture ONDE** | Aucun point ONDE, et département hors périmètre (DOM) | « Le réseau ONDE ne suit que certains petits cours d'eau de France hexagonale et de Corse. » |
| **Donnée périmée (> 24 h)** | `now - date_obs` | Marqueur atténué, valeur assortie de « Dernière mesure reçue le JJ/MM à HH:MM, il y a N jours. La station n'a rien transmis depuis. » |
| **Hors saison ONDE** | Mois entre octobre et avril | Âge de la campagne affiché systématiquement, état en gris au-delà de 60 jours |
| **Valeur manquante** (`resultat_obs` nul) | Champ nul | « La station n'a pas transmis de valeur pour ce paramètre. Cela arrive lors des pannes, de la maintenance ou du gel. » |
| **Historique insuffisant** | < 10 années sur la quinzaine | Niveau **« Indéterminé »**, jamais d'approximation |
| **Station hors service** | `en_service = 0` | Exclue de la carte ; consultable par recherche directe, signalée comme fermée |
| **Coordonnées absentes ou hors périmètre** | Filtre de mapping | Exclue de la carte |
| **HTTP 409 VigiEau** (commune multi-zones) | Code 409 | Bascule automatique sur `lat`/`lon` |
| **API indisponible** (5xx, délai dépassé) | Après épuisement des tentatives | Message par source : « Le service Hub'Eau n'a pas répondu. » Les autres sources restent affichées. Jamais d'écran blanc |
| **Vigilance crues — Vigicrues injoignable** (T4, `UC-009` A1) | Après épuisement des tentatives | « Vigicrues n'a pas répondu. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. » + action « Réessayer » ; jamais un trait vert par défaut (`BR-007`) |
| **Vigilance crues — réponse refusée ou illisible** (T4, `UC-009` A2) | Refus, racine ou `features` absents, date sans fuseau explicite | « La vigilance publiée par Vigicrues n'a pas pu être lue. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. » + action « Réessayer » |
| **Vigilance crues — entités écartées** (T4, `UC-009` A4) | Entité sans code, nom, territoire ou tracé lisible | « 1 tronçon de vigilance non lisible. » / « N tronçons de vigilance non lisibles. » ; remplace l'avis du secteur sans tronçon |
| **Vigilance crues — secteur sans tronçon** (T4, `UC-009` A5) | Aucun tronçon ne touche l'emprise, aucune entité écartée | « Aucun cours d'eau suivi par Vigicrues dans le secteur affiché. Cela ne dit rien du risque de crue : sur cette carte, Vigicrues ne suit que certains cours d'eau de métropole et de Corse. » |
| **Vigilance crues — premier chargement** (T4, `UC-009` flux nominal) | Carte de vigilance pas encore lue | « Lecture de la vigilance publiée par Vigicrues… Aucun tronçon n'est affiché tant qu'elle n'est pas lue. » |
| **Rupture de contrat VigiEau** | Désérialisation en échec | ~~Repli sur l'export data.gouv en cache ; à défaut, lien externe vers vigieau.gouv.fr~~ **Repli différé (Q3-B, 2026-09-27)** : échec nommé (`ReponseIllisible`), aucun niveau affiché, lien vers vigieau.gouv.fr (`UC-002 A2`) |
| **Nomenclature inconnue** | Code hors énumération | « Non renseigné » (`BR-011`) |
| **Cache plein** | Plafond atteint | Purge LRU des tuiles, jamais des dernières observations connues |
