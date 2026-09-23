// Verrouille le pilotage clavier de la carte (`K2`, 2026-09-23) :
// `mapShortcuts()` traduit `+`/`=`/`−` et les quatre flèches en `Intent` —
// vérifié SANS widget, sur la carte pure — puis, sur `MapView` rendu
// (`FlutterMap` compris : le fichier de tête de `map_view.dart` déconseille
// de le monter, mais `map_view_test.dart` le fait déjà pour les boutons de
// zoom `K1`, sans qu'aucun chargement de tuile ne fasse échouer le test —
// l'étape 1 du plan, « sans rendre FlutterMap », n'est donc pas praticable
// pour l'ordre de tabulation : celui-ci inclut « carte » lui-même), l'ordre
// de tabulation déclaré, le focus visible, `Échap`, et l'étanchéité d'un
// raccourci face à un champ de saisie.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/geo/area_cluster.dart' show AreaLevel;
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart'
    show initialWarningTitle;
import 'package:martinpecheur/features/map/view/area_cluster_marker.dart';
import 'package:martinpecheur/features/map/view/map_controls.dart';
import 'package:martinpecheur/features/map/view/map_view.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';
import 'package:martinpecheur/features/shared/keyboard_focus_ring.dart';
import 'package:martinpecheur/features/shared/warning_link.dart';

/// Le focus courant (`FocusManager.instance.primaryFocus`) est-il porté par
/// un élément du sous-arbre de [ancestor] ? Même construction que
/// `test/features/shared/warning_link_test.dart` (`_hasFocusWithin`) :
/// [Focus.of] ne cherche que des ANCÊTRES, jamais l'inverse.
bool _focusedWithin(WidgetTester tester, Finder ancestor) {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  final Element root = tester.element(ancestor);
  bool found = false;
  void visit(Element element) {
    if (element == focusedContext) {
      found = true;
    }
    element.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// Un contour de focus ([KeyboardFocusRing]) est-il VISIBLE (couleur non
/// transparente) sur le [DecoratedBox] le plus proche à l'intérieur de
/// [ancestor] ? Vérifie la DÉCORATION, pas une capture d'écran (cas de test
/// du plan : « assertion sur la décoration de focus, non sur une
/// capture »).
bool _focusRingVisible(WidgetTester tester, Finder ancestor) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: ancestor, matching: find.byType(DecoratedBox)).first,
  );
  final BoxDecoration decoration = box.decoration as BoxDecoration;
  final Color? color = decoration.border?.top.color;
  return color != null && color != Colors.transparent;
}

/// Le `FocusNode` du marqueur portant [key] — le `Marker.key` de
/// `flutter_map` est passé au `Positioned` qui l'enveloppe (paquet
/// installé, `marker_layer.dart` : `Positioned(key: m.key, …)`), et
/// [KeyboardFocusRing] (descendant) porte le `Focus` qui l'expose. Utilisé
/// pour donner le focus DIRECTEMENT à un marqueur précis, sans Tab répété
/// (relecture du commanditaire du 2026-09-23 : un test à 1 200 `Tab` faisait
/// passer la suite complète de ~7 s à plus de 4 min).
FocusNode _markerFocusNode(WidgetTester tester, Key key) {
  final Focus focusWidget = tester.widget<Focus>(
    find.descendant(of: find.byKey(key), matching: find.byType(Focus)).first,
  );
  return focusWidget.focusNode!;
}

/// « carte » (`K2`) est un cas particulier des deux vérifications
/// ci-dessus : ce n'est pas un `KeyboardFocusRing` qui la porte, mais le
/// `FocusNode` interne de `flutter_map` lui-même, réutilisé via
/// `KeyboardOptions.focusNode` (voir `_mapOptions` dans `map_view.dart`) —
/// le `Focus` correspondant est donc profondément DESCENDANT de
/// `FlutterMap`, jamais son ancêtre. [_MapViewState] nomme ce nœud
/// (`debugLabel: 'carte'`) précisément pour rester repérable depuis un test
/// qui ne peut pas nommer son `FocusNode`, privé.
bool _carteFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'carte';

/// Le `DecoratedBox` du contour de focus de « carte » — trouvé en remontant
/// depuis `FlutterMap`, pour la même raison que [_carteFocused].
bool _carteFocusRingVisible(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.byType(FlutterMap),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final BoxDecoration decoration = box.decoration as BoxDecoration;
  final Color? color = decoration.border?.top.color;
  return color != null && color != Colors.transparent;
}

/// `position` du `DecoratedBox` de l'anneau de « carte » — relecture du
/// commanditaire du 2026-09-23 (🔴 2) : verrouille `DecorationPosition
/// .foreground`, jamais verrouillé par aucun test avant celui-ci
/// (`grep -rn "DecorationPosition.foreground" test/` rendait vide).
DecorationPosition _carteFocusRingPosition(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.byType(FlutterMap),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.position;
}

final class _EmptyStationPointRepository implements StationPointRepository {
  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async => const <StationPoint>[];

  @override
  Future<List<StationPoint>> all() async => const <StationPoint>[];
}

/// Enregistre la DERNIÈRE emprise demandée — c'est ce qui prouve qu'une
/// flèche a bien déplacé la caméra (`PanIntent`), sur le même modèle que
/// `_BoundsSpyStationsStub` de `map_view_test.dart`.
final class _BoundsSpyStationPointRepository implements StationPointRepository {
  Bounds? lastBounds;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    lastBounds = bounds;
    return const <StationPoint>[];
  }

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

MapViewModel _viewModel({
  StationPointRepository? stationPoints,
  OndeObservationRepository? onde,
  // `delay` (🔴 1, test des 1 200 marqueurs) : au niveau individuel, le
  // ViewModel étale son préchargement de vingt stations sur
  // `preloadInterval` (200 ms) RÉELLES — un `Timer` encore actif à la fin
  // du test fait échouer `flutter_test` (« A Timer is still pending »).
  // Injecté à `Future<void>.value()` : le préchargement se termine en un
  // tour de boucle d'événements, sans attente réelle.
  Future<void> Function(Duration)? delay,
}) => MapViewModel(
  stationPoints: stationPoints ?? _EmptyStationPointRepository(),
  observations: _EmptyHydroObservationRepository(),
  onde: onde ?? _EmptyOndeObservationRepository(),
  delay: delay,
);

/// [all] et [withinBounds] rendent tous deux [points] — suffisant pour le
/// regroupement par zone ADMINISTRATIVE (`all`, `ADR-015`) comme pour les
/// marqueurs individuels de l'emprise (`withinBounds`), sur le même modèle
/// que `_StationsStub` de `map_view_test.dart`.
final class _StationsStub implements StationPointRepository {
  _StationsStub(this.points);

  final List<StationPoint> points;

  /// La dernière emprise passée à [withinBounds] — `null` tant qu'aucun
  /// appel n'a eu lieu. Sert à prouver qu'une flèche a déplacé la caméra
  /// même quand le focus est sur un marqueur (et non sur le nœud de
  /// secours de « carte »).
  Bounds? lastBounds;

  @override
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  }) async {
    lastBounds = bounds;
    return points;
  }

  @override
  Future<List<StationPoint>> all() async => points;
}

/// Rend toujours [observations], quelle que soit l'emprise demandée — assez
/// pour les cas de tabulation sur des points ONDE individuels.
final class _OndeStub implements OndeObservationRepository {
  _OndeStub(this.observations);

  final List<OndeObservation> observations;

  @override
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  }) async => OndeSweep(observations: observations, unreadableRows: 0);

  @override
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  }) async => const <OndeObservation>[];
}

/// Une station dans [region], à une position DISTINCTE par [index] — même
/// esprit que `_stationsInRegion` de `map_view_model_test.dart`.
StationPoint _stationInRegion(
  AdministrativeArea region,
  int index, {
  required double latitude,
  required double longitude,
}) => StationPoint(
  code: StationCode('K4470${index.toString().padLeft(5, '0')}'),
  label: 'Station $index',
  latitude: latitude,
  longitude: longitude,
  region: region,
);

/// Une station SANS rattachement administratif — marqueur individuel à tout
/// zoom (BR-007).
StationPoint _lonelyStation(
  int index, {
  required double latitude,
  required double longitude,
}) => StationPoint(
  code: StationCode('K4471${index.toString().padLeft(5, '0')}'),
  label: 'Station isolée $index',
  latitude: latitude,
  longitude: longitude,
);

/// Un point ONDE sans rattachement — marqueur individuel à tout zoom.
OndePoint _lonelyOndePoint(
  String suffix, {
  required double latitude,
  required double longitude,
}) => OndePoint(
  code: OndeStationCode('0417$suffix'),
  label: 'Point $suffix',
  latitude: latitude,
  longitude: longitude,
  waterCourseLabel: 'Cours $suffix',
  departement: null,
);

OndeObservation _ondeObservationAt(OndePoint point) => OndeObservation(
  station: point.code,
  point: point,
  observedAt: DateTime.utc(2026, 9, 1),
  category: const Assec(),
  rawFlowCode: '3',
  officialLabel: 'Assec',
  campaignCode: '1',
);

/// `SingleActivator` (paquet Flutter installé,
/// `lib/src/widgets/shortcuts.dart`) ne redéfinit NI `operator ==` NI
/// `hashCode` : deux instances portant la MÊME touche ne sont jamais égales
/// par valeur, et `Map<ShortcutActivator, Intent>[]` ne les retrouve donc
/// jamais par une clé reconstruite ailleurs (constaté par test avant d'être
/// compris — la première version de ce fichier cherchait ainsi, et échouait
/// systématiquement). On PARCOURT `mapShortcuts()` à la place, et on compare
/// le [SingleActivator.trigger] qu'elle porte réellement.
Intent? _intentFor(LogicalKeyboardKey trigger) {
  for (final MapEntry<ShortcutActivator, Intent> entry
      in mapShortcuts().entries) {
    final ShortcutActivator activator = entry.key;
    if (activator is SingleActivator && activator.trigger == trigger) {
      return entry.value;
    }
  }
  return null;
}

/// Même principe que [_intentFor], pour un `CharacterActivator` (🟠 4,
/// relecture du commanditaire du 2026-09-23) — les touches physiques du
/// pavé principal (`SingleActivator`) ne couvrent pas un clavier AZERTY,
/// où `+` s'obtient par Maj+`=` : `CharacterActivator` regarde le
/// CARACTÈRE produit, pas la touche physique.
Intent? _intentForCharacter(String character) {
  for (final MapEntry<ShortcutActivator, Intent> entry
      in mapShortcuts().entries) {
    final ShortcutActivator activator = entry.key;
    if (activator is CharacterActivator && activator.character == character) {
      return entry.value;
    }
  }
  return null;
}

void main() {
  group('mapShortcuts — pure, sans widget', () {
    test('+ et = demandent un zoom avant (ZoomIntent(1))', () {
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.add,
        LogicalKeyboardKey.equal,
      ]) {
        final Intent? intent = _intentFor(key);
        expect(intent, isA<ZoomIntent>());
        expect((intent! as ZoomIntent).delta, 1);
      }
    });

    test('− demande un zoom arrière (ZoomIntent(-1))', () {
      final Intent? intent = _intentFor(LogicalKeyboardKey.minus);

      expect(intent, isA<ZoomIntent>());
      expect((intent! as ZoomIntent).delta, -1);
    });

    test('numpadAdd et numpadSubtract (pavé numérique) demandent un zoom '
        '(🟠 4)', () {
      expect(_intentFor(LogicalKeyboardKey.numpadAdd), isA<ZoomIntent>());
      expect(
        (_intentFor(LogicalKeyboardKey.numpadAdd)! as ZoomIntent).delta,
        1,
      );
      expect(_intentFor(LogicalKeyboardKey.numpadSubtract), isA<ZoomIntent>());
      expect(
        (_intentFor(LogicalKeyboardKey.numpadSubtract)! as ZoomIntent).delta,
        -1,
      );
    });

    test("CharacterActivator('+')/('-') demandent un zoom — couvre un clavier "
        'AZERTY réel, où + s obtient par Maj+= (🟠 4)', () {
      expect(_intentForCharacter('+'), isA<ZoomIntent>());
      expect((_intentForCharacter('+')! as ZoomIntent).delta, 1);
      expect(_intentForCharacter('-'), isA<ZoomIntent>());
      expect((_intentForCharacter('-')! as ZoomIntent).delta, -1);
    });

    test('les quatre flèches demandent un PanIntent de la bonne direction', () {
      final Map<LogicalKeyboardKey, AxisDirection> attendu =
          <LogicalKeyboardKey, AxisDirection>{
            LogicalKeyboardKey.arrowUp: AxisDirection.up,
            LogicalKeyboardKey.arrowDown: AxisDirection.down,
            LogicalKeyboardKey.arrowLeft: AxisDirection.left,
            LogicalKeyboardKey.arrowRight: AxisDirection.right,
          };

      attendu.forEach((LogicalKeyboardKey key, AxisDirection direction) {
        final Intent? intent = _intentFor(key);
        expect(intent, isA<PanIntent>());
        expect((intent! as PanIntent).direction, direction);
      });
    });

    test('aucune clé en double : onze raccourcis (🟠 4 : + numpadAdd, '
        'numpadSubtract, CharacterActivator(+/-)) — touches déclenchantes et '
        'caractères tous distincts', () {
      final List<ShortcutActivator> activators = mapShortcuts().keys.toList();
      expect(activators, hasLength(11));

      final List<LogicalKeyboardKey> triggers = activators
          .whereType<SingleActivator>()
          .map((SingleActivator activator) => activator.trigger)
          .toList();
      expect(triggers, hasLength(9));
      expect(
        triggers.toSet(),
        hasLength(9),
        reason:
            'une touche physique répétée écraserait silencieusement '
            'un autre raccourci dans la Map',
      );

      final List<String> characters = activators
          .whereType<CharacterActivator>()
          .map((CharacterActivator activator) => activator.character)
          .toList();
      expect(characters, hasLength(2));
      expect(characters.toSet(), hasLength(2));
    });
  });

  group('MapView — ordre de tabulation déclaré (K2)', () {
    testWidgets(
      'Tab parcourt, dans cet ordre : chips (2) → contrôles de zoom (3) → '
      'carte → lien du bandeau — puis reboucle',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: _viewModel())),
        );
        await tester.pumpAndSettle();

        // Chaque étape : soit un `Finder` (vérifié par `_focusedWithin`),
        // soit `null` pour « carte » — cas particulier, voir
        // [_carteFocused].
        final List<Finder?> ordreAttendu = <Finder?>[
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
          find.byKey(mapZoomInButtonKey),
          find.byKey(mapZoomOutButtonKey),
          find.byKey(mapRecenterButtonKey),
          null,
          find.byKey(warningLinkKey),
        ];

        for (final Finder? attendu in ordreAttendu) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          if (attendu == null) {
            expect(_carteFocused(), isTrue, reason: 'attendu à ce Tab : carte');
          } else {
            expect(
              _focusedWithin(tester, attendu),
              isTrue,
              reason: 'attendu à ce Tab : $attendu',
            );
          }
        }

        // Un Tab de plus reboucle sur le premier arrêt : l'ordre déclaré
        // couvre TOUT ce que Tab atteint sur cet écran, rien n'est laissé
        // hors groupe.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedWithin(tester, ordreAttendu.first!), isTrue);
      },
    );

    testWidgets(
      'une fiche ouverte s intercale entre carte et lien du bandeau',
      (WidgetTester tester) async {
        const Key fiche = Key('fiche-de-test-K2');
        await tester.pumpWidget(
          MaterialApp(
            home: MapView(
              viewModel: _viewModel(),
              onStationTap: (StationCode code) {},
              stationSheet: const _FocusableTestSheet(key: fiche),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // chips (×2) puis contrôles (×3) puis carte : six Tab avant la
        // fiche.
        for (int i = 0; i < 6; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          _focusedWithin(tester, find.byKey(fiche)),
          isTrue,
          reason: 'la fiche ouverte suit la carte, avant le lien du bandeau',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedWithin(tester, find.byKey(warningLinkKey)), isTrue);
      },
    );

    testWidgets('le focus est visible sur chaque arrêt de l ordre déclaré', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: MapView(viewModel: _viewModel())),
      );
      await tester.pumpAndSettle();

      // chips (×2), contrôles (×3), carte, lien : sept arrêts, dans l'ordre
      // déclaré. « carte » (index 5) est vérifiée à part
      // ([_carteFocusRingVisible]) — voir [_carteFocused].
      final List<Finder?> arrets = <Finder?>[
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
        find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        find.byKey(mapZoomInButtonKey),
        find.byKey(mapZoomOutButtonKey),
        find.byKey(mapRecenterButtonKey),
        null,
        find.byKey(warningLinkKey),
      ];

      for (final Finder? arret in arrets) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (arret == null) {
          expect(
            _carteFocusRingVisible(tester),
            isTrue,
            reason:
                'aucun contour visible sur « carte » alors qu elle a le '
                'focus',
          );
          expect(
            _carteFocusRingPosition(tester),
            DecorationPosition.foreground,
            reason:
                'sans `DecorationPosition.foreground` (🔴 2), l\'anneau de '
                '« carte » se peint SOUS `FlutterMap` et ses tuiles '
                "opaques, invisible même quand il a le focus",
          );
        } else {
          expect(
            _focusRingVisible(tester, arret),
            isTrue,
            reason: 'aucun contour visible sur $arret alors qu il a le focus',
          );
        }
      }
    });
  });

  group('MapView — les raccourcis clavier pilotent la caméra (K2)', () {
    // Un raccourci n'atteint le ViewModel que si le focus se trouve DÉJÀ
    // quelque part sous le `Shortcuts` de `MapView` (`Shortcuts` intercepte
    // en remontant depuis le focus courant — sans focus, rien ne remonte).
    // Un seul `Tab`, sur la première puce, suffit : peu importe LEQUEL des
    // arrêts déclarés porte le focus, `mapShortcuts()` reste actif partout
    // sous ce `Shortcuts` (cas de test séparé : seul un `TextField` HORS de
    // ce sous-arbre y échappe).
    Future<void> tabIntoScope(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    testWidgets('+ (ici =, le clavier de test ne connaît pas Add) zoome '
        'd un cran, exactement comme le bouton (K1)', (
      WidgetTester tester,
    ) async {
      final MapViewModel viewModel = _viewModel();
      await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
      await tester.pumpAndSettle();
      await tabIntoScope(tester);
      final double zoomInitial = viewModel.zoom!;

      // `LogicalKeyboardKey.add` n'a pas de touche physique connue du
      // simulateur de `flutter_test` (`KeyEventSimulator._findPhysicalKey`,
      // constaté à l'exécution) : `=` porte exactement le même `ZoomIntent`
      // dans `mapShortcuts()`, et EST simulable. `mapShortcuts — pure, sans
      // widget` couvre déjà `add` séparément, sans passer par un clavier
      // simulé.
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();

      expect(viewModel.zoom, zoomInitial + zoomStep);
    });

    testWidgets('− dézoome d un cran', (WidgetTester tester) async {
      final MapViewModel viewModel = _viewModel();
      await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
      await tester.pumpAndSettle();
      await tabIntoScope(tester);
      final double zoomInitial = viewModel.zoom!;

      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();

      expect(viewModel.zoom, zoomInitial - zoomStep);
    });

    testWidgets('une flèche déplace la caméra — nouvelle emprise demandée '
        'au dépôt de points', (WidgetTester tester) async {
      final _BoundsSpyStationPointRepository stations =
          _BoundsSpyStationPointRepository();
      final MapViewModel viewModel = _viewModel(stationPoints: stations);
      await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      await tabIntoScope(tester);

      // Niveau individuel (`ADR-015`) : c'est à ce niveau que
      // `StationPointRepository.withinBounds` est appelé pour l'emprise
      // courante — au niveau regroupé, seul `all()` sert au regroupement
      // par zone, et [stations.lastBounds] ne bougerait jamais (même
      // montée que `map_view_test.dart`, groupe « les boutons de zoom »).
      // Zoom au CLAVIER (`=`), pas à la souris : ce test reste un test du
      // pilotage clavier de bout en bout.
      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull, reason: 'niveau individuel atteint');
      final Bounds avant = stations.lastBounds!;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final Bounds apres = stations.lastBounds!;
      expect(
        apres.east,
        greaterThan(avant.east),
        reason: 'une flèche DROITE déplace la caméra vers l est',
      );
    });
  });

  group('MapView — Échap ferme la fiche ouverte, et rien d autre (K2)', () {
    testWidgets('ferme la fiche station', (WidgetTester tester) async {
      bool fermee = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: _viewModel(),
            onStationTap: (StationCode code) {},
            stationSheet: const SizedBox.shrink(),
            onCloseSheets: () => fermee = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Même remarque que le groupe précédent : `Échap` doit remonter
      // depuis un focus déjà posé quelque part sous ce `MapView`.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(fermee, isTrue);
    });

    testWidgets(
      'sans fiche branchée, Échap ne fait rien — MapView.onCloseSheets '
      'reste optionnel',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: _viewModel())),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Échap ne change ni l échelle active ni le zoom courant — rien '
        "d'autre que la fiche ne bouge", (WidgetTester tester) async {
      final MapViewModel viewModel = _viewModel();
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            onStationTap: (StationCode code) {},
            stationSheet: const SizedBox.shrink(),
            onCloseSheets: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final MapScaleKind scaleAvant = viewModel.scale;
      final double? zoomAvant = viewModel.zoom;

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(viewModel.scale, scaleAvant);
      expect(viewModel.zoom, zoomAvant);
    });
  });

  group('MapView — un raccourci ne se déclenche pas depuis un TextField '
      '(harnais de test)', () {
    testWidgets(
      'le focus dans un TextField, à côté de la carte, absorbe + sans '
      'déclencher ZoomIntent',
      (WidgetTester tester) async {
        final MapViewModel viewModel = _viewModel();
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        // Le TextField est un FRÈRE de MapView, hors de son `Shortcuts` —
        // exactement le harnais que le plan demande (révision du
        // 2026-09-22 : le modal d'acquittement ne peut pas le prouver,
        // lui, n'a qu'une case à cocher). `Scaffold` fournit le
        // `Material` qu'exige `TextField`, et borne la hauteur de la
        // `Column` — sans lui, `Expanded` déborde (`RenderFlex`, aucun
        // ancêtre de taille finie).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  TextField(controller: controller),
                  Expanded(child: MapView(viewModel: viewModel)),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final double zoomInitial = viewModel.zoom!;

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        // `=`, pas `Add` : même remarque que le groupe précédent — la
        // touche `Add` n'a pas de touche physique connue du simulateur de
        // `flutter_test`. Les deux portent le même `ZoomIntent` dans
        // `mapShortcuts()`.
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pumpAndSettle();

        expect(
          viewModel.zoom,
          zoomInitial,
          reason:
              "'+' doit rester un caractère de saisie ici, jamais un "
              'ZoomIntent : le TextField est HORS du sous-arbre de '
              "MapView, l'événement clavier ne peut pas atteindre ses "
              "Shortcuts",
        );
      },
    );
  });

  group('MapView — « carte » est un GROUPE de tabulation (arbitrage du '
      'commanditaire du 2026-09-23) : Tab y parcourt pastilles et marqueurs '
      'dans l ordre déterministe du ViewModel', () {
    const AdministrativeArea proche = AdministrativeArea(
      code: '24',
      label: 'Centre-Val de Loire',
    );
    const AdministrativeArea lointaine = AdministrativeArea(
      code: '45',
      label: 'Loiret',
    );

    /// Six Tab après le montage : deux puces, trois boutons de zoom, puis
    /// UN de plus pour ENTRER dans le groupe « carte » — chaque Tab
    /// déplace le focus DEPUIS l'arrêt courant vers le suivant (le
    /// premier Tab atteint la première puce, pas « avant » elle), donc
    /// le sixième atteint le premier élément de « carte ».
    Future<void> tabJusquACarte(WidgetTester tester) async {
      for (int i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
    }

    testWidgets(
      'zoom 5 : Tab atteint la pastille la plus proche du centre, puis '
      'la suivante — Entrée sur la première fait passer level à '
      'departement (Z4), puis Tab atteint le lien du bandeau',
      (WidgetTester tester) async {
        // Centre de la carte au démarrage : (initialMapCenterLatitude,
        // initialMapCenterLongitude) = (46.6, 2.2).
        final List<StationPoint> stations = <StationPoint>[
          // '24', barycentre proche du centre (46,25 ; 3) : deux membres
          // ÉCARTÉS (même fixture que `map_view_test.dart`, groupe « la
          // sélection d'une pastille ») pour que l'ajustement naturel de
          // la caméra retombe sous le zoom 7, et que le PLANCHER de
          // `zoomTargetFor` (`regionClustersBelowZoom`) fasse passer le
          // niveau à département plutôt qu'à l'individuel — deux membres
          // trop proches zoomeraient jusqu'à l'individuel (`CoverBounds`
          // sans plancher effectif).
          _stationInRegion(proche, 1, latitude: 49.5, longitude: 4.5),
          _stationInRegion(proche, 2, latitude: 43, longitude: 1.5),
          // '45', barycentre plus loin — mais À L'INTÉRIEUR du viewport
          // rendu au zoom 5 (« la France métropolitaine tient à
          // l'écran », `map_view.dart`) : `MarkerLayer` NE DESSINE PAS
          // les marqueurs hors du viewport courant (constaté par test —
          // un cluster hors écran, même présent dans
          // `MapViewModel.clusters`, ne produit aucun `AreaClusterMarker`
          // trouvable).
          _stationInRegion(lointaine, 3, latitude: 48.8, longitude: 7),
          _stationInRegion(lointaine, 4, latitude: 48.85, longitude: 7.05),
        ];
        final MapViewModel viewModel = _viewModel(
          stationPoints: _StationsStub(stations),
        );
        await tester.pumpWidget(
          MaterialApp(home: MapView(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();
        expect(viewModel.level, AreaLevel.region);
        expect(find.byType(AreaClusterMarker), findsNWidgets(2));

        await tabJusquACarte(tester);
        final Finder ancestors = find.ancestor(
          of: find.byType(AreaClusterMarker),
          matching: find.byType(GestureDetector),
        );
        // Premier arrêt de « carte » : la pastille '24', la plus proche.
        expect(_focusedWithin(tester, ancestors.at(0)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(
          viewModel.level,
          AreaLevel.departement,
          reason: 'Entrée sur une pastille = le tap (Z4)',
        );
      },
    );

    testWidgets('zoom 9 (échelle débit) : Tab atteint un marqueur de station, '
        'Entrée appelle onStationTap UNE FOIS avec son code', (
      WidgetTester tester,
    ) async {
      final List<StationPoint> stations = <StationPoint>[
        _lonelyStation(1, latitude: 46.6, longitude: 2.2),
        _lonelyStation(2, latitude: 50, longitude: 10),
      ];
      final List<StationCode> tapped = <StationCode>[];
      final MapViewModel viewModel = _viewModel(
        stationPoints: _StationsStub(stations),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            onStationTap: tapped.add,
            stationSheet: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull, reason: 'niveau individuel');

      await tabJusquACarte(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tapped, hasLength(1));
      expect(tapped.single, stations.first.code);
    });

    testWidgets('zoom 9 (échelle écoulement) : Tab atteint un marqueur ONDE, '
        'Entrée appelle onOndeTap UNE FOIS avec son point', (
      WidgetTester tester,
    ) async {
      final OndePoint point1 = _lonelyOndePoint(
        '0001',
        latitude: 46.6,
        longitude: 2.2,
      );
      final OndePoint point2 = _lonelyOndePoint(
        '0002',
        latitude: 50,
        longitude: 10,
      );
      final List<OndePoint> tapped = <OndePoint>[];
      final MapViewModel viewModel = _viewModel(
        onde: _OndeStub(<OndeObservation>[
          _ondeObservationAt(point1),
          _ondeObservationAt(point2),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            onOndeTap: tapped.add,
            ondeSheet: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull, reason: 'niveau individuel');

      await tabJusquACarte(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tapped, hasLength(1));
      expect(tapped.single.code, point1.code);
    });

    testWidgets('après le dernier élément de « carte », Tab atteint le lien du '
        'bandeau', (WidgetTester tester) async {
      final List<StationPoint> stations = <StationPoint>[
        _lonelyStation(1, latitude: 46.6, longitude: 2.2),
      ];
      final MapViewModel viewModel = _viewModel(
        stationPoints: _StationsStub(stations),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            // Un marqueur SANS rappel de tap n'est pas focalisable
            // (`canRequestFocus`, `_stationMarkers`) : rien à activer,
            // rien à atteindre — ce test veut au contraire vérifier
            // qu'un marqueur INTERACTIF reste le dernier arrêt avant le
            // lien du bandeau.
            onStationTap: (StationCode code) {},
            stationSheet: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull);

      // Un seul marqueur au niveau individuel : un Tab de plus après
      // avoir atteint « carte » doit sortir du groupe.
      await tabJusquACarte(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_focusedWithin(tester, find.byKey(warningLinkKey)), isTrue);
    });

    testWidgets('les flèches déplacent la carte même quand le focus est sur un '
        'marqueur', (WidgetTester tester) async {
      final _StationsStub stations = _StationsStub(<StationPoint>[
        _lonelyStation(1, latitude: 46.6, longitude: 2.2),
      ]);
      final MapViewModel viewModel = _viewModel(stationPoints: stations);
      await tester.pumpWidget(MaterialApp(home: MapView(viewModel: viewModel)));
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull);
      await tabJusquACarte(tester);
      expect(
        _carteFocused(),
        isFalse,
        reason:
            'le focus doit être descendu sur le marqueur réel, pas '
            'resté sur le nœud de secours de « carte »',
      );
      final Bounds avant = stations.lastBounds!;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final Bounds apres = stations.lastBounds!;
      expect(
        apres.east,
        greaterThan(avant.east),
        reason:
            'le focus sur un marqueur ne doit pas empêcher la '
            "flèche d'agir",
      );
    });
  });

  group('MapView — relecture du commanditaire du 2026-09-23 (mutations '
      'survivantes, 🟢 7)', () {
    testWidgets('Shift+Tab parcourt l ordre inverse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: MapView(viewModel: _viewModel())),
      );
      await tester.pumpAndSettle();

      // Deux Tab : la deuxième puce d'échelle a le focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _focusedWithin(
          tester,
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.debit)),
        ),
        isTrue,
      );

      // Shift+Tab : retour à la première puce, jamais à la troisième.
      // `sendKeyEvent` n'a pas de paramètre `shift` : Maj se simule en
      // deux événements distincts, appui puis Tab puis relâchement.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        _focusedWithin(
          tester,
          find.byKey(const ValueKey<MapScaleKind>(MapScaleKind.ecoulement)),
        ),
        isTrue,
      );
    });

    testWidgets('Espace seul active un marqueur — même effet qu Entrée', (
      WidgetTester tester,
    ) async {
      final List<StationCode> tapped = <StationCode>[];
      final MapViewModel viewModel = _viewModel(
        stationPoints: _StationsStub(<StationPoint>[
          _lonelyStation(1, latitude: 46.6, longitude: 2.2),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            onStationTap: tapped.add,
            stationSheet: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      for (int i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(tapped, hasLength(1));
    });

    testWidgets('Échap dans WarningWindow ferme la fenêtre SANS appeler '
        'onCloseSheets — ce n est pas une fiche', (WidgetTester tester) async {
      bool closeSheetsAppele = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: _viewModel(),
            onCloseSheets: () => closeSheetsAppele = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(warningLinkKey));
      await tester.pumpAndSettle();
      expect(find.text(initialWarningTitle), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text(initialWarningTitle), findsNothing);
      expect(
        closeSheetsAppele,
        isFalse,
        reason:
            'la fenêtre d avertissement (`WarningWindow`) se ferme par '
            'sa propre route (`showDialog`/`Navigator`), pas par '
            '`MapView.onCloseSheets` — elle ne fait pas partie du '
            'sous-arbre `Shortcuts` de `MapView`',
      );
    });

    testWidgets('le focus reste sur la MÊME station après un déplacement qui '
        'change l ordre — Marker.key évite la réconciliation par POSITION '
        '(🟠 3)', (WidgetTester tester) async {
      // Deux stations : « proche » est la plus proche du centre au
      // départ, « lointaine » ne l est pas — après un déplacement vers
      // l est, leurs distances au centre s inversent (`lointaine`
      // devient la plus proche), ce qui inverse leur position dans
      // `orderedIndividualStations`. `Marker.key` doit garder le focus
      // sur LA MÊME station, jamais sur celle qui prend sa position
      // dans la liste.
      final StationPoint proche = _lonelyStation(
        1,
        latitude: 46.6,
        longitude: 2.2,
      );
      final StationPoint lointaine = _lonelyStation(
        2,
        latitude: 46.6,
        longitude: 2.9,
      );
      final MapViewModel viewModel = _viewModel(
        stationPoints: _StationsStub(<StationPoint>[proche, lointaine]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MapView(
            viewModel: viewModel,
            onStationTap: (StationCode code) {},
            stationSheet: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      viewModel.selectScale(MapScaleKind.debit);
      await tester.pumpAndSettle();
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(mapZoomInButtonKey));
        await tester.pumpAndSettle();
      }
      expect(viewModel.level, isNull);

      // Six Tab pour entrer dans « carte » : `proche` est en tête
      // (`orderedIndividualStations`, distance croissante).
      for (int i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(
        _focusedWithin(tester, find.byKey(ValueKey<String>(proche.code.value))),
        isTrue,
        reason: 'proche est la plus proche du centre au départ',
      );

      // Un geste directement au ViewModel — PAS une flèche au clavier —
      // pour changer l'ordre SANS déplacer la caméra RÉELLE de
      // `flutter_map` : sinon, un déplacement assez grand pour inverser
      // l'ordre risque aussi de faire sortir `proche` du viewport
      // (culling interne à `MarkerLayer`, constaté par test), ce qui ne
      // prouverait plus rien sur `Marker.key` — seulement que la
      // station est sortie de l'écran. Le centre de cette emprise est
      // celui de `lointaine` : elle devient la plus proche, et bascule
      // donc en tête de `orderedIndividualStations`.
      await viewModel.onGestureEnded(
        Bounds(west: 2.85, south: 46.55, east: 2.95, north: 46.65),
        zoom: individualMarkersFromZoom,
      );
      await tester.pumpAndSettle();

      expect(
        _focusedWithin(tester, find.byKey(ValueKey<String>(proche.code.value))),
        isTrue,
        reason:
            'le focus doit rester sur LA MÊME station (sa clé), même '
            "si l'ordre de la liste a changé — sans `Marker.key`, "
            'Flutter réconcilie par position et ferait glisser le '
            "focus sur `lointaine`, qui prend la place de `proche` "
            'dans la liste',
      );
    });

    testWidgets(
      '1 200 marqueurs synthétiques : après le dernier, Tab atteint la '
      'fiche ouverte puis « ⚠ Avertissement », jamais l inverse (🔴 1)',
      (WidgetTester tester) async {
        // ⚠️ Fixture SYNTHÉTIQUE, signalée comme telle (`CLAUDE.md`) :
        // 1 200 stations sans rapport avec un référentiel réel,
        // seulement assez nombreuses pour dépasser l ancien pas de
        // 0,001 (qui débordait dans l ordre du groupe suivant dès 500
        // éléments). Toutes très proches du centre initial pour rester
        // dans le viewport au zoom individuel — `flutter_map` ne
        // construit pas les marqueurs hors champ (constaté par test,
        // groupe « carte est un GROUPE de tabulation »).
        final List<StationPoint> stations = <StationPoint>[
          for (int i = 0; i < 1200; i++)
            _lonelyStation(
              i,
              latitude: 46.6 + (i % 40) * 0.001,
              longitude: 2.2 + (i ~/ 40) * 0.001,
            ),
        ];
        final MapViewModel viewModel = _viewModel(
          stationPoints: _StationsStub(stations),
          delay: (Duration duration) => Future<void>.value(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MapView(
              viewModel: viewModel,
              onStationTap: (StationCode code) {},
              stationSheet: const _FocusableTestSheet(key: Key('fiche-1200')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        viewModel.selectScale(MapScaleKind.debit);
        await tester.pumpAndSettle();
        for (int i = 0; i < 4; i++) {
          await tester.tap(find.byKey(mapZoomInButtonKey));
          await tester.pumpAndSettle();
        }
        expect(viewModel.level, isNull);
        // `find.byType` seul remonterait aussi la pastille de référence
        // que porte `MapLegend` (toujours rendue, `BR-008`) : on ne
        // compte que les marqueurs RÉELLEMENT dessinés sur la carte,
        // sous `MarkerLayer` (même précaution que `map_view_test.dart`).
        expect(
          find.descendant(
            of: find.byType(MarkerLayer),
            matching: find.byType(StationMarkerDot),
          ),
          findsNWidgets(1200),
        );

        // ⚠️ Relecture du commanditaire du 2026-09-23 : PAS de boucle de
        // 1 200 `nextFocus()`/Tab — ce test à lui seul faisait passer la
        // suite complète de ~7 s à 4 min 10 s, inacceptable pour la boucle
        // de développement. `FocusNode.requestFocus()` donne le focus
        // DIRECTEMENT au DERNIER marqueur (index 1 199, celui dont l'ordre
        // aurait le plus débordé avec l'ancien pas de 0,001) ; un SEUL
        // `Tab` suffit ensuite à prouver ce que 1 200 auraient prouvé un à
        // un.
        final StationPoint dernierMarqueur = stations.last;
        final FocusNode nodeDuDernierMarqueur = _markerFocusNode(
          tester,
          ValueKey<String>(dernierMarqueur.code.value),
        );
        nodeDuDernierMarqueur.requestFocus();
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus,
          nodeDuDernierMarqueur,
          reason: 'le focus doit avoir atteint le 1 200ᵉ marqueur',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          _focusedWithin(tester, find.byKey(const Key('fiche-1200'))),
          isTrue,
          reason:
              'après le dernier (1 200ᵉ) marqueur, Tab doit atteindre la '
              'fiche ouverte AVANT « ⚠ Avertissement » — avec l\'ancien '
              "pas de 0,001, l'ordre du 1 200ᵉ marqueur aurait dépassé "
              '3,5 (fiche) et même 4 (« ⚠ Avertissement »).',
        );

        // Symétrique : Shift+Tab depuis la fiche ramène au DERNIER
        // marqueur, jamais ailleurs.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus,
          nodeDuDernierMarqueur,
          reason:
              'Shift+Tab depuis la fiche doit revenir sur le 1 200ᵉ '
              'marqueur, symétrique du Tab qui l\'a atteinte',
        );

        // Un Tab de plus, depuis la fiche : « ⚠ Avertissement ».
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedWithin(tester, find.byKey(warningLinkKey)), isTrue);
      },
    );
  });
}

/// Un panneau de fiche MINIMAL mais FOCALISABLE, pour vérifier que l'ordre
/// de tabulation déclaré s'intercale correctement autour de lui — les vrais
/// panneaux de fiche (`StationSheetPanel`, `OndeSheetPanel`) ont leur propre
/// bouton de fermeture, focalisable pour la même raison ; ce double suffit à
/// prouver l'INSERTION dans l'ordre, sans dépendre de leur structure interne.
class _FocusableTestSheet extends StatelessWidget {
  const _FocusableTestSheet({super.key});

  @override
  Widget build(BuildContext context) =>
      const KeyboardFocusRing(child: SizedBox(width: 10, height: 10));
}
