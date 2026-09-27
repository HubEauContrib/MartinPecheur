# Changelog

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), et ce
projet adhère au [Versionnage Sémantique](https://semver.org/lang/fr/).

Chaque ligne décrit un changement visible **pour un usager ou un
intégrateur** — jamais un détail interne. Un remaniement sans effet
observable n'y figure pas.

## [Non publié]

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
