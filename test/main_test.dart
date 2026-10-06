// Verrouille la racine de composition (`lib/main.dart`, `MartinPecheurApp`)
// sur la garde de l'avertissement initial (`BR-012`, `UC-006`, tâche `W2`) :
// tant que `WarningsViewModel.requiresAcknowledgement` est vrai, la carte —
// donc `FlutterMap` — n'est PAS construite ; un usager déjà acquitté ne voit
// JAMAIS `InitialWarningView`, pas même une image, dès le tout premier
// `pump()`.
//
// Aucun test ici n'appelle `main()` : `main()` charge un asset, ouvre des
// clients HTTP et construit `SharedPreferencesAcknowledgementRepository`
// (`lib/data/…`), tout ce que ce fichier de test n'a pas à réaliser pour
// vérifier la garde. `MartinPecheurApp` est construit directement, avec des
// dépôts en mémoire — même style que
// `test/features/map/view/map_view_test.dart`.
//
// ⚠️ Ce fichier importe `lib/data/…` (les dépôts vides ci-dessous). C'est
// permis : `test/architecture/layers_test.dart` (règle `features-vers-data`)
// contraint `lib/`, pas `test/`.
import 'dart:async' show Completer;
import 'dart:ui' show Rect, Size;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart'
    show
        Checkbox,
        ListView,
        Scrollable,
        ScrollableState,
        Semantics,
        SingleChildScrollView,
        ValueKey;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart'
    show restrictionsPublicSiteUrl;
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';
import 'package:martinpecheur/features/map/view/designate_center_button.dart'
    show mapDesignateCenterButtonKey, mapDesignateCenterHintKey;
import 'package:martinpecheur/features/map/view/map_center_reticle.dart'
    show mapCenterReticleKey;
import 'package:martinpecheur/features/map/view/map_scale_chips.dart'
    show mapDesignationChipKey;
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/onde_sheet/view_model/onde_sheet_view_model.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';
import 'package:martinpecheur/features/shared/data_sources_view.dart';
import 'package:martinpecheur/features/shared/warning_link.dart'
    show warningLinkKey, warningWindowRegionKey, warningWindowSourcesLinkKey;
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';
import 'package:martinpecheur/features/warnings/view/initial_warning_view.dart';
import 'package:martinpecheur/features/warnings/view_model/warnings_view_model.dart';
import 'package:martinpecheur/main.dart';

import 'features/restrictions/zones_samples.dart';
import 'support/windows_platform.dart';

/// Dépôts vides, juste assez pour CONSTRUIRE les trois autres ViewModels :
/// aucun de ces tests n'attend leur chargement, seule la garde
/// d'acquittement est vérifiée. Même doubles que
/// `test/features/map/view/map_view_test.dart`.
final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

final class _EmptyHydroObservationRepository
    implements HydroObservationRepository {
  @override
  Future<HydroObservation?> findLatest(
    StationCode station,
    Grandeur grandeur,
  ) async => null;
}

final class _EmptyOndeObservationRepository
    implements OndeObservationRepository {
  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async =>
      const OndeSweep(observations: <OndeObservation>[], unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

final class _EmptyStationRepository implements StationRepository {
  @override
  Future<Station?> findByCode(StationCode code) async => null;
}

/// Double de [AcknowledgementRepository], programmable en lecture — même
/// style que `test/features/warnings/view_model/warnings_view_model_test.dart`.
final class _AcknowledgementRepositoryDouble
    implements AcknowledgementRepository {
  _AcknowledgementRepositoryDouble({
    this.storedVersion,
    this.readError,
    this.writeError,
  });

  final String? storedVersion;

  /// Levée par [readAcknowledgedVersion] si non nulle — simule un stockage
  /// illisible (`WarningsViewModel.load()` rebloque sans planter).
  final Object? readError;

  /// Levée par [writeAcknowledgedVersion] si non nulle — simule un echec
  /// d'ecriture (`UC-006 A6`, arbitrage du 2026-09-22).
  final Object? writeError;

  @override
  Future<String?> readAcknowledgedVersion() async {
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return storedVersion;
  }

  @override
  Future<void> writeAcknowledgedVersion(String version) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
  }
}

/// Source de restrictions dont chaque reponse est tenue par un `Completer` :
/// un test decide quand (et si) la reponse arrive.
final class _PendingRestrictionSource implements RestrictionSource {
  final List<GeoPoint> requested = <GeoPoint>[];
  final List<Completer<ZonesAtPoint>> completers = <Completer<ZonesAtPoint>>[];

  @override
  Future<ZonesAtPoint> zonesAt(GeoPoint point) {
    requested.add(point);
    final Completer<ZonesAtPoint> completer = Completer<ZonesAtPoint>();
    completers.add(completer);
    return completer.future;
  }
}

final class _NeverOpensLinks implements ExternalLinkOpener {
  @override
  Future<bool> open(Uri uri) async => false;
}

RestrictionsViewModel _restrictions([RestrictionSource? source]) =>
    RestrictionsViewModel(
      source: source ?? _PendingRestrictionSource(),
      links: _NeverOpensLinks(),
    );

MartinPecheurApp _app(
  WarningsViewModel warningsViewModel, [
  RestrictionsViewModel? restrictionsViewModel,
]) => MartinPecheurApp(
  warningsViewModel: warningsViewModel,
  restrictionsViewModel: restrictionsViewModel ?? _restrictions(),
  mapViewModel: MapViewModel(
    stationPoints: _EmptyStationPointRepository(),
    observations: _EmptyHydroObservationRepository(),
    onde: _EmptyOndeObservationRepository(),
  ),
  stationSheetViewModel: StationSheetViewModel(
    observations: _EmptyHydroObservationRepository(),
    stations: _EmptyStationRepository(),
  ),
  ondeSheetViewModel: OndeSheetViewModel(
    onde: _EmptyOndeObservationRepository(),
  ),
);

/// Un point DANS la bande du bouton de désignation (la boîte du `ListView` de
/// `_DesignationPlacement`, seul `ListView` au-dessus du bouton), sur la
/// rangée de la pilule, à mi-chemin entre le bord gauche de la bande et celui
/// de la pilule : hors de la pilule et de l'indice. Calculé depuis les
/// rectangles mesurés, jamais par une constante — il ne peut pas retomber hors
/// de la bande, où la carte reçoit les gestes de toute façon et où le test ne
/// prouverait plus rien. Même calcul que `_pointDansLaBande` de
/// `test/features/map/view/map_designation_test.dart`.
Offset _pointDansLaBande(WidgetTester tester) {
  final Rect bande = tester.getRect(
    find.ancestor(
      of: find.byKey(mapDesignateCenterButtonKey),
      matching: find.byType(ListView),
    ),
  );
  final Rect bouton = tester.getRect(find.byKey(mapDesignateCenterButtonKey));
  final Rect indice = tester.getRect(find.byKey(mapDesignateCenterHintKey));
  final Offset p = Offset((bande.left + bouton.left) / 2, bouton.center.dy);
  expect(
    bande.contains(p) && p.dx > bande.left,
    isTrue,
    reason: 'le point $p doit être DANS la bande $bande, pas sur son bord',
  );
  expect(bouton.contains(p), isFalse, reason: 'le point $p est dans $bouton');
  expect(indice.contains(p), isFalse, reason: 'le point $p est dans $indice');
  return p;
}

void main() {
  testWidgets('requiresAcknowledgement vrai : InitialWarningView est affiche, '
      'MapView n\'est jamais construit', (WidgetTester tester) async {
    final WarningsViewModel warningsViewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(),
      currentWarningVersion: warningTextVersion,
    );
    await warningsViewModel.load();

    await tester.pumpWidget(_app(warningsViewModel));

    expect(find.byType(InitialWarningView), findsOneWidget);
    expect(find.byType(MapView), findsNothing);
  });

  testWidgets('requiresAcknowledgement faux : MapView est affiche', (
    WidgetTester tester,
  ) async {
    final WarningsViewModel warningsViewModel = WarningsViewModel(
      acknowledgements: _AcknowledgementRepositoryDouble(
        storedVersion: warningTextVersion,
      ),
      currentWarningVersion: warningTextVersion,
    );
    await warningsViewModel.load();

    await tester.pumpWidget(_app(warningsViewModel));

    expect(find.byType(MapView), findsOneWidget);
    expect(find.byType(InitialWarningView), findsNothing);
  });

  testWidgets(
    'usager deja acquitte : InitialWarningView n\'est jamais rendu, pas '
    'meme une image — assertion des le tout premier pump',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      // `load()` est attendu AVANT `pumpWidget`, exactement comme
      // `main.dart` l'attend avant `runApp` : c'est ce qui évite le
      // clignotement (révision du plan du 2026-09-22).
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      // Assertion dès le PREMIER pump — pas de `pumpAndSettle` avant : si
      // le modal apparaissait ne serait-ce qu'une image, il serait déjà là
      // à cet instant précis.
      expect(find.byType(InitialWarningView), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
    },
  );

  testWidgets(
    'cocher puis presser le bouton bascule vers la carte sans redemarrer '
    'l\'app, MapView n\'est construit qu\'apres',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));
      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      await tester.tap(find.byKey(initialWarningButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(InitialWarningView), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
    },
  );

  testWidgets(
    'echec de lecture du stockage : le modal reste affiche, l\'app ne '
    'plante pas',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          readError: const FormatException('stockage illisible'),
        ),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      expect(tester.takeException(), isNull);
      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);
    },
  );

  testWidgets(
    'echec d\'ecriture de l\'acquittement (UC-006 A6) : le modal reste '
    'affiche, MapView n\'est jamais construit',
    (WidgetTester tester) async {
      final WarningsViewModel warningsViewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          writeError: const FormatException('ecriture ko'),
        ),
        currentWarningVersion: warningTextVersion,
      );
      await warningsViewModel.load();

      await tester.pumpWidget(_app(warningsViewModel));

      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      await tester.tap(find.byKey(initialWarningButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(InitialWarningView), findsOneWidget);
      expect(find.byType(MapView), findsNothing);
    },
  );

  // `S1` (T2) : l'ecran « D'ou vient cette donnee ? » est une route poussee
  // par `Navigator.of(context)` — depuis le modal du premier lancement, qui
  // est le `home` de l'application, puis depuis la fenetre d'avertissement,
  // une route de dialogue. Ces tests passent par la VRAIE composition de
  // `MartinPecheurApp` : un `MaterialApp` de banc ne prouverait pas que le
  // `Navigator` est trouve ici.
  group("ecran des sources (S1) — composition reelle", () {
    Future<void> pumpUnacknowledged(WidgetTester tester) async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      await tester.pumpWidget(_app(viewModel));
    }

    testWidgets('modal : le lien ouvre l ecran, rien n est acquitte, la '
        'carte n est toujours pas construite', (WidgetTester tester) async {
      await pumpUnacknowledged(tester);

      await tester.tap(find.byKey(initialWarningSourcesLinkKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataSourcesView), findsOneWidget);
      expect(find.text(dataSourcesTitle), findsOneWidget);
      // Ni visible NI cachee sous la route : la carte n'existe pas.
      expect(find.byType(MapView, skipOffstage: false), findsNothing);
    });

    for (final bool checked in <bool>[false, true]) {
      testWidgets('modal, case ${checked ? 'cochee' : 'decochee'} : le retour '
          'rend le modal tel qu il etait laisse, toujours bloquant', (
        WidgetTester tester,
      ) async {
        await pumpUnacknowledged(tester);
        if (checked) {
          await tester.tap(find.byKey(initialWarningCheckboxKey));
          await tester.pump();
        }

        await tester.tap(find.byKey(initialWarningSourcesLinkKey));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(DataSourcesView), findsNothing);
        expect(find.byType(InitialWarningView), findsOneWidget);
        expect(find.byType(MapView, skipOffstage: false), findsNothing);
        expect(
          tester.widget<Checkbox>(find.byKey(initialWarningCheckboxKey)).value,
          checked,
        );
      });
    }

    testWidgets('apres acquittement : la fenetre d avertissement de la carte '
        'porte le lien, qui ouvre l ecran', (WidgetTester tester) async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      await tester.pumpWidget(_app(viewModel));

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(warningWindowSourcesLinkKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataSourcesView), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DataSourcesView), findsNothing);
      expect(find.byKey(warningWindowRegionKey), findsOneWidget);
    });

    testWidgets('de bout en bout : relire les sources depuis le modal, '
        'acquitter, puis les relire depuis la carte', (
      WidgetTester tester,
    ) async {
      await pumpUnacknowledged(tester);

      await tester.tap(find.byKey(initialWarningSourcesLinkKey));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(initialWarningCheckboxKey));
      await tester.pump();
      await tester.tap(find.byKey(initialWarningButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(MapView), findsOneWidget);

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(warningWindowSourcesLinkKey));
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesView), findsOneWidget);
    });
  });

  group('ecran des restrictions (E3)', () {
    Future<WarningsViewModel> acknowledged() async {
      final WarningsViewModel viewModel = WarningsViewModel(
        acknowledgements: _AcknowledgementRepositoryDouble(
          storedVersion: warningTextVersion,
        ),
        currentWarningVersion: warningTextVersion,
      );
      await viewModel.load();
      return viewModel;
    }

    /// Désigne le centre de la carte par le bouton, que le choix
    /// « Restrictions » du sélecteur fait apparaître (`E5`). [allumer] faux :
    /// le mode est DÉJÀ actif (retour d'une désignation) — rappuyer sur la
    /// puce l'éteindrait.
    Future<void> designate(WidgetTester tester, {bool allumer = true}) async {
      if (allumer) {
        await tester.tap(find.byKey(mapDesignationChipKey));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pumpAndSettle();
    }

    bool echelleSelectionnee(WidgetTester tester, MapScaleKind kind) => tester
        .widget<Semantics>(find.byKey(ValueKey<MapScaleKind>(kind)))
        .properties
        .selected!;

    testWidgets('composition reelle, au lancement : la puce Restrictions est '
        'la, ni bouton, ni indice, ni reticule', (WidgetTester tester) async {
      await tester.pumpWidget(_app(await acknowledged()));

      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapDesignateCenterHintKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
    });

    testWidgets('composition reelle : apres la puce, le bouton et son indice '
        'sont centres sur la carte (fiches fermees)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(await acknowledged(), _restrictions(_PendingRestrictionSource())),
      );
      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.byKey(mapDesignateCenterButtonKey)).dx,
        closeTo(960, 1),
      );
      expect(
        tester.getCenter(find.byKey(mapDesignateCenterHintKey)).dx,
        closeTo(960, 1),
      );
    });

    testWidgets('designation : la route de l ecran est poussee et le '
        'ViewModel interroge le point designe', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(find.byType(RestrictionsScreen), findsNothing);

      await designate(tester);

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
      expect(restrictions.state, isA<RestrictionsEnCours>());
    });

    testWidgets('bouton de retour : route retiree, ViewModel ferme, carte '
        'de nouveau visible', (WidgetTester tester) async {
      final RestrictionsViewModel restrictions = _restrictions();
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(restrictions.state, isA<RestrictionsFermees>());
      expect(find.byType(MapView), findsOneWidget);
    });

    // Constat A de la revue : le futur de `push` se complete a l'appel de
    // `pop`, AVANT l'animation de sortie ; `close()` passait alors l'etat a
    // `RestrictionsFermees` et la route, encore montee, se vidait.
    testWidgets('retour : pendant la sortie de la route, l ecran garde son '
        'dernier contenu, le ViewModel est deja ferme', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);
      expect(find.byKey(restrictionsPointBannerKey), findsOneWidget);

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 50));

      // Le verrou contre une reponse tardive reste pose des le retrait...
      expect(restrictions.state, isA<RestrictionsFermees>());
      // ... mais la route, encore a l'ecran, n'est pas vide.
      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);
      expect(find.byKey(restrictionsPointBannerKey), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
    });

    // La route sortante est sous `IgnorePointer`, mais la carte DESSOUS recoit
    // les gestes : une nouvelle designation 50 ms apres le retour relance la
    // requete (le ViewModel quitte `RestrictionsFermees`) pendant que la
    // route sortante est encore a l'ecran. Elle ne doit pas se vider pour
    // autant : seule la NOUVELLE route montre « Recherche des zones… ».
    testWidgets('retour puis nouvelle designation pendant la sortie : la '
        'route SORTANTE garde ses cartes de zone', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      expect(find.byKey(restrictionsZoneCardKey(0)), findsOneWidget);

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 50));
      expect(restrictions.state, isA<RestrictionsFermees>());
      // Le bouton de la carte, dessous, recoit l'appui (le mode est reste
      // actif au retour).
      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pump();

      // La requete est bien repartie...
      expect(source.requested, hasLength(2));
      expect(restrictions.state, isA<RestrictionsEnCours>());
      // ... la nouvelle route cherche, et la SORTANTE garde ses cartes. La
      // nouvelle route est encore hors scene a sa premiere image : on compte
      // hors scene aussi.
      expect(
        find.byType(RestrictionsScreen, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        find.byKey(restrictionsZoneCardKey(0), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(
          "Recherche des zones d'alerte pour ce point…",
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(find.byKey(restrictionsZoneCardKey(0)), findsNothing);
      expect(
        find.text("Recherche des zones d'alerte pour ce point…"),
        findsOneWidget,
      );
    });

    // `close()` vide `unopenedLink` du ViewModel des le retrait : la route
    // sortante doit garder, elle, l'avis qu'elle affichait.
    testWidgets('retour : un avis de lien non ouvert reste affiche pendant la '
        'sortie de la route', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();

      // L'action de l'encart, par la composition reelle : `_NeverOpensLinks`
      // refuse, l'avis apparait.
      await tester.tap(find.text(reinforcedWarningActionLabel));
      await tester.pumpAndSettle();
      expect(restrictions.unopenedLink?.raw, restrictionsPublicSiteUrl);
      final Finder notice = find.textContaining(
        "Ce lien n'a pas pu être ouvert",
      );
      expect(notice, findsOneWidget);

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 50));

      expect(restrictions.state, isA<RestrictionsFermees>());
      expect(restrictions.unopenedLink, isNull);
      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(notice, findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
    });

    // Defaut 2, par la composition reelle : l'usager redescend, rappuie sur
    // l'action de l'encart, nouvel echec du meme lien ; l'avis revient dans
    // le champ. Rejoue en plateforme Windows, la premiere cible.
    testWidgetsOnWindows('second echec du site public : l avis, sorti du '
        'champ, est ramene dans le champ', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1266, 741);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      final Finder notice = find.textContaining(
        "Ce lien n'a pas pu être ouvert",
      );
      final Finder scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      await tester.tap(find.text(reinforcedWarningActionLabel));
      await tester.pumpAndSettle();
      final int first = restrictions.unopenedLink!.failureNumber;
      expect(notice, findsOneWidget);

      tester
          .state<ScrollableState>(scrollable)
          .position
          .jumpTo(
            tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          );
      await tester.pump();
      expect(
        tester.getRect(notice).bottom,
        lessThanOrEqualTo(tester.getRect(scrollable).top),
      );

      await tester.tap(find.text(reinforcedWarningActionLabel));
      await tester.pumpAndSettle();

      expect(restrictions.unopenedLink!.failureNumber, greaterThan(first));
      final Rect at = tester.getRect(notice);
      final Rect view = tester.getRect(scrollable);
      expect(at.top, greaterThanOrEqualTo(view.top), reason: '$at / $view');
      expect(at.bottom, lessThanOrEqualTo(view.bottom), reason: '$at / $view');
    });

    // La cible transmise au ViewModel par la composition reelle : `main.dart`
    // passe celle que la vue lui donne, il ne la fige pas. Un ouvreur qui
    // n'ouvre jamais, « Ouvrir l'arrete-cadre » : l'avis est dans la carte de
    // l'arrete-cadre, et nulle part ailleurs (pas dans celle de l'arrete, dont
    // l'adresse est pourtant la meme pour une zone qui cite l'une et l'autre).
    testWidgetsOnWindows('echec d ouverture de l arrete-cadre : l avis est '
        'dans la carte du CADRE, nulle part ailleurs, et la cible est '
        'frameworkDecree', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1266, 741);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);
      source.completers.single.complete(zonesAin());
      await tester.pumpAndSettle();
      final Finder notice = find.textContaining(
        "Ce lien n'a pas pu être ouvert",
      );
      expect(notice, findsNothing);

      await tester.ensureVisible(find.text("Ouvrir l'arrêté-cadre"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ouvrir l'arrêté-cadre"));
      await tester.pumpAndSettle();

      expect(restrictions.unopenedLink?.target, LinkTarget.frameworkDecree);
      expect(restrictions.unopenedLink?.raw, frameworkUrlAin);
      expect(
        find.descendant(
          of: find.byKey(
            restrictionsDecreeCardKey(frameworkUrlAin, framework: true),
          ),
          matching: notice,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            restrictionsDecreeCardKey(decreeUrlAin, framework: false),
          ),
          matching: notice,
        ),
        findsNothing,
      );
      expect(notice, findsOneWidget);
    });

    testWidgets('Echap : route retiree, ViewModel ferme', (
      WidgetTester tester,
    ) async {
      final RestrictionsViewModel restrictions = _restrictions();
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(restrictions.state, isA<RestrictionsFermees>());
    });

    testWidgets('retour pendant un chargement : la reponse tardive laisse '
        'le ViewModel ferme', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await designate(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      source.completers.single.complete(
        ZonesAtPoint(
          point: source.requested.single,
          retrievedAt: DateTime.utc(2026, 9, 27, 11, 25),
          zones: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(restrictions.state, isA<RestrictionsFermees>());
    });

    testWidgets('deux designations sans retour : une seule route, etat du '
        'second point, un retour ramene a la carte ViewModel ferme', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));

      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(mapDesignateCenterButtonKey));
      await tester.pump();
      // La route couvre deja la carte : le second geste (appui long, clic
      // droit) arrive par le rappel de la carte, sans retour entre les deux.
      tester
          .widget<MapView>(find.byType(MapView, skipOffstage: false))
          .onPointDesignated!(GeoPoint(latitude: 45, longitude: 3));
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(2));
      final RestrictionsState state = restrictions.state;
      expect(state, isA<RestrictionsEnCours>());
      expect((state as RestrictionsEnCours).point, source.requested.last);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byType(MapView), findsOneWidget);
      expect(restrictions.state, isA<RestrictionsFermees>());
    });

    testWidgets('re-designation apres retour : une seule route, l etat '
        'est celui du second point', (WidgetTester tester) async {
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));

      await designate(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Le mode est resté actif au retour : le bouton est là, sans rappuyer
      // sur la puce.
      await designate(tester, allumer: false);

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(2));
      final RestrictionsState state = restrictions.state;
      expect(state, isA<RestrictionsEnCours>());
      expect((state as RestrictionsEnCours).point, source.requested.last);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RestrictionsScreen), findsNothing);
    });

    testWidgets('au retour de l ecran des restrictions, le mode est toujours '
        'actif (bouton present) et l echelle inchangee (E5)', (
      WidgetTester tester,
    ) async {
      final RestrictionsViewModel restrictions = _restrictions();
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(echelleSelectionnee(tester, MapScaleKind.ecoulement), isTrue);

      await designate(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);
      expect(find.byKey(mapCenterReticleKey), findsOneWidget);
      expect(echelleSelectionnee(tester, MapScaleKind.ecoulement), isTrue);
      expect(echelleSelectionnee(tester, MapScaleKind.debit), isFalse);
    });

    testWidgets('une designation par appui long, hors mode, ouvre l ecran et '
        'laisse le mode eteint au retour (E5)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);

      await tester.longPressAt(const Offset(1200, 500));
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
    });

    // Windows est la première cible, et `flutter test` tourne par défaut en
    // Android : la désignation par appui long ET par clic droit, hors mode,
    // est rejouée par la composition RÉELLE, en plateforme Windows. C'est tout
    // ce que ces deux tests prouvent. Le point (1200, 500) est sur la carte
    // NUE, hors de tout défilement de surcouche (mesuré le 2026-10-06 : à
    // 1920 × 1032, hors mode, les deux colonnes du haut tiennent au-dessus de
    // y = 250) : ils ne disent RIEN de la `Scrollbar` automatique du bureau,
    // et resteraient verts si elle revenait. Ce verrou-là est porté par les
    // tests « dans la bande » ci-dessous et, pour les colonnes du haut, par
    // `test/features/map/view/map_designation_test.dart`.
    Future<void> designationHorsMode(
      WidgetTester tester,
      Future<void> Function(Offset at) geste,
    ) async {
      tester.view.physicalSize = const Size(1920, 1032);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);

      await geste(const Offset(1200, 500));
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(RestrictionsScreen), findsNothing);
      expect(find.byKey(mapDesignateCenterButtonKey), findsNothing);
      expect(find.byKey(mapCenterReticleKey), findsNothing);
      expect(find.byKey(mapDesignationChipKey), findsOneWidget);
    }

    testWidgetsOnWindows('Windows : une designation par appui long, hors '
        'mode, ouvre l ecran et laisse le mode eteint au retour (E5)', (
      WidgetTester tester,
    ) async {
      await designationHorsMode(tester, (Offset at) => tester.longPressAt(at));
    });

    testWidgetsOnWindows('Windows : une designation par clic droit, hors '
        'mode, ouvre l ecran et laisse le mode eteint au retour (E5)', (
      WidgetTester tester,
    ) async {
      await designationHorsMode(
        tester,
        (Offset at) => tester.tapAt(at, buttons: kSecondaryButton),
      );
    });

    // La bande du bouton de désignation est plus large que la pilule : un
    // appui long ou un clic droit posé DANS la bande, à côté de la pilule,
    // doit atteindre la carte dessous. Sur Windows, la `Scrollbar`
    // automatique de `MaterialScrollBehavior` enveloppait la bande, et son
    // `MouseRegion` opaque absorbait le geste sur toute la boîte. Verrou de
    // la composition réelle, à la taille minimale de la fenêtre (`K3`) : il
    // rougirait si `_DesignationPlacement` perdait `_WithoutScrollbar`, ou le
    // `hitTestBehavior: deferToChild` de son `ListView` (la bande, opaque,
    // capterait le geste : aucune désignation, aucun écran).
    Future<_PendingRestrictionSource> dansLaBande(
      WidgetTester tester,
      Future<void> Function(Offset at) geste,
    ) async {
      tester.view.physicalSize = const Size(800, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _PendingRestrictionSource source = _PendingRestrictionSource();
      final RestrictionsViewModel restrictions = _restrictions(source);
      await tester.pumpWidget(_app(await acknowledged(), restrictions));
      await tester.tap(find.byKey(mapDesignationChipKey));
      await tester.pumpAndSettle();
      expect(find.byKey(mapDesignateCenterButtonKey), findsOneWidget);

      await geste(_pointDansLaBande(tester));
      await tester.pumpAndSettle();
      return source;
    }

    testWidgetsOnWindows('Windows, 800 x 740, mode Restrictions : un appui '
        'long dans la bande du bouton, a cote de la pilule, ouvre l ecran', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = await dansLaBande(
        tester,
        (Offset at) => tester.longPressAt(at),
      );

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
    });

    testWidgetsOnWindows('Windows, 800 x 740, mode Restrictions : un clic '
        'droit dans la bande du bouton, a cote de la pilule, ouvre l ecran', (
      WidgetTester tester,
    ) async {
      final _PendingRestrictionSource source = await dansLaBande(
        tester,
        (Offset at) => tester.tapAt(at, buttons: kSecondaryButton),
      );

      expect(find.byType(RestrictionsScreen), findsOneWidget);
      expect(source.requested, hasLength(1));
    });
  });
}
