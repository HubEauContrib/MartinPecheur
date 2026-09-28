// La cible tactile minimale du produit (`04-ui.md` § 3 : cibles tactiles
// ≥ 44 × 44 pt iOS, ≥ 48 × 48 dp Android) — jusqu'à `K1`, cette même valeur vivait recopiée SIX
// fois : `stationMarkerTapTarget` (`features/map/view/station_marker.dart`),
// `areaClusterMarkerSize` (`features/map/view/area_cluster_marker.dart`),
// `warningLinkTapTarget` (`features/shared/warning_link.dart`),
// `ondeSheetTapTarget` (`features/onde_sheet/view/onde_summary_sheet.dart`),
// et deux `minimumTapTarget` distincts
// (`features/station_sheet/view/station_summary_sheet.dart`,
// `features/warnings/view/initial_warning_view.dart`) — dette actée dès `U1`
// faute d'un endroit commun (`test/architecture/layers_test.dart` interdisait
// alors à une tranche d'en importer une autre pour cela).
//
// `lib/features/shared/` existe depuis l'arbitrage du 2026-09-18
// (`shared-sans-tranche`) : `K1` y pose donc la constante UNIQUE, et chaque
// tranche qui portait sa propre copie la remplace par celle-ci — soit
// directement, soit par un ALIAS qui garde son nom d'origine (recopié dans
// les fiches et les tests existants) mais plus sa propre valeur littérale.
// Le critère de fin de `K1` demande une seule occurrence du littéral dans
// `lib/`, sous ce nom, dans ce fichier.
//
// Arbitrage du commanditaire du 2026-09-29 (`K4` de T2) : 48 sur Android,
// 44 partout ailleurs, Windows et iOS compris (44 pt est la règle iOS). La
// valeur dépend donc de la plateforme : [minimumTapTargetFor] la calcule,
// [minimumTapTarget] la lit sur `defaultTargetPlatform`. Définition UNIQUE.

import 'package:flutter/foundation.dart';

/// 48 pour [TargetPlatform.android], 44 pour toute autre plateforme.
double minimumTapTargetFor(TargetPlatform platform) =>
    platform == TargetPlatform.android ? 48.0 : 44.0;

/// La cible tactile minimale de la plateforme courante.
double get minimumTapTarget => minimumTapTargetFor(defaultTargetPlatform);
