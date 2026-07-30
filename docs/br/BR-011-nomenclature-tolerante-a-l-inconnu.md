# BR-011 — Toute nomenclature tolère une valeur inconnue

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Referentiel · Hydrometrie · Ecoulement · Restrictions

## Règle

> Toute valeur de nomenclature reçue d'une API et non reconnue est traduite en
> **« non renseigné »** et affichée comme telle. Elle ne provoque jamais d'erreur,
> et n'est jamais silencieusement assimilée à une valeur connue.

## Justification

Les nomenclatures publiées ne correspondent pas à ce que les APIs renvoient réellement. Constats du 2026-07-30 :

| Cas | Documentation | Production |
|---|---|---|
| `code_methode_obs` | Nomenclature `0`, `4`, `12` | **`8` (« Calculée ») existe en production**, absent de la doc |
| Type de campagne ONDE | `Usuelle`, `Complémentaire` | **`usuelle`, `complémentaire`** en minuscules |
| `code_ecoulement` | Attendu numérique | **Chaînes** : `"1a"`, `"1f"` |
| Niveaux VigiEau | `vigilance` attendu | **Non observé** dans l'échantillon du 2026-07-30 — existence non vérifiée |

Ces sources sont publiques, sans SLA, et évoluent sans préavis. Un `switch` exhaustif qui lève sur une valeur inconnue rendrait l'application inutilisable le jour où l'OFB ajoute une modalité.

## Invariants & cas limites

- Branche par défaut **obligatoire** sur toute conversion de nomenclature. Une énumération sans valeur `Inconnu` est un défaut de conception.
- La valeur brute reçue est **conservée en base**, même non reconnue : elle reste exploitable après mise à jour du mapping, et diagnosticable.
- « Non renseigné » est un état affiché (`BR-007`), pas une absence de marqueur ni un état neutre.
- Ne participe pas au classement de sévérité (`BR-009`).
- S'applique aussi aux **champs supplémentaires** : une réponse contenant des champs inconnus est désérialisée sans échec.
- Ne s'applique **pas** aux ruptures structurelles : un changement de forme de réponse VigiEau déclenche le repli de `ADR-004`, pas une valeur « non renseigné ».

## Vérifiable par

Test unitaire par nomenclature : une valeur hors énumération renvoie `Inconnu` sans lever. Test de désérialisation sur une charge utile contenant un champ inédit.

## Liens

- Use cases : tous
- ADR liés : `ADR-001`, `ADR-004`, `ADR-006`
- Contraintes d'API : `C-10`, `C-11`
- Voir aussi : `BR-006`, `BR-007`
