# Cadrage de la tranche d'ergonomie — une lecture à la fois, des fiches qui ne recouvrent plus la carte

**Date :** 2026-10-17 · **Statut :** ✅ **approuvé par le commanditaire le 2026-10-17** (« Approuvée »), textes d'écran du § 11.2 et décisions réversibles du § 11.3 compris — douze arbitrages reçus le même jour par questions fermées (§ 2), dont deux après la relecture du cadrage par un second agent, corrections intégrées · **Plan :** à écrire · **Branche :** aucune · **Maquette :** canvas « MartinPêcheur — ergonomie échelles, restrictions et fiches » du 2026-10-03, <https://claude.ai/artifact/L7wJpLzh1n9rK62bAdyTrU> (artefact privé du commanditaire ; **une proposition, pas une spécification**) · **Origine :** [cadrage de T5](2026-10-17-cadrage-t5-design.md), arbitrages 16 et 17 · **État vivant :** [`project-state.md`](../../project-state.md)

> Ce document décide du **quoi**, du **pourquoi** et des **frontières** (où vit quoi, au regard d'[`ADR-014`](../../adr/ADR-014-feature-first-mvvm.md)). Il ne fixe ni les tâches, ni les pixels, ni le détail des widgets : le plan vient après, et mesure. Les faits de code sont cités `fichier:ligne`, relevés le 2026-10-17 sur `c22ac0d` par trois agents de lecture (`lib/` et `test/` inchangés à `bc7b34f`, qui n'a touché que des documents) ; ceux que la boucle principale a relus elle-même sont marqués ✔ ; les estimations de hauteur à 200 % viennent d'un calcul de la relecture, **pas d'une mesure**. Les décisions prises sans arbitrage sont au § 11.3, réversibles.
>
> **Vocabulaire du document.** Le **bloc de lecture** est ce que les questions du 2026-10-17 appelaient « carte unique » ou « carte du haut » : le sélecteur, l'en-tête de légende, l'avis et la légende réunis. La **carte visible** est la partie de l'écran où la carte se voit, une fois la fiche posée (§ 5.2). La **fiche du bas** et le **panneau latéral** sont les deux places d'une fiche (§ 6.5).

## 1. But et succès

**Rendre la carte et ses fiches lisibles d'un coup d'œil, sans que rien ne s'y recouvre** : une seule lecture choisie dans un seul sélecteur, sa légende et l'avertissement attachés dessous ; une fiche qui prend sa place au lieu de cacher la carte — sous elle au téléphone, à côté d'elle sur grand écran — et qui se lit par ordre d'importance. La tranche reprend les trois rangées d'ergonomie de la maquette du 2026-10-03 et solde les points d'interface ouverts 49, 51, 60, 61, 63 et 64, **avant T5**, pour que T5 se planifie sur les écrans refaits (arbitrages 16 et 17 du cadrage de T5).

**La tranche est réussie si :**

1. sur Windows et sur Android, la carte porte un **bloc de lecture** unique — sélecteur à quatre entrées, en-tête « Légende · <lecture> » portant « ⚠ Avertissement », avis, légende — et la fiche ne recouvre plus la carte : **panneau latéral** dès 800 px de large, **fiche du bas** en deçà ;
2. aux **quatre tailles garanties** (360 × 640 et 390 × 844 sous Android, 800 × 740 et 1 280 × 720 sous Windows), à 100 % et 200 %, avec ou sans fiche, avec ou sans avis, hors mode et en mode « Restrictions », **rien ne recouvre** le sélecteur, le « ⚠ Avertissement » de la carte, le réticule, le bouton de désignation ni l'entrée « Restrictions » ; là où la place manque, elle se rend **dans l'ordre de repli** de l'arbitrage 11 (§ 5.6) ; en deçà (360 × 300, 640 × 360), « ⚠ Avertissement » et l'entrée « Restrictions » restent atteignables (arbitrage 10) — **points 49, 61, 63, 64** ;
3. les trois fiches gardent leur **en-tête** (nature, « ⚠ Avertissement », étoile, fermeture) quand elles défilent, et les fiches station et ONDE se lisent par ordre d'importance (arbitrage 5) — **point 60** ;
4. le bouton de retour des écrans pleins s'annonce **« Retour »** (arbitrage 8) — **point 51** ;
5. aucun avertissement ne perd sa présence ni son texte ; aucune règle métier n'est assouplie (`BR-001`, `BR-007`, `BR-008` hors écart déjà accepté, `BR-012`, `BR-013`, `BR-015`) ; aucun mot banni n'entre (`BR-003`) ;
6. la suite reste verte et son décompte ne baisse pas (repère : **3 978**, `dev` à `c22ac0d`, constaté le 2026-10-17) ;
7. la porte est franchie **sur Windows et sur Android**, version **`0.6.0`** (arbitrage 9).

## 2. Arbitrages du commanditaire

| # | Date | Question | Réponse |
|---|---|---|---|
| 0 | 2026-10-17 | Où passent la maquette et les points d'interface ouverts ? (cadrage de T5, arbitrages 16 et 17) | **Une seule tranche d'interface, avant T5** ; le plan de T5 est suspendu jusqu'à elle ; elle regroupe les trois rangées d'ergonomie de la maquette et les points 49, 51, 60, 61, 63, 64 |
| 1 | 2026-10-17 | Rangée 1 : un bloc unique en tête de la carte ? | **« Carte unique »** : sélecteur à quatre entrées, chacune avec titre et sous-titre — 2 × 2 au téléphone, une rangée quand il tient ; « Restrictions » reste un **interrupteur** (arbitrage du 2026-10-03) ; puis l'en-tête « Légende · <lecture> » qui porte « ⚠ Avertissement » ; puis l'avis éventuel et la légende. **Remplace** l'ordre arbitré le 2026-10-03 sous 600 px (avertissement, puces, avis, légende) et les deux colonnes au-delà (`04-ui.md` § 1) |
| 2 | 2026-10-17 | Où vont « Favoris », « Filtres » et le zoom, que la maquette (antérieure à T3) ne place pas ? | **« Rangée au téléphone »** : sous 600 px, une rangée en bas de la carte — « Favoris », « Filtres » à gauche ; −, +, recentrer à droite ; l'attribution dessous ; à partir de 600 px, la colonne actuelle. **Revoit** l'arbitrage du 2026-10-14 (« la place ne change pas ») |
| 3 | 2026-10-17 | Au téléphone, la fiche prend-elle sa place au lieu de recouvrir la carte ? | **« La fiche pousse la carte »** : la carte se réduit au-dessus de la fiche sans descendre sous une bande minimale ; la fiche ne recouvre jamais le bloc de lecture (points 60 et 64) ; son **en-tête est épinglé** — nature et code, « ⚠ Avertissement », étoile, fermeture —, le reste défile |
| 4 | 2026-10-17 | Rangée 3 : à partir de quand la fiche passe-t-elle en panneau latéral ? | **« Dès 800 px »**, par la largeur, **toutes plateformes** : toute fenêtre Windows (largeur minimale 800), une tablette Android en paysage ; panneau de **380 px** à droite, sur toute la hauteur, la carte à sa gauche ; en deçà, la fiche du bas |
| 5 | 2026-10-17 | Rangée 2 : quel contenu pour les fiches hiérarchisées ? | **« Hiérarchie sans position »** : en-tête « nature · code » ; titre ; « cours d'eau · Département NN » ; station : **Débit** mis en avant avec sa date et sa source, puis **Hauteur**, puis « Statut (Hub'Eau) », « Qualification (Hub'Eau) » ; ONDE : catégorie mise en avant avec son symbole de légende, historique à symboles. **Sans** le bloc « Indéterminé » de la maquette, qui attend les percentiles (point 6) |
| 6 | 2026-10-17 | Les passerelles de pied de fiche « Écoulement observé autour », « Débit mesuré autour » (proposées le 2026-10-03, non arbitrées) ? | **« Non »** : le sélecteur change de lecture en un geste. Aucune entrée vers les restrictions depuis une fiche, de toute façon (Q1 de T2, maintenue le 2026-10-03) |
| 7 | 2026-10-17 | L'écran « Sécheresse et restrictions » (planche Restrictions-Lieu) change-t-il ? | **« Inchangé »** : l'écran de T2, arbitré question par question (Q-1 à Q-8) et dont la porte reste due, ne bouge pas ; seule sa barre de titre change (point 51) |
| 8 | 2026-10-17 | Point 51 : comment franciser le bouton de retour ? | **« `flutter_localizations` »**, paquet du SDK Flutter, locale `fr` : « Retour », et tous les textes intégrés de Material en français (menu du texte sélectionnable compris) |
| 9 | 2026-10-17 | Nom, version et porte de la tranche | **« Ergonomie », `0.6.0`, deux cibles** : nom sans numéro (T5 garde le sien) ; **T5 passe à `0.7.0`** ; porte comme T3 et T4 — exécutable de release Windows lancé hors Flutter, émulateur `Pixel_7` en débogage |
| 10 | 2026-10-17 | Critère de clôture des points 49, 61, 63 et 64 | **« Quatre tailles, rien recouvert »** : à 360 × 640 et 390 × 844 (Android), 800 × 740 et 1 280 × 720 (Windows), à 100 % et 200 %, rien ne recouvre le sélecteur, « ⚠ Avertissement », le réticule, le bouton de désignation ni la sortie du mode ; le réticule est au centre de la carte visible, le bouton désigne le point dessous. En deçà (360 × 300, 640 × 360) : le bloc défile, « ⚠ Avertissement » et la sortie du mode restent atteignables |
| 11 | 2026-10-17 | Relecture du cadrage : à 360 × 640 et 200 %, en mode, tout ne tient pas (estimation, non mesurée). Dans quel ordre la place se rend-elle ? | **« Replis dans l'ordre »** : mesure au premier lot de code ; puis, là seulement où la place manque : 1. la légende défile ; 2. le corps de la fiche ; 3. l'avis (action atteignable en défilant, comme accepté le 2026-10-14) ; 4. les sous-titres du sélecteur s'effacent (l'annonce les garde) ; 5. l'indice sous le bouton s'efface ; 6. au téléphone, en mode, une fiche ouverte retire bouton et réticule jusqu'à sa fermeture (l'appui long désigne toujours). **Ne cèdent jamais** : titres du sélecteur, en-tête avec « ⚠ Avertissement », en-tête de fiche. Un écart restant : arrêt et question |
| 12 | 2026-10-17 | Relecture du cadrage : quand une fiche s'ouvre, que fait la carte ? | **« Elle ne bouge pas »** : la partie visible se réduit, le contenu reste en place ; un lieu tombé sous la fiche y reste, comme aujourd'hui ; aucun déplacement, donc aucun rechargement ; recentrer, zoomer et cadrer une pastille tiennent compte de la partie cachée |
| 13 | 2026-10-18 | Mesure de la porte `S6` (Roboto) : à 360 × 640 et texte à 200 %, il manque de 17 à 134 px quand une fiche est ouverte ou en mode — les titres du sélecteur passent sur une colonne (248 px) | **« Le bloc défile »** : à cette taille et cette échelle seulement, là où l'ordre de repli ne suffit pas, la partie fixe du bloc défile comme en deçà (arbitrage 10) ; « ⚠ Avertissement » et « Restrictions » restent atteignables en glissant, à la molette ou au clavier. Aucun nouveau repli ; les autres tailles et échelles restent garanties sans débordement |
| 14 | 2026-10-18 | Mesure de la porte `S6` : à 800 × 740 et texte à 200 %, en mode, fiche ouverte en panneau, la bande du bouton n'a pas de place à côté de la colonne du bas (−8 px) | **« Étendre le repli 6 »** : à toute largeur, en mode, une fiche ouverte retire la bande du bouton et le réticule jusqu'à sa fermeture quand la bande ne tient pas à côté de la colonne ; au téléphone, le repli 6 joue toujours quand la hauteur manque |
| 15 | 2026-10-18 | Relecture de `D1` : en mode, fiche du bas ouverte, quand un avis paraît, le corps de la fiche cède (repli 2 avant le 3) et le réticule descend de 7 à 137 px — l'ordre de l'arbitrage 11 contredit § 5.5 (« le réticule ne bouge pas quand un avis paraît ») | **« Le réticule reste fixe »** : en mode, bande du réticule posée et fiche du bas ouverte, l'avis défile avant le corps de la fiche (ordre 1, 3, 2 dans ce seul cas) ; la fiche ne dépend plus de l'avis, le point visé ne saute jamais. Partout ailleurs, l'ordre 1, 2, 3 reste |
| 16 | 2026-10-18 | Relecture de `D1` : pour tenir le réticule fixe (arbitrage 15), l'avis tombe à 0 px dans 21 répartitions (360 × 640 et 390 × 844 à 100 %, 390 × 844 à 200 %) ; son action « Élargir la recherche » n'est plus atteignable | **« Accepter »** : en mode, fiche du bas ouverte, quand la place manque, l'avis s'efface ; il revient dès que la fiche se ferme. Aucune hauteur garantie ne change. L'acceptation du 2026-10-14 (« action atteignable en défilant ») ne vaut pas dans ce cas |
| 17 | 2026-10-18 | Relecture de `D5` : au téléphone à 200 %, une fiche du bas ouverte se réduit souvent à son en-tête — corps à 0 px dans 63 configurations (station et tronçon, 360 × 640 et 390 × 844), le débit et « Lire le bulletin » illisibles | **« Sous-titres et indice d'abord »** : fiche du bas ouverte, les sous-titres du sélecteur (repli 4) et l'indice sous le bouton (repli 5) cèdent AVANT le corps de la fiche (repli 2). Hors mode : 1, 4, 2, 3 ; en mode (arbitrage 15) : 1, 3, 4, 5, 2 ; le repli 6 reste le dernier. Sans fiche du bas, l'ordre ne change pas |

## 3. Périmètre

### Dedans

| # | Élément | Source |
|---|---|---|
| D1 | **Bloc de lecture** : sélecteur à quatre entrées (trois lectures et l'interrupteur « Restrictions »), en-tête « Légende · <lecture> » avec « ⚠ Avertissement », avis, légende ; borné, il défile | arbitrage 1 ; rangée 1 |
| D2 | **Bas de la carte** : rangée sous 600 px (« Favoris », « Filtres », −, +, recentrer, attribution dessous) ; colonne à partir de 600 px | arbitrage 2 ; point 61 |
| D3 | **Carte visible et réticule** : en mode « Restrictions », le réticule se pose au centre de la carte visible, entre la partie fixe du bloc et la bande du bouton, que rien ne recouvre ; le bouton désigne le point sous lui ; + et − zooment autour de lui ; la bande du bouton ne recouvre jamais le bloc (§ 5.5) | arbitrages 10, 11 ; points 49, 63 |
| D4 | **Fiche du bas** (sous 800 px) : la fiche prend sa hauteur sur la carte visible, jusqu'à une bande minimale ; elle ne recouvre jamais le bloc de lecture ; la carte ne bouge pas | arbitrages 3, 12 ; points 60, 64 ; rangée 2 |
| D5 | **Panneau latéral** (dès 800 px) : la fiche à droite, 380 px, toute la hauteur ; la carte visible à sa gauche, bloc et colonne compris | arbitrage 4 ; rangée 3 |
| D6 | **Cadre commun des trois fiches** : en-tête épinglé (nature, et code pour une station ; « ⚠ Avertissement » ; étoile quand la fiche en porte une ; fermeture), corps défilant ; une fiche s'ouvre toujours par le haut | arbitrages 3, 5 ; point 60 |
| D7 | **Hiérarchie des fiches station et ONDE** ; fiche tronçon : cadre seul, contenu de T4 inchangé | arbitrage 5 ; rangée 2 |
| D8 | **Localisation française** de Material : `flutter_localizations`, locale `fr` | arbitrage 8 ; point 51 |
| D9 | **Mesures et replis** : mesure des pièces aux quatre tailles au premier lot de code ; ordre de repli (§ 5.6) ; les invariants du critère 2 (§ 1) remplacent les « CONSTAT » de l'ancienne disposition | arbitrages 10, 11 ; points 49, 61, 63, 64 |
| D10 | **Documents** (§ 13) | règle du projet |
| D11 | **Porte** sur Windows et Android, version `0.6.0` | arbitrage 9 |

### Dehors

| Élément | Vers | Motif |
|---|---|---|
| Passerelles « Écoulement observé autour » / « Débit mesuré autour » | non prévu | arbitrage 6 |
| Position statistique dans la fiche station (« Indéterminé · relatif à l'historique ») | avec les percentiles | arbitrage 5 ; point 6 (`assets/percentiles/` n'existe pas) |
| Écran « Sécheresse et restrictions », hors sa barre de titre | non prévu | arbitrage 7 ; sa porte (T2) reste due |
| Contenu et ordre de la fiche tronçon | T4, arbitré | seul le cadre change (D6) |
| Rangée « Crues » de la maquette (Crues-Carte, Crues-Fiche-Tronçon, Crues-Me-Prévenir, Crues-Avis-Reçus) | T4 (livrée), T5 | cadrage de T5, § 7 |
| Ce que T5 ajoute : étoile du tronçon, « Me prévenir », écran « Avis reçus », annonce sur la carte | T5 | § 12 ; aucun emplacement n'est réservé d'avance (YAGNI) |
| Phrase « Restrictions — placez le repère sur l'endroit voulu. » de la planche Carte-Restrictions | non prévu | § 11.3, R8 |
| Garantir 360 × 300, 640 × 360 et les téléphones en paysage au même niveau que les quatre tailles ; verrouiller l'orientation | non prévu | arbitrage 10 : seuls « ⚠ Avertissement » et la sortie du mode y sont dus ; § 11.3, R20 |
| Corriger la zone cliente de lancement sous Windows (estimée sous 740 px de haut) | à part | touche le runner natif ; § 11.3, R23 |
| Mesurer les tests en Segoe UI réelle | non prévu | la porte Windows la constate ; la réserve « Segoe UI réelle jamais mesurée en test » demeure |
| Mode sombre, mode « plein soleil » (`04-ui.md` § 3) | non prévu | jamais livrés, hors des rangées de la maquette |
| Changer le modal du premier lancement | non prévu | `BR-012` : un changement forcerait un nouvel acquittement |
| Constats d'écran dus de T2 (point 48) et de T3 (point 62) | restent dus | sauf ceux que la tranche rend sans objet (§ 11.3, R16) |

## 4. État des lieux — lu le 2026-10-17

### 4.1 La maquette du 2026-10-03

Sept planches dans le périmètre, lues par l'outil Artifact le 2026-10-17 (version `1792263730-f813`). **Elles datent d'avant T3 et T4** : ni « Favoris », ni « Filtres », ni étoile, ni lecture « Vigilance crues » dans les rangées 1 à 3 (le sélecteur à quatre entrées, en 2 × 2, n'apparaît que sur la planche Crues-Carte).

| Rangée | Planche | Ce qu'elle propose | Déjà fait, ou écarté |
|---|---|---|---|
| 1 | Main, Carte-Debit | Bloc blanc en tête : sélecteur à trois entrées (pictogramme, titre, sous-titre : « observé sur le terrain », « relatif à l'historique », « arrêtés préfectoraux »), en-tête « Légende · <lecture> » avec « ⚠ Avertissement » à droite, légende en grille ; zoom en rangée en bas à droite (−, +, recentrer), attribution en bas à gauche | Le choix « Restrictions » dans le sélecteur : **codé** (`E5` de T2, interrupteur arbitré le 2026-10-03) |
| 1 | Carte-Restrictions | En mode : l'échelle affichée cernée, « Restrictions » allumée ; phrase « Restrictions — placez le repère sur l'endroit voulu. » dans le bloc ; réticule ; bouton « Restrictions au centre de la carte » et indice « ou appui long sur n'importe quel point » en bas | Bouton, indice, réticule : **codés** (`E5`) |
| 2 | Fiche-Station | La fiche **sous** la carte (bloc en tête, bande de carte d'au moins 104 px avec réticule et zoom, fiche en bas) ; en-tête « STATION · K447001001 », « ⚠ Avertissement », fermeture ; titre ; « La Loire · Département 41 » ; tuiles Débit (mise en avant) et Hauteur, chacune datée et sourcée ; « Indéterminé · relatif à l'historique » ; « Statut (Hub'Eau) », « Qualification (Hub'Eau) » ; pied « Écoulement observé autour » | Bloc « Indéterminé » et passerelle : **écartés** (arbitrages 5, 6) |
| 2 | Fiche-Onde | Même cadre ; « POINT ONDE » ; catégorie mise en avant avec son symbole, modalité, campagne datée et sourcée ; « Campagnes précédentes » à symboles ; rappel de rythme ; pied « Débit mesuré autour » | Passerelle : **écartée** (arbitrage 6) |
| 2 | Restrictions-Lieu | L'écran des restrictions atteint par désignation seule, encart renforcé en tête, lieu désigné, zone, échelle en rangée de quatre crans, profils | Entrée par désignation seule : **codée** (Q1 de T2) ; le reste : **écarté** (arbitrage 7) |
| 3 | Windows-Carte | À 1 280 × 800 : carte à gauche (`flex: 999 1 560px`), fiche en panneau à droite (`flex: 1 1 380px`, filet gauche), bloc de lecture de 480 px en haut à gauche de la carte, zoom en colonne en bas à droite, attribution dessous ; panneau : « STATION HYDROMÉTRIQUE · K447001001 », fermeture, titre, « ⚠ Avertissement » sur sa ligne, tuile Débit en grand, Hauteur, statut et qualification | Le panneau passe sous la carte quand les deux ne tiennent pas côte à côte (940 px) ; ici, dès 800 px (arbitrage 4) |

Quand une fiche est ouverte, la planche Fiche-Station ôte le « ⚠ Avertissement » de l'en-tête de légende (la fiche porte le sien) : **non repris** (§ 11.3, R4).

### 4.2 Code (`c22ac0d`)

| Fait | Preuve |
|---|---|
| ✔ `enum MapScaleKind { ecoulement, debit, crues }` ; libellés « Écoulement », « Débit relatif à l'historique », « Vigilance crues » | `lib/features/map/view_model/map_scale.dart:24-38`, `:50-54` |
| ✔ Le sélecteur est un `Wrap` de puces en pilule, un seul `Text` par puce, sans sous-titre ; « Restrictions » (`designationChipLabel`) est un interrupteur (`toggled`, jamais `selected`), absent sans désignation câblée | `lib/features/map/view/map_scale_chips.dart:26`, `:80-99`, `:176-206` |
| ✔ Deux dispositions des surcouches du haut, seuil **600 px** ; sous 600, une colonne à droite : avertissement, puces, avis, légende ; à partir de 600, avertissement et légende à droite, puces et avis à gauche | `lib/features/map/view/map_view.dart:1312`, `:1441`, `:1490-1502` ; `:1369-1376`, `:1417` |
| ✔ Légende « toujours visible, jamais repliée », 260 px au plus, titre = `mapScaleLabel` | `lib/features/map/view/map_legend.dart:126`, `:188-189`, `:228-234` |
| Colonne du bas à droite, la même aux deux largeurs : « Favoris », « Filtres », +, −, recentrer, attribution ; défile ancrée en bas | `map_view.dart:1243-1281` ; `lib/features/map/view/map_controls.dart:73-98` |
| Mise en page par `MapOverlaysLayout` : la colonne du bas d'abord, celle du haut reçoit le reste (au moins une cible tactile) ; ordre de peinture : haut, gauche, fiches, bas | `lib/features/map/view/map_overlays_layout.dart:73-97` ; `map_view.dart:1322-1327` |
| ✔ Réticule `Center(MapCenterReticle)`, au centre exact de la carte, sous toutes les surcouches ; les boutons + et − zooment autour du centre de la caméra | `map_view.dart:1285`, `:2296-2309` ; `lib/features/map/view/map_center_reticle.dart:19` |
| ✔ `flutter_map` 8.3.2 (paquet installé) : `MapCamera.screenOffsetToLatLng(Offset)` donne le point sous un pixel de l'écran ; `focusedZoomCenter(Offset, double)` le centre d'un zoom qui garde un point fixe ; les `CameraFit` prennent une marge `EdgeInsets padding` | `flutter_map-8.3.2/lib/src/map/camera/camera.dart:353`, `:420` ; `camera_fit.dart:24-72` |
| ✔ Aucune `SafeArea` sur la carte (seule la feuille des filtres en porte une) ; l'orientation n'est pas verrouillée | `lib/features/map/view/map_filter_sheet.dart:157` ; `project-state.md`, point 60 |
| ✔ Bouton « Restrictions au centre de la carte » ; indice « ou appui long sur n'importe quel point » (toucher) / « ou clic droit sur n'importe quel point de la carte » (souris) ; bande en bas au centre, au-dessus de l'attribution | `lib/features/map/view/designate_center_button.dart:29`, `:153-170` ; `map_view.dart:1566-1620` |
| ✔ **Les fiches sont une surcouche** du `Stack` de la carte, empilées station, ONDE, tronçon, en bas à gauche à toute largeur, 420 px au plus ; hauteur bornée à celle de la carte (moins l'attribution en mode) ; la carte ne rétrécit pas | `map_view.dart:1006`, `:1133-1140`, `:1664`, `:1680`, `:1202-1205`, `:2520`, `:2583`, `:2616` |
| ✔ Un contrôleur de défilement de la zone des fiches, tenu par la racine et remis à zéro à chaque ouverture (`K4` de T3) | `lib/main.dart:322`, `:470-474`, `:591` |
| ✔ Fiche station : `WarningLink`, libellé, cours d'eau, « Département NN », une ligne « Débit : … — mesuré le … — Hub'Eau hydrométrie », une ligne « Hauteur », « Statut : … », « Qualification : … », avis de fraîcheur ; **ni code de station, ni position statistique** ; cadre : fermeture puis étoile en colonne à droite | `lib/features/station_sheet/view/station_summary_sheet.dart:158-200`, `:378-418` |
| Fiche ONDE : `WarningLink`, libellé, cours d'eau, département, catégorie en gras (sans symbole), phrase du code 4, modalité, campagne datée et sourcée, « Campagnes précédentes » (la dernière en tête, cinq au plus), rappel de rythme ; même cadre | `lib/features/onde_sheet/view/onde_summary_sheet.dart:168-222`, `:335-375` ; `onde_sheet_view_model.dart:151`, `:287` |
| Fiche tronçon : « Tronçon Vigicrues », nom, `WarningLink`, encart de crue, niveau, définition citée, date, bulletin ; pas d'étoile ; son propre cadre | `lib/features/flood_sheet/view/flood_sheet_panel.dart:14`, `:83-162` |
| ✔ Le symbole d'écoulement (`OndeMarkerShape`) vit dans la tranche carte : la fiche ONDE ne peut pas l'importer (règle `feature-vers-feature`) ; et il emprunte à `station_marker.dart` (tailles, liseré, `insetConvexPolygon`, d'après la relecture) : le déplacer seul sous `shared/` violerait `shared-sans-tranche` | `lib/features/map/view/onde_marker.dart:92`, `:621` ; `test/architecture/layers_test.dart` |
| ✔ `ScreenTitleBar` pose un `BackButton` sans info-bulle ; `MaterialApp` sans `locale`, `supportedLocales` ni `localizationsDelegates` ; `flutter_localizations` absent de `pubspec.yaml` : l'info-bulle vaut « Back » | `lib/features/shared/screen_layout.dart:52-57` ; `lib/main.dart:491-499` ; `pubspec.yaml` |
| ✔ `flutter_localizations` (SDK 3.47.7) dépend de `intl ^0.20.3` et `path` ; `intl` 0.20.3 est **déjà** dans `pubspec.lock` (transitif) ; sa table française donne `backButtonTooltip` « Retour », `copyButtonLabel` « Copier » | `<FLUTTER_ROOT>/packages/flutter_localizations/pubspec.yaml`, `lib/src/l10n/material_fr.arb:5`, `:27` ; `pubspec.lock` |
| `ScreenTitleBar` sert à « D'où vient cette donnée ? », « Sécheresse et restrictions », « Favoris » | `lib/features/shared/data_sources_view.dart:212` ; `lib/features/restrictions/view/restrictions_screen.dart:187` ; `lib/features/favorites/view/favorites_screen.dart:152` |
| ✔ Fenêtre Windows : **800 × 740 de zone cliente au minimum** (verrou `windows_min_size_test.dart`), imposé par `WM_GETMINMAXINFO` au redimensionnement ; au lancement, `CreateWindow` reçoit 1 280 × 720 **hors tout**, cadre et barre de titre compris : la zone cliente de départ est plus petite — environ 1 264 × 681 à 100 % de mise à l'échelle, **calcul de la relecture, non mesuré**, donc sous la hauteur minimale. « 1 280 × 720 » reste ici une surface de test | `windows/runner/main.cpp:29` ; `windows/runner/win32_window.cpp:49-50`, `:168-172`, `:191-200` |
| ✔ Cible tactile : 48 sous Android, 44 ailleurs | `lib/features/shared/tap_target.dart:29-33` |
| `WarningLink` posé sur la carte et en tête de chaque fiche | `map_view.dart:1037` ; `station_summary_sheet.dart:165` ; `onde_summary_sheet.dart:172` ; `flood_sheet_panel.dart:105` |
| ✔ Taille : `map_view.dart` 2 668 lignes, `main.dart` 823 ; tests : `map_overlays_phone_test.dart` 5 272 (23 déclarations « CONSTAT »), `map_view_test.dart` 3 857, `main_test.dart` 3 255, `map_sheet_height_test.dart` 1 215 | `wc -l` du 2026-10-17 |
| Textes d'acceptation liés à la disposition : « reste présent au-dessus de la légende », « la puce « Vigilance crues » », « les puces d'échelle » | `docs/acceptance/avertissements.feature:41` ; `crues.feature:11-14` ; `filtres.feature:83-86` |
| `BR-008` dit l'échelle « choisie par les puces d'échelle » ; `UC-001` place le contrôle « en haut à droite au-dessus de la légende » | `docs/br/BR-008-une-seule-echelle-a-la-fois.md:11`, `:40` ; `docs/use-cases/UC-001-consulter-la-carte-autour-de-moi.md:24` |

### 4.3 Les points d'interface repris

| Point | Constat | Ce qui le solde |
|---|---|---|
| 49 | En mode « Restrictions », au téléphone, l'avis recouvre le réticule (« CONSTAT », `map_overlays_phone_test.dart:2941`, `:3418`) | D3 : le réticule est au centre de la carte visible libre ; critère 2 |
| 51 | Le bouton de retour s'annonce « Back » | D8 ; constat au Narrateur à la porte |
| 60 | Fiche plus haute que la carte ; en mode, une fiche haute masque le bouton de désignation ; fermeture et étoile défilent avec la fiche | D4, D5, D6 : la fiche ne prend que ce que laissent le bloc et la bande minimale, en-tête épinglé |
| 61 | Colonne du bas à cinq boutons : (a) avis d'absence qui dépasse de 8 px à 360 × 640 ; (b) puce « Restrictions » coupée à 200 % sur fenêtre courte ; (c) action de l'avis de carte vidée hors de vue à 360 × 640 et 200 % ; sélecteur sur une rangée de plus avec la quatrième puce | (a), (b) et le sélecteur : D1, D2, critère 2. **(c) n'est pas soldé** : l'avis est le troisième repli (arbitrage 11) ; là où il cède, son action reste atteignable en faisant défiler le bloc — l'acceptation en constat du 2026-10-14 demeure, remesurée |
| 63 | En mode, à 360 × 300 et 200 %, la pilule du bouton recouvre le centre de « ⚠ Avertissement » (`map_overlays_phone_test.dart:3703`) | D3 : la bande du bouton ne monte jamais sur le bloc ; à cette taille, en deçà des quatre, « ⚠ Avertissement » est atteignable en faisant défiler le bloc |
| 64 | La fiche tronçon recouvre les puces et le « ⚠ Avertissement » de la carte (« CONSTAT — K1 de T4 », « K1b de T4 », `map_overlays_phone_test.dart:5027`, `:5115`, `:5223`) | D4, D5 : aucune fiche ne recouvre le bloc ; critère 2 |

## 5. Conception — la carte

### 5.1 Trois largeurs

| Largeur de la fenêtre | Bloc de lecture | Bas de la carte | Fiche |
|---|---|---|---|
| **moins de 600 px** (téléphone) | toute la largeur, en tête | **rangée** : « Favoris », « Filtres » à gauche ; −, +, recentrer à droite ; attribution dessous | fiche du bas |
| **600 à 799 px** (petite tablette en portrait, fenêtre partagée) | en haut à gauche, 480 px au plus | **colonne** à droite, comme aujourd'hui | fiche du bas |
| **800 px et plus** (toute fenêtre Windows, tablette en paysage, la plupart des téléphones en paysage) | en haut à gauche **de la carte visible**, 480 px au plus | colonne à droite **de la carte visible** | **panneau latéral** à droite, 380 px |

Les deux seuils sont des **constantes nommées**, révisables sur constat d'écran (comme les seuils de zoom d'`ADR-015`). Ils se lisent sur la largeur de la fenêtre, pas sur la plateforme (arbitrage 4). Un téléphone en paysage (844 × 390, `Pixel_7` tourné : environ 915 × 412) passe donc en panneau latéral, avec moins de 420 px de haut : il n'est pas parmi les quatre tailles et n'a que la garantie « en deçà » ; l'orientation n'est pas verrouillée (§ 11.3, R20).

### 5.2 La carte visible

La **carte visible** est l'écran moins la fiche : au-dessus de la fiche du bas, à gauche du panneau latéral, l'écran entier sans fiche. **Tout ce qui appartient à la carte s'y pose** — bloc de lecture, bas de la carte, bande du bouton de désignation, réticule, attribution — et **aucune fiche n'est jamais peinte par-dessus**.

- **La carte ne bouge pas** quand une fiche s'ouvre ou se ferme (arbitrage 12) : la fiche, opaque, se pose sur sa partie basse ou droite ; le contenu reste en place, un lieu tombé sous la fiche y reste, comme aujourd'hui ; aucun déplacement de caméra, donc **aucun rechargement** des lieux (`NFR-01`, `NFR-07`).
- **Recentrer, zoomer, cadrer une pastille** (`ADR-015`) tiennent compte de la partie cachée : le cadrage se fait dans la carte visible (`CameraFit` et sa marge `padding`, `flutter_map` 8.3.2).
- Le bloc de lecture et le bas de la carte se posent dans la **zone sûre** de l'appareil (barres système, encoche) ; la carte, elle, va jusqu'aux bords. Les mesures se font sans marge système et avec une marge de téléphone ; celle du `Pixel_7` se constate à la porte.

### 5.3 Le bloc de lecture (arbitrage 1)

```
┌──────────────────────────────────┐
│┌──────────────┐┌──────────────┐  │  ← sélecteur : 2 × 2 au téléphone,
││● Écoulement  ││◇ Débit       │  │    une rangée de quatre quand chaque
││observé sur le││relatif à     │  │    entrée y tient sans couper son titre
││terrain       ││l'historique  │  │
│└──────────────┘└──────────────┘  │
│┌──────────────┐┌──────────────┐  │
││≈ Vigilance   ││  Restrictions│  │  ← interrupteur, pas une échelle
││crues         ││arrêtés       │  │
││publiée par … ││préfectoraux  │  │
│└──────────────┘└──────────────┘  │
│ Légende · Écoulement  ⚠ Avertiss.│  ← en-tête : toujours entier
│ [avis éventuel]                  │  ← MapNotice, action comprise
│ ● Eau qui coule  ◐ Écoul. faible │  ← légende, en colonnes si la
│ ▲ Eau stagnante  ■ À sec  …      │    largeur le permet
└──────────────────────────────────┘
```

- **Ordre** : sélecteur, en-tête, avis, légende. L'avis s'intercale entre l'en-tête et la légende : « ⚠ Avertissement » ne bouge pas quand un avis paraît.
- **Sélecteur** : les trois lectures (`MapScaleKind`), puis l'interrupteur « Restrictions », sans changement de comportement (arbitrage du 2026-10-03 : la lecture affichée reste allumée, « Restrictions » s'allume en plus, un second appui l'éteint ; changer de lecture ne quitte pas le mode ; absent sans désignation câblée). Chaque entrée : un pictogramme, un **titre** et un **sous-titre** (§ 11.2), annoncés ensemble ; cible d'au moins `minimumTapTarget`. Lectures : `selected` ; « Restrictions » : `toggled`, comme aujourd'hui.
- **En-tête** : « Légende · <lecture> » à gauche, « ⚠ Avertissement » à droite — le même `WarningLink`, avec le texte de crue ajouté sur la lecture « Vigilance crues » (T4, inchangé).
- **Légende** : le contenu de `MapLegend` ne change pas ; son titre passe dans l'en-tête ; elle se pose en colonnes quand la largeur du bloc le permet.
- **Borne** : le bloc a une **partie fixe** (sélecteur et en-tête) et une **partie variable** (avis et légende). Il reçoit la hauteur que laissent le bas de la carte et, en mode, la bande du bouton et la bande du réticule (§ 5.5, § 5.6) ; la partie fixe reste entière aux quatre tailles ; **avis et légende défilent dans le bloc**, avec l'enveloppe des défilements de surcouche existants (pas de barre de bureau, gestes rendus à la carte hors des pièces, `primary: false`).

### 5.4 Le bas de la carte (arbitrage 2)

- **Sous 600 px**, une rangée au bas de la carte visible : « Favoris » et « Filtres » à gauche, −, +, recentrer à droite, chacun de la taille de `minimumTapTarget`, écart de 8 ; l'attribution IGN dessous, sur toute la largeur. Les deux formes du bouton « Filtres » (`04-ui.md` § 1, T3) ne changent pas.
- **À partir de 600 px**, la colonne actuelle à cinq boutons, au bas à droite de la carte visible, l'attribution dessous.
- Les boutons ne changent ni de libellé, ni d'annonce, ni de comportement.

### 5.5 Le mode « Restrictions » : le réticule ne se cache plus (points 49, 63)

- Le **réticule** se pose, horizontalement, au centre de la carte visible ; verticalement, au milieu de la hauteur comprise entre le bas de la **partie fixe** du bloc et le haut de la bande du bouton. En mode, la partie variable du bloc (avis, légende) s'arrête au-dessus de la bande du réticule et défile. Le réticule ne bouge donc **ni quand un avis paraît, ni quand la légende défile** ; il bouge quand la fenêtre, la taille du texte, la lecture (un en-tête qui passe à la ligne) ou la fiche changent la partie fixe ou la carte visible. Rien ne se peint sur lui.
- Le bouton « Restrictions au centre de la carte » désigne **exactement le point sous le réticule** (`screenOffsetToLatLng`) ; en mode, les boutons + et − **zooment autour du réticule** (`focusedZoomCenter`), pour que le point visé ne glisse pas.
- La **bande du bouton** (pilule et indice) se pose au bas de la carte visible, au-dessus de la rangée (sous 600 px) ou à gauche de la colonne (au-delà) ; elle ne monte **jamais** sur le bloc de lecture.
- **Repli 6** (arbitrage 11) : au téléphone, en mode, une fiche ouverte **retire la bande du bouton et le réticule** jusqu'à sa fermeture, là où la place manque ; l'entrée « Restrictions » reste allumée, l'appui long désigne toujours. **Étendu le 2026-10-18 (arbitrage 14)** : à toute largeur, en mode, une fiche ouverte les retire aussi quand la bande ne tient pas, en largeur, à côté de la colonne du bas (800 × 740 à 200 %, panneau ouvert).
- Appui long et clic droit désignent comme aujourd'hui, en mode comme hors mode ; l'épingle du point désigné ne change pas.

### 5.6 Quand la hauteur manque — l'ordre de repli (arbitrage 11)

La règle vaut à toutes les largeurs ; elle ne joue en pratique qu'au téléphone, surtout à 200 %. Rien ne cède tant que tout tient ; chaque repli ne joue que là où le précédent ne suffit pas.

| Ne cède jamais, aux quatre tailles | Cède, dans cet ordre |
|---|---|
| les **titres** du sélecteur ; l'en-tête du bloc, avec « ⚠ Avertissement » ; le bas de la carte (rangée ou colonne, attribution) ; l'en-tête de la fiche ; en mode, le réticule et sa bande, tant que le repli 6 ne joue pas | 1. la **légende** défile dans le bloc · 2. le **corps de la fiche** défile · 3. l'**avis** défile dans le bloc, son action atteignable en défilant (acceptation du 2026-10-14) · 4. les **sous-titres** du sélecteur s'effacent ; l'annonce de chaque entrée les garde · 5. l'**indice** sous le bouton de désignation s'efface · 6. au téléphone, en mode, une fiche ouverte **retire la bande du bouton et le réticule** (§ 5.5) ; à toute largeur, aussi quand la bande ne tient pas à côté de la colonne (arbitrage 14). Seule exception aux quatre tailles : à 360 × 640 et 200 %, là où les six replis ne suffisent pas, la partie fixe du bloc défile (arbitrage 13). En mode, fiche du bas ouverte, l'avis cède avant le corps de la fiche (1, 3, 2), pour que le réticule ne bouge pas (arbitrage 15), jusqu'à s'effacer quand la place manque (arbitrage 16). Fiche du bas ouverte, les sous-titres (4) et l'indice (5) cèdent avant le corps de la fiche (2) : 1, 4, 2, 3 hors mode ; 1, 3, 4, 5, 2 en mode (arbitrage 17) |

- La **bande du réticule** est la hauteur du réticule et une marge — pas une bande de carte en plus du bas de la carte (sur la planche Fiche-Station, les 104 px contiennent le zoom).
- **Mesure d'abord** : le premier lot de code mesure, en Roboto, chaque pièce aux quatre tailles, à 100 % et 200 %, hors mode et en mode, avec et sans fiche ; le plan en tire où chaque repli joue. Si, après le repli 6, un élément qui ne cède jamais ne tient pas : **arrêt et question**. **Fait le 2026-10-18** (`S6`, 432 configurations) : tout tient, sauf à 360 × 640 à 200 %, là où les six replis ne suffisent pas — fiche station ouverte, fiche tronçon sous la marge système, ou en mode sans fiche — où la partie fixe du bloc défile (arbitrage 13), et à 800 × 740 à 200 %, en mode, panneau ouvert, où le repli 6 étendu retire la bande (arbitrage 14).
- **En deçà des quatre tailles** (360 × 300, 640 × 360, téléphones en paysage), le bloc défile tout entier : « ⚠ Avertissement » et l'entrée « Restrictions » restent atteignables — en glissant sur le bloc, à la molette, ou au clavier (le focus amène le contrôle en vue). Hors mode, à 360 × 300 et 200 %, « ⚠ Avertissement », visible au repos aujourd'hui, ne l'est plus forcément : il faut faire défiler le bloc (arbitrage 10, « atteignables »).

### 5.7 Clavier

L'ordre de tabulation arbitré le 2026-10-14 (`K1` de T3) est gardé : entrées du sélecteur → action de l'avis → « Favoris » → « Filtres » → zoom et recentrer → (bouton de désignation, en mode) → carte → fiche → « ⚠ Avertissement » de la carte, en dernier. Dans la rangée, le zoom suit l'ordre de l'écran : −, +, recentrer. `Échap` ferme la fiche, comme aujourd'hui.

### 5.8 Où vit quoi (`ADR-014`)

| Quoi | Où |
|---|---|
| Les trois largeurs, la carte visible, le bloc, le bas, la bande, le réticule | `lib/features/map/view/` — `map_view.dart` et `map_overlays_layout.dart` refondus ; le plan découpe par responsabilité (bloc, bas, zone des fiches) plutôt que d'allonger `map_view.dart` |
| Le cadre commun des fiches (en-tête épinglé) | `lib/features/shared/` (trois tranches l'emploient ; règle `shared-sans-tranche`) |
| Le symbole d'écoulement, pour la fiche ONDE | **jamais recopié** : soit déplacé sous `lib/features/shared/` **avec** ce qu'il emprunte à `station_marker.dart` (règle `shared-sans-tranche`), soit fourni à la fiche par `main.dart`, qui seul compose les tranches — choix du plan, sur le plus petit déplacement |
| La localisation française | `lib/main.dart` (`MaterialApp`) ; `pubspec.yaml` |
| ViewModels, dépôts, domaine | **inchangés** : la tranche est une affaire de vues et de composition |

Les sept règles de `layers_test.dart` ne changent pas. Aucune bibliothèque d'état, aucune dépendance hors du SDK.

## 6. Conception — les fiches

### 6.1 Le cadre commun (arbitrage 3)

```
┌──────────────────────────────────────┐
│ STATION HYDROMÉTRIQUE · K447001001 ★ ✕│  ← épinglé : nature · code,
│ ⚠ Avertissement                      │    étoile, fermeture, puis
├──────────────────────────────────────┤    « ⚠ Avertissement »
│ La Loire à Blois                     │  ← corps : défile
│ La Loire · Département 41            │
│ …                                    │
└──────────────────────────────────────┘
```

- **En-tête épinglé** : une ligne de nature — « Station hydrométrique · <code> », « Point ONDE », « Tronçon Vigicrues » ; seule la station affiche son code (§ 11.2) ; la ligne se replie sur la largeur —, l'étoile quand la fiche en porte une (conditions de présence de `S7b`, inchangées ; aucune sur la fiche tronçon avant T5) et la fermeture à droite ; dessous, « ⚠ Avertissement » et sa phrase datée, inchangés. L'avis d'échec d'écriture du favori se pose sous l'en-tête, épinglé avec lui. L'en-tête ne cède jamais (§ 5.6).
- **Corps** : il défile ; la position remise à zéro à chaque ouverture (`K4` de T3) vaut pour lui.
- Les états « en cours », « en échec », « introuvable » se disent dans ce cadre, textes inchangés.
- La fermeture n'est pas un arrêt de tabulation (`Échap` ferme), l'étoile l'est : inchangé.

### 6.2 Fiche station (arbitrage 5)

Corps, dans l'ordre : le **titre** (libellé) ; « <cours d'eau> · Département NN » ; deux **tuiles**, **Débit** mis en avant puis **Hauteur**, chacune avec sa valeur, sa date et sa source (`BR-001`) — côte à côte quand elles tiennent, l'une sous l'autre sinon ; une valeur absente garde sa phrase dans sa tuile ; « Statut (Hub'Eau) » et « Qualification (Hub'Eau) », valeurs et replis inchangés ; l'avis de fraîcheur, inchangé.

### 6.3 Fiche ONDE (arbitrage 5)

Corps, dans l'ordre : le titre ; « <cours d'eau> · Département NN » ; une **tuile** : le **symbole de légende** de la catégorie puis la catégorie mise en avant, la phrase du code 4 s'il y a lieu, la modalité officielle, la campagne datée et sourcée (`BR-001`, `BR-010`) ; « Campagnes précédentes », une ligne par campagne avec son symbole ; le rappel de rythme. Le contenu ne change pas : l'historique garde la dernière campagne en tête, cinq au plus.

### 6.4 Fiche tronçon

Le cadre commun : nature « Tronçon Vigicrues », pas de code affiché, pas d'étoile (T5), « ⚠ Avertissement » épinglé ; puis l'ordre de T4 : nom, encart de crue, niveau, définition citée, date, bulletin. Seul changement d'ordre : « ⚠ Avertissement » passe avant le nom, dans l'en-tête.

### 6.5 Les deux places d'une fiche

- **Fiche du bas** (sous 800 px) : toute la largeur, au bas de l'écran ; elle prend la hauteur de son contenu, au plus ce que laisse la carte visible minimale — partie fixe du bloc, bas de la carte et, en mode, bande du réticule et bande du bouton, selon l'ordre de repli (§ 5.6) ; son contenu garde une largeur de lecture. La carte ne bouge pas (§ 5.2).
- **Panneau latéral** (dès 800 px) : 380 px à droite, toute la hauteur de la fenêtre, un filet à gauche ; la carte visible à sa gauche ; la carte ne bouge pas.
- Une seule fiche à la fois, exclusivités et fermetures inchangées (arbitrage du 2026-10-15 sur la lecture Crues compris).

## 7. Écrans pleins

- **Localisation (arbitrage 8, point 51)** : `flutter_localizations` (SDK) dans `pubspec.yaml` ; `MaterialApp` reçoit les délégués de Material, Widgets et Cupertino, `supportedLocales` = français, `locale` = français. Le `BackButton` de `ScreenTitleBar` s'annonce « Retour » ; tous les textes intégrés de Material passent en français (menu du texte sélectionnable : « Copier », « Tout sélectionner »). L'application garde ses propres formats de date ; rien d'autre n'est traduit.
- **« Sécheresse et restrictions »**, **« Favoris »**, **« D'où vient cette donnée ? »** : inchangés, hors l'annonce du bouton de retour (arbitrage 7).

## 8. Ce que la tranche ne change pas

- **Une lecture à la fois** (`BR-008`) ; « Restrictions » n'est pas une échelle et n'en dessine aucune ; l'écart accepté (« la légende défile ») demeure, et vaut aussi pendant qu'une fiche est ouverte au téléphone (§ 11.3, R5).
- **Les avertissements** (`BR-012`, `BR-013`, `BR-015`) : le contrôle « ⚠ Avertissement » de la carte est **toujours présent**, fiche ouverte ou non (§ 11.3, R4) ; chaque fiche porte le sien ; textes et fenêtres inchangés ; le modal du premier lancement ne change pas.
- **Aucune entrée vers les restrictions depuis une fiche** (Q1 de T2).
- Ce que montre la carte : regroupement par zone (`ADR-015`), marqueurs, traits de vigilance, étiquettes, filtres, avis, ouvertures de fiche par toucher et par clavier.
- Les ViewModels, les dépôts, les sources, le domaine.

## 9. Critères d'acceptation proposés

Ajoutés aux `.feature` existants — `avertissements.feature`, `fiche-station.feature`, `ecoulement-onde.feature`, `crues.feature`, `filtres.feature`, `restrictions.feature` —, écrits avec le lot qui les réalise ; aucun fichier nouveau.

1. Le bloc de lecture porte, dans l'ordre, le sélecteur à quatre entrées, l'en-tête « Légende · <lecture> » avec « ⚠ Avertissement », l'avis éventuel, la légende.
2. Chaque entrée du sélecteur porte son titre et son sous-titre, annoncés ensemble ; choisir une lecture la montre seule (`BR-008`) ; « Restrictions » s'allume en plus de la lecture affichée et s'éteint par un second appui.
3. Sous 600 px, « Favoris », « Filtres », −, +, recentrer sont sur une rangée au bas de la carte, l'attribution dessous ; à partir de 600 px, en colonne à droite.
4. Aux quatre tailles, à 100 % et 200 %, avec ou sans fiche, avec ou sans avis, hors mode et en mode : rien ne recouvre le sélecteur, le « ⚠ Avertissement » de la carte, le réticule, le bouton de désignation ni l'entrée « Restrictions » ; quand la place manque, la légende, le corps de la fiche, l'avis, les sous-titres du sélecteur, l'indice du bouton puis (au téléphone, en mode, fiche ouverte) bouton et réticule cèdent, dans cet ordre et seulement là où il le faut.
5. En mode « Restrictions », le réticule est au centre horizontal de la carte visible, à mi-hauteur entre la partie fixe du bloc et la bande du bouton ; il ne bouge pas quand un avis paraît ; le bouton désigne le point sous lui ; + et − zooment autour de lui.
6. À 360 × 300 et 640 × 360, à 200 %, « ⚠ Avertissement » et l'entrée « Restrictions » restent atteignables, en faisant défiler le bloc ou au clavier.
7. Sous 800 px, une fiche ouverte se pose au bas de l'écran, sous la carte visible ; elle ne recouvre jamais le bloc de lecture ni le bas de la carte.
8. Dès 800 px, une fiche s'ouvre en panneau à droite, sur toute la hauteur ; le bloc de lecture et la colonne restent dans la carte visible, à sa gauche.
9. Ouvrir ou fermer une fiche ne déplace pas la carte et ne recharge pas ses lieux ; recentrer et cadrer une pastille se font dans la carte visible.
10. L'en-tête d'une fiche (sa nature, le code pour une station, « ⚠ Avertissement », l'étoile quand la fiche en porte une, la fermeture) reste en place quand la fiche défile ; une fiche s'ouvre toujours par le haut.
11. La fiche station se lit dans l'ordre : nom ; cours d'eau et département ; débit puis hauteur, chacun avec sa date et sa source ; statut et qualification attribués à Hub'Eau ; avis de fraîcheur.
12. La fiche ONDE porte la catégorie avec son symbole de légende, la modalité officielle, la campagne datée et sourcée, l'historique avec symboles, le rappel de rythme.
13. La fiche tronçon garde l'ordre de T4 sous l'en-tête commun.
14. Le bouton de retour des écrans pleins s'annonce « Retour ».
15. Aucun texte nouveau ne qualifie un débit (`BR-003`, `vocabulary_test.dart`).

## 10. Constats qui ne se voient qu'à l'écran — porte, au commanditaire

**Windows** : exécutable de release lancé hors Flutter, en Segoe UI réelle, à la taille du lancement puis réduite à 800 × 740, texte à 100 % puis 200 % — réglage « Taille du texte » de Windows, que le moteur Windows de Flutter lit dans le registre de l'utilisateur (`<FLUTTER_ROOT>/engine/src/flutter/shell/platform/windows/settings_plugin.cc:116`, lu le 2026-10-17 ; réglage fait par le commanditaire). **Android** : émulateur `Pixel_7`, en débogage, police à 100 % puis 200 %.

| # | Constat | Cible |
|---|---|---|
| a | Le bloc de lecture : sélecteur à quatre entrées, en-tête avec « ⚠ Avertissement », avis, légende ; passer d'une lecture à l'autre, allumer et éteindre « Restrictions » | les deux |
| b | Le bas : la rangée (Android), la colonne (Windows) ; « Favoris » et « Filtres » s'ouvrent | les deux |
| c | Une fiche station ouverte : en panneau à droite (Windows), sous la carte (Android) ; son en-tête reste en place quand elle défile | les deux |
| d | Fiche ONDE (symbole, historique) et fiche tronçon dans le même cadre | les deux |
| e | En mode « Restrictions », fiche ouverte puis fermée : réticule et bouton visibles (ou retirés au téléphone, repli 6) ; + et − gardent le point sous le réticule ; désigner ouvre l'écran des restrictions au point sous le réticule | les deux |
| e′ | Ouvrir puis fermer une fiche : la carte ne bouge pas ; « recentrer » cadre la France dans la carte visible | les deux |
| f | À 200 % : rien de recouvert — points 49, 61, 63, 64 | les deux |
| g | Écran divisé (Android) ou fenêtre la plus basse (Windows, 740 px) : « ⚠ Avertissement » et la sortie du mode atteignables | les deux |
| h | Redimensionner la fenêtre jusqu'à 800 px de large : le panneau reste à droite ; relever la taille de la zone cliente au lancement (§ 4.2 : estimée sous 740 px de haut) | Windows |
| i | Narrateur : le bouton de retour d'un écran plein s'annonce « Retour » (point 51) | Windows |
| j | Le menu d'une adresse sélectionnable (écran des sources ou des restrictions) est en français | les deux |

## 11. Textes — règles et écrans

### 11.1 Documents de règles — amendements à écrire au lot 1

- **`BR-008`**, amendement daté : « Le choix se fait dans le **sélecteur de lecture** de la carte (tranche d'ergonomie, arbitrage 1 du 2026-10-17), qui remplace les puces d'échelle ; la légende est dans le bloc de lecture, sous l'en-tête « Légende · <lecture> ». L'entrée « Restrictions » du sélecteur est un **mode de désignation**, pas l'échelle « sévérité sécheresse » : elle s'allume en plus de la lecture affichée et ne dessine aucune échelle sur la carte (arbitrage du 2026-10-03, inchangé). L'écart accepté le 2026-10-12 (la légende défile quand la place manque) vaut aussi pendant qu'une fiche est ouverte : la légende est le premier repli (arbitrage 11 du 2026-10-17). »
- **`UC-001`**, amendement daté : le contrôle « ⚠ Avertissement » de la carte est dans l'en-tête de la légende, sous le sélecteur.
- **`docs/glossary.md`** : « Sélecteur de lecture », « Bloc de lecture », « Carte visible », « Fiche du bas », « Panneau latéral » ; l'entrée « Filtre » renvoie au sélecteur au lieu des puces.

### 11.2 Textes d'écran — proposés, à approuver avec ce document

| Emplacement | Texte |
|---|---|
| Sélecteur, Écoulement | titre « Écoulement » · sous-titre « observé sur le terrain » |
| Sélecteur, Débit | titre « Débit » · sous-titre « relatif à l'historique » |
| Sélecteur, Crues | titre « Vigilance crues » (T4) · sous-titre « publiée par Vigicrues » |
| Sélecteur, Restrictions | titre « Restrictions » (T2) · sous-titre « arrêtés préfectoraux » |
| Annonce d'une entrée | titre et sous-titre, séparés par une virgule : « Débit, relatif à l'historique » |
| En-tête de légende | « Légende · Écoulement » · « Légende · Débit relatif à l'historique » · « Légende · Vigilance crues » |
| Fiche station, en-tête | « Station hydrométrique · <code> » (le code de la station, 10 caractères) |
| Fiche ONDE, en-tête | « Point ONDE » |
| Fiche tronçon, en-tête | « Tronçon Vigicrues » (T4, inchangé) |
| Fiches station et ONDE, sous le titre | « <cours d'eau> · Département <NN> » ; replis existants : « Cours d'eau non renseigné », « Département non renseigné » |
| Tuiles de la fiche station | « Débit » · « <valeur> m³/s » · « mesuré le JJ/MM/AAAA à HH:MM » · « Hub'Eau hydrométrie » ; « Hauteur » · « <valeur> m » · « mesurée le JJ/MM/AAAA à HH:MM » · « Hub'Eau hydrométrie » ; valeur absente : la phrase existante |
| Statut et qualification | « Statut (Hub'Eau) » · « Qualification (Hub'Eau) », chacun au-dessus de sa valeur (valeurs et replis existants) |
| Bouton de retour | « Retour » (table française du SDK) |

Les textes de la tuile ONDE, de l'historique, du rappel de rythme, des états des fiches, des avis, de la légende et des avertissements ne changent pas.

### 11.3 Décisions de la boucle principale, réversibles

| # | Décision |
|---|---|
| R1 | « Bloc de lecture » nomme dans les documents ce que les questions appelaient « carte unique » ou « carte du haut » : « carte » désigne déjà la carte géographique |
| R2 | Seuils de 600 et 800 px en constantes nommées, lus sur la largeur de la fenêtre, révisables sur constat d'écran |
| R3 | ~~La technique de la carte visible laissée au plan~~ — tranché par l'**arbitrage 12** (la carte ne bouge pas) ; reste de la boucle principale : le cadrage par la marge `padding` des `CameraFit`, et la carte qui va jusqu'aux bords sous une fiche opaque |
| R4 | Le « ⚠ Avertissement » de la carte reste dans l'en-tête du bloc quand une fiche est ouverte — la planche Fiche-Station l'ôtait ; l'invariant « toujours présent » de `CLAUDE.md` le garde |
| R5 | Fiche ouverte, la légende cède la première (§ 5.6) : prolongement de l'écart à `BR-008` accepté le 2026-10-12, écrit dans `BR-008` (§ 11.1) ; l'ordre complet est l'**arbitrage 11** |
| R6 | En mode « Restrictions », la lecture affichée et « Restrictions » sont toutes deux allumées pleines, comme aujourd'hui (« la puce de l'échelle reste allumée », arbitrage du 2026-10-03) — pas le contour « échelle affichée » de la planche Carte-Restrictions |
| R7 | Pictogrammes des entrées tirés des icônes Material ou des formes de légende existantes ; aucun actif, aucune bibliothèque ; celui de « Restrictions » ne reprend pas le triangle de « ⚠ Avertissement » ; le pictogramme n'est jamais seul porteur du sens |
| R8 | La phrase « Restrictions — placez le repère sur l'endroit voulu. » n'est pas reprise : l'indice existant sous le bouton dit déjà le geste, et le bloc garde sa hauteur |
| R9 | Tabulation de `K1` de T3 gardée, « ⚠ Avertissement » de la carte en dernier ; dans la rangée, ordre de l'écran (−, +, recentrer) |
| R10 | En-tête de fiche : « nature · code » avec étoile et fermeture sur la première ligne, « ⚠ Avertissement » dessous ; le titre défile avec le corps ; l'avis d'échec d'écriture du favori épinglé sous l'en-tête |
| R11 | Les fiches ne perdent aucun texte ni aucun état ; l'historique ONDE garde la dernière campagne en tête (la planche ne montrait que les précédentes) |
| R12 | Fiche tronçon : « ⚠ Avertissement » passe avant le nom, dans l'en-tête ; l'ordre de T4 tient pour le reste |
| R13 | Le symbole d'écoulement atteint la fiche ONDE sans copie : déplacé sous `lib/features/shared/` avec ses emprunts à `station_marker.dart`, ou fourni par `main.dart` (§ 5.8) ; aucun autre widget ne change de tranche |
| R14 | Aucun ViewModel ne change ; **aucun ADR** : la tranche change des vues et ajoute une dépendance du SDK, consignée dans `CLAUDE.md` (stack) et dans l'arbitrage 8 |
| R15 | Les tests « CONSTAT » qui décrivent l'ancienne disposition sont **remplacés** par les invariants du critère 2 (§ 1), mesurés en Roboto ; le décompte ne baisse pas ; un écart restant à l'une des quatre tailles est un **rouge**, pas un nouveau « CONSTAT » : arrêt et question |
| R16 | Deviennent **sans objet** à la porte de la tranche, listés un à un dans `project-state.md`, les constats dus qui décrivent une disposition remplacée : de T2, (b) et (c) du 2026-10-06 (colonne droite de la disposition large, qui disparaît) ; de T3, les écarts « mesurés en test, à voir à l'écran » de la colonne du bas, de 360 × 300, de « Favoris » à 640 × 360 et de la fiche bord à bord (`K5`), et, au point 62, « l'étoile sous le bouton de fermeture » et la décision 4 ; la disposition des puces (point 61, arbitrage du 2026-10-15) ; le point 64. **Restent dus** : (a), (d) à (h) du 2026-10-06 (bande du bouton, écran des restrictions, caméra), `E4`, la porte de T2, et le reste du point 62 |
| R17 | `04-ui.md` : un croquis neuf de la carte (trois largeurs) et des fiches, en tête de chaque section, dit « fait foi » ; les croquis et les mesures qu'il remplace restent, marqués « remplacés, gardés pour mémoire », comme le projet l'a fait pour l'écran des restrictions |
| R18 | Fiche du bas pleine largeur, contenu dans la largeur de lecture (`readingColumnWidth`) ; panneau de 380 px fixe, le contenu défile à 200 % |
| R19 | Version `0.6.0+6` (`pubspec.yaml`), ouverte au lot 1 dans `CHANGELOG.md`, datée à la porte |
| R20 | Les téléphones en paysage passent en panneau latéral (largeur ≥ 800) et n'ont que la garantie « en deçà » ; **l'orientation n'est pas verrouillée** (un verrou serait un changement de configuration, à soumettre) |
| R21 | Bloc de lecture et bas de la carte dans la **zone sûre** de l'appareil ; mesures sans et avec marge système ; la marge du `Pixel_7` se constate à la porte |
| R22 | Le réticule est fixé par la partie fixe du bloc et la bande du bouton, pas par la hauteur de l'avis ou de la légende (§ 5.5) : il ne bouge pas quand un avis paraît ; en mode, + et − zooment autour de lui |
| R23 | La zone cliente de lancement sous Windows, estimée sous la hauteur minimale de 740 px (§ 4.2), n'est **pas corrigée** par la tranche (elle touche le runner natif) : elle se relève à la porte (constat `h`) ; la correction est proposée à part. « 1 280 × 720 » reste une surface de test |

## 12. Ce que la tranche change pour T5

Le cadrage de T5 est approuvé ; ses arbitrages tiennent. Ce qui suit est à **relire au plan de T5**, sur les écrans refaits (arbitrage 16) :

- **§ 7.1 et § 7.2 (fiches)** : l'étoile du tronçon prend la place de l'étoile dans l'**en-tête épinglé** du cadre commun ; « Me prévenir » s'écrit dans le **corps**. L'arbitrage 8 de T5 dit « sous l'étoile » : avec un en-tête épinglé, cela veut dire en tête du corps ou après le contenu — à trancher au plan de T5, sur constat de hauteur au téléphone.
- **§ 7.5 (annonce sur la carte)** : « aucun bouton de plus » tient ; l'annonce se pose dans la carte visible ou dans le bloc de lecture, **hors** de `mapNoticesFor` (R10 de T5) ; la tranche ne lui réserve aucun emplacement.
- **§ 7.4 (« Avis reçus »)** : `ScreenTitleBar` s'y annonce déjà « Retour ».
- **R13 de T5** : la version passe de `0.6.0+6` à **`0.7.0+7`** (arbitrage 9).
- **§ 1, critère 6, et § 4.1** : le décompte de tests, les tailles de `main.dart` et de `map_view.dart` et les lignes citées sont à relever de nouveau.
- **§ 10, constat `h`** (cibles et lecture au téléphone) : il se fait sur la nouvelle disposition.

## 13. Documents à produire ou amender

Code et spec dans le même commit : chaque document s'écrit avec le lot qui le réalise.

| Document | Changement | Lot |
|---|---|---|
| `BR-008`, `UC-001`, `docs/glossary.md` | § 11.1 | 1 |
| `CHANGELOG.md`, `pubspec.yaml` | `0.6.0` ouverte au lot 1, datée à la porte ; `flutter_localizations` au lot 7 | 1, 7, 9 |
| `CLAUDE.md` | tableau « Où on en est » ; stack (`flutter_localizations`, locale `fr`) ; liste des widgets partagés (cadre de fiche, symbole d'écoulement s'il y passe) ; arborescence de `features/map/view/` | 1, puis au fil des lots, relu au 8 |
| `docs/acceptance/*.feature` (six fichiers, § 9) | scénarios nouveaux ; « au-dessus de la légende » (`avertissements.feature:41`), « la puce » (`crues.feature`), « les puces d'échelle » (`filtres.feature`) récrits ; les libellés portés par une constante, liés par `acceptance_features_test.dart` | 1, puis au fil des lots |
| `04-ui.md` | § 1 (carte, trois largeurs ; fiches ; R17), § 3 (désignation : réticule, zoom autour de lui), § 4 et § 5 (place du contrôle « ⚠ Avertissement » de la carte : en-tête de légende) | 3 à 5, relu au 8 |
| `03-conception.md` | arbre des écrans : sélecteur, bloc, panneau | 8 |
| `project-state.md`, `docs/README.md` | ligne « Ergonomie » ; points 49, 51, 60, 61, 63, 64 clos à la porte ; constats rendus sans objet (R16) ; arbitrages | au fil des lots |
| Cadrage de T5 | aucun changement par cette tranche ; § 12 relu au plan de T5 | — |

## 14. Découpage indicatif en lots

Ordre `features/shared/` → `features/<tranche>/view/` → composition ; aucun `domain/`, aucun `data/`, aucun `view_model/`.

| Lot | Contenu | Dépend de |
|---|---|---|
| 1 | Documents du § 11.1 ; `0.6.0` ouverte | approbation de ce cadrage |
| 2 | **Pièces et mesure** — le premier lot de code (arbitrage 11) : entrée du sélecteur (titre, sous-titre), en-tête de légende, en-tête du cadre de fiche, rangée du bas ; **chaque pièce mesurée** en Roboto aux quatre tailles, à 100 % et 200 % ; le plan en tire, avant d'assembler, où chaque repli du § 5.6 joue — ou s'arrête et pose la question | lot 1 |
| 3 | **Fiches** : cadre commun (`shared`), les trois fiches dedans, hiérarchie station et ONDE, symbole d'écoulement (R13) (§ 6.1 à 6.4) | lot 2 |
| 4 | **Bloc de lecture** : sélecteur, en-tête, avis, légende en colonnes, partie fixe et partie variable, défilement (§ 5.3) | lot 2 |
| 5 | **Disposition** : trois largeurs, carte visible et carte immobile, zone sûre, fiche du bas, panneau latéral, bas de la carte, bande du bouton, réticule et zoom autour de lui, ordre de repli (§ 5.1, 5.2, 5.4 à 5.6, 6.5) ; composition dans `main.dart` | lots 3, 4 |
| 6 | **Invariants** : critère 2 aux quatre tailles, en Roboto ; « CONSTAT » de l'ancienne disposition remplacés (R15) ; clavier (§ 5.7) ; en deçà (critère 6) | lot 5 |
| 7 | **Point 51** : `flutter_localizations`, délégués et locale ; test de la racine (« Retour ») ; textes intégrés cherchés en anglais par des tests, relevés | lot 1 |
| 8 | Relecture des documents tenus au fil des lots ; `03-conception.md` ; `project-state.md` | lots 6, 7 |
| 9 | **Porte** : release Windows hors Flutter **et** émulateur Android, constats du § 10, version datée | lot 8 |

Les lots 3 et 4 sont indépendants l'un de l'autre. Le lot 7 ne dépend d'aucun lot de code ; il passe après le lot 2, qui reste le premier lot de code (arbitrage 11).

**Risques à garder en vue :** `map_view.dart` (2 668 lignes) et `buildMapOverlays` refondus d'un bloc — d'où le découpage du § 5.8 ; `map_overlays_phone_test.dart` (5 272 lignes, 23 déclarations « CONSTAT ») et `map_sheet_height_test.dart` à récrire sans que le décompte baisse ; la carte immobile sous une fiche opaque : le centre de la caméra n'est plus celui de la carte visible, et recentrer, zoomer, cadrer une pastille et désigner doivent tous en tenir compte (§ 5.2, § 5.5) ; à 360 × 640 et 200 %, la place manque d'après un calcul de la relecture (sélecteur ≈ 250 px, en-tête ≈ 90, bande du bouton ≈ 180, rangée et attribution ≈ 110) — d'où la mesure au lot 2 et l'ordre de repli ; à 800 px, la carte visible ne fait que 420 px pour un bloc de 480 au plus, en 2 × 2 à 200 % ; Segoe UI réelle n'est vue qu'à la porte ; `flutter_localizations` change des textes intégrés que des tests pourraient chercher en anglais (aucun « Back » trouvé le 2026-10-17, les autres à relever au lot 7) ; T5 attend la porte de cette tranche.
