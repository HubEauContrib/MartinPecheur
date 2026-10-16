# État du projet

> **Seule source des statuts du projet, réduite à l'état présent.** `CLAUDE.md` n'en garde qu'une ligne
> par tranche et renvoie ici. **Ce que git sait ne se recopie pas ici** : tags (`git tag --list`), PR et
> fusions (`gh pr list --state all`), commits et branches (`git log`, `git branch -a`) ; un hash n'y
> figure que pour dire sur quel code un constat a été fait. L'histoire de ce
> fichier est dans git : `git log -p -- docs/project-state.md`. En cas de contradiction avec le code,
> **le code a raison** — et ce document se corrige dans le même commit.
>
> ✅ implémenté · 🔄 décidé ou en cours · 💭 spéculatif · ⬜ à faire. Un constat garde sa date, sa cible,
> son mode (débogage ou release) et qui l'a fait.

**Mis à jour :** 2026-10-15

## Où on en est

| Tranche | Prouve | Statut |
|---|---|---|
| **Porte de spike** | Fond IGN (`F1`), exécutable Windows autonome (`F3`) | ✅ franchie sur Windows (2026-09-12) — `spike/porte_flutter/COMPTE-RENDU.md` |
| **T0** | Socle Flutter, carte, socle domaine, test d'architecture | ✅ close — `0.1.0` |
| **T1** | Carte, fiches, modal et contrôle « ⚠ Avertissement » | ✅ close — `0.2.0` |
| **T2** | Sécheresse et restrictions (VigiEau) | 🔄 porte non franchie : restent `A1`, `E4`, `P1`, `P2` (25 tâches closes sur 29) — `0.3.0` datée et taguée sans elle, sur décision du commanditaire |
| **T3** | Favoris, filtres, fraîcheur | ✅ close — `0.4.0` ; 50 tâches sur 50, `C1`, `P1`, `P2` comptées closes **en bloc** (décision réversible de la boucle principale) |
| **T4** | Crues : la vigilance Vigicrues sur la carte et dans une fiche tronçon | 🔄 en cours — faits Vigicrues vérifiés par appel réel le 2026-10-14 (`docs/sources/vigicrues.md`, `VC-01` à `VC-13`) ; cadrage approuvé le 2026-10-14 (`docs/superpowers/specs/2026-10-14-cadrage-t4-design.md`, treize arbitrages) ; plan de 28 tâches (`docs/superpowers/plans/2026-10-14-t4-crues-vigicrues.md`) : les tâches de code et de documents sont faites (`T4-X1` comprise), version `0.5.0` ouverte, non datée ; **restent la porte `T4-H1`, `T4-P1`, `T4-P2`, au commanditaire, puis `T4-P3`** ; aucun écran de T4 n'est constaté |
| **T5** | Être prévenu : avis sur les lieux suivis, sans serveur ni compte | 🔄 prévue après T4 (arbitrage du commanditaire du 2026-10-03), non cadrée — dépend des favoris de T3 et du moteur structuré laissé ouvert par `ADR-011` ; notifications en tâche de fond jamais essayées |

**Mise en production : non.** Rien ne part en production sans les quatre avertissements (`BR-012`,
`BR-013` ; l'étiquette est discutée au point 52). Les quatre sont posés dans le code : le modal du premier
lancement, le contrôle « ⚠ Avertissement » de la carte et de chaque fiche, l'encart renforcé en tête de
l'écran des restrictions. Le modal et le contrôle sont constatés à l'écran sur Windows en T1 ; l'encart
renforcé n'est vu qu'« en tête », en débogage sur Windows (2026-10-04), « non repliable » non constaté ;
aucune publication Android (`A⏸3`, `A⏸5`).

## Vérifié au 2026-10-16

Sur le code de `K1b` de T4 (le point 64 figé par test), avec ses documents : `flutter analyze` →
« No issues found! », `flutter test` → « +3973: All tests passed! » (3 961 avant `K1b`, 3 313 au départ de T4).

**Réserve durable sur les polices de mesure.** Quatre fichiers de test mesurent en Roboto, chargée depuis
le SDK Flutter (`FLUTTER_ROOT`) : `map_overlays_phone_test.dart`, `map_sheet_height_test.dart`,
`map_entry_buttons_overlap_test.dart` (ils échouent si la police manque) et
`restrictions_scale_text_test.dart` (ignoré si `FLUTTER_ROOT` manque hors intégration continue). Sous
Windows, Roboto y est enregistrée sous le nom « Segoe UI », un substitut : **Segoe UI réelle n'est jamais
mesurée.**

## Non constaté à l'écran, par tranche

### Transverse

- **Segoe UI réelle** : jamais mesurée (voir plus haut).
- **Lecteur d'écran** : ni Narrateur ni TalkBack n'ont été écoutés, sur aucun écran (point 33).
- **Hors réseau** : une zone de carte jamais chargée n'est pas constatée ; le cache de tuiles n'est
  éprouvé que sur des zones déjà parcourues (2026-09-13). Épreuve hors réseau de T1 conforme en release
  (2026-09-27, `NFR-03`).
- **`launchUrl`** : jamais vu ouvrir un arrêté ni le site public, sur aucune cible ; l'ouverture n'est
  éprouvée que par une fonction de lancement injectée.

### T1

- Tout le reste de T1 est constaté sur Windows (lot 3, modal, contrôle « ⚠ Avertissement », regroupement
  par zone, clavier, porte en release). **Non mesuré** : le coût du parcours de la carte au Tab, en
  release (point 46).

### T2 — code de `0.3.0`

**Constaté le 2026-10-04 par le commanditaire, en débogage sur Windows (code du sommet `ba5d079`)** :
trois puces au lancement, ni bouton ni réticule ; « Restrictions » fait apparaître bouton, indice et
réticule, marqueurs et légende restant ; bouton, appui long ou clic droit ouvrent « Sécheresse et
restrictions », encart en tête ; « ⚠ Avertissement » mène à « D'où vient cette donnée ? », dont la barre
de titre défile à la molette ; zones datées, eaux superficielles d'abord ; adresse de l'arrêté lisible.
La molette de l'écran des restrictions est constatée le 2026-09-29. **Rien en release, rien sur Android ;
aucun exécutable de release de `0.3.0` n'a été construit.**

- **`E4`, étape 4** : point 4 (aucun profil présélectionné, aucun usage avant le choix, puis les usages
  cités) et point 6 (point en mer → phrase d'absence) **manquants** ; point 2 constaté pour « en tête »,
  **réserve** « sans moyen de le replier ».
- **Choix « Restrictions »** : trois puces sur une ligne à 800 × 740 en police réelle ; deux puces allumées
  lisibles sans ambiguïté ; appui long et clic droit **hors mode** (faits, mode non dit) ; mode et échelle
  conservés au retour de l'écran ; Narrateur « Restrictions, bouton, activé / désactivé » ; sur Android, à
  largeur de téléphone, le contrôle « ⚠ Avertissement » atteignable hors mode à 200 %, et ce que le bouton
  recouvre en mode.
- **Écran des sources** : depuis le modal, sans acquitter (retour au modal, case inchangée) ; la fenêtre
  (carte ou fiche) d'où « ⚠ Avertissement » l'a ouvert.
- **Refonte du 2026-09-29** : centrage du bouton, zones et arrêtés en cartes, épingle du point désigné ;
  taille minimale de zone cliente 800 × 740.
- **Comportements** : filtre par profil, absence de zone, échecs nommés, cache de session ; hors réseau ;
  annonce de l'encart renforcé au lecteur d'écran.
- **Dus depuis le 2026-10-06 (revue de T2), sur Windows** : (a) clic droit dans la bande du bouton de
  désignation, à côté du bouton, en mode — il doit atteindre la carte ; (b) clic droit à gauche de
  « ⚠ Avertissement », sur l'échelle débit — idem ; (c) à 800 × 740 et 200 %, la légende de l'échelle débit
  atteinte à la molette, sans barre (387 px à défiler, mesurés par `F10b`, non remesurés depuis
  « Favoris ») ; (d) au retour de l'écran des restrictions, le contenu reste pendant la transition ;
  (e) redimensionner après avoir défilé : position gardée, tête épinglée (repli en largeur sous 792 px) ;
  (f) l'avis « Ce lien n'a pas pu être ouvert… » amené dans le champ à chaque échec, sous la seule carte
  pressée quand arrêté et arrêté-cadre ont la même adresse ; (g) au zoom minimal, flèche Haut répétée :
  arrêt au bord du monde, reprise à la première flèche Bas, le bouton désigne le point sous le réticule ;
  (h) au bord nord, agrandir la fenêtre en hauteur : aucun vide au-delà du monde, un appui long tout en haut
  désigne une latitude ≤ 85,06°.
- **La porte** : `P1` de T2 (exécutable de release de `0.3.0` lancé hors Flutter, sept constats, hors
  réseau) et `P2` de T2 (émulateur Android, au toucher).

### T3 — code de `0.4.0`

**Confirmé en bloc le 2026-10-14 par le commanditaire, sans détail point par point** : `C1` (Windows,
débogage — filtres sur l'écoulement, `a` et `b`) ; `P2` (Android, émulateur `Pixel_7`, débogage —
construction, lancement, « les écrans de T3 fonctionnent au toucher ») ; `P1` (Windows, release lancée hors
Flutter — `P1-c` à `P1-k`, « c'est bon » ; dossier `Release` de 35 Mo, 15 fichiers, `NFR-06` tenu).

- **Non dit** : `P1-m` (réseau coupé : liste « Favoris », échec nommé d'un favori station, étoile pleine
  qui se retire) ; `P2-g` (favoris retrouvés après fermeture et relancement, sur Android) ; `P2-m` (mode
  avion) ; pour `P1-g`, s'il restait un point ONDE à l'écran ; pour `C1`, secteur, catégories, comptes et
  symboles d'une pastille avec et sans filtre, pastille disparue ; `P2-c` à `P2-j` hors `P2-g`, rangés dans
  « au toucher » par la boucle principale ; durée et dernière ligne des constructions, premier écran Android.
- **Mesuré en test pendant T3, à voir à l'écran** : les trois écarts du point 61, acceptés en constat —
  à 360 × 640 et 100 %, l'avis d'absence « écoulement » qui dépasse de 8 px ; à 200 %, la puce
  « Restrictions » coupée (52 % atteignables à 360 × 568, rien à 360 × 540), à éprouver sur Android ; au
  téléphone à 200 %, l'avis de carte vidée coupé au repos et « Effacer les filtres » hors de vue (193 px à
  défiler à 360 × 640) ; à 360 × 300, seul
  « ⚠ Avertissement » en haut, l'échelle ne se change qu'en glissant depuis lui (décision 4) ; fiche et
  bandeau d'attribution bord à bord, fiche qui perd 28 px en mode (`K5`) ; « Favoris » qui dépasse de 12 px
  par le haut de sa fenêtre à 640 × 360 et 600 × 360 ; anneau de focus bleu sur le fond bleu
  d'« Appliquer » ; marque ronde du bouton « Filtres » actif peinte sur l'anneau de focus ; fiche ONDE à
  200 % défilée jusqu'au rappel de rythme, à la molette et au doigt (point 60).
- **Décisions à confirmer à l'écran** : point 62.

### T4 — code de `0.5.0`

**Rien de T4 n'est constaté à l'écran.** Tout est vérifié par test (domaine, données sur fixtures du
2026-10-14, ViewModels, vues, racine de composition) ; l'API Vigicrues n'est jamais appelée par un test,
et les niveaux 2 à 4, jamais publiés le 2026-10-14 (`VC-04`), ne sont éprouvés que par des cas construits.
La capture du README (lecture Crues, Windows, exécutable de release lancé par le commanditaire, 2026-10-15)
n'est **pas** un constat de porte. Dus au commanditaire à la porte (cadrage de T4, § 11) :

- **`a`** — la puce « Vigilance crues » : l'avis de lecture, puis les tronçons tracés, les marqueurs
  effacés ; la légende porte la date et « © VIGICRUES » (Windows et Android) ;
- **`b`** — sous le zoom 9 aucune étiquette « Vert », à partir du zoom 9 une étiquette par tronçon visible,
  lisible sans la couleur, qui suit la carte (les deux) ;
- **`c`** — toucher un trait (tolérance 22 / 24 px) ou une étiquette ouvre la fiche ; Tab atteint les
  étiquettes et Entrée l'ouvre (les deux ; clavier sur Windows) ;
- **`d`** — la fiche : encart en tête, non repliable, citation, date, lien ; le lien ouvre le bulletin dans
  le navigateur (les deux) ;
- **`e`** — la fenêtre « ⚠ Avertissement » porte le texte de crue, sur la carte et sur la fiche (les deux) ;
- **`f`** — réseau coupé avant la première activation : avis d'échec, aucun trait ; réseau rétabli,
  « Réessayer » trace les tronçons (les deux) ;
- **`g`** — carte amenée sur La Réunion : l'avis « secteur sans tronçon » (les deux) ;
- **`h`** — `NFR-01` mesuré sur la lecture Crues, gestes `G1` à `G3`, en `--profile` (sonde `X3`) ; durée
  du premier chargement, décodage compris (Windows) ;
- **`i`** — cibles de 48 au toucher, lecture des étiquettes en taille de téléphone (Android) ;
- **`j`** — si un épisode survient avant la porte : une étiquette « Jaune », « Orange » ou « Rouge » réelle
  et sa fiche.
- **Aussi à voir à l'écran** : la disposition acceptée des puces d'échelle (point 61) et la fiche tronçon
  plus haute que la fiche station (point 64). Mesures de recouvrement de la lecture Crues : en Roboto, pas
  en Segoe UI.

### Android

- **Constaté** : une construction en débogage, lancée sur l'émulateur `Pixel_7` le 2026-10-14 (APK
  `versionName` `0.4.0`, `versionCode` 4), confirmée en bloc par le commanditaire.
- **Non constaté** : aucune construction de release ; aucune sur le code de `0.3.0` (`A1` de T2) ; appareil
  réel (`A⏸4`) ; signature (`A⏸3`) et préversion (`A⏸5`) ; tenue sur entrée de gamme réel (`NV-5`) ;
  ouverture d'un arrêté par `url_launcher` ; TalkBack.

### iOS

- Configuré, **jamais compilé**, faute d'hôte macOS (`NV-W4`, point 7).

## Points ouverts

Les numéros sont ceux d'origine : ils sont cités ailleurs et ne se réutilisent pas.

| # | Sujet | Nature, qui tranche |
|---|---|---|
| 1 | **Stockage local : moteur structuré non tranché.** `shared_preferences` porte la préférence simple et les favoris (`ADR-011`, amendé le 2026-10-12) | Pour la donnée structurée (dernière vue, hors-ligne `US-10`, T5), `drift` reste candidat par défaut ; `sqflite` seul ne couvre pas Windows. Commanditaire, quand un écran en aura besoin |
| 2 | **Trois ADR tranchés sans arbitrage du commanditaire** : `ADR-002` ; `ADR-004` (amendé et en partie arbitré le 2026-09-27) ; `ADR-006` (seul « Non renseigné » arbitré, point 28) | Décisions par défaut, réversibles ; chacune porte sa section « Si la décision est revue ». Commanditaire |
| 3 | **Réduction de périmètre** : la qualité de l'eau, annoncée au cadrage, n'est pas livrée (`ADR-007`) | À porter explicitement auprès du commanditaire |
| 5 bis | 🚨 **`Indéterminé` concerne près d'une station sur deux** : sur l'échantillon du 2026-08-15, 19 stations sur 40 sans aucune quinzaine calculable, 48,8 % des quinzaines ; `ADR-002` fonde le positionnement statistique du débit sur cet asset | Confirmation demandée sur la passe complète (~2 h), **non lancée** ; un échantillon de 200 stations (~6 min) le resserrerait. Commanditaire |
| 6 | **Script Dart de génération des percentiles** (`ADR-003`) ; `assets/percentiles/` n'existe pas | Lot d'outillage à chiffrer ; d'ici là, sur l'échelle « débit », toute station est `Indéterminé` (`BR-004`) |
| 7 | **Hôte macOS** pour construire iOS (`NV-W4`) | Matériel, sans date ; bloque la livraison iOS, pas le développement |
| 9 | **Android** : construction de débogage constatée le 2026-10-14 sur le code de `0.4.0` | Commanditaire : (a) ce que cette construction apporte à `A1` de T2, qui demande le code de `0.3.0` avec `url_launcher` ; `A⏸2` (NDK `28.2.13676358` présent, `ndkVersion = flutter.ndkVersion`) reste 🔄, statut non déplacé ; (b) `adb` ne voit pas le Galaxy A54 réel (`A⏸4` ⏸) ; (c) `NV-5`, tenue sur Android d'entrée de gamme réel, jamais mesurée ; (d) `A⏸3` et `A⏸5` ⏸ ; question du 2026-10-04 sur l'APK de débogage de `0.2.0` (qui l'a lancé, ce qui a été vu) sans réponse, l'artefact étant remplacé |
| 10 | **Hors-ligne de zone** : le `Must` d'`UC-005` et d'`US-10` n'est pas livré ; le cache de tuiles ne sert que les zones déjà parcourues | La question d'`ADR-012` est déplacée, pas résolue : `ADR-013` ne tranche aucune de ses options A, B ou C. Commanditaire |
| 11 | **Bibliothèque de graphes** pour la courbe de débit (`US-11`) : aucune relevée | Question fermée au commanditaire, quand `US-11` entrera dans une tranche |
| 14 | **`Q-01` à `Q-04`** (appel groupé, `bbox`, `fields`, latence de `/v2/hydrometrie`) mesurés une seule fois, le 2026-09-18 (`T-15`) | Pas de campagne répétée. `D5` garde la forme garantie (un appel par station) : l'appel groupé ne garantit pas une mesure par station ; une bascule serait une décision du commanditaire |
| 17 | **Collision de nom public `EnEchec`** entre `lib/domain/observation/station_map_state.dart` et `lib/features/station_sheet/view_model/station_sheet_view_model.dart` (les deux classes existent, vérifié le 2026-10-15) | À préfixer si un fichier doit importer les deux ; les états ONDE et restrictions sont déjà préfixés |
| 20 | **Décisions du plan de T1 jamais validées** : 1 (percentiles hors T1), 2 (état = fraîcheur, sans teinte inventée), 4 et 5 (forme garantie), 6 (aucun framework BDD), 7 (traçabilité à la main), 9 (version d'avertissement datée), 10 (ordre des lots) ; et les décisions du lot 3 du 2026-09-14 : état `Introuvable`, vocabulaire de la colonne « Libellé carte » d'`ADR-006`, préchargement des débits sur l'échelle « débit » seule, halo de marqueur noir, cause technique jamais affichée | À valider par le commanditaire ; 2, 4, 5 et 10 coûtent un réusinage si elles sont revues. (3 est validée le 2026-09-18 ; 8 amendée par lui en 800 × 740) |
| 22 | **Caches résiduels sous `android/` du poste** (≈ 2,5 Go, `du -sh android/` le 2026-10-15), hérités de l'outillage précédent, ignorés par git et inertes pour Flutter | À supprimer par le commanditaire ; ne se committent jamais |
| 25 | **Codes ONDE à espaces** (`T-14`) : les codes à espaces de bord (`" O968 5312 "`) ne se retrouvent sous aucune forme en requête alors qu'ils apparaissent par emprise ; `A721 3011` et `A7213011` : deux points, un doublon ou un recodage ? | Non élucidé. Aucune fusion tant que ce n'est pas établi par appel réel |
| 27 | **L'axe « remplissage » de la pastille de station est pris par la fraîcheur** (`BR-005`) alors que `04-ui.md § 2` le réserve au percentile | Question fermée non posée : l'atténuation de fraîcheur passe-t-elle sur le halo ou sur l'opacité globale quand les percentiles arriveront ? Recommandation : l'opacité globale, halo vérifié à ≥ 3:1 |
| 31 | **Le nom du département est dans l'asset** (`libelle_departement`) mais `Station` ne le porte pas : la fiche station, la fiche ONDE et l'écran « Favoris » écrivent « Département » suivi du code (vérifié le 2026-10-15) | Lacune du mapper, à traiter quand une fiche devra se lire sans connaître les codes INSEE (`harold`) |
| 33 | **Annonces au lecteur d'écran** : marqueurs, avis, encart renforcé, région d'alerte de l'avis de lien, « Restrictions, bouton, activé / désactivé » | Jamais constatées, ni au Narrateur ni à TalkBack ; hors tests automatisés. Commanditaire |
| 42 | **`J543211003`** (Morbihan, projection 26, latitude 35,1) n'est pas une inversion de coordonnées (`C-18`) | Aucune correction inventée ; listée nommément dans `stations_asset_test.dart`. Cause non établie |
| 43 | **Pastilles qui se chevauchent au niveau département** : Île-de-France (75, 92, 93, 94), marqueurs corses sans rattachement dessinés sur la pastille 62 | Écart accepté pour T1 par le commanditaire le 2026-09-23 (`04-ui.md § 3`), non repris depuis ; écartés alors : fusion des pastilles proches, seuil de 9 abaissé |
| 46 | **Coût du parcours au Tab dans la carte** (`K2`) : au zoom 9 en zone dense, 450 à 1 500 marqueurs, ≈ 100 ms par appui en test (débogage), jusqu'à ≈ 900 appuis pour atteindre « ⚠ Avertissement » | Jamais mesuré en release : la mesure `X3` ne parcourt pas la carte au Tab |
| 47 | **Clés de marqueurs en double** sur une fenêtre de plus de 4 096 px de large, au zoom minimal 4 | Cas marginal non traité : la caméra n'est contrainte qu'en latitude. Lu dans le code, non éprouvé par un test de largeur |
| 48 | 🚨 **Constats d'écran de T2**, faits en partie le 2026-10-04 (débogage, Windows) | Dus au commanditaire : liste dans « Non constaté à l'écran », T2 — `E4` (points 4 et 6, réserve du point 2), constats de la désignation et de l'écran des sources, (a) à (h) du 2026-10-06, porte `P1` et `P2` de T2. Un point non fait se note « manquant » ; les tests ne remplacent pas l'écran |
| 49 | **En mode « Restrictions », au téléphone, l'avis recouvre le réticule** (dès 100 % à 360 × 640 ; en mode et carte vide, dans la plupart des cas) | Mesuré en test, en Roboto (« CONSTAT » de `map_overlays_phone_test.dart`), ni corrigé ni accepté. La puce « Restrictions » coupée sur fenêtre courte est acceptée (point 61). Levé par un constat sur appareil et une décision du commanditaire |
| 51 | **Le bouton de retour des écrans pleins** (`BackButton` de `ScreenTitleBar`, `lib/features/shared/screen_layout.dart`) s'annonce « Back » : aucune localisation configurée, `flutter_localizations` absent de `pubspec.yaml` | Commanditaire : ajouter `flutter_localizations` (une dépendance, question fermée) ou un `IconButton` à `tooltip` français (non essayé) ; puis constat au Narrateur |
| 52 | **`BR-012` sert d'étiquette aux quatre avertissements** (`CLAUDE.md`, plan de T2, `04-ui.md`, `context-map.md`, `nfr.md`) alors que son texte ne couvre que le modal du premier lancement ; les emplacements 2 et 3 n'ont de texte de règle que l'amendement du 2026-09-23 de `BR-013` et `04-ui.md § 5` | Commanditaire : étendre `BR-012` par un amendement daté, ou cesser de la citer pour eux |
| 53 | **Phrases d'écran citées par `restrictions.feature` et liées au code par aucun test** : 27 d'après une relecture (chiffre exact non fixé), plus trois phrases « sans eaux superficielles » et le scénario « l'arrêté-cadre liste ses zones » | Dette de test, sans décision : porter ces phrases par des constantes et les ajouter à `acceptance_features_test.dart` |
| 54 | **Licences** : celle de la donnée servie par l'API VigiEau n'est pas établie (`VG-12`) ; la version de la Licence Ouverte pour Hub'Eau n'est écrite nulle part ; `ADR-004` (tableau du contexte) écrit « Licence Ouverte 2.0 (jeu data.gouv associé) » sans le dire | Commanditaire : aligner `ADR-004`. Levé si l'éditeur publie la licence, constaté par appel réel daté |
| 55 | **`android/.kotlin/`**, cache de construction, n'est ignoré par aucune règle (`git check-ignore -v android/.kotlin` vide le 2026-10-15) ; le dossier est vide ce jour, donc absent de `git status` | À ignorer ou à supprimer, par le commanditaire |
| 56 | **`docs/domain-model.md` en retard sur T1** : onze types de `lib/domain/` non décrits (listés dans l'avis d'en-tête du document) ; `domain_model_doc_test.dart` ne les vérifie pas | Dette de documentation : étendre `typesDuDomaine` (test rouge d'abord), décrire chaque type, puis retirer l'avis d'en-tête, qui cite les onze noms et ferait passer le test à vide |
| 57 | **Limites laissées par la revue de T2** | Non annulées au délai : la phase de connexion (DNS, TCP, TLS) et une redirection suivie vers une autre origine (constaté contre des serveurs locaux ; aucune source appelée ne redirige). Doublons non arbitrés : le montage « contrôle accessible » en cinq copies, le câblage « une fermeture par clé » autour de `withCachePolicy` en trois. Caméra : un rechargement par pas pendant un redimensionnement continu au bord du monde (hors de France) ; dézoom vers 4 refusé sur une fenêtre de plus de 4 096 px de haut |
| 59 | **Restes de la seconde relecture de T2** | Avis de lien non ouvert : pour un même lien, l'ordre d'achèvement des ouvertures décide (une réussite tardive efface l'avis d'un échec plus récent), non corrigé ; `map_overlays_phone_test.dart` porte 21 doublons exacts à 800 × 740, suppression à décider ; trou du filet de `R1` à `R3` : indexer les documents par adresse en minuscules ne fait rougir aucun test d'écran ; l'assertion de `openDocument` ne joue pas en release (un appel avec la cible du site public y échouerait en silence), gardée par décision réversible de la boucle principale ; le titre de test « la bande va de 60 à 740 (cible de 44) quand Android (48) la donne de 64 à 736 » cite une valeur d'Android qu'aucun test ne vérifie. Soldés en T3 : la plateforme des tests de widget (`N1` à `N9`, verrou `widget_test_platform_test.dart`), la barre de titre d'écran plein (`B1`), les décisions métier de la vue des restrictions (`R1` à `R3`) |
| 60 | **Fiche plus haute que la carte** — zone des fiches bornée et défilante depuis le 2026-10-13 | **À trancher par le commanditaire** : en mode « Restrictions », une fiche haute masque le bouton de désignation (non construit dans 13 configurations sur 40). Limites : fermeture et étoile défilent avec la fiche ; pas de barre visible au bureau ; l'écart de 8 px défile ; pas de `SafeArea` ; `Tab` peut viser un contrôle hors champ ; ombre rognée ; réserve d'attribution calculée sur la hauteur entière du bandeau quand la colonne du bas défile (non mesuré) ; Roboto chargée trois fois dans les tests. Corrigés en T3 : la racine de composition ramène la fiche en haut à chaque ouverture par `sheetScrollController` (`K4`) — sans contrôleur fourni, la position de défilement survit au changement de fiche, tenu par le CONSTAT G de `map_sheet_height_test.dart` ; la marge basse de la fiche suit la hauteur réelle de l'attribution IGN (`K5`) |
| 61 | **Colonne du bas à cinq boutons** (« Favoris », « Filtres », `+`, `−`, recentrer ; `K3` de T3) : trois écarts acceptés en constat par le commanditaire le 2026-10-14 — (a) à 360 × 640 et 100 %, l'avis d'absence « écoulement » dépasse de 8 px, action entière et atteignable ; (b) à 200 %, la puce « Restrictions », seule sortie du mode, est coupée : 52 % atteignables à 360 × 568, rien à 360 × 540 ; (c) à 360 × 640 et 200 %, l'action de l'avis de carte vidée n'est pas visible au repos (193 px à défiler) | Vérifié par test, en Roboto. À voir à l'écran, au commanditaire : (b) sur Android ; constats `f` (la colonne ne recouvre ni la fiche, ni le bouton de désignation, ni l'attribution, en Segoe UI réelle puis sur Android) et `d` (l'avis de carte vidée et « Effacer les filtres » sans défiler) du cadrage de T3, § 9 — confirmés seulement en bloc par `P1` et `P2`. Mise à jour du 2026-10-15 (arbitrage « accepter la disposition », `L1` de T4) : la troisième puce d'échelle fait passer le sélecteur sur une rangée de plus là où il ne tient pas (390 × 844 à 100 % : 2 rangées au lieu de 1 ; 360 × 640 à 200 % : 4 au lieu de 3 ; « Restrictions » à la ligne à 800 px en police de test) ; ce qui sort de la fenêtre de la colonne du haut s'atteint en la faisant défiler (même écart que l'avis de T3). Mesures figées par test, en Roboto : « Restrictions » atteignable à 80 % au repos à 360 × 640 / 200 %, 100 % après défilement ; puces entières au repos dès 650 px de haut (592 avant) ; sélecteur plus large de 19,75 px à 800 × 740 ; avis d'absence caché au repos à 360 × 640 / 200 % (362, 251, 325 et 251 px à défiler) ; sous la fiche de 320 px hors mode à 360 × 640 / 200 %, « Restrictions » s'atteint après 42 px de défilement. Constat antérieur inchangé : à 360 × 330 / 200 % en mode, « Restrictions » reste inatteignable même en défilant. À constater à l'écran, à la porte |
| 62 | **Constats d'écran de T3 non dits, décisions à confirmer à l'écran** | Commanditaire : constater ou laisser « non vérifié » `P1-m`, `P2-g`, `P2-m` et le détail point par point (« Non constaté à l'écran », T3) ; confirmer les décisions de la boucle principale — l'étoile sous le bouton de fermeture de la fiche, « Appliquer » en couleur d'action principale, la décision 4 (« le haut cède d'abord »), le texte « La liste n'a pas pu être remplacée. » — et le décompte de `C1`, `P1`, `P2` closes en bloc |
| 63 | **En mode « Restrictions », à 360 × 300 et 200 %, la pilule du bouton de désignation recouvre le centre du contrôle « ⚠ Avertissement »** ; le glisser depuis le contrôle n'y est pas possible non plus. Antérieur à T3, tenu par un « CONSTAT » de `map_overlays_phone_test.dart` | Non corrigé ; à trancher par le commanditaire (tâche à part proposée le 2026-10-12). Hors mode, le contrôle reste visible et atteignable à toute taille |
| 64 | **Fiche tronçon plus haute que la fiche station** (`K1` de T4) : elle recouvre des puces d'échelle que la fiche station de Blois laisse atteignables — les quatre à 800 × 740 / 200 % et à 360 × 640 / 100 %, « Vigilance crues » et « Restrictions » à 390 × 844 / 100 % sous « Jaune » (cas construit) ; défiler ne les dégage pas, fermer la fiche oui. Aux six configurations mesurées, un panneau station de même hauteur recouvre exactement les mêmes puces (affirmé par test) : c'est la zone des fiches du point 60. Et le contrôle « ⚠ Avertissement » de la carte passe sous la fiche tronçon à 360 × 640 (100 et 200 %) et à 390 × 844 (200 %) ; la fiche porte le sien, atteignable | **Tranché le 2026-10-16 : accepté en constat** par le commanditaire (« on le fige par test et on le regarde à la porte »), rattaché au point 60. Figé en Roboto par les cas « CONSTAT — K1 de T4 » et « CONSTAT — K1b de T4 » de `map_overlays_phone_test.dart` : les puces recouvertes (comparées à un panneau station de même hauteur), la boîte et le centre du contrôle de la carte par configuration, la sortie (fiche fermée, puces atteignables), le défilement de la colonne (étendue 0, 142, 690 ou 952 selon la taille : aucune puce dégagée). À voir à l'écran, à la porte (`P1`, `P2`) |

## Points clos

- 4 — trois modalités ONDE annoncées au cadrage, six en réalité — clos, date non consignée : corrigé dans la spec (`ADR-006`).
- 5 — poids de l'asset de percentiles — clos le 2026-08-15 : ≈ 2,0 Mo bruts extrapolés, `ADR-003` tenu (confirmation complète : 5 bis).
- 8 — `NV-W3`, fluidité sur Windows — clos le 2026-09-27 : `NFR-01` mesuré en `--profile`, tenu.
- 12 — `gh` dans le bac à sable — clos le 2026-09-27 : dépend du poste, à constater.
- 13 — lot clavier, souris et responsive — clos le 2026-09-23 : lot 5 de T1 fait.
- 15 — YAGNI du lot 1 (`/campagnes`) — clos le 2026-09-14 : code sans appelant retiré.
- 16 — trois amendements du lot 1 de T1 — clos le 2026-09-18 : entérinés par le commanditaire.
- 18 — deux requêtes de `StationSheetViewModel.open()` — clos le 2026-09-14 : hauteur affichée par `U1`.
- 19 — fuseau affiché — clos le 2026-09-23 : heure locale sans suffixe, `H1`.
- 21 — `NV-W6`, rechargement par cran de molette — clos le 2026-09-27 : 5 appels pour 6 crans, sans anti-rebond.
- 23 — six PNG hérités d'Expo — clos le 2026-09-23 : retirés par `X5`.
- 24 — branche de T1 non fusionnée — clos le 2026-09-23 : fusionnée sur `dev`.
- 26 — `Q-05`, `code_ecoulement` nul — clos le 2026-09-14 : rendu `Inconnu(null)`, consigné dans `onde.md` (`T-14 e`).
- 28 — « Non renseigné » contre `ADR-006` — clos le 2026-09-18 : gardé, `ADR-006` amendé.
- 29 — phrase d'absence de l'échelle débit — clos le 2026-09-18 : phrase dédiée dans `BR-007`.
- 30 — tap entre marqueurs superposés — clos le 2026-09-23 : `ADR-015` sous le zoom 9, écart accepté au-delà.
- 32 — source à côté de la valeur (`BR-001`) — clos le 2026-09-23 : valeur, date et source réunies par `W4`.
- 34 — widget partagé entre tranches — clos le 2026-09-18 : `lib/features/shared/`, règle `shared-sans-tranche`.
- 35 — `RestrictionSource` sous `lib/data/` — clos le 2026-09-27 : contrat déplacé sous `lib/domain/restrictions/`.
- 36 — constat d'écran du lot 3 (« Vu aussi ») — clos le 2026-09-22 : quatre sur quatre, libellé « Sélectionnez pour charger ».
- 37 — échec d'écriture de l'acquittement muet — clos le 2026-09-22 : phrase sous le bouton, `W2b`.
- 38 — lien « Relire le détail des sources » du modal — clos le 2026-10-03 : rétabli avec l'écran des sources (`T2-S1`).
- 39 — fiche sans date — clos le 2026-09-23 : pas de phrase datée, jamais inventée.
- 40 — bandeau de carte fermable — clos le 2026-09-23 : remplacé par le point 41.
- 41 — « trop de bandeaux » — clos le 2026-09-23 : un seul contrôle « ⚠ Avertissement », constaté.
- 44 — « Avertissemen… » tronqué — clos le 2026-09-23 : ruban DEBUG, libellé entier en release.
- 45 — légende sur les contrôles de zoom à 800 × 400 — clos le 2026-10-12 : « La légende défile », 800 × 740 gardé.
- 50 — quatre décisions de la boucle principale (T2) — clos le 2026-10-06 : confirmées par le commanditaire.
- 58 — décisions de la boucle principale de la revue de T2 — clos le 2026-10-06 : quatre confirmées, une sans objet.

## Points non vérifiés, assumés comme tels

Une case vide est une case vide, pas un « probablement ».

- **`NV-W4`** — iOS jamais compilé, faute d'hôte macOS. Sans date.
- **`NV-W5` / `NV-5`** — Android : une seule construction constatée, en débogage sur émulateur ; ni appareil
  réel, ni release, ni tenue sur entrée de gamme.
- **`Q-01` à `Q-04`** — mesurés une seule fois, le 2026-09-18 (`T-15`, point 14).
- **Une zone de carte jamais chargée, hors réseau** — non constatée ; aucun bandeau « tuiles manquantes »
  n'existe.
- **`size` de Hub'Eau** — `C-08` dit ≤ 20 000 (`maxPageSize = 20000`, constaté sur `observations_tr`) ; un
  constat du 2026-07-31 sur le référentiel donnait `size=20000` → HTTP 400 `ValidatePageSize`, capture faite
  à `size=10000`. Contradiction non réconciliée, à vérifier par appel réel.
- **La contrainte SDK minimale** de `flutter_map`, `latlong2` et `http` — non affichée sur pub.dev.
- **Licences** — version de la Licence Ouverte pour Hub'Eau (1.0 ou 2.0) ; licence de la donnée servie par
  l'API VigiEau (point 54).
- **VigiEau** — fenêtre du `X-RateLimit-Limit: 300` ; sémantique du paramètre `departement` de
  `/arretes_restrictions` ; `alerte_renforcee` observé dans `/departements` seulement, jamais dans une
  réponse `/zones` ; le `500` de `/api/zones` que le schéma décrit comme déterministe.
- **Transport HTTP** — délais par tentative (20 s Hub'Eau, 10 s VigiEau) vérifiés en temps simulé, jamais
  contre les API réelles ; la composition réelle de `main.dart`, qui ne passe aucun délai, n'est éprouvée
  par aucun test ; `ArgumentError` nue sur une redirection vers un schéma non HTTP ou un statut inférieur à
  100 (serveur local seulement).
- **ONDE** — correspondance entre `nombre_modalite_ecoulement` (4 ou 5) et les codes disponibles ; 💭 date de
  la dernière campagne de 2026 (« plus aucun point ONDE à l'écran avant mai ») non vérifiée par appel réel.
- **T3** — 💭 taille maximale d'une valeur `shared_preferences` et sort d'une écriture interrompue (non
  trouvés dans les paquets, `ADR-011`) ; 💭 qu'un département portant un point ONDE porte aussi une station
  du référentiel embarqué, dont la feuille « Filtres » tire sa liste.
- **Vigicrues** — ce qui n'est pas vérifié (niveaux 2 à 4, panne réelle, rythme de publication, Android,
  `NFR-01`) est tenu dans la section « Non vérifié » de `docs/sources/vigicrues.md`.
- **Tout ce que T2 et T3 ont livré, vu à l'écran** — voir « Non constaté à l'écran ».

## Arbitrages en vigueur sans autre trace

Écrits nulle part ailleurs dans `docs/` ; chacun reste en vigueur.

- **2026-09-13** — pas de briefs de session dans `docs/`.
- **2026-10-06** — confirmées par le commanditaire, par questions fermées, huit décisions de la boucle
  principale (anciens points 50 et 58 ; `04-ui.md`, `UC-002` et la spec de l'écran des restrictions les
  disent encore « à confirmer ») : mesures des surcouches en Roboto, pas en police de test ; mode « Restrictions » conservé
  au retour de l'écran des restrictions ; colonne gauche de la disposition large défilante ; adresse du site
  public en texte sélectionnable sur l'écran des sources ; réponse corrompue pendant le transfert = panne de
  transport rejouable (`SourceInjoignable`) ; `liveRegion` sur les deux avis de lien non ouvert ; colonnes de
  surcouche sans barre de défilement de bureau ; textes « sans eaux superficielles » écrits en place dans la
  vue (écart du point 53).
- **2026-10-06** — la phrase de `BR-007` écrite deux fois (sans eaux superficielles, avec une zone de gravité
  non reconnue) : garder les deux, verrouillées par un test de `restrictions_screen_test.dart`.
- **2026-10-06** — horloge simulée maison (`test/support/simulated_clock.dart`) gardée pour les tests de délai,
  plutôt que déclarer `fake_async` ; aucune bibliothèque ajoutée.
- **2026-10-14** — Flutter 3.47.7 (Dart 3.13.5) gardé et `pubspec.lock` commité tel qu'il le résout ; un poste
  resté en 3.47.4 réécrit ce fichier.
- **2026-10-15** — puces d'échelle (`L1` de T4), question fermée « Accepter la disposition » : la troisième
  puce fait passer le sélecteur sur une rangée de plus là où il ne tient pas, et ce qui sort de la colonne
  du haut s'atteint en la faisant défiler (mesures au point 61). À constater à l'écran à la porte.
- **2026-10-15** — fiches à l'entrée sur la lecture Crues (relecture d'ensemble de T4), question fermée
  « Fiches Crues », réponse « Fermer, et changer d'échelle » : « Entrer sur la lecture Crues ferme les
  fiches station et ONDE. Ouvrir un favori station ou ONDE depuis la lecture Crues passe d'abord sur sa
  lecture (Débit pour une station, Écoulement pour un point ONDE). Cela revoit l'arbitrage 6 de T3 pour ce
  seul cas. » Composé dans `lib/main.dart`, vérifié par `test/main_test.dart` ; décrit dans `04-ui.md`
  (« Fiche tronçon Vigicrues ») et `UC-009` (`A10`). À constater à l'écran à la porte.
- **2026-10-16** — fiche tronçon plus haute que la fiche station (point 64), question fermée « Accepter en
  constat » : « J'accepte en constat le recouvrement des puces et du « ⚠ Avertissement » de la carte par la
  fiche tronçon (point 64) : on le fige par test et on le regarde à la porte. » Figé par les cas « CONSTAT —
  K1 de T4 » et « CONSTAT — K1b de T4 » de `test/features/map/view/map_overlays_phone_test.dart` ; à voir à
  l'écran à la porte (`P1`, `P2`), en Segoe UI et sur l'émulateur.

## Faits sans autre trace

- **Constats d'API du 2026-07-31** (avant la bascule de stack) : `GetCapabilities` du WMTS de l'IGN → HTTP 200,
  `application/xml`, 2,86 Mo ; tuile `TILEMATRIX=5`, `TILEMATRIXSET=PM` → HTTP 200, `image/png`, 256 × 256,
  donc adressable en `{z}/{x}/{y}` ; référentiel Hub'Eau : `size=1` → 206, `size=5000` (≥ 4 140 résultats)
  → 200.
- **Hashes introuvables dans les plans** : les titres de tâches du plan de T0 (fusion en squash), le tableau
  `R1`-`R6` du plan de T0 et le § « Préalable » du plan de T1 citent des commits qu'aucune branche de ce
  clone ne porte ; les plans ne sont pas corrigés.

## Prochaine étape

`T4-X1` est faite : les tâches de code et de documents de T4 sont closes. **Reste la porte de T4, au commanditaire** :
`T4-H1`, `T4-P1` (Windows, exécutable de release lancé hors Flutter) et `T4-P2` (Android, émulateur `Pixel_7`, en
débogage) — les constats `a` à `j` de « Non constaté à l'écran, T4 » et `NFR-01` sur la lecture Crues — ; puis `T4-P3`,
qui date `0.5.0`. Aucune question ouverte sur T4 : la fiche tronçon plus haute que la fiche station (point 64) est
acceptée en constat et figée par test, comme la disposition des puces d'échelle (point 61) ; leurs constats restent dus à l'écran.
**La porte de T2 reste due au commanditaire** (`A1`, `E4`, `P1`, `P2`) ; ce que la porte de T3 n'a pas dit
(point 62) se constate s'il le veut, ou reste « non vérifié ».
