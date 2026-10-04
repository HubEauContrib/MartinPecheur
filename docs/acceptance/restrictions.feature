Fonctionnalité: L'écran « Sécheresse et restrictions » au point désigné
  # Critères d'acceptation en Gherkin — spécification lisible, aucun
  # framework BDD (décision 9 du plan T2). Vérifié par
  # test/project/acceptance_features_test.dart : chaque scénario cite une
  # règle métier qui existe réellement sous docs/br/, et chaque user story
  # (US-09, US-07, US-08) a ses scénarios sous sa section.
  #
  # Libellés d'écran : ceux que le code porte dans une CONSTANTE ou une
  # fonction de libellé (titre de l'écran, titre et action de l'encart, phrase
  # de BR-007, choix « Restrictions » et bouton de désignation, échelles,
  # niveaux, types de zone, profils, nom et adresse du site de la source)
  # sont lus dans ce code : si l'un d'eux change, le test rougit. Les autres
  # phrases d'écran citées ici sont écrites en dur dans les vues
  # (restrictions_screen.dart) : elles ont été comparées au code à l'écriture
  # (2026-10-04), rien ne les verrouille.
  #
  # Sources : les scénarios de US-09, US-07 et US-08 du cadrage de T2
  # (docs/superpowers/specs/2026-09-27-cadrage-t2-design.md, § 4), dont les
  # formulations d'écran suivent ce qui a été arbitré ensuite et codé :
  # docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md
  # (arbitrages Q-1 à Q-8) et docs/04-ui.md § 1, § 3 et § 5, amendé le
  # 2026-10-03 pour le choix « Restrictions » du sélecteur de la carte. Une
  # règle n'est citée entre parenthèses que si son texte gouverne ce que la
  # phrase affirme ; ce qui relève d'un arbitrage ou d'une décision de
  # cadrage (Q-6, Q-7, Q1, Q2-A, Q7-A) le dit, sans règle.
  #
  # Ce que ces scénarios n'affirment pas : rien n'a été constaté à l'écran
  # (Windows ni Android) au moment de leur écriture. Ils décrivent ce qui est
  # décidé et codé, vérifié par les tests de la tranche restrictions. Les
  # dimensions de fenêtre citées sont des mesures de test (police de test de
  # Flutter) : le constat sur appareil reste dû.
  En tant qu'usager de la rivière (agriculteur ou élu)
  Je veux lire ce que dit la source des restrictions au point que je désigne
  Afin de savoir quel arrêté consulter, sans jamais prendre l'écran pour une règle

  # ── US-09 — l'encart renforcé précède tout ───────────────────────────────

  Scénario: L'encart renforcé est le premier contenu de l'écran, dans tous ses états
    Étant donné un usager qui désigne un point et ouvre l'écran « Sécheresse et restrictions »
    Quand l'écran s'affiche, avant même la réponse de la source, puis passe par ses autres états : zones trouvées, aucune zone, échec de la source
    Alors le titre « NE FONDEZ AUCUNE DÉCISION SUR CET ÉCRAN », puis l'action « Consulter les arrêtés en vigueur », puis le corps de l'encart sont, dans chaque état, les premiers contenus sous la barre de titre
    Et le point désigné, puis le niveau de gravité s'il est affiché, viennent après lui (BR-013)

  Scénario: Au défilement, le titre et l'action de l'encart restent en place quand ils tiennent dans la moitié de la hauteur utile
    # Arbitrage du commanditaire (Q-4) : « ni disparition au défilement » se
    # lit comme visant le titre et l'action ; le corps, premier élément du
    # défilement, défile avec le contenu. Cas mesurés par les tests (§ 4 de
    # la conception) : 360 × 640 à 100 %, 411 × 891 et 800 × 740 à 200 %.
    Étant donné l'écran affiché sur une fenêtre où le titre et l'action de l'encart occupent au plus la moitié de la hauteur utile, par exemple 800 × 740 à 200 % de police
    Quand l'usager fait défiler le contenu
    Alors le titre et l'action de l'encart ne bougent pas, sous la barre de titre
    Et le corps de l'encart défile avec le contenu
    Et aucun contrôle ne permet de replier l'encart, de le fermer ni de ne plus l'afficher (BR-013)

  Scénario: Sur un téléphone de 360 × 640 à 200 % de police, tout l'encart est le premier élément du défilement
    # Arbitrage du commanditaire (Q-4 amendé le 2026-09-29) : quand le titre
    # et l'action prennent plus de la moitié de la hauteur utile (cas mesuré
    # en police de test : 360 × 640 à 200 %), l'épinglage les rendrait
    # inatteignables — tout l'encart défile alors avec le contenu.
    Étant donné l'écran affiché sur un téléphone de 360 × 640, police agrandie à 200 %, où le titre et l'action de l'encart occupent plus de la moitié de la hauteur utile
    Quand l'écran s'affiche, puis que l'usager le fait défiler
    Alors le titre, l'action et le corps de l'encart forment ensemble le premier élément du défilement, au-dessus de tout autre contenu
    Et à l'ouverture, l'encart est en tête de l'écran, dans tous ses états
    Et faire défiler l'écran l'éloigne, mais aucun contrôle ne permet de le replier, de le fermer ni de ne plus l'afficher (BR-013)

  Scénario: Un nouveau point désigné ouvre l'écran en haut, sur l'encart
    Étant donné un usager qui a fait défiler l'écran des restrictions, puis est revenu à la carte
    Quand il désigne un autre point
    Alors l'écran s'ouvre en haut, l'encart renforcé en premier contenu, sans garder la position de défilement du point précédent (BR-013)

  Scénario: Le titre et l'action de l'encart sont annoncés en priorité au lecteur d'écran
    Étant donné un usager qui utilise un lecteur d'écran
    Quand il ouvre l'écran « Sécheresse et restrictions »
    Alors le titre et l'action de l'encart sont annoncés comme une région d'alerte, avant tout autre contenu
    Et le corps de l'encart n'est pas annoncé une seconde fois comme région d'alerte (BR-013)

  Scénario: L'action de l'encart ouvre le site public, hors de l'application
    Étant donné l'écran « Sécheresse et restrictions », dans n'importe lequel de ses états
    Quand l'usager actionne « Consulter les arrêtés en vigueur »
    Alors le site https://vigieau.gouv.fr/ s'ouvre hors de l'application
    Et son adresse reste lisible et sélectionnable dans le corps de l'encart (BR-013)

  # ── US-07 — désigner un point : la condition de « ma zone » ──────────────

  Scénario: Le choix « Restrictions » est à part des échelles : il s'allume et s'éteint sans toucher à l'échelle affichée
    Étant donné la carte au lancement
    Quand l'usager regarde le sélecteur de la carte
    Alors il propose « Écoulement », « Débit relatif à l'historique » et « Restrictions »
    Et ni le bouton « Restrictions au centre de la carte », ni son indice de geste, ni le réticule ne sont affichés
    Quand il actionne « Restrictions », passe à l'échelle « Débit relatif à l'historique », puis actionne de nouveau « Restrictions »
    Alors le changement d'échelle ne quitte pas le choix « Restrictions »
    Et le second appui l'éteint : le bouton, son indice et le réticule disparaissent, comme au lancement, l'échelle choisie restant affichée (BR-008)

  Scénario: Le choix « Restrictions » fait apparaître le bouton de désignation sans changer l'échelle affichée
    Étant donné la carte en échelle « Écoulement », avec ses marqueurs et sa légende
    Quand l'usager actionne le choix « Restrictions »
    Alors le bouton « Restrictions au centre de la carte », son indice de geste et un réticule au centre de la carte apparaissent
    Et « Écoulement » reste allumé, avec ses marqueurs et sa légende : « Restrictions » n'est pas une troisième échelle et ne dessine aucune échelle de sécheresse sur la carte (BR-008)

  Scénario: Un point se désigne par le bouton, par un appui long ou par un clic droit, et par rien d'autre
    Étant donné la carte affichée
    Quand l'usager désigne un point de l'une de ces trois façons : avec le choix « Restrictions » allumé, en actionnant « Restrictions au centre de la carte », touché ou atteint par la tabulation puis activé par Entrée ou Espace ; par un appui long, au toucher, ou par un clic droit, à la souris, sur un point de la carte, que le choix soit allumé ou non
    Alors l'écran « Sécheresse et restrictions » s'ouvre pour le point visé : le centre de la carte, celui que marque le réticule, pour le bouton ; le point sous le pointeur pour l'appui long et le clic droit
    Et l'encart renforcé en est le premier contenu (BR-013)
    Et le bouton de retour ou Échap ramène à la carte, où une épingle marque le point désigné jusqu'à la désignation suivante (Q-2b)
    Et aucune fiche station ni fiche point ONDE ne propose d'ouvrir cet écran : il ne s'atteint que par la désignation d'un point (cadrage Q1)

  # ── US-07 — niveau de gravité, zones, profil, usages ─────────────────────

  Scénario: Le niveau de gravité s'affiche avec sa date de début de validité
    Étant donné un point désigné situé dans la zone « Rivières de Bresse », de type « Eaux superficielles », où la source donne le niveau « Alerte » depuis le 20/08/2026 jusqu'au 31/10/2026
    Quand l'écran reçoit la réponse de la source
    Alors il affiche « Alerte · depuis le 20/08/2026 » à côté du badge de la zone, puis « jusqu'au 31/10/2026 » (BR-001)
    Et l'échelle complète, « Vigilance », « Alerte », « Alerte renforcée » et « Crise », la case « Alerte » y étant marquée « ← cette zone »
    Et le libellé du niveau est posé à côté du badge, jamais écrit sur sa teinte (Q-7)

  Scénario: Une date de fin absente le dit
    Étant donné une zone dont la source ne transmet pas de date de fin de validité
    Quand l'écran l'affiche
    Alors il affiche « Date de fin non transmise par la source. » à la place de la date de fin
    Et jamais une date inventée ni un vide (BR-007)

  Scénario: Le point interrogé est toujours un point, jamais une commune
    Étant donné un usager qui désigne un point sur la carte
    Quand l'application interroge la source
    Alors elle transmet la latitude et la longitude du point, jamais un code de commune (C-14)
    Et l'écran rappelle le point interrogé, « Point désigné : 46,20000° N, 5,22600° E », puis la date de la réponse, « Réponse de VigiEau obtenue le 27/09/2026 à 13:25 » (Q7-A)
    Et cette date est celle de la récupération : le niveau de chaque zone garde, lui, sa date de début de validité (BR-001)

  Scénario: Toutes les zones du point sont montrées, les eaux superficielles d'abord
    Étant donné un point désigné situé dans une zone de type « Eaux superficielles », une zone de type « Eaux souterraines » et une zone de type « Eau potable »
    Quand l'écran s'affiche
    Alors la zone « Eaux superficielles » vient en premier, puis « Autres zones au même point » présente « Eaux souterraines », puis « Eau potable »
    Et chaque zone porte son type, son nom, son niveau daté et son échelle, aucune n'étant écartée ni résumée par « la plus sévère » (BR-007)

  Scénario: Un niveau de gravité inconnu n'est jamais rabattu sur un niveau connu
    Étant donné une réponse dont le niveau de gravité n'appartient à aucune valeur connue
    Quand l'écran l'affiche
    Alors il affiche « Non renseigné », suivi de « Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de votre préfecture. » (BR-007)
    Et il ne lui attribue ni la teinte ni la forme d'un niveau connu, aucune case de l'échelle n'étant marquée « ← cette zone » (BR-011)

  Scénario: Un type de zone inconnu est gardé et signalé, jamais rabattu sur un type connu
    Étant donné une zone dont le type n'appartient à aucune valeur connue
    Quand l'écran l'affiche
    Alors la zone est gardée sous « Autres zones au même point », avec « Type de zone non renseigné » pour type
    Et la valeur brute reçue n'est jamais affichée (BR-011)

  Scénario: Aucune zone au point désigné n'est jamais un état neutre
    Étant donné un point désigné pour lequel la source ne renvoie aucune zone, par exemple en pleine mer
    Quand l'écran s'affiche
    Alors il affiche « VigiEau ne renvoie aucune zone d'alerte pour ce point. », puis « Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès de votre préfecture. »
    Et ni badge, ni échelle, ni choix de profil n'y figurent : aucune teinte ni aucun libellé ne suggère une absence de restriction (BR-007)

  Scénario: Pendant la recherche, l'écran n'affiche ni badge ni niveau de gravité
    Étant donné un usager qui vient de désigner un point, la source n'ayant pas encore répondu
    Quand l'écran s'affiche
    Alors il rappelle le point désigné et affiche « Recherche des zones d'alerte pour ce point… »
    Et ni badge, ni niveau de gravité, ni échelle n'y figurent : un écran en cours de chargement n'affiche pas d'état par défaut (BR-007)

  Scénario: Aucun profil n'est présupposé, et celui qui est choisi est gardé pour la session
    Étant donné un usager qui ouvre l'écran pour la première fois de la session, sur un point qui porte des zones
    Quand l'écran affiche le choix « Profil d'usager »
    Alors les quatre profils, « Particulier », « Exploitation », « Collectivité » et « Entreprise », sont proposés, aucun n'étant présélectionné
    Et « Les usages restreints s'affichent une fois un profil choisi. » tient la place de la liste, qui n'apparaît qu'après un choix explicite (BR-007)
    Quand l'usager choisit « Collectivité », revient à la carte, puis désigne un autre point
    Alors le profil « Collectivité » est encore celui qui est choisi, sans nouveau choix
    Et il n'est gardé que pour la session : l'application ne l'enregistre pas (cadrage Q2-A)

  Scénario: Les usages se filtrent sur le profil choisi et sont cités tels que transmis
    Étant donné une zone soumise à un arrêté et plusieurs usages restreints, dont un a pour description transmise « Interdiction de 10h à 18h »
    Quand l'usager choisit le profil « Particulier »
    Alors seuls les usages restreints qui concernent ce profil sont listés, groupés par zone dans l'ordre de l'écran, sans nouvel appel à la source
    Et le profil retenu est rappelé au-dessus de la liste : « Usages restreints pour le profil Particulier »
    Et chaque usage est cité tel que transmis, son nom en gras puis sa description mot pour mot entre guillemets, sous la phrase « Textes cités tels que transmis par VigiEau. Seul l'arrêté fait foi. », qui l'attribue à la source et non à l'application (BR-014)

  Scénario: Une zone sans usage pour le profil choisi le dit, jamais par une liste vide
    Étant donné une zone pour laquelle la source ne transmet aucun usage pour le profil « Particulier »
    Quand la liste des usages s'affiche
    Alors la zone porte « VigiEau ne transmet aucun usage pour le profil Particulier dans cette zone. Seul l'arrêté fait foi : consultez-le. »
    Et aucune liste vide n'y tient lieu d'absence de restriction (BR-007)

  Scénario: L'écran n'emploie aucun verbe d'instruction qui lui soit propre
    Étant donné tout texte de l'écran qui ne provient pas de la source
    Quand on le relit
    Alors il ne contient aucune consigne, aucune autorisation ni aucune interdiction portant sur un usage de l'eau
    Et le seul texte qui en parle est la négation de l'encart renforcé, qui renvoie aux arrêtés préfectoraux (BR-014)

  Plan du scénario: Un échec est dit tel qu'il est, jamais par un écran blanc
    Étant donné <situation>
    Quand l'usager désigne un point
    Alors l'écran affiche « <texte> »
    Et aucun niveau de gravité n'est affiché, et l'écran écrit « Les arrêtés en vigueur restent consultables à l'adresse https://vigieau.gouv.fr/ »
    Et l'action « Consulter les arrêtés en vigueur » de l'encart reste disponible (BR-013), et « Réessayer » interroge de nouveau le même point
    Et <précision> (<règles>)

    Exemples:
      | situation | texte | précision | règles |
      | une source des restrictions qui ne répond pas | VigiEau n'a pas répondu. Aucun niveau n'est disponible pour ce point. | la source qui n'a pas répondu est nommée | BR-007 |
      | une source dont la réponse a une forme que l'application ne sait pas lire | La réponse de VigiEau n'a pas pu être lue par l'application. Aucun niveau n'est affiché. | la réponse n'est pas rabattue sur « Non renseigné » : une rupture de structure n'est pas une valeur de nomenclature inconnue | BR-007, BR-011 |
      | une source qui répond, mais refuse de servir le point désigné | VigiEau a répondu, mais n'a pas pu servir ce point. Aucun niveau n'est affiché. | l'écran ne dit pas que la source n'a pas répondu | BR-007 |
      | un échec de l'application que la source des restrictions n'a pas provoqué | Les restrictions n'ont pas pu être obtenues pour ce point. Aucun niveau n'est affiché. | la source n'est pas nommée : elle n'est pas accusée d'une panne qui n'est pas la sienne | BR-007 |

  Scénario: Une réponse déjà obtenue pendant la session porte sa date de récupération
    Étant donné un point déjà consulté pendant cette session, dont la réponse est gardée en mémoire, et une source devenue injoignable
    Quand l'usager désigne de nouveau ce point
    Alors l'écran affiche la réponse gardée, avec « Réponse de VigiEau obtenue le » suivi de la date et de l'heure de sa récupération d'origine, et non de celles de la désignation présente (UC-002 A5)
    Et chaque niveau y garde sa date de début de validité, « depuis le » (BR-001)
    Et l'encart renforcé reste affiché en tête (BR-013)

  # ── US-08 — le texte qui fait foi ────────────────────────────────────────

  Scénario: Les arrêtés sont accessibles depuis l'écran, chacun une seule fois
    Étant donné un point dont trois zones citent le même arrêté, dont l'adresse est celle d'un PDF, et le même arrêté-cadre
    Quand la section « Arrêtés » s'affiche
    Alors elle annonce « 2 documents pour ce point », chaque adresse n'y figurant qu'une fois, avec les zones auxquelles elle s'applique (Q-6)
    Et l'arrêté-cadre, qui s'applique aux mêmes zones, dit « S'applique aux 3 mêmes zones » sans répéter la liste
    Quand l'usager actionne « Ouvrir l'arrêté »
    Alors le PDF s'ouvre hors de l'application, ce que dit la mention « PDF · s'ouvre hors de l'application » sous le bouton
    Et l'adresse du document reste lisible et sélectionnable à l'écran, telle que reçue
    Et l'arrêté-cadre s'ouvre de la même façon par « Ouvrir l'arrêté-cadre » (BR-013)

  Scénario: Un lien qui ne s'ouvre pas est signalé sans prétendre qu'il existe
    Étant donné une adresse d'arrêté, ou celle du site public, que l'application n'a pas pu ouvrir
    Quand l'usager actionne l'action d'ouverture
    Alors « Ce lien n'a pas pu être ouvert depuis l'application. Son adresse reste affichée ci-dessus. » apparaît sous l'adresse concernée
    Et l'écran ne dit pas que le document existe ni qu'il est à jour (BR-014)

  Scénario: Une adresse que l'application ne peut pas ouvrir est affichée sans bouton
    Étant donné une adresse d'arrêté que l'application ne sait pas ouvrir
    Quand la carte de ce document s'affiche
    Alors « Cette adresse ne peut pas être ouverte depuis l'application. » tient la place du bouton d'ouverture
    Et l'adresse reste lisible et sélectionnable (BR-014)

  Scénario: Une zone sans lien d'arrêté le dit
    Étant donné une zone pour laquelle la source ne fournit aucune adresse d'arrêté
    Quand l'écran l'affiche
    Alors il affiche « Le texte de l'arrêté n'est pas accessible depuis l'application : la source n'en transmet pas l'adresse. » (BR-007)
    Et l'action « Consulter les arrêtés en vigueur » de l'encart reste disponible (BR-013)
