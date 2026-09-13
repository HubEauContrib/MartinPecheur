// L'écran carte (T0-M3) : le fond IGN Géoplateforme et son attribution en
// toutes lettres — une condition d'usage de la donnée sous Licence Ouverte,
// jamais une finition (`04-ui.md` § 3). Les couches sont produites par
// [buildMapLayers], une fonction PURE : rendre un `FlutterMap` dans un test
// déclenche des chargements de tuiles que l'environnement de test refuse.
// `stations` et `camera` sont ignorés ici — ils arrivent avec les marqueurs
// en M4 — mais figurent déjà dans la signature pour ne pas la changer.
//
// État par `ValueNotifier` + `ListenableBuilder` (aucune dépendance
// ajoutée) : deux notifiers, les stations chargées et la caméra courante,
// mis à jour respectivement après [loadStations] et par
// `MapOptions.onPositionChanged`.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/data/referentiel/stations_asset.dart';
import 'package:martinpecheur/features/map/ign_tile_template.dart';

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLatitude = 46.6;

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLongitude = 2.2;

/// Zoom initial — la France métropolitaine tient à l'écran.
const double initialMapZoom = 5;

/// Zoom minimal — en dessous, la France n'emplit plus l'écran.
const double minimumMapZoom = 4;

/// Zoom maximal — aligné sur le niveau natif maximal du plan IGN
/// ([ignMaxNativeZoom]) : au-delà, le serveur n'a rien à offrir de plus fin.
const double maximumMapZoom = ignMaxNativeZoom * 1.0;

/// Construit les couches de la carte, dans l'ordre où `FlutterMap` doit les
/// empiler — le fond de tuiles **premier**. Fonction pure, testable sans
/// rendu ni accès réseau.
///
/// [stations] et [camera] sont ignorés pour l'instant (T0-M3) : ils
/// alimenteront une couche de marqueurs en M4. Les garder dans la signature
/// évite de la changer à ce moment-là.
List<Widget> buildMapLayers({
  required List<StationPoint> stations,
  required MapCamera? camera,
}) {
  return <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];
}

/// Bandeau d'attribution IGN Géoplateforme, exigé par la Licence Ouverte.
/// Porte son propre fond opaque : un texte posé directement sur un fond de
/// carte quelconque ne tient aucun contraste (`04-ui.md` § 3). Sous-arbre
/// entièrement `const` — rien ici ne dépend de l'état de l'écran.
class IgnAttributionBadge extends StatelessWidget {
  const IgnAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(ignAttribution, style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// L'écran carte : fond IGN, attribution, et — à partir de M4 — les
/// marqueurs de stations dans le viewport.
class MapScreen extends StatefulWidget {
  const MapScreen({required this.loadStations, super.key});

  /// Charge le référentiel des stations. Injecté pour rester testable sans
  /// `AssetBundle` réel.
  final Future<StationsReadResult> Function() loadStations;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ValueNotifier<List<StationPoint>> _stations =
      ValueNotifier<List<StationPoint>>(<StationPoint>[]);
  final ValueNotifier<MapCamera?> _camera = ValueNotifier<MapCamera?>(null);

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final StationsReadResult result = await widget.loadStations();
    if (!mounted) {
      return;
    }
    _stations.value = result.points;
  }

  @override
  void dispose() {
    _stations.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[_stations, _camera]),
            builder: (BuildContext context, Widget? child) {
              return FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(
                    initialMapCenterLatitude,
                    initialMapCenterLongitude,
                  ),
                  initialZoom: initialMapZoom,
                  minZoom: minimumMapZoom,
                  maxZoom: maximumMapZoom,
                  onPositionChanged: (MapCamera camera, bool hasGesture) {
                    _camera.value = camera;
                  },
                ),
                children: buildMapLayers(
                  stations: _stations.value,
                  camera: _camera.value,
                ),
              );
            },
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: IgnAttributionBadge(),
            ),
          ),
        ],
      ),
    );
  }
}
