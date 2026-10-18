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

  # ── Ergonomie — la carte ne bouge pas sous une fiche (cadrage du 2026-10-17, arbitrage 12, critère 9 ; D4)
  # La règle vient de l'arbitrage 12 de la spec d'ergonomie (docs/superpowers/specs/2026-10-17-cadrage-ergonomie-design.md) : aucun BR ne la porte ; BR-008 est cité pour la carte et ses lectures.
  # Vérifié par test/features/map/view/map_view_test.dart, groupe « MapView — critère 9, la carte ne bouge pas sous une fiche (D4 d’Ergonomie) »
  # Vérifié par test/features/map/view/map_view_test.dart, groupe « MapView — les boutons de zoom (K1) » (début du nom ; cas « D4 : … » et « sans fiche, recentrer au démarrage … »)
  # Vérifié par test/features/map/view/map_view_test.dart, groupe « MapView — la sélection d une pastille recharge l emprise » (début du nom ; cas « D4 : … »)
  # Vérifié par test/features/map/view/map_designation_reticle_test.dart, groupe « recentrer au téléphone, marge système posée (D4 d’Ergonomie) »

  Scénario: Ouvrir ou fermer une fiche ne déplace pas la carte ; recentrer, zoomer et cadrer une pastille se font dans la carte visible
    Étant donné la carte affichée, sans fiche ouverte
    Quand une fiche s'ouvre, défile puis se ferme
    Alors la carte ne se déplace pas et ses lieux ne se rechargent pas
    Et une fois une fiche ouverte, recentrer pose le centre de démarrage au centre de la partie de la carte que la fiche ne couvre pas
    Et hors mode « Restrictions », « + » et « − » zooment autour de ce centre ; cadrer une pastille pose ses lieux dans cette partie (BR-008, ADR-015)
