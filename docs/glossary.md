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
