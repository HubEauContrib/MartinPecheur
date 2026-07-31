# UC-005 — Consulter la dernière carte hors ligne

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Carte
- **Acteur principal :** Pêcheur (P3), Usager de loisir (P4) · **Acteurs secondaires :** cache local, pack de tuiles

## Objectif

Retrouver la dernière carte consultée sans réseau — le cas courant au bord de l'eau, où le produit est le plus utile et la couverture la plus mauvaise.

## Préconditions

- Une carte a déjà été consultée en ligne : `DerniereVueCarte` est renseignée (postcondition de `UC-001`).
- Un pack de tuiles a été téléchargé pour cette zone.

## Déclencheur

L'usager ouvre l'application alors que `Connectivity.NetworkAccess` indique l'absence de réseau, ou perd le réseau en cours d'usage.

## Flux nominal

1. L'application lit `DerniereVueCarte` et centre la carte sur la bbox enregistrée, au zoom enregistré.
2. Les tuiles sont servies depuis le pack local, via un gestionnaire de schéma personnalisé.
3. Les stations et points de la bbox sont lus en base, avec leur **dernière observation connue et sa date**.
4. Un **bandeau persistant** s'affiche : *« Mode hors-ligne — données du JJ/MM/AAAA à HH:MM. »*
5. Les données de plus de 24 heures restent atténuées (`BR-005`) : l'absence de réseau n'excuse pas l'absence de signalement.
6. Le rafraîchissement est désactivé ; aucune tentative répétée ne consomme la batterie.

```mermaid
stateDiagram-v2
    [*] --> EnLigne
    EnLigne --> HorsLigne : perte de réseau
    HorsLigne --> EnLigne : retour du réseau
    state EnLigne {
        [*] --> Rafraichissement
        Rafraichissement --> MajVue : stabilisation de la carte
        MajVue --> TelechargementTuiles : bbox ± marge
    }
    state HorsLigne {
        [*] --> LectureCache
        LectureCache --> BandeauPersistant
        note right of BandeauPersistant : « données du JJ/MM à HH:MM »
    }
```

## Flux alternatifs / erreurs

- **A1 — Aucune vue enregistrée** (première ouverture sans réseau) : message explicite d'absence de données, jamais une carte vide qui laisserait croire à une absence de problème (`BR-007`).
- **A2 — Pack de tuiles absent ou incomplet :** les marqueurs et leurs états restent affichés sur fond neutre. L'information métier ne dépend pas du fond de carte.
- **A3 — L'usager sort de la bbox téléchargée :** la zone non couverte est signalée comme telle, pas rendue en blanc silencieux.
- **A4 — Retour du réseau :** rafraîchissement en tâche de fond, le bandeau disparaît, les dates se mettent à jour. Aucune interruption de la navigation.
- **A5 — Écran de restrictions hors ligne :** dernière réponse en cache, avec sa date. **L'avertissement renforcé reste affiché** (`BR-013`) — il est d'autant plus nécessaire que la donnée est datée.

## Postconditions

- Aucune écriture réseau. Le cache n'est pas modifié.
- Aucune donnée d'usage n'est enregistrée ni transmise.

## Règles métier référencées

- `BR-001` — date obligatoire
- `BR-005` — donnée périmée atténuée
- `BR-007` — l'absence n'est jamais un état neutre
- `BR-013` — avertissement renforcé, y compris hors ligne

## Liens

- ADR : [`ADR-010`](../adr/ADR-010-react-native.md) — le téléchargement de tuiles est fourni par **`OfflineManager.createPack`** (région + niveaux de zoom), vérifié le 2026-07-31. *Auparavant `ADR-005` en faisait un lot de développement à chiffrer, faute d'équivalent côté .NET — c'est ce point qui a motivé la bascule de stack.*
- Écran : [`04-ui.md § 1`](../04-ui.md) · Conception : [`03-conception.md § 4.3`](../03-conception.md)
