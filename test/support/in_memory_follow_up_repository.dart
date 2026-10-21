// Double en mémoire du contrat `FollowUpRepository` (M2 de T5) : mêmes
// invariants que le dépôt réel, plus de quoi provoquer chaque échec.
import 'dart:async';

import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';

final class InMemoryFollowUpRepository implements FollowUpRepository {
  InMemoryFollowUpRepository([FollowUpBook? initial])
    : _followUps = List<FollowUp>.of(initial?.followUps ?? const <FollowUp>[]),
      _lastCheckAt = initial?.lastCheckAt;

  List<FollowUp> _followUps;
  DateTime? _lastCheckAt;

  /// Posée : `read` et chaque écriture sauf `clear` la lèvent.
  Object? readError;

  /// Posée : chaque écriture la lève, après `writeGate`.
  Object? writeError;

  /// Posée : chaque écriture attend qu'elle aboutisse.
  Completer<void>? writeGate;

  int readCalls = 0;
  int writeCalls = 0;

  /// Les vérifications reportées avec succès, dans l'ordre.
  final List<CheckRecord> recordedChecks = <CheckRecord>[];

  FollowUpBook get stored =>
      FollowUpBook(followUps: _followUps, lastCheckAt: _lastCheckAt);

  @override
  Future<FollowUpBook> read() async {
    readCalls++;
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return stored;
  }

  /// Lecture puis garde, comme le dépôt réel : une écriture lit d'abord.
  Future<void> _beforeWrite({bool reads = true}) async {
    writeCalls++;
    if (reads) {
      final Object? read = readError;
      if (read != null) {
        throw read;
      }
    }
    await writeGate?.future;
    final Object? write = writeError;
    if (write != null) {
      throw write;
    }
  }

  @override
  Future<void> followFlood(
    FloodSectionPlace place,
    FloodThreshold threshold,
  ) async {
    await _beforeWrite();
    final FollowUp? existing = followUpOf(_followUps, place);
    if (existing is FloodFollowUp) {
      _followUps = <FollowUp>[
        for (final FollowUp f in _followUps)
          if (identical(f, existing))
            FloodFollowUp(
              place: place,
              threshold: threshold,
              lastKnown: existing.lastKnown,
              series: existing.series,
            )
          else
            f,
      ];
      return;
    }
    _followUps = <FollowUp>[
      ..._followUps,
      FloodFollowUp(place: place, threshold: threshold),
    ];
  }

  @override
  Future<void> followDrought(DroughtPlace place) async {
    await _beforeWrite();
    if (followUpOf(_followUps, place) != null) {
      return;
    }
    _followUps = <FollowUp>[..._followUps, DroughtFollowUp(place: place)];
  }

  @override
  Future<void> unfollow(FollowedPlace place) async {
    await _beforeWrite();
    _followUps = <FollowUp>[
      for (final FollowUp f in _followUps)
        if (placeOfFollowUp(f) != place) f,
    ];
  }

  @override
  Future<void> recordCheck(CheckRecord record) async {
    await _beforeWrite();
    final List<FollowUp> next = <FollowUp>[];
    for (final FollowUp stored in _followUps) {
      final FollowedPlace? place = placeOfFollowUp(stored);
      if (record.orphans.contains(stored)) {
        continue;
      }
      FollowUp? update;
      if (place != null) {
        update = followUpOf(record.updated, place);
      }
      next.add(switch ((stored, update)) {
        (final FloodFollowUp s, final FloodFollowUp u) => FloodFollowUp(
          place: s.place,
          threshold: s.threshold,
          lastKnown: u.lastKnown,
          series: u.series,
        ),
        (final DroughtFollowUp s, final DroughtFollowUp u) => DroughtFollowUp(
          place: s.place,
          lastKnown: u.lastKnown,
          series: u.series,
        ),
        _ => stored,
      });
    }
    _followUps = next;
    _lastCheckAt = record.checkedAt;
    recordedChecks.add(record);
  }

  @override
  Future<void> clear() async {
    await _beforeWrite(reads: false);
    _followUps = <FollowUp>[];
    _lastCheckAt = null;
  }
}
