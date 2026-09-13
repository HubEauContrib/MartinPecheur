// Unités nommées par le type, pas par convention (BR-002). Les `extension
// type` s'effacent à l'exécution : aucun objet alloué, aucune validation —
// et ferment les deux sens : un `double` nu ne devient pas une unité, une
// unité ne redevient un `double` que par `.value`, explicitement —
// ces types nomment, ils ne refusent pas.

/// Débit brut renvoyé par l'API Hydrométrie, en litres par seconde (C-02).
extension type const LitresPerSecond(double value) {}

/// Hauteur brute renvoyée par l'API Hydrométrie, en millimètres (C-02).
extension type const Millimetres(double value) {}

/// Débit converti, seule unité affichable dans l'interface.
extension type const CubicMetresPerSecond(double value) {}

/// Hauteur convertie, seule unité affichable dans l'interface.
extension type const Metres(double value) {}
