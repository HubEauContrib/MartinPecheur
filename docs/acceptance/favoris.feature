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
    Étant donné une station présente sur la carte et absente du référentiel embarqué
    Quand sa fiche s'affiche
    Alors la fiche dit que la station n'est pas dans le référentiel (BR-007)
    Et aucune étoile n'est proposée : il n'y a aucun libellé à copier

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
