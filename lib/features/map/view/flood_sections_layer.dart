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
/// Le toucher : le code est relevé **à l'appui**. Un `Listener`
/// (`onPointerDown`) reçoit l'appui après le test de toucher de ce pointeur
/// — `GestureBinding` teste l'arbre, puis distribue l'événement — et lit
/// alors [hitNotifier] : le premier code de `hitValues`, le trait le plus
/// haut dessiné, ou rien. Le `GestureDetector` (`HitTestBehavior.deferToChild`)
/// passe ce code à [onTap] quand le toucher est tranché. Lire le notifier à
/// ce moment-là ne suffisait pas : `flutter_map` réemploie et réécrit sa
/// liste à chaque test de toucher
/// (`layer_interactivity/internal_hit_detectable.dart`), et sous Windows la
/// souris en relance un à chaque déplacement pendant l'appui (`MouseTracker`) :
/// un appui en bordure de tolérance n'ouvrait rien, ou un tronçon voisin. Le
/// code relevé vit dans une variable de cette fabrique, partagée par ses deux
/// rappels — le widget rendu est réemployé tel quel par l'appelant, aucun
/// état n'est lié à un widget. Un appui hors de tout trait le remet à `null`.
///
/// ⚠️ **Instance stable** (Review Focus 1) : cette fabrique ne garde rien
/// d'un appel à l'autre — seul le code relevé à l'appui vit, le temps d'un
/// toucher, dans le widget qu'elle rend — et rend un widget neuf à chaque
/// appel. Or `PolylineLayer` vide ses caches de
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

  FloodSectionCode? pressed;

  return Listener(
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: (PointerDownEvent event) {
      final List<FloodSectionCode> codes =
          hitNotifier.value?.hitValues ?? const <FloodSectionCode>[];
      pressed = codes.isEmpty ? null : codes.first;
    },
    child: GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () {
        final FloodSectionCode? code = pressed;
        pressed = null;
        if (code != null) {
          onTap(code);
        }
      },
      child: PolylineLayer<FloodSectionCode>(
        polylines: polylines,
        hitNotifier: hitNotifier,
        minimumHitbox: minimumTapTarget / 2,
      ),
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
