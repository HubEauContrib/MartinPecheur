// L'épingle du point désigné (`E1` de T2, conception § 2) : noire à halo
// blanc, une forme hors de toute famille d'échelle (ni rond plein, ni
// triangle, ni carré, ni chevron, ni badge — `04-ui.md` § 3). Elle marque le
// lieu interrogé, jamais un état de l'eau.
//
// Inerte : elle ne capte aucun tap (`IgnorePointer`) — un tap à sa position
// atteint le marqueur dessous — et n'entre pas dans l'ordre de tabulation
// (`ExcludeFocus`). Sa sémantique est exclue : le bouton et l'écran des
// restrictions disent déjà quel point est interrogé.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// Clé posée sur l'épingle, pour les tests.
const Key designatedPointPinKey = Key('designated-point-pin');

/// Hauteur et largeur de l'épingle, en pixels logiques.
const double designatedPointPinSize = 40;

/// Halo blanc : un pictogramme plus grand, blanc, sous le noir.
const double _haloSize = designatedPointPinSize;
const double _pinSize = designatedPointPinSize - 8;

/// Le pictogramme : `Icons.location_on` noir sur le même en blanc, plus
/// grand. Aucune couleur d'état d'échelle.
class DesignatedPointPin extends StatelessWidget {
  const DesignatedPointPin({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(
          child: SizedBox(
            width: designatedPointPinSize,
            height: designatedPointPinSize,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: const <Widget>[
                _Glyph(size: _haloSize, color: Colors.white),
                _Glyph(size: _pinSize, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La pointe de `Icons.location_on` est à 22/24 de la hauteur du glyphe, pas
/// au bord bas de sa boîte : sans correction, elle tomberait environ 3 px au
/// -dessus du point désigné. Le glyphe est donc descendu de 2/24 de sa taille.
const double _glyphTipInset = 2 / 24;

/// `Icons.location_on` dont la POINTE (et non le bord bas de la boîte) est
/// posée sur le bas de la boîte parente.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, size * _glyphTipInset),
    child: Icon(Icons.location_on, size: size, color: color),
  );
}

/// La couche qui pose l'épingle sur [point] : la POINTE (bas, centre) est
/// au point désigné.
MarkerLayer designatedPointLayer(GeoPoint point) => MarkerLayer(
  markers: <Marker>[
    Marker(
      point: LatLng(point.latitude, point.longitude),
      width: designatedPointPinSize,
      height: designatedPointPinSize,
      alignment: Alignment.topCenter,
      child: const DesignatedPointPin(key: designatedPointPinKey),
    ),
  ],
);
