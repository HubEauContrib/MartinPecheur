// L'encart de crue de la fiche tronçon (F3 de T4, `BR-015`) : « CE N'EST PAS
// UN SYSTÈME D'ALERTE » et son corps, placé AVANT le niveau.
//
// Même style que l'encart renforcé des restrictions
// (`reinforced_warning_card.dart`), SANS son action : il n'y a pas d'arrêtés
// ici. Surface verrouillée : aucun contrôle de repli, de fermeture ni de
// masquage (`ExpansionTile`, `Dismissible`, `Visibility` interdits). Les
// textes sont IMPORTÉS de `warning_texts.dart`, jamais écrits ici.
//
// ⚠️ Cette tranche n'importe aucune autre tranche : les couleurs de l'encart
// renforcé (noir sur blanc) sont redites ici, pas importées de `restrictions`.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

/// Clé de l'encart — pour les tests.
const Key floodWarningCardKey = ValueKey<String>('flood-warning-card');

const Color _textColor = Color(0xFF000000);
const Color _background = Color(0xFFFFFFFF);
const Color _rule = Color(0xFFC9CFC4);

/// L'encart de crue : titre en gras avec son icône, puis le corps. Région
/// annoncée en priorité au lecteur d'écran.
class FloodWarningCard extends StatelessWidget {
  const FloodWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: floodWarningCardKey,
      container: true,
      liveRegion: true,
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
                          floodWarningHeadline,
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
                const Text(floodWarningBody),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
