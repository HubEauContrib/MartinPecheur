// Verrouille `lib/features/map/view_model/map_zoom_bounds.dart` — Dart pur,
// seule source de vérité pour `ignMaxNativeZoom`, `minimumMapZoom` et
// `maximumMapZoom` (relecture du coordinateur, 2026-09-23 : `MapViewModel`
// ne doit importer AUCUN fichier de `features/map/view/`).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view_model/map_zoom_bounds.dart';

void main() {
  test('ignMaxNativeZoom vaut 18, vérifié par appel réel (voir sa doc)', () {
    expect(ignMaxNativeZoom, 18);
  });

  test('minimumMapZoom est strictement sous maximumMapZoom', () {
    expect(minimumMapZoom, lessThan(maximumMapZoom));
  });

  test('maximumMapZoom est aligné sur ignMaxNativeZoom', () {
    expect(maximumMapZoom, ignMaxNativeZoom);
  });
}
