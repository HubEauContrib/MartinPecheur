// Regles pures des troncons (T4) : etiquette ou non, appartenance a l'emprise,
// ancre de l'etiquette, ordre de dessin et ordre de tabulation des etiquettes.
//
// Dart pur. Tout se fait par les segments du trace (arbitrage 11) : un trait
// qui traverse l'ecran sans qu'aucun de ses sommets y soit est dans le
// secteur. Le seuil de zoom n'est pas ici : l'appelant dit `individualLevel`.

import 'dart:math' as math;

import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// Un troncon porte-t-il une etiquette ? Tout troncon non vert ou de niveau
/// non reconnu, a tout zoom ; un vert seulement au niveau individuel.
bool floodSectionLabelled(
  FloodSection section, {
  required bool individualLevel,
}) => switch (section.level) {
  Vert() => individualLevel,
  Jaune() => true,
  Orange() => true,
  Rouge() => true,
  NiveauCruesInconnu() => true,
};

/// Un troncon touche l'emprise si l'un de ses segments la coupe, bords inclus.
bool floodSectionTouches(FloodSection section, Bounds bounds) {
  for (final List<GeoPoint> line in section.lines) {
    for (int i = 0; i < line.length - 1; i++) {
      if (_clip(line[i], line[i + 1], bounds) != null) {
        return true;
      }
    }
  }

  return false;
}

/// Le point du trait visible le plus proche du centre de l'emprise, ou `null`
/// si aucun segment n'entre dans l'emprise.
///
/// Distance au carre en degres. Egalite : le premier dans l'ordre des lignes
/// puis des segments.
GeoPoint? floodLabelAnchor(FloodSection section, Bounds bounds) {
  final double centerLon = (bounds.west + bounds.east) / 2;
  final double centerLat = (bounds.south + bounds.north) / 2;
  GeoPoint? best;
  double bestDistance = double.infinity;

  for (final List<GeoPoint> line in section.lines) {
    for (int i = 0; i < line.length - 1; i++) {
      final ({double lon0, double lat0, double lon1, double lat1})? piece =
          _clip(line[i], line[i + 1], bounds);
      if (piece == null) {
        continue;
      }
      final double dLon = piece.lon1 - piece.lon0;
      final double dLat = piece.lat1 - piece.lat0;
      final double lengthSquared = dLon * dLon + dLat * dLat;
      double t = 0;
      if (lengthSquared > 0) {
        t =
            ((centerLon - piece.lon0) * dLon +
                (centerLat - piece.lat0) * dLat) /
            lengthSquared;
        t = math.min(1, math.max(0, t));
      }
      // Le recadrage garde le point dans l'emprise malgre l'arrondi.
      final double lon = math.min(
        bounds.east,
        math.max(bounds.west, piece.lon0 + t * dLon),
      );
      final double lat = math.min(
        bounds.north,
        math.max(bounds.south, piece.lat0 + t * dLat),
      );
      final double distance = _squaredDegrees(lat, lon, centerLat, centerLon);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = GeoPoint(latitude: lat, longitude: lon);
      }
    }
  }

  return best;
}

/// Les troncons du moins grave au plus grave : le plus grave est dessine
/// au-dessus. Tri stable ; liste non modifiable.
List<FloodSection> floodSectionsInDrawingOrder(
  Iterable<FloodSection> sections,
) {
  final List<(int, FloodSection)> indexed = <(int, FloodSection)>[
    for (final (int index, FloodSection s) in sections.indexed) (index, s),
  ];
  indexed.sort(((int, FloodSection) a, (int, FloodSection) b) {
    final int byRank = floodDrawingRank(a.$2.level)
        .compareTo(floodDrawingRank(b.$2.level));

    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });

  return List<FloodSection>.unmodifiable(
    indexed.map(((int, FloodSection) e) => e.$2),
  );
}

/// Les troncons etiquetes qui ont une ancre dans l'emprise, avec cette ancre,
/// dans l'ordre de tabulation : distance de l'ancre au centre croissante,
/// puis code. Liste non modifiable.
List<(FloodSection, GeoPoint)> floodLabelsFor(
  Iterable<FloodSection> sections,
  Bounds bounds, {
  required bool individualLevel,
}) {
  final double centerLon = (bounds.west + bounds.east) / 2;
  final double centerLat = (bounds.south + bounds.north) / 2;
  final List<(FloodSection, GeoPoint, double)> found =
      <(FloodSection, GeoPoint, double)>[];

  for (final FloodSection section in sections) {
    if (!floodSectionLabelled(section, individualLevel: individualLevel)) {
      continue;
    }
    final GeoPoint? anchor = floodLabelAnchor(section, bounds);
    if (anchor == null) {
      continue;
    }
    found.add((
      section,
      anchor,
      _squaredDegrees(anchor.latitude, anchor.longitude, centerLat, centerLon),
    ));
  }
  found.sort((
    (FloodSection, GeoPoint, double) a,
    (FloodSection, GeoPoint, double) b,
  ) {
    final int byDistance = a.$3.compareTo(b.$3);

    return byDistance != 0
        ? byDistance
        : a.$1.code.value.compareTo(b.$1.code.value);
  });

  return List<(FloodSection, GeoPoint)>.unmodifiable(
    found.map(((FloodSection, GeoPoint, double) e) => (e.$1, e.$2)),
  );
}

double _squaredDegrees(double lat, double lon, double toLat, double toLon) {
  final double deltaLatitude = lat - toLat;
  final double deltaLongitude = lon - toLon;

  return deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude;
}

/// Decoupe le segment [a]-[b] par l'emprise (Liang-Barsky, bornes incluses)
/// dans le plan (longitude, latitude). `null` si le segment ne la coupe pas.
({double lon0, double lat0, double lon1, double lat1})? _clip(
  GeoPoint a,
  GeoPoint b,
  Bounds bounds,
) {
  final double dLon = b.longitude - a.longitude;
  final double dLat = b.latitude - a.latitude;
  double t0 = 0;
  double t1 = 1;

  // Pour chaque bord : p = deplacement vers l'exterieur, q = marge restante.
  bool keeps(double p, double q) {
    if (p == 0) {
      return q >= 0;
    }
    final double r = q / p;
    if (p < 0) {
      if (r > t1) {
        return false;
      }
      t0 = math.max(t0, r);
    } else {
      if (r < t0) {
        return false;
      }
      t1 = math.min(t1, r);
    }

    return true;
  }

  if (!keeps(-dLon, a.longitude - bounds.west) ||
      !keeps(dLon, bounds.east - a.longitude) ||
      !keeps(-dLat, a.latitude - bounds.south) ||
      !keeps(dLat, bounds.north - a.latitude)) {
    return null;
  }

  return (
    lon0: a.longitude + t0 * dLon,
    lat0: a.latitude + t0 * dLat,
    lon1: a.longitude + t1 * dLon,
    lat1: a.latitude + t1 * dLat,
  );
}
