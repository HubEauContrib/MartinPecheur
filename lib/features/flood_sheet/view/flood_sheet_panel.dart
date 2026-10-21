// Le panneau de la fiche tronçon (F3 de T4, cadrage § 8) : rend l'état porté
// par `FloodSheetViewModel`. `switch` exhaustif sur un `sealed` (`BR-011`).
//
// Depuis `F3` d'Ergonomie (cadrage du 2026-10-17, § 6.1, § 6.4, critère 13), la
// fiche est dans le cadre commun des fiches ([SheetFrame]) :
// - l'EN-TÊTE épinglé porte « Tronçon Vigicrues » ([floodSheetNature]), la
//   fermeture, puis le contrôle « ⚠ Avertissement » et le texte de crue
//   ([floodWarningWindowText]) — SANS étoile (T5) ;
// - le CORPS défile dessous, dans l'ORDRE DE T4 (arbitrages 4 et 5 du cadrage
//   de T4) :
//   1. le nom publié ;
//   2. l'encart de crue, non repliable, AVANT le niveau (`BR-015`) ;
//   3. la jauge et le titre du niveau ;
//   4. la définition publiée, CITÉE et attribuée — ou, pour un niveau inconnu,
//      la phrase qui renvoie au bulletin, sans aucune citation (`BR-011`) ;
//   5. la date de la carte lue et l'attribution ;
//   6. le bouton du bulletin, l'adresse affichée et sélectionnable, l'avis de
//      lien non ouvert.
// Seul changement d'ordre : « ⚠ Avertissement » passe avant le nom, dans
// l'en-tête.
//
// L'application relaie : aucun niveau, seuil ni prévision n'est déduit ici
// (`BR-015`).
//
// Le corps répond aux demandes de dimensions intrinsèques (contrat de
// [SheetFrame.body]) : ni `LayoutBuilder` ni `ListView`. Sa hauteur
// intrinsèque minimale est sa mesure mise en avant (`D7`, arbitrage 18) : le
// nom, l'encart de crue, le niveau ; ce qui suit est enveloppé dans
// [NoMinIntrinsicHeight].
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
import 'package:martinpecheur/features/shared/sheet_frame.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/unopened_link_notice.dart';

/// La ligne de nature de l'en-tête de la fiche (spec § 11.2) : le texte de T4,
/// nommé. Aucun code n'est affiché — seule la station affiche le sien.
const String floodSheetNature = 'Tronçon $floodSourceName';

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
    this.bodyScrollController,
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

  /// La position du corps du cadre, que l'appelant remet à zéro à chaque
  /// ouverture (`K4` de T3), ou `null`.
  final ScrollController? bodyScrollController;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      FicheTronconFermee() => const SizedBox.shrink(),
      // Provisoire (V1 de T5) : W2 rend la fiche d'un tronçon absent.
      FicheTronconAbsente() => const SizedBox.shrink(),
      final FicheTronconOuverte open => SheetFrame(
        nature: floodSheetNature,
        closeButtonKey: floodSheetCloseButtonKey,
        onClose: onClose,
        warningExtraText: floodWarningWindowText,
        bodyScrollController: bodyScrollController,
        body: _body(open),
      ),
    };
  }

  /// Le corps de la fiche ouverte, dans l'ordre de T4.
  Widget _body(FicheTronconOuverte open) {
    final FloodVigilanceLevel level = open.section.level;
    final String? legend = publishedFloodLegend(level);
    final String? explanation = publishedFloodExplanation(level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          open.section.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
        // La mesure mise en avant s'arrête au bas du niveau (arbitrage 18) :
        // ce qui suit cède, fiche du bas ouverte, avant elle.
        NoMinIntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
      ],
    );
  }
}
