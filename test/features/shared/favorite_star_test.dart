// Verrouille [FavoriteStar] (`S4` de T3) : l'état d'affichage de l'étoile de
// favori, en Dart pur, que deux ViewModels de fiche produisent et qu'un widget
// partagé consomme. Sans rendu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

void main() {
  group('FavoriteStar', () {
    test('writeFailed vaut false par défaut', () {
      const FavoriteStar star = FavoriteStar(filled: true, enabled: true);

      expect(star.writeFailed, isFalse);
    });

    test('égalité structurelle sur les trois champs', () {
      const FavoriteStar base = FavoriteStar(
        filled: true,
        enabled: true,
        writeFailed: true,
      );

      expect(
        base,
        const FavoriteStar(filled: true, enabled: true, writeFailed: true),
      );
      expect(
        base.hashCode,
        const FavoriteStar(
          filled: true,
          enabled: true,
          writeFailed: true,
        ).hashCode,
      );
      expect(
        base,
        isNot(
          const FavoriteStar(filled: false, enabled: true, writeFailed: true),
        ),
      );
      expect(
        base,
        isNot(
          const FavoriteStar(filled: true, enabled: false, writeFailed: true),
        ),
      );
      expect(
        base,
        isNot(
          const FavoriteStar(filled: true, enabled: true, writeFailed: false),
        ),
      );
    });

    test('toString nomme les trois champs', () {
      const FavoriteStar star = FavoriteStar(filled: true, enabled: false);

      expect(star.toString(), contains('filled: true'));
      expect(star.toString(), contains('enabled: false'));
      expect(star.toString(), contains('writeFailed: false'));
    });
  });

  group('favorite_star.dart — Dart pur', () {
    test('le fichier ne contient aucune directive import : aucun '
        'package:flutter, un ViewModel peut donc le prendre', () {
      final String source = File('lib/features/shared/favorite_star.dart')
          .readAsStringSync();

      final RegExp importDirective = RegExp(r'^\s*import\s', multiLine: true);

      expect(importDirective.hasMatch(source), isFalse);
      expect(source, isNot(contains('package:flutter')));
    });
  });
}
