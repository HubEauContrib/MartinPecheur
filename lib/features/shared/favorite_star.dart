// L'état d'affichage de l'étoile de favori (`S4` de T3), partagé par les deux
// fiches : ce que `StationSheetViewModel` et `OndeSheetViewModel` produisent,
// ce que `FavoriteStarButton` consomme.
//
// Un état d'AFFICHAGE, pas du métier (arbitrage du commanditaire du
// 2026-10-12, décision 4) : il vit ici, à côté du widget, et non dans
// `lib/domain/` ni dans `docs/domain-model.md`.
//
// ⚠️ Dart pur et AUCUNE directive d'import, volontairement : un ViewModel
// l'importe sans toucher à un widget (`view-model-sans-widget`). Le verrou est
// `test/features/shared/favorite_star_test.dart`.

/// L'étoile telle qu'elle s'affiche : pleine ou vide, active ou non, et si la
/// dernière écriture a échoué.
final class FavoriteStar {
  const FavoriteStar({
    required this.filled,
    required this.enabled,
    this.writeFailed = false,
  });

  /// Le lieu est un favori : étoile pleine.
  final bool filled;

  /// L'étoile répond au tap et au clavier ; sinon elle garde sa forme, atténuée.
  final bool enabled;

  /// La dernière écriture (ajout ou retrait) a échoué.
  final bool writeFailed;

  @override
  bool operator ==(Object other) =>
      other is FavoriteStar &&
      other.filled == filled &&
      other.enabled == enabled &&
      other.writeFailed == writeFailed;

  @override
  int get hashCode => Object.hash(filled, enabled, writeFailed);

  @override
  String toString() =>
      'FavoriteStar(filled: $filled, enabled: $enabled, '
      'writeFailed: $writeFailed)';
}
