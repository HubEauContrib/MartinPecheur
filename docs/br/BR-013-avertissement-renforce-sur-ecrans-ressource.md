# BR-013 — Avertissement renforcé sur tout écran de ressource ou de sécheresse

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Avertissement · Restrictions

## Règle

> Tout écran traitant de la **sécheresse** ou de la **disponibilité de la ressource**
> porte un avertissement **renforcé**, **non repliable**, **en tête d'écran**, énonçant
> explicitement que l'information ne remplace ni les arrêtés préfectoraux, ni une
> décision d'irrigation, ni une évaluation de sécurité.

## Justification

C'est le seul endroit du produit où une mauvaise lecture entraîne une conséquence **juridique** — un prélèvement en infraction — ou **physique** — une baignade ou un franchissement en conditions dangereuses.

Le persona agriculteur/irrigant est le seul dont une décision engage sa responsabilité légale. Le niveau de gravité affiché provient de VigiEau, mais **seul l'arrêté préfectoral fait foi**, et son texte peut comporter des dérogations et des périmètres que l'API ne restitue pas.

## Invariants & cas limites

- **Non repliable** : ni accordéon, ni « ne plus afficher », ni disparition au défilement.
- Placé **avant** le niveau de gravité, jamais après ni à côté.
- Comporte une action directe vers les arrêtés en vigueur.
- S'applique aux écrans Restrictions **et** à tout écran présentant la disponibilité de la ressource — y compris une future vue territoriale agrégée.
- Reste affiché en mode hors ligne, où il est **plus** nécessaire encore : la donnée est datée.
- Annoncé en priorité par le lecteur d'écran, comme région d'alerte, à l'ouverture de l'écran.
- Distinct de l'encart de fiche (`BR-001`, contexte Hydrometrie/Ecoulement), qui est plus court et centré sur la nature de la mesure.

## Vérifiable par

Test d'instantané sur chaque écran du contexte Restrictions vérifiant la présence de l'encart, sa position en tête et l'absence de contrôle de repli. Test d'accessibilité vérifiant le rôle de région d'alerte.

## Liens

- Use cases : `UC-002`
- ADR liés : `ADR-004`
- Écran : [`04-ui.md § 1`](../04-ui.md) et [`§ 5`](../04-ui.md)
- Voir aussi : `BR-012`, `BR-014`
