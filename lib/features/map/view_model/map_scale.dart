// L'échelle active de la carte, et son libellé de légende. Un fichier à part
// du ViewModel : la légende (U3) et les contrôles d'échelle (U2) lisent ce
// libellé sans dépendre de [MapViewModel] — et un test de vocabulaire
// (BR-003) le balaie sans construire de ViewModel ni de dépôt.
//
// ⚠️ BR-008 : les échelles du produit — écoulement (fait observé), débit
// (statistique), sécheresse (décision préfectorale), vigilance crues
// (vigilance publiée par l'État, quatrième échelle depuis T4) — ne sont
// JAMAIS affichées ensemble. Une seule est active, et la légende l'indique.
// Cet `enum` porte l'échelle active de la carte ; c'est le type même qui
// rend impossible d'en afficher deux.
//
// Trois valeurs depuis le 2026-10-15 (`L1` de T4) : écoulement, débit,
// vigilance crues. La sécheresse n'en est pas une : depuis T2, elle se lit
// sur l'écran des restrictions, ouvert par la puce-interrupteur
// « Restrictions », qui n'est pas une échelle. Son vocabulaire n'est nommé
// nulle part ici, pas même en commentaire : `ADR-004` le confine à un seul
// module de `lib/data/`, et un test de confinement balaie tout le reste du
// dépôt. Une valeur ajoutée ici sans branche dans les `switch` qui la lisent
// ([mapScaleLabel] le premier) est une erreur de compilation (BR-011),
// jamais un libellé manquant à l'écran.

/// Échelle de lecture active sur la carte. Une seule à la fois (BR-008).
enum MapScaleKind {
  /// Écoulement observé ONDE — un fait constaté sur le terrain. Le libellé
  /// exact vient du filtre de `04-ui.md` l.13 (`[Écoulement*]`), pas de son
  /// § 203 (« Échelle 1 — Écoulement ONDE », un titre de section, pas le
  /// libellé). Active par défaut (`UC-001 § 3`).
  ecoulement,

  /// Débit rapporté à l'historique de la station — une statistique, jamais
  /// un jugement sur le débit lui-même (`04-ui.md` l.213, ADR-002).
  debit,

  /// Vigilance publiée par l'État — `BR-008`, quatrième échelle ; aucune
  /// pastille, aucun marqueur : un calque de traits, `FloodLayerViewModel`.
  crues,
}

/// Libellé de légende de [kind], en français, tel que `04-ui.md` le fixe —
/// jamais une reformulation locale ; « Vigilance crues » : cadrage de T4,
/// § 7.2 et § 12.2 (texte de la puce et titre de la légende).
///
/// `switch` exhaustif sur un `enum` fermé (BR-011) : une échelle ajoutée
/// sans branche ici ne compile pas.
///
/// Aucun des mots bannis (*suffisant, insuffisant, normal, bon, sûr*)
/// n'apparaît dans aucune branche (BR-003) : « relatif à l'historique » dit
/// la nature statistique de l'échelle sans qualifier le débit.
String mapScaleLabel(MapScaleKind kind) => switch (kind) {
  MapScaleKind.ecoulement => 'Écoulement',
  MapScaleKind.debit => "Débit relatif à l'historique",
  MapScaleKind.crues => 'Vigilance crues',
};

/// Décide si l'échelle [scale] justifie de précharger le débit des stations
/// visibles. Fonction pure, testable sans widget ni ViewModel — **déplacée**
/// de `map_view.dart` vers ce fichier (`H2`, 2026-09-22) : elle ferme
/// l'énumération qu'elle lit, et c'est `MapViewModel` qui la consulte
/// désormais ([MapViewModel.start], [MapViewModel.onGestureEnded],
/// [MapViewModel.selectScale]), plus la vue.
///
/// **Seule l'échelle « débit » précharge** (relecture du 2026-09-14). Sur
/// l'échelle « écoulement », qui est celle du démarrage (`UC-001 § 3`),
/// `buildMapLayers` ne dessine **aucun** marqueur de station : précharger y
/// enverrait jusqu'à vingt requêtes Hub'Eau par relâchement de geste pour
/// des marqueurs que personne ne voit. L'API n'a ni SLA ni quota chiffré
/// (`C-15`), et `NFR-07` interdit précisément le travail réseau sans
/// destinataire à l'écran.
///
/// Sur l'échelle « crues », aucune station n'est dessinée non plus (`L1` de
/// T4) : rien à précharger.
///
/// `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
/// sans branche ici ne compile pas — jamais un préchargement décidé par
/// défaut.
bool shouldPreloadOn(MapScaleKind scale) => switch (scale) {
  MapScaleKind.ecoulement => false,
  MapScaleKind.debit => true,
  MapScaleKind.crues => false,
};
