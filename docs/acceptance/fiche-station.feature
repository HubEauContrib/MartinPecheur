Fonctionnalité: Le contenu de la fiche station hydrométrique
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD en T1 (décision 6 du plan). Vérifié par
  # test/project/acceptance_features_test.dart.
  #
  # Sources : BR-001 (aucune valeur sans sa date de mesure), BR-006 (le
  # statut de qualification est toujours affiché), BR-007 (l'absence de
  # donnée n'est jamais un état neutre).
  En tant qu'usager consultant une station
  Je veux connaître l'origine et la qualification de chaque valeur affichée
  Afin de distinguer une mesure pré-validée d'une valeur brute, jamais vérifiée

  Scénario: Le statut et la qualification de la mesure sont toujours affichés
    Étant donné une station dont la dernière observation ne porte aucun champ de qualification
    Quand la fiche de cette station s'affiche
    Alors elle porte la mention « non qualifiée » par défaut, jamais une case vide (BR-006)

  Scénario: Chaque valeur affichée porte sa date et sa source
    Étant donné une fiche de station qui affiche une valeur de débit
    Quand l'usager consulte cette valeur
    Alors la date de la mesure et la source apparaissent au même endroit que la valeur (BR-001)

  Scénario: Une valeur manquante est signalée explicitement
    Étant donné une station dont le champ de débit n'a pas été transmis pour la dernière observation
    Quand la fiche de cette station s'affiche
    Alors elle affiche « La station n'a pas transmis de valeur pour ce paramètre. »
    Et jamais un zéro ni un tiret seul à la place (BR-007)

  # ── Ergonomie — la fiche station hiérarchisée (cadrage du 2026-10-17, critère 11 ; F1)

  Scénario: La fiche station se lit dans l'ordre, débit puis hauteur, chacun avec sa date et sa source
    Étant donné la fiche prête de la station K447001001, qui porte un débit et une hauteur
    Quand la fiche s'affiche
    Alors son en-tête porte « Station hydrométrique · K447001001 » et le contrôle « ⚠ Avertissement »
    Et son corps se lit dans l'ordre : le nom, le cours d'eau et le département, la tuile du débit puis celle de la hauteur, chacune avec sa valeur, sa date de mesure et sa source (BR-001)
    Et dessous « Statut (Hub'Eau) » et « Qualification (Hub'Eau) », chacun au-dessus de sa valeur, puis l'avis de fraîcheur quand il y en a un (BR-006)
