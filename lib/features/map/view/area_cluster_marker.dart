// La pastille d'un agrégat de zone administrative (`ADR-015`, lot 4 bis,
// tâche Z4) : une par région sous le zoom 7, par département de 7 à 9. Elle
// ne dessine RIEN de nouveau — sur l'échelle écoulement, le symbole existant
// de l'état le plus sévère (`OndeMarkerPainter`, `BR-009`) ; sur l'échelle
// débit, le losange neutre existant (`StationMarkerPainter.forState`, avec
// [NonChargee] — creux, contour continu, `#767676`, seule teinte que
// `BR-004` autorise tant qu'aucun percentile n'existe). Le compte de membres
// est écrit en toutes lettres, noir sur blanc.
//
// ⚠️ Cette pastille appelle directement `OndeMarkerPainter.forCategory` et
// `StationMarkerPainter.forState` — jamais `OndeMarkerShape` ni
// `StationMarkerDot` : ces deux widgets portent chacun leur PROPRE
// `Semantics`, ce qui donnerait deux nœuds sémantiques empilés ici. Un
// agrégat n'a d'ailleurs pas de date d'observation unique à annoncer
// (`OndeMarkerShape.observedAt` est réservé à une observation réelle ou à la
// légende) : passer par le peintre directement évite le faux choix entre
// une date inventée et un appelant qui outrepasserait ce contrat.
//
// La sélection d'une pastille (déplacement de la caméra sur l'emprise de ses
// membres) est câblée par l'appelant (`map_view.dart`) : ce widget est un
// widget de CONTENU pur, comme [StationMarkerDot] et [OndeMarkerShape] —
// il ne connaît aucun rappel, aucune géométrie de caméra. Voir
// `MapViewModel.zoomTargetFor` (Z3) et l'API de caméra `flutter_map` 8.3.2
// lue dans `map_view.dart`.

import 'package:flutter/widgets.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/features/map/view/onde_marker.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Côté d'une pastille de zone, en pixels logiques. Contrairement à
/// [stationMarkerSize] (12 px, une pastille de station), celle-ci PORTE à la
/// fois le rendu et la cible tactile : elle affiche un compte lisible, elle
/// ne peut donc pas rester minuscule comme un simple point. `04-ui.md § 3`
/// fixe le plancher tactile à 44 pt ; c'est aussi la taille retenue ici pour
/// que le symbole ET le compte restent lisibles. Alias de [minimumTapTarget]
/// (`K1`) : plus recopiée, gardée sous ce nom pour ses appelants existants.
const double areaClusterMarkerSize = minimumTapTarget;

/// Le libellé annoncé au lecteur d'écran pour [cluster] — le SEUL de ce
/// widget, préfixé par l'échelle active (`BR-008`, comme
/// `_stationSemanticLabel`/`_ondeSemanticLabel` de `map_view.dart`).
///
/// Sur l'échelle [MapScaleKind.ecoulement] : « Écoulement : `zone`, `N`
/// point(s) d'observation sur cette vue, état le plus sévère : `libellé` » —
/// « sur cette vue » parce que le compte ONDE ne porte que sur les points
/// **chargés** pour l'emprise courante (`ADR-015`), jamais sur un total
/// national qui n'existe pas côté client.
///
/// Sur l'échelle [MapScaleKind.debit] : « Débit relatif à l'historique :
/// `zone`, `N` station(s) » — le compte porte sur l'asset **entier**, donc
/// pas de « sur cette vue » ; et aucun état, faute de percentile (`BR-004`,
/// `ADR-003` hors T1) — `BR-009` n'a rien à départager.
///
/// `switch` exhaustif sur [MapScaleKind] (`BR-011`) : une échelle ajoutée
/// sans branche ici ne compile pas.
String areaClusterLabel(MapAreaCluster cluster) => switch (cluster.scale) {
  MapScaleKind.ecoulement => _ecoulementClusterLabel(cluster),
  MapScaleKind.debit => _debitClusterLabel(cluster),
};

String _ecoulementClusterLabel(MapAreaCluster cluster) {
  final String pointsPhrase = cluster.count == 1
      ? "1 point d'observation sur cette vue"
      : "${cluster.count} points d'observation sur cette vue";
  // `severest` n'est jamais nul sur cette échelle (`MapViewModel._ondeMapClusters`,
  // Z3) : `mostSevere` couvre l'exhaustif de `FlowCategory`, `Inconnu` compris.
  final String severestLabel = flowCategoryLabel(cluster.severest!);
  return "${mapScaleLabel(MapScaleKind.ecoulement)} : ${cluster.area.label}, "
      '$pointsPhrase, état le plus sévère : $severestLabel';
}

String _debitClusterLabel(MapAreaCluster cluster) {
  final String stationsPhrase = cluster.count == 1
      ? '1 station'
      : '${cluster.count} stations';
  return "${mapScaleLabel(MapScaleKind.debit)} : ${cluster.area.label}, "
      '$stationsPhrase';
}

/// Le symbole existant de [cluster], sans passer par [OndeMarkerShape] ni
/// [StationMarkerDot] — voir l'en-tête du fichier.
Widget _symbolFor(MapAreaCluster cluster) => switch (cluster.scale) {
  MapScaleKind.ecoulement => CustomPaint(
    size: const Size.square(stationMarkerSize),
    painter: OndeMarkerPainter.forCategory(
      category: cluster.severest!,
      age: cluster.severestAge!,
    ),
  ),
  MapScaleKind.debit => CustomPaint(
    size: const Size.square(stationMarkerSize),
    // `NonChargee` est l'état qui rend, chez `StationMarkerPainter`, le
    // losange creux à contour continu — le rendu « neutre » du plan
    // (`fillOpacity: 0`, `#767676`). Aucune nouvelle forme, aucune teinte.
    painter: StationMarkerPainter.forState(const NonChargee()),
  ),
};

/// La pastille d'un agrégat de zone administrative (`ADR-015`). Widget de
/// CONTENU pur : ni rappel de tap, ni géométrie de caméra — `map_view.dart`
/// pose le `GestureDetector` autour, comme pour [StationMarkerDot] et
/// [OndeMarkerShape].
class AreaClusterMarker extends StatelessWidget {
  const AreaClusterMarker({required this.cluster, super.key});

  /// L'agrégat à représenter.
  final MapAreaCluster cluster;

  @override
  Widget build(BuildContext context) {
    // Un seul nœud `Semantics` par pastille (invariant du plan) : le
    // symbole enfant n'a pas le sien ([_symbolFor] n'appelle ni
    // [OndeMarkerShape] ni [StationMarkerDot], qui en portent un chacun) —
    // `excludeSemantics` n'a donc rien à masquer, il documente l'intention
    // même si aucun descendant n'en produit aujourd'hui.
    return Semantics(
      button: true,
      label: areaClusterLabel(cluster),
      excludeSemantics: true,
      child: SizedBox(
        width: areaClusterMarkerSize,
        height: areaClusterMarkerSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF000000), width: 2),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _symbolFor(cluster),
                // Badge de compte : texte noir sur blanc (≥ 7:1, `04-ui.md
                // § 3`) — jamais une seconde teinte d'état.
                Text(
                  '${cluster.count}',
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
