// Verrouille le pont entre le filtre du domaine (`MapFilter`, qui ignore les
// échelles de la carte) et l'échelle active de la tranche carte (F4 de T3).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/filters/map_filter.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/features/map/view_model/map_filter_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';

void main() {
  test("aucun critère : inactif sur l'écoulement comme sur le débit", () {
    expect(
      mapFilterActiveFor(MapFilter.none, MapScaleKind.ecoulement),
      isFalse,
    );
    expect(mapFilterActiveFor(MapFilter.none, MapScaleKind.debit), isFalse);
  });

  test("une case décochée : actif sur l'écoulement seulement", () {
    final MapFilter filter = MapFilter.none.withCategory(
      const Assec(),
      shown: false,
    );

    expect(mapFilterActiveFor(filter, MapScaleKind.ecoulement), isTrue);
    expect(mapFilterActiveFor(filter, MapScaleKind.debit), isFalse);
  });

  test('un critère de fraîcheur : actif sur le débit seulement', () {
    final MapFilter filter = MapFilter.none.withDischargeFreshness(
      DischargeFreshnessCriterion.moinsDe2h,
    );

    expect(mapFilterActiveFor(filter, MapScaleKind.ecoulement), isFalse);
    expect(mapFilterActiveFor(filter, MapScaleKind.debit), isTrue);
  });

  test('un département : actif sur les deux échelles', () {
    final MapFilter filter = MapFilter.none.withDepartement('41');

    expect(mapFilterActiveFor(filter, MapScaleKind.ecoulement), isTrue);
    expect(mapFilterActiveFor(filter, MapScaleKind.debit), isTrue);
  });
}
