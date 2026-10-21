// Le double en mémoire de NoticeRepository tient le contrat, et ses pilotes
// d'échec fonctionnent (M3 de T5).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';

import '../../support/in_memory_notice_repository.dart';
import '../../support/notice_repository_contract.dart';

final ReadableNotice _notice = FloodLevelChanged(
  placeLabel: 'Loire à Orléans',
  before: const Jaune(),
  after: const Orange(),
  informationDate: DateTime.utc(2026, 10, 21, 6),
  receivedAt: DateTime.utc(2026, 10, 21, 8),
);

void main() {
  noticeRepositoryContract(
    () async => InMemoryNoticeRepository(),
    createSeeded: (List<ReceivedNotice> initial) async =>
        InMemoryNoticeRepository(initial),
    createUnreadableRoot: () async =>
        InMemoryNoticeRepository()
          ..readError = const ListeDAvisIllisible('racine'),
  );

  group('pilotes du double', () {
    test('addAll([]) n’écrit rien : writeCalls inchangé', () async {
      final InMemoryNoticeRepository repository = InMemoryNoticeRepository();
      await repository.addAll(const <ReadableNotice>[]);
      expect(repository.writeCalls, 0);
      await repository.addAll(<ReadableNotice>[_notice]);
      expect(repository.writeCalls, 1);
      await repository.addAll(const <ReadableNotice>[]);
      expect(repository.writeCalls, 1);
    });

    test(
      'readError : la lecture et chaque écriture sauf clear la lèvent',
      () async {
        final InMemoryNoticeRepository repository = InMemoryNoticeRepository(
          <ReceivedNotice>[_notice],
        )..readError = const ListeDAvisIllisible('x');
        await expectLater(
          repository.readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
        await expectLater(
          repository.addAll(<ReadableNotice>[_notice]),
          throwsA(isA<ListeDAvisIllisible>()),
        );
        await expectLater(
          repository.markAllRead(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
        expect(repository.readCalls, 1);
        expect(repository.stored, <ReceivedNotice>[_notice]);
        await repository.clear();
        expect(repository.stored, isEmpty);
      },
    );

    test("writeError : l'écriture échoue et ne change rien", () async {
      final InMemoryNoticeRepository repository = InMemoryNoticeRepository()
        ..writeError = const EcritureDAvisEnEchec('plein');
      await expectLater(
        repository.addAll(<ReadableNotice>[_notice]),
        throwsA(isA<EcritureDAvisEnEchec>()),
      );
      expect(repository.stored, isEmpty);
      expect(repository.writeCalls, 1);
    });

    test("writeGate suspend l'écriture", () async {
      final Completer<void> gate = Completer<void>();
      final InMemoryNoticeRepository repository = InMemoryNoticeRepository()
        ..writeGate = gate;
      bool done = false;
      final Future<void> pending = repository
          .addAll(<ReadableNotice>[_notice])
          .then((_) {
            done = true;
          });
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(repository.stored, isEmpty);
      gate.complete();
      await pending;
      expect(done, isTrue);
      expect(repository.stored, <ReceivedNotice>[_notice]);
    });

    test('stored ne se modifie pas du dehors', () {
      final InMemoryNoticeRepository repository = InMemoryNoticeRepository(
        <ReceivedNotice>[_notice],
      );
      expect(() => repository.stored.clear(), throwsUnsupportedError);
    });
  });
}
