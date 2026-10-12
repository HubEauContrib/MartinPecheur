// Les prédicats du filtre de la carte (T3), fonctions pures. Règle commune :
// un filtre ne masque que ce qui est **connu** comme hors critère. Un lieu
// sans rattachement, une station non chargée, en échec ou sans donnée restent
// affichés (cadrage de T3, § 6.3).
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Dit si [departement] reste affiché. Le département se compare par code
/// exact : les libellés de l'asset et de l'API n'ont pas la même casse.
/// Sans rattachement (`null`), le lieu est gardé.
bool filterKeepsDepartement(MapFilter filter, AdministrativeArea? departement) {
  final String? wanted = filter.departementCode;
  if (wanted == null || departement == null) {
    return true;
  }
  return departement.code == wanted;
}

/// Département puis catégorie d'écoulement d'une observation ONDE.
bool filterKeepsOndeObservation(
  MapFilter filter,
  OndeObservation observation,
) =>
    filterKeepsDepartement(filter, observation.point.departement) &&
    filter.shows(observation.category);

/// Département seul : c'est la règle des pastilles et du préchargement sur le
/// débit, où la fraîcheur n'est pas encore connue.
bool filterKeepsStationPoint(MapFilter filter, StationPoint station) =>
    filterKeepsDepartement(filter, station.departement);

/// Département, puis fraîcheur. Seule une mesure chargée peut être masquée par
/// le critère de fraîcheur ; `switch` exhaustif sans `default` (`BR-011`).
bool filterKeepsStation(
  MapFilter filter,
  StationPoint station,
  StationMapState state,
) {
  if (!filterKeepsDepartement(filter, station.departement)) {
    return false;
  }
  return switch (state) {
    NonChargee() => true,
    EnEchec() => true,
    SansDonnee() => true,
    Chargee(:final freshness) => dischargeFreshnessAdmits(
      filter.dischargeFreshness,
      freshness,
    ),
  };
}

/// Départements distincts par code, triés par code croissant, libellé du
/// premier rencontré ; les stations sans département sont ignorées. Liste non
/// modifiable.
List<AdministrativeArea> departementsOf(Iterable<StationPoint> stations) {
  final Map<String, AdministrativeArea> byCode = <String, AdministrativeArea>{};
  for (final StationPoint station in stations) {
    final AdministrativeArea? departement = station.departement;
    if (departement != null) {
      byCode.putIfAbsent(departement.code, () => departement);
    }
  }
  final List<String> codes = byCode.keys.toList()..sort();
  return List<AdministrativeArea>.unmodifiable(<AdministrativeArea>[
    for (final String code in codes) byCode[code]!,
  ]);
}
