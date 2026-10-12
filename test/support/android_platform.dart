// Test de widget qui fixe la plateforme à Android (`N1` de T3, dette 1 de
// T2) : cible tactile de 48 (arbitrage du commanditaire du 2026-09-29, `K4`
// de T2), mesures de téléphone.
//
// La convention est dite une fois, en tête de `windows_platform.dart` : tout
// test de widget nomme sa plateforme, et le titre d'un test passé par cet
// assistant dit « Android ».
//
// La plateforme est posée EXPLICITEMENT : l'assistant ne se repose pas sur le
// défaut de `flutter test`, qui se trouve être android aujourd'hui.
// `debugDefaultTargetPlatformOverride` doit être remis à `null` AVANT la
// vérification des invariants de fin de test — `setUp`/`tearDown`/
// `addTearDown` passent trop tard —, d'où ce `try/finally` autour du corps du
// test.
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:flutter_test/flutter_test.dart' show Timeout, WidgetTester;

void testWidgetsOnAndroid(
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
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
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
