// Le filtre de viewport, à marge proportionnelle (F2c) : en l'absence d'une
// mesure qui réhabilite le clustering (spike du 2026-09-09, jank 8,9 % pour
// un seuil < 5 %), l'approche par défaut est les marqueurs du viewport plus
// une marge, sans regroupement.
//
// La marge est proportionnelle à l'emprise, pas un nombre de degrés fixe :
// une marge fixe couvrirait la moitié de l'Europe au zoom national et rien
// du tout au zoom rue. Depuis la relecture M3/M4 (2026-09-13), la requête
// d'emprise ne part qu'au relâcher d'un geste (`features/map/view/`,
// `shouldRefreshOn`), jamais à chaque frame d'un geste en cours : la marge
// sert précisément à ce que les marqueurs déjà chargés couvrent le
// déplacement jusqu'au relâcher suivant, plutôt que de les faire surgir au
// bord une fois la requête suivante revenue (BR-007).
//
// Dart pur : aucun `package:flutter`, `package:flutter_map` ni
// `package:latlong2`. Ce module ne connaît que des `double` et
// [StationPoint] ; le repli est testable sans aucun rendu. L'antiméridien
// n'est pas traité — hors emprise du produit (rivières françaises).
//
// Rangé sous `lib/domain/geo/` depuis R2 (arbitrage 2026-09-13) : c'est un
// calcul pur sur des `double`, il ne connaît ni carte ni asset, et la
// tranche carte n'est plus la seule à pouvoir s'en servir — un dépôt de
// points l'applique désormais côté données.

import 'package:martinpecheur/domain/station/station_point.dart';

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
/// Une emprise inversée (`north` <= `south`, ou `east` <= `west`) lève aussi
/// une [ArgumentError] : sans ce contrôle, elle ne rendrait aucune station,
/// en silence — un faux négatif que l'écran présenterait comme « aucune
/// station », alors que c'est l'emprise passée qui est invalide (BR-007).
/// C'est la même règle que `Bounds` (`lib/domain/repositories/repositories.dart`)
/// applique à la construction ; ce module ne reçoit pas de `Bounds` et la
/// revalide donc lui-même.
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
  if (north <= south) {
    throw ArgumentError.value(
      north,
      'north',
      'doit être strictement supérieur à south ($south) : une emprise '
          'inversée rendrait une liste vide en silence (BR-007)',
    );
  }
  if (east <= west) {
    throw ArgumentError.value(
      east,
      'east',
      'doit être strictement supérieur à west ($west) : une emprise '
          'inversée rendrait une liste vide en silence (BR-007)',
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
