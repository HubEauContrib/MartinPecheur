# BR-003 — Un débit n'est jamais qualifié de « suffisant »

- **Statut :** Accepté
- **Date :** 2026-07-30
- **Contexte borné :** Hydrometrie

## Règle

> L'application ne qualifie jamais un débit de **suffisant, insuffisant, normal, bon
> ou sûr**. Elle le situe uniquement par rapport à l'historique de sa propre station,
> et nomme cette comparaison pour ce qu'elle est : une **statistique**.

## Justification

Qualifier un débit de « suffisant » suppose un seuil de référence. Vérifié le 2026-07-30 : **aucune API publique n'expose de seuil par station** — ni Hub'Eau (4 ressources hydrométrie, aucun seuil), ni HydroPortail (aucune API REST, `/api-docs` → 404), ni SANDRE (`zar.json` → 404). VigiEau renvoie un niveau de gravité **administratif** par zone, jamais le débit-seuil.

Inventer un seuil sur ces bases exposerait l'usager à une décision d'irrigation, de navigation ou de franchissement fondée sur un chiffre sans fondement réglementaire.

Le mot **« normal »** est proscrit spécifiquement : il laisse entendre une adéquation écologique que la statistique ne mesure pas. Une référence calculée sur 30 ans glissants intègre la dégradation progressive de la ressource — **un débit « habituel » peut être écologiquement dégradé**.

## Invariants & cas limites

- Libellé imposé pour la classe médiane : **« Habituel pour la saison »**, jamais « Normal » ni « Dans la normale ».
- Toute présentation du niveau porte le sous-texte : *« Comparaison statistique. Ce n'est pas un seuil réglementaire. »*
- La règle s'applique à l'interface, aux notifications système, aux textes de partage et à la description sur les magasins d'applications.
- Elle ne s'applique **pas** aux niveaux de gravité VigiEau, qui sont des qualifications **réglementaires** émises par le préfet : celles-là sont reprises telles quelles.

## Vérifiable par

Test de contenu balayant les ressources de localisation : aucune occurrence de « suffisant », « insuffisant », « normal », « bon niveau », « sûr » dans un libellé rattaché à une valeur de débit. Le test échoue à l'ajout d'un tel libellé.

## Liens

- Use cases : `UC-003`
- ADR liés : `ADR-002`, `ADR-003`
- Voir aussi : `BR-004` (indéterminé), `BR-014` (aucun verbe d'instruction)
