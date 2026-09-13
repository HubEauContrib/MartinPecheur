// La couture du volet secheresse, sans aucune implementation en T0
// (ADR-004). VigiEau est en version 0.1 sur un domaine beta.gouv.fr (C-16) :
// le risque de rupture reste confine a ce module, jamais appele
// directement depuis le reste de `lib/` — un test verifie que ce
// vocabulaire n'apparait nulle part ailleurs sous `lib/`.
//
// L'interrogation se fait toujours par latitude et longitude, jamais par
// commune (C-14) : `?commune=` renvoie HTTP 409 des qu'une commune porte
// plusieurs zones. La signature ne propose donc pas de commune, pour que
// l'erreur ne redevienne jamais possible par construction.
//
// Le filtrage porte uniquement sur les eaux superficielles : les eaux
// souterraines relevent d'une autre nomenclature VigiEau, hors perimetre de
// T0. `rawSeverityLevel` est conserve brut (BR-011) : aucune interpretation
// ici, l'affichage en decidera. `decreeFilePath` pointe vers le PDF de
// l'arrete prefectoral, seul texte qui s'applique juridiquement — un niveau
// de gravite affiche sans son arrete n'engagerait a rien.

/// Une zone de restriction sur les eaux superficielles, telle que rendue par
/// VigiEau — sans aucune interpretation (BR-011).
final class SurfaceWaterRestriction {
  const SurfaceWaterRestriction({
    required this.rawSeverityLevel,
    required this.decreeFilePath,
  });

  /// Niveau de gravite tel que recu de VigiEau, jamais interprete ici
  /// (BR-011) : un niveau inedit doit traverser sans etre rabattu sur une
  /// valeur connue.
  final String rawSeverityLevel;

  /// Chemin ou URL du PDF de l'arrete prefectoral. `null` si VigiEau n'en
  /// fournit pas — le seul texte qui s'applique juridiquement reste alors
  /// inaccessible depuis l'app, ce que l'ecran doit signaler.
  final String? decreeFilePath;
}

/// Source des restrictions sur les eaux superficielles (ADR-004).
///
/// Aucune implementation en T0 : ce module pose la seule couture par
/// laquelle VigiEau pourra un jour etre appelee. Aucun client HTTP n'y vit
/// tant qu'aucune implementation n'existe.
abstract interface class RestrictionSource {
  /// Les zones de restriction sur les eaux superficielles couvrant le point
  /// ([latitude], [longitude]).
  ///
  /// Toujours par coordonnees, jamais par commune (C-14) : un appel par
  /// commune renvoie HTTP 409 des que la commune porte plusieurs zones.
  Future<List<SurfaceWaterRestriction>> surfaceWaterZonesAt({
    required double latitude,
    required double longitude,
  });
}
