// Verrouille la cible tactile minimale (`K4` de T2, arbitrage du commanditaire
// du 2026-09-29) : 48 sur Android, 44 partout ailleurs, Windows et iOS
// compris. Sous `flutter test` la plateforme par défaut est android.
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

void main() {
  group('minimumTapTargetFor', () {
    test('android donne 48', () {
      expect(minimumTapTargetFor(TargetPlatform.android), 48.0);
    });

    test('windows, iOS, linux et macOS donnent 44', () {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        expect(minimumTapTargetFor(platform), 44.0, reason: '$platform');
      }
    });

    test('fuchsia donne 44 (seul android vaut 48)', () {
      expect(minimumTapTargetFor(TargetPlatform.fuchsia), 44.0);
    });
  });

  group('minimumTapTarget lit defaultTargetPlatform', () {
    test('android → 48', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(minimumTapTarget, 48.0);
    });

    test('windows → 44', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(minimumTapTarget, 44.0);
    });
  });

  group('sur un widget réel (WarningLink)', () {
    Future<Size> sizeOf(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WarningLink())),
      );
      return tester.getSize(find.byKey(warningLinkKey));
    }

    testWidgets('android : au moins 48 × 48 dp', (WidgetTester tester) async {
      final Size size = await sizeOf(tester);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('windows : au moins 44 × 44 pt', (WidgetTester tester) async {
      final Size size = await sizeOf(tester);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
