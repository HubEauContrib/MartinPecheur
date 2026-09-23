Fonctionnalité: L'âge d'une campagne d'observation ONDE
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD en T1 (décision 6 du plan). Vérifié par
  # test/project/acceptance_features_test.dart.
  #
  # Source : BR-010 (l'âge de la campagne ONDE est toujours affiché), et
  # la constante lib/domain/onde/campaign_age.dart
  # (campagneAncienneApres = 60 jours calendaires). La borne appartient à
  # l'état le plus sévère : un âge de 60 jours pile est déjà « ancienne ».
  En tant qu'usager consultant un point ONDE
  Je veux connaître l'ancienneté de la dernière campagne d'observation
  Afin de ne pas lire une observation de septembre comme un état de février

  Scénario: Une campagne observée il y a 59 jours reste récente
    Étant donné un point ONDE observé il y a 59 jours calendaires
    Quand la fiche de ce point affiche son état
    Alors l'état est affiché dans sa couleur de catégorie, sans mention d'ancienneté (BR-010)

  Scénario: Une campagne observée il y a 60 jours devient ancienne
    Étant donné un point ONDE observé il y a exactement 60 jours calendaires
    Quand la fiche de ce point affiche son état
    Alors l'état est affiché en gris, avec la mention « dernière observation le » suivie de la date (BR-010)

  Scénario: La date affichée est celle de l'observation, jamais celle de la publication
    Étant donné un point ONDE observé le 20/07/2026 et publié le 22/07/2026
    Quand la fiche de ce point affiche sa date de dernière campagne
    Alors la date affichée est le 20/07/2026 (BR-001)
