Fonctionnalité: Les quatre emplacements de l'avertissement
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD en T1 (décision 6 du plan). Vérifié par
  # test/project/acceptance_features_test.dart : chaque Scénario cite une
  # règle métier qui existe réellement sous docs/br/.
  #
  # Sources : docs/04-ui.md § 5 (tel qu'amendé le 2026-09-23, W3c),
  # docs/use-cases/UC-006-acquitter-l-avertissement-initial.md, BR-012,
  # BR-001. L'emplacement 4 (encart renforcé sur écran de ressource ou de
  # sécheresse) n'a volontairement aucun scénario ici : il est reporté en
  # T2 (décision 11 de la révision du plan du 2026-09-22) — aucun écran de
  # T1 ne présente la disponibilité de la ressource.
  En tant qu'usager de l'application
  Je veux être averti des limites des données à chaque endroit où elles comptent
  Afin de ne jamais confondre une information indicative avec une autorisation

  Scénario: Le bouton du modal initial reste inactif tant que la case n'est pas cochée
    Étant donné un usager qui lance l'application pour la première fois
    Quand l'écran d'avertissement bloquant s'affiche, avec sa case à cocher décochée
    Alors le bouton « J'ai compris ces limites » est inactif
    Et il ne devient actif qu'après que la case a été cochée (BR-012)

  Scénario: Le texte du modal initial change de version après une mise à jour
    Étant donné un usager qui a déjà acquitté une version antérieure du texte d'avertissement
    Quand une nouvelle version de ce texte est publiée
    Alors l'écran d'avertissement bloquant est réaffiché au lancement suivant
    Et l'ancien acquittement ne suffit plus à ouvrir la carte (BR-012, UC-006 A3)

  Scénario: Le contrôle « ⚠ Avertissement » de la carte reste présent à tous les niveaux de zoom
    Étant donné un usager qui a déjà acquitté l'écran du premier lancement
    Quand il consulte la carte, à n'importe quel niveau de zoom
    Alors le contrôle « ⚠ Avertissement » reste présent au-dessus de la légende
    Et l'ouverture de ce contrôle affiche le même texte que celui du modal initial (BR-012)

  Scénario: Le contrôle « ⚠ Avertissement » d'une fiche datée porte la phrase propre à cette fiche
    Étant donné une fiche station qui affiche une mesure du 15/03/2026 à 08:00
    Quand l'usager ouvre le contrôle « ⚠ Avertissement » en tête de cette fiche
    Alors la fenêtre affiche le texte général du modal initial
    Et elle affiche, sous ce texte général, une phrase propre mentionnant la date de cette mesure (BR-001)

  Scénario: Une fiche sans aucune mesure ni campagne n'affiche pas de phrase datée
    Étant donné une fiche station qui n'a reçu aucune mesure
    Quand l'usager ouvre le contrôle « ⚠ Avertissement » en tête de cette fiche
    Alors la fenêtre n'affiche que le texte général du modal initial
    Et aucune phrase datée n'y figure, faute de date à donner (BR-001)
