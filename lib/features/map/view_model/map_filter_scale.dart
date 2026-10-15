// Le pont entre le filtre de la carte et l'échelle active (T3). `MapFilter`
// vit dans le domaine et ne connaît pas [MapScaleKind], qui appartient à la
// tranche carte : c'est ici, et ici seulement, que l'échelle choisit lequel
// de ses deux membres lire. Dart pur, aucun widget.
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

/// Dit si [filter] masque quelque chose sur l'échelle [scale].
///
/// Sur la lecture Crues, jamais : aucun filtre ne s'y applique — masquer un
/// niveau publié cacherait une vigilance émise (R9, cadrage de T4, § 7.7).
///
/// `switch` exhaustif sur un `enum` fermé (`BR-011`) : une échelle ajoutée
/// sans branche ici ne compile pas.
bool mapFilterActiveFor(MapFilter filter, MapScaleKind scale) =>
    switch (scale) {
      MapScaleKind.ecoulement => filter.isActiveForFlow,
      MapScaleKind.debit => filter.isActiveForDischarge,
      MapScaleKind.crues => false,
    };
