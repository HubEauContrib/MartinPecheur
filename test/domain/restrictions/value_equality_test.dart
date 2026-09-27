// Verrouille les helpers factorises d'egalite structurelle et de
// validation UTC (`lib/domain/restrictions/value_equality.dart`), utilises
// par AlertZone et ZonesAtPoint. Cas positifs ET negatifs : un helper qui
// rendrait toujours `true` (ou ne validerait jamais rien) doit etre
// attrape ici, avant d'etre attrape par les tests des types qui l'utilisent.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/value_equality.dart';

void main() {
  group('listEquals', () {
    test('deux listes identiques, memes elements et meme ordre', () {
      expect(listEquals(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
    });

    test('meme reference : egale sans comparer les elements', () {
      final List<int> liste = <int>[1, 2, 3];

      expect(listEquals(liste, liste), isTrue);
    });

    test('longueurs differentes : inegales', () {
      expect(listEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
    });

    test('meme longueur, ordre different : inegales', () {
      expect(listEquals(<int>[1, 2], <int>[2, 1]), isFalse);
    });

    test('meme longueur, un element different : inegales', () {
      expect(listEquals(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
    });

    test('deux listes vides : egales', () {
      expect(listEquals(<int>[], <int>[]), isTrue);
    });
  });

  group('setEquals', () {
    test('deux ensembles aux memes elements, ordre d insertion different', () {
      expect(setEquals(<int>{1, 2, 3}, <int>{3, 2, 1}), isTrue);
    });

    test('meme reference : egaux sans comparer les elements', () {
      final Set<int> ensemble = <int>{1, 2};

      expect(setEquals(ensemble, ensemble), isTrue);
    });

    test('cardinaux differents : inegaux', () {
      expect(setEquals(<int>{1, 2}, <int>{1, 2, 3}), isFalse);
    });

    test('meme cardinal, elements differents : inegaux', () {
      expect(setEquals(<int>{1, 2}, <int>{1, 3}), isFalse);
    });

    test('deux ensembles vides : egaux', () {
      expect(setEquals(<int>{}, <int>{}), isTrue);
    });
  });

  group('setHash', () {
    test('coherent avec setEquals : meme hash quel que soit l ordre', () {
      expect(setHash(<int>{1, 2, 3}), setHash(<int>{3, 2, 1}));
    });

    test('deux ensembles distincts n ont pas necessairement le meme hash', () {
      expect(setHash(<int>{1, 2}), isNot(setHash(<int>{1, 3})));
    });

    test('ensemble vide : hash stable', () {
      expect(setHash(<int>{}), setHash(<int>{}));
    });
  });

  group('requireUtc', () {
    test('une date UTC est rendue telle quelle', () {
      final DateTime utc = DateTime.utc(2026, 9, 27);

      expect(requireUtc(utc, 'x'), utc);
    });

    test('une date locale leve une ArgumentError nommee', () {
      expect(
        () => requireUtc(DateTime(2026, 9, 27), 'monChamp'),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.name,
            'name',
            'monChamp',
          ),
        ),
      );
    });
  });
}
