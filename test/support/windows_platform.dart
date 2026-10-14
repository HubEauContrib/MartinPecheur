// Tout test de widget nomme sa plateforme. `testWidgetsOnWindows` par défaut
// (Windows est la première cible) ; `testWidgetsOnAndroid` pour un test qui
// porte sur Android (cible de 48, mesures de téléphone), ce que son titre dit.
// `testWidgets` nu est interdit hors de `test/support/` : verrou
// `test/project/widget_test_platform_test.dart`. Pas de paramètre `variant`.
//
// Sous `flutter test` la plateforme par défaut est android, où la cible
// tactile est de 48 et non de 44 (la cible, elle, est un arbitrage du
// commanditaire du 2026-09-29, `K4` de T2 : 48 sur Android, 44 ailleurs) :
// les tests de disposition de Windows (taille minimale 800 × 740, `K3`) et
// les goldens, calibrés sur 44, doivent fixer la plateforme.
// `debugDefaultTargetPlatformOverride` doit être remis à `null` AVANT la
// vérification des invariants de fin de test — `setUp`/`tearDown`/
// `addTearDown` passent trop tard —, d'où ce `try/finally` autour du corps du
// test.
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:flutter_test/flutter_test.dart' show Timeout, WidgetTester;

void testWidgetsOnWindows(
  String description,
  Future<void> Function(WidgetTester tester) callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  Object? tags,
}) {
  ft.testWidgets(
    description,
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    tags: tags,
  );
}
