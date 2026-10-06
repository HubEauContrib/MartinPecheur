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
  l'écran, 29 scénarios Gherkin (`restrictions.feature`), matrice de
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
- Hub'Eau et VigiEau : chaque tentative d'appel est bornée à **10 s** et
  rejouée comme une panne réseau (arbitrage du commanditaire, 2026-10-06) ;
  sans borne, un serveur qui acceptait la connexion sans répondre laissait
  l'écran en attente sans fin. Pire cas avant l'échec, avec quatre tentatives :
  43,5 à 47 s ; un serveur lent mais vivant, qui répondrait en plus de 10 s,
  échoue désormais. Une tentative qui dépasse son délai est **annulée** : le
  client ferme sa connexion, que le serveur n'ait pas encore répondu ou qu'il
  cale en plein corps ; la phase de connexion (DNS, connexion TCP, poignée de
  main TLS) n'est pas annulée, pas plus qu'une redirection suivie vers une
  autre origine (autre hôte, autre port ou autre schéma) tant que les
  en-têtes de la réponse redirigée ne sont pas arrivés. Établi contre un
  serveur local, jamais sur une API réelle.
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
- **Quatre décisions de la boucle principale, non confirmées par le
  commanditaire** : le mode « Restrictions » reste actif au retour de
  l'écran des restrictions ; la colonne gauche de la disposition large
  défile ; l'adresse du site public est un texte sélectionnable, non un
  lien, sur l'écran des sources ; les mesures de téléphone se font en
  Roboto.
- Les 29 scénarios de `restrictions.feature` sont lus et vérifiés en
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
  connexion TCP, poignée de main TLS) n'est pas annulée au délai de 10 s, seule
  la suite l'est (constaté pour la poignée de main TLS contre un serveur local,
  lu dans le paquet `http` pour le DNS et la connexion TCP), pas davantage une
  redirection suivie vers une autre origine (autre hôte, autre port ou autre
  schéma) tant que les en-têtes de la réponse redirigée ne sont pas arrivés :
  l'annulation détruit la connexion d'origine, laisse ouverte celle de la
  redirection et peut faire échouer une autre requête en vol qui réutilisait
  la connexion d'origine (constaté contre deux serveurs locaux le 2026-10-06 ;
  aucune des sources appelées ne redirige à ce jour) ; le délai de 10 s est
  trop court pour le balayage ONDE national, mesuré à 10,26 s le 2026-10-06
  (`docs/sources/onde.md`, `T-17` ; un échantillon, un jour, un poste) : un
  passage à 30 s pour Hub'Eau, arbitré par le commanditaire, a été retiré à sa
  demande avant tout commit, la question reste ouverte ; « Réessayer »
  n'apparaît qu'après 43,5 à 47 s si la source ne répond pas ; la carte d'un
  arrêté-cadre écrit « S'applique à la même zone » sans dire laquelle quand il
  y a deux arrêtés de restriction (le commanditaire a arbitré de lister ses
  zones dès qu'il y a plusieurs arrêtés, pas encore codé). Les autres constats
  de la revue (dédoublonnage des arrêtés et règle des dates décidés dans la
  vue, doublons de code) : `docs/project-state.md`, points 57 et 59.
- **Quatre décisions de la boucle principale du 2026-10-06, non confirmées par
  le commanditaire** : une réponse corrompue pendant le transfert est une
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
