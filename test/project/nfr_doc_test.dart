// Test de non-régression sur la documentation (pas sur le domaine métier) :
// dart:io est autorisé ici, jamais sous lib/domain/.
//
// Verrouille docs/nfr.md : une exigence non fonctionnelle sans chiffre n'est
// pas une exigence, c'est une intention. Le piège de ce type de document est
// une colonne de statut remplie de coches par optimisme — le dernier cas
// l'attrape explicitement.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('docs/nfr.md', () {
    late String contenu;

    setUpAll(() {
      contenu = File('docs/nfr.md').readAsStringSync();
    });

    test('nomme au moins sept identifiants NFR-NN distincts', () {
      final Iterable<String> identifiants = RegExp(r'NFR-\d{2}')
          .allMatches(contenu)
          .map((Match m) => m.group(0)!)
          .toSet();

      expect(
        identifiants.length,
        greaterThanOrEqualTo(7),
        reason:
            'une exigence sans chiffre est une intention, pas une '
            'exigence',
      );
    });

    test('contient les deux seuils de fluidité fixés avant la mesure du '
        'spike', () {
      expect(contenu, contains('16,7'));
      expect(contenu, contains('5 %'));
    });

    test('traite la géolocalisation, pas seulement la mentionner', () {
      expect(contenu, contains('géolocalisation'));
      expect(contenu, contains('aucun identifiant'));
    });

    test('renvoie vers 04-ui.md au lieu de recopier les ratios de '
        'contraste', () {
      expect(contenu, contains('04-ui.md'));
    });

    test('porte une section Constats ouverts', () {
      expect(contenu, contains('Constats ouverts'));
    });

    test(
      'toute ligne NFR- marquée par une coche nomme ce qui l\'a constatée',
      () {
        final List<String> lignesSuspectes = contenu
            .split('\n')
            .where((String ligne) => ligne.contains('NFR-'))
            .where((String ligne) => ligne.contains('✅'))
            .where(
              (String ligne) =>
                  !ligne.contains('constaté') &&
                  !ligne.contains('mesuré') &&
                  !ligne.contains('par construction') &&
                  !ligne.contains('test'),
            )
            .toList();

        expect(
          lignesSuspectes,
          isEmpty,
          reason:
              'une coche sans "constaté", "mesuré", "par construction" ni '
              '"test" est une coche posée par optimisme : $lignesSuspectes',
        );
      },
    );
  });
}
