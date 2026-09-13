// Verrouille ce qu'est un succès HTTP à un seul endroit (C-06). Constaté le
// 2026-09-13 sur le même endpoint hydrométrie : size=2 renvoie 206, une
// réponse vide renvoie 200 — un client qui n'accepte que 200 casse dès la
// première pagination. 204/304 ne sont pas des échecs mais n'ont pas de corps
// JSON : les compter en succès ferait échouer la désérialisation plus loin,
// pas la lecture du statut.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/http/http_status.dart';

void main() {
  group('isSuccess (C-06)', () {
    test('200 et 206 sont des succès', () {
      expect(isSuccess(200), isTrue);
      expect(isSuccess(206), isTrue);
    });

    test("204 et 304 n'apportent pas de corps JSON, ce ne sont pas des "
        'succès traités ici', () {
      expect(isSuccess(204), isFalse);
      expect(isSuccess(304), isFalse);
    });

    test('les 4xx et 5xx ne sont pas des succès', () {
      for (final int code in <int>[400, 403, 404, 409, 429, 500, 503]) {
        expect(isSuccess(code), isFalse, reason: '$code ne doit pas réussir');
      }
    });
  });

  group('isRetryable (C-12, C-01, C-14)', () {
    test('429 est rejouable (C-12) — aucun quota chiffré', () {
      expect(isRetryable(429), isTrue);
    });

    test('les 5xx sont rejouables', () {
      for (final int code in <int>[500, 502, 503, 599]) {
        expect(isRetryable(code), isTrue, reason: '$code doit être rejouable');
      }
    });

    test('les 4xx viennent de notre requête, aucun n\'est rejouable '
        '(403 = C-01, 409 = C-14)', () {
      for (final int code in <int>[400, 401, 403, 404, 409, 422]) {
        expect(
          isRetryable(code),
          isFalse,
          reason: '$code ne doit pas être rejouable',
        );
      }
    });

    test('200 et 206 ne sont pas rejouables, ce sont déjà des succès', () {
      expect(isRetryable(200), isFalse);
      expect(isRetryable(206), isFalse);
    });
  });
}
