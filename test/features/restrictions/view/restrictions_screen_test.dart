// Verrouille l'ecran des restrictions (E2 de T2), selon la conception
// arbitree (`docs/superpowers/specs/2026-09-27-ecran-restrictions-t2-design.md`) :
// ecran plein (Q-1), ordre du § 3 (Q-3), textes des § 5.1 a 5.3 mot pour
// mot (Q-5a/b/c/e), echec imprevu neutre (Q-5d, `RestrictionsNonObtenues`),
// arretes dedoublonnes (Q-6), badge a cote de son libelle (Q-7).
//
// Les zones viennent de `zones_samples.dart` (valeurs recopiees des
// fixtures) : ce test ne lit jamais `lib/data/`. L'encart renforce est la
// tache E4 : il n'est pas verifie ici.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/restrictions/view/drought_severity_badge.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import '../../../support/windows_platform.dart';
import '../zones_samples.dart';

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
  String? unopenedLink,
}) => RestrictionsScreen(
  state: state,
  profile: profile,
  onChooseProfile: onChooseProfile ?? (UserProfile _) {},
  onRetry: onRetry ?? () {},
  onOpenDocument: onOpenDocument,
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
        unopenedLink: unopenedLink,
      ),
    ),
  );
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
        find.text('Eaux souterraines — Dombes - Certines - Nord'),
      );
      final double aep = _top(
        tester,
        find.text('Eau potable — Rivières de Bresse'),
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
      expect(find.byType(DroughtSeverityBadge), findsNWidgets(3 + 3 * 4));
      expect(find.text('Échelle :'), findsNWidgets(3));
      expect(find.text('Alerte ← cette zone'), findsNWidgets(2));
      expect(find.text('Vigilance ← cette zone'), findsOneWidget);
      expect(find.text('Alerte renforcée'), findsNWidgets(3));
      expect(find.text('Crise'), findsNWidgets(3));
      expect(find.text('Vigilance'), findsNWidgets(2));
      expect(find.text('Alerte'), findsOneWidget);
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
        findsOneWidget,
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
        find.text('Eaux superficielles — Rivières de Bresse'),
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
      expect(
        find.text(
          "S'applique à : Eaux superficielles — Rivières de Bresse ; Eaux "
          'souterraines — Dombes - Certines - Nord ; Eau potable — Rivières '
          'de Bresse',
        ),
        findsNWidgets(2),
      );
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
      expect(
        find.text(
          "S'applique à : Eaux superficielles — Bassins de la Marne et de la "
          'Seine ; Eaux souterraines — Bassins de la Marne et de la Seine ; '
          'Eau potable — Bassins de la Marne et de la Seine',
        ),
        findsNWidgets(2),
      );
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
        find.widgetWithText(OutlinedButton, "Ouvrir l'arrêté"),
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

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
