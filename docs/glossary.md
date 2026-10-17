# Glossaire

Langage omniprésent du projet. **Colonne « Dit à l'usager »** = le texte exact affiché ;
il fait foi sur toute reformulation. **Colonne « Code »** = l'identifiant employé dans le
modèle et les APIs.

## Termes métier

| Terme | Code | Dit à l'usager |
|---|---|---|
| **Débit** | `ValeurM3S` | La quantité d'eau qui passe à un endroit de la rivière, chaque seconde. Plus le débit est élevé, plus il y a d'eau qui s'écoule. |
| **m³/s** | — | L'unité du débit. 1 m³/s, c'est environ 1 000 litres qui passent chaque seconde. |
| **Étiage** | — | La période de l'année où la rivière est naturellement au plus bas, en général en fin d'été. C'est normal, mais c'est aussi le moment le plus sensible. |
| **Assec** | `CodeEcoulement = "3"` | **À sec** — le lit du cours d'eau est sec, plus d'eau visible du tout à l'endroit observé. |
| **Écoulement non visible** | `CodeEcoulement = "2"` | **Eau stagnante** — il reste de l'eau, en flaques ou en mares, mais elle ne coule plus visiblement. |
| **Écoulement visible faible** | `CodeEcoulement = "1f"` | **Écoulement faible** — l'eau coule encore, mais faiblement. Principal signal précurseur d'assèchement. |
| **Station hydrométrique** | `Station` | Un appareil installé à un point précis de la rivière, qui mesure en continu la hauteur d'eau et en déduit le débit. Il n'y en a pas partout. |
| **Point ONDE** | `PointOnde` | Un endroit où des agents viennent regarder l'état d'un petit cours d'eau, quelques fois par an. |
| **Campagne d'observation** | `CampagneOnde` | Une tournée de terrain, à date fixe, de mai à septembre. Entre deux campagnes, personne ne regarde. |
| **Donnée brute / non validée** | `LibelleStatut`, `LibelleQualification` | Une mesure transmise automatiquement, avant vérification humaine. Elle peut être fausse et être corrigée ou supprimée plus tard. |
| **Arrêté sécheresse** | ~~`ZoneRestriction.UrlArrete`~~ `RestrictionDecree.document` (T2) | La décision du préfet qui fixe, pour un territoire, ce qui est limité ou interdit. **C'est le seul texte qui s'applique juridiquement.** |
| **Percentile** | `NiveauDebitCalcule.Percentile` | Une façon de situer le débit d'aujourd'hui par rapport aux mêmes dates des années passées. « Très bas » signifie : rarement aussi peu d'eau à cette période. Cela ne dit rien du niveau absolu. |
| **Zone d'alerte** | `AlertZone` (T2) | Un territoire, tel que VigiEau le publie, où s'applique un niveau de gravité sécheresse pour un type d'eau, selon un arrêté. Un même point peut se trouver dans plusieurs zones d'alerte, chacune avec son niveau, ses dates et ses usages restreints : aucune n'est « la » zone du point. Quand une zone d'eaux superficielles précède, l'écran dit sous « Autres zones au même point » : « Le point désigné se trouve aussi dans ces zones d'alerte. Chacune a son niveau et ses usages. » Sans zone d'eaux superficielles (arbitrage du 2026-10-06, cas jamais constaté par appel réel), rien ne précède : il écrit d'abord « VigiEau ne renvoie aucune zone d'alerte d'eaux superficielles pour ce point. » puis la phrase de `BR-007`, et, sous le titre « Zones d'alerte à ce point », « Le point désigné se trouve dans ces zones d'alerte. Chacune a son niveau et ses usages. » Si l'une des zones est de type non reconnu, il tait les deux premières phrases : il ne sait pas si cette zone est d'eaux superficielles (`BR-011`). |
| **Type de zone** | `ZoneKind` (T2) | Ce que couvre une zone d'alerte : « Eaux superficielles » (code `SUP`, présentées en premier), « Eaux souterraines » (`SOU`), « Eau potable » (`AEP`), ou « Type de zone non renseigné » pour une valeur inconnue — la zone est gardée, jamais écartée, et la valeur brute n'est pas affichée (`BR-011`). |
| **Profil d'usager** | `UserProfile` (T2) | Le choix que fait l'usager pour filtrer les usages restreints : « Particulier », « Exploitation », « Collectivité », « Entreprise ». **Aucun n'est présélectionné.** Il ne change ni le niveau de gravité ni la requête, seulement les usages affichés ; il est gardé le temps de la session et jamais enregistré. |
| **Arrêté-cadre** | `RestrictionDecree.frameworkDocument` (T2) | Le second document PDF que la source rattache à une zone, distinct de l'arrêté de restriction : « Ouvrir l'arrêté-cadre » à côté de « Ouvrir l'arrêté ». Ce que contient un arrêté-cadre n'est pas défini par ce projet, et l'application ne l'explique pas : elle donne son adresse et le moyen de l'ouvrir. Seul l'arrêté fait foi. |
| **Point désigné** | `GeoPoint` (T2) | Le lieu que l'usager désigne sur la carte pour lire les restrictions : le choix « Restrictions » puis le bouton « Restrictions au centre de la carte », un appui long, ou un clic droit. L'écran le rappelle : « Point désigné : 46,20000° N, 5,22600° E ». Ce n'est ni la position de l'appareil, ni une station : une restriction se lit en un lieu, jamais d'une station. |
| **Filtre** | `MapFilter` (T3) | Ce qui masque des lieux à l'intérieur de l'échelle affichée : des états (écoulement), un département, la fraîcheur d'une mesure (débit). Il ne choisit pas l'échelle — c'est le **sélecteur de lecture** (voir ce terme), qui a remplacé les puces d'échelle. Un lieu masqué n'est pas une absence de donnée. Gardé le temps de la session, jamais enregistré. |
| **Sélecteur de lecture** | — (tranche d'ergonomie) | Le choix, en tête de la carte, de ce que la carte montre : quatre entrées, chacune avec un titre et un sous-titre — « Écoulement » (observé sur le terrain), « Débit » (relatif à l'historique), « Vigilance crues » (publiée par Vigicrues) et « Restrictions » (arrêtés préfectoraux). Les trois premières sont des lectures : une seule est affichée à la fois (`BR-008`). « Restrictions » est un interrupteur, un mode de désignation et non une échelle : il s'allume en plus de la lecture affichée. Il remplace les puces d'échelle. |
| **Bloc de lecture** | — (tranche d'ergonomie) | Ce que la carte pose en tête, d'un seul tenant : le sélecteur de lecture, l'en-tête de la légende (« Légende · » suivi du nom de la lecture, avec le contrôle « ⚠ Avertissement » à droite du nom, ou dessous et aligné à droite quand le nom ne tient pas à côté sans couper un mot), l'avis éventuel, puis la légende. Le sélecteur et l'en-tête restent entiers ; l'avis et la légende défilent dans le bloc quand la place manque. |
| **Carte visible** | — (tranche d'ergonomie) | La partie de l'écran où la carte se voit, une fois la fiche posée : l'écran entier sans fiche, la part au-dessus d'une fiche du bas, la part à gauche d'un panneau latéral. Tout ce qui appartient à la carte (bloc de lecture, bas de la carte, réticule, attribution) s'y pose, et aucune fiche n'est peinte par-dessus. Ouvrir ou fermer une fiche ne déplace pas la carte. |
| **Fiche du bas** | — (tranche d'ergonomie) | La place d'une fiche — station, point ONDE ou tronçon de vigilance crues — quand la fenêtre fait moins de 800 px de large : toute la largeur, au bas de l'écran, sous la carte visible. Son en-tête (nature, « ⚠ Avertissement », étoile, fermeture) reste épinglé ; le reste défile. |
| **Panneau latéral** | — (tranche d'ergonomie) | La place d'une fiche quand la fenêtre fait 800 px de large ou plus : un panneau de 380 px à droite, sur toute la hauteur de la fenêtre, la carte visible à sa gauche. Même fiche, même en-tête épinglé que la fiche du bas. |
| **Favori** | `Favorite` (T3) | Un lieu que l'usager choisit de retrouver — une station hydrométrique ou un point ONDE. L'application en garde l'identité (nom, code, date d'ajout), jamais une mesure. |
| **Vigilance crues** | `FloodVigilanceMap` (T4) | Le niveau de vigilance que Vigicrues publie pour un tronçon de cours d'eau, à une date. L'application le relaie, datée et attribuée ; elle ne calcule et ne prévoit aucun risque de crue (`BR-015`). |
| **Tronçon de vigilance crues** | `FloodSection` (T4) | Le tronçon de cours d'eau pour lequel Vigicrues publie un niveau. Un cours d'eau sans trait de couleur n'est pas suivi : cela ne dit rien du risque (`BR-007`). |
| **Territoire de vigilance crues** | `FloodSection.territoryCode` (T4) | Le territoire de vigilance auquel Vigicrues rattache un tronçon, désigné par son code tel que publié. |
| **Niveau de vigilance crues** | `FloodVigilanceLevel` (T4) | Vert, jaune, orange ou rouge, d'après la nomenclature Sandre 837. Toute autre valeur s'affiche « Niveau non reconnu » (`BR-011`). L'application relaie le niveau publié, elle ne le déduit pas. |
| **Information de vigilance** | `FloodVigilanceMap` (T4) | La carte de vigilance publiée par Vigicrues, datée par Vigicrues. Sans date lisible, elle n'est pas affichée (`BR-001`). |
| **Vigicrues** | — | Le service de l'État qui publie la vigilance crues : le SCHAPI et le réseau Vigicrues. L'application le cite et lui attribue ce qu'elle relaie ; elle n'en est pas l'auteur. |
| **UDI** | — | La zone desservie par un même réseau d'eau du robinet. **Concerne l'eau potable, pas la rivière.** Hors périmètre v1 (`ADR-007`). |

## Contextes bornés

| Contexte | Périmètre |
|---|---|
| `Referentiel` | Stations, points ONDE, départements. Donnée quasi-statique. |
| `Hydrometrie` | Débit et hauteur mesurés, historique, positionnement statistique. |
| `Ecoulement` | Observations ONDE, campagnes. |
| `Restrictions` | Zones, niveaux de gravité, usages restreints, arrêtés. |
| `Carte` | Agrégation, clustering, échelles d'état, hors-ligne. |
| `Avertissement` | Les quatre emplacements, acquittement, textes de limites. |
| `Crues` | Vigilance crues publiée par Vigicrues, relayée par tronçon, datée et attribuée ; l'application ne calcule aucun niveau ni risque (`BR-015`). |

## Vocabulaire proscrit

Un concept, un mot. Les synonymes stylistiques sont interdits — ils font croire à des
notions différentes.

| Proscrit | Retenu | Motif |
|---|---|---|
| « suffisant », « insuffisant » | « bas », « très bas » pour la saison | `BR-003` — aucun seuil de référence n'existe |
| « normal », « dans la normale » | « habituel pour la saison » | `BR-003` — « normal » suggère une adéquation écologique |
| « assec », « tari », « asséché » | **« à sec »** partout | Un concept, un mot |
| « en direct », « temps réel » | « dernière mesure connue » | La fraîcheur va de 7 minutes à 9 jours |
| « fiable », « vérifié », « officiel », « sûr » | « selon les données disponibles » | `BR-014` — aucune garantie n'est promise, sauf pour attribuer une nomenclature à sa source, comme « Modalité officielle ONDE : » (`UC-004 § 3`) — le mot qualifie alors l'origine, jamais nos données |
| « rien à signaler », « tout va bien » | « aucune donnée disponible ici » | `BR-007` — l'absence n'est pas un état neutre |
