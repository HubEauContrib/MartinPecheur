// Tests du ViewModel de l'écran « Favoris » (S8 de T3), sans rendu : un double
// de dépôt en mémoire, jamais un widget. Un seul cas (revue finale de T3, M9a)
// prend le vrai `SharedPreferencesFavoriteRepository`, sur
// `FakeSharedPreferences` : seul le dépôt réel sérialise ses opérations.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_favorite_repository.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/favorites/view_model/favorites_view_model.dart';

import '../../../support/fake_shared_preferences.dart';
import '../../../support/in_memory_favorite_repository.dart';

StationFavorite _station() => StationFavorite(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  addedAt: DateTime.utc(2026, 10, 11, 17, 5),
);

OndePointFavorite _onde() => OndePointFavorite(
  point: OndePoint(
    code: OndeStationCode('K4640001'),
    label: 'LA BONNEURE A MILLANCAY',
    latitude: 47.444182169,
    longitude: 1.78116675,
    waterCourseLabel: 'la Bonne Heure',
    departement: const AdministrativeArea(code: '41', label: '41'),
  ),
  addedAt: DateTime.utc(2026, 10, 12, 8, 30),
);

const UnreadableFavorite _unreadable = UnreadableFavorite(
  raw: '{"type":"inconnu"}',
  label: 'Un lieu futur',
);

/// Le nom court d'un état, pour comparer des suites d'états notifiés.
String _name(FavoritesState state) => switch (state) {
  FavorisFermes() => 'fermes',
  FavorisEnLecture() => 'enLecture',
  AucunFavori() => 'aucun',
  FavorisLus(:final List<Favorite> favorites) => 'lus(${favorites.length})',
  FavorisIllisibles() => 'illisibles',
};

void main() {
  late InMemoryFavoriteRepository repository;
  late FavoritesViewModel viewModel;
  late List<String> notified;
  var viewModelDisposed = false;

  void build(List<Favorite> initial) {
    viewModelDisposed = false;
    repository = InMemoryFavoriteRepository(initial);
    viewModel = FavoritesViewModel(favorites: repository);
    notified = <String>[];
    viewModel.addListener(() => notified.add(_name(viewModel.state)));
  }

  setUp(() => build(<Favorite>[_onde(), _station()]));

  tearDown(() {
    if (!viewModelDisposed) {
      viewModel.dispose();
    }
  });

  group('lecture', () {
    test('état initial : fermés', () {
      expect(viewModel.state, isA<FavorisFermes>());
      expect(viewModel.busy, isFalse);
      expect(viewModel.writeFailed, isFalse);
    });

    test("load : en lecture puis la liste, dans l'ordre du dépôt", () async {
      await viewModel.load();

      expect(notified, <String>['enLecture', 'lus(2)']);
      final FavorisLus lus = viewModel.state as FavorisLus;
      expect(lus.favorites, <Favorite>[_onde(), _station()]);
    });

    test('dépôt vide : aucun favori', () async {
      viewModel.dispose();
      build(<Favorite>[]);

      await viewModel.load();

      expect(viewModel.state, isA<AucunFavori>());
    });

    test('liste illisible : illisibles, jamais aucun favori', () async {
      repository.readError = const ListeDeFavorisIllisible('x');

      await viewModel.load();

      expect(viewModel.state, isA<FavorisIllisibles>());
    });

    test('une levée quelconque vaut illisible', () async {
      repository.readError = StateError('boum');

      await viewModel.load();

      expect(viewModel.state, isA<FavorisIllisibles>());
    });

    test("load deux fois : le dépôt est relu à chaque ouverture", () async {
      await viewModel.load();
      await viewModel.load();

      expect(repository.readCalls, 2);
    });

    test('load émet « en lecture » avant son premier await', () {
      unawaited(viewModel.load());

      expect(viewModel.state, isA<FavorisEnLecture>());
    });

    test("load efface l'échec d'écriture", () async {
      await viewModel.load();
      repository.writeError = const EcritureDeFavorisEnEchec('x');
      await viewModel.remove(_station());
      expect(viewModel.writeFailed, isTrue);

      await viewModel.load();

      expect(viewModel.writeFailed, isFalse);
    });
  });

  group('retrait', () {
    test('remove : relecture sans repasser par la lecture', () async {
      await viewModel.load();
      notified.clear();

      await viewModel.remove(_station());

      expect(repository.stored, <Favorite>[_onde()]);
      expect((viewModel.state as FavorisLus).favorites, <Favorite>[_onde()]);
      // Occupé (état inchangé), puis la liste relue : jamais « en lecture ».
      expect(notified, <String>['lus(2)', 'lus(1)']);
      expect(viewModel.busy, isFalse);
    });

    test('retirer le dernier : aucun favori', () async {
      viewModel.dispose();
      build(<Favorite>[_station()]);
      await viewModel.load();

      await viewModel.remove(_station());

      expect(viewModel.state, isA<AucunFavori>());
    });

    test('une entrée illisible se retire, les autres restent', () async {
      viewModel.dispose();
      build(<Favorite>[_unreadable, _station()]);
      await viewModel.load();

      await viewModel.remove(_unreadable);

      expect((viewModel.state as FavorisLus).favorites, <Favorite>[_station()]);
    });

    test("occupé pendant l'écriture, un second retrait est ignoré", () async {
      await viewModel.load();
      final Completer<void> gate = Completer<void>();
      repository.writeGate = gate;

      final Future<void> first = viewModel.remove(_station());
      expect(viewModel.busy, isTrue);
      await viewModel.remove(_onde());
      expect(repository.writeCalls, 1);

      gate.complete();
      await first;

      expect(viewModel.busy, isFalse);
    });

    test('écriture en échec : échec dit, état inchangé', () async {
      await viewModel.load();
      final FavoritesState before = viewModel.state;
      repository.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.remove(_station());

      expect(viewModel.writeFailed, isTrue);
      expect(viewModel.busy, isFalse);
      expect(viewModel.state, same(before));
    });
  });

  group("repartir d'une liste vide", () {
    test('depuis illisibles : aucun favori', () async {
      repository.readError = const ListeDeFavorisIllisible('x');
      await viewModel.load();
      expect(viewModel.state, isA<FavorisIllisibles>());
      // Le dépôt réel remplace la valeur illisible ; le double garde son
      // `readError`, on le remet à `null` comme le ferait `clear`.
      repository.readError = null;

      notified.clear();

      await viewModel.startOver();

      expect(viewModel.state, isA<AucunFavori>());
      expect(notified, <String>['illisibles', 'aucun']);
      expect(repository.stored, isEmpty);
    });

    test('en échec : illisibles gardé, échec dit, aucune relecture', () async {
      repository.readError = const ListeDeFavorisIllisible('x');
      await viewModel.load();
      final int reads = repository.readCalls;
      repository.writeError = const EcritureDeFavorisEnEchec('x');

      await viewModel.startOver();

      expect(viewModel.state, isA<FavorisIllisibles>());
      expect(viewModel.writeFailed, isTrue);
      expect(repository.readCalls, reads);
    });

    test('ignoré pendant une écriture', () async {
      await viewModel.load();
      final Completer<void> gate = Completer<void>();
      repository.writeGate = gate;
      final Future<void> first = viewModel.remove(_station());

      await viewModel.startOver();

      expect(repository.writeCalls, 1);
      gate.complete();
      await first;
    });
  });

  group('fermeture', () {
    test('load puis close : fermés', () async {
      await viewModel.load();

      viewModel.close();

      expect(viewModel.state, isA<FavorisFermes>());
    });

    test("close pendant une lecture : l'état reste fermé", () async {
      final Completer<void> gate = Completer<void>();
      repository.readGate = gate;
      final Future<void> loading = viewModel.load();

      viewModel.close();
      gate.complete();
      await loading;

      expect(viewModel.state, isA<FavorisFermes>());
    });

    test('close pendant un retrait : dépôt modifié, état fermé', () async {
      await viewModel.load();
      final Completer<void> gate = Completer<void>();
      repository.writeGate = gate;
      final Future<void> removing = viewModel.remove(_station());

      viewModel.close();
      gate.complete();
      await removing;

      expect(repository.stored, <Favorite>[_onde()]);
      expect(viewModel.state, isA<FavorisFermes>());
      expect(viewModel.busy, isFalse);
    });

    test("close efface l'échec d'écriture", () async {
      await viewModel.load();
      repository.writeError = const EcritureDeFavorisEnEchec('x');
      await viewModel.remove(_station());

      viewModel.close();

      expect(viewModel.writeFailed, isFalse);
    });

    test('remove et startOver sur fermés : aucun appel au dépôt', () async {
      await viewModel.load();
      viewModel.close();

      await viewModel.remove(_station());
      await viewModel.startOver();

      expect(repository.writeCalls, 0);
    });

    test('load après close : relit', () async {
      await viewModel.load();
      viewModel.close();
      final int reads = repository.readCalls;

      await viewModel.load();

      expect(repository.readCalls, reads + 1);
      expect(viewModel.state, isA<FavorisLus>());
    });
  });

  group('écriture et lecture croisées', () {
    test(
      "remove et startOver ignorés pendant la lecture d'ouverture",
      () async {
        final Completer<void> gate = Completer<void>();
        repository.readGate = gate;
        unawaited(viewModel.load());

        await viewModel.remove(_station());
        await viewModel.startOver();
        expect(repository.writeCalls, 0);

        gate.complete();
        await pumpEventQueue();

        expect((viewModel.state as FavorisLus).favorites, hasLength(2));
      },
    );

    test('close pendant une écriture en échec : rien ne reparaît', () async {
      await viewModel.load();
      final Completer<void> gate = Completer<void>();
      repository.writeGate = gate;
      repository.writeError = const EcritureDeFavorisEnEchec('x');
      final Future<void> removing = viewModel.remove(_station());

      viewModel.close();
      notified.clear();
      gate.complete();
      await removing;

      expect(viewModel.writeFailed, isFalse);
      expect(viewModel.state, isA<FavorisFermes>());
      expect(notified, isEmpty);
    });

    // Revue finale de T3 (M9a) : `close()` puis `load()` aussitôt, pendant un
    // retrait encore en vol (relevé de S8). La lecture du nouveau `load()`
    // voit le retrait parce que `_write` appelle le dépôt AVANT son premier
    // `await`, et que le dépôt réel ne lance une opération qu'une fois la
    // précédente terminée. Le double en mémoire ne sérialise rien : seul le
    // dépôt réel verrouille cet ordre.
    test('dépôt réel : retrait en vol, close puis load — la lecture voit le '
        'retrait', () async {
      final FakeSharedPreferences preferences = FakeSharedPreferences();
      final SharedPreferencesFavoriteRepository real =
          SharedPreferencesFavoriteRepository(
            preferences: () async => preferences,
          );
      await real.add(_station());
      await real.add(_onde());
      final FavoritesViewModel screen = FavoritesViewModel(favorites: real);
      addTearDown(screen.dispose);
      await screen.load();
      expect((screen.state as FavorisLus).favorites, <Favorite>[
        _onde(),
        _station(),
      ]);

      final Future<void> removing = screen.remove(_station());
      screen.close();
      final Future<void> loading = screen.load();
      await loading;
      await removing;

      expect(screen.state, isA<FavorisLus>());
      expect((screen.state as FavorisLus).favorites, <Favorite>[_onde()]);
      expect(await real.readAll(), <Favorite>[_onde()]);
    });

    test(
      'dispose pendant une écriture : ni notification ni relecture',
      () async {
        await viewModel.load();
        final Completer<void> gate = Completer<void>();
        repository.writeGate = gate;
        final Future<void> removing = viewModel.remove(_station());
        final int reads = repository.readCalls;
        notified.clear();

        viewModel.dispose();
        viewModelDisposed = true;
        gate.complete();
        await removing;

        expect(notified, isEmpty);
        expect(repository.readCalls, reads);
      },
    );
  });

  group('disposition et croisements', () {
    test(
      'dispose pendant une lecture : ni notification ni exception',
      () async {
        final Completer<void> gate = Completer<void>();
        repository.readGate = gate;
        final Future<void> loading = viewModel.load();
        notified.clear();

        viewModel.dispose();
        viewModelDisposed = true;
        gate.complete();
        await loading;

        expect(notified, isEmpty);
      },
    );

    test("après dispose, aucune action n'appelle le dépôt", () async {
      viewModel.dispose();
      viewModelDisposed = true;

      await viewModel.load();
      await viewModel.remove(_station());
      await viewModel.startOver();

      expect(repository.readCalls, 0);
      expect(repository.writeCalls, 0);
    });

    test("deux load croisés : l'état est celui du second", () async {
      final Completer<void> first = Completer<void>();
      repository.readGate = first;
      final Future<void> a = viewModel.load();
      repository.readGate = null;
      final Future<void> b = viewModel.load();
      await b;
      expect(viewModel.state, isA<FavorisLus>());
      // Le premier aboutirait en échec : il est tardif et n'écrit rien.
      repository.readError = const ListeDeFavorisIllisible('x');
      first.complete();
      await a;

      expect(viewModel.state, isA<FavorisLus>());
    });
  });
}
