# ADR-003 — Pré-calculer les percentiles dans un asset embarqué

- **Statut :** Accepté
- **Date :** 2026-07-30

## Contexte

L'ADR-002 impose un positionnement statistique du débit. La matière première existe et elle est excellente : `obs_elab` avec `grandeur_hydro_elab=QmnJ` remonte à **1900-01-01**, en `libelle_statut = "Donnée validée"`, `libelle_methode = "Expertisée"`, `libelle_qualification = "Bonne"`.

Mais Hub'Eau **n'expose aucun percentile**, et le référentiel compte **4 140 stations en service**. Deux contraintes s'opposent :

- calculer sur le téléphone pour toutes les stations est hors de portée, et martèlerait une API sans quota documenté, en fair-use ;
- le périmètre v1 exclut explicitement un backend.

## Décision

Un **script de build, exécuté hors application**, aspire `obs_elab/QmnJ` sur 30 ans pour les stations en service et pré-calcule **P10 / P25 / P50 / P75 / P90 par quinzaine calendaire**. Le résultat est embarqué comme **asset versionné**, livré avec l'application.

Aucun appel réseau au runtime pour cette donnée. **Ce n'est pas un backend** : c'est un artefact de build, versionné comme le code, régénéré à chaque release.

Une station comptant moins de **10 années** de relevés sur la quinzaine considérée est classée **« Indéterminé »**, jamais approximée.

## Conséquences

- ➕ La carte peut être colorée par niveau de débit — impossible avec un calcul à la demande.
- ➕ Aucune charge d'appel supplémentaire sur Hub'Eau depuis la base installée.
- ➕ Fonctionne hors ligne par construction.
- ➖ Coûts détaillés ci-dessous.

| Conséquence négative | Traitement |
|---|---|
| L'asset **vieillit entre deux releases** | Il porte sa date de génération, affichée dans « À propos » |
| Le script de build est un **livrable à maintenir** | Versionné, avec procédure de régénération documentée |
| Poids ajouté au binaire — ordre de grandeur : 4 140 stations × 24 quinzaines × 5 valeurs, soit ~500 000 valeurs, quelques Mo en format compact. **À mesurer** | Format binaire compact plutôt que JSON |
| L'aspiration initiale est longue | Job hors ligne, throttlé, exécuté rarement |

## Alternatives écartées

- **Calcul à la demande sur le téléphone** : une station consultée = une requête curseur, mise en cache. Simple, sans outillage. Mais la carte ne peut alors plus être colorée par niveau de débit — seulement par écoulement ONDE et gravité sécheresse. L'écart d'expérience a été jugé supérieur au coût de l'outillage.
- **Backend de calcul** : hors périmètre v1, explicitement exclu au cadrage.

## Si la décision est revue

Bascule vers le calcul à la demande : l'échelle 2 disparaît de la carte et ne subsiste que sur la fiche station. La table `ReferencePercentile` devient un cache alimenté par le réseau au lieu d'un asset en lecture seule. Le contrat de `NiveauDebitCalcule` est inchangé.
