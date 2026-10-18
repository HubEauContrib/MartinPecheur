// L1 d'Ergonomie (arbitrage 8) : le menu d'un texte sélectionnable de
// l'application est en français. Libellés lus dans le SDK :
// `packages/flutter_localizations/lib/src/l10n/material_fr.arb`
// (`copyButtonLabel` « Copier », `selectAllButtonLabel` « Tout sélectionner »).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';

import '../../../support/android_platform.dart';
import '../../../support/windows_platform.dart';
import '../zones_samples.dart';

/// `true` : la configuration de `lib/main.dart` (locale `fr`, délégués de
/// `GlobalMaterialLocalizations`) ; `false` : sans elle, pour prouver que le
/// test peut échouer.
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  bool localized = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: localized
          ? GlobalMaterialLocalizations.delegates
          : null,
      supportedLocales: localized
          ? const <Locale>[Locale('fr')]
          : const <Locale>[Locale('en', 'US')],
      locale: localized ? const Locale('fr') : const Locale('en', 'US'),
      home: RestrictionsScreen(
        state: ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
        onChooseProfile: (UserProfile _) {},
        onRetry: () {},
        onOpenDocument: (DocumentLink _, LinkTarget _) {},
        onOpenPublicSite: () {},
        utcOffsetOf: (DateTime _) => const Duration(hours: 2),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _selectable = find.widgetWithText(
  SelectableText,
  restrictionsPublicSiteUrl,
);

Future<void> _rightClick(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(_selectable), buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

void main() {
  for (final bool localized in <bool>[true, false]) {
    final String copy = localized ? 'Copier' : 'Copy';
    final String selectAll = localized ? 'Tout sélectionner' : 'Select all';
    final String share = localized ? 'Partager' : 'Share';
    final String name = localized ? 'en français' : 'sans délégués, en anglais';

    testWidgetsOnWindows(
      'L1 : le menu du clic droit d\'un texte sélectionnable est $name',
      (WidgetTester tester) async {
        await _pump(tester, size: const Size(1266, 741), localized: localized);
        await tester.ensureVisible(_selectable);
        await tester.pumpAndSettle();

        // Rien n'est sélectionné : le menu ne propose que « Tout sélectionner ».
        await _rightClick(tester);
        expect(find.text(selectAll), findsOneWidget);

        // Le texte sélectionné, le menu propose « Copier ».
        await tester.tap(find.text(selectAll));
        await tester.pumpAndSettle();
        await _rightClick(tester);
        expect(find.text(copy), findsOneWidget);
      },
    );

    testWidgetsOnAndroid(
      'Android : le menu d\'appui long d\'un texte sélectionnable est $name',
      (WidgetTester tester) async {
        await _pump(tester, size: const Size(390, 844), localized: localized);
        await tester.ensureVisible(_selectable);
        await tester.pumpAndSettle();

        await tester.longPress(_selectable);
        await tester.pumpAndSettle();

        expect(find.text(copy), findsOneWidget);
        expect(find.text(share), findsOneWidget);

        // « Tout sélectionner » est, en français, dans la page de débordement
        // de la barre (derrière « more_vert ») ; en anglais, tout tient.
        final Finder more = find.byIcon(Icons.more_vert);
        if (more.evaluate().isNotEmpty) {
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        expect(find.text(selectAll), findsOneWidget);
      },
    );
  }
}
