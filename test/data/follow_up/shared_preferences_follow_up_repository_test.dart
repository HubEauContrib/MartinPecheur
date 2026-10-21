// Verrouille SharedPreferencesFollowUpRepository (D2 de T5) : une clé, une
// chaîne JSON, `getString` et `setString` seulement, aucun mémo. Le contrat du
// port est appelé sur le dépôt réel ; une valeur illisible n'est jamais
// remplacée sans geste ; une écriture en échec sort typée, la valeur d'avant
// rétablie.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/follow_up/follow_up_codec.dart';
import 'package:martinpecheur/data/follow_up/shared_preferences_follow_up_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/station/station.dart';

import '../../support/fake_shared_preferences.dart';
import '../../support/follow_up_repository_contract.dart';

const String _key = 'follow_ups';

const String _empty = '{"version":1,"derniere_verification":null,"suivis":[]}';

final FloodSectionPlace _a = FloodSectionPlace(FloodSectionCode('LC135'));
final StationPlace _station = StationPlace(StationCode('K447001001'));
final DateTime _t1 = DateTime.utc(2026, 10, 21, 9);

SharedPreferencesFollowUpRepository _on(FakeSharedPreferences preferences) =>
    SharedPreferencesFollowUpRepository(preferences: () async => preferences);

/// Sème le stockage par la chaîne JSON, illisibles compris par leur brut.
FakeSharedPreferences _seed(FollowUpBook book) =>
    FakeSharedPreferences(<String, Object>{_key: encodeFollowUps(book)});

void main() {
  followUpRepositoryContract(
    () async => _on(FakeSharedPreferences()),
    createSeeded: (FollowUpBook initial) async => _on(_seed(initial)),
  );

  group('SharedPreferencesFollowUpRepository', () {
    test('écrit sous la clé follow_ups, au format versionné', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      await _on(preferences).followFlood(_a, FloodThreshold.jaune);
      final FollowUpBook book = decodeFollowUps(
        preferences.disk[_key]! as String,
      );
      expect(book.followUps, <FollowUp>[
        FloodFollowUp(place: _a, threshold: FloodThreshold.jaune),
      ]);
    });

    test('ne mémorise rien : une valeur changée entre deux lectures', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesFollowUpRepository repository = _on(preferences);
      expect((await repository.read()).followUps, isEmpty);
      preferences.cache[_key] = encodeFollowUps(
        FollowUpBook(
          followUps: <FollowUp>[
            FloodFollowUp(place: _a, threshold: FloodThreshold.rouge),
          ],
        ),
      );
      expect((await repository.read()).followUps, hasLength(1));
    });

    test('le JSON écrit ne contient aucun mot d\'API', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesFollowUpRepository repository = _on(preferences);
      await repository.followFlood(_a, FloodThreshold.jaune);
      await repository.followDrought(_station);
      for (final String written in preferences.writtenValues) {
        expect(written, isNot(contains('alerte_renforcee')));
        expect(written, isNot(contains('NivInfViCr')));
        expect(written, isNot(contains('niveauGravite')));
      }
    });

    test('une entrée illisible est réécrite à l\'identique', () async {
      const String unreadable = '{"z":[1,2,{"a":null}]}';
      final FakeSharedPreferences preferences = FakeSharedPreferences(
        <String, Object>{
          _key:
              '{"version":1,"derniere_verification":null,'
              '"suivis":[$unreadable]}',
        },
      );
      await _on(preferences).followDrought(_station);
      final String written = preferences.disk[_key]! as String;
      expect(written, contains(unreadable));
      expect(
        decodeFollowUps(written).followUps.whereType<UnreadableFollowUp>(),
        hasLength(1),
      );
    });

    group('racine illisible', () {
      const List<String> roots = <String>[
        'pas du json',
        '{"version":2,"derniere_verification":null,"suivis":[]}',
        '{"version":1,"derniere_verification":null,"suivis":{}}',
        '[]',
      ];

      for (final String stored in roots) {
        test(
          'read et chaque écriture lèvent SuiviIllisible : $stored',
          () async {
            final FakeSharedPreferences preferences = FakeSharedPreferences(
              <String, Object>{_key: stored},
            );
            final SharedPreferencesFollowUpRepository repository = _on(
              preferences,
            );
            final List<Future<void> Function()> operations =
                <Future<void> Function()>[
                  () => repository.read(),
                  () => repository.followFlood(_a, FloodThreshold.jaune),
                  () => repository.followDrought(_station),
                  () => repository.unfollow(_a),
                  () => repository.recordCheck(
                    CheckRecord(
                      checkedAt: _t1,
                      updated: const <FollowUp>[],
                      orphans: const <FollowUp>[],
                    ),
                  ),
                ];
            for (final Future<void> Function() operation in operations) {
              await expectLater(operation(), throwsA(isA<SuiviIllisible>()));
            }
            expect(preferences.disk[_key], stored);
            expect(preferences.cache[_key], stored);
            expect(preferences.writtenValues, isEmpty);
          },
        );
      }

      test('une valeur qui n\'est pas une chaîne est illisible', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences(
          <String, Object>{_key: 5},
        );
        await expectLater(
          _on(preferences).read(),
          throwsA(isA<SuiviIllisible>()),
        );
      });

      test('des préférences inaccessibles sont illisibles', () async {
        final SharedPreferencesFollowUpRepository repository =
            SharedPreferencesFollowUpRepository(
              preferences: () async => throw StateError('inaccessible'),
            );
        await expectLater(repository.read(), throwsA(isA<SuiviIllisible>()));
        await expectLater(
          repository.clear(),
          throwsA(isA<EcritureDuSuiviEnEchec>()),
        );
      });

      test('clear remplace une racine illisible', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences(
          <String, Object>{_key: 'pas du json'},
        );
        final SharedPreferencesFollowUpRepository repository = _on(preferences);
        await repository.clear();
        expect(preferences.disk[_key], _empty);
        expect((await repository.read()).followUps, isEmpty);
      });
    });

    group('écriture en échec', () {
      test(
        'false : EcritureDuSuiviEnEchec, la valeur d\'avant rétablie',
        () async {
          final FakeSharedPreferences preferences = FakeSharedPreferences();
          final SharedPreferencesFollowUpRepository repository = _on(
            preferences,
          );
          await repository.followFlood(_a, FloodThreshold.jaune);
          final String before = preferences.disk[_key]! as String;
          preferences.writeOutcomes.add(false);
          await expectLater(
            repository.followDrought(_station),
            throwsA(isA<EcritureDuSuiviEnEchec>()),
          );
          expect(preferences.disk[_key], before);
          expect(preferences.cache[_key], before);
          expect((await repository.read()).followUps, hasLength(1));
        },
      );

      test(
        'levée : EcritureDuSuiviEnEchec, la valeur d\'avant rétablie',
        () async {
          final FakeSharedPreferences preferences = FakeSharedPreferences();
          final SharedPreferencesFollowUpRepository repository = _on(
            preferences,
          );
          await repository.followFlood(_a, FloodThreshold.jaune);
          final String before = preferences.disk[_key]! as String;
          preferences.writeOutcomes.add(StateError('disque plein'));
          await expectLater(
            repository.unfollow(_a),
            throwsA(isA<EcritureDuSuiviEnEchec>()),
          );
          expect(preferences.cache[_key], before);
          expect((await repository.read()).followUps, hasLength(1));
        },
      );

      test('rien de stocké avant : rétablit un livre vide', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences();
        preferences.writeOutcomes.add(false);
        await expectLater(
          _on(preferences).followFlood(_a, FloodThreshold.jaune),
          throwsA(isA<EcritureDuSuiviEnEchec>()),
        );
        expect(preferences.cache[_key], _empty);
      });

      test('recordCheck et clear échouent de même', () async {
        final FakeSharedPreferences preferences = FakeSharedPreferences();
        final SharedPreferencesFollowUpRepository repository = _on(preferences);
        preferences.writeOutcomes.add(false);
        await expectLater(
          repository.recordCheck(
            CheckRecord(
              checkedAt: _t1,
              updated: const <FollowUp>[],
              orphans: const <FollowUp>[],
            ),
          ),
          throwsA(isA<EcritureDuSuiviEnEchec>()),
        );
        expect((await repository.read()).lastCheckAt, isNull);
        preferences.writeOutcomes.add(false);
        await expectLater(
          repository.clear(),
          throwsA(isA<EcritureDuSuiviEnEchec>()),
        );
      });
    });

    test('les opérations se suivent sans se croiser', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesFollowUpRepository repository = _on(preferences);
      final Completer<void> gate = Completer<void>();
      preferences.writeGate = gate;
      final Future<void> first = repository.followFlood(
        _a,
        FloodThreshold.jaune,
      );
      final Future<void> second = repository.followDrought(_station);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writtenValues, hasLength(1));
      preferences.writeGate = null;
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect((await repository.read()).followUps, hasLength(2));
    });
  });
}
