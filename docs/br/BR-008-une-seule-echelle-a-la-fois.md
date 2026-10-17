# BR-008 — Une seule échelle d'état est active à la fois

- **Statut :** Accepté · **amendé le 2026-10-12 (T3)** · **amendé le 2026-10-14 (T4, vigilance crues)** · **amendé le 2026-10-17 (tranche d'ergonomie)**
- **Date :** 2026-07-30
- **Contexte borné :** Carte

## Règle

> Les **quatre** échelles d'état — **écoulement**, **niveau de débit**, **sévérité sécheresse**, **vigilance crues** —
> ne sont jamais superposées sur un même marqueur ni affichées simultanément sur la carte.
> Une seule est active, choisie par **les puces d'échelle**, et la **légende l'indique en permanence**.

> ⚠️ **Amendement du 2026-10-17 — tranche d'ergonomie.** Le choix se fait dans le **sélecteur de lecture** de la carte (tranche d'ergonomie, arbitrage 1 du 2026-10-17), qui remplace les puces d'échelle ; la légende est dans le bloc de lecture, sous l'en-tête « `Légende · <lecture>` ». L'entrée « Restrictions » du sélecteur est un **mode de désignation**, pas l'échelle « sévérité sécheresse » : elle s'allume en plus de la lecture affichée et ne dessine aucune échelle sur la carte (arbitrage du 2026-10-03, inchangé). L'écart accepté le 2026-10-12 (la légende défile quand la place manque) vaut aussi pendant qu'une fiche est ouverte : la légende est le premier repli (arbitrage 11 du 2026-10-17).

## Justification

Les quatre échelles ont des **natures différentes** et ne se comparent pas :

| Échelle | Nature | Ce qu'elle dit |
|---|---|---|
| Écoulement ONDE | **Fait observé** | Ce qu'un agent a vu, un jour donné |
| Niveau de débit | **Statistique** | Comment la valeur se situe face à 30 ans d'historique |
| Sévérité sécheresse | **Décision administrative** | Ce que le préfet a arrêté |
| Vigilance crues | **Vigilance publiée par l'État** | Le niveau que Vigicrues a émis pour un tronçon de cours d'eau, à une date |

Superposer un fait observé, un calcul et une décision préfectorale sur une même carte, avec une échelle chromatique continue, laisserait croire à un indicateur unique de gravité. C'est précisément la confusion que `ADR-002` cherche à éviter.

C'est aussi ce qui **autorise la réutilisation de teintes** d'une échelle à l'autre : le contexte lève l'ambiguïté, et chaque échelle a sa propre famille de formes (formes pleines · chevrons · badges · **traits et étiquettes à jauge**).

## Invariants & cas limites

- La légende est **toujours visible**, jamais repliée : elle porte le nom de l'échelle active et ses états.
  > ⚠️ **Écart accepté — arbitrage du commanditaire du 2026-10-03.** Sous 600 px de large, la légende est repoussée sous un avis tant qu'il s'affiche ; la règle ci-dessus n'est pas modifiée. Voir [`04-ui.md` § 1](../04-ui.md) (amendement du 2026-10-03).
  >
  > **Complété le 2026-10-12 — arbitrage du commanditaire, « La légende défile » (`F10b` de T3).**
  > - **Ce qui disparaît.** L'écart du 2026-10-03 avait une conséquence mesurée : la légende repoussée passait **sous les contrôles de zoom** à 360 × 640 (sous les contrôles et l'attribution à 200 %). Ce recouvrement n'existe plus : dans les deux dispositions, la fenêtre de la colonne qui porte la légende s'arrête au-dessus de la colonne du bas à droite (~~« Filtres », contrôles de zoom, attribution~~ « Favoris », « Filtres », contrôles de zoom, attribution — « Favoris » y est depuis `S10` de T3, ajouté ici le 2026-10-14, revue finale de T3), et **rien de ce qu'on voit de la légende n'est masqué par un bouton**.
  > - **Ce qui demeure.** Sous 600 px, un avis affiché repousse toujours la légende ; elle peut alors n'être lue **qu'en faisant défiler** la colonne. Et dès que la fenêtre est trop courte pour elle, la légende n'est plus entière au repos, avis ou non : elle défile — sous 600 px comme à partir de 600 px (mesuré à 800 × 740, à 200 %, sur l'échelle « débit »).
  > - **Écart de plus, non arbitré par le commanditaire — décision de la boucle principale du 2026-10-12, réversible.** Sur une fenêtre compacte courte, la colonne du bas à droite passe avant celle du haut, qui ne garde que le contrôle « ⚠ Avertissement » : **mesuré à 360 × 300 le 2026-10-13 (Roboto), la légende est entièrement sous le bord de sa fenêtre au repos**, avec les puces d'échelle et l'avis. À dire au commanditaire et à constater en écran divisé à la porte Android de T3.
  > - **Effet de l'arbitrage sur les avis, non arbitré (`BR-007`).** « Rien n'est masqué » vaut pour la légende. À 200 %, aux largeurs de téléphone (360 × 640, 390 × 844), un avis affiché n'est plus entier au repos et son action s'amène en faisant défiler la colonne ; l'avis de carte vidée par le filtre vit dans cette colonne, ce qui touche le constat (d) du cadrage de T3, § 9 — ~~par déduction, non par mesure : à 200 %, les tests ne mesurent que l'avis d'absence, pas l'avis du filtre~~ **mesuré par `K3` le 2026-10-14, « Favoris » posé : à 360 × 640 et 200 %, l'avis de carte vidée par le filtre a 193 px à défiler au repos, sur les deux échelles, et « Effacer les filtres » ne s'atteint qu'en faisant défiler la colonne** (`test/features/map/view/map_overlays_phone_test.dart`, [`04-ui.md` § 1](../04-ui.md)) ; **arbitrage du commanditaire du 2026-10-14 : accepté en constat**, à voir à l'écran à la porte Android (barré et complété le 2026-10-14, revue finale de T3). À dire au commanditaire avec l'effet à 360 × 300.
  >
  > Mesures, seuils et tests : [`04-ui.md` § 1](../04-ui.md) (amendement du 2026-10-12). Vérifié par test, **pas constaté à l'écran**.
- Le changement d'échelle est explicite, via **les puces d'échelle**. Il n'y a pas d'échelle « automatique » selon le zoom.
- Un filtre (T3) masque des lieux à l'intérieur de l'échelle active ; il ne choisit pas l'échelle et n'en superpose aucune.
- Un marqueur peut exister dans plusieurs échelles (une station hydrométrique dans une zone de restriction) : il n'affiche que l'état de l'échelle active.
- La fiche de détail, elle, présente **toutes** les informations disponibles — la règle porte sur la carte, pas sur le détail.
- En lecture d'écran, l'annonce du marqueur nomme l'échelle : *« écoulement : à sec »*, jamais *« à sec »* seul.

## Vérifiable par

Test d'interface : après sélection d'une échelle, aucun marqueur ne porte de symbole appartenant à une autre famille de formes. Test vérifiant que la légende affichée correspond à l'échelle sélectionnée.

## Liens

- Use cases : `UC-001`, `UC-009`
- ADR liés : `ADR-002`, `ADR-006`, `ADR-016`
- Écran : [`04-ui.md § 2`](../04-ui.md)
- Voir aussi : `BR-009`
