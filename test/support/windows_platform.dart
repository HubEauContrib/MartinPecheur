// `testWidgets` qui fixe la plateforme à Windows (arbitrage du commanditaire du
// 2026-09-29, `K4` de T2 : cible tactile de 48 sur Android, 44 ailleurs).
//
// Sous `flutter test` la plateforme par défaut est android : les tests de
// disposition de Windows (taille minimale 800 × 740, `K3`) et les goldens,
// calibrés sur 44, doivent la fixer. `debugDefaultTargetPlatformOverride`
// doit être remis à `null` AVANT la vérification des invariants de fin de
// test — `setUp`/`tearDown`/`addTearDown` passent trop tard —, d'où ce
// `try/finally` autour du corps du test.
//
// N'utiliser `testWidgetsOnWindows` que pour les tests qui en ont besoin : les
// autres restent en `testWidgets`. Pas de paramètre `variant` : le test tourne
// sous Windows, point.
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
