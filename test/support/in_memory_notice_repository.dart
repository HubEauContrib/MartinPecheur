// Double en mémoire du contrat `NoticeRepository` (M3 de T5) : mêmes
// invariants que le dépôt réel, plus de quoi provoquer chaque échec.
import 'dart:async';

import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';

final class InMemoryNoticeRepository implements NoticeRepository {
  InMemoryNoticeRepository([List<ReceivedNotice>? initial])
    : _notices = List<ReceivedNotice>.of(initial ?? const <ReceivedNotice>[]);

  List<ReceivedNotice> _notices;

  /// Posée : `readAll` et chaque écriture sauf `clear` la lèvent. Comme le
  /// dépôt réel remplace alors la racine, un `clear` réussi la retire.
  Object? readError;

  /// Posée : chaque écriture la lève, après `writeGate`.
  Object? writeError;

  /// Posée : chaque écriture attend qu'elle aboutisse.
  Completer<void>? writeGate;

  int readCalls = 0;

  /// Les écritures tentées ; `addAll([])` n'en compte aucune.
  int writeCalls = 0;

  /// Ce qui est stocké, le plus récent en tête. Non modifiable.
  List<ReceivedNotice> get stored =>
      List<ReceivedNotice>.unmodifiable(_notices);

  @override
  Future<List<ReceivedNotice>> readAll() async {
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
  Future<void> addAll(List<ReadableNotice> notices) async {
    if (notices.isEmpty) {
      return;
    }
    await _beforeWrite();
    _notices = <ReceivedNotice>[
      ...notices,
      ..._notices,
    ].take(maxStoredNotices).toList();
  }

  @override
  Future<void> markAllRead() async {
    await _beforeWrite();
    _notices = <ReceivedNotice>[
      for (final ReceivedNotice notice in _notices)
        switch (notice) {
          final ReadableNotice readable => readable.asRead(),
          UnreadableNotice() => notice,
        },
    ];
  }

  @override
  Future<void> clear() async {
    await _beforeWrite(reads: false);
    _notices = <ReceivedNotice>[];
    readError = null;
  }
}
