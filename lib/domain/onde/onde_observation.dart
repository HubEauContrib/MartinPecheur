// OndeCampaign et OndeObservation, dans le même fichier (choix signalé à la
// relecture : le plan laissait le découpage libre). Les deux sont des
// classes immuables simples ; la conversion depuis l'API — code_campagne
// entier côté /campagnes, chaîne côté /observations (T-07) — vit dans le
// mapper de D3, jamais ici.

import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

/// Une campagne d'observation ONDE (une session de terrain, plusieurs
/// stations relevées le même jour).
final class OndeCampaign {
  const OndeCampaign({
    required this.code,
    required this.date,
    required this.rawTypeLabel,
    required this.modalityCount,
  });

  /// Code de la campagne, toujours une chaîne ici (T-07) — l'API le rend en
  /// entier côté `/campagnes` et en chaîne côté `/observations`, le mapper
  /// absorbe cet écart.
  final String code;

  /// Date de la campagne, sans heure : l'API n'en donne pas (T-08).
  final DateTime date;

  /// Libellé du type de campagne, tel que reçu — `'usuelle'`,
  /// `'complémentaire'`… La comparaison en minuscules se fait côté
  /// appelant (T-06), jamais ici.
  final String rawTypeLabel;

  /// Nombre de modalités de l'échelle d'écoulement observées lors de cette
  /// campagne (`nombre_modalite_ecoulement` — 4 ou 5 selon les campagnes de
  /// la fixture réelle), **pas** un nombre de points ni de stations. `null`
  /// si absent.
  final int? modalityCount;
}

/// Une observation d'écoulement ONDE, pour une station et une campagne.
final class OndeObservation {
  const OndeObservation({
    required this.station,
    required this.point,
    required this.observedAt,
    required this.category,
    required this.rawFlowCode,
    required this.officialLabel,
    required this.campaignCode,
  });

  /// Station ONDE à l'origine de l'observation.
  final OndeStationCode station;

  /// Le point observé, lu sur la même ligne d'API que l'observation (T-09) ;
  /// c'est ce qui permet à la carte de placer l'observation et à la fiche
  /// d'afficher le libellé sans second appel (D8).
  final OndePoint point;

  /// Date de l'observation, sans heure : l'API n'en donne pas (T-08).
  final DateTime observedAt;

  /// Catégorie d'écoulement traduite depuis [rawFlowCode].
  final FlowCategory category;

  /// Le `code_ecoulement` tel que reçu de l'API, jamais normalisé, à
  /// l'exception de la chaîne vide vue comme une absence (BR-007) — même
  /// quand [category] est [Inconnu] (BR-011).
  final String? rawFlowCode;

  /// Libellé officiel de la modalité d'écoulement, tel que reçu de l'API.
  /// `null` si absent — jamais une chaîne vide (BR-007).
  final String? officialLabel;

  /// Code de la campagne dont est issue cette observation. `null` si absent
  /// — jamais une chaîne vide (BR-007).
  final String? campaignCode;
}
