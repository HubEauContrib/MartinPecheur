// Verrouille la conversion l/s → m³/s et mm → m à un seul endroit (BR-002).
// Une absence reste une absence (BR-007), une valeur non finie est un
// défaut, jamais une absence.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/units/conversions.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

void main() {
  group('Conversion débit l/s → m³/s (BR-002, C-02)', () {
    test('les débits mesurés se convertissent par mille '
        '(2026-09-13, 2026-08-01, 2026-07-30)', () {
      expect(
        toCubicMetresPerSecond(const LitresPerSecond(47800.0))?.value,
        closeTo(47.8, 1e-9),
      );
      expect(
        toCubicMetresPerSecond(const LitresPerSecond(48524.0))?.value,
        closeTo(48.524, 1e-9),
      );
      expect(
        toCubicMetresPerSecond(const LitresPerSecond(53000.0))?.value,
        closeTo(53.0, 1e-9),
      );
      expect(
        toCubicMetresPerSecond(const LitresPerSecond(350571.0))?.value,
        closeTo(350.571, 1e-9),
      );
    });

    test("un zero mesure reste un zero, c'est un assec (BR-007)", () {
      expect(
        toCubicMetresPerSecond(const LitresPerSecond(0))?.value,
        closeTo(0.0, 1e-9),
      );
    });

    test("une absence de debit reste une absence (BR-007)", () {
      expect(toCubicMetresPerSecond(null), isNull);
    });

    test(
      'une valeur non finie leve, ce n est pas une absence mais un defaut',
      () {
        expect(
          () => toCubicMetresPerSecond(const LitresPerSecond(double.nan)),
          throwsArgumentError,
        );
        expect(
          () => toCubicMetresPerSecond(const LitresPerSecond(double.infinity)),
          throwsArgumentError,
        );
      },
    );
  });

  group('Conversion hauteur mm → m (BR-002, C-02)', () {
    test('une hauteur negative traverse sans controle de signe', () {
      expect(
        toMetres(const Millimetres(-1232.0))?.value,
        closeTo(-1.232, 1e-9),
      );
    });

    test('une absence de hauteur reste une absence (BR-007)', () {
      expect(toMetres(null), isNull);
    });
  });
}
