// L'écran « Favoris » (`S9` de T3, cadrage § 5.4) : la liste des lieux que
// l'usager a choisi de retrouver.
//
// - IDENTITÉ SEULE : libellé, nature du lieu, cours d'eau et département quand
//   la copie les porte, date d'ajout. AUCUNE valeur mesurée, aucun appel
//   réseau : sinon chaque ligne devrait porter date, source et fraîcheur
//   (`BR-001`) et coûter un appel par favori (`C-15`). La liste le dit, en
//   tête ([favoritesNoMeasureNotice]).
// - La vue AFFICHE l'état que `FavoritesViewModel` produit, elle ne décide
//   rien : ouvrir, retirer et repartir d'une liste vide sont trois rappels.
//   Ouvrir un favori revient à la racine de composition : cette tranche
//   n'importe aucune autre tranche (`feature-vers-feature`).
// - Une liste vide dit comment un favori s'ajoute, rien de l'état des cours
//   d'eau ; une liste illisible est dite telle, jamais montrée vide (`BR-007`).
// - Une entrée non lisible est montrée et retirable, jamais ouvrable
//   (`BR-011`).
// - ÉCRAN PLEIN bâti comme `DataSourcesView` : barre de titre partagée
//   ([ScreenTitleBar], la seule de `lib/`), `Échap`, molette posée sur la
//   barre, colonne de lecture.
//
// Textes : ceux du cadrage § 10.1, mot pour mot.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/features/favorites/view_model/favorites_view_model.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/shared/favorite_star_button.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/screen_layout.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Titre de l'écran.
const String favoritesScreenTitle = 'Favoris';

/// En tête de la liste : elle ne montre aucune mesure (`BR-001`).
const String favoritesNoMeasureNotice =
    'Cette liste ne montre aucune mesure. La fiche d\'un lieu donne sa '
    'dernière mesure connue, avec sa date.';

/// Liste vide : comment un favori s'ajoute (`BR-007`).
const String favoritesEmptyText =
    'Aucun favori enregistré. L\'étoile d\'une fiche — station de mesure ou '
    'point d\'observation — ajoute ce lieu à cette liste.';

/// Liste illisible : dite telle, jamais montrée vide (`BR-007`).
const String favoritesUnreadableText =
    'Les favoris enregistrés sur cet appareil n\'ont pas pu être lus. Ils '
    'sont conservés tels quels : aucun favori ne peut être ajouté ni retiré '
    'tant que la liste n\'est pas remplacée.';

/// L'action explicite d'une liste illisible.
const String favoritesStartOverLabel = "Repartir d'une liste vide";

/// Sous-titre de [favoritesStartOverLabel] : ce que l'action efface.
const String favoritesStartOverHint =
    'Les favoris enregistrés sur cet appareil seront effacés.';

/// Mention d'une entrée que cette version ne sait pas lire (`BR-011`).
const String unreadableFavoriteText =
    "Favori non lisible par cette version de l'application";

/// Nature d'un favori station (`glossary.md`).
const String stationFavoriteKind = 'Station hydrométrique';

/// Nature d'un favori point ONDE (`glossary.md`).
const String ondeFavoriteKind = 'Point ONDE';

/// Préfixe de la date d'ajout, suivie de `JJ/MM/AAAA`.
const String favoriteAddedOnPrefix = 'Ajouté le ';

/// Avis de « Repartir d'une liste vide » en échec.
const String favoritesReplaceFailedText = "La liste n'a pas pu être remplacée.";

/// Annonce du retrait d'un favori lisible, suivie du nom du lieu que sa ligne
/// affiche (arbitrage du commanditaire du 2026-10-14). Les étoiles des fiches
/// gardent « Retirer des favoris » : le lieu y est celui de la fiche.
const String removeNamedFavoritePrefix = 'Retirer des favoris : ';

/// Annonce du retrait d'une entrée non lisible (arbitrage du commanditaire du
/// 2026-10-14).
const String removeUnreadableFavoriteLabel = 'Retirer ce favori non lisible';

/// Posée sur le bouton « Repartir d'une liste vide ».
const Key favoritesStartOverButtonKey = Key('favorites-start-over');

/// L'écran « Favoris » : rend l'état porté par `FavoritesViewModel`, quel
/// qu'il soit (`switch` exhaustif, `BR-011`).
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.state,
    required this.busy,
    required this.writeFailed,
    required this.onOpen,
    required this.onRemove,
    required this.onStartOver,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// L'état courant, produit par `FavoritesViewModel`.
  final FavoritesState state;

  /// Une écriture court : retrait et remise à zéro sont inactifs.
  final bool busy;

  /// La dernière écriture a échoué.
  final bool writeFailed;

  /// Ouvre la fiche d'un favori lisible — jamais appelé avec un
  /// [UnreadableFavorite]. La racine de composition le branche.
  final void Function(Favorite favorite) onOpen;

  /// Retire un favori — branché sur `FavoritesViewModel.remove`.
  final void Function(Favorite favorite) onRemove;

  /// « Repartir d'une liste vide » — branché sur
  /// `FavoritesViewModel.startOver`.
  final VoidCallback onStartOver;

  /// Décalage UTC → heure locale pour la date d'ajout (`H1`).
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(Navigator.maybePop(context));
        },
      },
      // Le focus de l'écran sert `Échap` et `PageDown` dès l'ouverture ; il
      // n'est pas un arrêt de tabulation : sans indicateur visible, ce serait
      // un focus invisible (`K2`).
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Scaffold(
          body: SafeArea(
            // La molette posée sur la barre de titre, hors du défilement,
            // fait défiler l'écran.
            child: WheelScrollsScreen(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const ScreenTitleBar(title: favoritesScreenTitle),
                  // L'écriture en échec, SOUS la barre de titre et HORS du
                  // défilement : dans la liste, l'avis serait hors champ dès
                  // qu'elle est défilée, et un retrait en échec ne montrerait
                  // rien. Sur une liste illisible, c'est « Repartir d'une
                  // liste vide » qui a échoué ; ailleurs, un retrait.
                  if (writeFailed)
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth:
                              readingColumnWidth + 2 * readingColumnGutter,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            readingColumnGutter,
                            8,
                            readingColumnGutter,
                            8,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FavoriteWriteFailedNotice(switch (state) {
                              FavorisIllisibles() => favoritesReplaceFailedText,
                              FavorisFermes() ||
                              FavorisEnLecture() ||
                              AucunFavori() ||
                              FavorisLus() => favoriteRemoveFailedText,
                            }),
                          ),
                        ),
                      ),
                    ),
                  // Une seule barre de défilement, toujours visible ;
                  // l'automatique du bureau est retirée pour ne pas la
                  // doubler. `primary: true` : la molette de la barre de
                  // titre et `PageDown` trouvent le défilement de la route.
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          primary: true,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth:
                                    readingColumnWidth +
                                    2 * readingColumnGutter,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  readingColumnGutter,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _content(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    final FavoritesState state = this.state;
    return switch (state) {
      FavorisFermes() => const <Widget>[],
      FavorisEnLecture() => const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      AucunFavori() => const <Widget>[Text(favoritesEmptyText)],
      FavorisLus(:final List<Favorite> favorites) => <Widget>[
        const Text(favoritesNoMeasureNotice),
        const SizedBox(height: 8),
        for (int i = 0; i < favorites.length; i++) ...<Widget>[
          const Divider(height: 1),
          _FavoriteRow(
            key: ValueKey<String>('favorite-row-$i'),
            removeKey: ValueKey<String>('favorite-remove-$i'),
            favorite: favorites[i],
            busy: busy,
            onOpen: onOpen,
            onRemove: onRemove,
            utcOffsetOf: utcOffsetOf,
          ),
        ],
      ],
      FavorisIllisibles() => <Widget>[
        const Text(favoritesUnreadableText),
        const SizedBox(height: 16),
        _StartOverButton(onStartOver: busy ? null : onStartOver),
        const SizedBox(height: 8),
        const Text(favoritesStartOverHint),
      ],
    };
  }
}

/// Une ligne : l'identité du favori, puis son bouton de retrait.
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.removeKey,
    required this.favorite,
    required this.busy,
    required this.onOpen,
    required this.onRemove,
    required this.utcOffsetOf,
    super.key,
  });

  final Key removeKey;
  final Favorite favorite;
  final bool busy;
  final void Function(Favorite favorite) onOpen;
  final void Function(Favorite favorite) onRemove;
  final UtcOffsetOf utcOffsetOf;

  String _addedOn(DateTime addedAt) =>
      '$favoriteAddedOnPrefix'
      '${formatLocalDate(addedAt, offsetOf: utcOffsetOf)}';

  @override
  Widget build(BuildContext context) {
    final Favorite favorite = this.favorite;
    // Le libellé d'abord, en gras ; `null` : l'entrée n'en porte pas. Le
    // retrait nomme le lieu que la ligne affiche : les lignes se suivent par
    // rang, et après un retrait le focus reste au même rang, sur le favori
    // suivant (arbitrage du commanditaire du 2026-10-14).
    final (
      String? label,
      List<String> details,
      bool opens,
      String removeLabel,
    ) = switch (favorite) {
      StationFavorite(:final String label, :final DateTime addedAt) => (
        label,
        <String>[stationFavoriteKind, _addedOn(addedAt)],
        true,
        '$removeNamedFavoritePrefix$label',
      ),
      OndePointFavorite(:final OndePoint point, :final DateTime addedAt) => (
        point.label,
        <String>[
          ondeFavoriteKind,
          if (point.waterCourseLabel case final String waterCourse) waterCourse,
          if (point.departement case final AdministrativeArea area)
            'Département ${area.code}',
          _addedOn(addedAt),
        ],
        true,
        '$removeNamedFavoritePrefix${point.label}',
      ),
      // Ni date, ni ouverture : rien d'autre ne se lit de cette entrée.
      UnreadableFavorite(:final String? label) => (
        label,
        const <String>[unreadableFavoriteText],
        false,
        removeUnreadableFavoriteLabel,
      ),
    };

    final Widget identity = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumTapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (label != null)
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final String detail in details) Text(detail),
          ],
        ),
      ),
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: opens
              ? _OpenFavorite(onOpen: () => onOpen(favorite), child: identity)
              : identity,
        ),
        const SizedBox(width: 8),
        // L'étoile pleine des fiches : même forme, inactive tant qu'une
        // écriture court ; son annonce nomme le lieu ([removeLabel]).
        KeyedSubtree(
          key: removeKey,
          child: FavoriteStarButton(
            star: FavoriteStar(filled: true, enabled: !busy),
            onToggle: () => onRemove(favorite),
            label: removeLabel,
          ),
        ),
      ],
    );
  }
}

/// L'identité d'un favori lisible, en bouton : tap, `Entrée`, `Espace`.
/// Même construction que `DataSourcesLink`, sans masquer les textes au
/// lecteur d'écran : ils sont ce que le bouton annonce.
class _OpenFavorite extends StatelessWidget {
  const _OpenFavorite({required this.onOpen, required this.child});

  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: KeyboardFocusRing(
          onActivate: onOpen,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpen,
              // `KeyboardFocusRing` porte déjà le focus : un second
              // `FocusNode` ferait de la ligne DEUX arrêts de tabulation.
              canRequestFocus: false,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// « Repartir d'une liste vide ». [onStartOver] `null` : inactif, annoncé
/// tel, et toujours dans l'ordre de tabulation (le focus ne se perd pas
/// pendant l'écriture).
class _StartOverButton extends StatelessWidget {
  const _StartOverButton({required this.onStartOver});

  final VoidCallback? onStartOver;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onStartOver != null;
    return Semantics(
      key: favoritesStartOverButtonKey,
      button: true,
      label: favoritesStartOverLabel,
      enabled: enabled,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap qu'`InkWell`
      // porterait sinon.
      onTap: onStartOver,
      excludeSemantics: true,
      child: KeyboardFocusRing(
        onActivate: onStartOver,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: primaryActionColor,
            child: InkWell(
              onTap: onStartOver,
              canRequestFocus: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumTapTarget),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Text(
                      favoritesStartOverLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onPrimaryActionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
