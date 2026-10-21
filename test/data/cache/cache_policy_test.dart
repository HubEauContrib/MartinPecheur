// La politique de cache, une seule fois : rendu immediat depuis le cache,
// rafraichissement en tache de fond si perime et si le reseau est
// disponible, deduplication des rafraichissements en vol (C-12), et un TTL
// refuse a la construction. Neuf cas, TTL 20 min sauf mention contraire.
// Puis la lecture fraiche (D1 de T5) : une valeur valide rendue telle
// quelle, une valeur perimee ou absente relue en attendant load, le meme
// rafraichissement en vol que la lecture ordinaire.

import 'dart:async';

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

  group('lecture fraiche (withCachePolicyReads, D1 de T5)', () {
    test('(12) lecture fraiche d une valeur valide : zero load, la valeur en '
        'cache est rendue telle quelle', () async {
      int appelsLoad = 0;

      final CachedReads<String> lectures = withCachePolicyReads<String>(
        load: () async {
          appelsLoad++;
          return 'frais';
        },
        readCache: () async => CachedValue<String>(
          value: 'cache',
          storedAt: maintenant.subtract(ttl - const Duration(seconds: 1)),
        ),
        writeCache: (String v) async {},
        ttl: ttl,
        now: () => maintenant,
      );

      final String resultat = await lectures.readFresh();
      await Future<void>.delayed(Duration.zero);

      expect(resultat, 'cache');
      expect(appelsLoad, 0);
    });

    test('(13) a ttl exactement : load est attendu, puis la nouvelle valeur '
        'est rendue et ecrite', () async {
      int appelsLoad = 0;
      final List<String> ecritures = <String>[];
      final Completer<void> barriere = Completer<void>();

      final CachedReads<String> lectures = withCachePolicyReads<String>(
        load: () async {
          appelsLoad++;
          await barriere.future;
          return 'frais';
        },
        readCache: () async => CachedValue<String>(
          value: 'vieux',
          storedAt: maintenant.subtract(ttl),
        ),
        writeCache: (String v) async => ecritures.add(v),
        ttl: ttl,
        now: () => maintenant,
      );

      String? resultat;
      final Future<void> lecture = lectures.readFresh().then((String v) {
        resultat = v;
      });
      await Future<void>.delayed(Duration.zero);

      expect(appelsLoad, 1);
      expect(resultat, isNull, reason: 'la lecture fraiche attend load');

      barriere.complete();
      await lecture;

      expect(resultat, 'frais');
      expect(ecritures, <String>['frais']);
    });

    test('(14) lecture fraiche a froid : un seul load', () async {
      int appelsLoad = 0;
      CachedValue<String>? entree;

      final CachedReads<String> lectures = withCachePolicyReads<String>(
        load: () async {
          appelsLoad++;
          return 'frais';
        },
        readCache: () async => entree,
        writeCache: (String v) async {
          entree = CachedValue<String>(value: v, storedAt: maintenant);
        },
        ttl: ttl,
        now: () => maintenant,
      );

      expect(await lectures.readFresh(), 'frais');
      expect(await lectures.readFresh(), 'frais');
      expect(appelsLoad, 1);
    });

    test('(15) un read perime et un readFresh lances ensemble ne font qu un '
        'load', () async {
      int appelsLoad = 0;
      final Completer<void> barriere = Completer<void>();

      final CachedReads<String> lectures = withCachePolicyReads<String>(
        load: () async {
          appelsLoad++;
          await barriere.future;
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

      final Future<String> ordinaire = lectures.read();
      final Future<String> fraiche = lectures.readFresh();
      await Future<void>.delayed(Duration.zero);
      barriere.complete();

      expect(await ordinaire, 'vieux');
      expect(await fraiche, 'frais');
      expect(appelsLoad, 1);
    });

    test('(16) echec de load a la lecture fraiche : l exception remonte ; un '
        'read suivant rend l ancienne valeur et relance en fond', () async {
      int appelsLoad = 0;
      final List<String> ecritures = <String>[];

      final CachedReads<String> lectures = withCachePolicyReads<String>(
        load: () async {
          appelsLoad++;
          throw const FormatException('reponse illisible');
        },
        readCache: () async => CachedValue<String>(
          value: 'vieux',
          storedAt: maintenant.subtract(ttl),
        ),
        writeCache: (String v) async => ecritures.add(v),
        ttl: ttl,
        now: () => maintenant,
      );

      await expectLater(lectures.readFresh(), throwsFormatException);
      expect(appelsLoad, 1);
      expect(ecritures, isEmpty);

      expect(await lectures.read(), 'vieux');
      await Future<void>.delayed(Duration.zero);
      expect(appelsLoad, 2);
      expect(ecritures, isEmpty);
    });

    test('(17) lecture fraiche d une valeur perimee sans reseau annonce : '
        'networkAvailable n est pas consulte, load est attendu', () async {
      int appelsLoad = 0;
      int consultations = 0;

      final CachedReads<String> lectures = withCachePolicyReads<String>(
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
        networkAvailable: () {
          consultations++;
          return false;
        },
      );

      expect(await lectures.readFresh(), 'frais');
      expect(appelsLoad, 1);
      expect(consultations, 0);
    });

    test('(18) withCachePolicyReads refuse un ttl nul, comme '
        'withCachePolicy', () {
      expect(
        () => withCachePolicyReads<String>(
          load: () async => 'frais',
          readCache: () async => null,
          writeCache: (String v) async {},
          ttl: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
