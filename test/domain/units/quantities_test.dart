// Verrouille la signature des quatre unités nommées par le type (BR-002).
// Aucune validation attendue ici : ces types nomment, ils ne refusent pas.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

void main() {
  group('Unités nommées par le type (BR-002)', () {
    test('LitresPerSecond conserve la valeur brute de débit '
        "(relevé sur K447001001 le 2026-09-13)", () {
      const LitresPerSecond debitBrut = LitresPerSecond(47800.0);

      expect(debitBrut.value, 47800.0);
    });

    test(
      'Millimetres conserve une hauteur négative sans contrôle de signe',
      () {
        const Millimetres hauteurBrute = Millimetres(-1232.0);

        expect(hauteurBrute.value, -1232.0);
      },
    );

    test('CubicMetresPerSecond et Metres conservent leur valeur', () {
      const CubicMetresPerSecond debit = CubicMetresPerSecond(47.8);
      const Metres hauteur = Metres(-1.232);

      expect(debit.value, 47.8);
      expect(hauteur.value, -1.232);
    });
  });
}
