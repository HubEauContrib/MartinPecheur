// Le double en mémoire de FollowUpRepository tient le contrat, et ses
// pilotes d'échec fonctionnent (M2 de T5).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';

import '../../support/follow_up_repository_contract.dart';
import '../../support/in_memory_follow_up_repository.dart';

final FloodSectionPlace _a = FloodSectionPlace(FloodSectionCode('LC135'));

void main() {
  followUpRepositoryContract(
    () async => InMemoryFollowUpRepository(),
    createSeeded: (FollowUpBook initial) async =>
        InMemoryFollowUpRepository(initial),
  );

  group('pilotes du double', () {
    test('readError : toute lecture et toute écriture la lèvent', () async {
      final InMemoryFollowUpRepository repository = InMemoryFollowUpRepository()
        ..readError = const SuiviIllisible('x');
      await expectLater(repository.read(), throwsA(isA<SuiviIllisible>()));
      await expectLater(
        repository.followFlood(_a, FloodThreshold.jaune),
        throwsA(isA<SuiviIllisible>()),
      );
      expect(repository.readCalls, 1);
      // clear ne lit pas : c'est « Repartir sans lieu suivi ».
      await repository.clear();
    });

    test("writeError : l'écriture échoue et ne change rien", () async {
      final InMemoryFollowUpRepository repository = InMemoryFollowUpRepository()
        ..writeError = const EcritureDuSuiviEnEchec('plein');
      await expectLater(
        repository.followFlood(_a, FloodThreshold.jaune),
        throwsA(isA<EcritureDuSuiviEnEchec>()),
      );
      expect(repository.stored.followUps, isEmpty);
      expect(repository.writeCalls, 1);
    });

    test(
      "writeGate suspend l'écriture, recordedChecks garde la vérification",
      () async {
        final Completer<void> gate = Completer<void>();
        final InMemoryFollowUpRepository repository =
            InMemoryFollowUpRepository()..writeGate = gate;
        final CheckRecord record = CheckRecord(
          checkedAt: DateTime.utc(2026, 10, 21),
          updated: <FollowUp>[],
          orphans: <FollowUp>[],
        );
        bool done = false;
        final Future<void> pending = repository.recordCheck(record).then((_) {
          done = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(done, isFalse);
        gate.complete();
        await pending;
        expect(done, isTrue);
        expect(repository.recordedChecks, <CheckRecord>[record]);
        expect(repository.stored.lastCheckAt, DateTime.utc(2026, 10, 21));
      },
    );
  });
}
