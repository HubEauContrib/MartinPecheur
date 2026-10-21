// Verrouille SharedPreferencesNoticeRepository (D3 de T5) : une clé, une
// chaîne JSON, `getString` et `setString` seulement, aucun mémo. Le contrat du
// port est appelé sur le dépôt réel, les semences passant par la chaîne JSON ;
// une valeur illisible n'est jamais remplacée sans geste ; une écriture en
// échec sort typée, la valeur d'avant rétablie.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/follow_up/notices_codec.dart';
import 'package:martinpecheur/data/follow_up/shared_preferences_notice_repository.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/notice_repository.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/notice_repository_contract.dart';

const String _key = 'notices';

const String _empty = '{"version":1,"avis":[]}';

final DateTime _t0 = DateTime.utc(2026, 10, 21, 9);

ReadableNotice _notice(int index) => FloodLevelChanged(
  placeLabel: 'Tronçon $index',
  before: const Jaune(),
  after: const Orange(),
  informationDate: _t0.add(Duration(minutes: index)),
  receivedAt: _t0.add(Duration(minutes: index)),
);

SharedPreferencesNoticeRepository _on(FakeSharedPreferences preferences) =>
    SharedPreferencesNoticeRepository(preferences: () async => preferences);

/// Sème le stockage par la chaîne JSON, illisibles compris par leur brut.
FakeSharedPreferences _seed(List<ReceivedNotice> notices) =>
    FakeSharedPreferences(<String, Object>{_key: encodeNotices(notices)});

/// L'entrée JSON d'un avis, extraite de l'encodage de la liste à un élément.
String _entryOf(ReadableNotice notice) {
  final String written = encodeNotices(<ReceivedNotice>[notice]);

  return written.substring(written.indexOf('[') + 1, written.lastIndexOf(']'));
}

void main() {
  noticeRepositoryContract(
    () async => _on(FakeSharedPreferences()),
    createSeeded: (List<ReceivedNotice> initial) async => _on(_seed(initial)),
    createUnreadableRoot: () async =>
        _on(FakeSharedPreferences(<String, Object>{_key: 'pas du json'})),
  );

  group('SharedPreferencesNoticeRepository', () {
    test('écrit sous la clé notices, au format versionné', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      await _on(preferences).addAll(<ReadableNotice>[_notice(1)]);
      expect(decodeNotices(preferences.disk[_key]! as String), <ReceivedNotice>[
        _notice(1),
      ]);
    });

    test('addAll([]) n\'écrit rien', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      await _on(preferences).addAll(const <ReadableNotice>[]);
      expect(preferences.writtenValues, isEmpty);
      expect(preferences.disk, isEmpty);
    });

    test('ne mémorise rien : une valeur changée entre deux lectures', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesNoticeRepository repository = _on(preferences);
      expect(await repository.readAll(), isEmpty);
      preferences.cache[_key] = encodeNotices(<ReceivedNotice>[_notice(1)]);
      expect(await repository.readAll(), hasLength(1));
    });

    test('le JSON écrit ne contient aucun mot d\'API', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      await _on(preferences).addAll(<ReadableNotice>[
        DroughtZoneChanged(
          placeLabel: 'S',
          zoneName: 'Z',
          zoneKind: const EauxSuperficielles(),
          before: null,
          after: const AlerteRenforcee(),
          decreeValidFrom: _t0,
          receivedAt: _t0,
        ),
        _notice(1),
      ]);
      expect(preferences.writtenValues, isNotEmpty);
      for (final String written in preferences.writtenValues) {
        expect(written, contains('alerte-renforcee'));
        expect(written, isNot(contains('alerte_renforcee')));
        expect(written, isNot(contains('NivInfViCr')));
        expect(written, isNot(contains('niveauGravite')));
      }
    });

    test('un avis illisible est réécrit à l\'identique', () async {
      const String unreadable = '{"z":[1,2,{"a":null}]}';
      final FakeSharedPreferences preferences = FakeSharedPreferences(
        <String, Object>{_key: '{"version":1,"avis":[$unreadable]}'},
      );
      await _on(preferences).addAll(<ReadableNotice>[_notice(1)]);
      final String written = preferences.disk[_key]! as String;
      expect(written, contains(unreadable));
      expect(
        decodeNotices(written).whereType<UnreadableNotice>(),
        hasLength(1),
      );
    });

    test('markAllRead ne touche pas un illisible', () async {
      const String unreadable = '{"z":1}';
      final FakeSharedPreferences preferences = FakeSharedPreferences(
        <String, Object>{
          _key: '{"version":1,"avis":[$unreadable,${_entryOf(_notice(1))}]}',
        },
      );
      await _on(preferences).markAllRead();
      expect(decodeNotices(preferences.disk[_key]! as String), <ReceivedNotice>[
        const UnreadableNotice(raw: unreadable),
        _notice(1).asRead(),
      ]);
    });

    group('racine illisible', () {
      const List<String> roots = <String>[
        'pas du json',
        '{"version":2,"avis":[]}',
        '{"version":1,"avis":{}}',
        '[]',
      ];

      for (final String stored in roots) {
        test('readAll et chaque écriture lèvent : $stored', () async {
          final FakeSharedPreferences preferences = FakeSharedPreferences(
            <String, Object>{_key: stored},
          );
          final SharedPreferencesNoticeRepository repository = _on(preferences);
          final List<Future<void> Function()> operations =
              <Future<void> Function()>[
                () => repository.readAll(),
                () => repository.addAll(<ReadableNotice>[_notice(1)]),
                () => repository.markAllRead(),
              ];
          for (final Future<void> Function() operation in operations) {
            await expectLater(operation(), throwsA(isA<ListeDAvisIllisible>()));
          }
          expect(preferences.disk[_key], stored);
          expect(preferences.cache[_key], stored);
          expect(preferences.writtenValues, isEmpty);
        });
      }

      test('une valeur qui n\'est pas une chaîne est illisible', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences(
          <String, Object>{_key: 5},
        );
        await expectLater(
          _on(preferences).readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
      });

      test('des préférences inaccessibles sont illisibles', () async {
        final SharedPreferencesNoticeRepository repository =
            SharedPreferencesNoticeRepository(
              preferences: () async => throw StateError('inaccessible'),
            );
        await expectLater(
          repository.readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
        await expectLater(
          repository.clear(),
          throwsA(isA<EcritureDAvisEnEchec>()),
        );
      });

      test('clear remplace une racine illisible', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences(
          <String, Object>{_key: 'pas du json'},
        );
        final SharedPreferencesNoticeRepository repository = _on(preferences);
        await repository.clear();
        expect(preferences.disk[_key], _empty);
        expect(await repository.readAll(), isEmpty);
      });

      test('clear en échec rétablit la racine illisible d\'avant', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences(
          <String, Object>{_key: 'pas du json'},
        );
        final SharedPreferencesNoticeRepository repository = _on(preferences);
        preferences.writeOutcomes.add(false);
        await expectLater(
          repository.clear(),
          throwsA(isA<EcritureDAvisEnEchec>()),
        );
        expect(preferences.disk[_key], 'pas du json');
        expect(preferences.cache[_key], 'pas du json');
        await expectLater(
          repository.readAll(),
          throwsA(isA<ListeDAvisIllisible>()),
        );
      });
    });

    group('écriture en échec', () {
      test(
        'false : EcritureDAvisEnEchec, la valeur d\'avant rétablie',
        () async {
          final FakeSharedPreferences preferences = FakeSharedPreferences();
          final SharedPreferencesNoticeRepository repository = _on(preferences);
          await repository.addAll(<ReadableNotice>[_notice(1)]);
          final String before = preferences.disk[_key]! as String;
          preferences.writeOutcomes.add(false);
          await expectLater(
            repository.addAll(<ReadableNotice>[_notice(2)]),
            throwsA(isA<EcritureDAvisEnEchec>()),
          );
          expect(preferences.disk[_key], before);
          expect(preferences.cache[_key], before);
          expect(await repository.readAll(), hasLength(1));
        },
      );

      test(
        'levée : EcritureDAvisEnEchec, la valeur d\'avant rétablie',
        () async {
          final FakeSharedPreferences preferences = FakeSharedPreferences();
          final SharedPreferencesNoticeRepository repository = _on(preferences);
          await repository.addAll(<ReadableNotice>[_notice(1)]);
          final String before = preferences.disk[_key]! as String;
          preferences.writeOutcomes.add(StateError('disque plein'));
          await expectLater(
            repository.markAllRead(),
            throwsA(isA<EcritureDAvisEnEchec>()),
          );
          expect(preferences.cache[_key], before);
          expect((await repository.readAll()).single, _notice(1));
        },
      );

      test('rien de stocké avant : rétablit une liste vide', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences();
        preferences.writeOutcomes.add(false);
        await expectLater(
          _on(preferences).addAll(<ReadableNotice>[_notice(1)]),
          throwsA(isA<EcritureDAvisEnEchec>()),
        );
        expect(preferences.cache[_key], _empty);
      });

      test('clear en échec rétablit la valeur d\'avant', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences();
        final SharedPreferencesNoticeRepository repository = _on(preferences);
        await repository.addAll(<ReadableNotice>[_notice(1)]);
        final String before = preferences.disk[_key]! as String;
        preferences.writeOutcomes.add(false);
        await expectLater(
          repository.clear(),
          throwsA(isA<EcritureDAvisEnEchec>()),
        );
        expect(preferences.cache[_key], before);
        expect(await repository.readAll(), hasLength(1));
      });
    });

    test('les opérations se suivent sans se croiser', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesNoticeRepository repository = _on(preferences);
      final Completer<void> gate = Completer<void>();
      preferences.writeGate = gate;
      final Future<void> first = repository.addAll(<ReadableNotice>[
        _notice(1),
      ]);
      final Future<void> second = repository.addAll(<ReadableNotice>[
        _notice(2),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writtenValues, hasLength(1));
      preferences.writeGate = null;
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(await repository.readAll(), <ReceivedNotice>[
        _notice(2),
        _notice(1),
      ]);
    });
  });
}
