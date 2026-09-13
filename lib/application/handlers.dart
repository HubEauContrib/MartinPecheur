// Le registre explicite de gestionnaires (Bus, cf. bus.dart) n'a besoin
// d'aucune bibliotheque de mediateur : une fonction qui enregistre chaque
// gestionnaire suffit (cf. CLAUDE.md § Architecture). Un fichier par
// gestionnaire aurait ete aussi defendable ; ce choix reste au plus simple
// tant que T0 n'en compte que deux.
//
// StationsWithinBoundsQuery est adossee a [StationRepository] (le depot
// lu depuis l'asset, cf. AssetStationRepository) : c'est le chemin general,
// pour tout futur appelant qui a besoin de la Station entiere (fiche
// station, T1). StationPointsWithinBoundsQuery, elle, ne passe PAS par
// StationRepository : elle filtre directement [stationPoints], la
// projection carte deja chargee au demarrage — la carte n'a besoin que de
// StationPoint, et repasser par Station puis reconvertir a chaque geste de
// camera serait une allocation inutile pour 4 150 stations (arbitrage
// T0-M4, cf. messages.dart).
//
// La dépendance application → features/map (viewport_filter) a disparu en
// R2 : le filtre est rangé sous `lib/domain/geo/`, un calcul pur sur des
// `double` que n'importe quelle couche peut appeler sans traverser une
// tranche de fonctionnalité.

import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/messages.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Enregistre sur [bus] les gestionnaires connus de T0 : [stationRepository]
/// repond a [StationsWithinBoundsQuery], [stationPoints] (le referentiel
/// deja charge) repond directement a [StationPointsWithinBoundsQuery].
void registerHandlers(
  Bus bus, {
  required StationRepository stationRepository,
  required List<StationPoint> stationPoints,
}) {
  bus.register<StationsWithinBoundsQuery, List<Station>>(
    (StationsWithinBoundsQuery query) =>
        stationRepository.findWithinBounds(query.bounds),
  );

  bus.register<StationPointsWithinBoundsQuery, List<StationPoint>>(
    (StationPointsWithinBoundsQuery query) async => stationsWithinViewport(
      stationPoints,
      north: query.bounds.north,
      south: query.bounds.south,
      east: query.bounds.east,
      west: query.bounds.west,
    ),
  );
}
