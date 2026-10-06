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
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// La clé du choix « Restrictions » (`E5` de T2) : posée sur son nœud
/// sémantique, donc sur la boîte entière — celle que les tests tapent et
/// mesurent, comme `ValueKey<MapScaleKind>` pour les deux échelles.
const Key mapDesignationChipKey = Key('map-designation-chip');

/// Le libellé du choix « Restrictions » — celui de l'écran des restrictions
/// et du bouton qu'il fait apparaître.
const String designationChipLabel = 'Restrictions';

/// Les puces du sélecteur, en haut de la carte : une par valeur de
/// [MapScaleKind], celle de [scale] marquée active, puis — si
/// [onToggleDesignationMode] est fourni — le choix « Restrictions ». À
/// gauche à partir de 600 px de large, dans la colonne de droite en deçà
/// (`buildMapOverlays`).
///
/// ⚠️ « Restrictions » n'est **pas** une troisième échelle (`E5`, arbitrage
/// du commanditaire du 2026-10-03) : c'est un interrupteur **indépendant**
/// des deux autres. La puce de l'échelle reste allumée, « Restrictions »
/// s'allume en plus ; elle porte `toggled`, jamais `selected`.
class MapScaleChips extends StatelessWidget {
  const MapScaleChips({
    required this.scale,
    required this.onSelect,
    this.designationMode = false,
    this.onToggleDesignationMode,
    super.key,
  });

  /// L'échelle active, lue sur `MapViewModel.scale`.
  final MapScaleKind scale;

  /// Appelé avec l'échelle demandée. En production,
  /// `MapViewModel.selectScale`.
  final void Function(MapScaleKind kind) onSelect;

  /// Le mode de désignation est-il actif ? Lu sur
  /// `MapViewModel.designationMode`. Sans effet quand
  /// [onToggleDesignationMode] est nul : la puce est alors absente.
  final bool designationMode;

  /// Appelé par un tap sur « Restrictions ». En production,
  /// `MapViewModel.toggleDesignationMode`. `null` : aucune désignation n'est
  /// câblée, la troisième puce est **absente** — jamais une puce morte.
  final VoidCallback? onToggleDesignationMode;

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
    final VoidCallback? toggleDesignation = onToggleDesignationMode;
    return Wrap(
      spacing: _overlayPadding,
      runSpacing: _overlayPadding,
      children: <Widget>[
        for (final MapScaleKind kind in MapScaleKind.values)
          _Chip(
            semanticsKey: ValueKey<MapScaleKind>(kind),
            label: mapScaleLabel(kind),
            lit: kind == scale,
            selected: kind == scale,
            onActivate: () => onSelect(kind),
          ),
        if (toggleDesignation != null)
          _Chip(
            semanticsKey: mapDesignationChipKey,
            label: designationChipLabel,
            lit: designationMode,
            toggled: designationMode,
            onActivate: toggleDesignation,
          ),
      ],
    );
  }
}

/// Une puce. Construite à la main plutôt qu'avec un `ChoiceChip` de
/// Material pour deux raisons, dans cet ordre :
/// 1. la **cible tactile** de 44 pt (`04-ui.md` § 3) est ici une contrainte
///    explicite, pas la densité que le thème veut bien accorder ;
/// 2. l'état allumé est porté par `Semantics` **en plus** du rendu :
///    « aucune information n'est portée par la seule couleur »
///    (`04-ui.md` § 3) vaut aussi pour un contrôle.
///
/// Les trois puces partagent cette seule pilule. Une échelle porte
/// `selected` ; le choix « Restrictions » porte `toggled` (un interrupteur,
/// pas un choix exclusif) — l'un ou l'autre, jamais les deux.
///
/// ⚠️ Le noir et le blanc employés ici ne codent **aucun état de l'eau** :
/// `04-ui.md` § 2 ne régit que les teintes d'état, et une puce de filtre
/// n'en est pas une.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.semanticsKey,
    required this.label,
    required this.lit,
    required this.onActivate,
    this.selected,
    this.toggled,
  });

  final Key semanticsKey;
  final String label;

  /// Rendu allumé (fond noir, texte blanc) — pour `selected` comme pour
  /// `toggled`.
  final bool lit;

  /// `Semantics(selected:)` d'une échelle ; `null` pour « Restrictions ».
  final bool? selected;

  /// `Semantics(toggled:)` de « Restrictions » ; `null` pour une échelle.
  final bool? toggled;

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    // `KeyboardFocusRing` (`K2`) : la puce n'était, avant cette tâche,
    // atteignable qu'à la souris — un `GestureDetector` nu ne participe à
    // aucun ordre de tabulation. « Tout ce qui se fait à la souris se fait
    // au clavier » (`04-ui.md § 3`) : Entrée/Espace appellent [onActivate],
    // exactement comme le tap. Posé SOUS `Semantics`, comme `WarningLink` :
    // la clé reste la racine du sous-arbre où le focus se trouve.
    return Semantics(
      // La clé est posée sur le nœud sémantique, donc sur la boîte
      // entière : c'est elle que les tests tapent et mesurent.
      key: semanticsKey,
      button: true,
      selected: selected,
      toggled: toggled,
      label: label,
      // Le libellé est déjà annoncé ici ; sans cette exclusion le `Text`
      // intérieur en ferait un second nœud.
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap que le
      // geste porterait sinon lui-même : un double-tap au lecteur d'écran
      // n'activerait plus rien (relecture du 2026-09-23).
      onTap: onActivate,
      child: KeyboardFocusRing(
        onActivate: onActivate,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onActivate,
          child: ConstrainedBox(
            // 44 × 44 pt (48 dp sur Android) au minimum (`04-ui.md` § 3). La puce s'élargit avec
            // son texte, elle ne rétrécit jamais en deçà.
            constraints: BoxConstraints(
              minWidth: minimumTapTarget,
              minHeight: minimumTapTarget,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: lit ? Colors.black : Colors.white,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(
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
                    label,
                    style: TextStyle(
                      fontSize: _chipFontSize,
                      color: lit ? Colors.white : Colors.black,
                      fontWeight: lit ? FontWeight.w600 : FontWeight.w400,
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
