// Ce test ne redémontre pas la politique de cache elle-même — c'est le
// rôle de `test/data/cache/cache_policy_test.dart`. Il démontre que
// `CachedRestrictionSource` la BRANCHE correctement (D4 de T2, conception
// § 10.6) : une fermeture `withCachePolicy` par point (clé =
// `formatPointParameters`, la même chaîne que l'URI, N1 d'ONDE), TTL fixe
// de six heures, `retrievedAt` d'origine qui survit à une relecture servie
// par le cache, et un échec jamais écrit — `inner` qui lève ne laisse rien
// en cache, l'appel suivant le rappelle.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/cached_restriction_source.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// Source bouchon : compte les appels par point, rend une valeur réglable,
/// et peut lever à la demande pour simuler une source en échec ou un
/// rafraîchissement en échec.
final class _SourceBouchon implements RestrictionSource {
  final Map<GeoPoint, int> appelsParPoint = <GeoPoint, int>{};
  final Map<GeoPoint, ZonesAtPoint> valeurs = <GeoPoint, ZonesAtPoint>{};
  Object? erreur;
  Duration delai = Duration.zero;

  int get appels =>
      appelsParPoint.values.fold(0, (int total, int n) => total + n);

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) async {
    appelsParPoint.update(point, (int n) => n + 1, ifAbsent: () => 1);
    if (delai > Duration.zero) {
      await Future<void>.delayed(delai);
    }
    final Object? echec = erreur;
    if (echec != null) {
      throw echec;
    }
    final ZonesAtPoint? valeur = valeurs[point];
    if (valeur == null) {
      throw StateError('aucune valeur reglee pour $point');
    }
    return valeur;
  }
}

ZonesAtPoint _reponse(GeoPoint point, DateTime retrievedAt) => ZonesAtPoint(
  point: point,
  retrievedAt: retrievedAt,
  zones: const <AlertZone>[],
);

void main() {
  final GeoPoint point = GeoPoint(latitude: 46.2, longitude: 5.2);
  final GeoPoint pointVoisin = GeoPoint(latitude: 46.20000001, longitude: 5.2);
  final GeoPoint autrePoint = GeoPoint(latitude: 43.6, longitude: 1.4);

  test('la duree n est ecrite qu une fois, dans la constante', () {
    expect(restrictionsCacheTtl, const Duration(hours: 6));
  });

  test(
    'inner qui leve : rien d ecrit, l appel suivant rappelle inner',
    () async {
      final _SourceBouchon bouchon = _SourceBouchon()
        ..erreur = const SourceInjoignable('panne');
      final DateTime maintenant = DateTime.utc(2026, 9, 27);
      final CachedRestrictionSource source = CachedRestrictionSource(
        inner: bouchon,
        now: () => maintenant,
      );

      await expectLater(
        source.zonesAt(point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(bouchon.appelsParPoint[point], 1);

      await expectLater(
        source.zonesAt(point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(
        bouchon.appelsParPoint[point],
        2,
        reason: 'un echec ne doit jamais etre ecrit en cache',
      );
    },
  );

  test('reponse vide : ecrite, l appel suivant n appelle pas inner', () async {
    final _SourceBouchon bouchon = _SourceBouchon();
    final DateTime maintenant = DateTime.utc(2026, 9, 27);
    bouchon.valeurs[point] = _reponse(point, maintenant);
    final CachedRestrictionSource source = CachedRestrictionSource(
      inner: bouchon,
      now: () => maintenant,
    );

    final ZonesAtPoint premiere = await source.zonesAt(point);
    expect(premiere.zones, isEmpty);
    expect(bouchon.appels, 1);

    final ZonesAtPoint seconde = await source.zonesAt(point);
    expect(seconde.zones, isEmpty);
    expect(bouchon.appels, 1);
  });

  test('retrievedAt survit au cache : ecrit a T0, relu a T0+1h, inner appele '
      'une fois', () async {
    final _SourceBouchon bouchon = _SourceBouchon();
    final DateTime t0 = DateTime.utc(2026, 9, 27, 8);
    bouchon.valeurs[point] = _reponse(point, t0);
    DateTime horloge = t0;
    final CachedRestrictionSource source = CachedRestrictionSource(
      inner: bouchon,
      now: () => horloge,
    );

    final ZonesAtPoint premiere = await source.zonesAt(point);
    expect(premiere.retrievedAt, t0);
    expect(bouchon.appels, 1);

    horloge = t0.add(const Duration(hours: 1));
    final ZonesAtPoint seconde = await source.zonesAt(point);
    expect(seconde.retrievedAt, t0);
    expect(bouchon.appels, 1);
  });

  test('meme point (memes decimales formatees) : une seule entree', () async {
    final _SourceBouchon bouchon = _SourceBouchon();
    final DateTime maintenant = DateTime.utc(2026, 9, 27);
    bouchon.valeurs[point] = _reponse(point, maintenant);
    bouchon.valeurs[pointVoisin] = _reponse(pointVoisin, maintenant);
    final CachedRestrictionSource source = CachedRestrictionSource(
      inner: bouchon,
      now: () => maintenant,
    );

    await source.zonesAt(point);
    await source.zonesAt(pointVoisin);
    expect(
      bouchon.appels,
      1,
      reason:
          'GeoPoint(46.2, 5.2) et GeoPoint(46.20000001, 5.2) partagent la '
          'meme chaine formatee a sept decimales',
    );
  });

  test('deux points distincts : deux entrees', () async {
    final _SourceBouchon bouchon = _SourceBouchon();
    final DateTime maintenant = DateTime.utc(2026, 9, 27);
    bouchon.valeurs[point] = _reponse(point, maintenant);
    bouchon.valeurs[autrePoint] = _reponse(autrePoint, maintenant);
    final CachedRestrictionSource source = CachedRestrictionSource(
      inner: bouchon,
      now: () => maintenant,
    );

    await source.zonesAt(point);
    await source.zonesAt(autrePoint);
    expect(bouchon.appels, 2);

    await source.zonesAt(point);
    await source.zonesAt(autrePoint);
    expect(bouchon.appels, 2);
  });

  group('AR-3 : entree perimee a six heures', () {
    test('bornee incluse (6h) : ancienne reponse rendue immediatement, '
        'datee de son retrievedAt d origine, rafraichissement en tache de '
        'fond', () async {
      final _SourceBouchon bouchon = _SourceBouchon();
      final DateTime t0 = DateTime.utc(2026, 9, 27, 8);
      bouchon.valeurs[point] = _reponse(point, t0);

      DateTime horloge = t0;
      final CachedRestrictionSource source = CachedRestrictionSource(
        inner: bouchon,
        now: () => horloge,
      );

      final ZonesAtPoint premiere = await source.zonesAt(point);
      expect(premiere.retrievedAt, t0);
      expect(bouchon.appels, 1);

      horloge = t0.add(const Duration(hours: 6));
      final DateTime t1 = horloge;
      bouchon.valeurs[point] = _reponse(point, t1);

      final ZonesAtPoint seconde = await source.zonesAt(point);
      expect(
        seconde.retrievedAt,
        t0,
        reason: 'rendue immediatement avec son retrievedAt d origine',
      );
      // `load` s'execute de facon synchrone dans `refresh()`
      // (`Future.sync`, `cache_policy.dart`) : le compteur du bouchon vaut
      // deja 2 avant tout `await` supplementaire.
      expect(bouchon.appels, 2);

      await Future<void>.delayed(Duration.zero);

      final ZonesAtPoint troisieme = await source.zonesAt(point);
      expect(
        troisieme.retrievedAt,
        t1,
        reason: 'la lecture suivante rend la reponse rafraichie',
      );
      expect(bouchon.appels, 2);
    });

    test('deux lectures simultanees sur une entree perimee : un seul appel '
        'a inner (C-12)', () async {
      final _SourceBouchon bouchon = _SourceBouchon()
        ..delai = const Duration(milliseconds: 10);
      final DateTime t0 = DateTime.utc(2026, 9, 27, 8);
      bouchon.valeurs[point] = _reponse(point, t0);

      DateTime horloge = t0;
      final CachedRestrictionSource source = CachedRestrictionSource(
        inner: bouchon,
        now: () => horloge,
      );

      await source.zonesAt(point);
      expect(bouchon.appels, 1);

      horloge = t0.add(const Duration(hours: 6));
      bouchon.valeurs[point] = _reponse(point, horloge);

      final List<ZonesAtPoint> lectures = await Future.wait<ZonesAtPoint>(
        <Future<ZonesAtPoint>>[source.zonesAt(point), source.zonesAt(point)],
      );
      expect(
        lectures.map((ZonesAtPoint z) => z.retrievedAt),
        everyElement(t0),
        reason:
            'les deux lectures sont servies tout de suite avec l ancien '
            'retrievedAt, sans attendre le rafraichissement en tache de '
            'fond',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bouchon.appels, 2);
    });

    test('rafraichissement en echec : l ancienne reponse reste', () async {
      final _SourceBouchon bouchon = _SourceBouchon();
      final DateTime t0 = DateTime.utc(2026, 9, 27, 8);
      bouchon.valeurs[point] = _reponse(point, t0);

      DateTime horloge = t0;
      final CachedRestrictionSource source = CachedRestrictionSource(
        inner: bouchon,
        now: () => horloge,
      );

      await source.zonesAt(point);
      expect(bouchon.appels, 1);

      horloge = t0.add(const Duration(hours: 6));
      bouchon.erreur = const SourceInjoignable('panne de rafraichissement');

      final ZonesAtPoint seconde = await source.zonesAt(point);
      expect(seconde.retrievedAt, t0);

      await Future<void>.delayed(Duration.zero);
      expect(bouchon.appels, 2);

      final ZonesAtPoint troisieme = await source.zonesAt(point);
      expect(
        troisieme.retrievedAt,
        t0,
        reason:
            'la source reste en echec : l ancienne reponse continue d etre '
            'servie',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        bouchon.appels,
        3,
        reason:
            'une lecture sur une entree toujours perimee relance un '
            'rafraichissement, meme apres un echec precedent',
      );
    });
  });
}
