// Verrouille l'echelle 3 (`04-ui.md` § 2) : quatre niveaux connus, une
// branche inconnue qui porte la valeur brute (BR-011), un seul libelle par
// niveau, et AUCUN rang de severite (conception T2 § 2.7, YAGNI).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';

/// `switch` exhaustif SANS `default` : une branche ajoutee a
/// [DroughtSeverity] sans cas ici casse la compilation (BR-011).
String _exhaustive(DroughtSeverity severity) => switch (severity) {
  Vigilance() => 'vigilance',
  Alerte() => 'alerte',
  AlerteRenforcee() => 'alerte renforcee',
  Crise() => 'crise',
  GraviteInconnue() => 'inconnue',
};

void main() {
  group('droughtSeverityLabel — echelle 3 de 04-ui.md § 2', () {
    test('les quatre niveaux connus et la branche inconnue', () {
      expect(droughtSeverityLabel(const Vigilance()), 'Vigilance');
      expect(droughtSeverityLabel(const Alerte()), 'Alerte');
      expect(droughtSeverityLabel(const AlerteRenforcee()), 'Alerte renforcée');
      expect(droughtSeverityLabel(const Crise()), 'Crise');
      expect(droughtSeverityLabel(const GraviteInconnue('x')), 'Non renseigné');
      expect(
        droughtSeverityLabel(const GraviteInconnue(null)),
        'Non renseigné',
      );
    });
  });

  group('droughtSeverityScale', () {
    test('les quatre niveaux, dans l ordre, sans branche inconnue', () {
      expect(droughtSeverityScale, const <DroughtSeverity>[
        Vigilance(),
        Alerte(),
        AlerteRenforcee(),
        Crise(),
      ]);
      expect(droughtSeverityScale.whereType<GraviteInconnue>(), isEmpty);
      expect(
        droughtSeverityScale.contains(const GraviteInconnue('x')),
        isFalse,
      );
    });

    test('la position se repere par egalite, instance non constante '
        'comprise', () {
      // ignore: prefer_const_constructors
      final DroughtSeverity nonConstant = AlerteRenforcee();

      expect(nonConstant, const AlerteRenforcee());
      expect(nonConstant.hashCode, const AlerteRenforcee().hashCode);
      expect(droughtSeverityScale.indexOf(nonConstant), 2);
      // ignore: prefer_const_constructors
      expect(Vigilance(), const Vigilance());
      expect(const Vigilance(), isNot(const Alerte()));
    });
  });

  group('GraviteInconnue — la valeur brute est portee (BR-011)', () {
    test('egalite par valeur brute', () {
      expect(
        const GraviteInconnue('extreme'),
        const GraviteInconnue('extreme'),
      );
      expect(
        const GraviteInconnue('extreme').hashCode,
        const GraviteInconnue('extreme').hashCode,
      );
      expect(
        const GraviteInconnue('extreme'),
        isNot(const GraviteInconnue('Extreme')),
      );
      expect(const GraviteInconnue(null), isNot(const GraviteInconnue('')));
    });

    test('null se construit sans lever', () {
      expect(() => const GraviteInconnue(null), returnsNormally);
      expect(const GraviteInconnue(null).rawValue, isNull);
    });

    test('la valeur brute est gardee telle que recue', () {
      expect(const GraviteInconnue(' Extreme ').rawValue, ' Extreme ');
    });

    test('une branche inconnue n egale aucun niveau connu', () {
      for (final DroughtSeverity level in droughtSeverityScale) {
        expect(const GraviteInconnue('vigilance'), isNot(level));
      }
    });
  });

  test('switch exhaustif sans default sur DroughtSeverity (BR-011)', () {
    expect(_exhaustive(const Crise()), 'crise');
    expect(_exhaustive(const GraviteInconnue(null)), 'inconnue');
  });

  test('aucun rang de severite expose (conception T2 § 2.7)', () {
    final String source = File('lib/domain/restrictions/drought_severity.dart')
        .readAsStringSync();

    expect(
      source,
      isNot(matches(RegExp(r'compareTo|Comparable|\brank|\bindex\b'))),
    );
  });
}
