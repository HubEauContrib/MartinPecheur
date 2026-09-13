// Seuils absolus de BR-005, sans rapport avec un TTL de cache : les
// confondre déclarerait périmée une observation de quarante minutes.
// Ne s'applique pas aux observations d'écoulement, où une campagne de trois
// semaines est normale (BR-010).

/// État de fraîcheur d'une observation hydrométrique, calculé sur la date de
/// **mesure** — jamais de récupération (`BR-001`) : une donnée fraîchement
/// téléchargée peut avoir dix-sept jours.
///
/// Affichage attendu :
/// - [fraiche] : aucune mention à l'écran ;
/// - [ancienne] : « il y a N h » ;
/// - [perimee] : marqueur atténué **et** avertissement explicite.
enum Freshness {
  /// Âge strictement inférieur à [ancienneApres].
  fraiche,

  /// Âge dans `[ancienneApres, perimeeApres)`.
  ancienne,

  /// Âge supérieur ou égal à [perimeeApres].
  perimee,
}

/// Borne au-delà de laquelle une observation cesse d'être [Freshness.fraiche].
/// La borne appartient à l'état le plus sévère : un âge de 2 h exactement est
/// [Freshness.ancienne].
const Duration ancienneApres = Duration(hours: 2);

/// Borne au-delà de laquelle une observation devient [Freshness.perimee].
/// La borne appartient à l'état le plus sévère : un âge de 24 h exactement
/// est [Freshness.perimee].
const Duration perimeeApres = Duration(hours: 24);

/// Calcule la fraîcheur d'une observation mesurée à [measuredAt], vue à
/// l'instant [now]. Fonction pure : [now] est un paramètre, jamais lu à
/// l'intérieur — c'est ce qui rend les bornes testables.
///
/// Un âge négatif (mesure dans le futur) est une anomalie de la source, pas
/// une donnée vieille : il est traité comme [Freshness.fraiche] plutôt que
/// d'inventer un âge inconnu.
///
/// `now.difference(measuredAt)` compare des instants absolus : la
/// comparaison reste correcte que l'une ou l'autre des deux dates soit
/// exprimée en UTC ou en heure locale, sans conversion préalable.
Freshness freshnessOf({required DateTime measuredAt, required DateTime now}) {
  final Duration age = now.difference(measuredAt);

  if (age < ancienneApres) {
    return Freshness.fraiche;
  }
  if (age < perimeeApres) {
    return Freshness.ancienne;
  }
  return Freshness.perimee;
}
