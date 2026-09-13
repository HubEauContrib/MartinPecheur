// La politique de cache, une seule fois : rendu immediat depuis le cache,
// rafraichissement en tache de fond si perime et si le reseau est
// disponible, deduplication des rafraichissements en vol (C-12), et un TTL
// refuse a la construction. Neuf cas, TTL 20 min sauf mention contraire.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/cache/cache_policy.dart';

void main() {
  final DateTime maintenant = DateTime(2026, 9, 13, 12);
  const Duration ttl = Duration(minutes: 20);

  test(
    "(1) un cache d'une minute rend la valeur en cache, aucun appel reseau",
    () async {
      int appelsLoad = 0;
      final List<String> ecritures = <String>[];

      final Future<String> Function() lire = withCachePolicy<String>(
        load: () async {
          appelsLoad++;
          return 'frais';
        },
        readCache: () async => CachedValue<String>(
          value: 'cache',
          storedAt: maintenant.subtract(const Duration(minutes: 1)),
        ),
        writeCache: (String v) async => ecritures.add(v),
        ttl: ttl,
        now: () => maintenant,
      );

      final String resultat = await lire();

      expect(resultat, 'cache');
      expect(appelsLoad, 0);
      expect(ecritures, isEmpty);
    },
  );

  test('(2) un cache de deux heures rend "vieux" immediatement, puis ecrit '
      '"frais" apres un tour de boucle', () async {
    int appelsLoad = 0;
    final List<String> ecritures = <String>[];

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(hours: 2)),
      ),
      writeCache: (String v) async => ecritures.add(v),
      ttl: ttl,
      now: () => maintenant,
    );

    final String resultat = await lire();
    expect(resultat, 'vieux');
    expect(ecritures, isEmpty);

    await Future<void>.delayed(Duration.zero);

    expect(appelsLoad, 1);
    expect(ecritures, <String>['frais']);
  });

  test('(3) un cache d un jour sans reseau disponible rend "vieux", aucun '
      'appel', () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(days: 1)),
      ),
      writeCache: (String v) async {},
      ttl: ttl,
      now: () => maintenant,
      networkAvailable: () => false,
    );

    final String resultat = await lire();
    await Future<void>.delayed(Duration.zero);

    expect(resultat, 'vieux');
    expect(appelsLoad, 0);
  });

  test('(4) un cache vide attend load, rend et ecrit "frais"', () async {
    int appelsLoad = 0;
    final List<String> ecritures = <String>[];

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => null,
      writeCache: (String v) async => ecritures.add(v),
      ttl: ttl,
    );

    final String resultat = await lire();

    expect(resultat, 'frais');
    expect(appelsLoad, 1);
    expect(ecritures, <String>['frais']);
  });

  test('(5) un rafraichissement en echec conserve "vieux", n ecrit rien, un '
      'second appel reessaie', () async {
    int appelsLoad = 0;
    final List<String> ecritures = <String>[];

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        throw const FormatException('reponse illisible');
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(hours: 2)),
      ),
      writeCache: (String v) async => ecritures.add(v),
      ttl: ttl,
      now: () => maintenant,
    );

    final String premier = await lire();
    await Future<void>.delayed(Duration.zero);

    expect(premier, 'vieux');
    expect(appelsLoad, 1);
    expect(ecritures, isEmpty);

    final String second = await lire();
    await Future<void>.delayed(Duration.zero);

    expect(second, 'vieux');
    expect(appelsLoad, 2);
    expect(ecritures, isEmpty);
  });

  test('(6) un cache d exactement vingt minutes bascule : "vieux" rendu, un '
      'appel', () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(ttl),
      ),
      writeCache: (String v) async {},
      ttl: ttl,
      now: () => maintenant,
    );

    final String resultat = await lire();
    await Future<void>.delayed(Duration.zero);

    expect(resultat, 'vieux');
    expect(appelsLoad, 1);
  });

  test('(7) quatre lectures simultanees sur une entree perimee ne '
      'declenchent qu un seul appel', () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'frais';
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(hours: 2)),
      ),
      writeCache: (String v) async {},
      ttl: ttl,
      now: () => maintenant,
    );

    final List<String> resultats = await Future.wait<String>(<Future<String>>[
      lire(),
      lire(),
      lire(),
      lire(),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(resultats, <String>['vieux', 'vieux', 'vieux', 'vieux']);
    expect(appelsLoad, 1);
  });

  test('(8) deux lectures separees par un tour de boucle declenchent deux '
      'appels', () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(hours: 2)),
      ),
      writeCache: (String v) async {},
      ttl: ttl,
      now: () => maintenant,
    );

    await lire();
    await Future<void>.delayed(Duration.zero);
    await lire();
    await Future<void>.delayed(Duration.zero);

    expect(appelsLoad, 2);
  });

  test('(10) cache perime, load leve de facon synchrone (fonction non async) : '
      'trois lectures separees par un tour de boucle appellent load trois '
      'fois', () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      // Non async : le throw est synchrone, avant tout await.
      load: () {
        appelsLoad++;
        throw const FormatException('sync');
      },
      readCache: () async => CachedValue<String>(
        value: 'vieux',
        storedAt: maintenant.subtract(const Duration(hours: 2)),
      ),
      writeCache: (String v) async {},
      ttl: ttl,
      now: () => maintenant,
    );

    await lire();
    await Future<void>.delayed(Duration.zero);
    await lire();
    await Future<void>.delayed(Duration.zero);
    await lire();
    await Future<void>.delayed(Duration.zero);

    expect(appelsLoad, 3);
  });

  test('(11) cache vide, writeCache leve : la lecture rend quand meme "frais", '
      "l'echec d'ecriture est absorbe", () async {
    int appelsLoad = 0;

    final Future<String> Function() lire = withCachePolicy<String>(
      load: () async {
        appelsLoad++;
        return 'frais';
      },
      readCache: () async => null,
      writeCache: (String v) async {
        throw StateError('disque plein');
      },
      ttl: ttl,
    );

    final String resultat = await lire();

    expect(resultat, 'frais');
    expect(appelsLoad, 1);
  });

  test('(9) un ttl de duree nulle est refuse', () {
    expect(
      () => withCachePolicy<String>(
        load: () async => 'frais',
        readCache: () async => null,
        writeCache: (String v) async {},
        ttl: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
