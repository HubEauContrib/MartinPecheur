// Le contrat de NoticeRepository (M3 de T5) : les cas que tout dépôt tient,
// le double en mémoire comme le dépôt réel (D3). Il ne dépend que du port.
//
// Deux semences sont requises, car le port ne sait écrire ni un avis
// illisible ni une racine illisible ; les cas qui les gardent ne doivent pas
// disparaître sans bruit :
// - `createSeeded` rend un dépôt qui contient déjà la liste donnée, le plus
//   récent en tête, illisibles compris ;
// - `createUnreadableRoot` rend un dépôt dont la valeur stockée n'est pas une
//   liste d'avis lisible.
//
// « `addAll([])` n'écrit rien » se voit ici par la liste relue ; le nombre
// d'écritures se compte dans le test propre de chaque réalisation
// (`writeCalls` du double, le stockage du dépôt réel).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';

final DateTime _origin = DateTime.utc(2026, 10, 21);

/// Un avis lisible reconnaissable par [index] : plus [index] est grand, plus
/// l'avis est récent.
ReadableNotice _notice(int index) => FloodLevelChanged(
  placeLabel: 'Tronçon $index',
  before: const Jaune(),
  after: const Orange(),
  informationDate: _origin.add(Duration(minutes: index)),
  receivedAt: _origin.add(Duration(minutes: index)),
);

/// [count] avis, le plus récent en tête : `from + count - 1` … `from`.
List<ReadableNotice> _newestFirst(int from, int count) => <ReadableNotice>[
  for (int i = from + count - 1; i >= from; i--) _notice(i),
];

/// Pose les cas du contrat.
void noticeRepositoryContract(
  Future<NoticeRepository> Function() create, {
  required Future<NoticeRepository> Function(List<ReceivedNotice> initial)
  createSeeded,
  required Future<NoticeRepository> Function() createUnreadableRoot,
}) {
  group('contrat de NoticeRepository', () {
    late NoticeRepository repository;

    setUp(() async {
      repository = await create();
    });

    test('rien de stocké : une liste vide', () async {
      expect(await repository.readAll(), isEmpty);
    });

    test('addAll insère en tête, dans l’ordre donné', () async {
      await repository.addAll(<ReadableNotice>[_notice(2), _notice(1)]);
      await repository.addAll(<ReadableNotice>[_notice(4), _notice(3)]);
      expect(await repository.readAll(), <ReceivedNotice>[
        _notice(4),
        _notice(3),
        _notice(2),
        _notice(1),
      ]);
    });

    test('101 avis ajoutés : 100 gardés, les plus récents', () async {
      expect(maxStoredNotices, 100);
      await repository.addAll(_newestFirst(0, 101));
      final List<ReceivedNotice> stored = await repository.readAll();
      expect(stored, hasLength(maxStoredNotices));
      expect(stored, _newestFirst(1, 100));
    });

    test('101 avis ajoutés un à un : le plus ancien tombe', () async {
      for (int i = 0; i < 101; i++) {
        await repository.addAll(<ReadableNotice>[_notice(i)]);
      }
      expect(await repository.readAll(), _newestFirst(1, 100));
    });

    test('avec 99 existants, 3 ajoutés en tête dans l’ordre donné : les 2 plus '
        'anciens tombent', () async {
      await repository.addAll(_newestFirst(0, 99));
      await repository.addAll(<ReadableNotice>[
        _notice(100),
        _notice(102),
        _notice(101),
      ]);
      expect(await repository.readAll(), <ReceivedNotice>[
        _notice(100),
        _notice(102),
        _notice(101),
        ..._newestFirst(2, 97),
      ]);
    });

    test('markAllRead marque chaque avis lu, sans rien perdre', () async {
      await repository.addAll(<ReadableNotice>[_notice(2), _notice(1)]);
      await repository.markAllRead();
      final List<ReceivedNotice> stored = await repository.readAll();
      expect(stored, <ReceivedNotice>[
        _notice(2).asRead(),
        _notice(1).asRead(),
      ]);
      // Un avis ajouté ensuite arrive non lu.
      await repository.addAll(<ReadableNotice>[_notice(3)]);
      final List<ReceivedNotice> after = await repository.readAll();
      expect((after.first as ReadableNotice).read, isFalse);
    });

    test('addAll([]) ne change rien', () async {
      await repository.addAll(<ReadableNotice>[_notice(1)]);
      await repository.addAll(const <ReadableNotice>[]);
      expect(await repository.readAll(), <ReceivedNotice>[_notice(1)]);
    });

    test('clear vide la liste', () async {
      await repository.addAll(<ReadableNotice>[_notice(1)]);
      await repository.clear();
      expect(await repository.readAll(), isEmpty);
    });

    group('un avis illisible', () {
      const UnreadableNotice unreadable = UnreadableNotice(raw: '{"z":1}');

      test('garde sa place et son brut', () async {
        final NoticeRepository seeded = await createSeeded(<ReceivedNotice>[
          _notice(3),
          unreadable,
          _notice(1),
        ]);
        expect(await seeded.readAll(), <ReceivedNotice>[
          _notice(3),
          unreadable,
          _notice(1),
        ]);
        await seeded.addAll(<ReadableNotice>[_notice(4)]);
        expect(await seeded.readAll(), <ReceivedNotice>[
          _notice(4),
          _notice(3),
          unreadable,
          _notice(1),
        ]);
        await seeded.markAllRead();
        expect(await seeded.readAll(), <ReceivedNotice>[
          _notice(4).asRead(),
          _notice(3).asRead(),
          unreadable,
          _notice(1).asRead(),
        ]);
      });

      test('compte parmi les 100 gardés', () async {
        final NoticeRepository seeded = await createSeeded(<ReceivedNotice>[
          ..._newestFirst(1, 98),
          unreadable,
        ]);
        await seeded.addAll(<ReadableNotice>[_notice(200), _notice(199)]);
        final List<ReceivedNotice> stored = await seeded.readAll();
        expect(stored, hasLength(maxStoredNotices));
        expect(stored.last, _notice(1));
        expect(stored, isNot(contains(unreadable)));
      });
    });

    group('une racine illisible', () {
      late NoticeRepository unreadableRoot;

      setUp(() async {
        unreadableRoot = await createUnreadableRoot();
      });

      test('lève ListeDAvisIllisible à la lecture', () async {
        await expectLater(
          unreadableRoot.readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
      });

      test(
        'lève ListeDAvisIllisible à l’écriture, sans rien écraser',
        () async {
          await expectLater(
            unreadableRoot.addAll(<ReadableNotice>[_notice(1)]),
            throwsA(isA<ListeDAvisIllisible>()),
          );
          await expectLater(
            unreadableRoot.markAllRead(),
            throwsA(isA<ListeDAvisIllisible>()),
          );
          await expectLater(
            unreadableRoot.readAll(),
            throwsA(isA<ListeDAvisIllisible>()),
          );
        },
      );

      test('addAll([]) ne lève pas et ne la remplace pas', () async {
        await unreadableRoot.addAll(const <ReadableNotice>[]);
        await expectLater(
          unreadableRoot.readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
      });

      test('clear la remplace par une liste vide, sans la lire', () async {
        await unreadableRoot.clear();
        expect(await unreadableRoot.readAll(), isEmpty);
      });
    });
  });
}
