Fonctionnalité: Filtrer la carte
  # Critères d'acceptation en Gherkin — spécification lisible, jamais exécutée.
  # Vérifié par test/project/acceptance_features_test.dart.
  # Source : cadrage de T3 (2026-10-12), § 8 ; UC-007 ; BR-007, BR-008, BR-009.
  En tant qu'usager de la carte
  Je veux masquer les lieux qui ne m'intéressent pas
  Afin de ne lire que ce que je cherche, sans prendre un lieu masqué pour une absence

  # ── US-13 — Je filtre par type de donnée, état, département et fraîcheur

  Scénario: Décocher une catégorie d'écoulement retire ses marqueurs
    Étant donné l'échelle « Écoulement » et des points « À sec » et « Eau qui coule » à l'écran
    Quand le filtre appliqué a la case « À sec » décochée
    Alors seuls les marqueurs « Eau qui coule » restent, et le lieu masqué n'est pas une absence de donnée (BR-007)

  Scénario: Un code d'écoulement non reconnu suit la case « Non renseigné »
    Étant donné deux points dont le code d'écoulement n'est pas reconnu, l'un de valeur brute « 9 », l'autre sans valeur
    Quand le filtre appliqué a la case « Non renseigné » décochée
    Alors les deux marqueurs sont masqués, et un point « Non observé » reste affiché (BR-011)

  Scénario: Choisir un département ne laisse que ses lieux, sur les deux échelles
    Étant donné des lieux de deux départements à l'écran
    Quand le filtre appliqué porte l'un des deux départements
    Alors seuls les lieux de ce département restent, sur « Écoulement » comme sur « Débit relatif à l'historique » (BR-008)

  Scénario: Un lieu sans département reste affiché sous un critère de département
    Étant donné une station du référentiel sans département
    Quand le filtre appliqué porte un département
    Alors cette station reste affichée : son département n'est pas connu (BR-007)

  Plan du scénario: Le critère de fraîcheur masque une station chargée dont la mesure a atteint la borne
    Étant donné l'échelle « Débit relatif à l'historique » et une station chargée dont la mesure a <âge>
    Quand le critère de fraîcheur appliqué est <critère>
    Alors le marqueur de cette station est <rendu> (BR-005)

    Exemples:
      | âge     | critère       | rendu   |
      | 1 h 59  | Moins de 2 h  | affiché |
      | 2 h 00  | Moins de 2 h  | masqué  |
      | 23 h 59 | Moins de 24 h | affiché |
      | 24 h 00 | Moins de 24 h | masqué  |

  Scénario: Une station dont l'état n'est pas connu reste affichée sous le critère de fraîcheur
    Étant donné l'échelle « Débit relatif à l'historique » et trois stations : non chargée, en échec, sans donnée
    Quand le critère « Moins de 2 h » est appliqué
    Alors les trois marqueurs restent affichés, sous leur rendu habituel (BR-007)

  Scénario: Le préchargement ne porte que sur les stations du département choisi
    Étant donné l'échelle « Débit relatif à l'historique » et des stations de deux départements à l'écran
    Quand le filtre appliqué porte l'un des deux départements
    Alors aucune mesure n'est demandée pour les stations de l'autre, qui sont masquées et non absentes (BR-007)

  Scénario: Sous le zoom 9, une pastille d'écoulement ne compte que les points retenus
    Étant donné l'échelle « Écoulement », sous le zoom 9, une pastille de trois points dont un « À sec »
    Quand le filtre appliqué a la case « À sec » décochée
    Alors la pastille compte deux points et porte l'état le plus sévère de ces deux-là ; une pastille sans point retenu n'est pas dessinée (BR-009)

  Scénario: Sous le zoom 9, le critère de fraîcheur ne change aucune pastille de débit
    Étant donné l'échelle « Débit relatif à l'historique », sous le zoom 9, une pastille dont une station a une mesure chargée de plus de 24 h
    Quand le critère « Moins de 24 h » est appliqué
    Alors le compte de la pastille est le même qu'avant le filtre (BR-009)

  Scénario: Effacer retire tous les critères, des deux échelles
    Étant donné un filtre portant une case décochée, un département et le critère « Moins de 2 h »
    Quand l'usager efface les filtres
    Alors aucun critère n'est actif, ni sur « Écoulement » ni sur « Débit relatif à l'historique » (BR-007)

  Scénario: Après relancement, aucun filtre n'est actif
    Étant donné un filtre appliqué pendant une session
    Quand l'application est relancée
    Alors la carte montre tous les lieux : aucun n'est masqué sans un geste de l'usager ce jour-là (BR-007)

  Scénario: Une carte vidée par le filtre le dit et propose de l'effacer
    Étant donné une emprise où des lieux ont été lus et un filtre qui les masque tous
    Quand la carte s'affiche
    Alors elle écrit « Les filtres masquent tous les lieux du secteur affiché. Cela ne dit rien de l'état des cours d'eau. », propose « Effacer les filtres », et n'affiche aucun avis d'absence (BR-007)

  Scénario: Une emprise sans lieu garde son avis d'absence, filtre actif ou non
    Étant donné une emprise où aucun lieu n'a été lu et un filtre actif
    Quand la carte s'affiche
    Alors l'avis d'absence habituel s'affiche, et l'avis des filtres ne s'affiche pas (BR-007)

  Scénario: Le type de donnée se choisit par les puces d'échelle, pas dans la feuille
    Étant donné la carte et ses puces d'échelle
    Quand la feuille « Filtres » s'ouvre
    Alors elle ne propose aucune échelle : l'échelle active reste celle des puces (BR-008)

  Scénario: Sur l'écoulement, la feuille ne propose pas de fraîcheur et dit la borne des 60 jours
    Étant donné l'échelle « Écoulement »
    Quand la feuille « Filtres » s'ouvre
    Alors elle écrit « La carte ne montre que les campagnes d'observation des 60 derniers jours. Un point observé plus tôt n'y figure pas. » à la place du critère de fraîcheur (BR-010)

  Scénario: Sur le débit, la feuille ne propose aucun critère d'état
    Étant donné l'échelle « Débit relatif à l'historique »
    Quand la feuille « Filtres » s'ouvre
    Alors elle propose le département et la fraîcheur, et aucune case d'état : un débit ne se qualifie pas (BR-003)

  Scénario: La feuille dit ce que le critère de fraîcheur ne masque pas
    Étant donné l'échelle « Débit relatif à l'historique »
    Quand la feuille « Filtres » s'ouvre
    Alors elle écrit « Ce critère ne porte que sur les mesures déjà chargées : une station dont la mesure n'est pas encore chargée reste affichée. » puis « Il ne s'applique pas aux regroupements par région ou par département : leur compte n'en tient pas compte. » (BR-007, BR-009)

  Scénario: Fermer la feuille sans appliquer ne change rien à la carte
    Étant donné la feuille « Filtres » ouverte et une case décochée dans le brouillon
    Quand l'usager ferme la feuille sans activer « Appliquer » — par « Fermer », par la touche Échap, par le retour du téléphone ou en touchant hors de la feuille
    Alors la carte montre les mêmes lieux qu'avant, et aucun lieu n'est masqué (BR-007)

  Scénario: Aucun texte de la feuille ne qualifie un débit
    Étant donné la feuille « Filtres » sur l'échelle « Débit relatif à l'historique »
    Quand l'usager lit ses critères et ses phrases
    Alors la fraîcheur y est dite en heures — « Toutes », « Moins de 2 h », « Moins de 24 h » — et aucun mot ne juge le débit (BR-003)

  Scénario: Le bouton « Filtres » montre qu'un critère est actif, à tous les zooms
    Étant donné un filtre dont un critère est actif pour l'échelle affichée
    Quand la carte s'affiche, au niveau des marqueurs comme à celui des pastilles de région
    Alors le bouton « Filtres » a changé de forme et s'annonce « Filtres — un filtre est actif » (BR-007)

  Scénario: Une fiche ouverte reste ouverte quand le filtre masque son lieu
    Étant donné la fiche d'un lieu ouverte sur la carte
    Quand un filtre appliqué masque ce lieu
    Alors la fiche reste ouverte : un lieu masqué n'est pas une absence de donnée (BR-007)
