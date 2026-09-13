// Verrouille le recul exponentiel à gigue injectée (C-12) : aucun quota
// chiffré n'est publié, aucun service intermédiaire ne mutualise la charge —
// sans étalement, tous les appareils réessaient à la même seconde. Le
// plafond porte sur la base, pas sur le résultat (voir doc de
// [delayForAttempt]) : deux tests au plateau avec gigue non nulle vérifient
// que la gigue reste visible au-delà de la sixième tentative.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/http/retry.dart';

void main() {
  group('Constantes (C-12)', () {
    test('baseDelay vaut 500 ms et maxDelay vaut 30 s', () {
      expect(baseDelay, const Duration(milliseconds: 500));
      expect(maxDelay, const Duration(seconds: 30));
    });
  });

  group('delayForAttempt, gigue nulle', () {
    double zeroJitter() => 0.0;

    test('double à chaque tentative avant le plateau', () {
      expect(
        delayForAttempt(0, jitter: zeroJitter),
        const Duration(milliseconds: 500),
      );
      expect(
        delayForAttempt(1, jitter: zeroJitter),
        const Duration(milliseconds: 1000),
      );
      expect(
        delayForAttempt(2, jitter: zeroJitter),
        const Duration(milliseconds: 2000),
      );
      expect(
        delayForAttempt(3, jitter: zeroJitter),
        const Duration(milliseconds: 4000),
      );
      expect(
        delayForAttempt(4, jitter: zeroJitter),
        const Duration(milliseconds: 8000),
      );
    });

    test('plafonne à maxDelay / 2 dès la tentative 5, gigue nulle', () {
      expect(
        delayForAttempt(5, jitter: zeroJitter),
        const Duration(milliseconds: 15000),
      );
      expect(
        delayForAttempt(12, jitter: zeroJitter),
        const Duration(milliseconds: 15000),
      );
    });
  });

  group('delayForAttempt, gigue maximale (1.0)', () {
    double maxJitter() => 1.0;

    test('au plateau, la gigue double la base plafonnée jusqu\'à maxDelay', () {
      expect(
        delayForAttempt(5, jitter: maxJitter),
        const Duration(milliseconds: 30000),
      );
      expect(
        delayForAttempt(40, jitter: maxJitter),
        const Duration(milliseconds: 30000),
      );
    });

    test('avant le plateau, la gigue double la base', () {
      expect(
        delayForAttempt(0, jitter: maxJitter),
        const Duration(milliseconds: 1000),
      );
    });
  });

  group('delayForAttempt, gigue médiane (0.5)', () {
    double medianJitter() => 0.5;

    test('au plateau, la gigue reste visible : 22500 ms', () {
      expect(
        delayForAttempt(5, jitter: medianJitter),
        const Duration(milliseconds: 22500),
      );
      expect(
        delayForAttempt(20, jitter: medianJitter),
        const Duration(milliseconds: 22500),
      );
    });

    test('avant le plateau : 750 ms à la tentative 0', () {
      expect(
        delayForAttempt(0, jitter: medianJitter),
        const Duration(milliseconds: 750),
      );
    });
  });

  group('Bornes et erreurs', () {
    test('le délai ne dépasse jamais maxDelay, gigue maximale, 0 à 63', () {
      for (int attempt = 0; attempt <= 63; attempt++) {
        final Duration delay = delayForAttempt(attempt, jitter: () => 1.0);
        expect(
          delay <= maxDelay,
          isTrue,
          reason: 'tentative $attempt a produit $delay > $maxDelay',
        );
      }
    });

    test('une tentative négative lève', () {
      expect(() => delayForAttempt(-1), throwsArgumentError);
    });
  });
}
