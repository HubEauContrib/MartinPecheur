// Verrouille les trois symboles communs à tous les endpoints Hub'Eau :
// maxPageSize, checkPageSize (C-08) et formatDateUtc. Déplacés hors de
// hub_eau_client_test.dart lors de l'extraction de hub_eau_paging.dart, pour
// que ce fichier ne dépende plus, même en test, d'un endpoint particulier.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/http/hub_eau_paging.dart';

void main() {
  group('maxPageSize', () {
    test('vaut 20000 (C-08, constaté sur /observations_tr)', () {
      expect(maxPageSize, 20000);
    });
  });

  group('checkPageSize — size minimal (C-08)', () {
    test('size: 0 lève ArgumentError', () {
      expect(() => checkPageSize(0), throwsArgumentError);
    });

    test('size: au-delà de maxPageSize lève ArgumentError', () {
      expect(() => checkPageSize(maxPageSize + 1), throwsArgumentError);
    });

    test('size: 1 et size: maxPageSize sont acceptées, sans lever', () {
      expect(() => checkPageSize(1), returnsNormally);
      expect(() => checkPageSize(maxPageSize), returnsNormally);
    });
  });

  group('formatDateUtc', () {
    test('formate AAAA-MM-JJ en UTC', () {
      expect(formatDateUtc(DateTime.utc(2026, 8, 1)), '2026-08-01');
    });

    // Deux cas symétriques : lequel des deux fait rougir le test sans
    // .toUtc() dépend du signe du décalage horaire local de la machine qui
    // exécute le test — décalage positif (est de l'UTC), c'est 23h59 qui
    // bascule au jour suivant ; décalage négatif (ouest de l'UTC), c'est
    // 00h01 qui bascule à la veille. `DateTime.utc(2026, 8, 1)` seul ne
    // discriminait rien : minuit reste le 1er quel que soit le signe.
    test('une date locale non UTC donne le jour UTC — décalage positif, '
        "c'est 23h59 qui bascule", () {
      final DateTime local = DateTime.utc(2026, 8, 1, 23, 59).toLocal();

      expect(formatDateUtc(local), '2026-08-01');
    });

    test('une date locale non UTC donne le jour UTC — décalage négatif, '
        "c'est 00h01 qui bascule", () {
      final DateTime local = DateTime.utc(2026, 8, 1, 0, 1).toLocal();

      expect(formatDateUtc(local), '2026-08-01');
    });
  });
}
