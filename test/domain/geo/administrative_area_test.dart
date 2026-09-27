// AdministrativeArea est une classe immuable simple, sans validation propre
// (ADR-015) : ce test vérifie le port des deux champs et l'égalité
// structurelle, exactement comme pour les autres objets-valeur du domaine.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';

void main() {
  group('AdministrativeArea', () {
    test('porte le code et le libellé', () {
      const AdministrativeArea occitanie = AdministrativeArea(
        code: '76',
        label: 'OCCITANIE',
      );

      expect(occitanie.code, '76');
      expect(occitanie.label, 'OCCITANIE');
    });

    test('égalité structurelle sur les deux champs', () {
      expect(
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
      );
      expect(
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher').hashCode,
        const AdministrativeArea(code: '41', label: 'Loir-et-Cher').hashCode,
      );
    });

    test(
      'deux zones de même code mais de libellé différent restent '
      'distinctes — le libellé vient de la source, il n\'est pas jugé ici',
      () {
        expect(
          const AdministrativeArea(code: '41', label: 'Loir-et-Cher'),
          isNot(const AdministrativeArea(code: '41', label: 'AUTRE LIBELLE')),
        );
      },
    );

    test('un code différent rend deux zones distinctes, même libellé', () {
      expect(
        const AdministrativeArea(code: '41', label: 'X'),
        isNot(const AdministrativeArea(code: '45', label: 'X')),
      );
    });
  });
}
