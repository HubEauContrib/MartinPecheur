// La feuille « Filtres » de la carte (`F9` de T3, `US-13`, `UC-007`).
//
// Une vue : elle reçoit le filtre appliqué, l'échelle active, la liste des
// départements et un rappel. Elle n'appelle aucun dépôt. Son brouillon est un
// [MapFilter] tenu par son état ; toute règle reste dans la valeur du domaine.
//
// - Écoulement : les six états, le département, puis la phrase des 60 jours
//   à la place d'un critère de fraîcheur.
// - Débit : le département et la fraîcheur, aucun état — un débit ne se
//   qualifie pas (`BR-003`) —, puis ce que le critère ne masque pas.
// - Vigilance crues (`L1` de T4) : une phrase, aucun critère, ni
//   « Appliquer » ni « Effacer » — masquer un niveau publié cacherait une
//   vigilance émise (cadrage de T4, § 7.7). « Fermer » reste.
//
// L'échelle ne se choisit pas ici : c'est le sélecteur de lecture de la carte
// (`BR-008`).
// « Effacer » est immédiat et porte sur les critères des deux échelles ;
// fermer autrement que par « Appliquer » n'appelle jamais le rappel.
//
// Textes : cadrage de T3, § 10.1 (b), mot pour mot.
import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/shared/action_color.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

/// Titre de la feuille.
const String mapFilterSheetTitle = 'Filtres';

/// Action qui applique le brouillon.
const String mapFilterApplyLabel = 'Appliquer';

/// Action qui retire tous les critères, des deux échelles.
const String mapFilterClearLabel = 'Effacer';

/// Option du sélecteur qui ne retient aucun département.
const String mapFilterAllDepartementsLabel = 'Tous les départements';

/// Écrit à la place du sélecteur quand la liste n'a pas pu être lue.
const String mapFilterDepartementsUnreadableText =
    "La liste des départements n'a pas pu être lue.";

/// Débit, sous le critère de fraîcheur, première phrase.
const String mapFilterFreshnessLoadedOnlyText =
    'Ce critère ne porte que sur les mesures déjà chargées : une station '
    "dont la mesure n'est pas encore chargée reste affichée.";

/// Débit, sous le critère de fraîcheur, seconde phrase.
const String mapFilterFreshnessClustersText =
    "Il ne s'applique pas aux regroupements par région ou par département : "
    "leur compte n'en tient pas compte.";

/// Écoulement, à la place du critère de fraîcheur. La borne est lue dans
/// [campagneAncienneApres], jamais recopiée.
final String mapFilterFlowWindowText =
    "La carte ne montre que les campagnes d'observation des "
    '${campagneAncienneApres.inDays} derniers jours. Un point observé plus '
    "tôt n'y figure pas.";

/// Lecture Crues, seule phrase de la feuille : aucun critère n'y est offert
/// (cadrage de T4, § 7.7 ; texte du § 12.2, mot pour mot).
const String mapFilterFloodNoCriterionText =
    "Aucun filtre ne s'applique à la lecture Vigilance crues.";

/// Titres de section, repris du croquis de `docs/04-ui.md`.
const String _statesSectionTitle = 'États';
const String _departementSectionTitle = 'Département';
const String _freshnessSectionTitle = 'Fraîcheur';

/// Clé de la région que forme la feuille.
const Key mapFilterSheetKey = Key('map-filter-sheet');

/// Clé de l'action [mapFilterClearLabel].
const Key mapFilterClearKey = Key('map-filter-clear');

/// Clé de la case de [category] ; elle porte son libellé.
Key mapFilterCategoryKey(FlowCategory category) =>
    Key('map-filter-category-${flowCategoryLabel(category)}');

/// Clé du sélecteur de département.
const Key mapFilterDepartementKey = Key('map-filter-departement');

/// Clé du choix de fraîcheur [criterion].
Key mapFilterFreshnessKey(DischargeFreshnessCriterion criterion) =>
    Key('map-filter-freshness-${criterion.name}');

/// Clé de l'action [warningReviewCloseLabel].
const Key mapFilterCloseKey = Key('map-filter-close');

/// Clé de l'action [mapFilterApplyLabel].
const Key mapFilterApplyKey = Key('map-filter-apply');

/// Largeur maximale de la feuille : celle que la documentation de [Dialog]
/// cite pour une fenêtre de dialogue. `readingColumnWidth` (760) est la
/// colonne de texte d'un écran plein, trop large pour une liste de cases.
const double _sheetMaxWidth = 560;

/// Valeur du sélecteur pour [mapFilterAllDepartementsLabel] : aucun code de
/// département n'est vide.
const String _allDepartementsValue = '';

class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({
    required this.scale,
    required this.initialFilter,
    required this.departements,
    required this.onApply,
    super.key,
  });

  /// L'échelle affichée par la carte : elle décide des critères proposés.
  final MapScaleKind scale;

  /// Le filtre appliqué à l'ouverture.
  final MapFilter initialFilter;

  /// Les départements proposés, ou `null` si leur liste n'a pas pu être lue.
  final List<AdministrativeArea>? departements;

  /// Reçoit le filtre à appliquer — le brouillon, ou [MapFilter.none] pour
  /// « Effacer ». Jamais appelé par une simple fermeture.
  final void Function(MapFilter filter) onApply;

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late MapFilter _draft = widget.initialFilter;

  void _applyAndClose(MapFilter filter) {
    widget.onApply(filter);
    Navigator.of(context).maybePop();
  }

  /// L'échelle offre-t-elle des critères ? Sinon, ni « Appliquer » ni
  /// « Effacer » (`L1` de T4). `switch` exhaustif (`BR-011`), jamais une
  /// comparaison sur l'échelle.
  bool get _offersCriteria => switch (widget.scale) {
    MapScaleKind.ecoulement => true,
    MapScaleKind.debit => true,
    MapScaleKind.crues => false,
  };

  @override
  Widget build(BuildContext context) {
    final bool offersCriteria = _offersCriteria;
    return Dialog(
      // Sans borne, la feuille prend toute la fenêtre : sur un grand écran
      // une case se retrouve à un bord et son libellé à l'autre.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
        child: SafeArea(
          child: Semantics(
            key: mapFilterSheetKey,
            container: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // `Wrap` et non `Row` : à 200 % sur un téléphone, titre et
                  // action ne tiennent pas sur une ligne.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      const Text(
                        mapFilterSheetTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (offersCriteria)
                        _SheetAction(
                          actionKey: mapFilterClearKey,
                          label: mapFilterClearLabel,
                          onTap: () => _applyAndClose(MapFilter.none),
                        ),
                    ],
                  ),
                  ...switch (widget.scale) {
                    MapScaleKind.ecoulement => <Widget>[
                      const _SectionTitle(_statesSectionTitle),
                      for (final FlowCategory category
                          in filterableFlowCategories)
                        CheckboxListTile(
                          key: mapFilterCategoryKey(category),
                          contentPadding: EdgeInsets.zero,
                          value: _draft.shows(category),
                          onChanged: (bool? shown) {
                            if (shown != null) {
                              setState(() {
                                _draft = _draft.withCategory(
                                  category,
                                  shown: shown,
                                );
                              });
                            }
                          },
                          title: Text(flowCategoryLabel(category)),
                        ),
                      ..._departementSection(),
                      const SizedBox(height: 16),
                      Text(mapFilterFlowWindowText),
                    ],
                    MapScaleKind.debit => <Widget>[
                      ..._departementSection(),
                      const _SectionTitle(_freshnessSectionTitle),
                      RadioGroup<DischargeFreshnessCriterion>(
                        groupValue: _draft.dischargeFreshness,
                        onChanged: (DischargeFreshnessCriterion? chosen) {
                          if (chosen != null) {
                            setState(() {
                              _draft = _draft.withDischargeFreshness(chosen);
                            });
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final DischargeFreshnessCriterion criterion
                                in DischargeFreshnessCriterion.values)
                              RadioListTile<DischargeFreshnessCriterion>(
                                key: mapFilterFreshnessKey(criterion),
                                contentPadding: EdgeInsets.zero,
                                value: criterion,
                                title: Text(
                                  dischargeFreshnessCriterionLabel(criterion),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(mapFilterFreshnessLoadedOnlyText),
                      const SizedBox(height: 8),
                      const Text(mapFilterFreshnessClustersText),
                    ],
                    MapScaleKind.crues => const <Widget>[
                      SizedBox(height: 16),
                      Text(mapFilterFloodNoCriterionText),
                    ],
                  },
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      // Ferme sans appliquer : le brouillon est abandonné.
                      _SheetAction(
                        actionKey: mapFilterCloseKey,
                        label: warningReviewCloseLabel,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      if (offersCriteria)
                        _SheetAction(
                          actionKey: mapFilterApplyKey,
                          label: mapFilterApplyLabel,
                          onTap: () => _applyAndClose(_draft),
                          primary: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le titre « Département » puis le sélecteur, ou la phrase d'illisibilité.
  List<Widget> _departementSection() {
    final List<AdministrativeArea>? areas = widget.departements;
    if (areas == null) {
      return const <Widget>[
        _SectionTitle(_departementSectionTitle),
        Text(mapFilterDepartementsUnreadableText),
      ];
    }
    final String selected = _draft.departementCode ?? _allDepartementsValue;
    // Un code appliqué que la liste ne porte pas garde une option, à son seul
    // code : le sélecteur exige que sa valeur soit l'une de ses options.
    final bool listed =
        selected == _allDepartementsValue ||
        areas.any((AdministrativeArea area) => area.code == selected);
    return <Widget>[
      const _SectionTitle(_departementSectionTitle),
      DropdownButton<String>(
        key: mapFilterDepartementKey,
        isExpanded: true,
        // `null` : la hauteur suit le libellé (48 au moins), qui passe à la
        // ligne au lieu d'être coupé.
        itemHeight: null,
        value: selected,
        onChanged: (String? chosen) {
          if (chosen != null) {
            setState(() {
              _draft = _draft.withDepartement(
                chosen == _allDepartementsValue ? null : chosen,
              );
            });
          }
        },
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: _allDepartementsValue,
            child: Text(mapFilterAllDepartementsLabel),
          ),
          if (!listed)
            DropdownMenuItem<String>(value: selected, child: Text(selected)),
          for (final AdministrativeArea area in areas)
            DropdownMenuItem<String>(
              value: area.code,
              child: Text('${area.label} (${area.code})'),
            ),
        ],
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

/// Une action de la feuille — « Effacer », « Fermer », « Appliquer » —, dans
/// la forme exacte de l'action de fermeture de la fenêtre d'avertissement
/// (`lib/features/shared/warning_link.dart`, classe privée, d'où cette
/// reconstruction) : `Semantics` à la racine, [KeyboardFocusRing] dessous
/// pour le focus et Entrée/Espace, un seul arrêt de tabulation.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onTap;

  /// Vrai pour l'action principale de la feuille : elle porte
  /// [primaryActionColor].
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: actionKey,
      button: true,
      label: label,
      excludeSemantics: true,
      // Sans ce rappel, `excludeSemantics` masque l'action de tap
      // qu'`InkWell` porterait sinon lui-même.
      onTap: onTap,
      child: KeyboardFocusRing(
        onActivate: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: primary ? primaryActionColor : null),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              // `KeyboardFocusRing` porte déjà le focus : un second nœud
              // ferait de l'action deux arrêts de tabulation.
              canRequestFocus: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minimumTapTarget,
                  minHeight: minimumTapTarget,
                ),
                // Facteurs à 1 : sans eux `Center` prend toute la largeur
                // offerte, et deux actions ne tiendraient pas côte à côte.
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: primary ? 12 : 0),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      style: primary
                          ? const TextStyle(color: onPrimaryActionColor)
                          : null,
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
