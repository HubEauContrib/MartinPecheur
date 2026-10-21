# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et ce
projet adhère au [Versionnage Sémantique](https://semver.org/lang/fr/).

Chaque ligne décrit un changement visible **pour un usager ou un
intégrateur** — jamais un détail interne. Un remaniement sans effet
observable n'y figure pas.

## [Non publié]

## [1.0.0] — 2026-10-21

Même application que `0.6.0`, sous un nouveau numéro : la première version
destinée au Microsoft Store, datée et étiquetée sur décision du commanditaire
du 2026-10-21. Le Store refuse une version dont le premier nombre vaut 0
(exigences d'un paquet MSIX, relues le 2026-10-21 ; `ADR-018`). Aucun paquet
MSIX n'est construit et rien n'est soumis au Store ; la mise en production
reste une décision du commanditaire, et la porte de T2 reste due.

### Modifié

- Le numéro de version passe de `0.6.0` à `1.0.0` (numéro de construction
  `7`) : c'est lui qu'affichent les propriétés du fichier sous Windows et les
  informations de l'application sous Android. Aucune fonctionnalité ne change
  par rapport à `0.6.0`.

## [0.6.0] — 2026-10-21

Tranche d'ergonomie, avant T5 : une lecture à la fois sur la carte, des fiches
qui ne recouvrent plus la carte (cadrage du 2026-10-17). **Version datée du
2026-10-21**, après les constats de la porte par le commanditaire. La porte de
la tranche est franchie sur les deux cibles, Windows (exécutable de release
lancé hors Flutter) et Android (émulateur Pixel_7, en débogage) : « Constaté à
l'exécution » recopie ce que le commanditaire a dit, « Non vérifié » ce qu'il
n'a pas dit. Aucun tag n'est posé et la mise en production reste une décision
du commanditaire ; la porte de T2 reste due. « Ajouté » et « Modifié » sont
écrits d'après le code livré sur `feat/ergonomie` et vérifiés par
`flutter test` (mesures de disposition en Roboto) ; seul ce que « Constaté à
l'exécution » dit a été vu à l'écran. « Modifié » dit ce qui
change par rapport à `0.5.0`.

### Ajouté

- Panneau latéral : dès 800 px de large (toute fenêtre Windows, une tablette en
  paysage), une fiche s'ouvre à droite, sur 380 px et toute la hauteur, un
  filet à sa gauche ; la carte reste à sa gauche, bloc de lecture et colonne de
  boutons compris. Sous 800 px, la fiche se pose au bas de l'écran, sous la
  carte visible.
- Les textes intégrés de Material passent en français (`flutter_localizations`,
  locale `fr`) : le bouton de retour des écrans pleins s'annonce « Retour »
  (point 51), et le menu d'une adresse sélectionnable est en français.
- En deçà des quatre tailles garanties (360 × 300, 640 × 360, téléphones en
  paysage), « ⚠ Avertissement » et l'entrée « Restrictions » restent atteignables
  : la partie fixe du bloc garde au moins la hauteur d'une cible tactile
  (48 sur Android, 44 ailleurs), la colonne de boutons défile au-dessus de
  l'attribution, et l'en-tête d'une fiche passe devant elle. Limite acceptée à
  360 × 300 et 200 %, fiche station ouverte : la partie fixe n'y garde que 40 px.

### Modifié

- Sous 600 px, une rangée au bas de la carte remplace la colonne de boutons :
  « Favoris » et « Filtres » à gauche, −, + et recentrer à droite, l'attribution
  IGN dessous. À partir de 600 px, la colonne de cinq boutons reste à droite.
- En mode « Restrictions », le réticule et le bouton « Restrictions au centre de
  la carte » se posent au centre de la carte visible, entre le bloc de lecture et
  la bande du bouton : le bouton désigne le point sous le réticule, et + et −
  zooment autour de ce point. Là où la place manque, une fiche ouverte retire le
  bouton et le réticule jusqu'à sa fermeture ; l'appui long et le clic droit
  désignent toujours.
- Windows : la fenêtre s'ouvre avec une zone cliente d'au moins 800 × 740, soit
  1 280 × 740 à 100 % (1 264 × 681 auparavant).

- La carte porte un seul **bloc de lecture** : un sélecteur à quatre entrées
  (écoulement, débit, vigilance crues, puis l'interrupteur « Restrictions »),
  chacune avec son titre et son sous-titre annoncés ensemble, remplace les
  puces d'échelle ; dessous, l'en-tête « Légende · <lecture> », l'avis éventuel
  et la légende. Une seule lecture est affichée à la fois (`BR-008`).
- Le contrôle « ⚠ Avertissement » de la carte passe dans l'en-tête du bloc, à
  droite du nom de la lecture, ou dessous quand le nom ne tient pas à côté sans
  couper un mot. Il reste toujours présent, fiche ouverte ou non.
- Une fiche ne recouvre plus la carte : au téléphone, elle prend sa hauteur sur
  la carte visible ; la carte ne bouge ni à l'ouverture ni à la fermeture, et
  recentrer ou cadrer une pastille tiennent compte de la partie cachée. Quand la
  hauteur manque, la place se rend dans un ordre arbitré, selon le cas, et
  seulement là où il le faut. Sans fiche au bas : la légende défile, puis le
  corps d'une fiche en panneau, l'avis, les sous-titres du sélecteur et
  l'indice sous le bouton cèdent, et enfin, en mode « Restrictions », le bouton
  et le réticule se retirent. Fiche du bas ouverte, « Restrictions » éteinte :
  la légende, les sous-titres, le corps de la fiche, puis l'avis. Fiche du bas
  ouverte, « Restrictions » allumée : la légende, l'avis, les sous-titres,
  l'indice, le corps de la fiche, puis le bouton et le réticule. La fiche garde
  au moins sa mesure mise en avant (le débit, la catégorie ou le niveau) ; là
  où cela ne suffit pas, la partie fixe du bloc défile, jusqu'à la hauteur
  d'une cible tactile (à 360 × 640 et 200 % notamment).
- Les trois fiches partagent un cadre commun : un en-tête épinglé (nature,
  code pour une station, étoile de favori quand la fiche en porte une,
  fermeture, puis « ⚠ Avertissement »), séparé du corps par un filet, qui défile
  dessous ; une fiche s'ouvre toujours par le haut.
- La fiche station se lit par ordre d'importance : titre, « cours d'eau ·
  Département NN », tuile **Débit** mise en avant puis tuile **Hauteur** (chacune
  avec sa date et sa source, côte à côte quand elles tiennent), puis « Statut
  (Hub'Eau) » et « Qualification (Hub'Eau) » au-dessus de leurs valeurs.
- La fiche du point ONDE montre la catégorie avec son symbole de légende, dans
  une tuile qui dit aussi la modalité officielle et la campagne datée et
  sourcée ; l'historique des campagnes porte un symbole par ligne.
- La fiche tronçon Vigicrues garde son contenu et son ordre de `0.5.0` sous le
  cadre commun ; « ⚠ Avertissement » passe avant le nom, dans l'en-tête.
- L'écran « Sécheresse et restrictions » ne change pas, hors l'annonce « Retour »
  de sa barre de titre.

### Constaté à l'exécution

Constats du commanditaire, recopiés tels qu'il les a dits. Le code Dart de la
release Windows est celui de `data/app.so`, daté du 2026-10-18 à 23:54, après
le commit `7ce3f73` (23:44), dernier changement de `lib/`.

- Le 2026-10-19, sur Windows, exécutable de release lancé hors Flutter, code de
  `7ce3f73` (`P1`) : « c'est bon », précisé par question fermée — « Oui, tout
  vu » : constats `a` à `j` du cadrage (§ 10) vus et conformes, à la taille du
  lancement et à 800 × 740, texte à 100 % puis 200 %, dont `h` (zone cliente
  de 1 280 × 740) et `i` (« Retour » au Narrateur). Points vus en Segoe UI réelle (grille du
  sélecteur, rayon, ombre et couture du bloc, filet des fiches, tuiles de la
  fiche station, pilule à 800 × 740 et 100 %) : « Vus, conformes ». Aucun
  écart dicté.
- Rapporté le 2026-10-21, sur Android, émulateur Pixel_7, en débogage (`P2`) :
  « j'ai testé la 10 P2 c'est validé ». Aucun détail point par point ; la date
  du test n'est pas dite.
- Sur la construction du 2026-10-18 (23:54), sur Windows, dossier de
  publication de l'exécutable de release de `0.6.0` : **35 Mo**, 36 224 870 octets, 15 fichiers, budget de
  60 Mo tenu (`NFR-06`). Repère de `0.5.0` : 35 748 882 octets, 15 fichiers.
  Relevé par la boucle principale, non rapporté par le commanditaire.

### Non vérifié

- **Ce que « validé » ne dit pas, sur Android** : le détail de `P2` (constats
  `a` à `g` et `j`, police à 100 % puis 200 %, `g` en écran divisé) n'est pas
  rapporté ; la **version installée** sur l'émulateur n'a pas été relue par
  `adb` (émulateur éteint au moment du relevé) ; la **marge système** réelle du
  Pixel_7 (barre d'état, barre de navigation) n'a été ni relevée ni comparée à
  celle des tests (24 en haut, 48 en bas) — à 390 × 844 et 200 %, il ne reste
  que 6 px de jeu, et une marge réelle plus haute ferait défiler le bloc.
- **En deçà des quatre tailles garanties** : 360 × 300 (dont la limite
  acceptée à 200 %, fiche station ouverte, où la partie fixe n'a que 40 px) et
  les téléphones en paysage (600 et 640 × 360) ne sont pas constatés : la
  fenêtre minimale de Windows est de 800 × 740, et l'émulateur Pixel_7
  demanderait un écran divisé ou un autre profil (le détail de `g` n'est pas
  rapporté). Ils ne sont éprouvés qu'en test.
- **Aucune annonce à TalkBack constatée** ; au Narrateur, seul « Retour »
  (`i`) est constaté.
- **Mesures en Roboto** : les tests de disposition mesurent en Roboto,
  enregistrée sous le nom « Segoe UI » sous Windows ; **Segoe UI réelle** est
  vue à l'écran (`P1`), jamais mesurée.
- **Zone cliente de lancement** à 125, 150 et 200 % de mise à l'échelle de
  Windows : non constatée. La fluidité (`NFR-01`) n'est pas remesurée sur la
  disposition de `0.6.0`.
- **La porte de T2 n'est pas franchie** : `A1`, `E4`, `P1` et `P2` de T2
  restent dus (voir `0.3.0`). La **publication** Android reste différée :
  signature (`A⏸3`) et préversion (`A⏸5`) ; aucun appareil réel (`A⏸4`).
  **iOS** n'a jamais été compilé.

## [0.5.0] — 2026-10-17

Cinquième tranche (T4) : la vigilance crues publiée par Vigicrues, en
quatrième lecture de la carte. **Version datée du 2026-10-17**, après les
constats de la porte par le commanditaire. La porte de T4 est franchie sur les
deux cibles, Windows (exécutable de release lancé hors Flutter) et Android
(émulateur Pixel_7, en débogage) : « Constaté à l'exécution » recopie ce que le
commanditaire a dit, « Non vérifié » ce qu'il n'a pas dit. Aucun tag n'est posé
et la mise en production reste une décision du commanditaire ; la porte de T2
reste due. « Ajouté » est écrit d'après le code livré sur `feat/t4-crues` et
vérifié par `flutter test` ; seul ce que « Constaté à l'exécution » dit a été
vu à l'écran.

### Ajouté

- Quatrième lecture de la carte, « Vigilance crues » (`US-21`, `UC-009`) : une troisième puce
  d'échelle du sélecteur, qui efface les marqueurs et les pastilles des autres échelles (`BR-008`)
  et trace, pour chaque tronçon de cours d'eau suivi, le **niveau de vigilance publié par
  Vigicrues** : vert, jaune, orange, rouge, ou « Niveau non reconnu » en gris pointillé quand la
  valeur publiée est hors de 1 à 4, absente ou nulle (`BR-011`). Teinte, épaisseur et motif
  portent le niveau, le plus grave étant tracé au-dessus ; une jauge à barres le redit sans la
  couleur. L'application relaie le niveau publié, elle n'en calcule, n'en déduit ni n'en prévoit
  aucun, et ne rapproche jamais un débit, une hauteur ou un écoulement d'une crue (`BR-015`).
  Le sélecteur, qui compte désormais quatre puces (les trois échelles, puis « Restrictions »),
  prend une rangée de plus là où elles ne tiennent pas sur une seule (mesuré en test, en Roboto,
  non constaté à l'écran : 390 × 844 à 100 %, 360 × 640 à 200 %) : ce qui sort de la colonne du
  haut s'atteint en la faisant défiler. Un changement de taille de la fenêtre, ou une rotation de
  l'écran, remet à jour les étiquettes et l'avis du secteur de la lecture Crues sans qu'il faille
  déplacer la carte.
- Étiquettes des tronçons, posées selon le zoom : sous le zoom 9, seuls les tronçons non verts et
  ceux de niveau non reconnu en portent une ; à partir du zoom 9, chaque tronçon dont un segment
  coupe l'emprise, posée sur le point du trait visible le plus proche du centre. Une étiquette
  porte la jauge et le nom du niveau, se parcourt au clavier (Entrée ouvre la fiche) et
  s'annonce « crues : vigilance orange, <nom du tronçon> » ou « crues : niveau non reconnu,
  <nom du tronçon> ».
- Légende « Vigilance crues », qui cite les légendes publiées par Vigicrues pour chaque niveau,
  « Un cours d'eau sans trait de couleur n'est pas suivi par Vigicrues. », puis « Information de
  vigilance du JJ/MM/AAAA à HH:MM — © VIGICRUES » (`BR-001`). Pendant le premier chargement,
  elle ne porte ni date ni phrase de couverture.
- Avis de la lecture, qui ne laissent jamais une panne ou une absence passer pour une absence de
  risque (`BR-007`) : lecture en cours (« Lecture de la vigilance publiée par Vigicrues… Aucun
  tronçon n'est affiché tant qu'elle n'est pas lue. »), Vigicrues injoignable, réponse refusée
  ou illisible (« Réessayer » est alors la seule façon de relancer : un geste sur la carte ne
  relance rien), entités illisibles écartées et comptées (« 1 tronçon de vigilance non lisible. »
  ou « N tronçons de vigilance non lisibles. »), secteur sans tronçon suivi (« Aucun cours d'eau
  suivi par Vigicrues dans le secteur affiché. Cela ne dit rien du risque de crue : … »). Une
  réponse dont la date de l'information de vigilance est absente ou sans fuseau explicite est
  illisible pour toute la réponse : aucun trait n'est tracé (`BR-001`).
- Fiche du tronçon, ouverte en touchant un trait ou une étiquette (le tronçon dessiné le plus haut
  quand deux traits se superposent ; le tronçon retenu est celui touché à l'appui, même si la
  souris bouge avant le relâcher) : « Tronçon Vigicrues » et le nom publié, l'encart « CE N'EST
  PAS UN SYSTÈME D'ALERTE » (non repliable, annoncé en priorité au lecteur d'écran, `BR-015`), le
  niveau, la définition publiée par Vigicrues citée et suivie de « — Vigicrues », la date et
  « © VIGICRUES », puis « Lire le bulletin sur www.vigicrues.gouv.fr », qui ouvre le bulletin
  local du territoire hors de l'application ; si le lien ne s'ouvre pas, son adresse reste
  affichée, lisible et sélectionnable. Un niveau non reconnu est dit tel quel, sans citation. La
  fiche se ferme en ouvrant une autre fiche, un favori, en désignant un point ou en quittant la
  lecture : il n'y a jamais deux fiches ensemble. Dans l'autre sens, entrer sur la lecture Crues
  ferme les fiches station et ONDE, et ouvrir un favori station ou ONDE depuis la lecture Crues
  passe d'abord sur sa lecture — Débit pour une station, Écoulement pour un point ONDE —, puis
  ouvre sa fiche ; sur les deux autres lectures, ouvrir un favori ne change toujours ni la
  lecture ni la caméra.
- Contrôle « ⚠ Avertissement » : sur la lecture Crues, sa fenêtre ajoute le texte de crue sous le
  texte général ; la fiche du tronçon porte le sien. « D'où vient cette donnée ? » nomme Vigicrues.
- La feuille « Filtres » dit « Aucun filtre ne s'applique à la lecture Vigilance crues. » et n'offre
  aucun critère ; le bouton « Filtres » ne se montre pas actif sur cette lecture.
- Vigicrues n'est appelé qu'après la première activation de la lecture, avec un délai de 20
  secondes par tentative ; la carte lue est gardée 30 minutes pour la session. Passé ce délai,
  rien ne se met à jour de soi-même : l'ancienne vigilance reste tracée avec sa date, sans avis,
  et c'est un geste ou un changement de taille de la carte, sur la lecture Crues, qui lance
  un rafraîchissement en fond — un seul à la fois, retenté au geste suivant s'il échoue ; la
  nouvelle vigilance paraît au geste qui suit la fin de ce rafraîchissement. Rien n'est conservé au-delà de la session.

### Constaté à l'exécution

Constats du commanditaire du 2026-10-17, recopiés tels qu'il les a dictés. Le
code Dart de la release est celui de `data/app.so`, daté du 2026-10-17 à 19:58
(après le dernier changement de `lib/`).

- Le 2026-10-17, sur Windows, exécutable de release lancé hors Flutter
  (`P1-a` à `P1-g`) : « p1-a ok » · « p1-b ok » · « p1-c ok » · « p1-d ok » ·
  « p1-e ok » (écrit d'abord « ij », une faute de frappe confirmée par le
  commanditaire) · « p1-f ok » · « p1-g ok ». Aucun détail point par point.
- Le 2026-10-17, sur Android, émulateur Pixel_7, en débogage (`P2-a` à
  `P2-g` et `P2-i`) : « p2-a: ok » · « p2-b :  ok » · « p2-c : ok » · « p2-d: ok »
  · « p2-e: ok » · « p2-f: ok » · « p2-g: ok » · « p2-i: ok ». La version 0.4.0
  de T3 était restée installée avant ce lancement ; la boucle principale a lu
  par `adb` la version `0.5.0` installée (quatre puces sur la capture).
- Le 2026-10-17, sur Windows, en `--profile`, sonde de fluidité (`NFR-01`),
  sur la lecture « Vigilance crues » (déclaration du commanditaire : il a refait
  `G1`, `G2` six crans et `G3` sur cette lecture), chiffres lus à l'écran par la
  boucle principale : `G1` 185 trames, rastérisation p50 1,5 ms / p90 1,7 ms,
  0,0 % en retard ; `G2` 81 trames, p50 1,6 ms / p90 1,9 ms, 0,0 % en retard,
  11 appels au dépôt de points pour 6 crans ; `G3` 194 trames, p50 1,2 ms /
  p90 2,4 ms, 0,0 % en retard. Seuils tenus ; aucune tâche d'anti-rebond
  n'est ouverte. Durée du premier chargement : « bon », non chronométrée.
  Survol de la vue nationale : « assez bien ». Une première mesure, dont la
  lecture active n'était pas certaine, n'est pas retenue.
- Le 2026-10-17, « G2 impossible » : la boucle principale a lu la cause dans
  le code, la butée de zoom voulue (`maximumMapZoom` = 18, choix du
  2026-09-13), appliquée par `flutter_map` 8.3.2 ; ce n'est ni un défaut ni
  propre à T4 (même butée sur la lecture Écoulement).
- Le 2026-10-17, sur Windows, dossier de publication de l'exécutable de
  release de `0.5.0` : **35 Mo** (`du -sh`), 35 748 882 octets (`du -sb`),
  15 fichiers (4 à la racine et `data/`), budget de 60 Mo tenu (`NFR-06`).
  Repère de `0.4.0` : 35 634 194 octets, 15 fichiers. Relevé par la boucle
  principale, non rapporté par le commanditaire.

### Non vérifié

- **Point 64 à l'écran** : le recouvrement des puces et du « ⚠ Avertissement »
  de la carte par la fiche tronçon est accepté en constat par le commanditaire
  (arbitrage du 2026-10-16) et figé par test ; le commanditaire n'a rien dicté
  à l'écran, ni sur Windows ni sur Android. Constat d'écran non fait.
- **Niveaux 2 à 4 en production** : aucun épisode de crue n'a été signalé ;
  `P1-j` et `P2-j` sont sans objet. Une étiquette « Jaune », « Orange » ou
  « Rouge » réelle et sa fiche n'ont jamais été vues ; ces niveaux ne
  s'éprouvent que par des cas construits dans les tests (`VC-04`).
- **Ce que les constats en bloc ne disent pas** : le commanditaire a écrit
  « ok » par lettre ; le détail de ce qu'il a regardé n'est pas rapporté. La
  mesure du premier chargement n'est pas chronométrée.
- **Aucune annonce au lecteur d'écran constatée** : ni Narrateur (Windows) ni
  TalkBack (Android) ; l'annonce des étiquettes et de l'encart est lue dans le
  code et éprouvée en test seulement.
- **Mesures en Roboto**, la police d'Android ; sous Windows, enregistrée sous
  le nom « Segoe UI », un substitut : **Segoe UI réelle n'est pas mesurée**.
- **Rythme de publication de Vigicrues** et **comportement sur Android au-delà
  du lancement** : non vérifiés (`docs/sources/vigicrues.md`). `NFR-01` n'est
  pas mesuré sur Android ; aucun appareil réel (`A⏸4`).
- **La porte de T2 n'est pas franchie** : `A1`, `E4`, `P1` et `P2` de T2
  restent dus (voir `0.3.0`). La **publication** Android reste différée :
  signature (`A⏸3`) et préversion (`A⏸5`). **iOS** n'a jamais été compilé.

## [0.4.0] — 2026-10-14

Quatrième tranche (T3) : les favoris, les filtres de la carte et le critère
de fraîcheur du débit. **Version datée du 2026-10-14**, à la demande du
commanditaire, après ses confirmations **en bloc** des constats de la porte.
La porte de T3 est franchie sur les deux cibles, Windows (exécutable de
release lancé hors Flutter) et Android (émulateur, en débogage), constats
confirmés en bloc par le commanditaire : « Constaté à l'exécution » dit ce
qu'il a confirmé, « Non vérifié » ce qu'il n'a pas dit. Aucun tag n'est posé
et la mise en production reste une décision du commanditaire ; la porte de T2
reste due (`A1`, `E4`, `P1`, `P2`). « Ajouté », « Modifié » et « Corrigé »
sont écrits en une fois, d'après le code livré sur
`feat/t3-favoris-filtres` (50 tâches closes sur 50, dont `C1`, `P1` et `P2`
dans leur forme en bloc), et vérifiés par `flutter test` ; seul ce que
« Constaté à l'exécution » dit a été vu à l'écran. « Modifié » et « Corrigé »
disent ce qui change par rapport à `0.3.0`. Les trois dettes de T2 soldées en
T3 (plateforme des tests de widget, décisions sorties de la vue des
restrictions, barre de titre des écrans pleins partagée) sont des
remaniements sans effet observable : elles n'y figurent pas.

### Ajouté

- Étoile de favori dans le cadre des deux fiches, station hydrométrique et
  point ONDE (`US-14`, `UC-008`), sous le bouton de fermeture : pleine ou
  vide, annoncée « Ajouter aux favoris » ou « Retirer des favoris », lisible
  sans la couleur, atteinte par Tab et basculée par Entrée ou Espace, cible
  de 44 (48 sur Android). Un favori copie à l'ajout l'identité du lieu — son
  libellé ; pour un point ONDE, aussi son cours d'eau et son département — et
  sa date d'ajout, jamais une mesure. Ajouter une station demande que sa
  fiche soit prête ; une station déjà en favori garde son étoile pleine et se
  retire depuis sa fiche dans tous les états, même en échec ; sur une liste
  lisible, une station absente du référentiel embarqué qui n'est pas en
  favori n'a pas d'étoile. Un point ONDE s'ajoute quel que soit l'état de sa
  fiche. Une station et un point ONDE de même code sont deux favoris.
  L'étoile est inactive pendant une écriture ; tant que la liste enregistrée
  est illisible, elle est vide et inactive dans tous les états des deux
  fiches, station absente du référentiel ou fiche en chargement compris : la
  liste ne dit pas si le lieu y est. Une écriture en échec laisse l'étoile
  dans son état et le dit (« Le favori n'a pas pu être enregistré. », « Le
  favori n'a pas pu être retiré. »).
- Écran « Favoris » (`US-14`, `UC-008`), ouvert par le bouton « Favoris » de
  la carte : les lieux suivis, dernier ajouté en tête, chacun par son
  identité seule — libellé, nature (« Station hydrométrique », « Point
  ONDE »), cours d'eau et département d'un point ONDE, « Ajouté le
  JJ/MM/AAAA » —, et **aucune valeur mesurée**, ce que la liste dit en tête.
  Un favori se retire depuis sa ligne, par un bouton que le lecteur d'écran
  annonce « Retirer des favoris : » suivi du nom du lieu, ou « Retirer ce
  favori non lisible » (arbitrage du commanditaire du 2026-10-14) ; l'ouvrir
  referme l'écran et ouvre sa fiche, sans déplacer la carte ni changer
  l'échelle ou le filtre. Ouvrir l'écran ferme la fiche ouverte. Liste vide :
  une phrase dit comment un favori s'ajoute. Liste enregistrée illisible :
  elle est dite telle, jamais montrée vide, gardée telle quelle, et ne se
  remplace que par l'action explicite « Repartir d'une liste vide », qui
  annonce l'effacement des favoris enregistrés. Une entrée que cette version
  ne sait pas lire reste affichée (« Favori non lisible par cette version de
  l'application »), retirable, non ouvrable, et réécrite telle quelle
  (`BR-011`). Lignes et actions atteintes au clavier, cibles de 44 (48 sur
  Android). L'écran n'a pas de contrôle « ⚠ Avertissement » : il ne montre ni
  mesure ni état ; les fiches qu'il ouvre le portent (arbitrage du
  commanditaire du 2026-10-14).
- Favoris retrouvés d'un lancement à l'autre, sur l'appareil, sans compte ni
  serveur : `shared_preferences`, une clé, une forme JSON versionnée
  (`ADR-011` amendé le 2026-10-12, aucune dépendance ajoutée).
- Feuille « Filtres » (`US-13`, `UC-007`), ouverte par le bouton « Filtres »
  de la carte : sur l'échelle écoulement, six cases d'état, une par
  catégorie, « Non renseigné » comprise, toutes cochées au départ ; sur les
  deux échelles, un département ou « Tous les départements » ; sur l'échelle
  débit, la fraîcheur de la mesure : « Toutes », « Moins de 2 h », « Moins de
  24 h » (bornes de `BR-005`). Aucun critère d'état sur le débit (`BR-003`) ;
  sur l'écoulement, aucun critère de fraîcheur : la feuille dit que la carte
  ne montre que les campagnes des 60 derniers jours. « Appliquer »,
  « Effacer » (tous les critères, des deux échelles) et « Fermer » (rien ne
  change). Le filtre vaut pour la session : il survit au changement
  d'échelle et à un écran plein, pas à un relancement. Le type de donnée
  reste choisi par les puces d'échelle (`BR-008`).
- Ce que le filtre ne masque pas (`BR-007`, `BR-009`) : un lieu dont l'état
  n'est pas connu reste affiché — station dont la mesure n'est pas encore
  chargée, en échec ou sans donnée, lieu sans département. Sous le zoom 9,
  une pastille ne compte que les lieux retenus et une pastille vidée n'est
  pas dessinée, sauf pour le critère de fraîcheur, qui ne s'applique pas aux
  pastilles de débit. La feuille dit ces deux limites du critère de
  fraîcheur. Une fiche ouverte reste ouverte quand le filtre masque son lieu.
  Le préchargement des mesures de débit ne porte que sur le département
  choisi.
- Bouton « Filtres » qui montre un filtre actif (`BR-007`) : dès qu'un
  critère est actif pour l'échelle affichée, il change de forme — icône et
  fond pleins, marque ronde au coin —, à tous les zooms, et s'annonce
  « Filtres — un filtre est actif ».
- Avis de carte vidée par le filtre : « Les filtres masquent tous les lieux
  du secteur affiché. Cela ne dit rien de l'état des cours d'eau. », avec
  l'action « Effacer les filtres », atteinte au clavier. Il ne prend jamais la
  place d'un avis d'absence, qui reste décidé sur les lieux lus, filtre actif
  ou non ; une panne de source parle seule.
- Deux boutons en bas à droite de la carte, au-dessus de `+`, `−` et
  recentrer : « Favoris », puis « Filtres » (arbitrage 8 du cadrage, ordre
  confirmé le 2026-10-14), cibles de 44 (48 sur Android).
- Documentation : `UC-007` « Filtrer la carte », `UC-008` « Suivre un lieu en
  favori », `filtres.feature` (21 scénarios) et `favoris.feature` (14),
  `BR-007`, `BR-008` et `BR-009` amendées pour le filtre de l'usager,
  `ADR-011` amendé pour les favoris, matrice de traçabilité de T3.

### Modifié

- « La légende défile » (arbitrage du commanditaire du 2026-10-12) : la
  colonne du haut à droite de la carte (avertissement et légende ; au
  téléphone, la colonne unique avec les puces et les avis) s'arrête
  au-dessus de la colonne du bas à droite et défile quand elle ne tient
  plus : rien de ce qui s'y voit ne passe plus sous les contrôles de zoom ni
  sous l'attribution. L'écart à `BR-008` accepté le 2026-10-03 demeure — sous
  600 px, un avis affiché repousse toujours la légende, qui se lit alors en
  faisant défiler la colonne ; seul disparaît le recouvrement de la légende
  repoussée, par les contrôles de zoom (et, à 200 %, par l'attribution). Sur
  une fenêtre trop courte pour elle, la légende n'est plus entière au repos,
  avis ou non, et défile. Au téléphone à 200 %, un avis n'est plus entier au
  repos : il s'amène en faisant défiler la colonne. Sur une fenêtre de
  téléphone très courte (écran divisé), le haut ne garde que
  « ⚠ Avertissement » et la colonne du bas à droite défile, ancrée en bas
  (décision de la boucle principale).
- Ordre de tabulation de la carte : les puces d'échelle, l'action de l'avis
  affiché (« Effacer les filtres » ou « Élargir la recherche » ; rang arbitré
  par le commanditaire le 2026-10-14), « Favoris », « Filtres » (rang posé
  avec le groupe d'entrée), `+`, `−`, recentrer, le bouton de désignation en
  mode « Restrictions », la carte, la fiche ouverte, puis
  « ⚠ Avertissement ».
- Outillage, pour l'intégrateur : Flutter 3.47.7 et Dart 3.13.5 (3.47.4 et
  3.13.3 pour `0.3.0`), gardés par arbitrage du commanditaire du 2026-10-14 ;
  `pubspec.yaml` ne change que de version. `pubspec.lock` change la version
  de onze paquets — les deux directs, `shared_preferences` 2.5.6 et
  `url_launcher` 6.3.3, et neuf transitifs, `archive`, `code_assets`,
  `hooks`, `jni`, `jni_flutter`, `meta`, `objective_c`, `record_use` et
  `vector_math` —, dont six servent à la construction native (`jni`, greffon
  natif compilé pour Windows et Android ; `jni_flutter`, Android ;
  `objective_c`, cibles Apple ; `hooks`, `code_assets` et `record_use`,
  protocole des hooks de construction du code natif) : la prochaine
  construction Windows de release et la première construction Android se
  feront avec eux.

### Corrigé

- Une fiche plus haute que la carte (police à 200 %, téléphone en paysage)
  débordait de l'écran et son bas était hors de portée — défaut antérieur à
  T3, déjà dans `0.3.0`, mesuré par test : la zone des fiches est bornée à la
  hauteur de la carte et défile (arbitrage du commanditaire du 2026-10-13).
  Une fiche s'ouvre toujours par son haut, et ce qui s'en voit ne passe plus
  sous le bandeau d'attribution IGN, dont la marge suit désormais la hauteur
  réelle. En mode « Restrictions », une fiche haute masque toujours le bouton
  de désignation.
- « Élargir la recherche », l'action de l'avis d'absence, n'était pas
  atteignable au clavier (depuis `0.2.0`) : c'est désormais un arrêt de Tab,
  juste après les puces.

### Constaté à l'exécution

Constats du commanditaire du 2026-10-14, tous **confirmés en bloc** : il a
écrit « j'ai testé c'est bon » pour `C1` et `P2`, puis « c'est bon » pour
`P1`, sans détail **point par point** ; ce qu'il n'a pas dit est écrit dans
« Non vérifié ». Le code est celui de la branche à ces heures (sommet
`e2cd338`, puis `fe793bd`, dont les fichiers sous `lib/` sont ceux de
`e2cd338`).

- Le 2026-10-14, sur Windows, en débogage (`C1`) : « j'ai testé c'est bon »,
  et parmi les réponses proposées il confirme en bloc les filtres sur
  l'écoulement — décocher une catégorie masque ses marqueurs et le bouton
  « Filtres » change de forme (`a`) ; les pastilles de département et de
  région suivent le filtre (`b`). Le secteur, les catégories vues, les
  comptes et les symboles d'une pastille avec et sans filtre, et la pastille
  disparue ne sont pas relevés.
- Le 2026-10-14, sur Android, dans l'émulateur Pixel_7, en débogage (`P2`) :
  « j'ai testé c'est bon », et parmi les réponses proposées il confirme en
  bloc « L'application s'est construite et lancée sur Pixel_7, et les écrans
  de T3 fonctionnent au toucher. » C'est la première construction Android dont
  le lancement est confirmé : l'APK de débogage de `0.4.0` est daté du
  2026-10-14 à 15:11:49 (71 882 325 octets, relevé par la date de
  l'artefact). Le détail point par point n'est pas rapporté.
- Le 2026-10-14, sur Windows, exécutable de release lancé hors Flutter
  (`P1`) : le commanditaire construit la release (`flutter build windows
  --release`), lance `./build/windows/x64/runner/Release/martinpecheur.exe`
  hors de toute session de développement, regarde les écrans de T3 (`P1-c`
  à `P1-k`) et écrit « c'est bon » : confirmation en bloc, sans détail. La
  ligne finale `Built …` et la durée de la construction ne sont pas
  rapportées ; l'exécutable daté du 2026-10-14 à 15:53:06 atteste la
  construction.
- Le 2026-10-14, sur Windows, dossier de publication de l'exécutable de
  release de `0.4.0` : **35 Mo** (`du -sh`), 35 634 194 octets (`du -sb`),
  15 fichiers, dont `flutter_windows.dll` 21 274 112 octets et le référentiel
  des stations 6 604 249 octets ; budget de 60 Mo tenu (`NFR-06`). Repère de
  `0.2.0` : 33 Mo, 14 fichiers. Relevé par la boucle principale sur le poste,
  non rapporté par le commanditaire.

### Non vérifié

- **Ce que la confirmation en bloc ne dit pas.** Le commanditaire n'a pas
  rapporté, point par point, `P1-c` à `P1-k` (Windows, release) ni `P2-c` à
  `P2-j` (Android) ; ces derniers, hors `P2-g`, sont rangés sous « les écrans
  de T3 fonctionnent au toucher » par la boucle principale, ce que le
  commanditaire n'a pas dit. **Ne sont pas dits** : `P1-m` (réseau coupé :
  la liste « Favoris » s'affiche, ouvrir un favori station montre l'échec
  nommé, l'étoile reste pleine et se retire) ; `P2-g` (deux favoris
  retrouvés après fermeture et relancement, sur Android) ; `P2-m` (mode
  avion) ; pour `P2-l`, la durée de la construction, sa dernière ligne et le
  premier écran ; pour `P1-g`, s'il restait un point ONDE à l'écran. Le
  secteur, les comptes et les symboles de `C1` ne sont pas relevés non plus.
- **La porte de T2 n'est pas franchie** : `A1`, les deux constats manquants
  de `E4` et sa réserve, `P1` et `P2` de T2 restent dus (voir `0.3.0`). Une
  construction Android est constatée le 2026-10-14, sur le code de `0.4.0` et
  non de `0.3.0` ; ce qu'il en advient pour `A1` revient au commanditaire.
  Les écrans de T2 ne sont toujours pas nommés par un constat sur Android ni
  en release. Aucun exécutable de release de `0.3.0` n'est construit.
- **Effets de mise en page mesurés en test, à constater à l'écran** : au
  téléphone à 200 %, « La légende défile » laisse l'avis de carte vidée coupé
  au repos, son action « Effacer les filtres » hors de vue ; sur une fenêtre
  de téléphone très courte (360 × 300, écran divisé), le haut ne garde que
  « ⚠ Avertissement » et l'on ne change d'échelle qu'en faisant glisser
  depuis lui ; au téléphone en paysage (640 × 360 et 600 × 360), « Favoris »
  dépasse de 12 px par le haut de sa fenêtre et s'atteint en défilant, la
  légende n'étant pas visible au repos ; la fiche et le bandeau d'attribution
  se touchent bord à bord quand la marge suit le bandeau ; en mode
  « Restrictions », la fiche perd 28 px de hauteur même là où elle ne recoupe
  pas le bandeau. Trois constats acceptés par le commanditaire le
  2026-10-14, à voir à la porte Android et que sa confirmation en bloc du
  même jour ne nomme pas : à 360 × 640 et 100 %, l'avis d'absence
  « écoulement » dépasse de 8 px, son action restant atteignable ; à 200 %
  sur fenêtre courte, la puce « Restrictions », seule sortie du mode, est
  coupée plus tôt (52 % atteignables à 360 × 568, rien à 360 × 540) ; à
  360 × 640 et 200 %, le constat `d` ne tient pas (193 px à défiler). Aucun
  de ces effets n'est donc constaté à l'écran.
- **Mesures en Roboto**, la police d'Android, chargée depuis le SDK Flutter ;
  sous Windows, enregistrée sous le nom « Segoe UI », un substitut : **Segoe
  UI réelle n'est pas mesurée**.
- **Aucune annonce au lecteur d'écran constatée** : ni l'étoile, ni
  « Filtres — un filtre est actif », ni les états de la liste, ni le retrait
  d'un favori de la liste, qui nomme le lieu depuis l'arbitrage du
  commanditaire du 2026-10-14.
- **Stockage des favoris** : la tenue d'un lancement à l'autre est éprouvée
  par les tests du dépôt, contre un double et contre le magasin de test du
  paquet, et confirmée en bloc sous Windows en release (`P1-g` parmi
  `P1-c` à `P1-k`, sans détail) ; sur Android, `P2-g` n'est pas dit. Aucune
  écriture refusée n'est provoquée sur une cible. Non trouvés dans les
  paquets relus le 2026-10-12 (`ADR-011`) : la taille maximale d'une valeur
  `shared_preferences`, et ce que devient une écriture interrompue par une
  fermeture brutale.
- **Départements** : la liste de la feuille vient du référentiel des
  stations ; qu'un département qui porte un point ONDE porte aussi une
  station de ce référentiel n'est pas vérifié — un département qui n'en
  porterait aucune ne serait pas proposé (lu dans le code).
- **Décisions de la boucle principale, à confirmer à l'écran** : l'étoile
  sous le bouton de fermeture de la fiche, et non à côté ; « Appliquer » en
  couleur d'action principale ; sur une fenêtre courte, le haut de la carte
  qui cède d'abord, jusqu'à une cible tactile ; le texte « La liste n'a pas pu
  être remplacée. » (échec de « Repartir d'une liste vide »), venu du plan et
  non du cadrage. La confirmation en bloc de la porte ne les nomme pas : le
  commanditaire ne les a pas confirmées une à une.
- Les 21 scénarios de `filtres.feature` et les 14 de `favoris.feature` sont
  lus et vérifiés en structure par test, **jamais exécutés**.
- **Android** : une construction de débogage est lancée sur l'émulateur
  Pixel_7 le 2026-10-14 (voir « Constaté à l'exécution »), en bloc ; ni les
  cibles de 48, ni la persistance des favoris (`P2-g`), ni le mode avion
  (`P2-m`) ne sont dits. Aucun appareil réel (`A⏸4`), aucune construction
  Android de release. La **publication** Android reste différée : signature
  (`A⏸3`) et préversion (`A⏸5`). **iOS** n'a jamais été compilé, faute
  d'hôte macOS.
- **Fluidité de la carte (`NFR-01`)** : la seule mesure date du 2026-09-27
  (Windows, `--profile`, `docs/nfr.md`) ; aucune mesure n'est consignée depuis.
- **Hors T3, dits tels** : la courbe de débit (`US-11`), la recherche
  (`US-16`), `integration_test/` et le recentrage de la carte sur un favori
  sont renvoyés à une tranche ultérieure.

## [0.3.0] — 2026-10-09

Troisième tranche (T2) : la sécheresse et les restrictions, lues sur VigiEau
au point que l'usager désigne sur la carte. **Version datée le 2026-10-09
sans que la porte de T2 soit franchie**, par décision du commanditaire du
même jour, **et pas publiée** : le code est écrit et vérifié par
`flutter test`, mais aucun exécutable de release de `0.3.0` n'est construit,
aucune construction Android n'est consignée ni constatée à l'écran (voir « Non vérifié »), et **les
écrans de T2 ne sont constatés qu'en partie** : par le commanditaire, en
débogage sur Windows, le 2026-10-04 (« Constaté à l'exécution » dit ce qui a
été vu, « Non vérifié » ce qui manque). Aucun ne l'est sur l'exécutable de
release ni sur Android. La porte (exécutable Windows lancé hors outil,
constat Android : `P1`, `P2`) reste due : dater la version ne la remplace
pas. Les quatre avertissements sont posés dans le code ; la mise en
production reste une décision du commanditaire, et la publication Android
(`A⏸3`) n'est pas faite. « Modifié » et « Corrigé » ne décrivent que ce qui
change par rapport à `0.2.0` publiée : les corrections faites pendant la
tranche sur du code jamais publié (le bouton de désignation, les écrans de
T2) n'y figurent pas.

### Ajouté

- Écran « Sécheresse et restrictions » (`US-07`, `UC-002`), ouvert par la
  désignation d'un point : il nomme le point, la source VigiEau et la date
  de la réponse obtenue, puis liste **toutes** les zones d'alerte du point —
  eaux superficielles d'abord, puis eaux souterraines, eau potable et type
  de zone non renseigné —, chacune en carte, sur une colonne de lecture de
  760 px, avec son niveau de gravité (vigilance, alerte, alerte renforcée,
  crise, ou « Non renseigné » quand la source n'en donne pas ou en donne un
  que l'application ne connaît pas, `BR-011`) en badge de forme et de teinte
  accompagné de son libellé, daté du début de validité de son arrêté. Aucune
  zone n'est écartée ni résumée en « la » zone du point (`BR-007`), aucune
  n'est comparée à une autre. Sans zone d'eaux superficielles (cas jamais
  constaté par appel réel), l'écran le dit d'abord, ajoute la phrase de
  `BR-007`, puis présente toutes les zones sous « Zones d'alerte à ce
  point » ; il tait ces deux phrases quand une zone est de type non reconnu,
  l'application ne sachant pas si elle est d'eaux superficielles (`BR-011`).
- Usages restreints selon le profil d'usager (particulier, exploitation,
  collectivité, entreprise) : **aucun profil n'est présélectionné**, les
  usages n'apparaissent qu'après le choix, cités tels que transmis par
  VigiEau, l'écran rappelant que seul l'arrêté fait foi (`BR-014`). Le choix
  est gardé pour la session. Un seul appel par point : changer de profil n'en
  refait pas.
- Arrêtés (`US-08`) : une carte par arrêté, dédoublonnés par adresse, avec
  les zones qu'il régit ; ses dates de validité ne s'affichent que si toutes
  ses zones les partagent, et jamais pour l'arrêté-cadre. « Ouvrir
  l'arrêté » et « Ouvrir l'arrêté-cadre » ouvrent le document **hors de
  l'application**, l'adresse restant toujours affichée, même si l'ouverture
  échoue.
- Couleur des actions principales (« Ouvrir l'arrêté », « Restrictions au
  centre de la carte ») : `#0B5E86`, texte blanc dessus. Rapport de contraste
  calculé de 7,0957:1 (formule WCAG, recalculé le 2026-10-04) ; seul le seuil
  de 7:1 est verrouillé par test.
- Absence et échec nommés (`BR-007`) : phrase d'absence quand VigiEau ne
  renvoie aucune zone ; source injoignable, requête refusée, réponse
  illisible et échec imprévu distingués, sans jamais afficher un niveau
  inventé. Une réponse obtenue est gardée en mémoire le temps de la session
  et affichée avec sa date de récupération ; au-delà de six heures elle est
  servie datée pendant qu'elle est redemandée. Rien ne survit à un
  relancement.
- Encart renforcé, quatrième avertissement (`US-09`, `BR-013`), en tête de
  l'écran des restrictions dans tous ses états — avant même la réponse, et
  quand la source ne répond pas — : non repliable, déclaré région d'alerte,
  avec l'action « Consulter les arrêtés en vigueur » qui ouvre le site public
  de VigiEau hors de l'application.
- Écran « D'où vient cette donnée ? » (`US-01`, `BR-012`) : les quatre
  sources nommées (Hub'Eau hydrométrie, Hub'Eau écoulement ONDE, VigiEau,
  IGN Géoplateforme), leurs licences telles que relevées, leurs limites.
  Accessible depuis la fenêtre « ⚠ Avertissement » de la carte et de chaque
  fiche ; le lien « Relire le détail des sources », retiré en `0.2.0`, revient
  dans le modal du premier lancement et ouvre cet écran **sans acquitter** :
  la version du texte acquitté ne change pas, personne n'est réinterrogé.
- Choix « Restrictions » dans le sélecteur de la carte, à côté des deux
  échelles : un interrupteur indépendant, l'échelle choisie reste affichée
  avec ses marqueurs et sa légende (`BR-008`). Actif, il fait apparaître le
  bouton « Restrictions au centre de la carte », son indice de geste et un
  réticule au centre de la carte ; inactif, ni bouton ni réticule.
- Désignation d'un point : appui long (toucher) ou clic droit (souris), dans
  les deux modes, ou bouton, qui désigne le centre de la carte. Une épingle
  marque le point jusqu'à la désignation suivante.
- Dépendance ajoutée : `url_launcher` 6.3.2 (BSD-3-Clause, Windows et
  Android, relevée sur pub.dev le 2026-09-27), derrière un port du domaine ;
  le manifeste Android déclare la requête de visualisation en `https`.
- Documentation : faits VigiEau relevés par appel réel le 2026-09-27 et seize
  réponses gardées en fixtures datées (`docs/sources/vigieau.md`, `VG-01` à
  `VG-11`, puis `VG-12` le 2026-10-03), modèle du domaine, conception de
  l'écran, 30 scénarios Gherkin (`restrictions.feature`), matrice de
  traçabilité de T2.

### Modifié

- Marqueurs de carte à 26 px avec un liseré blanc de 2 px (refonte visuelle
  du 2026-09-29, option A d'un canvas de design).
- Aux largeurs de téléphone (moins de 600 px), le contrôle
  « ⚠ Avertissement », les puces, l'avis d'absence ou de panne et la légende
  forment une seule colonne alignée à droite et défilante ; le libellé du
  contrôle se replie. La légende n'est repoussée sous l'avis que pendant
  qu'un avis s'affiche : écart à `BR-008` accepté le 2026-10-03.
- La colonne gauche de la disposition large défile quand la hauteur manque,
  sans capter les gestes hors de ses enfants.
- Cibles tactiles de 48 sur Android, 44 ailleurs (`T2-K4`) : ce que `0.2.0`
  listait comme non vérifié est codé, **pas constaté**.
- Fenêtre Windows : zone cliente minimale portée de 800 × 700 à 800 × 740.
- Hub'Eau et VigiEau : chaque tentative d'appel est bornée et rejouée comme
  une panne réseau (arbitrages du commanditaire, 2026-10-06) : **20 s pour
  Hub'Eau** (hydrométrie v2 et écoulement ONDE v1) et **10 s pour VigiEau**.
  Le matin du même jour la borne était de 10 s pour les deux ; elle est portée
  à 20 s pour Hub'Eau le soir, le balayage ONDE national ayant été mesuré à
  10,26 s. Sans borne, un serveur qui acceptait la connexion sans répondre
  laissait l'écran en attente sans fin. Pire cas avant l'échec, avec quatre
  tentatives : 83,5 à 87 s pour Hub'Eau, 43,5 à 47 s pour VigiEau ; un serveur
  lent mais vivant, qui répondrait en plus de 20 s (Hub'Eau) ou de 10 s
  (VigiEau), échoue désormais. Une tentative qui dépasse son délai est
  **annulée** : le
  client ferme sa connexion, que le serveur n'ait pas encore répondu ou qu'il
  cale en plein corps ; la phase de connexion (DNS, connexion TCP, poignée de
  main TLS) n'est pas annulée, pas plus qu'une redirection suivie vers une
  autre origine (autre hôte, autre port ou autre schéma) tant que les
  en-têtes de la réponse redirigée ne sont pas arrivés. Établi contre un
  serveur local et, pour les délais, par test en temps simulé, jamais sur une
  API réelle.
- Surcouches de la carte (colonnes gauche et droite, colonne unique des
  largeurs de téléphone, bande du bouton de désignation) : plus de barre de
  défilement de bureau ; quand l'une déborde, elle défile à la molette posée
  sur un de ses enfants et au clavier, sans indice visuel. La colonne de
  droite (avertissement et légende) ne capte plus les gestes que sur ses
  enfants. Vérifié par test, non constaté à l'écran.

### Corrigé

- Aux largeurs de téléphone, les puces d'échelle et le libellé du contrôle
  « ⚠ Avertissement » débordaient de l'écran (mesuré en test, sur le code de
  `0.2.0`) : voir la colonne unique de « Modifié ».
- Hub'Eau (lu dans le code de `0.2.0`) : le corps d'un échec HTTP qui n'était
  pas de l'UTF-8 valide, ou une réponse corrompue pendant le transfert (corps
  `gzip` invalide, redirection mal formée), faisait sortir une
  `FormatException` nue du client au lieu d'un échec rejouable. Le corps d'un
  échec est maintenant décodé avec tolérance (un `503` non UTF-8 est rejoué,
  un `400` non UTF-8 reste refusé) et la `FormatException` du transport est
  rejouée comme une panne réseau. Établi contre un serveur local, jamais sur
  Hub'Eau.
- Sur Windows, la colonne de droite de la carte (avertissement et légende),
  dont le code de `0.2.0` était un défilement opaque, absorbait clic droit,
  glisser et molette posés à gauche du contrôle d'avertissement (zone morte
  de 121 px mesurée par test sur l'échelle débit à 100 %) : lu dans le code,
  non constaté à l'écran.
- La caméra de la carte est contrainte au monde (arbitrage du commanditaire,
  2026-10-06). Le code de `0.2.0` ne contraignait rien (lu dans le code) : les
  flèches Haut et Bas poussaient sans borne le centre hors du monde, et après
  33 flèches Haut la carte ne rebougeait qu'à la 27e flèche Bas (mesuré par
  test sur le code de la branche ; défaut antérieur à la branche) ; avec le
  bouton « Restrictions au centre de la carte » de cette version, le point sous
  le réticule n'était plus celui qu'il désignait. Le bord de la caméra
  s'arrête désormais au bord du monde ; glisser, molette, boutons de zoom,
  recentrage et rotation sont contraints de même, et les cinq départements
  d'outre-mer restent atteignables. Un changement de taille de la fenêtre
  rejoue la contrainte : agrandir la fenêtre depuis le bord du monde ne laisse
  plus de vide au-delà. Vérifié par test, non constaté à l'écran ;
  deux limites sont écrites dans « Non vérifié ».

### Constaté à l'exécution

Les quatre constats du 2026-10-04 : par le commanditaire, sur Windows, **en
débogage** (`flutter run -d windows`), sur le code de ce jour (sommet
`ba5d079`). Celui du 2026-09-29 est antérieur : par le commanditaire, sur le
code de ce jour-là (correctif `bc81efe`), mode de lancement non consigné.
**Aucun de ces constats n'est fait sur l'exécutable de release ni sur
Android**, et le code a changé depuis (suites des deux relectures de la
PR #17) : aucun constat d'écran n'est rapporté depuis le 2026-10-04. Ce n'est
pas le constat d'une porte : celle de T2 n'est pas franchie (voir « Non
vérifié »).

- Le 2026-10-04, sur la carte : au lancement, trois puces, ni bouton ni
  réticule ; un appui sur « Restrictions » fait apparaître le bouton, son
  indice et le réticule, marqueurs et légende restant.
- Le 2026-10-04, désignation d'un point : le bouton, un appui long ou un
  clic droit ouvrent l'écran « Sécheresse et restrictions », l'encart
  renforcé en tête.
- Le 2026-10-04, sur l'écran des restrictions : les zones sont datées, eaux
  superficielles d'abord ; l'adresse de l'arrêté est lisible.
- Le 2026-10-04, « ⚠ Avertissement » mène à « D'où vient cette donnée ? »,
  où la molette posée sur la barre de titre fait défiler.
- Le 2026-09-29, constat antérieur : le défilement à la molette de l'écran
  des restrictions est constaté résolu.

### Non vérifié

- **La porte de T2 n'est pas franchie** : la version est datée sans elle,
  par décision du commanditaire du 2026-10-09. Restent dus : la première
  construction Android (`A1`) ; les deux constats manquants de `E4` et sa
  réserve (puce suivante) ; l'exécutable Windows de release lancé hors
  Flutter, ses sept constats d'écran, son poids et l'épreuve hors réseau
  (`P1`) ; le constat Android (`P2`) ; les constats d'écran dus depuis la
  revue de la PR #17 (plus bas).
- **Les écrans de T2 ne sont constatés qu'en partie** : par le commanditaire,
  en débogage (`flutter run -d windows`), sur Windows, le 2026-10-04 — ce
  qui a été vu est écrit dans « Constaté à l'exécution ». **Non
  constaté** : aucun profil présélectionné, puis les usages cités après le
  choix ; un point en mer et sa phrase d'absence ; l'encart « non
  repliable » (aucun moyen de le replier) ; le mode « Restrictions » conservé
  au retour de l'écran des restrictions. Le constat ne dit rien non plus de
  l'épingle du point désigné, de la taille minimale de fenêtre de 800 × 740,
  de la présentation des zones et des arrêtés en cartes, ni du lien
  « Relire le détail des sources » depuis le modal. Rien n'est constaté sur
  l'exécutable de release (`P1`) ni sur Android (`P2`). Le reste est vérifié
  par `flutter test`, pas à l'écran.
- **Aucune construction Windows de release de `0.3.0`** : pas d'exécutable
  de release lancé hors Flutter avec le code de T2 ; poids (`NFR-06`) et
  tenue hors réseau (`NFR-03`) non constatés pour T2.
- **Fluidité de la carte (`NFR-01`)** : la seule mesure date du 2026-09-27
  (Windows, `--profile`, `docs/nfr.md`) ; les marqueurs de carte ont été
  redessinés le 2026-09-29 (`c53c5d4`) et la fluidité n'a **pas été
  remesurée depuis**.
- **Android** : aucune construction n'est consignée ni constatée à l'écran.
  Un APK de débogage de `0.2.0` (`versionCode 2`) daté du 2026-09-27 est
  présent sur un poste, avec des traces de construction du 2026-09-29 sans
  APK ; qui l'a lancé, et ce qui a été vu, n'est écrit nulle part — question
  posée au commanditaire le 2026-10-04. Rien n'est donc constaté pour T2 sur
  Android (`A1`, `P2` dues) : ni la bibliothèque d'ouverture de lien, ni les
  cibles de 48 dp, ni l'appui long au toucher. Aucun appareil réel (`A⏸4`).
  La **publication** Android reste différée : signature (`A⏸3`) et
  préversion (`A⏸5`).
- **iOS** n'a jamais été compilé, faute d'hôte macOS.
- **Mesures aux largeurs de téléphone** (360 × 640 et 390 × 844, polices à
  100 et 200 %) faites en test, avec la police Roboto de Flutter, celle
  d'Android ; Windows rend en Segoe UI, **non mesurée**. Recouvrements
  mesurés et non corrigés : en mode « Restrictions » et à 200 %, le bouton
  recouvre l'action de l'avis ; en mode, l'avis recouvre le réticule (dès
  100 % à 360 × 640) ; sur fenêtre courte à 200 %, le bouton recouvre la
  puce « Restrictions », seule sortie du mode.
- **Ouverture de lien jamais éprouvée sur une cible** : aucun arrêté et
  aucun site public n'a été ouvert. Seuls deux PDF (un arrêté et un
  arrêté-cadre d'Ariège) ont reçu une requête d'en-tête, le 2026-09-27 : ils
  répondent `200`, `application/pdf`.
- **Aucune annonce au lecteur d'écran constatée** : ni la région d'alerte de
  l'encart renforcé, ni le bouton « Restrictions », ni les badges. Le bouton
  de retour des écrans pleins est vraisemblablement annoncé « Back » : aucune
  localisation française n'est configurée (relevé dans le code, non constaté
  au Narrateur).
- **Licences** : la licence de la donnée servie par l'API des restrictions
  n'est **pas établie** — l'API n'en déclare aucune (relevé du 2026-10-03) ;
  seuls le site VigiEau et son jeu de données publié sur data.gouv.fr sont
  sous Licence Ouverte 2.0, et l'écran des sources l'écrit ainsi. Pour
  Hub'Eau, la version de la Licence Ouverte n'est écrite nulle part :
  « Licence Ouverte Etalab », sans numéro.
- **API VigiEau** (version `0.1`, sans SLA) : faits relevés par appel réel
  sur quelques points seulement (Ain, Paris, Corse, Ariège, Guyane, un point
  en mer). `alerte_renforcee` n'a jamais été rendu par `/zones` à un point
  précis (cherché, non trouvé) : ce niveau n'est couvert que par une valeur
  dans le test du mapper. Un `409` par `lat`/`lon` jamais provoqué (vu
  seulement par `commune`) ; `429` et `5xx` jamais provoqués ; fenêtre exacte
  de `X-RateLimit-Reset` non déterminée (valeur `1` vue une fois, unité non
  déterminée) ; deux zones du même type au même point exact jamais
  rencontrées ; outre-mer autres que la Guyane non interrogés par point ; un
  arrêté expiré encore rendu : non vérifié, l'écran affiche les dates et ne
  filtre rien. Une date de validité écrite avec un décalage non nul n'a
  jamais été vue (seule la forme en `Z` l'est) : le mapper la garde telle
  qu'écrite, jamais convertie en UTC (arbitrage du 2026-10-06). Le `500` de
  `/api/zones` que le schéma décrit comme déterministe (plusieurs zones de
  même type au même point) est lu dans le schéma seul, jamais constaté par
  appel réel : la source le range avec les `5xx` rejouables, et un
  « Réessayer » échouerait toujours s'il existe. Le comportement du transport
  sur un corps `gzip` corrompu, une redirection mal formée, un schéma non HTTP
  ou un statut inférieur à 100 est établi contre un serveur local seulement.
- **Aucun percentile** (`ADR-003`, hors T2) et **aucune échelle
  « sécheresse » sur la carte** : un niveau de gravité ne se lit que sur
  l'écran des restrictions, jamais en marqueurs. Hors périmètre de T2, non
  livrés : position de l'appareil, repli data.gouv, conservation des
  restrictions au-delà de la session.
- **Quatre décisions de la boucle principale, confirmées par le
  commanditaire le 2026-10-06 au soir (elles ne sont pas pour autant
  constatées à l'écran)** : le mode « Restrictions » reste actif au retour de
  l'écran des restrictions ; la colonne gauche de la disposition large
  défile ; l'adresse du site public est un texte sélectionnable, non un
  lien, sur l'écran des sources ; les mesures de téléphone se font en
  Roboto.
- Les 30 scénarios de `restrictions.feature` sont lus et vérifiés en
  structure par test, **jamais exécutés** ; certaines phrases d'écran qu'ils
  citent ne sont liées au code par aucun test (`docs/project-state.md`,
  point 53).
- **Après la revue de la PR #17, traitée en grande partie le 2026-10-06 :
  constats d'écran dus, aucun n'est fait.** Par le commanditaire, sur Windows :
  un clic droit dans la bande du bouton de désignation, à côté du bouton ; un
  clic droit à gauche de « ⚠ Avertissement » sur l'échelle débit ; à
  800 × 740 et 200 %, la légende de l'échelle débit s'atteint-elle à la
  molette, sans barre ; le retour de l'écran des restrictions (son contenu
  reste pendant la sortie) ; redimensionner la fenêtre après avoir défilé ;
  l'avis de lien non ouvert amené dans le champ à chaque échec, y compris un
  second échec du même lien, et sous la carte pressée quand l'arrêté et
  l'arrêté-cadre ont la même adresse ; au zoom minimal, contre le bord nord du
  monde, la fenêtre agrandie en hauteur : aucun vide au-delà du monde, et un
  appui long tout en haut qui désigne un point du monde ; et, depuis la caméra
  contrainte au monde, au zoom minimal, la flèche Haut répétée : la carte
  s'arrête-t-elle au bord du monde et repart-elle à la première flèche Bas, et
  le bouton « Restrictions au centre de la carte » désigne-t-il le point sous le
  réticule. Tout cela est vérifié par `flutter test` seulement.
- **Segoe UI réelle n'est pas mesurée** : les verrous de gestes de la carte
  sont rejoués en plateforme Windows, mais les largeurs y sont mesurées en
  Roboto enregistrée sous le nom « Segoe UI », un substitut. L'annonce de
  l'avis de lien non ouvert (région d'alerte) par le Narrateur n'est pas
  constatée.
- **Limites connues, non traitées** : la caméra contrainte au monde a deux
  limites, jamais constatées à l'écran : sur une fenêtre de plus de 4 096 px de
  haut le dézoom vers le zoom 4 est refusé (le monde y fait 4 096 px ; établi
  par un test de caractérisation de `flutter_map` 8.3.2, le recalage au
  redimensionnement étant alors refusé de même, sans exception), et, pendant
  un redimensionnement continu de la fenêtre AU bord du monde, la carte se
  recharge à chaque pas, sans anti-rebond (mesuré par un relecteur dans une
  copie : dix pas de hauteur, dix chargements ; seuls garde-fous, le refus
  d'une emprise identique et le jeton de génération ; n'arrive qu'au bord du
  monde, hors de France) ; la phase de connexion d'une tentative d'appel (DNS,
  connexion TCP, poignée de main TLS) n'est pas annulée au délai (20 s pour
  Hub'Eau, 10 s pour VigiEau), seule la suite l'est (constaté pour la poignée
  de main TLS contre un serveur local, lu dans le paquet `http` pour le DNS et
  la connexion TCP), pas davantage une
  redirection suivie vers une autre origine (autre hôte, autre port ou autre
  schéma) tant que les en-têtes de la réponse redirigée ne sont pas arrivés :
  l'annulation détruit la connexion d'origine, laisse ouverte celle de la
  redirection et peut faire échouer une autre requête en vol qui réutilisait
  la connexion d'origine (constaté contre deux serveurs locaux le 2026-10-06 ;
  aucune des sources appelées ne redirige à ce jour) ; le délai de 10 s était
  trop court pour le balayage ONDE national, mesuré à 10,26 s le 2026-10-06
  (`docs/sources/onde.md`, `T-17` ; un échantillon, un jour, un poste) : le
  commanditaire a arbitré le soir même 20 s pour Hub'Eau et 10 s pour VigiEau
  (le passage à 30 s, d'abord arbitré puis retiré à sa demande avant tout
  commit, n'a pas été retenu). Le balayage mesuré passe à 20 s ; les trois
  appels de `T-17` restés sans réponse à plus de 60 s et l'appel écoulement de
  `T-18` sans réponse en 20 s seraient encore coupés ; le délai de 20 s n'est
  éprouvé que par test en temps simulé, jamais sur l'API réelle, et la
  composition réelle de `main.dart` n'est éprouvée par aucun test (lue
  seulement) ; « Réessayer » de l'écran des restrictions (VigiEau) n'apparaît
  qu'après 43,5 à 47 s si la source ne répond pas, le pire cas avant l'échec
  pour Hub'Eau étant de 83,5 à 87 s ; la carte d'un arrêté-cadre écrivait
  « S'applique à la même zone » sans dire laquelle quand il y a deux arrêtés
  de restriction : le commanditaire a arbitré de lister ses zones dès qu'il y a
  plusieurs arrêtés de restriction, **codé le 2026-10-06 au soir** (vérifié par
  test, non constaté à l'écran ; aucune réponse réelle gardée en fixture ne
  porte deux arrêtés de restriction à un même point). La phrase de `BR-007`
  écrite deux fois, sans zone d'eaux superficielles et avec un niveau de
  gravité non reconnu, est gardée telle quelle par arbitrage et verrouillée par
  un test depuis le 2026-10-06 au soir. Les autres constats de la revue
  (dédoublonnage des arrêtés et règle des dates décidés dans la vue, doublons
  de code) : `docs/project-state.md`, points 57 et 59.
- **Quatre décisions de la boucle principale du 2026-10-06, confirmées par le
  commanditaire le 2026-10-06 au soir (elles ne sont pas pour autant
  constatées à l'écran)** : une réponse corrompue pendant le transfert est une
  source injoignable rejouable, non plus une réponse illisible ; l'avis de
  lien non ouvert est une région d'alerte pour l'arrêté **et** le site public ;
  les surcouches de la carte n'ont plus de barre de défilement de bureau ; les
  phrases « sans zone d'eaux superficielles » sont écrites en place dans la
  vue, sans constante liée au `.feature` (`docs/project-state.md`, point 58 ;
  la cinquième décision d'origine, borner la latitude désignée plutôt que
  contraindre la caméra, est sans objet : le commanditaire a arbitré la
  contrainte).

## [0.2.0] — 2026-09-27

Deuxième tranche (T1) : la carte devient consultable — fiches, écoulement
observé, avertissements. **Ce n'est toujours pas un produit** : l'encart
renforcé de `BR-013` n'a pas d'écran en T1 (arbitrage du 2026-09-22), et
`CLAUDE.md` interdit toute mise en production avant T2. La porte de la
version (exécutable lancé hors outil, poids, hors réseau) est passée sur
Windows le 2026-09-27 (`P1`) ; les constats d'écran lot par lot sont dans
`docs/project-state.md`.

### Ajouté

- Fiche d'une station au tap : débit en m³/s et hauteur en m, chacun avec
  sa date et la source Hub'Eau nommée à côté (`BR-001`) ; état de fraîcheur
  de la mesure (`BR-005`) ; phrase d'absence quand la source ne répond pas
  ou qu'aucune mesure n'existe (`BR-007`).
- Écoulement observé (ONDE) : points sur la carte, six catégories
  distinguées par forme, teinte et motif, grisées au-delà de 60 jours
  (`BR-010`) ; fiche du point avec la date de campagne et les cinq dernières
  campagnes.
- Bascule entre l'échelle « écoulement » et l'échelle « débit » : une seule
  active, marqueurs et légende changent ensemble (`BR-008`).
- Avis d'absence et de panne sur la carte, qui nomment la source en cause ;
  nombre de points d'observation illisibles affiché.
- Avertissements (`BR-012`) : écran bloquant au premier lancement, bouton
  inactif tant que la case n'est pas cochée, acquittement enregistré sur le
  poste et redemandé si le texte change ; puis un contrôle
  « ⚠ Avertissement » toujours présent sur la carte et en tête de chaque
  fiche, qui ouvre le texte du premier lancement complété, sur une fiche
  datée, par sa phrase datée (arbitrage du 2026-09-23).
- Regroupement des marqueurs par zone administrative (`ADR-015`) : une
  pastille par région sous le zoom 7, par département de 7 à 9, marqueurs
  individuels au-delà ; la sélection d'une pastille zoome sur ses membres.
- Clavier et souris : boutons zoom avant, zoom arrière et recentrage
  (cibles de 44 pt), ordre de tabulation déclaré avec focus visible,
  flèches, `+`/`−`, `Entrée`, `Échap`.
- Fenêtre Windows : zone cliente minimale de 800 × 700.
- Sonde de fluidité de la carte (`NFR-01`), inerte sans
  `--dart-define=FLUIDITY_PROBE=true`.
- Documentation : critères d'acceptation en Gherkin français
  (`docs/acceptance/`), matrice de traçabilité US, BR, UC et tests
  (`docs/tracabilite.md`), toutes deux vérifiées par test.
- Cible Android réactivée le 2026-09-18 : gabarit de plateforme versionné.

### Modifié

- Architecture feature-first + MVVM (`ADR-014`) : un `ChangeNotifier` par
  écran, appelé par la vue, qui appelle son dépôt par un appel typé.
- Politique de cache (stale-while-revalidate) portée par un décorateur de
  dépôt, toujours en un seul composant.
- Heure des mesures affichée en heure locale, sans suffixe
  (« 27/08/2026 à 10:00 »).

### Corrigé

- Carte vide au lancement : un code de station ONDE hors de la forme
  attendue faisait tomber toute la page ; il est désormais conservé tel
  quel, et une ligne illisible est ignorée et comptée (`T-14`).
- 54 stations dont Hub'Eau inverse latitude et longitude (projection `31`)
  sont replacées en lisant leurs coordonnées X/Y (`C-18`).

### Retiré

- `lib/application/` : bus de messages, `Query`/`Command` et gestionnaires
  (`ADR-014`).
- Traces de l'ancienne architecture React Native : deux guides APK et six
  images héritées d'Expo (les ADR remplacés sont gardés).

### Constaté à l'exécution

- Exécutable Windows (`flutter build windows --release`, 21,1 s) produit et
  lancé **sans outil de développement** par le commanditaire le 2026-09-27.
  La ligne finale `Built` n'a pas été recopiée ; l'exécutable daté du jour
  atteste la construction.
- Dossier de publication : **33 Mo** (budget 60 Mo), 14 fichiers, dont
  `flutter_windows.dll` 21 Mo et le référentiel 6,4 Mo.
- Premier lancement : l'écran d'avertissement s'affiche, le bouton
  « J'ai compris ces limites » reste inactif tant que la case n'est pas
  cochée ; au lancement suivant, la carte vient directement. Éprouvé après
  effacement de l'acquittement déjà présent sur le poste.
- Le contrôle « ⚠ Avertissement » est présent sur la carte à tous les
  zooms ; sa fenêtre se lit en entier et se ferme par « Fermer ».
- Fiche d'une station : « ⚠ Avertissement » en tête, date de la mesure en
  heure locale, source nommée.
- Points ONDE sur l'échelle « écoulement », fiche avec sa date de campagne ;
  la bascule vers « débit » change marqueurs et légende ensemble.
- Clavier : focus visible au `Tab`, flèches, `+`/`−` ; la fenêtre refuse de
  descendre sous 800 × 700 ; le libellé « Avertissement » n'est pas tronqué.
- Hors réseau, carte réseau désactivée : les pastilles s'affichent, le fond
  de carte vient du cache sur les zones déjà parcourues, la fiche d'une
  station nomme la source injoignable.
- Fluidité (`NFR-01`), en `--profile`, rastérisation p90 / trames en
  retard : glisser au zoom départemental 6,4 ms / 2,5 % puis 2,1 ms / 0,0 %
  (deux essais) ; six crans de molette 2,4 ms / 2,2 %, avec 5 appels au dépôt
  de points ; glisser au zoom national 1,8 ms / 0,0 %. Seuils : 16,7 ms et
  5 %.

### Non vérifié

- **Fluidité (`NFR-01`) mesurée une seule fois**, le 2026-09-27, sur un
  seul poste Windows, en `--profile` : seuils tenus sur les trois gestes,
  sans campagne répétée. Rien n'est mesuré sur Android ni sur un appareil
  d'entrée de gamme.
- **`BR-013` reporté en T2** : le texte de l'encart renforcé est écrit et
  figé, mais posé sur aucun écran — aucun écran de ressource en T1
  (arbitrage du 2026-09-22).
- Le lien « Relire le détail des sources » de l'écran de premier lancement
  est retiré en T1, faute d'écran cible : écart à `BR-012`, le lien arrive
  en T2.
- `Q-01` à `Q-04` (appel groupé, emprise, `fields`, latence de
  l'hydrométrie) mesurés une seule fois, le 2026-09-18, sans campagne
  répétée ; la forme garantie, un appel par station, est gardée.
- **Android** : réactivé le 2026-09-18 — chaîne d'outils vue par
  `flutter doctor`, gabarit généré, émulateur `Pixel_7` démarré. **Aucune
  construction, aucun lancement, aucun écran de l'app constaté sur
  Android** ; aucun appareil réel.
- **iOS** n'a jamais été compilé, faute d'hôte macOS.
- Cibles tactiles de 48 dp (Android) : non vérifiées, T1 tient les 44 pt.
- Aucun ratio de contraste audité (`NFR-04`).
- Aucun percentile (`ADR-003` hors T1) : sur l'échelle « débit », aucune
  station n'est positionnée statistiquement.
- Aucun appel VigiEau (volet sécheresse prévu en T2).
- Aucun parcours intégré (`integration_test/`).
- Station `J543211003` : coordonnées invalides dans le référentiel, ni
  corrigées ni inventées.
- Pastilles de département qui se chevauchent en Île-de-France : écart
  accepté pour T1.
- Coût du parcours au `Tab` dans une carte dense, et clés de marqueurs en
  double au-delà d'une fenêtre de 4 096 px : non mesurés, non traités.
- Aucune annonce constatée avec un lecteur d'écran réel.
- Une zone de carte jamais chargée, hors réseau.

## [0.1.0] — 2026-09-13

Première tranche technique, **rien de tout cela n'est un produit** : aucun
des quatre avertissements obligatoires n'est encore posé (`BR-012`,
`BR-013`), et `CLAUDE.md` interdit toute mise en production tant qu'ils
manquent.

### Ajouté

- Cible Windows construite et lancée hors Flutter ; cible iOS déclarée,
  jamais compilée (aucun hôte macOS).
- Écran carte, fond IGN Géoplateforme en tuiles raster, attribution
  « © IGN Géoplateforme — Licence Ouverte » affichée.
- 4 150 stations en marqueurs, limités à l'emprise visible de la carte plus
  une marge.
- Socle de domaine : unités typées (m³/s, m), fraîcheur des données
  (`BR-005`), nomenclature d'écoulement tolérante à l'inconnu (`BR-011`),
  code station à dix caractères.
- Socle de données : client hydrométrie v2 avec nouvelle tentative à gigue,
  réponses `200` et `206` traitées comme des succès, conversion d'unités en
  un seul point.
- Politique de cache unique, partagée par tous les dépôts.
- Documentation de spécification : fiches de sources datées, modèle de
  domaine, exigences non fonctionnelles, plan de tests.

### Modifié

- Licence du code : MIT → GPL-3.0-or-later (2026-09-13). Les données
  restent sous Licence Ouverte.

### Différé

- Android en entier (arbitrage du 2026-09-12) : aucune plateforme générée,
  aucune signature, aucune publication.
- Stockage local, `ADR-011` réservé.
- Volet sécheresse : `RestrictionSource` n'est encore qu'une interface
  (prévu en T2).

### Constaté à l'exécution

- Exécutable Windows (`flutter build windows --release`) produit et lancé **sans
  outil de développement** par le commanditaire le 2026-09-13 : la carte IGN
  s'affiche, les 4 150 pastilles sont là, l'attribution est lisible, le glisser
  déplace la carte, la molette zoome.
- Dossier de publication : **31 Mo** (budget 60 Mo), dont `flutter_windows.dll`
  21 Mo et le référentiel 6,4 Mo.
- Hors réseau, carte réseau désactivée : la carte s'ouvre, les pastilles et le
  fond de carte s'affichent depuis le cache de tuiles sur les zones déjà
  parcourues, aucun message d'erreur. Une zone jamais chargée n'a pas été
  constatée.

### Non vérifié

- Aucune mesure chiffrée de fluidité sur Windows (`NFR-01`).
- Une zone de carte jamais chargée, hors réseau.
- iOS n'a jamais été compilé, faute d'hôte.
- Android ⏸ différé le 2026-09-12.
