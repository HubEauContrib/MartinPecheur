// Implementation de StationPointRepository adossee au referentiel fige
// (ADR-003) : les 4 150 points sont lus une fois au demarrage
// (`stations_asset_loader.dart`), ce depot ne fait que les filtrer a
// l'emprise demandee. Aucun reseau, aucune politique de cache — le depot
// reste bete (cf. domain/repositories/repositories.dart).
//
// Il remplace le gestionnaire `StationPointsWithinBoundsQuery` de T0 (R3/R4,
// arbitrage 2026-09-13) : le ViewModel de la carte l'appelle directement et
// de facon typee, au lieu d'envoyer un message a un registre qui perdait le
// type a l'envoi. Le calcul lui-meme n'a pas bouge d'un caractere : c'est
// `stationsWithinViewport` (`lib/domain/geo/viewport_filter.dart`), et il
// n'est recopie nulle part.

import 'package:martinpecheur/domain/geo/viewport_filter.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Depot des points de carte, adosse a l'asset fige (ADR-003).
final class AssetStationPointRepository implements StationPointRepository {
  AssetStationPointRepository(this._points);

  final List<StationPoint> _points;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    return stationsWithinViewport(
      _points,
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
      margin: margin,
    );
  }
}
