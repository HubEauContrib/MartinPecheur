// Le contrat de `FavoriteRepository`, éprouvé sur le double en mémoire
// (S1 de T3).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/station/station.dart';

import '../../support/in_memory_favorite_repository.dart';

StationFavorite _a([DateTime? at]) => StationFavorite(
  code: StationCode('K447001001'),
  label: 'La Loire à Blois',
  addedAt: at ?? DateTime.utc(2026, 10, 11),
);

StationFavorite _b() => StationFavorite(
  code: StationCode('K447001002'),
  label: 'Autre station',
  addedAt: DateTime.utc(2026, 10, 12),
);

String _failure(FavoriteStorageFailure f) => switch (f) {
  ListeDeFavorisIllisible() => 'illisible',
  EcritureDeFavorisEnEchec() => 'ecriture',
};

void main() {
  test('add de A puis B → [B, A] ; A rajouté garde sa date', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository();
    await repo.add(_a());
    await repo.add(_b());
    expect(await repo.readAll(), <Favorite>[_b(), _a()]);
    await repo.add(_a(DateTime.utc(2030)));
    expect(await repo.readAll(), <Favorite>[_b(), _a()]);
  });

  test('remove retire, puis sans erreur si absent', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository(
      <Favorite>[_b(), _a()],
    );
    await repo.remove(_a());
    expect(await repo.readAll(), <Favorite>[_b()]);
    await repo.remove(_a());
    expect(await repo.readAll(), <Favorite>[_b()]);
  });

  test('clear vide', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository(
      <Favorite>[_a()],
    );
    await repo.clear();
    expect(await repo.readAll(), isEmpty);
  });

  test('la liste rendue est non modifiable', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository(
      <Favorite>[_a()],
    );
    final List<Favorite> list = await repo.readAll();
    expect(() => list.add(_b()), throwsUnsupportedError);
  });

  test('add(UnreadableFavorite) → ArgumentError', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository();
    await expectLater(
      repo.add(const UnreadableFavorite(raw: '{}')),
      throwsArgumentError,
    );
  });

  test('readError : readAll, add, remove lèvent ; clear aboutit', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository(
      <Favorite>[_a()],
    )..readError = const ListeDeFavorisIllisible('x');
    await expectLater(repo.readAll(), throwsA(isA<ListeDeFavorisIllisible>()));
    await expectLater(repo.add(_b()), throwsA(isA<ListeDeFavorisIllisible>()));
    await expectLater(
      repo.remove(_a()),
      throwsA(isA<ListeDeFavorisIllisible>()),
    );
    await repo.clear();
    repo.readError = null;
    expect(await repo.readAll(), isEmpty);
  });

  test('writeError lève sur add, remove et clear', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository()
      ..writeError = const EcritureDeFavorisEnEchec('x');
    await expectLater(repo.add(_a()), throwsA(isA<EcritureDeFavorisEnEchec>()));
    await expectLater(
      repo.remove(_a()),
      throwsA(isA<EcritureDeFavorisEnEchec>()),
    );
    await expectLater(repo.clear(), throwsA(isA<EcritureDeFavorisEnEchec>()));
  });

  test('readGate : readAll compte son appel, attend la porte, puis rend la '
      'liste ; sans porte, il aboutit tout de suite', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository(
      <Favorite>[_a()],
    );
    final Completer<void> gate = Completer<void>();
    repo.readGate = gate;
    List<Favorite>? read;

    final Future<void> reading = repo.readAll().then((List<Favorite> l) {
      read = l;
    });
    await pumpEventQueue();

    expect(repo.readCalls, 1);
    expect(read, isNull);

    gate.complete();
    await reading;

    expect(read, <Favorite>[_a()]);

    repo.readGate = null;
    expect(await repo.readAll(), <Favorite>[_a()]);
    expect(repo.readCalls, 2);
  });

  test('readGate : la porte précède readError', () async {
    final InMemoryFavoriteRepository repo = InMemoryFavoriteRepository()
      ..readError = const ListeDeFavorisIllisible('x');
    final Completer<void> gate = Completer<void>();
    repo.readGate = gate;
    Object? failure;

    final Future<void> reading = repo.readAll().then<void>(
      (List<Favorite> _) {},
      onError: (Object e) {
        failure = e;
      },
    );
    await pumpEventQueue();
    expect(failure, isNull);

    gate.complete();
    await reading;

    expect(failure, isA<ListeDeFavorisIllisible>());
  });

  test('switch sans default sur FavoriteStorageFailure', () {
    expect(_failure(const ListeDeFavorisIllisible('x')), 'illisible');
    expect(_failure(const EcritureDeFavorisEnEchec('x')), 'ecriture');
    expect(const ListeDeFavorisIllisible('d').diagnostic, 'd');
  });
}
