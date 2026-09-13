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

    test('une date locale non UTC donne le jour UTC', () {
      final DateTime utc = DateTime.utc(2026, 8, 1);
      final DateTime local = utc.toLocal();
      expect(local.isUtc, isFalse);

      expect(formatDateUtc(local), '2026-08-01');
    });
  });
}
