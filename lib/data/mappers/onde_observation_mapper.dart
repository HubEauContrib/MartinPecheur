// Le mapper est le seul point de passage entre une ligne brute de
// `/ecoulement/observations` ou `/ecoulement/campagnes` et le domaine
// (BR-002). `code_campagne` est l'écart le plus coûteux de cette API : un
// entier côté `/campagnes`, une chaîne côté `/observations` (T-07). Il est
// donc lu en `Object?` et rendu en `String` sans jamais passer par un
// `as int` — un tel cast casserait sur l'une des deux formes, sans qu'aucun
// test de l'autre ne le voie. `date_observation` et `date_campagne` sont des
// dates sans heure (T-08) : aucune heure n'est inventée, la date est
// reconstruite en UTC minuit explicite à partir de ses seules composantes
// année/mois/jour. `code_ecoulement` est délégué à `flowCategoryFromCode`
// (`lib/domain/nomenclature/flow_category.dart`), jamais recopié : un code
// non reconnu devient `Inconnu`, il ne fait jamais planter l'appelant
// (C-10, BR-011).

import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Convertit une ligne brute de `/ecoulement/observations` en
/// [OndeObservation].
///
/// Lève une [FormatException] si `code_station` ou `date_observation` sont
/// absents ou illisibles, une [ArgumentError] si `code_station` est d'une
/// forme inconnue (via [OndeStationCode]). `code_ecoulement` inconnu ou
/// absent ne lève jamais : il devient [Inconnu] (BR-011).
OndeObservation mapOndeObservation(Map<String, dynamic> raw) {
  final String? rawStationCode = raw['code_station'] as String?;
  if (rawStationCode == null) {
    throw const FormatException(
      'code_station absent — la station ne peut pas être identifiée',
    );
  }
  final OndeStationCode station = OndeStationCode(rawStationCode);

  final DateTime observedAt = _dateOnly(
    raw['date_observation'],
    field: 'date_observation',
  );

  final String? rawFlowCode = raw['code_ecoulement'] as String?;
  final FlowCategory category = flowCategoryFromCode(rawFlowCode);

  return OndeObservation(
    station: station,
    observedAt: observedAt,
    category: category,
    rawFlowCode: rawFlowCode,
    officialLabel: raw['libelle_ecoulement'] as String?,
    campaignCode: _campaignCode(raw['code_campagne']),
  );
}

/// Convertit une ligne brute de `/ecoulement/campagnes` en [OndeCampaign].
///
/// Lève une [FormatException] si `code_campagne`, `date_campagne` ou
/// `libelle_type_campagne` sont absents ou illisibles — une campagne sans
/// ces informations ne peut ni être identifiée, ni datée, ni classée.
OndeCampaign mapOndeCampaign(Map<String, dynamic> raw) {
  final String? code = _campaignCode(raw['code_campagne']);
  if (code == null) {
    throw const FormatException('code_campagne absent ou illisible');
  }

  final DateTime date = _dateOnly(raw['date_campagne'], field: 'date_campagne');

  final String? rawTypeLabel = raw['libelle_type_campagne'] as String?;
  if (rawTypeLabel == null) {
    throw const FormatException('libelle_type_campagne absent');
  }

  final Object? rawModalityCount = raw['nombre_modalite_ecoulement'];
  if (rawModalityCount != null && rawModalityCount is! num) {
    throw FormatException(
      'nombre_modalite_ecoulement attendu numérique, reçu $rawModalityCount',
    );
  }
  final int? modalityCount = (rawModalityCount as num?)?.toInt();

  return OndeCampaign(
    code: code,
    date: date,
    rawTypeLabel: rawTypeLabel,
    modalityCount: modalityCount,
  );
}

/// Convertit une ligne brute de `/ecoulement/observations` en [OndePoint].
///
/// `latitude`/`longitude` sont lues à plat ; `geometry` (GeoJSON) est
/// ignorée — deux sources concordantes, une seule lue (T-09). Lève une
/// [FormatException] si `code_station`, `latitude` ou `longitude` sont
/// absents ou illisibles : un point sans coordonnées n'est pas plaçable.
/// `libelle_station` absent replie [OndePoint.label] sur le code, jamais une
/// chaîne vide (BR-007).
OndePoint mapOndePoint(Map<String, dynamic> raw) {
  final String? rawStationCode = raw['code_station'] as String?;
  if (rawStationCode == null) {
    throw const FormatException(
      'code_station absent — la station ne peut pas être identifiée',
    );
  }
  final OndeStationCode code = OndeStationCode(rawStationCode);

  final Object? rawLatitude = raw['latitude'];
  final Object? rawLongitude = raw['longitude'];
  if (rawLatitude is! num || rawLongitude is! num) {
    throw const FormatException(
      'latitude/longitude absentes ou illisibles — un point sans '
      'coordonnées n\'est pas plaçable',
    );
  }

  final String? departementRaw = raw['code_departement'] as String?;

  return OndePoint(
    code: code,
    label: (raw['libelle_station'] as String?) ?? rawStationCode,
    latitude: rawLatitude.toDouble(),
    longitude: rawLongitude.toDouble(),
    waterCourseLabel: raw['libelle_cours_eau'] as String?,
    departement: departementRaw == null
        ? null
        : DepartementCode(departementRaw),
  );
}

/// Lit `code_campagne`, rendu tantôt en entier (`/campagnes`), tantôt en
/// chaîne (`/observations`) — T-07. Aucun `as int` n'apparaît ici : le
/// contenu est distingué par son type, jamais forcé.
String? _campaignCode(Object? raw) => switch (raw) {
  null => null,
  final String value => value,
  final num value => value.toInt().toString(),
  _ => throw FormatException('code_campagne de type inattendu : $raw'),
};

/// Lit une date sans heure (`'2026-08-25'` — l'API n'en donne pas, T-08) et
/// la rend en UTC minuit explicite, construite à partir des seules
/// composantes année/mois/jour : `DateTime.parse` sur une chaîne sans fuseau
/// rend un minuit LOCAL, jamais réutilisable tel quel. Lève une
/// [FormatException] si [raw] est absent ou illisible (BR-001) — une date
/// muette ferait sinon ressortir l'observation ou la campagne comme la plus
/// récente, l'état le moins fiable.
DateTime _dateOnly(Object? raw, {required String field}) {
  if (raw is! String) {
    throw FormatException('$field absent ou illisible');
  }
  final DateTime parsed = DateTime.parse(raw);
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
