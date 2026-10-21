Fonctionnalité: Être prévenu d'un changement sur un lieu suivi
  # Critères d'acceptation en Gherkin — spécification lisible, jamais exécutée.
  # Vérifié par test/project/acceptance_features_test.dart.
  # Source : cadrage de T5 (2026-10-17), § 9 ; UC-010 ; BR-001, BR-003, BR-007, BR-008, BR-011, BR-014, BR-015, BR-016.
  En tant qu'usager d'un lieu en favori
  Je veux être prévenu, à l'ouverture de l'application, d'un changement du niveau publié sur ce lieu, par un avis daté et attribué
  Afin de ne jamais prendre une vérification impossible ou un silence pour une absence de changement

  # ── US-22 — Je suis prévenu, quand j'ouvre l'application, d'un changement du niveau publié sur un lieu que je suis

  # Critère 1
  Scénario: La fiche d'un tronçon porte l'étoile, et le tronçon ajouté paraît dans « Favoris »
    Étant donné la fiche d'un tronçon « Blavet », ouverte sans appel réseau
    Quand l'usager ajoute le tronçon aux favoris par l'étoile
    Alors « Favoris » montre une ligne avec le nom publié « Blavet », « Tronçon Vigicrues » et la date d'ajout, sans niveau ni mesure (BR-016)
    Et le nom gardé est celui publié au moment de l'ajout, tel quel (BR-016)

  # Critère 2
  Scénario: Ouvrir un favori tronçon passe sur la lecture Crues et ouvre sa fiche une fois la vigilance lue
    Étant donné un tronçon « Blavet » en favori, la carte sur une autre lecture
    Quand l'usager ouvre ce favori depuis « Favoris »
    Alors la carte passe sur la lecture « Vigilance crues » et la fiche du tronçon s'ouvre une fois la vigilance lue, sans que la caméra ne bouge (BR-008)
    Et si le tronçon n'est pas dans la vigilance publiée, la fiche dit « Ce tronçon n'est pas dans la vigilance publiée par Vigicrues le 14/10/2026 à 15:55. », l'étoile restant disponible (BR-007)

  # Critère 3
  Scénario: « Me prévenir » n'apparaît que pour un lieu en favori, et il est sur « Non » à l'ajout
    Étant donné la fiche d'un tronçon qui n'est pas en favori
    Quand l'usager l'ajoute aux favoris
    Alors la section « Me prévenir » apparaît, avec les choix « Non », « Jaune », « Orange » et « Rouge », et « Non » est choisi
    Et la fiche d'un lieu qui n'est pas en favori n'offre aucun réglage « Me prévenir » (BR-016)

  # Critère 4
  Scénario: Choisir « Orange » enregistre le seuil, « Favoris » le rappelle, retirer l'étoile éteint le suivi
    Étant donné la fiche d'un tronçon « Blavet » en favori, « Me prévenir » sur « Non »
    Quand l'usager choisit « Orange », puis ouvre « Favoris »
    Alors la fiche dit « Un avis à chaque changement de la vigilance publiée, dès qu'elle atteint le niveau choisi ou le quitte. » et « Favoris » rappelle « Prévenu : vigilance crues à partir de l'orange » (BR-016)
    Et si l'usager retire l'étoile, le suivi s'éteint et ne revient jamais avec un ancien favori (BR-016)

  # Critère 5
  Scénario: L'interrupteur « Me prévenir des restrictions sécheresse » des fiches station et ONDE s'enregistre et se rappelle
    Étant donné la fiche d'une station en favori et celle d'un point ONDE en favori, l'interrupteur éteint
    Quand l'usager active « Me prévenir des restrictions sécheresse » sur chacune, puis ouvre « Favoris »
    Alors chaque fiche dit « Un avis quand la gravité d'une zone d'alerte change à cet endroit, d'après VigiEau. » et « Favoris » rappelle « Prévenu : restrictions sécheresse » (BR-016)
    Et la sécheresse reste une échelle à part de la crue : l'interrupteur ne règle aucun seuil de crue (BR-008)

  # Critère 6
  Scénario: Sous chaque réglage, l'avertissement de suivi est écrit en entier
    Étant donné un lieu suivi, sur la fiche d'un tronçon, d'une station ou d'un point ONDE
    Quand le réglage « Me prévenir » s'affiche
    Alors l'avertissement de suivi suit le réglage, en entier : « CE N'EST PAS UN SYSTÈME D'ALERTE » puis « Cette application ne relit les niveaux publiés par Vigicrues et VigiEau que lorsqu'elle est ouverte, depuis cet appareil, sans serveur. Un avis peut arriver tard, ou ne pas arriver : un changement survenu entre deux ouvertures peut ne pas être vu. Elle ne remplace ni le bulletin de Vigicrues, ni les arrêtés préfectoraux, ni les consignes des autorités et des secours. » (BR-016, BR-015)
    Et il s'ajoute aux autres avertissements sans les remplacer : le contrôle « ⚠ Avertissement » de la fiche reste présent (BR-015)

  # Critère 7
  Scénario: Sans lieu suivi, aucune vérification n'appelle de source
    Étant donné des favoris dont « Me prévenir » est sur « Non » ou éteint, ou aucun favori
    Quand une vérification est lancée
    Alors ni Vigicrues ni VigiEau ne sont appelés, et rien n'est écrit (BR-016)
    Et « Avis reçus » dit « Aucun lieu n'est suivi. Un lieu en favori se suit depuis sa fiche, par « Me prévenir ». » : un silence qui se dit (BR-007)

  # Critère 8
  Scénario: Vigicrues n'est lu que si un tronçon est suivi
    Étant donné une station et un point ONDE suivis, aucun tronçon suivi
    Quand une vérification est lancée
    Alors Vigicrues n'est pas lu, et VigiEau reçoit un appel par station ou point suivi, l'un après l'autre (BR-016)
    Et dès qu'un tronçon est suivi, la vérification lit la vigilance de Vigicrues, une seule fois quel que soit le nombre de tronçons suivis (BR-015)

  # Critère 9
  Scénario: Une vérification part au lancement et au retour au premier plan, une seule à la fois
    Étant donné un lieu suivi, l'avertissement du premier lancement acquitté, et aucune vérification en cours
    Quand la carte s'affiche, puis que l'application revient au premier plan, puis que l'usager active « Vérifier maintenant », ces deux derniers pendant la vérification du lancement
    Alors une vérification part au lancement, après l'acquittement ; un retour au premier plan, sans vérification en cours, en lance une (BR-016)
    Et pendant la vérification du lancement, le retour au premier plan et « Vérifier maintenant » rendent la même : une seule court à la fois (BR-016)
    Et aucun « Suivi commencé » n'est produit en double pour un même lieu, et « Vérifier maintenant » dit « Vérification en cours… » tant qu'elle dure (BR-007)

  # Critère 10
  Scénario: La première lecture d'un lieu suivi produit « Suivi commencé », qui dit l'état publié lu
    Étant donné un tronçon « Blavet » suivi à partir de l'orange, et un point dont VigiEau cite une zone, jamais lus
    Quand la première vérification les lit
    Alors l'avis du tronçon dit « Suivi commencé », « Blavet », « Vigilance orange — information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. » puis « Prévenu : vigilance crues à partir de l'orange » (BR-001, BR-016)
    Et l'avis du point dit « Suivi commencé », le libellé du lieu, puis « Zone « Scorff » (Eaux superficielles) : Alerte d'après VigiEau, arrêté en vigueur depuis le 02/10/2026. » ou, sans zone, « VigiEau ne cite aucune zone d'alerte à cet endroit. Cela ne dit pas qu'aucune restriction ne s'y applique. » (BR-007)
    Et aucune règle de changement ne s'applique à cette lecture : l'état lu est seulement enregistré, et chaque avis porte « Reçu le … » (BR-016)

  # Critère 11
  Plan du scénario: Avec le seuil « Orange », un changement de vigilance produit un avis selon les niveaux publiés
    Étant donné un tronçon suivi à partir de l'orange, dont la dernière vigilance connue est <ancien>
    Quand la vigilance publiée devient <nouveau>
    Alors <resultat> (BR-016)
    Et la comparaison n'oppose que deux niveaux publiés : l'application n'en calcule aucun (BR-015)

    Exemples:
      | ancien | nouveau | resultat                           |
      | jaune  | orange  | un avis « Vigilance crues orange » |
      | orange | rouge   | un avis « Vigilance crues rouge »  |
      | rouge  | orange  | un avis « Vigilance crues orange » |
      | orange | jaune   | un avis « Vigilance crues jaune »  |
      | vert   | jaune   | aucun avis                         |
      | jaune  | vert    | aucun avis                         |

  # Critère 12
  Scénario: Un niveau non reconnu, ancien ou nouveau, produit un avis « niveau non reconnu »
    Étant donné un tronçon suivi, dont la vigilance publiée passe de « jaune » à un niveau que l'application ne sait pas lire (cas construit, jamais observé en production, VC-04)
    Quand la vérification compare les deux niveaux
    Alors l'avis est « Niveau de vigilance non reconnu », suivi de « Vigicrues a publié un niveau que cette application ne sait pas lire. Le bulletin sur www.vigicrues.gouv.fr fait foi. » (BR-011)
    Et si c'est l'ancien niveau qui n'est pas reconnu, la ligne de date dit « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. Avant : niveau de vigilance non reconnu. » (BR-011)

  # Critère 13
  Scénario: Une gravité changée, une zone nouvelle, une zone plus citée produisent chacune un avis qui nomme la zone et son type
    Étant donné un point suivi dont VigiEau cite la zone « Scorff » (Eaux superficielles) en « Vigilance » et la zone « Nappe du Blavet » (Eaux souterraines) en « Alerte »
    Quand la vérification lit une gravité changée pour la première, une zone nouvelle « Ellé » (Eaux superficielles), et plus aucune mention de la seconde
    Alors l'avis de gravité dit « Restrictions sécheresse : Alerte », puis « Zone « Scorff » (Eaux superficielles) : Alerte d'après VigiEau, arrêté en vigueur depuis le 02/10/2026. Avant : Vigilance. L'arrêté fait foi. » (BR-016)
    Et l'avis de la zone nouvelle dit « Avant : cette zone n'était pas citée à cet endroit. », et celui de la zone plus citée dit « Restrictions sécheresse : zone plus citée » puis « Cela ne dit pas que les restrictions sont levées : l'arrêté fait foi. » (BR-007)
    Et les avis d'eaux superficielles précèdent les autres, et une gravité non reconnue produit un avis dit « Non renseigné » (BR-011)
    Et un changement de la seule date d'arrêté, à gravité égale, ne produit aucun avis (BR-016)

  # Critère 14
  Plan du scénario: Une source injoignable, qui refuse ou dont la réponse est illisible produit un avis « Vérification impossible »
    Étant donné un tronçon « Blavet » et une station « Station du Scorff » suivis, dont aucune série d'échecs n'est ouverte
    Quand <source> est <cas>
    Alors un seul avis « Vérification impossible » est produit pour cette source, qui nomme <lieux> : « <avis> » (BR-007)
    Et un lieu déjà en série d'échecs n'est pas redit, et le dernier état connu du lieu ne change pas (BR-016)
    Et un point VigiEau en échec n'empêche pas les autres points de se lire, chaque point ayant sa série (BR-016)

    Exemples:
      | source    | cas                | lieux     | avis                                                                                                                                                  |
      | Vigicrues | injoignable        | Blavet | Vigicrues n'a pas répondu : aucun avis de crue n'a pu être donné pour Blavet. Cela ne dit rien du risque de crue.                                      |
      | Vigicrues | refusée            | Blavet | Vigicrues a refusé la demande : aucun avis de crue n'a pu être donné pour Blavet. Cela ne dit rien du risque de crue.                                  |
      | Vigicrues | illisible          | Blavet | La vigilance publiée par Vigicrues n'a pas pu être lue : aucun avis de crue n'a pu être donné pour Blavet. Cela ne dit rien du risque de crue.         |
      | VigiEau   | injoignable        | Station du Scorff | VigiEau n'a pas répondu : aucun avis de restrictions n'a pu être donné pour Station du Scorff. Cela ne dit rien des restrictions en vigueur.                 |
      | VigiEau   | refusée            | Station du Scorff | VigiEau a refusé la demande pour Station du Scorff : aucun avis de restrictions n'a pu être donné. Cela ne dit rien des restrictions en vigueur.            |
      | VigiEau   | illisible          | Station du Scorff | La réponse de VigiEau n'a pas pu être lue pour Station du Scorff : aucun avis de restrictions n'a pu être donné. Cela ne dit rien des restrictions en vigueur. |

  # Critère 15
  Plan du scénario: Un lieu absent de ce qui est publié produit un avis « Lieu non vérifiable », une fois par série
    Étant donné <lieu>, suivi
    Quand la vérification ne peut pas le rattacher à ce qui est publié
    Alors un avis « Lieu non vérifiable » dit « <avis> », une seule fois tant que la série dure (BR-016)
    Et aucun avis de crue ni de restrictions n'est donné pour lui, et aucun n'est rangé en « Vérification impossible » (BR-007)

    Exemples:
      | lieu                                                  | avis                                                                                                                                       |
      | un tronçon absent de la vigilance publiée             | Blavet : ce tronçon n'est pas dans la vigilance publiée par Vigicrues le 14/10/2026 à 15:55. Aucun avis de crue ne peut être donné pour lui. |
      | un tronçon peut-être parmi les entités illisibles     | Blavet : ce tronçon n'a pas pu être lu dans la vigilance publiée par Vigicrues le 14/10/2026 à 15:55. Aucun avis de crue ne peut être donné pour lui. |
      | une station absente du référentiel embarqué           | Station du Scorff : cette station n'est pas dans le référentiel embarqué. Aucun avis de restrictions ne peut être donné pour elle.            |

  # Critère 15 bis
  Scénario: Un suivi, une liste d'avis ou une liste de favoris illisibles bloquent la vérification, qui le dit
    Étant donné le suivi, les avis ou la liste des favoris enregistrés sur l'appareil, illisibles
    Quand une vérification est lancée
    Alors aucune source n'est appelée et rien n'est écrit, et l'annonce de la carte dit « Aucune vérification n'a été faite : les avis ou les réglages enregistrés n'ont pas pu être lus. » avec l'action « Lire les avis » (BR-007, BR-011)
    Et « Avis reçus » dit, pour les avis, « Les avis enregistrés sur cet appareil n'ont pas pu être lus. Ils sont conservés tels quels : aucune vérification n'est faite tant que la liste n'est pas remplacée. », et pour les réglages, « Les réglages « Me prévenir » enregistrés sur cet appareil n'ont pas pu être lus. Ils sont conservés tels quels : aucune vérification n'est faite tant qu'ils ne sont pas remplacés. » (BR-011)
    Et pour la liste des favoris, « La liste des favoris n'a pas pu être lue : aucune vérification n'est faite tant qu'elle n'est pas remplacée, depuis l'écran « Favoris ». » (BR-007)
    Et « Repartir d'une liste vide » (avis, ou favoris depuis l'écran « Favoris ») et « Repartir sans lieu suivi » (réglages) sont les seuls gestes qui remplacent une racine illisible, et seulement à ce geste (BR-011)

  # Critère 16
  Scénario: Chaque avis porte son échelle, le lieu, le niveau publié et le précédent, la date, la source et « Reçu le … »
    Étant donné un avis de crue et un avis de sécheresse reçus
    Quand « Avis reçus » les affiche
    Alors l'avis de crue porte le titre « Vigilance crues orange », le nom du tronçon, « Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. Avant : vigilance jaune. » et « Reçu le 14/10/2026 à 16:02 » (BR-001, BR-016)
    Et l'avis de sécheresse porte son titre, le libellé du lieu, la zone, la gravité d'après VigiEau, la date d'entrée en vigueur de l'arrêté, la gravité précédente et « Reçu le … » (BR-001)
    Et un avis porte une seule échelle, crues ou sécheresse, jamais les deux (BR-008)
    Et un avis n'est pas un lien (BR-016)

  # Critère 17
  Scénario: La liste garde les 100 avis les plus récents
    Étant donné 100 avis enregistrés
    Quand une vérification en produit 3 de plus
    Alors la liste garde les 100 plus récents, les 3 nouveaux en tête, et les 3 plus anciens quittent la liste (BR-016)
    Et un avis enregistré mais illisible par cette version de l'application s'affiche seul, « Avis non lisible par cette version de l'application », et est gardé tel quel (BR-011)

  # Critère 18
  Scénario: Un avis nouveau est annoncé sur la carte, « Lire les avis » ouvre « Avis reçus », les non lus sont marqués « Nouveau »
    Étant donné une vérification qui vient de produire 2 avis
    Quand la carte l'annonce, puis que l'usager active « Lire les avis »
    Alors l'annonce dit « 2 avis nouveaux sur vos lieux suivis », avec « Lire les avis » et « Fermer l'annonce », sans bouton de plus dans les colonnes de la carte (BR-016)
    Et « Avis reçus » s'ouvre, l'annonce disparaît, et les avis non lus portent « Nouveau » jusqu'à la fermeture de l'écran (BR-016)
    Et avec un seul avis, l'annonce dit « 1 avis nouveau sur vos lieux suivis », et sans avis nouveau, aucune annonce ne paraît (BR-007)

  # Critère 19
  Scénario: « Avis reçus » porte en tête l'encart, le lien, la dernière vérification et « Vérifier maintenant »
    Étant donné l'écran « Avis reçus » ouvert depuis « Favoris », qui montre « Avis reçus — 2 nouveaux »
    Quand il s'affiche
    Alors il porte dans l'ordre : l'encart non repliable « CE N'EST PAS UN SYSTÈME D'ALERTE », annoncé en priorité, le lien « Lire la vigilance sur www.vigicrues.gouv.fr », « Dernière vérification : le 14/10/2026 à 16:02 » ou « Aucune vérification pour l'instant. », puis « Vérifier maintenant » (BR-016, BR-015)
    Et sa fenêtre « ⚠ Avertissement » porte le texte général puis le texte de suivi (BR-016)
    Et si le lien ne s'ouvre pas, « Ce lien n'a pas pu être ouvert depuis l'application. Son adresse reste affichée ci-dessus. » s'affiche, l'adresse restant lisible et sélectionnable (BR-007)
    Et si l'écriture des avis échoue, « La dernière vérification n'a pas pu être enregistrée sur cet appareil. » s'affiche, et la vérification suivante redonne les mêmes avis (BR-007)

  # Critère 20
  Scénario: Passé 30 minutes, une vérification attend la nouvelle vigilance ; avant, elle reprend celle du cache
    Étant donné une carte de vigilance lue en cache, un tronçon suivi
    Quand une vérification est lancée moins de 30 minutes après la lecture, puis une autre plus de 30 minutes après
    Alors la première reprend la vigilance du cache sans aucun appel (BR-016)
    Et la seconde attend la nouvelle vigilance au lieu de comparer l'ancienne, et si cette lecture échoue, elle dit « Vérification impossible » sans jamais comparer à la carte périmée, la carte de l'écran gardant l'ancienne vigilance avec sa date (BR-001, BR-007)
    Et VigiEau suit le même principe, par un cache de 6 heures, un appel par station ou point ONDE suivi (BR-016)

  # Critère 21
  Scénario: Aucun texte de suivi ne qualifie un débit, ne donne de consigne ni ne promet
    Étant donné l'ensemble des textes de suivi : avis, réglages, annonce, encart, fenêtre « ⚠ Avertissement » d'« Avis reçus »
    Quand on les relit
    Alors aucun ne qualifie un débit (BR-003), aucun ne porte de verbe d'instruction sur un usage de l'eau ni de mot de garantie (BR-014)
    Et aucun ne dit « fin de vigilance », « danger écarté » ni « restrictions levées », et aucun ne rapproche un débit, une hauteur ou un écoulement d'un avis (BR-016, BR-015)
