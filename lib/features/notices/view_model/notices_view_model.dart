// ViewModel de l'écran « Avis reçus » (V4 de T5 ; cadrage § 7.4 et § 7.5).
//
// C'est le SEUL appelant de `FollowUpCheck` (PD6) : le lancement, le retour au
// premier plan et « Vérifier maintenant » passent tous par [check], qui rend
// la vérification en cours s'il y en a une. « Vérification en cours… » dit
// donc vrai quelle que soit l'origine de la vérification.
//
// Il porte aussi l'annonce de la carte ([MapAnnouncement]) : l'écran fermé,
// une vérification qui écrit des avis, qui bute sur un stockage illisible ou
// qui n'a pas pu écrire ses avis la pose ; l'écran ouvert, aucune annonce
// n'est posée et l'état se relit. Le nombre annoncé est celui des avis NON
// LUS après la vérification (PD19), relu dans le dépôt, et non celui des
// seuls avis de cette vérification. Une écriture en échec se dit toujours
// (BR-016, Q2) : elle n'est jamais tue.
//
// ⚠️ Aucun widget, aucun fichier de `lib/data/`, aucune autre tranche.

import 'dart:math' show max;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_check.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';

/// État de l'écran « Avis reçus ». Cinq branches, closes.
sealed class NoticesState {
  const NoticesState();
}

/// L'écran n'est pas ouvert.
final class AvisFermes extends NoticesState {
  const AvisFermes();
}

/// L'écran est ouvert ; les avis et les réglages se lisent.
final class AvisEnLecture extends NoticesState {
  const AvisEnLecture();
}

/// Les avis et les réglages sont lus.
final class AvisPrets extends NoticesState {
  AvisPrets({
    required List<ReceivedNotice> notices,
    required this.followsAnyPlace,
    required this.favoritesUnreadable,
    required this.lastCheckAt,
  }) : notices = List<ReceivedNotice>.unmodifiable(notices);

  /// Les avis, le plus récent en tête. Non modifiable.
  final List<ReceivedNotice> notices;

  /// Un lieu en favori est suivi. Toujours faux quand [favoritesUnreadable].
  final bool followsAnyPlace;

  /// La liste des favoris n'a pas pu être lue (Q1) : l'écran le dit au lieu
  /// de « Aucun lieu n'est suivi » ; le geste de remplacement est celui de
  /// l'écran « Favoris ».
  final bool favoritesUnreadable;

  /// Instant de la dernière vérification enregistrée, en UTC ; `null` si
  /// aucune.
  final DateTime? lastCheckAt;
}

/// La liste des avis enregistrés n'a pas pu être lue : « Repartir d'une liste
/// vide » ([NoticesViewModel.startOverNotices]).
final class AvisIllisibles extends NoticesState {
  const AvisIllisibles();
}

/// Les réglages « Me prévenir » enregistrés n'ont pas pu être lus :
/// « Repartir sans lieu suivi » ([NoticesViewModel.startOverFollowUps]).
final class ReglagesDeSuiviIllisibles extends NoticesState {
  const ReglagesDeSuiviIllisibles();
}

/// L'annonce de la carte, posée par une vérification l'écran fermé. Trois
/// branches, closes.
sealed class MapAnnouncement {
  const MapAnnouncement();
}

/// [count] avis non lus sur les lieux suivis (PD19).
final class NewNoticesAnnouncement extends MapAnnouncement {
  const NewNoticesAnnouncement(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is NewNoticesAnnouncement && other.count == count;

  @override
  int get hashCode => Object.hash(NewNoticesAnnouncement, count);

  @override
  String toString() => 'NewNoticesAnnouncement($count)';
}

/// Aucune vérification n'a été faite : les avis, les réglages ou les favoris
/// enregistrés n'ont pas pu être lus (R16, Q1).
final class UnreadableStorageAnnouncement extends MapAnnouncement {
  const UnreadableStorageAnnouncement();

  @override
  bool operator ==(Object other) => other is UnreadableStorageAnnouncement;

  @override
  int get hashCode => (UnreadableStorageAnnouncement).hashCode;

  @override
  String toString() => 'UnreadableStorageAnnouncement()';
}

/// La dernière vérification n'a pas pu écrire ses avis (Q2).
final class NotRecordedAnnouncement extends MapAnnouncement {
  const NotRecordedAnnouncement();

  @override
  bool operator ==(Object other) => other is NotRecordedAnnouncement;

  @override
  int get hashCode => (NotRecordedAnnouncement).hashCode;

  @override
  String toString() => 'NotRecordedAnnouncement()';
}

/// Porte l'écran « Avis reçus », la vérification et l'annonce de la carte.
final class NoticesViewModel extends ChangeNotifier {
  NoticesViewModel({
    required this._notices,
    required this._followUps,
    required this._favorites,
    required this._check,
    required this._links,
  });

  final NoticeRepository _notices;
  final FollowUpRepository _followUps;
  final FavoriteRepository _favorites;
  final FollowUpCheck _check;
  final ExternalLinkOpener _links;

  NoticesState _state = const AvisFermes();
  MapAnnouncement? _announcement;
  Future<CheckOutcome>? _running;
  bool _lastCheckNotRecorded = false;
  int _unopenedLinkCount = 0;
  bool _disposed = false;

  /// Génération des lectures : incrémentée par chaque lecture et par
  /// [close]. Une lecture dépassée n'écrit rien.
  int _generation = 0;

  /// État courant de l'écran.
  NoticesState get state => _state;

  /// Une vérification court.
  bool get checking => _running != null;

  /// La dernière vérification n'a pas pu être enregistrée (Q2) : vrai après
  /// tout [CheckNotRecorded], faux après [CheckDone] ou [NothingFollowed].
  bool get lastCheckNotRecorded => _lastCheckNotRecorded;

  /// Nombre d'échecs d'ouverture du lien Vigicrues.
  int get unopenedLinkCount => _unopenedLinkCount;

  /// L'annonce de la carte, ou `null`.
  MapAnnouncement? get announcement => _announcement;

  bool get _screenOpen => switch (_state) {
    AvisFermes() => false,
    AvisEnLecture() ||
    AvisPrets() ||
    AvisIllisibles() ||
    ReglagesDeSuiviIllisibles() => true,
  };

  /// Le SEUL chemin vers [FollowUpCheck.run] (PD6). Pendant une vérification,
  /// rend la même.
  Future<CheckOutcome> check() {
    final Future<CheckOutcome>? running = _running;
    if (running != null) {
      return running;
    }
    final Future<CheckOutcome> started = _runCheck();
    _running = started;
    _notify();
    return started;
  }

  // `run()` ne lève pas, par contrat ; le `finally` garde `checking` juste
  // s'il levait quand même.
  Future<CheckOutcome> _runCheck() async {
    try {
      final CheckOutcome outcome = await _check.run();
      if (!_disposed) {
        await _apply(outcome);
      }
      return outcome;
    } finally {
      _running = null;
      _notify();
    }
  }

  Future<void> _apply(CheckOutcome outcome) async {
    switch (outcome) {
      case CheckNotRecorded():
        _lastCheckNotRecorded = true;
      case CheckDone() || NothingFollowed():
        _lastCheckNotRecorded = false;
      case CheckBlockedByUnreadableStorage():
        break;
    }
    if (_screenOpen) {
      await _read();
      return;
    }
    switch (outcome) {
      case CheckDone(newNotices: final int written) when written > 0:
        await _announceWritten(written);
      case CheckNotRecorded(noticesWritten: final int written) when written > 0:
        // Les avis sont écrits : ils ne sont jamais tus.
        await _announceWritten(written);
      case CheckNotRecorded():
        _announcement = const NotRecordedAnnouncement();
      case CheckBlockedByUnreadableStorage():
        _announcement = const UnreadableStorageAnnouncement();
      case CheckDone() || NothingFollowed():
        break;
    }
  }

  /// Annonce les avis non lus après la vérification (PD19), jamais moins que
  /// les [written] avis qu'elle a écrits : une fermeture de l'écran tombée
  /// entre leur écriture et la fin de la vérification les a marqués lus sans
  /// les montrer. Si l'écran s'est ouvert pendant la relecture, aucune
  /// annonce : l'état se relit.
  Future<void> _announceWritten(int written) async {
    final int unread = await _unreadAfter(written);
    if (_disposed) {
      return;
    }
    if (_screenOpen) {
      await _read();
      return;
    }
    _announcement = NewNoticesAnnouncement(max(unread, written));
  }

  /// Le nombre d'avis non lus après la vérification (PD19). Si la relecture
  /// échoue, le nombre des avis de la vérification : jamais un silence.
  Future<int> _unreadAfter(int written) async {
    try {
      final List<ReceivedNotice> notices = await _notices.readAll();
      return notices
          .whereType<ReadableNotice>()
          .where((ReadableNotice notice) => !notice.read)
          .length;
    } on Object {
      return written;
    }
  }

  /// À l'ouverture de l'écran : retire l'annonce, puis lit les avis, le suivi
  /// et les favoris.
  Future<void> load() async {
    _announcement = null;
    _state = const AvisEnLecture();
    _notify();
    await _read();
  }

  /// Lit les avis, puis le suivi, puis les favoris. Des avis illisibles
  /// passent avant un suivi illisible ; des favoris illisibles ne cachent pas
  /// les avis.
  Future<void> _read() async {
    final int generation = ++_generation;
    final NoticesState next = await _readState();
    if (_disposed || generation != _generation) {
      return;
    }
    _state = next;
    _notify();
  }

  Future<NoticesState> _readState() async {
    final List<ReceivedNotice> notices;
    try {
      notices = await _notices.readAll();
    } on Object {
      return const AvisIllisibles();
    }
    final FollowUpBook book;
    try {
      book = await _followUps.read();
    } on Object {
      return const ReglagesDeSuiviIllisibles();
    }
    List<Favorite>? favorites;
    try {
      favorites = await _favorites.readAll();
    } on Object {
      favorites = null;
    }
    return AvisPrets(
      notices: notices,
      followsAnyPlace:
          favorites != null && followsAnyPlace(favorites, book.followUps),
      favoritesUnreadable: favorites == null,
      lastCheckAt: book.lastCheckAt,
    );
  }

  /// À la fermeture de l'écran : marque tout comme lu (R8), puis
  /// [AvisFermes]. Un échec est ignoré : les avis restent « Nouveau ».
  Future<void> close() async {
    try {
      await _notices.markAllRead();
    } on Object {
      // Ignoré : les avis restent « Nouveau » à la prochaine ouverture.
    }
    if (_disposed) {
      return;
    }
    _generation++;
    _announcement = null;
    _state = const AvisFermes();
    _notify();
  }

  /// « Repartir d'une liste vide » : efface les avis, puis relit.
  Future<void> startOverNotices() async {
    try {
      await _notices.clear();
    } on Object {
      // La relecture dit ce qui reste stocké.
    }
    await _read();
  }

  /// « Repartir sans lieu suivi » : efface les réglages « Me prévenir », puis
  /// relit. Les favoris restent.
  Future<void> startOverFollowUps() async {
    try {
      await _followUps.clear();
    } on Object {
      // La relecture dit ce qui reste stocké.
    }
    await _read();
  }

  /// Ouvre le site public de Vigicrues hors de l'application. Un échec se
  /// compte.
  Future<void> openVigicrues() async {
    final bool opened = await _links.open(Uri.parse(floodPublicSiteUrl));
    if (opened || _disposed) {
      return;
    }
    _unopenedLinkCount++;
    _notify();
  }

  /// Ferme l'annonce de la carte.
  void dismissAnnouncement() {
    if (_announcement == null) {
      return;
    }
    _announcement = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
