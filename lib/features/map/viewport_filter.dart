// Le filtre de viewport, à marge proportionnelle (F2c) : en l'absence d'une
// mesure qui réhabilite le clustering (spike du 2026-09-09, jank 8,9 % pour
// un seuil < 5 %), l'approche par défaut est les marqueurs du viewport plus
// une marge, sans regroupement.
//
// La marge est proportionnelle à l'emprise, pas un nombre de degrés fixe :
// une marge fixe couvrirait la moitié de l'Europe au zoom national et rien
// du tout au zoom rue. Elle existe pour que les marqueurs soient déjà là
// quand ils entrent à l'écran, plutôt que de surgir au bord (BR-007).
//
// Dart pur : aucun `package:flutter`, `package:flutter_map` ni
// `package:latlong2`. Ce module ne connaît que des `double` et
// [StationPoint] ; le repli est testable sans aucun rendu. L'antiméridien
// n'est pas traité — hors emprise du produit (rivières françaises).

import 'package:martinpecheur/data/referentiel/stations_asset.dart';

/// Marge proportionnelle par défaut : une demi-hauteur de l'emprise ajoutée
/// en haut et en bas, une demi-largeur ajoutée de chaque côté.
const double defaultViewportMargin = 0.5;

/// Filtre [stations] à l'emprise `[north, south, east, west]`, élargie de
/// [margin] fois sa hauteur et sa largeur de chaque côté. Les bornes de
/// l'emprise élargie sont incluses. L'ordre d'origine de [stations] est
/// préservé.
///
/// [margin] est proportionnel, jamais un nombre de degrés fixe : une marge
/// fixe couvrirait la moitié de l'Europe au zoom national et rien au zoom
/// rue. Une [margin] négative lève une [ArgumentError] — elle rétrécirait
/// l'emprise, et les marqueurs disparaîtraient avant de sortir de l'écran
/// (BR-007).
///
/// L'antiméridien n'est pas traité : une emprise qui le franchit (`east` <
/// `west` une fois élargie) ne retient aucune station à l'est de `west`.
List<StationPoint> stationsWithinViewport(
  List<StationPoint> stations, {
  required double north,
  required double south,
  required double east,
  required double west,
  double margin = defaultViewportMargin,
}) {
  if (margin < 0) {
    throw ArgumentError.value(
      margin,
      'margin',
      'doit être positive ou nulle : une marge négative rétrécirait '
          "l'emprise et les marqueurs disparaîtraient avant de sortir de "
          "l'écran (BR-007)",
    );
  }

  final double height = north - south;
  final double width = east - west;
  final double expandedNorth = north + height * margin;
  final double expandedSouth = south - height * margin;
  final double expandedEast = east + width * margin;
  final double expandedWest = west - width * margin;

  return stations
      .where(
        (StationPoint station) =>
            station.latitude <= expandedNorth &&
            station.latitude >= expandedSouth &&
            station.longitude <= expandedEast &&
            station.longitude >= expandedWest,
      )
      .toList();
}
