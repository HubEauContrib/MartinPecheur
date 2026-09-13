// Implementation de StationRepository adossee au referentiel fige
// (ADR-003) : elle ne connait que les StationPoint issus de l'asset, jamais
// le reseau. Le depot reste bete (cf. domain/repositories/repositories.dart)
// : il lit, ne decide de rien.
//
// ⚠️ Ecart connu, documente plutot que fabrique en silence : StationPoint
// (assets/referentiel/stations.json) ne porte ni departement, ni cours
// d'eau, ni etat de service — seuls code, libelle et coordonnees y figurent
// (cf. stations_asset.dart). Or Station (entite domaine complete) exige un
// DepartementCode non nul. findByCode et findWithinBounds renvoient donc des
// Station dont le departement est une valeur SENTINELLE ('00', qui ne
// designe aucun departement francais reel — la numerotation commence a 01) :
// jamais une valeur plausible qui pourrait passer pour une vraie donnee.
// riverLabel reste `null` (une absence honnete, BR-007). inService vaut
// `true` sous l'hypothese non verifiee que le referentiel hydrometrie ne
// liste que des stations en service — hypothese a confirmer par appel reel
// avant tout usage qui en depend (regle d'anti-hallucination, CLAUDE.md).
// findByDepartement, lui, ne PEUT pas filtrer sans departement : il leve un
// UnimplementedError plutot que de fabriquer un resultat vide qui se
// confondrait avec une absence reelle (BR-007) — a lever en T1 quand le
// referentiel sera enrichi.

import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/features/map/viewport_filter.dart';

/// Departement sentinelle utilise pour les Station composees depuis un
/// StationPoint : aucun departement francais ne porte ce code (la
/// numerotation commence a 01), donc jamais confondu avec une vraie donnee.
/// A retirer en T1 quand le referentiel portera le departement.
final DepartementCode sentinelDepartementInconnu = DepartementCode('00');

/// Depot du referentiel des stations, adosse a l'asset fige (ADR-003).
final class AssetStationRepository implements StationRepository {
  AssetStationRepository(this._points);

  final List<StationPoint> _points;

  @override
  Future<Station?> findByCode(StationCode code) async {
    for (final StationPoint point in _points) {
      if (point.code == code) {
        return _toStation(point);
      }
    }
    return null;
  }

  @override
  Future<List<Station>> findWithinBounds(Bounds bounds) async {
    final List<StationPoint> withinBounds = stationsWithinViewport(
      _points,
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
    );
    return withinBounds.map(_toStation).toList();
  }

  @override
  Future<List<Station>> findByDepartement(DepartementCode code) async {
    throw UnimplementedError(
      'T1 : StationPoint (referentiel fige) ne porte pas le departement — '
      'impossible de filtrer sans enrichir le referentiel ou composer avec '
      'une source complementaire.',
    );
  }

  Station _toStation(StationPoint point) => Station(
    code: point.code,
    label: point.label,
    latitude: point.latitude,
    longitude: point.longitude,
    departement: sentinelDepartementInconnu,
    riverLabel: null,
    inService: true,
  );
}
