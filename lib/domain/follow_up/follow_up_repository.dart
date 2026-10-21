// Le contrat du dépôt des suivis (M2 de T5). Dart pur : la réalisation
// (stockage local) vit sous `lib/data/`.

import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';

/// Ce qui est stocké : les suivis, dans l'ordre, et l'instant de la dernière
/// vérification enregistrée (`null` si aucune). Listes non modifiables.
final class FollowUpBook {
  FollowUpBook({required List<FollowUp> followUps, this.lastCheckAt})
    : followUps = List<FollowUp>.unmodifiable(followUps);

  final List<FollowUp> followUps;

  /// Instant de la dernière vérification enregistrée, en UTC.
  final DateTime? lastCheckAt;
}

/// Ce qu'une vérification reporte sur le stockage, en une seule écriture.
final class CheckRecord {
  CheckRecord({
    required this.checkedAt,
    required List<FollowUp> updated,
    required List<FollowUp> orphans,
  }) : updated = List<FollowUp>.unmodifiable(updated),
       orphans = List<FollowUp>.unmodifiable(orphans);

  /// Instant de la vérification, en UTC.
  final DateTime checkedAt;

  /// Les suivis dont le dernier état ou la série a changé.
  final List<FollowUp> updated;

  /// Les suivis dont plus aucun favori ne porte le lieu, TELS QU'ILS ONT ÉTÉ
  /// LUS au début de la vérification (et non leurs seuls lieux) : on ne retire
  /// que ce qui n'a pas changé depuis.
  final List<FollowUp> orphans;
}

/// Le dépôt des suivis. L'échec est LEVÉ ([FollowUpStorageFailure]), jamais
/// rendu.
abstract interface class FollowUpRepository {
  /// Rien de stocké : un livre vide. Une racine illisible lève
  /// [SuiviIllisible] ; une entrée illisible donne un [UnreadableFollowUp], à
  /// sa place.
  Future<FollowUpBook> read();

  /// Crée le suivi de [place], ou change son seuil en GARDANT son dernier état
  /// et sa série.
  Future<void> followFlood(FloodSectionPlace place, FloodThreshold threshold);

  /// Sans effet si [place] est déjà suivi.
  Future<void> followDrought(DroughtPlace place);

  /// Sans effet si [place] n'est pas suivi.
  Future<void> unfollow(FollowedPlace place);

  /// REPORTE sur l'état stocké AU MOMENT DE L'ÉCRITURE : pour chaque suivi de
  /// `updated` dont le lieu est ENCORE suivi, remplace le dernier état et la
  /// série et GARDE le seuil stocké (un réglage changé pendant la vérification
  /// est donc gardé). Un lieu de `updated` qui n'est plus suivi est ignoré.
  /// Retire chaque suivi de `orphans` SEULEMENT si l'entrée stockée lui est
  /// encore égale : un suivi recréé pendant la vérification, sans dernier
  /// état, n'est pas effacé. Pose `lastCheckAt`.
  Future<void> recordCheck(CheckRecord record);

  /// Remplace ce qui est stocké par un livre vide sans le DÉCODER : c'est
  /// « Repartir sans lieu suivi ». Seul échec possible :
  /// [EcritureDuSuiviEnEchec].
  Future<void> clear();
}

/// L'échec du dépôt des suivis : deux branches closes. Chaque écriture lit
/// d'abord le stockage : une racine illisible lève [SuiviIllisible] et
/// n'écrase rien.
sealed class FollowUpStorageFailure implements Exception {
  const FollowUpStorageFailure(this.diagnostic);

  /// Texte technique, pour le journal ; jamais affiché à l'usager.
  final String diagnostic;
}

/// La valeur stockée n'est pas un livre de suivis lisible.
final class SuiviIllisible extends FollowUpStorageFailure {
  const SuiviIllisible(super.diagnostic);
}

/// Le stockage a refusé l'écriture.
final class EcritureDuSuiviEnEchec extends FollowUpStorageFailure {
  const EcritureDuSuiviEnEchec(super.diagnostic);
}
