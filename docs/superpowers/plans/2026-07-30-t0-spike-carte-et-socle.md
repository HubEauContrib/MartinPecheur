# T0 — Spike carte & socle données : plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUISE — utiliser `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans` pour exécuter ce plan tâche par tâche. Les étapes
> utilisent la syntaxe checkbox (`- [ ]`) pour le suivi.

**Objectif :** lever le seul risque bloquant du projet — la faisabilité de la carte en .NET — et
poser en parallèle le socle Domain/Data, qui n'en dépend pas.

**Architecture :** `MartinPecheur.Domain` en C# pur (entités, cas d'usage, interfaces de dépôt),
`MartinPecheur.Data` (mappers, clients HTTP, SQLite), `MartinPecheur.App` (MAUI). Le choix d'UI
— Blazor Hybrid ou XAML natif — reste **ouvert** jusqu'à la fin de la voie A.

**Stack cible :** .NET 9/10 · MAUI · CommunityToolkit.Mvvm · `IHttpClientFactory` + Polly ·
`sqlite-net-pcl` · MapLibre GL JS (à valider) · xUnit.

**Spec de référence :** [`03-conception.md`](../../03-conception.md) ·
**Décision en jeu :** [`ADR-005`](../../adr/ADR-005-stack-maui-blazor-hybrid.md) — statut `Proposé`

---

## Préambule pour l'exécutant

Tu ne connais pas ce projet. Quatre choses à savoir avant de commencer :

1. **Le dépôt est vide.** `MartinPecheur.sln` ne contient aucun projet. Tout est à créer.
2. **Le Domain ne dépend de rien.** Ni MAUI, ni HTTP, ni SQLite. C'est ce qui rend le socle
   (voie B) indépendant du résultat du spike (voie A). Toute référence d'infrastructure depuis
   le Domain est une erreur d'architecture, pas un détail.
3. **Les APIs mentent sur leurs unités.** Le débit arrive en **litres par seconde**, la hauteur
   en **millimètres**. Voir [`BR-002`](../../br/BR-002-debit-en-metres-cubes-par-seconde.md).
   C'est la première chose à couvrir par un test.
4. **On ne spécifie jamais d'après la documentation seule.** Si une réponse d'API contredit ce
   plan, c'est l'API qui a raison : le constater, le dater, et mettre à jour
   [`01-analyse.md`](../../01-analyse.md).

**Critère de fin d'étape, non négociable :** build Release **0 warning** + tests unitaires verts.

---

## Voie A — Spike carte (bloquant, 2 à 3 jours)

**But :** décider si [`ADR-005`](../../adr/ADR-005-stack-maui-blazor-hybrid.md) passe en `Accepté`
ou bascule sur l'option A (Mapsui). **Aucune autre décision d'UI n'est prise avant.**

- [ ] **A1 — Créer la solution.** Ajouter `MartinPecheur.App` (MAUI Blazor Hybrid, iOS + Android
      uniquement) à `MartinPecheur.sln`. Build Release vert sur les deux cibles.
- [ ] **A2 — Jeu de données de test réaliste.** Récupérer une fois
      `/v2/hydrometrie/referentiel/stations?en_service=1&size=20000&format=geojson`
      (≈ 4 140 points) et le figer en fichier local. Le spike ne doit pas dépendre du réseau.
- [ ] **A3 — Carte dans le WebView.** MapLibre GL JS dans le `BlazorWebView`, fond IGN
      Géoplateforme WMTS, source GeoJSON locale, clustering activé.
- [ ] **A4 — Mesurer.** Sur un **Android d'entrée de gamme réel**, pas un émulateur :
      images par seconde au déplacement et au zoom · mémoire résidente · temps de démarrage à
      froid · consommation au bout de 10 minutes d'usage continu.
- [ ] **A5 — Tuiles hors ligne.** Prototyper l'énumération et le téléchargement des tuiles XYZ
      d'une bbox, puis leur lecture par le WebView **sans réseau**. C'est le point faible connu :
      aucune fonction clé en main n'existe côté .NET. Chiffrer le lot réel.
- [ ] **A6 — Trancher.** Passer `ADR-005` en `Accepté`, ou écrire `ADR-008` qui le remplace par
      Mapsui. Reporter les mesures dans l'ADR — **des chiffres, pas une impression**.

> **Seuils d'échec, à fixer avant de mesurer, pas après :** moins de 30 images par seconde au
> déplacement, plus de 400 Mo résidents, ou plus de 4 secondes de démarrage à froid invalident
> l'option B.

---

## Voie B — Socle données (parallèle, indépendant du spike)

- [ ] **B1 — Projets `Domain` et `Data`.** C# pur pour `Domain`. Test d'architecture interdisant
      toute référence d'infrastructure depuis `Domain`.
- [ ] **B2 — Entités et énumérations** du modèle de [`03-conception.md § 3`](../../03-conception.md).
      Les trois échelles d'état restent **séparées**
      ([`BR-008`](../../br/BR-008-une-seule-echelle-a-la-fois.md)). Chaque énumération porte une
      valeur `Inconnu` ([`BR-011`](../../br/BR-011-nomenclature-tolerante-a-l-inconnu.md)).
- [ ] **B3 — Mappers Hub'Eau, dirigés par les tests.** Commencer par la conversion d'unités :
      `53000.0 → 53.0 m³/s` et `350571.0 → 350.571 m³/s` — valeurs réelles vérifiées le 2026-07-30.
- [ ] **B4 — Client HTTP.** `IHttpClientFactory` + Polly (retry, backoff exponentiel avec gigue).
      `DelegatingHandler` normalisant **200 et 206** en succès (`C-06`) — sans lui, toute
      pagination échoue.
- [ ] **B5 — Dépôt référentiel.** Préchargement des stations et points ONDE, persistance SQLite.
      Filtrer `en_service = false` et les coordonnées absentes. N'interroger que des **codes
      station à 10 caractères**, jamais des codes site (`C-05`, sinon doublons).
- [ ] **B6 — Dépôt observations.** `observations_tr` par bbox, pagination **par curseur**.
      Calcul d'âge et états fraîche/ancienne/périmée
      ([`BR-005`](../../br/BR-005-donnee-perimee-signalee.md)), testé aux bornes.
- [ ] **B7 — Dépôt ONDE.** Projection des 6 codes vers les 4 catégories
      ([`ADR-006`](../../adr/ADR-006-onde-quatre-categories.md)) — **fonction pure, testable**.
      Codes typés en `string`. Comparaison de type de campagne en minuscules (`C-10`).
- [ ] **B8 — `IRestrictionSource` + implémentation VigiEau.** Requêtes par `lat`/`lon`
      exclusivement. Le repli data.gouv est un lot séparé, l'interface doit juste le permettre
      ([`ADR-004`](../../adr/ADR-004-integration-vigieau.md)).

---

## Voie C — Outillage percentiles (indépendant, non bloquant)

- [ ] **C1 — Script d'aspiration.** `obs_elab/QmnJ` sur 30 ans par station, pagination curseur,
      **débit d'appel limité**. Toujours passer `date_debut_obs_elab` : sans lui, l'API renvoie
      silencieusement 1900 (`C-04`).
- [ ] **C2 — Calcul des percentiles** P10/P25/P50/P75/P90 par quinzaine calendaire. Moins de
      10 années sur une quinzaine → `Indeterminé`
      ([`BR-004`](../../br/BR-004-historique-insuffisant-indetermine.md)).
- [ ] **C3 — Format d'asset compact** + mesure du poids réel. **Mesurer, ne pas estimer** :
      le chiffre conditionne [`ADR-003`](../../adr/ADR-003-reference-percentiles-en-asset.md).
- [ ] **C4 — Documenter la procédure de régénération.** L'asset est un livrable versionné, pas
      un fichier apparu un jour dans le dépôt.

---

## Ce que T0 ne fait pas

Aucun écran final, aucun avertissement implémenté, aucune fiche de détail. Ces lots viennent
en T1, une fois `ADR-005` tranché — les quatre emplacements d'avertissement
([`BR-012`](../../br/BR-012-acquittement-au-premier-lancement.md),
[`BR-013`](../../br/BR-013-avertissement-renforce-sur-ecrans-ressource.md)) dépendent de la
technologie d'UI retenue.

**Rien ne part en production sans les quatre avertissements.** Ce n'est pas une finition.
