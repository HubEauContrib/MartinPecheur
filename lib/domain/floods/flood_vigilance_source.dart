// Le port de la vigilance crues (T4). Ses echecs sont propres a ce contexte :
// ils ne partagent aucun type avec ceux des restrictions.

import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';

/// Source de la carte de vigilance crues en cours.
abstract interface class FloodVigilanceSource {
  /// La carte de vigilance en cours.
  ///
  /// Leve un [FloodVigilanceFailure], ne le rend jamais : le cache n'ecrit
  /// que ce qui est rendu, un echec rendu serait servi jusqu'a expiration.
  Future<FloodVigilanceMap> current();
}

/// Echec d'interrogation de la source, ferme a trois branches (BR-011).
sealed class FloodVigilanceFailure implements Exception {
  const FloodVigilanceFailure(this.diagnostic);

  /// Diagnostic technique, jamais affiche tel quel a l'usager.
  final String diagnostic;
}

/// La source n'a pas repondu de facon exploitable (reseau, delai, 429/5xx
/// persistant).
final class VigilanceInjoignable extends FloodVigilanceFailure {
  const VigilanceInjoignable(super.diagnostic);

  @override
  bool operator ==(Object other) =>
      other is VigilanceInjoignable && other.diagnostic == diagnostic;

  @override
  int get hashCode => diagnostic.hashCode;

  @override
  String toString() => 'VigilanceInjoignable($diagnostic)';
}

/// La source a repondu par un statut non rejouable hors succes.
final class VigilanceRefusee extends FloodVigilanceFailure {
  const VigilanceRefusee({required this.statusCode, required String diagnostic})
    : super(diagnostic);

  /// Code de statut HTTP tel que recu.
  final int statusCode;

  @override
  bool operator ==(Object other) =>
      other is VigilanceRefusee &&
      other.statusCode == statusCode &&
      other.diagnostic == diagnostic;

  @override
  int get hashCode => Object.hash(statusCode, diagnostic);

  @override
  String toString() => 'VigilanceRefusee(statusCode: $statusCode, $diagnostic)';
}

/// La reponse ne se laisse pas lire.
final class VigilanceIllisible extends FloodVigilanceFailure {
  const VigilanceIllisible(super.diagnostic);

  @override
  bool operator ==(Object other) =>
      other is VigilanceIllisible && other.diagnostic == diagnostic;

  @override
  int get hashCode => diagnostic.hashCode;

  @override
  String toString() => 'VigilanceIllisible($diagnostic)';
}
