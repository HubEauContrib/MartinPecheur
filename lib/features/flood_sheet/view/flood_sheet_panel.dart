// Le panneau de la fiche tronçon (F3 de T4, cadrage § 8) : rend l'état porté
// par `FloodSheetViewModel`. `switch` exhaustif sur un `sealed` (`BR-011`).
//
// Contenu, DANS L'ORDRE (arbitrages 4 et 5 du cadrage) :
// 1. « Tronçon Vigicrues », le nom publié, le contrôle « ⚠ Avertissement » ;
// 2. l'encart de crue, non repliable, AVANT le niveau (`BR-015`) ;
// 3. la jauge et le titre du niveau ;
// 4. la définition publiée, CITÉE et attribuée — ou, pour un niveau inconnu,
//    la phrase qui renvoie au bulletin, sans aucune citation (`BR-011`) ;
// 5. la date de la carte lue et l'attribution ;
// 6. le bouton du bulletin, l'adresse affichée et sélectionnable, l'avis de
//    lien non ouvert.
//
// Pas d'étoile (T5). L'application relaie : aucun niveau, seuil ni prévision
// n'est déduit ici (`BR-015`).
//
// ⚠️ Cette tranche n'importe AUCUNE autre tranche : seulement `lib/domain/` et
// `lib/features/shared/`.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/floods/published_flood_definitions.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/flood_sheet/view/flood_warning_card.dart';
import 'package:martinpecheur/features/flood_sheet/view_model/flood_sheet_view_model.dart';
import 'package:martinpecheur/features/shared/flood_level_gauge.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/unopened_link_notice.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Clé du bouton « Fermer la fiche » — pour les tests.
const Key floodSheetCloseButtonKey = Key('flood-sheet-close');

/// Clé du bouton du bulletin — pour les tests.
const Key floodBulletinButtonKey = Key('flood-bulletin-button');

/// Phrase d'un niveau que l'application ne sait pas lire (cadrage § 12.2).
const String floodUnknownLevelText =
    "$floodSourceName a publié un niveau que cette application ne sait pas "
    "lire. Le bulletin sur $floodPublicSiteLabel fait foi.";

/// Libellé du bouton du bulletin (cadrage § 12.2).
const String floodBulletinButtonLabel =
    'Lire le bulletin sur $floodPublicSiteLabel';

/// Le panneau de la fiche tronçon.
class FloodSheetPanel extends StatelessWidget {
  const FloodSheetPanel({
    required this.state,
    required this.onClose,
    required this.onOpenBulletin,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// L'état courant de la fiche.
  final FloodSheetState state;

  /// Appelé par le bouton de fermeture.
  final VoidCallback onClose;

  /// Appelé par le bouton du bulletin.
  final VoidCallback onOpenBulletin;

  /// Le décalage UTC → heure locale, demandé pour l'instant affiché — par
  /// défaut celui de la machine, injectable par un test.
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      FicheTronconFermee() => const SizedBox.shrink(),
      final FicheTronconOuverte open => _frame(open),
    };
  }

  Widget _frame(FicheTronconOuverte open) {
    final FloodVigilanceLevel level = open.section.level;
    final String? legend = publishedFloodLegend(level);
    final String? explanation = publishedFloodExplanation(level);
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Tronçon $floodSourceName',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    open.section.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const WarningLink(extraText: floodWarningWindowText),
                  const SizedBox(height: 8),
                  const FloodWarningCard(),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      FloodLevelGauge(level: level, size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          floodVigilanceTitle(level),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (legend != null) ...<Widget>[
                    Text('« $legend »'),
                    if (explanation != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('« $explanation »'),
                    ],
                    const SizedBox(height: 4),
                    const Text('— $floodSourceName'),
                  ] else
                    const Text(floodUnknownLevelText),
                  const SizedBox(height: 8),
                  Text(
                    'Information de vigilance du '
                    '${formatLocalDateTime(open.informationDate, offsetOf: utcOffsetOf)}'
                    ' — $floodAttribution',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: floodBulletinButtonKey,
                    onPressed: onOpenBulletin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.square(minimumTapTarget),
                      visualDensity: VisualDensity.standard,
                    ),
                    child: const Text(floodBulletinButtonLabel),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(open.bulletinUri.toString()),
                  if (open.unopenedBulletinCount > 0)
                    UnopenedLinkNotice(
                      key: ValueKey<int>(open.unopenedBulletinCount),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CloseButton(onClose: onClose),
          ],
        ),
      ),
    );
  }
}

/// Le bouton de fermeture, dimensionné à [minimumTapTarget] par un
/// `SizedBox` explicite (mesurable par test, `04-ui.md` § 3).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fermer la fiche',
      child: GestureDetector(
        key: floodSheetCloseButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: SizedBox(
          width: minimumTapTarget,
          height: minimumTapTarget,
          child: const Center(child: Icon(Icons.close)),
        ),
      ),
    );
  }
}
