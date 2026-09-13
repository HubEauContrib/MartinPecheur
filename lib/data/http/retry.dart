// Recul exponentiel à gigue injectée (C-12) : aucune des APIs publiques du
// projet ne publie de quota chiffré, et aucun service intermédiaire ne
// mutualise la charge entre appareils. Sans étalement, tous les appareils
// réessaient à la même seconde après une panne partagée — la gigue casse
// cette synchronisation, et le tirage est injectable pour rester testable
// (le générateur de dart:math est autrement non déterministe).
import 'dart:math';

/// Base du recul avant gigue à la première tentative : 500 ms.
const Duration baseDelay = Duration(milliseconds: 500);

/// Plafond absolu du délai renvoyé, gigue comprise : 30 s.
const Duration maxDelay = Duration(seconds: 30);

/// Tentative au-delà de laquelle le décalage de bits déborderait avant même
/// d'avoir atteint le plafond. La base y vaut déjà directement le plafond
/// (`maxDelay / 2`) : la figer à ce cran ne change aucun résultat observable.
const int _maxShiftedAttempt = 30;

final Random _rng = Random();

/// Tirage uniforme dans `[0, 1)` via le générateur de `dart:math` — le seul
/// de tout le produit.
double _defaultJitter() => _rng.nextDouble();

/// Délai avant une nouvelle tentative HTTP, gigue comprise (C-12).
///
/// La base vaut `baseDelay × 2^attempt`, **plafonnée à `maxDelay / 2`**
/// (15 000 ms). Le délai renvoyé vaut `base + jitter() × base`, donc entre
/// la base seule (gigue nulle) et le double de la base (gigue maximale).
///
/// Le plafond porte sur la **base**, pas sur le résultat : plafonner le
/// résultat ferait valoir `min(30000 + gigue, 30000) = 30000` dès la
/// sixième tentative, et la gigue disparaîtrait précisément quand elle
/// compte le plus pour étaler la charge entre appareils. En plafonnant la
/// base, le résultat continue de varier entre `maxDelay / 2` et `maxDelay`
/// selon la gigue, même au plateau.
///
/// [attempt] négatif lève une [ArgumentError] — une tentative n'a pas de
/// rang négatif.
Duration delayForAttempt(
  int attempt, {
  double Function() jitter = _defaultJitter,
}) {
  if (attempt < 0) {
    throw ArgumentError.value(attempt, 'attempt', 'doit être positif ou nul');
  }

  final int shiftedAttempt = attempt > _maxShiftedAttempt
      ? _maxShiftedAttempt
      : attempt;
  final int rawBaseMs = baseDelay.inMilliseconds * (1 << shiftedAttempt);
  final int capMs = maxDelay.inMilliseconds ~/ 2;
  final int baseMs = rawBaseMs > capMs ? capMs : rawBaseMs;

  final double delayMs = baseMs + jitter() * baseMs;
  return Duration(milliseconds: delayMs.round());
}
