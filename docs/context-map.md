# Carte des contextes

Six contextes bornés, aucun backend. Toutes les sources sont des **APIs publiques
externes**, sans authentification et **sans SLA** — le contrat est subi, jamais négocié.

```mermaid
flowchart TB
    subgraph EXT["Sources externes — subies, sans SLA"]
        HE2[("Hub'Eau v2<br/>hydrométrie")]
        HE1[("Hub'Eau v1<br/>écoulement ONDE")]
        VE[("VigiEau 0.1<br/>beta.gouv.fr")]
        DG[("data.gouv<br/>exports quotidiens")]
        IGN[("IGN Géoplateforme<br/>tuiles WMTS")]
    end

    subgraph APP["MartinPecheur — application seule"]
        REF["Referentiel<br/>stations, points, départements"]
        HYD["Hydrometrie<br/>débit, historique, percentiles"]
        ECO["Ecoulement<br/>observations, campagnes"]
        RES["Restrictions<br/>zones, gravité, arrêtés"]
        CAR["Carte<br/>agrégation, échelles, hors-ligne"]
        AVE["Avertissement<br/>4 emplacements, acquittement"]
    end

    ASSET[["Asset embarqué<br/>référence percentiles<br/>généré au build"]]

    HE2 --> REF
    HE2 --> HYD
    HE1 --> REF
    HE1 --> ECO
    VE --> RES
    DG -.repli.-> RES
    IGN --> CAR
    ASSET --> HYD

    REF --> CAR
    HYD --> CAR
    ECO --> CAR
    RES --> CAR
    AVE -.traverse tous les écrans.-> CAR
    AVE -.-> HYD
    AVE -.-> ECO
    AVE -.-> RES
```

## Relations entre contextes

| Amont → Aval | Nature | Contrat |
|---|---|---|
| `Referentiel` → `Carte` | Fournisseur | Position et identité des points. Quasi-statique |
| `Hydrometrie` → `Carte` | Fournisseur | Échelle 2 (niveau de débit) |
| `Ecoulement` → `Carte` | Fournisseur | Échelle 1 (écoulement) |
| `Restrictions` → `Carte` | Fournisseur | Échelle 3 (sévérité sécheresse) |
| `Avertissement` → tous | **Transverse, non négociable** | Aucun écran ne s'affranchit de `BR-012` / `BR-013` |
| Asset percentiles → `Hydrometrie` | Fournisseur, lecture seule | Généré hors application (`ADR-003`) |

**Les trois échelles ne fusionnent jamais** (`BR-008`) : un fait observé, une statistique
et une décision préfectorale sont trois natures distinctes.

## Comment un écran atteint un contexte

Un contexte borné est atteint **par un dépôt, jamais autrement**. Le chemin est le même pour
les six, et il est direct — **View → ViewModel → Repository → Service**
([`ADR-014`](adr/ADR-014-feature-first-mvvm.md), *feature-first* + MVVM) :

```mermaid
flowchart LR
    V["View<br/>widgets d'une tranche"] -->|"écoute, déclenche une action"| VM["ViewModel<br/>ChangeNotifier, un par écran"]
    VM -->|"appel typé"| R["Repository du contexte<br/>+ décorateur CachePolicy"]
    R --> S["Service / DataSource"]
    S -.-> EXT[("source externe<br/>ou asset embarqué")]
```

Trois conséquences sur la carte des contextes :

- **Un widget n'atteint aucun contexte directement.** Il passe par le ViewModel de son écran.
- **Un écran qui croise deux contextes croise deux dépôts**, dans son ViewModel — c'est là, et
  nulle part ailleurs, que l'agrégation du contexte `Carte` s'écrit.
- **Le contexte `Avertissement` reste transverse** : il ne dépend d'aucune donnée, donc d'aucun
  dépôt. Il traverse les vues (`BR-012`, `BR-013`).

## Couches anticorruption

| Source | Protection | Motif |
|---|---|---|
| VigiEau | **`RestrictionSource`**, deux implémentations | API en version `0.1` sur `beta.gouv.fr`, rupture possible sans préavis (`ADR-004`) |
| Hub'Eau | Mappers dédiés par endpoint | Unités trompeuses, nomenclatures incomplètes, doublons site/station (`BR-002`, `BR-011`) |
| Toutes | `BR-011` — branche par défaut obligatoire | Sources publiques sans engagement de stabilité |

## Ce qui n'existe pas, et pourquoi

| Absent | Motif |
|---|---|
| Backend, base serveur | Hors périmètre v1. Contourné par un asset généré au build (`ADR-003`) |
| Compte utilisateur | Hors périmètre v1. Les favoris sont locaux |
| Catalogue d'événements | Aucun événement de domaine, aucun event sourcing, aucune projection, **aucun registre de messages** ([`ADR-014`](adr/ADR-014-feature-first-mvvm.md)). Un écran demande une donnée par un **appel typé** de son ViewModel à un dépôt ; rien ne publie, rien ne s'abonne — sauf la vue, qui écoute son propre ViewModel |
| Contexte `Qualite` | Écarté (`ADR-007`) |
