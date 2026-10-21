// L'encart de l'avertissement de suivi (`W1` de T5, `BR-016`) : « CE N'EST PAS
// UN SYSTÈME D'ALERTE » et son corps, repris sous chaque réglage « Me prévenir »
// et en tête d'« Avis reçus ».
//
// Même style que l'encart de crue (`flood_warning_card.dart`). Surface
// verrouillée : aucun contrôle de repli, de fermeture ni de masquage
// (`ExpansionTile`, `Dismissible`, `Visibility` interdits). Les textes sont
// IMPORTÉS de `warning_texts.dart`, jamais écrits ici.
//
// ⚠️ Cette tranche partagée n'importe aucune autre tranche : les couleurs de
// l'encart (noir sur blanc) sont redites ici.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

/// Clé de l'encart — pour les tests.
const Key followUpWarningCardKey = ValueKey<String>('follow-up-warning-card');

const Color _textColor = Color(0xFF000000);
const Color _background = Color(0xFFFFFFFF);
const Color _rule = Color(0xFFC9CFC4);

/// L'encart de suivi : titre en gras avec son icône, puis le corps. Région
/// annoncée en priorité au lecteur d'écran seulement si [announced] (l'encart
/// repris sous un réglage ne l'est pas).
class FollowUpWarningCard extends StatelessWidget {
  const FollowUpWarningCard({this.announced = false, super.key});

  /// Annoncer l'encart en priorité (`liveRegion`).
  final bool announced;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: followUpWarningCardKey,
      container: true,
      liveRegion: announced,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _background,
          border: Border.symmetric(horizontal: BorderSide(color: _rule)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: _textColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          followUpWarningHeadline,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(followUpWarningBody),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
