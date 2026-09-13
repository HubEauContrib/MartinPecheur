import 'package:flutter/material.dart';
import 'package:martinpecheur/application/bus.dart';
import 'package:martinpecheur/application/handlers.dart';
import 'package:martinpecheur/data/referentiel/asset_station_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/map/map_screen.dart';

// Le référentiel est chargé une fois, avant `runApp` : c'est ici, et nulle
// part ailleurs, que le dépôt est câblé au gestionnaire puis au registre
// (invariant d'architecture, arbitrage 2026-09-13) — l'écran, lui, n'appelle
// jamais le dépôt, il envoie une requête au bus.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final StationsReadResult referentiel = await loadStationsFromAsset();
  final StationRepository stationRepository = AssetStationRepository(
    referentiel.points,
  );
  final Bus bus = Bus();
  registerHandlers(
    bus,
    stationRepository: stationRepository,
    stationPoints: referentiel.points,
  );

  runApp(MartinPecheurApp(bus: bus));
}

// L'écran carte (T0-M4) : fond IGN, attribution, et les stations en
// marqueurs du viewport élargi. Aucun des quatre avertissements (`BR-012`,
// `BR-013`) n'est encore posé — ils arrivent en T1, avant toute mise en
// production.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({required this.bus, super.key});

  /// Le registre de messages, câblé dans [main] : dépôt → gestionnaire →
  /// registre → écran.
  final Bus bus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      home: MapScreen(bus: bus),
    );
  }
}
