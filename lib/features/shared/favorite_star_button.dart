// L'étoile de favori partagée par les deux fiches (`S4` de T3, cadrage § 5.3).
//
// Lisible SANS la couleur (critère 14) : la FORME dit l'état — `Icons.star`
// pleine, `Icons.star_border` vide —, la teinte est la même, et le lecteur
// d'écran annonce le libellé de l'action. Inactive, elle garde sa forme,
// atténuée, annoncée désactivée, et RESTE dans l'ordre de tabulation : elle
// n'appelle simplement pas `onToggle` (le focus ne doit pas se perdre pendant
// une écriture).
//
// Même construction que `DataSourcesLink` : `Semantics` en racine,
// `KeyboardFocusRing` dessous, `InkWell` sans focus propre.
//
// Aucune tranche importée (`shared-sans-tranche`).

import 'package:flutter/material.dart';

import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Posée sur la cible carrée de l'étoile : c'est elle que les tests mesurent.
const Key favoriteStarButtonKey = Key('favorite-star');

/// Libellé annoncé quand le lieu n'est pas un favori.
const String addFavoriteLabel = 'Ajouter aux favoris';

/// Libellé annoncé quand le lieu est un favori.
const String removeFavoriteLabel = 'Retirer des favoris';

/// Avis d'un ajout en échec (§ 10.1 du cadrage).
const String favoriteWriteFailedText = "Le favori n'a pas pu être enregistré.";

/// Avis d'un retrait en échec (décision 1, approuvée par le commanditaire le
/// 2026-10-12).
const String favoriteRemoveFailedText = "Le favori n'a pas pu être retiré.";

/// Opacité de l'étoile inactive : la forme reste lisible.
const double _disabledOpacity = 0.4;

class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    required this.star,
    required this.onToggle,
    super.key,
  });

  final FavoriteStar star;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? activate = star.enabled ? onToggle : null;
    final double size = minimumTapTarget;
    return Semantics(
      button: true,
      label: star.filled ? removeFavoriteLabel : addFavoriteLabel,
      enabled: star.enabled,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap qu'`InkWell`
      // porterait sinon.
      onTap: activate,
      excludeSemantics: true,
      // Toujours focalisable, même inactive : le ViewModel rend
      // `enabled: false` pendant toute écriture, et un nœud qui cesserait
      // d'être focalisable alors perdrait le focus sans le retrouver. Inactive,
      // `activate` est nul : Entrée, Espace et tap ne font rien (`KeyboardFocusRing`).
      child: KeyboardFocusRing(
        onActivate: activate,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: activate,
            // `KeyboardFocusRing` porte déjà le focus : un second `FocusNode`
            // ferait de l'étoile DEUX arrêts de tabulation.
            canRequestFocus: false,
            child: SizedBox(
              key: favoriteStarButtonKey,
              width: size,
              height: size,
              child: Center(
                child: Opacity(
                  opacity: star.enabled ? 1 : _disabledOpacity,
                  child: Icon(
                    star.filled ? Icons.star : Icons.star_border,
                    // La même teinte pleine ou vide : seule la forme change.
                    color: primaryActionColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'avis d'une écriture de favori en échec, annoncé au lecteur d'écran.
/// L'appelant choisit le texte ([favoriteWriteFailedText] ou
/// [favoriteRemoveFailedText]).
class FavoriteWriteFailedNotice extends StatelessWidget {
  const FavoriteWriteFailedNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, child: Text(text));
  }
}
