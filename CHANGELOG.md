# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et ce
projet adhère au [Versionnage Sémantique](https://semver.org/lang/fr/).

Chaque ligne décrit un changement visible **pour un usager ou un
intégrateur** — jamais un détail interne. Un remaniement sans effet
observable n'y figure pas.

## [Non publié]

## [0.3.0] — à publier

Troisième tranche (T2) : la sécheresse et les restrictions, lues sur VigiEau
au point que l'usager désigne sur la carte. **Version ouverte, pas
publiée** : le code est écrit et vérifié par `flutter test`, mais aucun
exécutable de release de `0.3.0` n'est construit, aucune construction Android
n'est consignée ni constatée à l'écran (voir « Non vérifié »), et **les
écrans de T2 ne sont constatés qu'en partie** : par le commanditaire, en
débogage sur Windows, le 2026-10-04 (détail dans « Non vérifié »). Aucun ne
l'est sur l'exécutable de release ni sur Android. La porte de la version
(exécutable Windows lancé hors outil, constat Android) reste à passer (`P1`,
`P2`). Les quatre avertissements sont posés dans le code ; la mise en
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
  n'est comparée à une autre.
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
  l'écran, 27 scénarios Gherkin (`restrictions.feature`), matrice de
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

### Corrigé

- Aux largeurs de téléphone, les puces d'échelle et le libellé du contrôle
  « ⚠ Avertissement » débordaient de l'écran (mesuré en test, sur le code de
  `0.2.0`) : voir la colonne unique de « Modifié ».

### Non vérifié

- **Les écrans de T2 ne sont constatés qu'en partie** : par le commanditaire,
  en débogage (`flutter run -d windows`), sur Windows, le 2026-10-04. Vu : au
  lancement, trois puces, ni bouton ni réticule ; un appui sur
  « Restrictions » fait apparaître le bouton, son indice et le réticule,
  marqueurs et légende restant ; le bouton, un appui long ou un clic droit
  ouvrent l'écran « Sécheresse et restrictions », l'encart renforcé en
  tête ; « ⚠ Avertissement » mène à « D'où vient cette donnée ? », où la
  molette posée sur la barre de titre fait défiler ; les zones sont datées,
  eaux superficielles d'abord ; l'adresse de l'arrêté est lisible. **Non
  constaté** : aucun profil présélectionné, puis les usages cités après le
  choix ; un point en mer et sa phrase d'absence ; l'encart « non
  repliable » (aucun moyen de le replier) ; le mode « Restrictions » conservé
  au retour de l'écran des restrictions. Le constat ne dit rien non plus de
  l'épingle du point désigné, de la taille minimale de fenêtre de 800 × 740,
  de la présentation des zones et des arrêtés en cartes, ni du lien
  « Relire le détail des sources » depuis le modal. Déjà consigné avant ce
  constat : le défilement à la molette de l'écran des restrictions, constaté
  résolu le 2026-09-29. Rien n'est constaté sur l'exécutable de release
  (`P1`) ni sur Android (`P2`). Le reste est vérifié par `flutter test`, pas
  à l'écran.
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
  filtre rien.
- **Aucun percentile** (`ADR-003`, hors T2) et **aucune échelle
  « sécheresse » sur la carte** : un niveau de gravité ne se lit que sur
  l'écran des restrictions, jamais en marqueurs. Hors périmètre de T2, non
  livrés : position de l'appareil, repli data.gouv, conservation des
  restrictions au-delà de la session.
- **Quatre décisions de la boucle principale, non confirmées par le
  commanditaire** : le mode « Restrictions » reste actif au retour de
  l'écran des restrictions ; la colonne gauche de la disposition large
  défile ; l'adresse du site public est un texte sélectionnable, non un
  lien, sur l'écran des sources ; les mesures de téléphone se font en
  Roboto.
- Les 27 scénarios de `restrictions.feature` sont lus et vérifiés en
  structure par test, **jamais exécutés** ; certaines phrases d'écran qu'ils
  citent ne sont liées au code par aucun test (`docs/project-state.md`,
  point 53).

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
