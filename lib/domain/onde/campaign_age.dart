// Seuil de BR-010, sans rapport avec Freshness (`lib/domain/observation/
// freshness.dart`) : une campagne ONDE est normale à trois semaines,
// l'âge s'y compte en JOURS CALENDAIRES, pas en heures — l'API ONDE ne
// donne pas d'heure sur une observation d'écoulement (T-08), et une
// campagne se compare par date, jamais par instant. Même modèle que
// freshnessOf : fonction pure, `now` en paramètre, borne appartenant à
// l'état le plus sévère.
//
// L'âge se calcule sur les composantes année/mois/jour, jamais sur
// `now.difference(observedAt).inDays` directement : cette dernière compte
// une durée absolue, qui se décale d'une heure au changement d'heure d'été
// — un couple d'instants locaux distants de 60 jours calendaires peut ne
// représenter que 59 jours 23 h 30 de durée réelle si une transition
// CET → CEST s'intercale, et `inDays` tronquerait alors à 59.

/// Age d'une campagne ONDE, calculé sur la date d'**observation**.
///
/// Affichage attendu :
/// - [recente] : aucune mention alarmante à l'écran ;
/// - [ancienne] : mention explicite de l'ancienneté de la campagne.
enum CampaignAge {
  /// Age strictement inférieur à [campagneAncienneApres].
  recente,

  /// Age supérieur ou égal à [campagneAncienneApres].
  ancienne,
}

/// Borne au-delà de laquelle une campagne cesse d'être [CampaignAge.recente].
/// La borne appartient à l'état le plus sévère : un âge de 60 jours
/// calendaires exactement est [CampaignAge.ancienne].
const Duration campagneAncienneApres = Duration(days: 60);

/// Age en jours CALENDAIRES d'une campagne observée à [observedAt], vue à
/// l'instant [now]. Fonction pure : [now] est un paramètre, jamais lu à
/// l'intérieur.
///
/// Compare les seules composantes année/mois/jour de [observedAt] et [now],
/// ramenées à minuit UTC : deux instants locaux distants de 60 jours
/// calendaires restent à 60 jours même si une transition d'heure d'été
/// s'intercale entre les deux, ce qu'un `now.difference(observedAt).inDays`
/// sur les instants bruts ne garantit pas (T-08).
///
/// Un âge négatif (observation dans le futur) n'est pas filtré ici : c'est
/// [campaignAgeOf] qui le traite comme [CampaignAge.recente], pour la même
/// raison que [freshnessOf] traite une mesure future comme fraîche.
///
/// [observedAt] et [now] doivent être exprimées dans le même fuseau ; le
/// mapper rend `observedAt` en UTC (T-08), l'appelant passe `now` en UTC.
int campaignAgeInDays({required DateTime observedAt, required DateTime now}) {
  final DateTime observedDay = DateTime.utc(
    observedAt.year,
    observedAt.month,
    observedAt.day,
  );
  final DateTime today = DateTime.utc(now.year, now.month, now.day);

  return today.difference(observedDay).inDays;
}

/// Calcule l'âge d'une campagne observée à [observedAt], vue à l'instant
/// [now]. Fonction pure : [now] est un paramètre, jamais lu à l'intérieur —
/// c'est ce qui rend la borne testable.
///
/// Un âge négatif (observation dans le futur) est une anomalie de la
/// source, pas une donnée vieille : il est traité comme [CampaignAge.recente]
/// plutôt que d'inventer un âge inconnu — même parade que [freshnessOf].
///
/// [observedAt] et [now] doivent être exprimées dans le même fuseau ; le
/// mapper rend `observedAt` en UTC (T-08), l'appelant passe `now` en UTC.
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
