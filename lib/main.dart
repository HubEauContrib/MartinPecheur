import 'package:flutter/material.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/features/map/map_screen.dart';

void main() {
  runApp(const MartinPecheurApp());
}

// L'écran carte (T0-M3) : fond IGN et attribution. Aucun des quatre
// avertissements (`BR-012`, `BR-013`) n'est encore posé — ils arrivent en
// T1, avant toute mise en production.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      home: MapScreen(loadStations: loadStationsFromAsset),
    );
  }
}
