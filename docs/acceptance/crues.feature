Fonctionnalité: Consulter la vigilance crues
  # Critères d'acceptation en Gherkin — spécification lisible, jamais exécutée.
  # Vérifié par test/project/acceptance_features_test.dart.
  # Source : cadrage de T4 (2026-10-14), § 10 ; UC-009 ; BR-001, BR-007, BR-008, BR-011, BR-014, BR-015.
  En tant qu'usager de la carte
  Je veux lire le niveau de vigilance crues publié par Vigicrues, daté et attribué
  Afin de ne jamais prendre une panne ou une absence pour une absence de risque

  # ── US-21 — Je lis sur la carte et dans la fiche d'un tronçon la vigilance crues publiée par Vigicrues

  Scénario: L'entrée « Vigilance crues » du sélecteur active la lecture et efface les autres échelles
    Étant donné la carte affichée sur l'échelle « Écoulement », avec des marqueurs et des pastilles
    Quand l'usager active l'entrée « Vigilance crues » du sélecteur
    Alors les marqueurs et les pastilles des autres échelles disparaissent, et la légende « Vigilance crues » s'affiche (BR-008)

  Scénario: Pendant le premier chargement, aucun trait n'est tracé
    Étant donné la lecture « Vigilance crues » activée pour la première fois, la carte de vigilance pas encore lue
    Quand le chargement est en cours
    Alors aucun trait n'est tracé et l'avis « Lecture de la vigilance publiée par Vigicrues… Aucun tronçon n'est affiché tant qu'elle n'est pas lue. » s'affiche (BR-007)
    Et la légende ne porte ni la phrase de couverture ni de date (BR-001)

  Scénario: Une fois la carte de vigilance lue, chaque tronçon est tracé à son niveau
    Étant donné une carte de vigilance lue avec des tronçons de niveaux « Vert », « Jaune », « Orange » et « Rouge »
    Quand la carte est affichée
    Alors chaque tronçon est tracé à la teinte, à l'épaisseur et au motif de son niveau, le plus grave au-dessus (BR-008)

  Scénario: Les étiquettes se posent selon le zoom
    Étant donné une carte de vigilance lue avec des tronçons verts, jaunes et de niveau non reconnu dans l'emprise
    Quand le zoom passe de moins de 9 à 9 ou plus
    Alors sous le zoom 9 seuls les tronçons non verts et ceux de niveau non reconnu portent une étiquette
    Et à partir du zoom 9 chaque tronçon dont un segment coupe l'emprise en porte une, posée sur le point du trait visible le plus proche du centre (BR-008)

  Scénario: Une étiquette porte la jauge et le nom du niveau, et s'annonce avec son échelle
    Étant donné un tronçon « Blavet » de niveau orange et un tronçon « Scorff » de niveau non reconnu
    Quand le lecteur d'écran atteint leurs étiquettes
    Alors la première porte la jauge et « Orange », et s'annonce « crues : vigilance orange, Blavet »
    Et la seconde porte « Niveau non reconnu » et s'annonce « crues : niveau non reconnu, Scorff » (BR-008)

  Scénario: La légende cite les légendes publiées et porte la date de l'information
    Étant donné une carte de vigilance lue, datée du 14/10/2026 à 15:55
    Quand la légende « Vigilance crues » est affichée
    Alors elle cite « Vert — Pas de vigilance particulière requise », « Jaune — Risque de crue génératrice de débordements », « Orange — Risque de crue génératrice de débordements importants » et « Rouge — Risque de crue majeure »
    Et elle porte « Un cours d'eau sans trait de couleur n'est pas suivi par Vigicrues. » puis « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES » (BR-001, BR-014)

  Scénario: Toucher un trait ou une étiquette ouvre la fiche du tronçon
    Étant donné une carte de vigilance lue et la fiche d'un premier tronçon ouverte
    Quand l'usager touche le trait d'un autre tronçon, son étiquette, ou appuie sur Entrée sur son étiquette
    Alors la fiche de cet autre tronçon remplace celle du premier : il n'y a jamais deux fiches ensemble
    Et si deux traits se superposent, la fiche est celle du tronçon dessiné le plus haut (BR-008)

  Scénario: Ouvrir une autre fiche ou quitter la lecture ferme la fiche du tronçon
    Étant donné la fiche d'un tronçon ouverte
    Quand l'usager ouvre une fiche de station ou de point ONDE, un favori, désigne un point, ou quitte la lecture « Vigilance crues »
    Alors la fiche du tronçon se ferme : il n'y a jamais deux fiches ensemble (BR-008)

  Scénario: La fiche du tronçon suit un ordre fixe et porte l'avertissement de crue
    Étant donné la fiche d'un tronçon « Blavet » de niveau orange
    Quand elle s'affiche
    Alors elle porte dans l'ordre : « Tronçon Vigicrues » et le nom publié, l'encart « CE N'EST PAS UN SYSTÈME D'ALERTE », « Vigilance orange », la définition publiée suivie de « — Vigicrues », « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES », puis « Lire le bulletin sur www.vigicrues.gouv.fr »
    Et sa fenêtre « ⚠ Avertissement » porte « Ce n'est pas un système d'alerte. Cette application reprend la vigilance publiée par Vigicrues, à la date indiquée ; elle ne remplace ni le bulletin de Vigicrues, ni les consignes des autorités et des secours. » (BR-015, BR-014)

  Scénario: Le lien du bulletin s'ouvre, ou son adresse reste lisible
    Étant donné la fiche d'un tronçon (cas construit) dont le territoire a pour code « 12 »
    Quand l'usager active « Lire le bulletin sur www.vigicrues.gouv.fr »
    Alors l'adresse ouverte est « https://www.vigicrues.gouv.fr/bulletin_local/12 »
    Et si le lien ne s'ouvre pas, « Ce lien n'a pas pu être ouvert depuis l'application. Son adresse reste affichée ci-dessus. » s'affiche, l'adresse restant lisible et sélectionnable (BR-007)

  Scénario: Un niveau non reconnu est tracé en gris pointillé et dit tel quel
    Étant donné des tronçons dont le niveau publié vaut « 7 », est absent, ou est nul
    Quand la carte et la fiche sont affichées
    Alors chaque trait est gris pointillé, étiqueté « Niveau non reconnu »
    Et la fiche dit « Niveau de vigilance non reconnu » puis « Vigicrues a publié un niveau que cette application ne sait pas lire. Le bulletin sur www.vigicrues.gouv.fr fait foi. », sans citer de définition (BR-011)

  Plan du scénario: Une source en échec ne trace rien et ne se lit jamais comme un trait vert
    Étant donné la lecture « Vigilance crues » activée, la carte de vigilance pas encore lue
    Quand la source est <cas>
    Alors aucun trait n'est tracé et l'avis est « <avis> », avec l'action « Réessayer » (BR-007)
    Et un relâchement de geste ne relance rien, seul « Réessayer » relance la lecture

    Exemples:
      | cas                  | avis                                                                                                                       |
      | injoignable          | Vigicrues n'a pas répondu. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue.                               |
      | refusée ou illisible | La vigilance publiée par Vigicrues n'a pas pu être lue. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. |

  Scénario: Une carte de vigilance sans date lisible n'est pas affichée
    Étant donné une réponse dont la date de l'information de vigilance est absente ou sans fuseau explicite
    Quand la carte de vigilance est lue
    Alors elle est illisible pour toute la réponse : aucun trait n'est tracé, et l'avis « La vigilance publiée par Vigicrues n'a pas pu être lue. Aucun tronçon n'est affiché : cela ne dit rien du risque de crue. » s'affiche (BR-001, BR-011)

  Scénario: Des entités illisibles sont écartées et comptées
    Étant donné une carte de vigilance dont une entité n'a pas de nom et une autre pas de tracé lisible, les autres étant valides, et aucun tronçon lisible ne touchant l'emprise affichée
    Quand la carte est affichée
    Alors les entités valides restent tracées, et l'avis « 2 tronçons de vigilance non lisibles. » remplace l'avis du secteur sans tronçon (BR-011, BR-007)

  Scénario: Un secteur sans tronçon le dit sans rien affirmer du risque
    Étant donné une carte de vigilance lue, sans entité écartée, dont aucun tronçon lisible ne touche l'emprise affichée
    Quand la carte est affichée
    Alors l'avis est « Aucun cours d'eau suivi par Vigicrues dans le secteur affiché. Cela ne dit rien du risque de crue : sur cette carte, Vigicrues ne suit que certains cours d'eau de métropole et de Corse. » (BR-007)

  Scénario: Passé 30 minutes, la carte en cache reste tracée avec sa date
    Étant donné une carte de vigilance lue il y a plus de 30 minutes
    Quand l'usager relâche un geste sur la lecture « Vigilance crues »
    Alors la carte en cache reste tracée avec sa date pendant qu'une nouvelle se charge, sans avis (BR-001)
    Et Vigicrues n'est appelé qu'après la première activation de la lecture, et au plus une fois par 30 minutes tant que les chargements réussissent

  Scénario: La feuille de filtres dit qu'aucun filtre ne s'applique
    Étant donné la lecture « Vigilance crues » active
    Quand l'usager ouvre la feuille « Filtres »
    Alors elle dit « Aucun filtre ne s'applique à la lecture Vigilance crues. » et n'offre aucun critère (BR-007)
    Et le bouton « Filtres » ne se montre pas actif

  Scénario: La fenêtre « ⚠ Avertissement » de la carte porte le texte de crue
    Étant donné la lecture « Vigilance crues » active
    Quand l'usager ouvre « ⚠ Avertissement » sur la carte
    Alors la fenêtre ajoute « Ce n'est pas un système d'alerte. Cette application reprend la vigilance publiée par Vigicrues, à la date indiquée ; elle ne remplace ni le bulletin de Vigicrues, ni les consignes des autorités et des secours. » sous le texte général (BR-015)

  Scénario: Aucun texte de la vigilance crues ne qualifie un débit ni ne donne de consigne
    Étant donné l'ensemble des textes de la lecture « Vigilance crues » et de la fiche d'un tronçon
    Quand on les relit
    Alors aucun ne qualifie un débit (BR-003), aucun ne porte de verbe d'instruction sur un usage de l'eau ni de mot de garantie (BR-014)
    Et aucun ne rapproche un débit, une hauteur ou un écoulement d'un risque de crue (BR-015)

  # ── Ergonomie — la fiche du tronçon dans le cadre commun (cadrage du 2026-10-17, critère 13 ; F3)

  Scénario: La fiche du tronçon se pose dans le cadre commun des fiches, sans étoile, et garde l'ordre de T4
    Étant donné la fiche d'un tronçon « Blavet » de niveau orange
    Quand elle s'affiche
    Alors son en-tête épinglé porte « Tronçon Vigicrues », la fermeture, puis le contrôle « ⚠ Avertissement » avec le texte de crue, sans étoile ni code (BR-015)
    Et son corps, qui défile sous l'en-tête, garde l'ordre de T4 : le nom publié, l'encart « CE N'EST PAS UN SYSTÈME D'ALERTE », « Vigilance orange », la définition publiée suivie de « — Vigicrues », « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES », « Lire le bulletin sur www.vigicrues.gouv.fr », puis son adresse
