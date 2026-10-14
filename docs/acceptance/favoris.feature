Fonctionnalité: Suivre un lieu en favori
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD : ces scénarios ne sont jamais exécutés. Vérifié par
  # test/project/acceptance_features_test.dart.
  #
  # Sources : US-14 (cadrage de T3, § 8) ; BR-001 (aucune valeur sans sa date),
  # BR-007 (l'absence n'est jamais un état neutre), BR-011 (nomenclature
  # tolérante à l'inconnu), BR-014 (aucun verbe d'instruction).
  En tant qu'usager qui suit quelques lieux
  Je veux les enregistrer en favoris et les retrouver en liste
  Afin de rouvrir leur fiche sans les chercher sur la carte

  # ── US-14 — l'étoile des fiches ──────────────────────────────────────────

  Scénario: L'étoile d'une fiche station prête ajoute la station
    Étant donné une fiche station dont les valeurs sont affichées, pour une station qui n'est pas en favori
    Quand l'usager active l'étoile « Ajouter aux favoris »
    Alors l'étoile devient pleine et s'annonce « Retirer des favoris »
    Et le favori garde le libellé de la station et sa date d'ajout, jamais une mesure (BR-001)

  Scénario: L'étoile d'une fiche de point ONDE ajoute le point, quel que soit l'état de la fiche
    Étant donné une fiche de point ONDE en chargement, prête ou en échec, pour un point qui n'est pas en favori
    Quand l'usager active l'étoile « Ajouter aux favoris »
    Alors le point est ajouté aux favoris avec son libellé, son cours d'eau et son département
    Et aucune observation n'est copiée dans le favori (BR-001)

  Scénario: L'étoile retire un favori, même quand la fiche est en échec
    Étant donné une station en favori dont la fiche n'a pas pu charger ses valeurs
    Quand l'usager active l'étoile « Retirer des favoris »
    Alors la station n'est plus en favori
    Et la fiche garde son message d'échec, jamais un état neutre (BR-007)

  Scénario: Une station absente du référentiel embarqué n'offre pas d'ajout
    Étant donné une station présente sur la carte et absente du référentiel embarqué, que la liste de favoris, lisible, ne porte pas
    Quand sa fiche s'affiche
    Alors la fiche dit que la station n'est pas dans le référentiel (BR-007)
    Et aucune étoile n'est proposée : il n'y a aucun libellé à copier
    Mais une liste de favoris enregistrée illisible laisse l'étoile proposée, vide et inactive, comme dans tous les états de la fiche : elle ne dit pas si la station y est (BR-007)

  Scénario: Une station et un point ONDE de même code sont deux favoris
    Étant donné une station en favori et un point ONDE qui porte le même code
    Quand l'usager ajoute ce point ONDE aux favoris
    Alors la liste compte deux favoris distincts
    Et un code ONDE à espaces revient identique, espaces compris (BR-011)

  Scénario: Une écriture en échec laisse l'étoile dans son état et le dit
    Étant donné une fiche station prête dont la station n'est pas en favori
    Quand l'usager active l'étoile et que l'enregistrement échoue
    Alors l'étoile reste vide et la fiche affiche « Le favori n'a pas pu être enregistré. » (BR-007)
    Et l'étoile est inactive tant qu'une écriture court

  Scénario: L'état de l'étoile se lit sans la couleur
    Étant donné une fiche dont le lieu est en favori, puis une fiche dont le lieu ne l'est pas
    Quand un lecteur d'écran atteint l'étoile
    Alors il annonce « Retirer des favoris » pour la première et « Ajouter aux favoris » pour la seconde
    Et la forme de l'étoile, pleine ou vide, suffit à les distinguer ; aucun libellé ne porte sur un usage de l'eau (BR-014)

  # ── US-14 — la liste des favoris ─────────────────────────────────────────

  Scénario: La liste n'affiche aucune valeur mesurée, et le dit
    Étant donné deux favoris enregistrés, une station et un point ONDE
    Quand l'écran des favoris s'affiche
    Alors chaque ligne porte le libellé du lieu, sa nature et sa date d'ajout
    Et la liste s'ouvre sur « Cette liste ne montre aucune mesure. La fiche d'un lieu donne sa dernière mesure connue, avec sa date. » (BR-001)

  Scénario: Une liste vide dit comment un favori s'ajoute
    Étant donné aucun favori enregistré
    Quand l'écran des favoris s'affiche
    Alors il affiche « Aucun favori enregistré. L'étoile d'une fiche — station de mesure ou point d'observation — ajoute ce lieu à cette liste. »
    Et rien ne suggère un état des cours d'eau (BR-007)

  Scénario: Une entrée que cette version ne sait pas lire reste affichée et retirable
    Étant donné une liste enregistrée dont une entrée est d'un type inconnu
    Quand l'écran des favoris s'affiche
    Alors cette entrée porte la mention « Favori non lisible par cette version de l'application »
    Et elle se retire, ne s'ouvre pas, et reste enregistrée après l'ajout d'un autre favori (BR-011)

  Scénario: Une liste illisible est dite telle et n'est remplacée que sur demande
    Étant donné une valeur enregistrée que l'application ne sait pas lire
    Quand l'écran des favoris s'affiche
    Alors il dit que les favoris n'ont pas pu être lus, jamais que la liste est vide (BR-007)
    Et rien n'est effacé avant l'action « Repartir d'une liste vide »

  # ── US-14 — retrouver et ouvrir un favori ────────────────────────────────

  Scénario: Après relancement, la liste est celle d'avant
    Étant donné deux favoris enregistrés et une entrée non lisible
    Quand l'usager ferme l'application, la relance et active le bouton « Favoris » de la carte
    Alors la liste montre les mêmes lieux, dans le même ordre, entrée non lisible comprise (BR-011)

  Scénario: Ouvrir un favori ouvre sa fiche sans déplacer la carte
    Étant donné un point ONDE en favori et la carte sur l'échelle débit
    Quand l'usager choisit ce favori dans la liste
    Alors la fiche du point s'ouvre, avec la date et la source de son observation (BR-001)
    Et la carte n'a pas bougé et l'échelle affichée reste le débit

  Scénario: Ouvrir l'écran des favoris ferme la fiche ouverte
    Étant donné une fiche station ouverte sur la carte
    Quand l'usager active le bouton « Favoris » de la carte
    Alors la fiche est fermée et l'écran des favoris s'affiche
    Et aucune valeur mesurée n'y apparaît : elle ne se lit que sur une fiche, avec sa date (BR-001)
