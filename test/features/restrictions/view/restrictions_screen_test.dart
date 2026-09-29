// Verrouille l'ecran des restrictions (E2 de T2), selon la conception
// arbitree (`docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md`) :
// ecran plein (Q-1), ordre du § 3 (Q-3), textes des § 5.1 a 5.3 mot pour
// mot (Q-5a/b/c/e), echec imprevu neutre (Q-5d, `RestrictionsNonObtenues`),
// arretes dedoublonnes (Q-6), badge a cote de son libelle (Q-7).
//
// Les zones viennent de `zones_samples.dart` (valeurs recopiees des
// fixtures) : ce test ne lit jamais `lib/data/`. L'encart renforce (E4) est
// verrouille ici par son ordre et sa tenue au defilement ; sa surface l'est
// dans `reinforced_warning_card_test.dart`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';
import 'package:martinpecheur/features/restrictions/view/reinforced_warning_card.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/windows_platform.dart';
import '../zones_samples.dart';
import 'drought_severity_badge_test.dart' show contrastRatio;

/// Heure de Paris en ete : les captures du 2026-09-27 sont en UTC+2.
Duration _paris(DateTime _) => const Duration(hours: 2);

const String _brSept =
    "Cela ne signifie pas qu'aucun arrêté ne s'applique : vérifiez auprès "
    'de votre préfecture.';

Widget _screen(
  RestrictionsState state, {
  UserProfile? profile,
  ValueChanged<UserProfile>? onChooseProfile,
  VoidCallback? onRetry,
  ValueChanged<DocumentLink>? onOpenDocument,
  VoidCallback? onOpenPublicSite,
  String? unopenedLink,
}) => RestrictionsScreen(
  state: state,
  profile: profile,
  onChooseProfile: onChooseProfile ?? (UserProfile _) {},
  onRetry: onRetry ?? () {},
  onOpenDocument: onOpenDocument,
  onOpenPublicSite: onOpenPublicSite ?? () {},
  unopenedLink: unopenedLink,
  utcOffsetOf: _paris,
);

Future<void> _pump(
  WidgetTester tester,
  RestrictionsState state, {
  UserProfile? profile,
  ValueChanged<UserProfile>? onChooseProfile,
  VoidCallback? onRetry,
  ValueChanged<DocumentLink>? onOpenDocument,
  VoidCallback? onOpenPublicSite,
  String? unopenedLink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _screen(
        state,
        profile: profile,
        onChooseProfile: onChooseProfile,
        onRetry: onRetry,
        onOpenDocument: onOpenDocument,
        onOpenPublicSite: onOpenPublicSite,
        unopenedLink: unopenedLink,
      ),
    ),
  );
  // La disposition de l'encart (épinglé ou non) se décide au passage suivant.
  await tester.pump();
}

/// Ordonnee du haut de [finder] — l'ordre du § 3 se lit de haut en bas
/// (tout est construit : l'ecran defile une colonne, pas une liste
/// paresseuse).
double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

/// Le defilement de l'ecran — pas celui, interne, d'un `SelectableText`.
final Finder _mainScrollable = find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

/// Tous les textes affiches (Text, RichText, SelectableText).
Iterable<String> _allTexts(WidgetTester tester) sync* {
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    yield rich.text.toPlainText();
  }
  for (final EditableText editable in tester.widgetList<EditableText>(
    find.byType(EditableText),
  )) {
    yield editable.controller.text;
  }
}

/// Vrai si un `RichText` porte un `TextSpan` dont le texte est EXACTEMENT
/// [text] — egalite sur la chaine entiere, `\n` et espaces de fin compris.
Finder _spanExactly(String text) => find.byWidgetPredicate((Widget widget) {
  if (widget is! RichText) {
    return false;
  }
  bool found = false;
  widget.text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == text) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
});

void main() {
  group('forme (Q-1) : écran plein, titre, retour', () {
    testWidgets('barre de titre « Sécheresse et restrictions »', (
      WidgetTester tester,
    ) async {
      await _pump(tester, RestrictionsEnCours(pointAin()));
      expect(find.text('Sécheresse et restrictions'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('RestrictionsFermees : aucun contenu d état', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const RestrictionsFermees());
      expect(find.text('Sécheresse et restrictions'), findsOneWidget);
      expect(find.textContaining('Point désigné'), findsNothing);
      expect(find.byType(DroughtSeverityBadge), findsNothing);
    });

    testWidgets('Échap et le bouton de retour retirent la route (maybePop)', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('carte')),
      );
      for (final bool byEscape in <bool>[true, false]) {
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => _screen(ZonesTrouvees(zonesAin())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sécheresse et restrictions'), findsOneWidget);

        if (byEscape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.text('Sécheresse et restrictions'), findsNothing);
        expect(find.text('carte'), findsOneWidget);
      }
    });
  });

  group('point interrogé et chargement', () {
    testWidgets('RestrictionsEnCours : point rappelé, texte de chargement, '
        'aucun badge ni niveau (BR-007)', (WidgetTester tester) async {
      await _pump(tester, RestrictionsEnCours(pointAin()));
      expect(
        find.text('Point désigné : 46,20000° N, 5,22600° E'),
        findsOneWidget,
      );
      expect(
        find.text("Recherche des zones d'alerte pour ce point…"),
        findsOneWidget,
      );
      expect(find.byType(DroughtSeverityBadge), findsNothing);
      for (final DroughtSeverity level in droughtSeverityScale) {
        expect(find.textContaining(droughtSeverityLabel(level)), findsNothing);
      }
    });

    testWidgets('latitude et longitude négatives : S et O, cinq décimales', (
      WidgetTester tester,
    ) async {
      await _pump(tester, RestrictionsEnCours(pointGuyane()));
      expect(
        find.text('Point désigné : 4,90000° N, 52,30000° O'),
        findsOneWidget,
      );
    });
  });

  group('ZonesTrouvees (Ain) — zones, niveaux datés, échelles', () {
    testWidgets('zone SUP d abord, puis « Autres zones au même point », sa '
        'phrase, et les autres sous leur libellé de type', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));

      final double sup = _top(tester, find.text('Eaux superficielles'));
      final double supName = _top(tester, find.text('Rivières de Bresse'));
      final double autres = _top(
        tester,
        find.text('Autres zones au même point'),
      );
      final double phrase = _top(
        tester,
        find.text(
          "Le point désigné se trouve aussi dans ces zones d'alerte. Chacune "
          'a son niveau et ses usages.',
        ),
      );
      final double sou = _top(
        tester,
        find.text('Eaux souterraines — Dombes - Certines - Nord').first,
      );
      final double aep = _top(
        tester,
        find.text('Eau potable — Rivières de Bresse').first,
      );
      expect(sup, lessThan(supName));
      expect(supName, lessThan(autres));
      expect(autres, lessThan(phrase));
      expect(phrase, lessThan(sou));
      expect(sou, lessThan(aep));
    });

    testWidgets('chaque zone : badge, libellé daté « depuis le » dans le même '
        'texte (BR-001), date de fin, échelle complète marquée', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));

      expect(find.text('Alerte · depuis le 20/08/2026'), findsNWidgets(2));
      expect(find.text('Vigilance · depuis le 20/08/2026'), findsOneWidget);
      expect(find.text("jusqu'au 31/10/2026"), findsNWidgets(3));

      // Un badge par niveau de zone, plus quatre par échelle : une échelle
      // par zone, jamais une échelle commune.
      // Plus un par zone de la liste « S'applique à » de l'arrêté.
      expect(find.byType(DroughtSeverityBadge), findsNWidgets(3 + 3 * 4 + 3));
      expect(find.text('Échelle :'), findsNWidgets(3));
      expect(find.text('Alerte ← cette zone'), findsNWidgets(2));
      expect(find.text('Vigilance ← cette zone'), findsOneWidget);
      expect(find.text('Alerte renforcée'), findsNWidgets(3));
      expect(find.text('Crise'), findsNWidgets(3));
      // Niveaux nus : un par échelle, plus un par ligne de la liste de
      // l'arrêté (le niveau à côté du badge, Q-7).
      expect(find.text('Vigilance'), findsNWidgets(3));
      expect(find.text('Alerte'), findsNWidgets(3));
    });

    testWidgets('le libellé est posé à côté du badge, jamais dans le badge '
        '(Q-7)', (WidgetTester tester) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        find.descendant(
          of: find.byType(DroughtSeverityBadge),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('lecteur d écran : le niveau est nommé comme gravité', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        find.bySemanticsLabel(
          'Niveau de gravité : Alerte, depuis le 20 août 2026',
        ),
        findsNWidgets(2),
      );
      handle.dispose();
    });

    testWidgets('lecteur d écran : la ligne marquée de l échelle est lue « '
        'niveau de cette zone », jamais la flèche', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        find.bySemanticsLabel('Alerte, niveau de cette zone'),
        findsNWidgets(2),
      );
      expect(
        find.bySemanticsLabel('Vigilance, niveau de cette zone'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('←')), findsNothing);
      handle.dispose();
    });

    testWidgets('date de fin absente : phrase de C1', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupSansDateDeFin()])),
      );
      expect(
        find.text('Date de fin non transmise par la source.'),
        findsOneWidget,
      );
      expect(find.textContaining("jusqu'au"), findsNothing);
    });

    testWidgets('date de récupération, à l heure locale injectée (Q7-A)', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        find.text('Réponse de VigiEau obtenue le 27/09/2026 à 13:25'),
        findsOneWidget,
      );
    });

    testWidgets('type de zone inconnu : libellé fixe, valeur brute cachée', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup(), ainTypeInconnu()])),
      );
      expect(
        find.text('Type de zone non renseigné — Rivières de Bresse'),
        findsNWidgets(2), // bloc de la zone + liste de l'arrêté
      );
      expect(find.textContaining('XYZ'), findsNothing);
    });
  });

  group('gravité inconnue (BR-011, Q-5c)', () {
    testWidgets('« Non renseigné », badge #767676, phrase de BR-007, aucune '
        'position marquée', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupGraviteInconnue()])),
      );
      expect(find.text('Non renseigné · depuis le 20/08/2026'), findsOneWidget);
      expect(find.text(_brSept), findsOneWidget);
      expect(
        _top(tester, find.text(_brSept)),
        greaterThan(
          _top(tester, find.text('Non renseigné · depuis le 20/08/2026')),
        ),
      );
      expect(find.textContaining('← cette zone'), findsNothing);

      final DroughtSeverityBadge badge = tester.widget<DroughtSeverityBadge>(
        find.byType(DroughtSeverityBadge).first,
      );
      expect(badge.severity, const GraviteInconnue(null));
      expect(droughtBadgeStyle(badge.severity).tint, const Color(0xFF767676));
    });
  });

  group('ordre du contenu (Q-3)', () {
    testWidgets('zones, puis « Arrêtés », puis « Profil d usager », puis les '
        'usages', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
      );
      final double lastZone = _top(
        tester,
        find.text('Eau potable — Rivières de Bresse').first,
      );
      final double decrees = _top(tester, find.text('Arrêtés'));
      final double profile = _top(tester, find.text("Profil d'usager"));
      final double usages = _top(
        tester,
        find.text('Usages restreints pour le profil Particulier'),
      );
      expect(lastZone, lessThan(decrees));
      expect(decrees, lessThan(profile));
      expect(profile, lessThan(usages));
    });
  });

  group('profil d usager (Q-3, Q-5b)', () {
    testWidgets('profil nul : quatre choix, aucun coché, groupe exclusif, '
        'aucune liste d usages, phrase de C1', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZonesTrouvees(zonesAin()));

      for (final String label in <String>[
        'Particulier',
        'Exploitation',
        'Collectivité',
        'Entreprise',
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(
            label: label,
            hasCheckedState: true,
            isChecked: false,
            isInMutuallyExclusiveGroup: true,
          ),
        );
      }
      expect(
        find.text(
          "Les usages restreints s'affichent une fois un profil "
          'choisi.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Usages restreints pour'), findsNothing);
      expect(
        find.text(
          'Arrosage des centres équestres et carrières équestres',
          findRichText: true,
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('chaque choix mesure au moins minimumTapTarget de haut', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      for (final UserProfile profile in UserProfile.values) {
        final Size size = tester.getSize(
          find.byKey(restrictionsProfileChoiceKey(profile)),
        );
        expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
        expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      }
    });

    testWidgets('choisir un profil appelle onChooseProfile', (
      WidgetTester tester,
    ) async {
      final List<UserProfile> chosen = <UserProfile>[];
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onChooseProfile: chosen.add,
      );
      await tester.ensureVisible(find.text('Exploitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exploitation'));
      await tester.pump();
      expect(chosen, <UserProfile>[UserProfile.exploitation]);
    });

    testWidgets('profil posé : coché, rappelé, attribution, usages groupés '
        'par zone dans l ordre des zones, thème non affiché', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
      );
      expect(
        tester.getSemantics(find.text('Particulier')),
        isSemantics(
          label: 'Particulier',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      final double title = _top(
        tester,
        find.text('Usages restreints pour le profil Particulier'),
      );
      final double attribution = _top(
        tester,
        find.text(
          "Textes cités tels que transmis par VigiEau. Seul l'arrêté fait "
          'foi.',
        ),
      );
      // Groupes : titre « type — nom » (le second exemplaire de chaque, le
      // premier étant le bloc de zone ou n'existant que pour les autres
      // zones).
      final double groupSup = _top(
        tester,
        find.text('Eaux superficielles — Rivières de Bresse').last,
      );
      final double groupSou = _top(
        tester,
        find.text('Eaux souterraines — Dombes - Certines - Nord').last,
      );
      final double groupAep = _top(
        tester,
        find.text('Eau potable — Rivières de Bresse').last,
      );
      expect(title, lessThan(attribution));
      expect(attribution, lessThan(groupSup));
      expect(groupSup, lessThan(groupSou));
      expect(groupSou, lessThan(groupAep));

      // SUP : deux usages du profil, dans l'ordre de la source.
      final double fontaines = _top(
        tester,
        find.text(
          'Alimentation des fontaines publiques et privées d’ornement',
          findRichText: true,
        ),
      );
      final double equestres = _top(
        tester,
        find
            .text(
              'Arrosage des centres équestres et carrières équestres',
              findRichText: true,
            )
            .first,
      );
      expect(groupSup, lessThan(fontaines));
      expect(fontaines, lessThan(equestres));
      expect(equestres, lessThan(groupSou));

      // SOU : aucun usage pour ce profil — la phrase de C1, jamais une
      // phrase de neutralité.
      final Finder none = find.text(
        'VigiEau ne transmet aucun usage pour le profil Particulier dans '
        "cette zone. Seul l'arrêté fait foi : consultez-le.",
      );
      expect(none, findsOneWidget);
      expect(_top(tester, none), greaterThan(groupSou));
      expect(_top(tester, none), lessThan(groupAep));

      // Usages exploitation seuls : absents.
      expect(
        find.text('Abreuvement des animaux', findRichText: true),
        findsNothing,
      );
      // Thème (`thematique`) non affiché (Q-5e).
      expect(find.text('Arroser', findRichText: true), findsNothing);
      expect(
        find.text(
          'Alimenter des fontaines et autres usages de loisirs',
          findRichText: true,
        ),
        findsNothing,
      );
      // Chaque groupe porte son niveau daté.
      expect(find.text('Alerte · depuis le 20/08/2026'), findsNWidgets(4));
      handle.dispose();
    });

    testWidgets('description rendue à l identique, \\n et espace de fin '
        'compris, guillemets hors de la chaîne (BR-014)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAriege()),
        profile: UserProfile.exploitation,
      );
      expect(_spanExactly(descriptionIrrigationAriege), findsOneWidget);
      expect(_spanExactly('Interdiction totale '), findsOneWidget);
      expect(
        _spanExactly(
          'Irrigation agricole des cultures (sauf retenues déconnectées) ',
        ),
        findsOneWidget,
      );
      final RichText quoted = tester.widget<RichText>(
        _spanExactly(descriptionIrrigationAriege),
      );
      expect(quoted.text.toPlainText(), '« $descriptionIrrigationAriege »');
    });
  });

  group('arrêtés (Q-6, UC-002 A6)', () {
    testWidgets('Ain : un arrêté et un arrêté-cadre, une fois chacun, les '
        'trois zones nommées', (WidgetTester tester) async {
      final List<DocumentLink> opened = <DocumentLink>[];
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: opened.add,
      );

      expect(find.text('Arrêté de restriction'), findsOneWidget);
      expect(find.text('Arrêté-cadre'), findsOneWidget);
      expect(find.widgetWithText(SelectableText, decreeUrlAin), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, frameworkUrlAin),
        findsOneWidget,
      );
      // Les trois zones citées à l'identique, une fois chacune, dans la
      // carte de l'arrêté de restriction ; l'arrêté-cadre a les mêmes.
      expect(find.text("S'applique à 3 zones"), findsOneWidget);
      expect(find.text("S'applique aux 3 mêmes zones"), findsOneWidget);
      for (final String title in <String>[
        'Eaux superficielles — Rivières de Bresse',
        'Eaux souterraines — Dombes - Certines - Nord',
        'Eau potable — Rivières de Bresse',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(
              restrictionsDecreeCardKey(decreeUrlAin, framework: false),
            ),
            matching: find.text(title),
          ),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Arrêté du'), findsNothing);

      await tester.ensureVisible(find.text("Ouvrir l'arrêté"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ouvrir l'arrêté"));
      await tester.ensureVisible(find.text("Ouvrir l'arrêté-cadre"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ouvrir l'arrêté-cadre"));
      expect(opened, const <DocumentLink>[
        DocumentLink(decreeUrlAin),
        DocumentLink(frameworkUrlAin),
      ]);
    });

    testWidgets('Paris : même arrêté pour trois zones -> une entrée, adresse '
        'brute gardée telle quelle', (WidgetTester tester) async {
      await _pump(tester, ZonesTrouvees(zonesParis()));
      expect(find.text('Arrêté de restriction'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, decreeUrlParis),
        findsOneWidget,
      );
      expect(find.text("S'applique à 3 zones"), findsOneWidget);
      for (final String title in <String>[
        'Eaux superficielles — Bassins de la Marne et de la Seine',
        'Eaux souterraines — Bassins de la Marne et de la Seine',
        'Eau potable — Bassins de la Marne et de la Seine',
      ]) {
        expect(find.text(title), findsWidgets);
      }
    });

    testWidgets('deux adresses différentes -> deux entrées', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup(), ariegeSup()])),
      );
      expect(find.text('Arrêté de restriction'), findsNWidgets(2));
      expect(find.text('Arrêté-cadre'), findsNWidgets(2));
    });

    testWidgets('adresse non ouvrable : visible, aucune action, phrase de C1', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupAdresseNonOuvrable()])),
        onOpenDocument: (DocumentLink _) {},
      );
      expect(
        find.widgetWithText(SelectableText, relativeDecreeUrl),
        findsOneWidget,
      );
      expect(find.text("Ouvrir l'arrêté"), findsNothing);
      expect(
        find.text(
          "Cette adresse ne peut pas être ouverte depuis "
          "l'application.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('zone sans arrêté : phrase de C1 dans le bloc de la zone', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupSansArrete(), ainSou()])),
      );
      final Finder phrase = find.text(
        "Le texte de l'arrêté n'est pas accessible depuis l'application : la "
        "source n'en transmet pas l'adresse.",
      );
      expect(phrase, findsOneWidget);
      expect(
        _top(tester, phrase),
        greaterThan(_top(tester, find.text('Rivières de Bresse'))),
      );
      expect(
        _top(tester, phrase),
        lessThan(_top(tester, find.text('Autres zones au même point'))),
      );
    });

    testWidgets('lien qui ne s est pas ouvert : adresse gardée, phrase de C1 '
        'sous elle', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
        unopenedLink: decreeUrlAin,
      );
      final Finder phrase = find.text(
        "Ce lien n'a pas pu être ouvert depuis l'application. Son adresse "
        'reste affichée ci-dessus.',
      );
      expect(phrase, findsOneWidget);
      expect(
        _top(tester, phrase),
        greaterThan(
          _top(tester, find.widgetWithText(SelectableText, decreeUrlAin)),
        ),
      );
      expect(
        _top(tester, phrase),
        lessThan(
          _top(tester, find.widgetWithText(SelectableText, frameworkUrlAin)),
        ),
      );
    });

    testWidgets('sans onOpenDocument : aucune action d ouverture', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(find.text("Ouvrir l'arrêté"), findsNothing);
      expect(find.widgetWithText(SelectableText, decreeUrlAin), findsOneWidget);
    });
  });

  // Section « Arrêtés » en cartes (arbitrage du commanditaire du 2026-09-29,
  // canvas de design) : amendement de la conception T2 § 6.
  group('arrêtés en cartes (amendement du 2026-09-29)', () {
    /// Une zone de l'Ain dont [decree] est remplacé — un champ change.
    AlertZone withDecree(AlertZone zone, RestrictionDecree decree) => AlertZone(
      name: zone.name,
      kind: zone.kind,
      severity: zone.severity,
      decree: decree,
      usages: zone.usages,
    );

    Finder card(String raw, {bool framework = false}) =>
        find.byKey(restrictionsDecreeCardKey(raw, framework: framework));

    Finder within(String raw, Finder matching) => find.descendant(
      of: card(raw, framework: raw == frameworkUrlAin),
      matching: matching,
    );

    testWidgets('en-tête : titre gardé et « N documents pour ce point »', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(find.text('Arrêtés'), findsOneWidget);
      expect(find.text('2 documents pour ce point'), findsOneWidget);
      expect(
        _top(tester, find.text('Arrêtés')),
        lessThan(_top(tester, find.text('2 documents pour ce point'))),
      );
    });

    testWidgets('en-tête au singulier : « 1 document pour ce point »', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupSansDateDeFin()])),
      );
      expect(find.text('1 document pour ce point'), findsOneWidget);
      expect(find.text('2 documents pour ce point'), findsNothing);
    });

    testWidgets('chaque document est une carte : bordure 1 px #C9CFC4, rayon '
        '12, fond blanc, sans bordure gauche colorée', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      for (final String raw in <String>[decreeUrlAin, frameworkUrlAin]) {
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: card(raw, framework: raw == frameworkUrlAin),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final BoxDecoration decoration = box.decoration as BoxDecoration;
        expect(decoration.color, Colors.white);
        expect(decoration.borderRadius, BorderRadius.circular(12));
        expect(decoration.border, Border.all(color: const Color(0xFFC9CFC4)));
      }
    });

    testWidgets('tête : icônes distinctes, titre en gras', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        within(decreeUrlAin, find.byIcon(Icons.description_outlined)),
        findsOneWidget,
      );
      expect(
        within(frameworkUrlAin, find.byIcon(Icons.article_outlined)),
        findsOneWidget,
      );
      final Text title = tester.widget<Text>(
        within(decreeUrlAin, find.text('Arrêté de restriction')),
      );
      expect(title.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('dates identiques pour toutes les zones : « Du … au … »', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        within(decreeUrlAin, find.text('Du 20/08/2026 au 31/10/2026')),
        findsOneWidget,
      );
      // Pas de ligne de dates sur l'arrêté-cadre.
      expect(within(frameworkUrlAin, find.textContaining('Du ')), findsNothing);
    });

    testWidgets('date de fin nulle pour toutes les zones : « Depuis le … »', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupSansDateDeFin()])),
      );
      expect(find.text('Depuis le 20/08/2026'), findsOneWidget);
      expect(find.textContaining('Du 20'), findsNothing);
    });

    testWidgets('dates différentes entre zones : aucune ligne de date', (
      WidgetTester tester,
    ) async {
      final AlertZone other = withDecree(
        ainSou(),
        RestrictionDecree(
          validFrom: DateTime.utc(2026, 8, 20),
          validUntil: DateTime.utc(2026, 11, 15),
          document: const DocumentLink(decreeUrlAin),
        ),
      );
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup(), other])),
      );
      expect(find.textContaining('Du 20/08/2026'), findsNothing);
      expect(find.textContaining('Depuis le'), findsNothing);
      expect(find.text("S'applique à 2 zones"), findsOneWidget);
    });

    testWidgets('même adresse pour l arrêté et pour le cadre : deux cartes, '
        'clés distinctes, aucune exception', (WidgetTester tester) async {
      const String shared = 'https://example.org/commun.pdf';
      await _pump(
        tester,
        ZonesTrouvees(
          zonesAinWith(<AlertZone>[
            withDecree(
              ainSup(),
              RestrictionDecree(
                validFrom: DateTime.utc(2026, 8, 20),
                validUntil: DateTime.utc(2026, 10, 31),
                document: const DocumentLink(shared),
                frameworkDocument: const DocumentLink(shared),
              ),
            ),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Arrêté de restriction'), findsOneWidget);
      expect(find.text('Arrêté-cadre'), findsOneWidget);
      expect(
        find.byKey(restrictionsDecreeCardKey(shared, framework: false)),
        findsOneWidget,
      );
      expect(
        find.byKey(restrictionsDecreeCardKey(shared, framework: true)),
        findsOneWidget,
      );
    });

    // Verrou (passe d'emblée) : un désaccord entre zones, y compris fin
    // nulle contre fin datée, n'affiche aucune date.
    testWidgets('une zone à fin nulle, l autre à fin datée : aucune ligne de '
        'dates', (WidgetTester tester) async {
      final AlertZone open = withDecree(
        ainSou(),
        RestrictionDecree(
          validFrom: DateTime.utc(2026, 8, 20),
          document: const DocumentLink(decreeUrlAin),
        ),
      );
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup(), open])),
      );
      expect(find.textContaining('Du 20/08/2026'), findsNothing);
      expect(find.textContaining('Depuis le'), findsNothing);
    });

    testWidgets(
      "une zone : « à 1 zone » et, sur le cadre, « à la même zone » sans liste",
      (WidgetTester tester) async {
        await _pump(tester, ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup()])));
        expect(
          within(decreeUrlAin, find.text("S'applique à 1 zone")),
          findsOneWidget,
        );
        expect(
          within(frameworkUrlAin, find.text("S'applique à la même zone")),
          findsOneWidget,
        );
        expect(
          within(frameworkUrlAin, find.byType(DroughtSeverityBadge)),
          findsNothing,
        );
      },
    );

    testWidgets('arrêté-cadre dont les zones diffèrent de celles de '
        'l\'arrêté : la liste, comme la restriction', (
      WidgetTester tester,
    ) async {
      // ainSou : même arrêté, aucun arrêté-cadre -> le cadre ne couvre que
      // ainSup.
      final AlertZone withoutFramework = withDecree(
        ainSou(),
        RestrictionDecree(
          validFrom: DateTime.utc(2026, 8, 20),
          validUntil: DateTime.utc(2026, 10, 31),
          document: const DocumentLink(decreeUrlAin),
        ),
      );
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSup(), withoutFramework])),
      );
      expect(find.textContaining('mêmes zones'), findsNothing);
      expect(find.textContaining('la même zone'), findsNothing);
      expect(
        within(frameworkUrlAin, find.text("S'applique à 1 zone")),
        findsOneWidget,
      );
      expect(
        within(
          frameworkUrlAin,
          find.text('Eaux superficielles — Rivières de Bresse'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('liste : une ligne par zone, badge, titre et niveau en gras '
        'à côté, noms à l\'identique', (WidgetTester tester) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        within(decreeUrlAin, find.byType(DroughtSeverityBadge)),
        findsNWidgets(3),
      );
      // Dernière ligne (eau potable, alerte) : titre court, tient à côté.
      final Finder level = within(decreeUrlAin, find.text('Alerte')).last;
      expect(find.text('Vigilance'), findsWidgets);
      expect(tester.widget<Text>(level).style?.fontWeight, FontWeight.bold);
      // Le niveau est à côté du titre de sa zone (même ligne), jamais dans
      // le badge.
      final Finder title = within(
        decreeUrlAin,
        find.text('Eau potable — Rivières de Bresse'),
      );
      expect(
        (tester.getTopLeft(level).dy - tester.getTopLeft(title).dy).abs(),
        lessThan(2),
      );
      expect(
        find.descendant(
          of: find.byType(DroughtSeverityBadge),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('lecteur d écran : « titre, niveau de gravité : niveau » par '
        'ligne de zone', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(
        find.bySemanticsLabel(
          'Eaux souterraines — Dombes - Certines - Nord, niveau de gravité : '
          'Vigilance',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Eau potable — Rivières de Bresse, niveau de gravité : Alerte',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('bouton principal : plein, #0B5E86, texte blanc, pleine '
        'largeur, icône d ouverture à droite', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
      );
      final Finder button = within(
        decreeUrlAin,
        find.widgetWithText(FilledButton, "Ouvrir l'arrêté"),
      );
      expect(button, findsOneWidget);
      final ButtonStyle style = tester.widget<FilledButton>(button).style!;
      expect(
        style.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF0B5E86),
      );
      expect(
        style.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFFFFFFF),
      );
      expect(
        within(decreeUrlAin, find.byIcon(Icons.open_in_new)),
        findsOneWidget,
      );
      // Pleine largeur de la carte (moins son remplissage de 16 + 16).
      expect(
        tester.getSize(button).width,
        closeTo(tester.getSize(card(decreeUrlAin)).width - 32, 1),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });

    testWidgets('arrêté-cadre : bouton à contour noir de 1,5 px', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
      );
      final OutlinedButton button = tester.widget<OutlinedButton>(
        within(
          frameworkUrlAin,
          find.widgetWithText(OutlinedButton, "Ouvrir l'arrêté-cadre"),
        ),
      );
      final BorderSide? side = button.style?.side?.resolve(<WidgetState>{});
      expect(side?.color, const Color(0xFF000000));
      expect(side?.width, 1.5);
    });

    testWidgets('mention sous le bouton : PDF si le chemin finit par .pdf '
        '(casse ignorée), sinon sans « PDF »', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
      );
      expect(
        find.text("PDF · s'ouvre hors de l'application"),
        findsNWidgets(2),
      );

      AlertZone at(String url) => withDecree(
        ainSup(),
        RestrictionDecree(
          validFrom: DateTime.utc(2026, 8, 20),
          validUntil: DateTime.utc(2026, 10, 31),
          document: DocumentLink(url),
          frameworkDocument: const DocumentLink(
            'https://example.org/CADRE.PDF?x=1',
          ),
        ),
      );
      await _pump(
        tester,
        ZonesTrouvees(
          zonesAinWith(<AlertZone>[at('https://example.org/arrete')]),
        ),
        onOpenDocument: (DocumentLink _) {},
      );
      expect(find.text("S'ouvre hors de l'application"), findsOneWidget);
      // .PDF en majuscules, avec requête : le chemin finit par .pdf.
      expect(find.text("PDF · s'ouvre hors de l'application"), findsOneWidget);
    });

    testWidgets('sans onOpenDocument ou adresse non ouvrable : aucune mention '
        'd ouverture', (WidgetTester tester) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(find.textContaining("hors de l'application"), findsNothing);
      await _pump(
        tester,
        ZonesTrouvees(zonesAinWith(<AlertZone>[ainSupAdresseNonOuvrable()])),
        onOpenDocument: (DocumentLink _) {},
      );
      expect(find.textContaining("hors de l'application"), findsNothing);
    });

    testWidgets('adresse : bloc « Adresse du document », entière, brute, '
        'sélectionnable, à chasse fixe', (WidgetTester tester) async {
      await _pump(tester, ZonesTrouvees(zonesParis()));
      expect(find.text('Adresse du document'), findsNWidgets(2));
      final Finder address = within(
        decreeUrlParis,
        find.byType(SelectableText),
      );
      expect(address, findsOneWidget);
      final SelectableText text = tester.widget<SelectableText>(address);
      // BR-014 : jamais réparée, jamais coupée.
      expect(text.data, decreeUrlParis);
      expect(text.style?.fontFamily, 'monospace');
      expect(tester.takeException(), isNull);
    });

    test('libellé « Adresse du document » : au moins 4,5:1 sur #F3F4F1', () {
      expect(
        contrastRatio(const Color(0xFF4A5259), const Color(0xFFF3F4F1)),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('lien non ouvert : encart orange sous le bloc d adresse, icône '
        'hors de la sémantique', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
        unopenedLink: decreeUrlAin,
      );
      final Finder notice = within(
        decreeUrlAin,
        find.textContaining("Ce lien n'a pas pu être ouvert"),
      );
      expect(notice, findsOneWidget);
      expect(
        _top(tester, notice),
        greaterThan(
          _top(tester, within(decreeUrlAin, find.byType(SelectableText))),
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.ancestor(of: notice, matching: find.byType(DecoratedBox)).first,
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFF4E0));
      expect(decoration.border, Border.all(color: const Color(0xFFB36B00)));
      expect(
        find.ancestor(
          of: within(decreeUrlAin, find.byIcon(Icons.info_outline)),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      // Pas d'encart sur la carte dont le lien s'est ouvert.
      expect(
        within(frameworkUrlAin, find.textContaining("Ce lien n'a pas")),
        findsNothing,
      );
      handle.dispose();
    });
  });

  group('aucune zone (UC-002 A3, BR-007)', () {
    testWidgets(
      'les deux phrases, la date de récupération, ni badge ni profil',
      (WidgetTester tester) async {
        await _pump(
          tester,
          AucuneZone(point: pointGuyane(), retrievedAt: retrievedAtGuyane),
        );
        final Finder first = find.text(
          "VigiEau ne renvoie aucune zone d'alerte pour ce point.",
        );
        expect(first, findsOneWidget);
        expect(find.text(_brSept), findsOneWidget);
        expect(_top(tester, first), lessThan(_top(tester, find.text(_brSept))));
        expect(
          find.text('Réponse de VigiEau obtenue le 27/09/2026 à 13:26'),
          findsOneWidget,
        );
        expect(find.byType(DroughtSeverityBadge), findsNothing);
        expect(find.text("Profil d'usager"), findsNothing);
      },
    );
  });

  group('échecs (§ 5.3, Q-5d)', () {
    const String siteSentence =
        "Les arrêtés en vigueur restent consultables à l'adresse "
        '$restrictionsPublicSiteUrl';

    final Map<String, (RestrictionsState, String)> cases =
        <String, (RestrictionsState, String)>{
          'SourceInjoignable': (
            RestrictionsEnEchec(
              point: pointAin(),
              cause: const SourceInjoignable('timeout'),
            ),
            "VigiEau n'a pas répondu. Aucun niveau n'est disponible pour ce "
                'point.',
          ),
          'ReponseIllisible': (
            RestrictionsEnEchec(
              point: pointAin(),
              cause: const ReponseIllisible('json'),
            ),
            "La réponse de VigiEau n'a pas pu être lue par l'application. "
                "Aucun niveau n'est affiché.",
          ),
          'RequeteRefusee': (
            RestrictionsEnEchec(
              point: pointAin(),
              cause: const RequeteRefusee(statusCode: 409, diagnostic: 'x'),
            ),
            "VigiEau a répondu, mais n'a pas pu servir ce point. Aucun niveau "
                "n'est affiché.",
          ),
          'RestrictionsNonObtenues': (
            RestrictionsNonObtenues(pointAin()),
            "Les restrictions n'ont pas pu être obtenues pour ce point. Aucun "
                "niveau n'est affiché.",
          ),
        };

    for (final MapEntry<String, (RestrictionsState, String)> entry
        in cases.entries) {
      testWidgets('${entry.key} : texte de C1, adresse du site public, aucun '
          'niveau, « Réessayer » -> onRetry', (WidgetTester tester) async {
        int retries = 0;
        await _pump(tester, entry.value.$1, onRetry: () => retries++);

        expect(find.text(entry.value.$2), findsOneWidget);
        expect(
          find.text('Point désigné : 46,20000° N, 5,22600° E'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(SelectableText, siteSentence),
          findsOneWidget,
        );
        expect(find.byType(DroughtSeverityBadge), findsNothing);
        expect(find.text("Profil d'usager"), findsNothing);

        await tester.tap(find.text('Réessayer'));
        expect(retries, 1);
      });
    }

    testWidgets('RequeteRefusee ne dit pas « injoignable »', (
      WidgetTester tester,
    ) async {
      await _pump(tester, cases['RequeteRefusee']!.$1);
      for (final String text in _allTexts(tester)) {
        expect(text.toLowerCase(), isNot(contains('injoignable')));
      }
    });

    testWidgets('RestrictionsNonObtenues ne nomme pas la source', (
      WidgetTester tester,
    ) async {
      await _pump(tester, RestrictionsNonObtenues(pointAin()));
      for (final String text in _allTexts(tester)) {
        expect(text, isNot(contains(restrictionsSourceName)));
      }
    });

    testWidgets('lien du site public qui ne s est pas ouvert : phrase de C1', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        RestrictionsNonObtenues(pointAin()),
        unopenedLink: restrictionsPublicSiteUrl,
      );
      expect(
        find.text(
          "Ce lien n'a pas pu être ouvert depuis l'application. Son adresse "
          'reste affichée ci-dessus.',
        ),
        findsOneWidget,
      );
    });
  });

  group('cibles (04-ui.md § 3, K4)', () {
    Future<void> checkTargets(WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        onOpenDocument: (DocumentLink _) {},
      );
      for (final Finder finder in <Finder>[
        find.byType(BackButton),
        find.widgetWithText(FilledButton, "Ouvrir l'arrêté"),
        find.widgetWithText(OutlinedButton, "Ouvrir l'arrêté-cadre"),
      ]) {
        final Size size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(minimumTapTarget));
        expect(size.width, greaterThanOrEqualTo(minimumTapTarget));
      }
      await _pump(tester, RestrictionsNonObtenues(pointAin()));
      final Size retry = tester.getSize(
        find.widgetWithText(OutlinedButton, 'Réessayer'),
      );
      expect(retry.height, greaterThanOrEqualTo(minimumTapTarget));
    }

    testWidgets('Android : 48', (WidgetTester tester) async {
      expect(minimumTapTarget, 48);
      await checkTargets(tester);
    });

    testWidgetsOnWindows('Windows : 44', (WidgetTester tester) async {
      expect(minimumTapTarget, 44);
      await checkTargets(tester);
    });
  });

  group('défilement', () {
    testWidgets('revient en haut à chaque nouveau point', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      ScrollableState scrollable = tester.state(_mainScrollable);
      expect(scrollable.position.pixels, greaterThan(0));

      await _pump(tester, RestrictionsEnCours(pointParis()));
      await _pump(tester, ZonesTrouvees(zonesParis()));
      await tester.pumpAndSettle();
      scrollable = tester.state(_mainScrollable);
      expect(scrollable.position.pixels, 0);
    });
  });

  group('encart renforcé (E4, BR-013, Q-4 (a))', () {
    final Finder headline = find.textContaining(reinforcedWarningHeadline);
    final Finder action = find.text(reinforcedWarningActionLabel);
    final Finder body = find.text(reinforcedWarningBody);

    final Map<String, RestrictionsState> states = <String, RestrictionsState>{
      'RestrictionsEnCours': RestrictionsEnCours(pointAin()),
      'ZonesTrouvees': ZonesTrouvees(zonesAin()),
      'AucuneZone': AucuneZone(
        point: pointGuyane(),
        retrievedAt: retrievedAtGuyane,
      ),
      'EnEchec SourceInjoignable': RestrictionsEnEchec(
        point: pointAin(),
        cause: const SourceInjoignable('timeout'),
      ),
      'EnEchec ReponseIllisible': RestrictionsEnEchec(
        point: pointAin(),
        cause: const ReponseIllisible('json'),
      ),
      'EnEchec RequeteRefusee': RestrictionsEnEchec(
        point: pointAin(),
        cause: const RequeteRefusee(statusCode: 409, diagnostic: 'x'),
      ),
      'RestrictionsNonObtenues': RestrictionsNonObtenues(pointAin()),
    };

    for (final MapEntry<String, RestrictionsState> entry in states.entries) {
      testWidgets('${entry.key} : titre, action puis corps, avant tout '
          'contenu, après la barre de titre', (WidgetTester tester) async {
        await _pump(tester, entry.value);
        expect(headline, findsOneWidget);
        expect(action, findsOneWidget);
        expect(body, findsOneWidget);
        expect(
          find.text(restrictionsPublicSiteUrl, findRichText: true),
          findsWidgets,
        );

        final double titleBar = _top(
          tester,
          find.text(restrictionsScreenTitle),
        );
        final double firstContent = _top(
          tester,
          find.textContaining('Point désigné'),
        );
        expect(titleBar, lessThan(_top(tester, headline)));
        expect(_top(tester, headline), lessThan(_top(tester, action)));
        expect(_top(tester, action), lessThan(_top(tester, body)));
        expect(_top(tester, body), lessThan(firstContent));
        // Le badge vient après l'encart.
        for (final Element badge
            in find.byType(DroughtSeverityBadge).evaluate()) {
          expect(
            tester.getTopLeft(find.byWidget(badge.widget).first).dy,
            greaterThan(_top(tester, body)),
          );
        }
      });

      testWidgets('${entry.key} : l action ouvre le site public', (
        WidgetTester tester,
      ) async {
        int opened = 0;
        await _pump(tester, entry.value, onOpenPublicSite: () => opened++);
        await tester.tap(action);
        expect(opened, 1);
      });
    }

    testWidgets('sémantique : titre, action puis corps, dans cet ordre', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, ZonesTrouvees(zonesAin()));
      final SemanticsNode header = tester.getSemantics(
        find.byKey(reinforcedWarningHeaderKey),
      );
      final SemanticsNode bodyNode = tester.getSemantics(
        find.byKey(reinforcedWarningBodyKey),
      );
      expect(header.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(bodyNode.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      expect(header.label, contains(reinforcedWarningHeadline));

      // Ordre de parcours : l'encart précède le contenu de l'état.
      final List<String> order = <String>[];
      void visit(SemanticsNode node) {
        order.add(node.label);
        node.visitChildren((SemanticsNode child) {
          visit(child);
          return true;
        });
      }

      visit(tester.getSemantics(find.byType(Scaffold).first));
      final int headerAt = order.indexWhere(
        (String l) => l.contains(reinforcedWarningHeadline),
      );
      final int bodyAt = order.indexWhere(
        (String l) => l.contains(reinforcedWarningBody),
      );
      final int pointAt = order.indexWhere(
        (String l) => l.contains('Point désigné'),
      );
      expect(headerAt, greaterThanOrEqualTo(0));
      expect(headerAt, lessThan(bodyAt));
      expect(bodyAt, lessThan(pointAt));
      handle.dispose();
    });

    testWidgets('titre et action restent visibles après défilement, le corps '
        'sort', (WidgetTester tester) async {
      await _pump(
        tester,
        ZonesTrouvees(zonesAin()),
        profile: UserProfile.particulier,
      );
      final double headlineBefore = _top(tester, headline);
      final double actionBefore = _top(tester, action);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(_top(tester, headline), headlineBefore);
      expect(_top(tester, action), actionBefore);
      expect(
        tester.getRect(body).bottom,
        lessThan(tester.getRect(action).bottom),
      );
    });

    testWidgets('aucun repli : ni ExpansionTile, ni Dismissible', (
      WidgetTester tester,
    ) async {
      await _pump(tester, ZonesTrouvees(zonesAin()));
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
    });

    test('aucun texte de l encart dans lib/features', () {
      for (final FileSystemEntity file in Directory(
        'lib/features',
      ).listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          expect(
            file.readAsStringSync(),
            isNot(contains('NE FONDEZ')),
            reason: file.path,
          );
        }
      }
    });

    // Q-4 amendé (2026-09-29) : la tête (titre, action) est épinglée tant
    // qu'elle prend au plus la moitié de la hauteur utile (sous la barre de
    // titre) ; sinon tout l'encart est le premier élément du défilement.
    // [expectPinned] : `true`, `false`, ou `null` = « épinglée si elle tient ».
    Future<void> checkLayout(
      WidgetTester tester,
      Size window, {
      required double scale,
      required bool? expectPinned,
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final RestrictionsState state in states.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: _screen(state),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Aucun débordement (RenderFlex overflowed) à aucune taille.
        expect(tester.takeException(), isNull, reason: '$state');

        final double barBottom = tester
            .getRect(
              find
                  .ancestor(
                    of: find.text(restrictionsScreenTitle),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .bottom;
        final double usable = window.height - barBottom;
        final Rect header = tester.getRect(
          find.byKey(reinforcedWarningHeaderKey),
        );
        final bool inScroll = find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byKey(reinforcedWarningHeaderKey),
            )
            .evaluate()
            .isNotEmpty;
        final bool fits = header.height * 2 <= usable;
        debugPrint(
          'E4 mesure ${window.width.toInt()}x${window.height.toInt()} '
          '${(scale * 100).toInt()}% utile=${usable.toStringAsFixed(1)} '
          'tete=${header.height.toStringAsFixed(1)} '
          'ratio=${(header.height / usable).toStringAsFixed(3)} '
          'epinglee=${!inScroll}',
        );
        expect(!inScroll, expectPinned ?? fits, reason: '$state');
        if (!inScroll) {
          expect(header.height, lessThanOrEqualTo(usable / 2));
        } else {
          // Tout l'encart en tête du défilement, au-dessus du contenu.
          expect(_top(tester, headline), lessThan(_top(tester, action)));
          expect(_top(tester, action), lessThan(_top(tester, body)));
          expect(
            _top(tester, body),
            lessThan(_top(tester, find.textContaining('Point désigné'))),
          );
          // Il défile avec le contenu.
          final ScrollableState scrollable = tester.state(_mainScrollable);
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
        }
      }
    }

    testWidgetsOnWindows('200 % : tête épinglée, <= moitié, 800 x 740', (
      WidgetTester tester,
    ) async {
      await checkLayout(
        tester,
        const Size(800, 740),
        scale: 2,
        expectPinned: true,
      );
    });

    // Ne dépendent pas de l'hôte : plateforme par défaut.
    testWidgets('200 % : rien d épinglé, encart en tête du défilement, '
        '360 x 640', (WidgetTester tester) async {
      await checkLayout(
        tester,
        const Size(360, 640),
        scale: 2,
        expectPinned: false,
      );
    });

    testWidgets('100 % : tête épinglée si elle tient, 360 x 640', (
      WidgetTester tester,
    ) async {
      await checkLayout(
        tester,
        const Size(360, 640),
        scale: 1,
        expectPinned: true,
      );
    });

    testWidgets('le facteur de police change sans reconstruire l écran : la '
        'tête passe de épinglée à défilée', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ValueNotifier<double> scale = ValueNotifier<double>(1);
      addTearDown(scale.dispose);
      // Même instance d'écran : seul le MediaQuery change au-dessus.
      final Widget screen = _screen(ZonesTrouvees(zonesAin()));
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<double>(
            valueListenable: scale,
            child: screen,
            builder: (BuildContext context, double value, Widget? child) =>
                MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(value)),
                  child: child!,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder headerInScroll = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byKey(reinforcedWarningHeaderKey),
      );
      expect(headerInScroll, findsNothing);

      scale.value = 2;
      await tester.pumpAndSettle();
      expect(headerInScroll, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lien du site public non ouvert : avis sous le corps, une '
        'fois, dans chaque état', (WidgetTester tester) async {
      for (final RestrictionsState state in states.values) {
        await _pump(tester, state, unopenedLink: restrictionsPublicSiteUrl);
        expect(
          find.textContaining("Ce lien n'a pas pu être ouvert"),
          findsOneWidget,
          reason: '$state',
        );
        expect(
          _top(tester, find.textContaining("Ce lien n'a pas pu être ouvert")),
          greaterThan(_top(tester, body)),
        );
        await _pump(tester, state);
        expect(
          find.textContaining("Ce lien n'a pas pu être ouvert"),
          findsNothing,
          reason: '$state',
        );
      }
    });

    testWidgets('200 % : tête épinglée, <= moitié, téléphone 411 x 891', (
      WidgetTester tester,
    ) async {
      await checkLayout(
        tester,
        const Size(411, 891),
        scale: 2,
        expectPinned: true,
      );
    });
  });

  group('typographie dynamique : 200 %, rien n est tronqué', () {
    Future<void> check(WidgetTester tester, Size window) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _screen(
              ZonesTrouvees(zonesAin()),
              profile: UserProfile.particulier,
              onOpenDocument: (DocumentLink _) {},
              unopenedLink: decreeUrlAin,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // La section « Arrêtés » : adresse, mention et avis atteignables.
      for (final Finder finder in <Finder>[
        find.text('Adresse du document').first,
        find.text("PDF · s'ouvre hors de l'application").first,
        find.textContaining("Ce lien n'a pas pu être ouvert"),
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.getRect(finder).right, lessThanOrEqualTo(window.width));
        expect(tester.takeException(), isNull);
      }

      for (final RenderParagraph paragraph
          in tester.allRenderObjects.whereType<RenderParagraph>()) {
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: paragraph.text.toPlainText(),
        );
      }

      final ScrollableState scrollable = tester.state(_mainScrollable);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      // Atteignable jusqu'au dernier usage du dernier groupe.
      final Finder last = find
          .text(
            'Arrosage des centres équestres et carrières équestres',
            findRichText: true,
          )
          .last;
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(window.height));
      expect(tester.takeException(), isNull);
    }

    testWidgetsOnWindows('fenêtre minimale Windows, 800 x 740', (
      WidgetTester tester,
    ) async {
      await check(tester, const Size(800, 740));
    });

    testWidgets('téléphone, 390 x 844', (WidgetTester tester) async {
      await check(tester, const Size(390, 844));
    });
  });
}
