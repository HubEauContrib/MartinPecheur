# BR-014 — Aucun verbe d'instruction sur un usage de l'eau

- **Statut :** Accepté · **amendé le 2026-10-14 (T4, vigilance crues)**
- **Date :** 2026-07-30
- **Contexte borné :** Avertissement · Restrictions · Hydrometrie · Crues

## Règle

> L'application **décrit**, elle ne prescrit pas. Elle n'emploie aucun verbe
> d'instruction, d'autorisation ni d'interdiction portant sur un usage de l'eau.
> Elle oriente vers la source qui fait foi.

## Justification

Autoriser ou interdire un usage de l'eau relève du préfet. Une application qui écrit « vous pouvez arroser » se substitue à une autorité, sur une donnée qu'elle sait partielle et non validée.

Le risque est symétrique et les deux versants comptent : « baignade possible » engage la sécurité d'une personne ; « traversée déconseillée » sur une donnée de 9 jours produit une alerte infondée qui, répétée, décrédibilise les vraies.

## Invariants & cas limites

| Interdit | Retenu |
|---|---|
| « Vous pouvez arroser » | « Consultez l'arrêté de votre commune » |
| « Baignade possible » | « Cette application ne renseigne pas sur la baignade » |
| « Traversée déconseillée » | « Débit très bas pour la saison » |
| « Niveau sûr » | « Habituel pour la saison » |
| « Données fiables », « vérifié », « officiel », « en direct » | « Dernière mesure connue », « selon les données disponibles » |

- **Aucun mot de garantie** : ni temps réel, ni exactitude, ni exhaustivité, ni sécurité, ni conformité réglementaire.
- Les libellés de restriction **repris de VigiEau** sont cités tels quels (« Interdiction de 10h à 18h ») : ce sont les mots du préfet, présentés comme tels et attribués. Ce n'est pas l'application qui prescrit.
- S'applique à l'interface, aux textes de partage et à la description sur les magasins d'applications.
- Vouvoiement systématique : le public inclut des élus, des exploitants et des administrations.
- Les légendes et explications des niveaux de vigilance **reprises de Vigicrues** sont citées telles quelles et attribuées à Vigicrues — entre guillemets et suivies de « — Vigicrues » dans la fiche d'un tronçon ; dans la légende de la carte, la ligne « © VIGICRUES » qui la clôt les attribue. Elles ont été relevées le 2026-10-14 (`docs/sources/vigicrues.md`, `VC-13`). Ce n'est pas l'application qui qualifie le risque.

## Vérifiable par

Test de contenu sur les ressources de localisation : aucune occurrence des tournures interdites hors des champs provenant de VigiEau, lesquels sont identifiés comme cités. Revue éditoriale à chaque ajout de libellé.

## Liens

- Use cases : `UC-002`, `UC-003`, `UC-009`
- ADR liés : `ADR-002`, `ADR-004`, `ADR-007`, `ADR-016`
- Voir aussi : `BR-003`, `BR-007`, `BR-013`
