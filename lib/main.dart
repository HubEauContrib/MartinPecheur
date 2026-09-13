import 'package:flutter/material.dart';
import 'package:martinpecheur/data/referentiel/asset_station_point_repository.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/data/referentiel/stations_asset_loader.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

// La racine de composition, et elle seule (MVVM, ADR-014, arbitrage
// 2026-09-13) : asset → dépôt → ViewModel → vue. Aucune bibliothèque
// d'injection — un câblage explicite se lit de haut en bas et ne cache aucune
// résolution à l'exécution.
//
// Le référentiel est chargé une fois, avant `runApp`. La vue n'appelle jamais
// un dépôt : elle observe son ViewModel, qui appelle le dépôt directement et
// de façon typée.
//
// `AssetStationRepository` (le dépôt des entités `Station` complètes) n'est
// délibérément pas câblé ici : aucun écran ne le consomme encore. Son premier
// appelant sera la fiche station (T1) ; le câbler d'avance mettrait dans la
// racine de composition un objet que rien ne lit.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final StationsReadResult referentiel = await loadStationsFromAsset();
  final StationPointRepository stationPoints = AssetStationPointRepository(
    referentiel.points,
  );

  runApp(MartinPecheurApp(mapViewModel: MapViewModel(stationPoints)));
}

// L'écran carte (T0-M4) : fond IGN, attribution, et les stations en
// marqueurs du viewport élargi. Aucun des quatre avertissements (`BR-012`,
// `BR-013`) n'est encore posé — ils arrivent en T1, avant toute mise en
// production.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({required this.mapViewModel, super.key});

  /// Le ViewModel de la tranche carte, construit dans [main]. C'est cette
  /// racine qui le possède : il vit aussi longtemps que l'application, et la
  /// vue ne dispose pas un objet dont elle n'est pas propriétaire.
  final MapViewModel mapViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MartinPêcheur',
      home: MapView(viewModel: mapViewModel),
    );
  }
}
