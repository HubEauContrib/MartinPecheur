// L'état d'affichage de l'interrupteur « Me prévenir des restrictions
// sécheresse » (`V2` de T5), partagé par les fiches station et ONDE : ce que
// `StationSheetViewModel` et `OndeSheetViewModel` produisent.
//
// Un état d'AFFICHAGE, pas du métier : il vit ici, à côté de [FavoriteStar],
// et non dans `lib/domain/`.
//
// ⚠️ Dart pur et AUCUNE directive d'import, volontairement : un ViewModel
// l'importe sans toucher à un widget (`view-model-sans-widget`). Le verrou est
// `test/features/shared/follow_up_toggle_test.dart`.

/// Texte de l'échec d'écriture du réglage « Me prévenir » (`Q2`).
const String followUpWriteFailedText = "Le réglage n'a pas pu être enregistré.";

/// L'interrupteur tel qu'il s'affiche : allumé ou non, actif ou non, et si la
/// dernière écriture a échoué.
final class FollowUpToggle {
  const FollowUpToggle({
    required this.on,
    required this.enabled,
    this.writeFailed = false,
  });

  /// Le lieu est suivi pour les restrictions : interrupteur allumé.
  final bool on;

  /// L'interrupteur répond au toucher et au clavier ; sinon il garde sa forme,
  /// atténuée (écriture en cours, suivi illisible).
  final bool enabled;

  /// La dernière écriture du réglage a échoué.
  final bool writeFailed;

  @override
  bool operator ==(Object other) =>
      other is FollowUpToggle &&
      other.on == on &&
      other.enabled == enabled &&
      other.writeFailed == writeFailed;

  @override
  int get hashCode => Object.hash(on, enabled, writeFailed);

  @override
  String toString() =>
      'FollowUpToggle(on: $on, enabled: $enabled, writeFailed: $writeFailed)';
}
