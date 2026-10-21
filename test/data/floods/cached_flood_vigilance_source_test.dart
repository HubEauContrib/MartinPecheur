// Ce test ne redemontre pas la politique de cache (c'est le role de
// `test/data/cache/cache_policy_test.dart`) : il demontre que
// `CachedFloodVigilanceSource` la BRANCHE correctement (W3 de T4) — une
// entree, une fermeture, TTL de `floodVigilanceCacheTtl`, un echec jamais
// ecrit, un rafraichissement en echec absorbe puis retente au geste suivant
// (arbitrage 12), un seul rafraichissement en vol. Les instants s'ecrivent a
// partir de la constante, jamais en dur.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/floods/cached_flood_vigilance_source.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';

FloodVigilanceMap _carte(int heure) => FloodVigilanceMap(
  informationDate: DateTime.utc(2026, 10, 14, heure),
  sections: const [],
  skippedEntities: 0,
);

/// Source bouchon : compte ses appels, rend la prochaine carte reglee, peut
/// lever, et peut retenir sa reponse derriere une barriere.
final class _SourceBouchon implements FloodVigilanceSource {
  int appels = 0;
  FloodVigilanceMap prochaine = _carte(1);
  Object? erreur;
  Completer<void>? barriere;

  @override
  Future<FloodVigilanceMap> current() async {
    appels++;
    final Completer<void>? attente = barriere;
    if (attente != null) {
      await attente.future;
    }
    final Object? echec = erreur;
    if (echec != null) {
      throw echec;
    }
    return prochaine;
  }
}

Future<void> _laisserCourir() => Future<void>.delayed(Duration.zero);

void main() {
  late _SourceBouchon source;
  late DateTime maintenant;
  late CachedFloodVigilanceSource cache;

  setUp(() {
    source = _SourceBouchon();
    maintenant = DateTime.utc(2026, 10, 14, 12);
    cache = CachedFloodVigilanceSource(inner: source, now: () => maintenant);
  });

  test('premier appel : attend la source et rend sa carte', () async {
    final FloodVigilanceMap carte = await cache.current();

    expect(carte, same(source.prochaine));
    expect(source.appels, 1);
  });

  test('a ttl - 1 s : meme carte, aucun nouvel appel', () async {
    final FloodVigilanceMap premiere = await cache.current();
    maintenant = maintenant.add(
      floodVigilanceCacheTtl - const Duration(seconds: 1),
    );

    final FloodVigilanceMap seconde = await cache.current();
    await _laisserCourir();

    expect(seconde, same(premiere));
    expect(source.appels, 1);
  });

  test('a ttl pile : rend le cache tout de suite, un rafraichissement part, '
      "l'appel suivant rend la nouvelle carte", () async {
    final FloodVigilanceMap ancienne = await cache.current();
    source.prochaine = _carte(2);
    maintenant = maintenant.add(floodVigilanceCacheTtl);

    final FloodVigilanceMap rendue = await cache.current();
    expect(rendue, same(ancienne));
    await _laisserCourir();
    expect(source.appels, 2);

    final FloodVigilanceMap suivante = await cache.current();
    expect(suivante, same(source.prochaine));
    expect(source.appels, 2);
  });

  test("rafraichissement en echec : l'ancienne carte reste rendue, aucune "
      "exception, l'appel suivant relance un seul rafraichissement", () async {
    final FloodVigilanceMap ancienne = await cache.current();
    maintenant = maintenant.add(floodVigilanceCacheTtl);
    source.erreur = const VigilanceInjoignable('reseau');

    expect(await cache.current(), same(ancienne));
    await _laisserCourir();
    expect(source.appels, 2);

    expect(await cache.current(), same(ancienne));
    await _laisserCourir();
    expect(source.appels, 3);

    source.erreur = null;
    source.prochaine = _carte(3);
    expect(await cache.current(), same(ancienne));
    await _laisserCourir();
    expect(source.appels, 4);
    expect(await cache.current(), same(source.prochaine));
  });

  test("premier appel en echec : l'echec remonte, l'appel suivant rappelle "
      'la source', () async {
    source.erreur = const VigilanceInjoignable('reseau');

    await expectLater(
      cache.current(),
      throwsA(const VigilanceInjoignable('reseau')),
    );
    expect(source.appels, 1);

    source.erreur = null;
    final FloodVigilanceMap carte = await cache.current();

    expect(carte, same(source.prochaine));
    expect(source.appels, 2);
  });

  test('deux appels simultanes sur une entree perimee : un seul '
      'rafraichissement', () async {
    await cache.current();
    maintenant = maintenant.add(floodVigilanceCacheTtl);
    source.barriere = Completer<void>();

    final Future<FloodVigilanceMap> a = cache.current();
    final Future<FloodVigilanceMap> b = cache.current();
    await Future.wait(<Future<FloodVigilanceMap>>[a, b]);
    await _laisserCourir();

    expect(source.appels, 2);
    source.barriere!.complete();
    await _laisserCourir();
  });

  group('vue fraiche (D1 de T5)', () {
    test('fresh.current() a ttl - 1 min d un current() : meme carte, zero '
        'appel', () async {
      final FloodVigilanceMap premiere = await cache.current();
      maintenant = maintenant.add(
        floodVigilanceCacheTtl - const Duration(minutes: 1),
      );

      final FloodVigilanceMap fraiche = await cache.fresh.current();
      await _laisserCourir();

      expect(fraiche, same(premiere));
      expect(source.appels, 1);
    });

    test('a ttl : fresh.current() attend la nouvelle carte, que current() '
        'rend ensuite sans nouvel appel', () async {
      await cache.current();
      source.prochaine = _carte(2);
      maintenant = maintenant.add(floodVigilanceCacheTtl);
      source.barriere = Completer<void>();

      FloodVigilanceMap? fraiche;
      final Future<void> lecture = cache.fresh.current().then((
        FloodVigilanceMap carte,
      ) {
        fraiche = carte;
      });
      await _laisserCourir();
      expect(source.appels, 2);
      expect(fraiche, isNull, reason: 'la vue fraiche attend la source');

      source.barriere!.complete();
      await lecture;
      expect(fraiche, same(source.prochaine));

      expect(await cache.current(), same(source.prochaine));
      expect(source.appels, 2, reason: 'les deux vues partagent l entree');
    });

    test('Review Focus 5 : a ttl + 1 min, l echec de la lecture fraiche '
        'remonte, et current() rend l ancienne carte avec sa date', () async {
      final FloodVigilanceMap ancienne = await cache.current();
      final DateTime dateAncienne = ancienne.informationDate;
      maintenant = maintenant.add(
        floodVigilanceCacheTtl + const Duration(minutes: 1),
      );
      source.prochaine = _carte(2);
      source.erreur = const VigilanceInjoignable('reseau');

      await expectLater(
        cache.fresh.current(),
        throwsA(const VigilanceInjoignable('reseau')),
      );
      expect(source.appels, 2);

      final FloodVigilanceMap rendue = await cache.current();
      await _laisserCourir();
      expect(rendue, same(ancienne));
      expect(rendue.informationDate, dateAncienne);
    });

    test('une lecture fraiche et une lecture ordinaire simultanees sur une '
        'entree perimee : un seul appel a la source', () async {
      await cache.current();
      maintenant = maintenant.add(floodVigilanceCacheTtl);
      source.prochaine = _carte(2);
      source.barriere = Completer<void>();

      final Future<FloodVigilanceMap> ordinaire = cache.current();
      final Future<FloodVigilanceMap> fraiche = cache.fresh.current();
      await _laisserCourir();
      source.barriere!.complete();

      await ordinaire;
      expect(await fraiche, same(source.prochaine));
      expect(source.appels, 2);
    });
  });
}
