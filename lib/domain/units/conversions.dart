// Conversion l/s → m³/s et mm → m, à un seul endroit (BR-002, C-02).
// Une absence en entree reste une absence en sortie (BR-007) : jamais
// remplacee par zero. Une valeur non finie n'est pas une absence mais un
// defaut, elle leve.

import 'package:martinpecheur/domain/units/quantities.dart';

/// Facteur de conversion entre l/s et m³/s, et entre mm et m. N'apparaît
/// que dans ce fichier (BR-002).
const int _perThousand = 1000;

/// Convertit un débit brut de l'API (l/s) en débit affichable (m³/s).
/// `null` en entrée renvoie `null` (BR-007). Une valeur non finie lève.
CubicMetresPerSecond? toCubicMetresPerSecond(LitresPerSecond? raw) {
  if (raw == null) {
    return null;
  }

  return CubicMetresPerSecond(_divide(raw.value));
}

/// Convertit une hauteur brute de l'API (mm) en hauteur affichable (m).
/// `null` en entrée renvoie `null` (BR-007). Une valeur non finie lève.
Metres? toMetres(Millimetres? raw) {
  if (raw == null) {
    return null;
  }

  return Metres(_divide(raw.value));
}

double _divide(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'doit être une valeur finie, ni NaN ni infinie',
    );
  }

  return value / _perThousand;
}
