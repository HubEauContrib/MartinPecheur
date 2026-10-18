// L'ordre de tabulation déclaré de l'écran carte (`K2`, `K1` de T3, spec
// d'Ergonomie § 5.7) : des constantes NOMMÉES, partagées par la composition
// de la carte (`map_view.dart`) et par les pièces qui posent elles-mêmes le
// rang de leurs groupes (le bas de la carte, `map_bottom.dart`). Déplacées
// telles quelles de `map_view.dart` par `D2` d'Ergonomie, pour que le bas ne
// dépende pas de l'écran entier.

/// L'ordre de tabulation déclaré (`K2`) : entrées du sélecteur de lecture
/// (le nom de la constante date des puces d'échelle) → action de l'avis,
/// s'il en porte une (`K1` de T3, [mapTraversalOrderNotices]) → boutons
/// d'entrée (`F10b` de T3, [mapTraversalOrderEntryButtons]) → contrôles de
/// zoom → carte → fiche, si une est ouverte → lien du bandeau
/// (`WarningLink`). Des constantes NOMMÉES, jamais des `1`/`2`/`3` recopiés
/// à chaque `FocusTraversalOrder` : un futur réordonnancement se lit ici,
/// à un seul endroit.
const double mapTraversalOrderChips = 1;

/// Les avis de la carte (`K1` de T3, arbitrage du commanditaire du
/// 2026-10-14) : leur action — « Élargir la recherche » ou « Effacer les
/// filtres » — est un arrêt de Tab juste APRÈS les entrées du sélecteur
/// ([mapTraversalOrderChips]) et AVANT les boutons d'entrée
/// ([mapTraversalOrderEntryButtons]), à toutes les largeurs : c'est sous le
/// sélecteur, dans le bloc de lecture, que l'avis s'affiche. Sans rang,
/// `OrderedTraversalPolicy` la placerait après « ⚠ Avertissement », en
/// dernier.
const double mapTraversalOrderNotices = 1.25;

/// Le groupe des boutons d'entrée ([MapEntryButtons], `F10b` de T3) : entre
/// les entrées du sélecteur ([mapTraversalOrderChips]) et les contrôles de
/// zoom ([mapTraversalOrderControls]). UNE valeur pour tout le groupe : à
/// l'intérieur, Tab suit l'ordre de la colonne.
const double mapTraversalOrderEntryButtons = 1.5;

/// Voir [mapTraversalOrderChips].
const double mapTraversalOrderControls = 2;

/// Voir [mapTraversalOrderChips]. « carte » est un GROUPE (arbitrage du
/// commanditaire du 2026-09-23, `K2`) : `FlutterMap` porte son PROPRE
/// `FocusTraversalGroup(policy: OrderedTraversalPolicy())`, placé à CET
/// ordre dans le groupe parent — voir [_MapViewState.build]. À l'intérieur
/// de ce sous-groupe, chaque marqueur reçoit un `NumericFocusOrder` ENTIER
/// (`0`, `1`, `2`, …), une échelle INDÉPENDANTE de celle du groupe parent :
/// aucun nombre d'éléments ne peut donc jamais atteindre
/// [mapTraversalOrderSheet] (relecture du commanditaire du 2026-09-23,
/// 🔴 1 — la première version partageait l'échelle du parent avec un pas de
/// 0,001, dépassée par une zone dense de plus de 500 marqueurs).
const double mapTraversalOrderCarte = 3;

/// Entre « carte » et « lien du bandeau » : une fiche ouverte s'intercale
/// dans l'ordre déclaré, plutôt que de sauter au dernier arrêt ou de rester
/// hors de l'ordre de tabulation.
const double mapTraversalOrderSheet = 3.5;

/// Voir [mapTraversalOrderChips] — le dernier arrêt.
const double mapTraversalOrderWarningLink = 4;

/// Le bouton « Restrictions au centre de la carte » : juste APRÈS les
/// contrôles de zoom et de recentrage ([mapTraversalOrderControls]), juste
/// AVANT la carte (`04-ui.md` § 3 : « atteint par Tab dans l'ordre des
/// contrôles »).
const double mapTraversalOrderDesignate = 2.5;
