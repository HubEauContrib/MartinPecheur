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
| **Arrêté sécheresse** | `ZoneRestriction.UrlArrete` | La décision du préfet qui fixe, pour un territoire, ce qui est limité ou interdit. **C'est le seul texte qui s'applique juridiquement.** |
| **Percentile** | `NiveauDebitCalcule.Percentile` | Une façon de situer le débit d'aujourd'hui par rapport aux mêmes dates des années passées. « Très bas » signifie : rarement aussi peu d'eau à cette période. Cela ne dit rien du niveau absolu. |
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
| « fiable », « vérifié », « officiel », « sûr » | « selon les données disponibles » | `BR-014` — aucune garantie n'est promise |
| « rien à signaler », « tout va bien » | « aucune donnée disponible ici » | `BR-007` — l'absence n'est pas un état neutre |
