// Seuil de BR-010, sans rapport avec Freshness (`lib/domain/observation/
// freshness.dart`) : une campagne ONDE est normale a trois semaines,
// l'age s'y compte en JOURS entiers, pas en heures — l'API ne donne pas
// d'heure sur une observation d'ecoulement (T-08). Meme modele que
// freshnessOf : fonction pure, `now` en parametre, borne appartenant a
// l'etat le plus severe.

/// Age d'une campagne ONDE, calcule sur la date d'**observation**.
///
/// Affichage attendu :
/// - [recente] : aucune mention alarmante a l'ecran ;
/// - [ancienne] : mention explicite de l'anciennete de la campagne.
enum CampaignAge {
  /// Age strictement inferieur a [campagneAncienneApres].
  recente,

  /// Age superieur ou egal a [campagneAncienneApres].
  ancienne,
}

/// Borne au-dela de laquelle une campagne cesse d'etre [CampaignAge.recente].
/// La borne appartient a l'etat le plus severe : un age de 60 jours
/// exactement est [CampaignAge.ancienne].
const Duration campagneAncienneApres = Duration(days: 60);

/// Age en jours entiers d'une campagne observee a [observedAt], vu a
/// l'instant [now]. Fonction pure : [now] est un parametre, jamais lu a
/// l'interieur.
///
/// Un age negatif (observation dans le futur) n'est pas filtre ici : c'est
/// [campaignAgeOf] qui le traite comme [CampaignAge.recente], pour la meme
/// raison que [freshnessOf] traite une mesure future comme fraiche.
int campaignAgeInDays({required DateTime observedAt, required DateTime now}) =>
    now.difference(observedAt).inDays;

/// Calcule l'age d'une campagne observee a [observedAt], vue a l'instant
/// [now]. Fonction pure : [now] est un parametre, jamais lu a l'interieur —
/// c'est ce qui rend la borne testable.
///
/// Un age negatif (observation dans le futur) est une anomalie de la
/// source, pas une donnee vieille : il est traite comme [CampaignAge.recente]
/// plutot que d'inventer un age inconnu — meme parade que [freshnessOf].
CampaignAge campaignAgeOf({
  required DateTime observedAt,
  required DateTime now,
}) {
  final int ageInDays = campaignAgeInDays(observedAt: observedAt, now: now);

  if (ageInDays >= campagneAncienneApres.inDays) {
    return CampaignAge.ancienne;
  }
  return CampaignAge.recente;
}
