// Les puces de bascule d'échelle — **extraites** de `map_view.dart` par
// `K1` (2026-09-23), au même titre que [IgnAttributionBadge] et
// `MapControls` (`map_controls.dart`), pour que ce fichier n'accumule pas de
// surcouches supplémentaires (dette déjà actée en `U3`). Aucun changement de
// comportement : seuls les imports des appelants changent.
//
// `BR-008` et `UC-001 A6` : changer d'échelle change **marqueurs et légende
// ensemble**, et une seule échelle est active à la fois. Ce widget ne décide
// rien — il appelle [MapScaleChips.onSelect], et c'est le ViewModel qui
// bascule (et qui ignore une demande sans effet).
//
// Les libellés viennent de `mapScaleLabel`, jamais d'une recopie locale : la
// légende nomme l'échelle active avec exactement les mêmes mots.

import 'package:flutter/material.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Les puces de bascule d'échelle, en haut à gauche de la carte : une par
/// valeur de [MapScaleKind], celle de [scale] marquée active.
class MapScaleChips extends StatelessWidget {
  const MapScaleChips({required this.scale, required this.onSelect, super.key});

  /// L'échelle active, lue sur `MapViewModel.scale`.
  final MapScaleKind scale;

  /// Appelé avec l'échelle demandée. En production,
  /// `MapViewModel.selectScale`.
  final void Function(MapScaleKind kind) onSelect;

  @override
  Widget build(BuildContext context) {
    // `Wrap` et non `Row` : « Débit relatif à l'historique » est un libellé
    // long, et les deux puces ne tiennent pas côte à côte sur un écran
    // étroit — ni sur un large, une fois réservée la place de la légende.
    // Une `Row` déborderait ; `Wrap` les empile.
    //
    // ⚠️ Le `Wrap` ne replie qu'ENTRE les puces, jamais dans l'une d'elles :
    // ce qui tient la typographie dynamique jusqu'à 200 % (`04-ui.md` § 3)
    // est, à l'intérieur de chaque puce, le `ConstrainedBox(minWidth: 44)`
    // — un plancher, pas un plafond — et le retour à la ligne du `Text`,
    // qu'aucune contrainte de hauteur ne bride.
    return Wrap(
      spacing: _overlayPadding,
      runSpacing: _overlayPadding,
      children: <Widget>[
        for (final MapScaleKind kind in MapScaleKind.values)
          _MapScaleChip(
            kind: kind,
            selected: kind == scale,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

/// Une puce. Construite à la main plutôt qu'avec un `ChoiceChip` de
/// Material pour deux raisons, dans cet ordre :
/// 1. la **cible tactile** de 44 pt (`04-ui.md` § 3) est ici une contrainte
///    explicite, pas la densité que le thème veut bien accorder ;
/// 2. l'état sélectionné est porté par `Semantics(selected:)` **en plus** du
///    rendu : « aucune information n'est portée par la seule couleur »
///    (`04-ui.md` § 3) vaut aussi pour un contrôle.
///
/// ⚠️ Le noir et le blanc employés ici ne codent **aucun état de l'eau** :
/// `04-ui.md` § 2 ne régit que les teintes d'état, et une puce de filtre
/// n'en est pas une.
class _MapScaleChip extends StatelessWidget {
  const _MapScaleChip({
    required this.kind,
    required this.selected,
    required this.onSelect,
  });

  final MapScaleKind kind;
  final bool selected;
  final void Function(MapScaleKind kind) onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // La clé est posée sur le nœud sémantique, donc sur la boîte entière :
      // c'est elle que les tests tapent et mesurent.
      key: ValueKey<MapScaleKind>(kind),
      button: true,
      selected: selected,
      label: mapScaleLabel(kind),
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud.
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que le
      // geste porterait sinon lui-même : un double-tap au lecteur d'écran
      // n'activerait plus rien (relecture du 2026-09-23).
      onTap: () => onSelect(kind),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(kind),
        child: ConstrainedBox(
          // 44 × 44 pt au minimum (`04-ui.md` § 3). La puce s'élargit avec
          // son texte, elle ne rétrécit jamais en deçà.
          constraints: const BoxConstraints(
            minWidth: minimumTapTarget,
            minHeight: minimumTapTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.white,
              border: Border.all(color: Colors.black),
              borderRadius: const BorderRadius.all(
                Radius.circular(minimumTapTarget / 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _chipHorizontalPadding,
                vertical: _chipVerticalPadding,
              ),
              // `Align` à facteurs 1 : la boîte se dimensionne sur son
              // texte, et c'est le `ConstrainedBox` au-dessus qui impose le
              // plancher de 44 pt.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  mapScaleLabel(kind),
                  style: TextStyle(
                    fontSize: _chipFontSize,
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

/// Marge d'une surcouche au bord de la carte, en pixels logiques — recopiée
/// de `map_view.dart` (`_overlayPadding`) : cette valeur habille l'espacement
/// ENTRE puces, une décision propre à ce widget, pas la marge d'une
/// surcouche de `map_view.dart` elle-même.
const double _overlayPadding = 8;

/// Marge horizontale d'une puce, en pixels logiques.
const double _chipHorizontalPadding = 12;

/// Marge verticale d'une puce, en pixels logiques.
const double _chipVerticalPadding = 8;

/// Taille de texte d'une puce, en pixels logiques.
const double _chipFontSize = 12;
