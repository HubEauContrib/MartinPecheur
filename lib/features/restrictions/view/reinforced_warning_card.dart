// L'encart renforce (E4 de T2, `BR-013`, avertissement 4 sur 4 de
// `04-ui.md § 5`) : premier contenu de l'ecran des restrictions, dans tous
// ses etats, avant meme la reponse de la source.
//
// Arbitrage Q-4 (a) de `docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md`
// (§ 4) : a 200 % de police l'encart entier ne tient pas dans la hauteur
// utile. Il se dedouble donc en DEUX morceaux :
// - [ReinforcedWarningHeader], la tete EPINGLEE (titre et action), qui ne
//   defile jamais ;
// - [ReinforcedWarningBody], le corps et l'adresse du site public, PREMIER
//   element du defilement.
// Surface verrouillee : aucun parametre de repli, de fermeture ni de
// masquage, ni sur l'un ni sur l'autre (`ExpansionTile`, `Dismissible`,
// `Visibility` interdits). Les textes sont IMPORTES de `warning_texts.dart` ;
// aucune phrase de l'encart n'est ecrite ici.
//
// Dans la tranche restrictions, pas sous `features/shared/` : un seul ecran de
// ressource en T2 (conception § 7, YAGNI).

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Cle de la region d'alerte de la tete epinglee — pour les tests.
const Key reinforcedWarningHeaderKey = ValueKey<String>(
  'reinforced-warning-header',
);

/// Cle du corps — pour les tests. Ce n'est PAS une region d'alerte : la seule
/// region est la tete (arbitrage du 2026-09-29, pas de double annonce).
const Key reinforcedWarningBodyKey = ValueKey<String>(
  'reinforced-warning-body',
);

/// La tete epinglee : titre puis action, annonces comme region d'alerte.
class ReinforcedWarningHeader extends StatelessWidget {
  const ReinforcedWarningHeader({required this.onConsultDecrees, super.key});

  /// Ouvre les arretes en vigueur (site public), hors de l'application.
  final VoidCallback onConsultDecrees;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: reinforcedWarningHeaderKey,
      container: true,
      liveRegion: true,
      child: Material(
        color: droughtScreenBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // L'icone est en ligne avec le titre : a 200 % elle ne prend
              // pas de colonne entiere (critere de la moitie, Q-4).
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: droughtLevelLabelColor,
                        ),
                      ),
                    ),
                    const TextSpan(text: ' '),
                    const TextSpan(text: reinforcedWarningHeadline),
                  ],
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: droughtLevelLabelColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onConsultDecrees,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.square(minimumTapTarget),
                  visualDensity: VisualDensity.standard,
                  foregroundColor: droughtLevelLabelColor,
                ),
                child: const Text(reinforcedWarningActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le corps : le texte fige de `BR-013` et l'adresse du site public,
/// toujours visible et selectionnable.
class ReinforcedWarningBody extends StatelessWidget {
  const ReinforcedWarningBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: reinforcedWarningBodyKey,
      container: true,
      // Couleur explicite : le corps ne depend pas du style herite.
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: droughtLevelLabelColor),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(reinforcedWarningBody),
            SizedBox(height: 8),
            SelectableText(restrictionsPublicSiteUrl),
          ],
        ),
      ),
    );
  }
}
