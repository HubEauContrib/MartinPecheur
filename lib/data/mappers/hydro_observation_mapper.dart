// Le mapper est le seul point de passage entre une ligne brute de
// `observations_tr` et le domaine (BR-002) : la division par mille est
// deleguee a `domain/units/conversions.dart`, aucun facteur numerique
// n'apparait ici. Une date illisible ou absente leve a la frontiere (BR-001) —
// sinon l'observation ressortirait en fraiche, l'etat le moins severe, ce
// qui est pire qu'un plantage explicite. `code_station` absent leve aussi :
// c'est la signature du doublon par code site (C-05), pas une absence a
// accepter en silence. `resultat_obs` est lu en `num` puis converti en
// `double` : l'API rend tantot `47800`, tantot `47800.0`.

import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/conversions.dart';
import 'package:martinpecheur/domain/units/quantities.dart';

/// Convertit une ligne brute de `observations_tr` en [HydroObservation].
///
/// Seul point de passage entre l'API et le domaine (BR-002) : la conversion
/// d'unite est deleguee a `conversions.dart`, jamais recopiee ici. Leve une
/// [FormatException] si `code_station` ou `date_obs` sont absents ou
/// illisibles, une [ArgumentError] si `code_station` est d'une forme
/// inconnue (C-05, via [StationCode]). Une grandeur non reconnue range sa
/// value nulle part plutot que de la mal etiqueter (BR-011).
HydroObservation mapHydroObservation(Map<String, dynamic> raw) {
  final String? rawStationCode = raw['code_station'] as String?;
  if (rawStationCode == null) {
    throw const FormatException(
      'code_station absent — un code site renverrait un doublon (C-05)',
    );
  }
  final StationCode station = StationCode(rawStationCode);

  final DateTime measuredAt = _measuredAt(raw['date_obs']);
  final Grandeur grandeur = grandeurFromCode(raw['grandeur_hydro'] as String?);

  final Object? rawResult = raw['resultat_obs'];
  if (rawResult != null && rawResult is! num) {
    throw FormatException('resultat_obs attendu numerique, recu ', rawResult);
  }
  final double? value = (rawResult as num?)?.toDouble();

  final (CubicMetresPerSecond? discharge, Metres? level) = switch (grandeur) {
    Grandeur.debit => (
      toCubicMetresPerSecond(value == null ? null : LitresPerSecond(value)),
      null,
    ),
    Grandeur.hauteur => (
      null,
      toMetres(value == null ? null : Millimetres(value)),
    ),
    Grandeur.inconnu => (null, null),
  };

  final Qualification qualification = Qualification(
    statusCode: raw['code_statut'] as int?,
    statusLabel: raw['libelle_statut'] as String?,
    qualificationCode: raw['code_qualification_obs'] as int?,
    qualificationLabel: raw['libelle_qualification_obs'] as String?,
  );

  return HydroObservation(
    station: station,
    measuredAt: measuredAt,
    grandeur: grandeur,
    discharge: discharge,
    level: level,
    qualification: qualification,
  );
}

/// Lit et parse `date_obs`. Leve une [FormatException] si [raw] est absent
/// ou n'est pas une date lisible (BR-001) : une date illisible ressortirait
/// sinon en observation fraiche, l'etat le moins severe. `measuredAt` est
/// toujours renvoyee en UTC.
DateTime _measuredAt(Object? raw) {
  if (raw is! String) {
    throw const FormatException('date_obs absente ou illisible');
  }
  return DateTime.parse(raw).toUtc();
}
