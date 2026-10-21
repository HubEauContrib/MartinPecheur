// La vérification des lieux suivis (M4 de T5, BR-016, arbitrage 7) : le cas
// d'usage du domaine qui relit les lieux suivis, compare des niveaux PUBLIÉS,
// produit les avis et dit l'impossible. Elle ne calcule aucun niveau (BR-015) :
// aucun avis ne naît d'un débit, d'une hauteur ou d'un écoulement.
//
// Son seul appelant est le ViewModel des avis (PD6). Elle ne dépend que de
// ports du domaine et d'une horloge injectée.
//
// Ordre des écritures (PD13) : les avis D'ABORD, puis les derniers états par
// `recordCheck`, qui reporte sur l'état stocké au moment de l'écriture. Un
// échec des avis n'enregistre rien : la vérification suivante redonnera les
// mêmes avis. Un échec du report peut redonner une fois les mêmes avis.
//
// Dart pur.

import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_rules.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Ce que rend une vérification. Quatre branches, closes.
sealed class CheckOutcome {
  const CheckOutcome();
}

/// La vérification est faite et enregistrée : [newNotices] avis nouveaux.
final class CheckDone extends CheckOutcome {
  const CheckDone(this.newNotices);

  final int newNotices;

  @override
  bool operator ==(Object other) =>
      other is CheckDone && other.newNotices == newNotices;

  @override
  int get hashCode => Object.hash(CheckDone, newNotices);

  @override
  String toString() => 'CheckDone($newNotices)';
}

/// Aucun lieu n'est suivi : aucune source n'a été appelée.
final class NothingFollowed extends CheckOutcome {
  const NothingFollowed();

  @override
  bool operator ==(Object other) => other is NothingFollowed;

  @override
  int get hashCode => (NothingFollowed).hashCode;

  @override
  String toString() => 'NothingFollowed()';
}

/// Le suivi, les avis ou les favoris n'ont pas pu être lus : aucune source
/// n'a été appelée, rien n'a été écrit (R16, Q1).
final class CheckBlockedByUnreadableStorage extends CheckOutcome {
  const CheckBlockedByUnreadableStorage();

  @override
  bool operator ==(Object other) => other is CheckBlockedByUnreadableStorage;

  @override
  int get hashCode => (CheckBlockedByUnreadableStorage).hashCode;

  @override
  String toString() => 'CheckBlockedByUnreadableStorage()';
}

/// La vérification n'a pas pu être enregistrée. [noticesWritten] vaut 0 si
/// c'est l'écriture des avis qui a échoué ; sinon, les avis sont écrits et
/// c'est le report des derniers états qui a échoué.
final class CheckNotRecorded extends CheckOutcome {
  const CheckNotRecorded(this.noticesWritten);

  final int noticesWritten;

  @override
  bool operator ==(Object other) =>
      other is CheckNotRecorded && other.noticesWritten == noticesWritten;

  @override
  int get hashCode => Object.hash(CheckNotRecorded, noticesWritten);

  @override
  String toString() => 'CheckNotRecorded($noticesWritten)';
}

/// La vérification des lieux suivis. Une seule à la fois : un [run] pendant
/// qu'une vérification court rend son `Future`.
final class FollowUpCheck {
  FollowUpCheck({
    required this._favorites,
    required this._followUps,
    required this._notices,
    required this._floods,
    required this._restrictions,
    required this._stations,
    DateTime Function()? now,
  }) : _clock = now ?? DateTime.now;

  final FavoriteRepository _favorites;
  final FollowUpRepository _followUps;
  final NoticeRepository _notices;
  final FloodVigilanceSource _floods;
  final RestrictionSource _restrictions;
  final StationRepository _stations;
  final DateTime Function() _clock;

  Future<CheckOutcome>? _running;

  /// Relit les lieux suivis et rend ce qui a été fait. Ne lève jamais.
  Future<CheckOutcome> run() => _running ??= _guarded();

  // `_check` attend toujours avant de rendre : le `finally` s'exécute donc
  // après que `run` a posé `_running`, jamais avant.
  Future<CheckOutcome> _guarded() async {
    try {
      return await _check();
    } finally {
      _running = null;
    }
  }

  Future<CheckOutcome> _check() async {
    final _Stored? stored = await _readStorage();
    if (stored == null) {
      return const CheckBlockedByUnreadableStorage();
    }
    final DateTime now = _clock().toUtc();

    final _Targets targets = _pair(stored.favorites, stored.book.followUps);
    if (targets.isEmpty) {
      if (targets.orphans.isNotEmpty) {
        try {
          await _followUps.recordCheck(
            CheckRecord(
              checkedAt: now,
              updated: <FollowUp>[],
              orphans: targets.orphans,
            ),
          );
        } on Object {
          // Ignoré : rien n'est suivi, l'orphelin sera retiré la prochaine
          // fois.
        }
      }
      return const NothingFollowed();
    }

    final List<FollowUp> updated = <FollowUp>[];
    final List<ReadableNotice> notices = <ReadableNotice>[
      ...await _checkFloods(targets.floods, now, updated),
      ...await _checkDrought(targets.drought, now, updated),
    ];

    if (notices.isNotEmpty) {
      try {
        await _notices.addAll(notices);
      } on Object {
        return const CheckNotRecorded(0);
      }
    }
    try {
      await _followUps.recordCheck(
        CheckRecord(checkedAt: now, updated: updated, orphans: targets.orphans),
      );
    } on Object {
      return CheckNotRecorded(notices.length);
    }
    return CheckDone(notices.length);
  }

  /// Le suivi, les avis et les favoris ; `null` si l'une des lectures lève.
  Future<_Stored?> _readStorage() async {
    try {
      final FollowUpBook book = await _followUps.read();
      await _notices.readAll();
      final List<Favorite> favorites = await _favorites.readAll();
      return (book: book, favorites: favorites);
    } on Object {
      return null;
    }
  }

  /// Apparie chaque suivi lisible à son favori, dans l'ordre des favoris. Un
  /// suivi lisible sans favori est un orphelin, tel qu'il a été lu ; un suivi
  /// illisible est ignoré.
  _Targets _pair(List<Favorite> favorites, List<FollowUp> followUps) {
    final List<_FloodTarget> floods = <_FloodTarget>[];
    final List<_DroughtTarget> drought = <_DroughtTarget>[];
    final Set<FollowedPlace> favoritePlaces = <FollowedPlace>{};
    for (final Favorite favorite in favorites) {
      final FollowedPlace? place = followedPlaceOf(favorite);
      if (place == null) {
        continue;
      }
      favoritePlaces.add(place);
      final FollowUp? followUp = followUpOf(followUps, place);
      switch (favorite) {
        case FloodSectionFavorite(:final FloodSectionCode code, :final name):
          if (followUp is FloodFollowUp) {
            floods.add(_FloodTarget(name, code, followUp));
          }
        case StationFavorite(:final StationCode code, :final label):
          if (followUp is DroughtFollowUp) {
            drought.add(
              _DroughtTarget(label, followUp, () => _stationAt(code)),
            );
          }
        case OndePointFavorite(:final OndePoint point):
          if (followUp is DroughtFollowUp) {
            drought.add(
              _DroughtTarget(
                point.label,
                followUp,
                () async => GeoPoint(
                  latitude: point.latitude,
                  longitude: point.longitude,
                ),
              ),
            );
          }
        case UnreadableFavorite():
          break;
      }
    }
    final List<FollowUp> orphans = <FollowUp>[
      for (final FollowUp followUp in followUps)
        if (placeOfFollowUp(followUp) case final FollowedPlace place
            when !favoritePlaces.contains(place))
          followUp,
    ];
    return _Targets(floods, drought, orphans);
  }

  /// Le point d'une station du référentiel, ou `null` si elle en est absente.
  Future<GeoPoint?> _stationAt(StationCode code) async {
    final Station? station = await _stations.findByCode(code);
    if (station == null) {
      return null;
    }
    return GeoPoint(latitude: station.latitude, longitude: station.longitude);
  }

  /// Le bloc crues : la vigilance n'est lue que si un tronçon est suivi.
  Future<List<ReadableNotice>> _checkFloods(
    List<_FloodTarget> targets,
    DateTime now,
    List<FollowUp> updated,
  ) async {
    if (targets.isEmpty) {
      return const <ReadableNotice>[];
    }
    final FloodVigilanceMap map;
    try {
      map = await _floods.current();
    } on FloodVigilanceFailure catch (failure) {
      return _floodsImpossible(targets, _floodCause(failure), now, updated);
    } on Object {
      return _floodsImpossible(
        targets,
        CheckFailureCause.unreadable,
        now,
        updated,
      );
    }

    final List<ReadableNotice> notices = <ReadableNotice>[];
    for (final _FloodTarget target in targets) {
      final FloodFollowUp before = target.followUp;
      final FloodSection? section = map.sectionByCode(target.code);
      if (section == null) {
        if (before.series != FailureSeries.notVerifiable) {
          notices.add(
            PlaceNotVerifiable(
              placeLabel: target.label,
              reason: map.skippedEntities > 0
                  ? SectionMaybeUnreadable(map.informationDate)
                  : SectionAbsent(map.informationDate),
              receivedAt: now,
            ),
          );
        }
        _addIfChanged(
          updated,
          before,
          _withFlood(before, before.lastKnown, FailureSeries.notVerifiable),
        );
        continue;
      }

      final LastKnownFloodLevel? last = before.lastKnown;
      if (last == null) {
        notices.add(
          FloodFollowUpStarted(
            placeLabel: target.label,
            level: section.level,
            informationDate: map.informationDate,
            threshold: before.threshold,
            receivedAt: now,
          ),
        );
      } else if (floodNoticeDue(
        before: last.level,
        after: section.level,
        threshold: before.threshold,
      )) {
        notices.add(
          FloodLevelChanged(
            placeLabel: target.label,
            before: last.level,
            after: section.level,
            informationDate: map.informationDate,
            receivedAt: now,
          ),
        );
      }
      _addIfChanged(
        updated,
        before,
        _withFlood(
          before,
          LastKnownFloodLevel(
            level: section.level,
            informationDate: map.informationDate,
          ),
          null,
        ),
      );
    }
    return notices;
  }

  /// La vigilance n'a pas pu être lue : chaque tronçon entre en série, ses
  /// derniers états ne changent pas ; un avis nomme ceux dont la série
  /// s'ouvre.
  List<ReadableNotice> _floodsImpossible(
    List<_FloodTarget> targets,
    CheckFailureCause cause,
    DateTime now,
    List<FollowUp> updated,
  ) {
    final List<String> opening = <String>[];
    for (final _FloodTarget target in targets) {
      final FloodFollowUp before = target.followUp;
      if (before.series != FailureSeries.checkImpossible) {
        opening.add(target.label);
      }
      _addIfChanged(
        updated,
        before,
        _withFlood(before, before.lastKnown, FailureSeries.checkImpossible),
      );
    }
    return <ReadableNotice>[
      if (opening.isNotEmpty)
        CheckImpossible(
          source: FollowUpSource.floods,
          cause: cause,
          placeLabels: opening,
          receivedAt: now,
        ),
    ];
  }

  /// Le bloc sécheresse : les lieux passent l'un après l'autre ; l'échec d'un
  /// lieu n'empêche pas les autres de se lire.
  Future<List<ReadableNotice>> _checkDrought(
    List<_DroughtTarget> targets,
    DateTime now,
    List<FollowUp> updated,
  ) async {
    final Map<CheckFailureCause, List<String>> opening =
        <CheckFailureCause, List<String>>{
          for (final CheckFailureCause cause in CheckFailureCause.values)
            cause: <String>[],
        };
    final List<ReadableNotice> placeNotices = <ReadableNotice>[];

    for (final _DroughtTarget target in targets) {
      final DroughtFollowUp before = target.followUp;
      ZonesAtPoint? zones;
      bool stationAbsent = false;
      CheckFailureCause? cause;
      // Le point se construit DANS le `try` : un point hors plage lève, et
      // la vérification ne lève jamais.
      try {
        final GeoPoint? point = await target.locate();
        if (point == null) {
          stationAbsent = true;
        } else {
          zones = await _restrictions.zonesAt(point);
        }
      } on RestrictionLookupFailure catch (failure) {
        cause = _droughtCause(failure);
      } on Object {
        cause = CheckFailureCause.unreadable;
      }

      if (cause != null) {
        if (before.series != FailureSeries.checkImpossible) {
          opening[cause]!.add(target.label);
        }
        _addIfChanged(
          updated,
          before,
          _withDrought(before, before.lastKnown, FailureSeries.checkImpossible),
        );
      } else if (stationAbsent) {
        if (before.series != FailureSeries.notVerifiable) {
          placeNotices.add(
            PlaceNotVerifiable(
              placeLabel: target.label,
              reason: const StationAbsent(),
              receivedAt: now,
            ),
          );
        }
        _addIfChanged(
          updated,
          before,
          _withDrought(before, before.lastKnown, FailureSeries.notVerifiable),
        );
      } else if (zones != null) {
        final LastKnownZones read = lastKnownZonesOf(zones);
        final LastKnownZones? last = before.lastKnown;
        if (last == null) {
          placeNotices.add(
            DroughtFollowUpStarted(
              placeLabel: target.label,
              zones: read.zones,
              readAt: read.readAt,
              receivedAt: now,
            ),
          );
        } else {
          for (final DroughtZoneChange change in droughtZoneChanges(
            before: last,
            after: read,
          )) {
            placeNotices.add(
              DroughtZoneChanged(
                placeLabel: target.label,
                zoneName: change.name,
                zoneKind: change.kind,
                before: change.before,
                after: change.after,
                decreeValidFrom: change.decreeValidFrom,
                receivedAt: now,
              ),
            );
          }
        }
        _addIfChanged(updated, before, _withDrought(before, read, null));
      }
    }

    // Un avis par cause dont des lieux ouvrent leur série, dans l'ordre de
    // déclaration de `CheckFailureCause` : injoignable, refusée, illisible
    // (PD4).
    return <ReadableNotice>[
      for (final CheckFailureCause cause in CheckFailureCause.values)
        if (opening[cause]!.isNotEmpty)
          CheckImpossible(
            source: FollowUpSource.drought,
            cause: cause,
            placeLabels: opening[cause]!,
            receivedAt: now,
          ),
      ...placeNotices,
    ];
  }
}

CheckFailureCause _floodCause(FloodVigilanceFailure failure) =>
    switch (failure) {
      VigilanceInjoignable() => CheckFailureCause.unreachable,
      VigilanceRefusee() => CheckFailureCause.refused,
      VigilanceIllisible() => CheckFailureCause.unreadable,
    };

CheckFailureCause _droughtCause(RestrictionLookupFailure failure) =>
    switch (failure) {
      SourceInjoignable() => CheckFailureCause.unreachable,
      RequeteRefusee() => CheckFailureCause.refused,
      ReponseIllisible() => CheckFailureCause.unreadable,
    };

FloodFollowUp _withFlood(
  FloodFollowUp followUp,
  LastKnownFloodLevel? lastKnown,
  FailureSeries? series,
) => FloodFollowUp(
  place: followUp.place,
  threshold: followUp.threshold,
  lastKnown: lastKnown,
  series: series,
);

DroughtFollowUp _withDrought(
  DroughtFollowUp followUp,
  LastKnownZones? lastKnown,
  FailureSeries? series,
) => DroughtFollowUp(
  place: followUp.place,
  lastKnown: lastKnown,
  series: series,
);

/// `updated` ne porte que les suivis dont le dernier état ou la série change.
void _addIfChanged(List<FollowUp> updated, FollowUp before, FollowUp after) {
  if (after != before) {
    updated.add(after);
  }
}

typedef _Stored = ({FollowUpBook book, List<Favorite> favorites});

final class _FloodTarget {
  const _FloodTarget(this.label, this.code, this.followUp);

  /// Le nom du favori.
  final String label;
  final FloodSectionCode code;
  final FloodFollowUp followUp;
}

final class _DroughtTarget {
  const _DroughtTarget(this.label, this.followUp, this.locate);

  /// Le libellé du favori.
  final String label;
  final DroughtFollowUp followUp;

  /// Le point à interroger ; `null` pour une station absente du référentiel.
  final Future<GeoPoint?> Function() locate;
}

final class _Targets {
  const _Targets(this.floods, this.drought, this.orphans);

  final List<_FloodTarget> floods;
  final List<_DroughtTarget> drought;
  final List<FollowUp> orphans;

  bool get isEmpty => floods.isEmpty && drought.isEmpty;
}
