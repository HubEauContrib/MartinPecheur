// Le contrat du dépôt des favoris (S1 de T3). Dart pur : la réalisation
// (stockage local) vit sous `lib/data/`.

import 'package:martinpecheur/domain/favorites/favorite.dart';

/// Le dépôt des favoris. L'échec est LEVÉ, jamais rendu.
abstract interface class FavoriteRepository {
  /// Liste NON MODIFIABLE, dans l'ordre d'affichage, DERNIER AJOUTÉ EN TÊTE.
  /// Rien de stocké : liste vide. Valeur illisible : lève
  /// [ListeDeFavorisIllisible], jamais une liste vide.
  Future<List<Favorite>> readAll();

  /// Insère [favorite] EN TÊTE. Un favori de même lieu ([sameFavoritePlace])
  /// déjà présent : AUCUN changement, aucune erreur (la date d'origine
  /// reste). `add(UnreadableFavorite)` lève une [ArgumentError]. Valeur
  /// illisible : [ListeDeFavorisIllisible] ; écriture refusée :
  /// [EcritureDeFavorisEnEchec].
  Future<void> add(Favorite favorite);

  /// Retire TOUTE entrée de même lieu que [favorite] ; absente : aucun
  /// changement, aucune erreur. Mêmes échecs que [add].
  Future<void> remove(Favorite favorite);

  /// Remplace ce qui est stocké par une liste vide SANS le lire. Seul échec
  /// possible : [EcritureDeFavorisEnEchec].
  Future<void> clear();
}

/// L'échec du dépôt des favoris : deux branches closes.
sealed class FavoriteStorageFailure implements Exception {
  const FavoriteStorageFailure(this.diagnostic);

  /// Texte technique, pour le journal ; jamais affiché à l'usager.
  final String diagnostic;
}

/// La valeur stockée n'est pas une liste de favoris lisible.
final class ListeDeFavorisIllisible extends FavoriteStorageFailure {
  const ListeDeFavorisIllisible(super.diagnostic);
}

/// Le stockage a refusé l'écriture.
final class EcritureDeFavorisEnEchec extends FavoriteStorageFailure {
  const EcritureDeFavorisEnEchec(super.diagnostic);
}
