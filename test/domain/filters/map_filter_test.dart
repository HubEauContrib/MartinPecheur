import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';

/// `switch` sans `default` : compile tant que la nomenclature est close
/// (`BR-011`).
String _exhaustive(DischargeFreshnessCriterion criterion) =>
    switch (criterion) {
      DischargeFreshnessCriterion.toutes => 'toutes',
      DischargeFreshnessCriterion.moinsDe2h => '2h',
      DischargeFreshnessCriterion.moinsDe24h => '24h',
    };

void main() {
  const MapFilter none = MapFilter.none;

  group('MapFilter au départ', () {
    test('const MapFilter() == MapFilter.none', () {
      expect(const MapFilter(), MapFilter.none);
    });

    test('aucun critère actif', () {
      expect(none.isActiveForFlow, isFalse);
      expect(none.isActiveForDischarge, isFalse);
    });

    test('montre les six éléments et tout Inconnu', () {
      for (final FlowCategory category in filterableFlowCategories) {
        expect(none.shows(category), isTrue, reason: '$category');
      }
      expect(none.shows(const Inconnu('9')), isTrue);
      expect(none.shows(const Inconnu('')), isTrue);
    });
  });

  group('MapFilter.withCategory', () {
    test('masquer Assec ne masque que lui', () {
      final MapFilter filter = none.withCategory(const Assec(), shown: false);
      expect(filter.shows(const Assec()), isFalse);
      expect(filter.shows(const Ecoulement()), isTrue);
      expect(filter.shows(const EcoulementFaible()), isTrue);
      expect(filter.shows(const EcoulementNonVisible()), isTrue);
      expect(filter.shows(const NonObserve()), isTrue);
      expect(filter.shows(const Inconnu(null)), isTrue);
      expect(filter.isActiveForFlow, isTrue);
      expect(filter.isActiveForDischarge, isFalse);
    });

    test('masquer Inconnu(9) masque tout Inconnu mais pas NonObserve', () {
      final MapFilter filter = none.withCategory(
        const Inconnu('9'),
        shown: false,
      );
      expect(filter.shows(const Inconnu(null)), isFalse);
      expect(filter.shows(const Inconnu('9')), isFalse);
      expect(filter.shows(const Inconnu('x')), isFalse);
      expect(filter.shows(const NonObserve()), isTrue);
    });

    test('masquer NonObserve ne masque pas Inconnu', () {
      final MapFilter filter = none.withCategory(
        const NonObserve(),
        shown: false,
      );
      expect(filter.shows(const Inconnu(null)), isTrue);
      expect(filter.shows(const NonObserve()), isFalse);
    });

    test('décocher puis recocher rend MapFilter.none, pour les six', () {
      for (final FlowCategory category in filterableFlowCategories) {
        final MapFilter back = none
            .withCategory(category, shown: false)
            .withCategory(category, shown: true);
        expect(back, MapFilter.none, reason: '$category');
      }
    });

    test('les six cases à faux : valeur valide, actif pour l\'écoulement', () {
      MapFilter filter = none;
      for (final FlowCategory category in filterableFlowCategories) {
        filter = filter.withCategory(category, shown: false);
      }
      expect(filter.isActiveForFlow, isTrue);
      for (final FlowCategory category in filterableFlowCategories) {
        expect(filter.shows(category), isFalse, reason: '$category');
      }
    });
  });

  group('MapFilter département et fraîcheur', () {
    test('un département active les deux échelles', () {
      final MapFilter filter = none.withDepartement('24');
      expect(filter.departementCode, '24');
      expect(filter.isActiveForFlow, isTrue);
      expect(filter.isActiveForDischarge, isTrue);
      expect(filter.withDepartement(null), MapFilter.none);
    });

    test('une fraîcheur active le débit seulement', () {
      final MapFilter filter = none.withDischargeFreshness(
        DischargeFreshnessCriterion.moinsDe2h,
      );
      expect(filter.isActiveForDischarge, isTrue);
      expect(filter.isActiveForFlow, isFalse);
    });
  });

  group('MapFilter égalité', () {
    test('deux chemins, même filtre, même hashCode', () {
      final MapFilter a = none
          .withCategory(const Assec(), shown: false)
          .withDepartement('24');
      final MapFilter b = none
          .withDepartement('24')
          .withCategory(const Assec(), shown: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un champ différent rend les filtres inégaux (huit cas)', () {
      final List<MapFilter> different = <MapFilter>[
        const MapFilter(ecoulement: false),
        const MapFilter(ecoulementFaible: false),
        const MapFilter(ecoulementNonVisible: false),
        const MapFilter(assec: false),
        const MapFilter(nonObserve: false),
        const MapFilter(inconnu: false),
        const MapFilter(departementCode: '24'),
        const MapFilter(
          dischargeFreshness: DischargeFreshnessCriterion.moinsDe24h,
        ),
      ];
      expect(different, hasLength(8));
      for (final MapFilter filter in different) {
        expect(filter == MapFilter.none, isFalse, reason: '$filter');
      }
    });

    test('toString nomme le type', () {
      expect(none.toString(), contains('MapFilter'));
    });
  });

  group('dischargeFreshnessAdmits', () {
    const Map<DischargeFreshnessCriterion, List<bool>> table =
        <DischargeFreshnessCriterion, List<bool>>{
          DischargeFreshnessCriterion.toutes: <bool>[true, true, true],
          DischargeFreshnessCriterion.moinsDe2h: <bool>[true, false, false],
          DischargeFreshnessCriterion.moinsDe24h: <bool>[true, true, false],
        };
    // Ordre des colonnes : fraiche, ancienne, perimee.
    for (final MapEntry<DischargeFreshnessCriterion, List<bool>> row
        in table.entries) {
      for (int i = 0; i < Freshness.values.length; i++) {
        test('${row.key.name} / ${Freshness.values[i].name}', () {
          expect(
            dischargeFreshnessAdmits(row.key, Freshness.values[i]),
            row.value[i],
          );
        });
      }
    }

    test('les états de la table sont ceux de freshnessOf aux bornes', () {
      final DateTime now = DateTime.utc(2026, 10, 12, 12);
      expect(
        freshnessOf(measuredAt: now.subtract(ancienneApres), now: now),
        Freshness.ancienne,
      );
      expect(
        freshnessOf(
          measuredAt: now.subtract(perimeeApres - const Duration(seconds: 1)),
          now: now,
        ),
        Freshness.ancienne,
      );
    });
  });

  group('libellés', () {
    test('Toutes, Moins de 2 h, Moins de 24 h', () {
      expect(
        dischargeFreshnessCriterionLabel(DischargeFreshnessCriterion.toutes),
        'Toutes',
      );
      expect(
        dischargeFreshnessCriterionLabel(DischargeFreshnessCriterion.moinsDe2h),
        'Moins de 2 h',
      );
      expect(
        dischargeFreshnessCriterionLabel(
          DischargeFreshnessCriterion.moinsDe24h,
        ),
        'Moins de 24 h',
      );
    });

    test('les bornes sont lues dans freshness.dart', () {
      expect(
        dischargeFreshnessCriterionLabel(DischargeFreshnessCriterion.moinsDe2h),
        'Moins de ${ancienneApres.inHours} h',
      );
      expect(
        dischargeFreshnessCriterionLabel(
          DischargeFreshnessCriterion.moinsDe24h,
        ),
        'Moins de ${perimeeApres.inHours} h',
      );
    });

    test('filterableFlowCategories suit l\'ordre de la légende', () {
      expect(filterableFlowCategories.map(flowCategoryLabel).toList(), <String>[
        'Eau qui coule',
        'Écoulement faible',
        'Eau stagnante',
        'À sec',
        'Non observé',
        'Non renseigné',
      ]);
    });

    test('un switch sans default sur le critère compile (BR-011)', () {
      expect(
        DischargeFreshnessCriterion.values.map(_exhaustive).toList(),
        <String>['toutes', '2h', '24h'],
      );
    });
  });
}
