# BR-006 — Le statut de qualification est toujours affiché

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Hydrometrie

## Règle

> Toute fiche de station affiche le **statut** et la **qualification** de la mesure.
> La mention « donnée brute, non qualifiée » est la valeur par défaut, pas une exception.

## Justification

Le débit temps réel Hub'Eau est une donnée **brute ou corrigée, non qualifiée**. Valeurs relevées en production le 2026-07-30 :

| Champ | Valeurs observées |
|---|---|
| `libelle_statut` | `Brute` (Rhône), `Corrigée` (Loire à Blois) |
| `libelle_qualification_obs` | `Non qualifiée` — cas courant en temps réel |
| `libelle_methode_obs` | `Calculée` — le débit est déduit d'une courbe de tarage, il n'est pas mesuré directement |

Le débit n'est presque jamais mesuré : il est **calculé** à partir d'une hauteur d'eau et d'une courbe d'étalonnage, qui peut dériver (encrassement, embâcle, modification du lit). L'usager doit pouvoir distinguer une valeur pré-validée d'une valeur brute.

## Invariants & cas limites

- Nomenclature de `code_qualification_obs` : `0` Neutre, `4` Faible, `8` Forte, `12` Douteuse, `16` Non qualifiée, `20` Bonne, `30` Estimée.
- `code_methode_obs = 8` (« Calculée ») **existe en production mais est absent de la documentation**. Toute valeur hors nomenclature suit `BR-011`.
- Sur l'historique `obs_elab`, les statuts diffèrent : `Donnée validée`, méthode `Expertisée`, qualification `Bonne`. La distinction historique/temps réel est portée à l'écran.
- Absent de la carte : le statut figure sur la fiche, pas sur le marqueur — il ne doit pas concurrencer l'échelle d'état active (`BR-008`).
- Les libellés `libelle_statut` et `libelle_qualification_obs` sont cités **verbatim** (ex. « Bonne », « Pré-validée ») : ce sont des qualifications de la **mesure** par le producteur, jamais une qualification du **débit** par le produit — ils échappent donc au balayage de `BR-003`, qui ne porte que sur la copie rédigée par le produit. Même exemption que les niveaux de gravité VigiEau, repris tels quels parce qu'ils émanent d'une autorité et sont attribués (`BR-003`, dernier invariant ; `BR-014`). Conséquence pour les tests : un balayage de vocabulaire neutralise ces deux libellés avant de mesurer, et il balaye **par mot entier** — une recherche par sous-chaîne confondrait « Bonne » avec le mot banni « bon ».

## Vérifiable par

Test d'instantané de la fiche station vérifiant la présence des deux libellés. Test unitaire : une réponse sans champ de qualification produit « non qualifiée », jamais une chaîne vide.

## Liens

- Use cases : `UC-003`
- ADR liés : `ADR-001`
- Contrainte d'API : `C-11`
- Voir aussi : `BR-001`, `BR-011`
