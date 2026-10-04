Fonctionnalité: Les quatre emplacements de l'avertissement
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD (décision 6 du plan T1, décision 9 du plan T2). Vérifié par
  # test/project/acceptance_features_test.dart : chaque Scénario cite une
  # règle métier qui existe réellement sous docs/br/. Les libellés d'écran
  # que le code porte dans une constante (bouton d'acquittement, lien du
  # modal vers les sources, titre de l'écran des sources, contrôle
  # d'avertissement, titre de l'encart renforcé) sont lus dans ce code : si
  # l'un d'eux change, le test rougit. Les autres phrases citées n'ont pas de
  # verrou.
  #
  # Sources : docs/04-ui.md § 5 (tel qu'amendé le 2026-09-23, W3c),
  # docs/use-cases/UC-006-acquitter-l-avertissement-initial.md, BR-012,
  # BR-001. Le quatrième emplacement (encart renforcé de l'écran des
  # restrictions, BR-013) a son scénario depuis T2 : il était reporté en T2
  # faute d'écran de ressource en T1 (décision 11 de la révision du plan du
  # 2026-09-22). Le détail de ses comportements — défilement, états,
  # lecteur d'écran — est dans restrictions.feature. Le détail des sources
  # (« Relire le détail des sources », « D'où vient cette donnée ? ») complète
  # US-01 et BR-012 depuis T2 (conception de l'écran des restrictions § 8,
  # arbitrage Q-8 du commanditaire).
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

  Scénario: Le quatrième emplacement est un encart renforcé, affiché d'emblée sur l'écran des restrictions
    Étant donné un usager qui désigne un point sur la carte
    Quand l'écran « Sécheresse et restrictions » s'affiche
    Alors l'encart renforcé « NE FONDEZ AUCUNE DÉCISION SUR CET ÉCRAN » est le premier contenu sous la barre de titre, affiché d'emblée et non repliable
    Et, à la différence du contrôle « ⚠ Avertissement » des emplacements 2 et 3, il ne s'ouvre pas à la demande et n'exige aucun acquittement : ni case à cocher, ni bouton « J'ai compris ces limites » (BR-013)

  Scénario: Le modal initial propose de relire le détail des sources, sans rien acquitter
    Étant donné un usager face à l'écran d'avertissement du premier lancement, sa case cochée ou non
    Quand il actionne « Relire le détail des sources », lit l'écran « D'où vient cette donnée ? », puis revient au modal par le bouton de retour ou par Échap
    Alors il a lu les sources et leurs limites sans avoir acquitté : aucun acquittement n'est enregistré
    Et il retrouve le modal tel qu'il l'a laissé, sa case dans l'état où il l'a laissée, la carte restant fermée tant qu'il n'a pas actionné « J'ai compris ces limites » (BR-012)

  Scénario: Le détail des sources reste accessible après l'acquittement
    Étant donné un usager qui a acquitté l'avertissement initial
    Quand il ouvre le contrôle « ⚠ Avertissement » de la carte, ou celui d'une fiche, puis le lien « D'où vient cette donnée ? » de la fenêtre
    Alors l'écran « D'où vient cette donnée ? » s'ouvre par-dessus la fenêtre
    Et le retour ramène à la fenêtre d'avertissement, telle qu'elle était (BR-012)
