// Verrouille SharedPreferencesFavoriteRepository (S3 de T3) : une clé, une
// chaîne JSON, `getString` et `setString` seulement, aucun mémo. Une valeur
// illisible n'est jamais remplacée sans geste ; une écriture en échec sort
// typée et est suivie d'une écriture compensatoire de la valeur d'avant ; les
// opérations d'une instance se suivent sans se croiser.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_favorite_repository.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_shared_preferences.dart';

const String _key = 'favorites';

const String _empty = '{"version":1,"favoris":[]}';

const String _stationEntry =
    '{"type":"station","ajoute_le":"2026-10-11T17:05:00.000Z",'
    '"code":"K447001001","libelle":"La Loire à Blois"}';

const String _ondeEntry =
    '{"type":"onde","ajoute_le":"2026-10-12T08:30:00.000Z","point":'
    '{"code":" O968 5312 ","libelle":"LA BONNEURE A MILLANCAY",'
    '"latitude":47.444182169,"longitude":1.78116675,'
    '"cours_d_eau":"la Bonne Heure",'
    '"departement":{"code":"41","libelle":"41"},"region":null}}';

const String _designatedEntry =
    '{"type":"point_designe","ajoute_le":"2027-01-02T00:00:00.000Z",'
    '"libelle":"Chez moi","latitude":46.2,"longitude":5.2}';

/// La valeur stockée portant [entries], en version 1.
String _value(List<String> entries) =>
    '{"version":1,"favoris":[${entries.join(',')}]}';

/// L'exemple entier de S2 : un point ONDE, une station, un type inconnu.
final String _example = _value(<String>[
  _ondeEntry,
  _stationEntry,
  _designatedEntry,
]);

StationFavorite _station({
  String code = 'K447001001',
  String label = 'La Loire à Blois',
}) => StationFavorite(
  code: StationCode(code),
  label: label,
  addedAt: DateTime.utc(2026, 10, 11, 17, 5),
);

OndePointFavorite _onde({
  String code = 'K4640001',
  double latitude = 47.444182169,
}) => OndePointFavorite(
  point: OndePoint(
    code: OndeStationCode(code),
    label: 'LA BONNEURE A MILLANCAY',
    latitude: latitude,
    longitude: 1.78116675,
    waterCourseLabel: 'la Bonne Heure',
    departement: const AdministrativeArea(code: '41', label: '41'),
  ),
  addedAt: DateTime.utc(2026, 10, 12, 8, 30),
);

SharedPreferencesFavoriteRepository _repository(FakeSharedPreferences fake) =>
    SharedPreferencesFavoriteRepository(preferences: () async => fake);

final Matcher _illisible = throwsA(isA<ListeDeFavorisIllisible>());
final Matcher _ecritureEnEchec = throwsA(isA<EcritureDeFavorisEnEchec>());

void main() {
  group('lecture et écriture', () {
    test('rien de stocké : readAll rend une liste vide, sans écrire', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences();

      expect(await _repository(fake).readAll(), isEmpty);
      expect(fake.writtenValues, isEmpty);
    });

    test('add(station) écrit la forme exacte ; add(onde) ensuite : le dernier '
        'ajouté est en tête', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences();
      final SharedPreferencesFavoriteRepository repository = _repository(fake);
      final StationFavorite station = _station();
      final OndePointFavorite onde = _onde();

      await repository.add(station);

      expect(
        fake.disk[_key],
        '{"version":1,"favoris":[{"type":"station",'
        '"ajoute_le":"2026-10-11T17:05:00.000Z","code":"K447001001",'
        '"libelle":"La Loire à Blois"}]}',
      );

      await repository.add(onde);

      expect(await repository.readAll(), <Favorite>[onde, station]);
    });

    test('readAll rend une liste non modifiable', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _value(<String>[_stationEntry]),
      });

      final List<Favorite> read = await _repository(fake).readAll();

      expect(() => read.add(_onde()), throwsUnsupportedError);
      expect(read.clear, throwsUnsupportedError);
    });

    test('rien de stocké : la liste vide rendue est non modifiable '
        'elle aussi', () async {
      final List<Favorite> read = await _repository(FakeSharedPreferences())
          .readAll();

      expect(() => read.add(_station()), throwsUnsupportedError);
    });

    test('station et point ONDE de même code : deux favoris ; '
        'remove(station) laisse le point ONDE', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences();
      final SharedPreferencesFavoriteRepository repository = _repository(fake);
      final StationFavorite station = _station();
      final OndePointFavorite onde = _onde(code: 'K447001001');

      await repository.add(station);
      await repository.add(onde);

      expect(await repository.readAll(), <Favorite>[onde, station]);

      await repository.remove(station);

      expect(await repository.readAll(), <Favorite>[onde]);
    });

    test('code ONDE à espaces de bord : relu identique ; remove du code sans '
        'espaces de bord ne retire rien', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences();
      final SharedPreferencesFavoriteRepository repository = _repository(fake);
      final OndePointFavorite onde = _onde(code: ' O968 5312 ');

      await repository.add(onde);

      final List<Favorite> read = await repository.readAll();
      expect(read, <Favorite>[onde]);
      expect(
        (read.single as OndePointFavorite).point.code.value,
        hasLength(11),
      );

      await repository.remove(_onde(code: 'O968 5312'));

      expect(await repository.readAll(), <Favorite>[onde]);
      expect(fake.writtenValues, hasLength(1));
    });

    test('add(station) deux fois : un seul setString ; remove d\'un absent : '
        'aucun', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences();
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await repository.add(_station());
      await repository.add(_station());

      expect(fake.writtenValues, hasLength(1));

      await repository.remove(_onde());

      expect(fake.writtenValues, hasLength(1));
    });

    test('deux entrées station de même code déjà stockées : remove retire les '
        'deux', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _value(<String>[_stationEntry, _ondeEntry, _stationEntry]),
      });
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await repository.remove(_station());

      expect(fake.disk[_key], _value(<String>[_ondeEntry]));
    });

    test('deux entrées station de même code déjà stockées : add de cette '
        'station n\'écrit rien', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _value(<String>[_stationEntry, _stationEntry]),
      });

      await _repository(fake).add(_station());

      expect(fake.writtenValues, isEmpty);
    });
  });

  group('magasin réel du paquet', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('une seconde instance relit le favori ajouté par la première — ce '
        'n\'est pas un cache mémoire', () async {
      final StationFavorite station = _station();
      await SharedPreferencesFavoriteRepository().add(station);

      final List<Favorite> read = await SharedPreferencesFavoriteRepository()
          .readAll();

      expect(read, <Favorite>[station]);
    });
  });

  group('entrée illisible', () {
    test('type inconnu conservé après un ajout : quatre entrées, la quatrième '
        'telle quelle', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _example,
      });

      await _repository(fake)
          .add(_station(code: 'K418001010', label: 'Une autre station'));

      final Map<String, Object?> written =
          jsonDecode(fake.writtenValues.single) as Map<String, Object?>;
      final List<Object?> entries = written['favoris']! as List<Object?>;
      expect(entries, hasLength(4));
      expect(entries[3], <String, Object?>{
        'type': 'point_designe',
        'ajoute_le': '2027-01-02T00:00:00.000Z',
        'libelle': 'Chez moi',
        'latitude': 46.2,
        'longitude': 5.2,
      });
    });

    test('retrait d\'un UnreadableFavorite par son texte brut : deux entrées '
        'restent, plus aucune de type point_designe', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _example,
      });
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await repository.remove(
        (await repository.readAll()).whereType<UnreadableFavorite>().single,
      );

      final Map<String, Object?> written =
          jsonDecode(fake.disk[_key]! as String) as Map<String, Object?>;
      final List<Object?> entries = written['favoris']! as List<Object?>;
      expect(entries, hasLength(2));
      expect(
        entries.cast<Map<String, Object?>>().map(
          (Map<String, Object?> entry) => entry['type'],
        ),
        <String>['onde', 'station'],
      );
    });

    test('un UnreadableFavorite de texte brut différent : aucun '
        'setString', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _example,
      });

      await _repository(fake)
          .remove(const UnreadableFavorite(raw: '{"type":"point_designe"}'));

      expect(fake.writtenValues, isEmpty);
    });

    test(
      'add(UnreadableFavorite) lève une ArgumentError, sans écrire',
      () async {
        final FakeSharedPreferences fake = FakeSharedPreferences();

        await expectLater(
          _repository(fake)
              .add(const UnreadableFavorite(raw: _designatedEntry)),
          throwsArgumentError,
        );
        expect(fake.writtenValues, isEmpty);
      },
    );

    test('add(UnreadableFavorite) lève une ArgumentError avant toute lecture, '
        'même sur une valeur illisible', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: 'pas du json',
      });

      await expectLater(
        _repository(fake).add(const UnreadableFavorite(raw: _designatedEntry)),
        throwsArgumentError,
      );
      expect(fake.writtenValues, isEmpty);
    });
  });

  group('valeur illisible', () {
    final Map<String, Object> illisibles = <String, Object>{
      "n'est pas du JSON": 'pas du json',
      'version 2': '{"version":2,"favoris":[]}',
      "n'est pas une chaîne": 42,
    };

    for (final MapEntry<String, Object> cas in illisibles.entries) {
      test('valeur qui ${cas.key} : readAll, add et remove lèvent '
          'ListeDeFavorisIllisible, rien n\'est écrit', () async {
        final FakeSharedPreferences fake = FakeSharedPreferences(
          <String, Object>{_key: cas.value},
        );
        final SharedPreferencesFavoriteRepository repository = _repository(
          fake,
        );

        await expectLater(repository.readAll(), _illisible);
        await expectLater(repository.add(_station()), _illisible);
        await expectLater(repository.remove(_station()), _illisible);

        expect(fake.writtenValues, isEmpty);
        expect(fake.cache[_key], cas.value);
        expect(fake.disk[_key], cas.value);
      });

      test('valeur qui ${cas.key} : « Tout effacer » aboutit, puis lire et '
          'ajouter aboutissent', () async {
        final FakeSharedPreferences fake = FakeSharedPreferences(
          <String, Object>{_key: cas.value},
        );
        final SharedPreferencesFavoriteRepository repository = _repository(
          fake,
        );

        await repository.clear();

        expect(fake.disk[_key], _empty);
        expect(await repository.readAll(), isEmpty);

        await repository.add(_station());

        expect(await repository.readAll(), <Favorite>[_station()]);
      });
    }

    test(
      'preferences() qui lève : readAll, add et remove lèvent '
      'ListeDeFavorisIllisible ; clear lève EcritureDeFavorisEnEchec',
      () async {
        final SharedPreferencesFavoriteRepository repository =
            SharedPreferencesFavoriteRepository(
              preferences: () async => throw StateError('prefs'),
            );

        await expectLater(repository.readAll(), _illisible);
        await expectLater(repository.add(_station()), _illisible);
        await expectLater(repository.remove(_station()), _illisible);
        await expectLater(repository.clear(), _ecritureEnEchec);
      },
    );
  });

  group('écriture en échec', () {
    test('setString qui rend false : add lève EcritureDeFavorisEnEchec, le '
        'magasin ne porte pas la station, et l\'écriture compensatoire remet la '
        'liste vide', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeOutcomes.add(false);
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await expectLater(repository.add(_station()), _ecritureEnEchec);

      // La compensation aboutit : elle écrit la liste vide, pas la station.
      expect(fake.disk[_key], _empty);
      expect(await repository.readAll(), isEmpty);
      expect(fake.writtenValues, hasLength(2));
      expect(fake.writtenValues[1], _empty);
    });

    test('setString qui rend false sur une liste déjà stockée : la '
        'compensation réécrit la valeur d\'avant, au caractère près', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _example,
      })..writeOutcomes.add(false);
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await expectLater(repository.remove(_station()), _ecritureEnEchec);

      expect(fake.writtenValues, hasLength(2));
      expect(fake.writtenValues[1], _example);
      expect(fake.cache[_key], _example);
      expect(await repository.readAll(), hasLength(3));
    });

    test('setString qui lève : add lève EcritureDeFavorisEnEchec, pas '
        'StateError', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeOutcomes.add(StateError('disque'));
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await expectLater(repository.add(_station()), _ecritureEnEchec);

      expect(await repository.readAll(), isEmpty);
    });

    test('setString qui lève : remove lève EcritureDeFavorisEnEchec, la liste '
        'd\'avant reste lue', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _value(<String>[_stationEntry]),
      })..writeOutcomes.add(StateError('disque'));
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await expectLater(repository.remove(_station()), _ecritureEnEchec);

      expect(await repository.readAll(), <Favorite>[_station()]);
    });

    test('setString qui lève : clear lève EcritureDeFavorisEnEchec, la liste '
        'd\'avant reste lue', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: _value(<String>[_stationEntry]),
      })..writeOutcomes.add(StateError('disque'));
      final SharedPreferencesFavoriteRepository repository = _repository(fake);

      await expectLater(repository.clear(), _ecritureEnEchec);

      expect(fake.writtenValues, <String>[
        _empty,
        _value(<String>[_stationEntry]),
      ]);
      expect(await repository.readAll(), <Favorite>[_station()]);
    });

    test('setString qui rend false : clear lève '
        'EcritureDeFavorisEnEchec', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeOutcomes.add(false);

      await expectLater(_repository(fake).clear(), _ecritureEnEchec);
    });

    test(
      'clear en échec sur une valeur qui n\'est pas une chaîne : '
      'EcritureDeFavorisEnEchec, sans autre exception ni compensation',
      () async {
        final FakeSharedPreferences fake = FakeSharedPreferences(
          <String, Object>{_key: 42},
        )..writeOutcomes.add(false);

        await expectLater(_repository(fake).clear(), _ecritureEnEchec);

        expect(fake.writtenValues, <String>[_empty]);
        expect(fake.disk[_key], 42);
        // La limite : sans valeur d'avant lisible, rien ne compense — le cache
        // porte la liste vide alors que le magasin garde l'ancienne valeur.
        expect(fake.cache[_key], _empty);
      },
    );

    test(
      'compensation qui échoue elle aussi : add lève '
      'EcritureDeFavorisEnEchec, une seule fois, sans autre exception',
      () async {
        final FakeSharedPreferences fake = FakeSharedPreferences()
          ..writeOutcomes.addAll(<Object>[false, false]);

        final SharedPreferencesFavoriteRepository repository = _repository(
          fake,
        );

        await expectLater(repository.add(_station()), _ecritureEnEchec);

        expect(fake.writtenValues, hasLength(2));
        expect(fake.writeOutcomes, isEmpty);
        expect(fake.disk.containsKey(_key), isFalse);
        // Le but de la compensation : le cache est remis, même si le magasin
        // l'a refusée elle aussi.
        expect(await repository.readAll(), isEmpty);
      },
    );

    test('compensation qui lève : add lève EcritureDeFavorisEnEchec, pas '
        'l\'erreur de la compensation', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeOutcomes.addAll(<Object>[false, StateError('disque')]);

      await expectLater(_repository(fake).add(_station()), _ecritureEnEchec);

      expect(fake.writtenValues, hasLength(2));
    });

    test('encodage qui lève (point ONDE à coordonnée non finie) : add lève '
        'EcritureDeFavorisEnEchec, sans aucun setString, la valeur stockée '
        'intacte', () async {
      final String before = _value(<String>[_stationEntry]);
      final FakeSharedPreferences fake = FakeSharedPreferences(<String, Object>{
        _key: before,
      });

      await expectLater(
        _repository(fake).add(_onde(latitude: double.nan)),
        _ecritureEnEchec,
      );

      expect(fake.writtenValues, isEmpty);
      expect(fake.cache[_key], before);
      expect(fake.disk[_key], before);
    });
  });

  group('sérialisation', () {
    test('deux ajouts lancés sans attendre : le second ne commence pas avant '
        'la fin du premier, et aucun favori n\'est perdu', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeGate = Completer<void>();
      final SharedPreferencesFavoriteRepository repository = _repository(fake);
      final StationFavorite station = _station();
      final OndePointFavorite onde = _onde();

      final Future<void> first = repository.add(station);
      final Future<void> second = repository.add(onde);
      await Future<void>.delayed(Duration.zero);

      expect(fake.writtenValues, hasLength(1));

      fake.writeGate!.complete();
      await first;
      await second;

      expect(await repository.readAll(), <Favorite>[onde, station]);
    });

    test('la première écriture échoue : la seconde opération s\'exécute quand '
        'même et aboutit', () async {
      final FakeSharedPreferences fake = FakeSharedPreferences()
        ..writeOutcomes.add(false);
      final SharedPreferencesFavoriteRepository repository = _repository(fake);
      final OndePointFavorite onde = _onde();

      final Future<void> first = repository.add(_station());
      final Future<void> second = repository.add(onde);

      await expectLater(first, _ecritureEnEchec);
      await second;

      expect(await repository.readAll(), <Favorite>[onde]);
      expect(fake.writtenValues, hasLength(3));
    });
  });

  test('le fichier du dépôt ne déclare aucun champ de type List<Favorite> — '
      'aucun mémo', () {
    final String source = File(
      'lib/data/preferences/shared_preferences_favorite_repository.dart',
    ).readAsStringSync();

    // Un champ de classe est indenté de deux espaces ; une variable locale,
    // de quatre au moins.
    final RegExp field = RegExp(
      r'^  (?:static |late |final )*List<Favorite>\??\s+\w+\s*[;=]',
      multiLine: true,
    );

    expect(field.hasMatch(source), isFalse);
    expect(
      field.hasMatch('  final List<Favorite> _memo = <Favorite>[];'),
      isTrue,
      reason: 'le motif doit reconnaître un champ',
    );
  });
}
