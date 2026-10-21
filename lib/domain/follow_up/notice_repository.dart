// Le contrat du dépôt des avis reçus (M3 de T5). Dart pur : la réalisation
// (stockage local) vit sous `lib/data/`.

import 'package:martinpecheur/domain/follow_up/received_notice.dart';

/// Le nombre d'avis gardés au plus, illisibles compris (BR-016).
const int maxStoredNotices = 100;

/// Le dépôt des avis reçus. L'échec est LEVÉ ([NoticeStorageFailure]),
/// jamais rendu.
abstract interface class NoticeRepository {
  /// Les avis, le plus récent en tête. Rien de stocké : une liste vide. Une
  /// racine illisible lève [ListeDAvisIllisible] ; une entrée illisible donne
  /// un [UnreadableNotice], à sa place.
  Future<List<ReceivedNotice>> readAll();

  /// Insère [notices] en tête, DANS L'ORDRE DONNÉ, puis garde les
  /// [maxStoredNotices] premières entrées, illisibles comprises. Une liste
  /// vide n'écrit rien.
  Future<void> addAll(List<ReadableNotice> notices);

  /// Marque chaque avis lisible comme lu ; un illisible reste tel quel.
  Future<void> markAllRead();

  /// Remplace ce qui est stocké par une liste vide, sans le DÉCODER. Seul
  /// échec possible : [EcritureDAvisEnEchec].
  Future<void> clear();
}

/// L'échec du dépôt des avis : deux branches closes. Chaque écriture, sauf
/// [NoticeRepository.clear], lit d'abord le stockage : une racine illisible
/// lève [ListeDAvisIllisible] et n'écrase rien.
sealed class NoticeStorageFailure implements Exception {
  const NoticeStorageFailure(this.diagnostic);

  /// Texte technique, pour le journal ; jamais affiché à l'usager.
  final String diagnostic;
}

/// La valeur stockée n'est pas une liste d'avis lisible.
final class ListeDAvisIllisible extends NoticeStorageFailure {
  const ListeDAvisIllisible(super.diagnostic);
}

/// Le stockage a refusé l'écriture.
final class EcritureDAvisEnEchec extends NoticeStorageFailure {
  const EcritureDAvisEnEchec(super.diagnostic);
}
