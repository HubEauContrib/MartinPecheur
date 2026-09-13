// Implementation de StationRepository adossee au referentiel fige
// (ADR-003) : elle ne connait que les Station issues de l'asset, jamais
// le reseau. Le depot reste bete (cf. domain/repositories/repositories.dart)
// : il lit, ne decide de rien.
//
// Arbitrage 2026-09-13 : l'asset porte code_departement, libelle_cours_eau
// et en_service pour chaque entite (cf. stations_asset.dart) — une valeur
// inventee dans le domaine viole BR-007. Le depot est donc construit
// directement sur les entites Station completes, sans valeur fabriquee ni
// hypothese invérifiée. Une entite du referentiel dont le departement ou
// l'etat de service etaient absents ou mal formes a deja ete ecartee et
// comptee (`stationsSkipped`) au moment de l'analyse — ce depot ne voit que
// des entites completes.

import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Depot du referentiel des stations, adosse a l'asset fige (ADR-003).
final class AssetStationRepository implements StationRepository {
  AssetStationRepository(this._stations);

  final List<Station> _stations;

  @override
  Future<Station?> findByCode(StationCode code) async {
    for (final Station station in _stations) {
      if (station.code == code) {
        return station;
      }
    }
    return null;
  }

  @override
  Future<List<Station>> findWithinBounds(Bounds bounds) async {
    return _stations
        .where(
          (Station station) =>
              station.latitude <= bounds.north &&
              station.latitude >= bounds.south &&
              station.longitude <= bounds.east &&
              station.longitude >= bounds.west,
        )
        .toList();
  }

  @override
  Future<List<Station>> findByDepartement(DepartementCode code) async {
    return _stations
        .where((Station station) => station.departement == code)
        .toList();
  }
}
