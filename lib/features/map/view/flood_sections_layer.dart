// Le calque des traits de la lecture Crues (T4, M2 ; cadrage § 7.3) : un seul
// `PolylineLayer`, tous les tronçons de la carte de vigilance dans l'ordre de
// dessin du domaine, et le toucher d'un trait par `hitNotifier`.
//
// L'emprise n'y entre pas : elle ne sert qu'aux étiquettes et aux avis. Un
// calque reconstruit avec d'autres traits reprojetterait tous les points.

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_section_rules.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/features/shared/flood_level_style.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Le calque des traits de [map] : un seul `PolylineLayer<FloodSectionCode>`,
/// une `Polyline` par ligne de chaque tronçon, dans l'ordre de
/// [floodSectionsInDrawingOrder] (le plus grave dessiné au-dessus).
///
/// Chaque trait prend la teinte, l'épaisseur et le motif de son niveau
/// ([floodLevelStyle] ; pointillé pour le niveau non reconnu), un contour
/// noir de [floodContourWidth] visible de chaque côté (`borderStrokeWidth`
/// se partage entre les deux côtés, d'où le double), une tolérance de
/// toucher de la moitié de la cible ([minimumTapTarget] / 2 : un rayon, 22
/// sur Windows, 24 sur Android) et la simplification par défaut du paquet.
///
/// Le toucher : un `GestureDetector` (`HitTestBehavior.deferToChild`) lit
/// [hitNotifier] au relâcher. Une valeur `null` ne donne rien. La liste
/// `hitValues` est **copiée** avant d'en prendre le premier élément — le
/// trait le plus haut dessiné : `flutter_map` réemploie et vide cette liste
/// à chaque test de toucher, survol compris sous Windows
/// (`layer_interactivity/internal_hit_detectable.dart`). [onTap] reçoit le
/// code tel quel.
///
/// ⚠️ **Instance stable** (Review Focus 1) : cette fabrique ne garde rien et
/// rend un widget neuf à chaque appel. Or `PolylineLayer` vide ses caches de
/// projection et de simplification dans **chaque** `didUpdateWidget`
/// (`lib/src/layer/shared/layer_projection_simplification/state.dart:52-58`
/// du paquet `flutter_map` 8.3.2) : un widget neuf à chaque reconstruction de
/// la carte reprojetterait tous les points. C'est donc à l'appelant de
/// garder le widget rendu tant que [map] ne change pas, et de passer en
/// [onTap] une méthode, jamais une fermeture qui capture un état périmé.
Widget buildFloodSectionsLayer({
  required FloodVigilanceMap map,
  required LayerHitNotifier<FloodSectionCode> hitNotifier,
  required void Function(FloodSectionCode code) onTap,
}) {
  final List<Polyline<FloodSectionCode>> polylines =
      <Polyline<FloodSectionCode>>[
        for (final FloodSection section in floodSectionsInDrawingOrder(
          map.sections,
        ))
          for (final List<GeoPoint> line in section.lines)
            _polyline(section, line),
      ];

  return GestureDetector(
    behavior: HitTestBehavior.deferToChild,
    onTap: () {
      final LayerHitResult<FloodSectionCode>? hit = hitNotifier.value;
      if (hit == null) {
        return;
      }
      final List<FloodSectionCode> codes = List<FloodSectionCode>.of(
        hit.hitValues,
      );
      if (codes.isEmpty) {
        return;
      }
      onTap(codes.first);
    },
    child: PolylineLayer<FloodSectionCode>(
      polylines: polylines,
      hitNotifier: hitNotifier,
      minimumHitbox: minimumTapTarget / 2,
    ),
  );
}

Polyline<FloodSectionCode> _polyline(
  FloodSection section,
  List<GeoPoint> line,
) {
  final FloodLevelStyle style = floodLevelStyle(section.level);

  return Polyline<FloodSectionCode>(
    points: <LatLng>[
      for (final GeoPoint point in line)
        LatLng(point.latitude, point.longitude),
    ],
    color: style.tint,
    strokeWidth: style.strokeWidth,
    pattern: style.dotted
        ? const StrokePattern.dotted()
        : const StrokePattern.solid(),
    borderColor: floodContourColor,
    borderStrokeWidth: 2 * floodContourWidth,
    hitValue: section.code,
  );
}
