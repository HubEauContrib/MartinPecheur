// OndeCampaign et OndeObservation, dans le meme fichier (choix signale a la
// relecture : le plan laissait le decoupage libre). Les deux sont de
// classes immuables simples ; la conversion depuis l'API — code_campagne
// entier cote /campagnes, chaine cote /observations (T-07) — vit dans le
// mapper de D3, jamais ici.

import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';

/// Une campagne d'observation ONDE (une session de terrain, plusieurs
/// stations relevees le meme jour).
final class OndeCampaign {
  const OndeCampaign({
    required this.code,
    required this.date,
    required this.rawTypeLabel,
    required this.modalityCount,
  });

  /// Code de la campagne, toujours une chaine ici (T-07) — l'API le rend en
  /// entier cote `/campagnes` et en chaine cote `/observations`, le mapper
  /// absorbe cet ecart.
  final String code;

  /// Date de la campagne, sans heure : l'API n'en donne pas (T-08).
  final DateTime date;

  /// Libelle du type de campagne, tel que recu — `'usuelle'`,
  /// `'complementaire'`… La comparaison en minuscules se fait cote
  /// appelant (T-06), jamais ici.
  final String rawTypeLabel;

  /// Nombre de points observes lors de cette campagne. `null` si absent —
  /// jamais zero (BR-007).
  final int? modalityCount;
}

/// Une observation d'ecoulement ONDE, pour une station et une campagne.
final class OndeObservation {
  const OndeObservation({
    required this.station,
    required this.observedAt,
    required this.category,
    required this.rawFlowCode,
    required this.officialLabel,
    required this.campaignCode,
  });

  /// Station ONDE a l'origine de l'observation.
  final OndeStationCode station;

  /// Date de l'observation, sans heure : l'API n'en donne pas (T-08).
  final DateTime observedAt;

  /// Categorie d'ecoulement traduite depuis [rawFlowCode].
  final FlowCategory category;

  /// Le `code_ecoulement` tel que recu de l'API, jamais normalise — meme
  /// quand [category] est [Inconnu] (BR-011).
  final String? rawFlowCode;

  /// Libelle officiel de la modalite d'ecoulement, tel que recu de l'API.
  /// `null` si absent — jamais une chaine vide (BR-007).
  final String? officialLabel;

  /// Code de la campagne dont est issue cette observation. `null` si absent
  /// — jamais une chaine vide (BR-007).
  final String? campaignCode;
}
