// Les depots restent betes : ils lisent, ils n'orchestrent pas, et ils ne
// decident pas de la politique de cache — cela reste au seul decorateur
// CachePolicy (`lib/data/cache/cache_policy.dart`). Un widget n'appelle
// jamais un depot : il passe par le ViewModel de sa tranche, qui appelle le
// depot directement et de facon typee (R3/R4, arbitrage 2026-09-13 —
// ADR-014 remplace le volet CQRS leger d'ADR-008).
//
// Bounds ne vit plus ici mais dans `lib/domain/geo/bounds.dart` (relecture du
// 2026-09-13) : la vue en construit une a chaque relachement de geste, et elle
// n'a pas a importer les contrats de depot pour cela.

import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Depot du referentiel des stations. Lit, ne decide de rien : ni cache, ni
/// orchestration.
///
/// Une seule methode, et elle suffit (YAGNI) : `findWithinBounds` et
/// `findByDepartement` ont ete retirees a la relecture du 2026-09-13 — rien
/// ne les appelait. La carte passe par [StationPointRepository] ; un filtre
/// par departement viendra avec l'ecran qui le demande, pas avant.
abstract interface class StationRepository {
  /// La station de code [code], ou `null` si aucune station ne porte ce
  /// code (BR-007) — jamais une erreur pour une absence attendue. Premier
  /// appelant : la fiche station (T1).
  Future<Station?> findByCode(StationCode code);
}

/// Depot des points de carte du referentiel : la projection [StationPoint],
/// pas l'entite [Station] complete.
///
/// Un depot a lui seul, et non une methode de plus sur [StationRepository]
/// (R3, arbitrage 2026-09-13) : c'est une segregation d'interface (le `I` de
/// SOLID). La carte n'a besoin que de code, libelle et coordonnees, et la
/// marge d'emprise n'a de sens que pour elle — la fiche station, qui lit une
/// [Station] complete par son code, n'a rien a faire d'une emprise elargie
/// et ne doit pas dependre d'une methode qu'elle n'appelle jamais.
abstract interface class StationPointRepository {
  /// Les points dont les coordonnees tombent dans [bounds], elargie de
  /// [margin] fois sa hauteur et sa largeur de chaque cote.
  ///
  /// [margin] est proportionnel, jamais un nombre de degres fixe (voir
  /// `stationsWithinViewport`) : c'est le seul endroit ou la marge par
  /// defaut est nommee dans un contrat de depot. Une liste vide est une
  /// absence, jamais une erreur (BR-007).
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  });
}

/// Depot des observations hydrometriques. Lit la derniere observation
/// connue, ne calcule ni fraicheur ni conversion — deja faites en amont
/// (mapper, BR-002).
abstract interface class HydroObservationRepository {
  /// La derniere observation connue pour [station] et [grandeur].
  /// [grandeur] est obligatoire : une hauteur et un debit ne sont jamais
  /// confondus.
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur);
}
