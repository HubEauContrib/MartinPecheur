// Le filtre de la carte (T3) : ce qui masque des lieux à l'intérieur de
// l'échelle affichée. Il ne choisit pas l'échelle — ce sont les puces
// d'échelle, qui vivent dans la tranche carte. D'où deux membres nommés
// (`isActiveForFlow`, `isActiveForDischarge`) et aucun paramètre d'échelle :
// ce domaine n'importe rien de `lib/features/`.
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';

/// Critère de fraîcheur du débit : les seuils sont ceux de `BR-005`, lus dans
/// `freshness.dart`, jamais recopiés.
enum DischargeFreshnessCriterion {
  /// Aucune exigence de fraîcheur.
  toutes,

  /// Mesure [Freshness.fraiche] seulement (âge inférieur à [ancienneApres]).
  moinsDe2h,

  /// Mesure fraîche ou ancienne (âge inférieur à [perimeeApres]).
  moinsDe24h,
}

/// Dit si une observation de fraîcheur [freshness] passe le [criterion].
/// Deux `switch` exhaustifs, sans `default` (`BR-011`).
bool dischargeFreshnessAdmits(
  DischargeFreshnessCriterion criterion,
  Freshness freshness,
) => switch (criterion) {
  DischargeFreshnessCriterion.toutes => true,
  DischargeFreshnessCriterion.moinsDe2h => switch (freshness) {
    Freshness.fraiche => true,
    Freshness.ancienne => false,
    Freshness.perimee => false,
  },
  DischargeFreshnessCriterion.moinsDe24h => switch (freshness) {
    Freshness.fraiche => true,
    Freshness.ancienne => true,
    Freshness.perimee => false,
  },
};

/// Libellé du [criterion] ; les bornes sont lues dans `freshness.dart`.
String dischargeFreshnessCriterionLabel(
  DischargeFreshnessCriterion criterion,
) => switch (criterion) {
  DischargeFreshnessCriterion.toutes => 'Toutes',
  DischargeFreshnessCriterion.moinsDe2h =>
    'Moins de ${ancienneApres.inHours} h',
  DischargeFreshnessCriterion.moinsDe24h =>
    'Moins de ${perimeeApres.inHours} h',
};

/// Les six catégories que le filtre propose, dans l'ordre de la légende.
const List<FlowCategory> filterableFlowCategories = <FlowCategory>[
  Ecoulement(),
  EcoulementFaible(),
  EcoulementNonVisible(),
  Assec(),
  NonObserve(),
  Inconnu(null),
];

/// Valeur immuable du filtre de la carte. Un lieu masqué n'est pas une absence
/// de donnée. Gardé le temps de la session, jamais enregistré.
///
/// La décision par catégorie se prend par `switch` sur le **type** de
/// [FlowCategory] : [Inconnu] est égal par code brut, un ensemble laisserait
/// passer `Inconnu('9')` quand `Inconnu(null)` est masqué.
final class MapFilter {
  const MapFilter({
    this.ecoulement = true,
    this.ecoulementFaible = true,
    this.ecoulementNonVisible = true,
    this.assec = true,
    this.nonObserve = true,
    this.inconnu = true,
    this.departementCode,
    this.dischargeFreshness = DischargeFreshnessCriterion.toutes,
  });

  /// Aucun critère actif.
  static const MapFilter none = MapFilter();

  final bool ecoulement;
  final bool ecoulementFaible;
  final bool ecoulementNonVisible;
  final bool assec;
  final bool nonObserve;

  /// Toute catégorie [Inconnu], quel que soit son code brut.
  final bool inconnu;

  /// Code du département retenu, ou `null` pour tous.
  final String? departementCode;

  final DischargeFreshnessCriterion dischargeFreshness;

  /// Vrai si une case est décochée ou si un département est retenu.
  bool get isActiveForFlow =>
      !ecoulement ||
      !ecoulementFaible ||
      !ecoulementNonVisible ||
      !assec ||
      !nonObserve ||
      !inconnu ||
      departementCode != null;

  /// Vrai si un département est retenu ou si la fraîcheur n'est pas `toutes`.
  bool get isActiveForDischarge =>
      departementCode != null ||
      dischargeFreshness != DischargeFreshnessCriterion.toutes;

  /// Dit si [category] reste affichée.
  bool shows(FlowCategory category) => switch (category) {
    Ecoulement() => ecoulement,
    EcoulementFaible() => ecoulementFaible,
    EcoulementNonVisible() => ecoulementNonVisible,
    Assec() => assec,
    NonObserve() => nonObserve,
    Inconnu() => inconnu,
  };

  MapFilter withCategory(FlowCategory category, {required bool shown}) =>
      switch (category) {
        Ecoulement() => _copy(ecoulement: shown),
        EcoulementFaible() => _copy(ecoulementFaible: shown),
        EcoulementNonVisible() => _copy(ecoulementNonVisible: shown),
        Assec() => _copy(assec: shown),
        NonObserve() => _copy(nonObserve: shown),
        Inconnu() => _copy(inconnu: shown),
      };

  MapFilter withDepartement(String? code) => MapFilter(
    ecoulement: ecoulement,
    ecoulementFaible: ecoulementFaible,
    ecoulementNonVisible: ecoulementNonVisible,
    assec: assec,
    nonObserve: nonObserve,
    inconnu: inconnu,
    departementCode: code,
    dischargeFreshness: dischargeFreshness,
  );

  MapFilter withDischargeFreshness(DischargeFreshnessCriterion criterion) =>
      MapFilter(
        ecoulement: ecoulement,
        ecoulementFaible: ecoulementFaible,
        ecoulementNonVisible: ecoulementNonVisible,
        assec: assec,
        nonObserve: nonObserve,
        inconnu: inconnu,
        departementCode: departementCode,
        dischargeFreshness: criterion,
      );

  MapFilter _copy({
    bool? ecoulement,
    bool? ecoulementFaible,
    bool? ecoulementNonVisible,
    bool? assec,
    bool? nonObserve,
    bool? inconnu,
  }) => MapFilter(
    ecoulement: ecoulement ?? this.ecoulement,
    ecoulementFaible: ecoulementFaible ?? this.ecoulementFaible,
    ecoulementNonVisible: ecoulementNonVisible ?? this.ecoulementNonVisible,
    assec: assec ?? this.assec,
    nonObserve: nonObserve ?? this.nonObserve,
    inconnu: inconnu ?? this.inconnu,
    departementCode: departementCode,
    dischargeFreshness: dischargeFreshness,
  );

  @override
  bool operator ==(Object other) =>
      other is MapFilter &&
      other.ecoulement == ecoulement &&
      other.ecoulementFaible == ecoulementFaible &&
      other.ecoulementNonVisible == ecoulementNonVisible &&
      other.assec == assec &&
      other.nonObserve == nonObserve &&
      other.inconnu == inconnu &&
      other.departementCode == departementCode &&
      other.dischargeFreshness == dischargeFreshness;

  @override
  int get hashCode => Object.hash(
    ecoulement,
    ecoulementFaible,
    ecoulementNonVisible,
    assec,
    nonObserve,
    inconnu,
    departementCode,
    dischargeFreshness,
  );

  @override
  String toString() =>
      'MapFilter(cases: $ecoulement/$ecoulementFaible/$ecoulementNonVisible/'
      '$assec/$nonObserve/$inconnu, departementCode: $departementCode, '
      'dischargeFreshness: ${dischargeFreshness.name})';
}
