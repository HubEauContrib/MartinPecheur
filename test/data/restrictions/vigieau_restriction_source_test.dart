// Verrouille `VigieauRestrictionSource` : l'URI n'a que `lat` et `lon`, la
// conversion des trois echecs (D3 de T2, conception T2 § 3 et § 4.2), et
// `retrievedAt` depuis une horloge injectee. Aucun appel reel :
// `http.testing.MockClient` sert les corps des fixtures reelles de
// `test/fixtures/vigieau/`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:martinpecheur/data/http/json_http_client.dart';
import 'package:martinpecheur/data/restrictions/vigieau_restriction_source.dart';
import 'package:martinpecheur/data/restrictions/vigieau_uris.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

final GeoPoint _point = GeoPoint(latitude: 46.2044, longitude: 5.2258);
final DateTime _retrievedAt = DateTime.utc(2026, 9, 27, 12, 0, 0);

String _fixtureBody(String name) =>
    File('test/fixtures/vigieau/$name').readAsStringSync();

VigieauRestrictionSource _sourceSur(
  http.Client mock, {
  DateTime Function()? now,
  List<Duration>? attentes,
  Duration? requestTimeout,
}) {
  return VigieauRestrictionSource(
    client: JsonHttpClient(
      httpClient: mock,
      jitter: () => 0,
      sleep: (Duration duree) async => attentes?.add(duree),
      requestTimeout: requestTimeout ?? defaultRequestTimeout,
    ),
    now: now ?? () => _retrievedAt,
  );
}

void main() {
  group('VigieauRestrictionSource.zonesAt — succes', () {
    test('Ain : trois zones, retrievedAt vient de l horloge injectee, '
        'l URI recue n a que lat et lon', () async {
      http.Request? requeteRecue;
      final http.Client mock = MockClient((http.Request request) async {
        requeteRecue = request;
        return http.Response.bytes(
          utf8.encode(
            _fixtureBody(
              'zones_ain_bourg-en-bresse_sans_profil_2026-09-27.json',
            ),
          ),
          200,
        );
      });

      final ZonesAtPoint reponse = await _sourceSur(mock).zonesAt(_point);

      expect(reponse.zones, hasLength(3));
      expect(reponse.retrievedAt, _retrievedAt);
      expect(reponse.point, _point);
      final ({String lat, String lon}) parametres = formatPointParameters(
        _point,
      );
      expect(requeteRecue!.url.queryParameters.keys, <String>{'lat', 'lon'});
      expect(requeteRecue!.url.queryParameters['lat'], parametres.lat);
      expect(requeteRecue!.url.queryParameters['lon'], parametres.lon);
    });

    test('200 [] : reponse vide, aucune exception', () async {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('[]', 200),
      );

      final ZonesAtPoint reponse = await _sourceSur(mock).zonesAt(_point);

      expect(reponse.zones, isEmpty);
    });

    test('horloge locale injectee : retrievedAt est convertie en UTC, au '
        'meme instant', () async {
      final DateTime horlogeLocale = DateTime(2026, 9, 27, 14);
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('[]', 200),
      );

      final ZonesAtPoint reponse = await _sourceSur(
        mock,
        now: () => horlogeLocale,
      ).zonesAt(_point);

      expect(reponse.retrievedAt.isUtc, isTrue);
      expect(reponse.retrievedAt.isAtSameMomentAs(horlogeLocale), isTrue);
    });
  });

  group('VigieauRestrictionSource.zonesAt — RequeteRefusee', () {
    test(
      '400 sur coordonnees invalides : RequeteRefusee(400), aucun rejeu',
      () async {
        int tentatives = 0;
        final List<Duration> attentes = <Duration>[];
        final http.Client mock = MockClient((http.Request request) async {
          tentatives++;
          return http.Response.bytes(
            utf8.encode(
              _fixtureBody('zones_coordonnees_invalides_400_2026-09-27.json'),
            ),
            400,
          );
        });

        await expectLater(
          _sourceSur(mock, attentes: attentes).zonesAt(_point),
          throwsA(
            isA<RequeteRefusee>()
                .having(
                  (RequeteRefusee echec) => echec.statusCode,
                  'statusCode',
                  400,
                )
                .having(
                  (RequeteRefusee echec) => echec.diagnostic,
                  'diagnostic',
                  contains('400'),
                ),
          ),
        );
        expect(tentatives, 1);
        expect(attentes, isEmpty);
      },
    );

    test('409 par commune : RequeteRefusee(409), aucun rejeu', () async {
      int tentatives = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response.bytes(
          utf8.encode(_fixtureBody('zones_commune_45210_409_2026-09-27.json')),
          409,
        );
      });

      await expectLater(
        _sourceSur(mock, attentes: attentes).zonesAt(_point),
        throwsA(
          isA<RequeteRefusee>().having(
            (RequeteRefusee echec) => echec.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
      expect(tentatives, 1);
      expect(attentes, isEmpty);
    });
  });

  group('VigieauRestrictionSource.zonesAt — SourceInjoignable', () {
    test('503 x4 : SourceInjoignable apres rejeux', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response('service indisponible', 503);
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(tentatives, 4);
    });

    test('429 x4 : SourceInjoignable apres rejeux', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response('trop de requetes', 429);
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(tentatives, 4);
    });

    test('panne reseau (ClientException) : SourceInjoignable', () async {
      final http.Client mock = MockClient((http.Request request) async {
        throw http.ClientException('connexion refusee');
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
    });

    test('panne TLS (HandshakeException, non enveloppee par IOClient) : '
        'SourceInjoignable', () async {
      final http.Client mock = MockClient((http.Request request) async {
        throw const HandshakeException('handshake TLS echoue');
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
    });

    test('source qui ne repond jamais : le delai d attente de chaque tentative '
        'est une panne rejouable, SourceInjoignable apres rejeux, la requete '
        'ne reste pas sans fin', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) {
        tentatives++;
        return Completer<http.Response>().future;
      });

      await expectLater(
        _sourceSur(
          mock,
          requestTimeout: const Duration(milliseconds: 20),
        ).zonesAt(_point),
        throwsA(
          isA<SourceInjoignable>().having(
            (SourceInjoignable echec) => echec.diagnostic,
            'diagnostic',
            'délai d\'attente de 20 ms dépassé',
          ),
        ),
      );
      expect(tentatives, 4);
    });

    test('FormatException levee par le transport (gzip corrompu, redirection '
        'mal formee) : SourceInjoignable apres rejeux, jamais une '
        'FormatException nue', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        throw const FormatException('Filter error, bad data');
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(tentatives, 4);
    });
  });

  group('VigieauRestrictionSource.zonesAt — ReponseIllisible', () {
    test('200 objet au lieu de tableau : ReponseIllisible', () async {
      final http.Client mock = MockClient(
        (http.Request request) async => http.Response('{"a":1}', 200),
      );

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<ReponseIllisible>()),
      );
    });

    test('200 corps non JSON : ReponseIllisible apres rejeux', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response('pas du json', 200);
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<ReponseIllisible>()),
      );
      expect(tentatives, 4);
    });

    test('200 dont les octets ne sont pas de l UTF-8 : le decodage de succes '
        'est strict, ReponseIllisible apres rejeux', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        // `["\xFF"]` : un tableau JSON valide une fois l octet FF decode avec
        // tolerance (en caractere de remplacement U+FFFD) — seul un decodage
        // strict le refuse. Des octets qui ne sont pas du JSON meme toleres
        // (FF FE FD) ne distingueraient pas les deux decodages. Le
        // diagnostic et les quatre tentatives disent que le refus vient du
        // transport (corps illisible, rejouable), pas du mapper : decode avec
        // tolerance, ce serait un tableau d une chaine, refuse ensuite par le
        // mapper, sans rejeu.
        return http.Response.bytes(<int>[0x5B, 0x22, 0xFF, 0x22, 0x5D], 200);
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(
          isA<ReponseIllisible>().having(
            (ReponseIllisible echec) => echec.diagnostic,
            'diagnostic',
            startsWith('corps illisible (statut 200) : '),
          ),
        ),
      );
      expect(tentatives, 4);
    });
  });

  group('VigieauRestrictionSource.zonesAt — corps d echec non UTF-8', () {
    test('400 et octets FF FE FD : RequeteRefusee(400), aucun rejeu — le '
        'corps d echec n est qu un diagnostic, il ne rend pas la reponse '
        'illisible', () async {
      int tentatives = 0;
      final List<Duration> attentes = <Duration>[];
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response.bytes(<int>[0xFF, 0xFE, 0xFD], 400);
      });

      await expectLater(
        _sourceSur(mock, attentes: attentes).zonesAt(_point),
        throwsA(
          isA<RequeteRefusee>().having(
            (RequeteRefusee echec) => echec.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
      expect(tentatives, 1);
      expect(attentes, isEmpty);
    });

    test('503 et octets FF FE FD : rejoue, puis SourceInjoignable', () async {
      int tentatives = 0;
      final http.Client mock = MockClient((http.Request request) async {
        tentatives++;
        return http.Response.bytes(<int>[0xFF, 0xFE, 0xFD], 503);
      });

      await expectLater(
        _sourceSur(mock).zonesAt(_point),
        throwsA(isA<SourceInjoignable>()),
      );
      expect(tentatives, 4);
    });
  });
}
