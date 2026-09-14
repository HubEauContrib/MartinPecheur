// La vue de la tranche carte (MVVM, ADR-014) : le fond IGN Géoplateforme,
// son attribution en toutes lettres — une condition d'usage de la donnée sous
// Licence Ouverte, jamais une finition (`04-ui.md` § 3) — et les stations du
// référentiel en marqueurs du viewport élargi. Les couches sont produites par
// [buildMapLayers], une fonction PURE : rendre un `FlutterMap` dans un test
// déclenche des chargements de tuiles que l'environnement de test refuse.
//
// Les **surcouches** — légende, bandeau d'erreur, panneau de fiche,
// attribution — sont produites de la même façon, par [buildMapOverlays]
// (relecture du 2026-09-14). Leur câblage n'était couvert par aucun test tant
// qu'il vivait dans `build` : ce qui garantit qu'une légende est TOUJOURS
// rendue, même en erreur (`BR-008`), tenait au fait que personne n'avait
// touché à ce `Stack`. Les deux fonctions pures rendent l'écran entier
// vérifiable sans monter de carte.
//
// ⚠️ Au zoom national, les 4 150 zones de tap de 44 pt se chevauchent, et le
// marqueur qui reçoit le tap est le plus tardif dans l'ordre de l'asset, pas
// le plus proche du doigt — écart assumé pour T1, acté sous `U1` dans le plan
// (`docs/superpowers/plans/2026-09-13-t1-fiche-station-et-avertissements.md`).
//
// ⚠️ Au zoom national, la France entière est visible : les 4 150 stations
// sont TOUTES dessinées — c'est le prix réel de l'approche par défaut
// (`F2c`, aucun clustering tant qu'aucune mesure ne le réhabilite), pas un
// défaut caché. La pastille ([StationMarkerDot], `station_marker.dart`) est
// une forme DESSINÉE, jamais un glyphe de police : un glyphe coûterait une
// passe de texte par marqueur, inutile pour 4 150 occurrences.
//
// La pastille porte désormais l'état de sa station (T1-U2) : la couleur ne
// distingue rien — en T1 tout est « Indéterminé » (`BR-004`, aucun
// percentile avant `ADR-003`) — ce sont le motif et le libellé annoncé qui
// séparent une mesure fraîche d'une absence constatée (`04-ui.md` § 3).
// [MapLegend] nomme l'échelle active en permanence, jamais repliée
// (`BR-008`) : sans elle, une teinte réutilisée d'une échelle à l'autre
// rendrait la carte ambiguë.
//
// La vue ne fait que **brancher** : elle observe [MapViewModel], traduit les
// événements de `flutter_map` en emprises de domaine, et n'appelle aucun
// dépôt. C'est le ViewModel qui appelle le dépôt, directement et de façon
// typée (R3, arbitrage 2026-09-13 — le registre de messages et ses
// gestionnaires ont disparu).
//
// Relecture M3/M4 (2026-09-13), deux défauts corrigés et toujours en vigueur :
// - `MapOptions` était reconstruite à chaque `build` avec des fermetures
//   inline : `MapOptions ==` (paquet flutter_map 8.3.2,
//   `lib/src/map/options/options.dart`) compare chaque callback par égalité
//   de fonction, et deux fermetures inline ne sont jamais égales même à
//   code identique. `flutter_map` remplaçait donc l'état de son contrôleur
//   à chaque frame (NFR-01). [_mapOptions] est un champ `late final`,
//   construit une seule fois, avec un tear-off de méthode
//   (`_handleMapEvent`) — un tear-off d'une méthode d'instance reste égal à
//   lui-même d'un accès à l'autre.
// - la requête d'emprise partait à chaque frame d'un glisser : dix frames
//   faisaient dix requêtes et reconstruisaient dix fois les 4 150 marqueurs.
//   `onPositionChanged` n'est plus câblé du tout : la requête part sur
//   [_handleMapEvent], câblé à `MapOptions.onMapEvent`, uniquement pour les
//   événements de **fin** de geste — voir [shouldRefreshOn]. La marge
//   proportionnelle
//   `defaultViewportMargin` (`lib/domain/geo/viewport_filter.dart`) couvre le
//   déplacement entre-temps.
//
// Une erreur de lecture n'est pas avalée : [MapViewModel.error] la porte, et
// la vue affiche [MapErrorBanner] au lieu d'une carte muette (`BR-007`).
//
// ⚠️ La fiche station est **injectée**, pas importée (T1-U1). La règle
// `feature-vers-feature` de `test/architecture/layers_test.dart` interdit à
// une tranche d'en citer une autre : `features/map/` ne peut donc nommer ni
// `features/station_sheet/view/…`, ni son ViewModel. [MapView] reçoit donc
// le panneau déjà composé ([MapView.stationSheet], un `Widget`) et le rappel
// de tap ([MapView.onStationTap], un `void Function(StationCode)`) ; c'est
// `main.dart`, la racine de composition — le seul fichier exempté de ces
// règles — qui assemble `StationSheetPanel` avec son ViewModel et les passe
// ici. La carte reste ignorante de ce qu'elle affiche par-dessus elle : elle
// **branche**, elle ne décide pas.
//
// Un `Widget` déjà construit suffit, et un `WidgetBuilder` n'apporterait
// rien : le panneau injecté est un `ListenableBuilder` sur le ViewModel de
// la fiche, qui se reconstruit tout seul quand la fiche change d'état — la
// carte, elle, n'a aucune raison d'être reconstruite pour cela.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/observation/station_map_state.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';
import 'package:martinpecheur/features/map/view/ign_tile_template.dart';
import 'package:martinpecheur/features/map/view/map_legend.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';
import 'package:martinpecheur/features/map/view_model/map_scale.dart';
import 'package:martinpecheur/features/map/view_model/map_view_model.dart';

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLatitude = 46.6;

/// Centre initial de la carte : France métropolitaine.
const double initialMapCenterLongitude = 2.2;

/// Zoom initial — la France métropolitaine tient à l'écran.
const double initialMapZoom = 5;

/// Zoom minimal — en dessous, la France n'emplit plus l'écran.
const double minimumMapZoom = 4;

/// Zoom maximal — aligné sur le niveau natif maximal du plan IGN
/// ([ignMaxNativeZoom]) : au-delà, le serveur n'a rien à offrir de plus fin.
const double maximumMapZoom = ignMaxNativeZoom * 1.0;

/// État par défaut de [buildMapLayers.stateOf] : aucune requête n'a abouti
/// pour cette station. Une fonction de premier niveau, et non une fermeture
/// `(_) => const NonChargee()` — seul un tear-off de fonction de premier
/// niveau est une expression constante, donc utilisable comme valeur par
/// défaut d'un paramètre.
StationMapState _alwaysUnloaded(StationCode code) => const NonChargee();

/// Décide si [event] doit déclencher un nouveau chargement d'emprise.
/// Fonction pure, testable sans widget ni `FlutterMap` — construite avec les
/// constructeurs de `MapEvent` du paquet, ou testée par son type runtime.
///
/// Elle vit du côté **vue** et non du ViewModel : son seul paramètre est un
/// type de `flutter_map`, et un ViewModel ne connaît pas la bibliothèque de
/// carte (ADR-014). C'est la vue qui traduit un événement de geste en
/// emprise de domaine.
///
/// Seuls les événements de **fin** de geste répondent `true` : ce sont les
/// classes `…End` du paquet flutter_map 8.3.2
/// (`lib/src/gestures/map_events.dart`) — [MapEventMoveEnd] (ligne 219, fin
/// d'un glisser), [MapEventFlingAnimationEnd] (ligne 262, fin d'un fling),
/// [MapEventDoubleTapZoomEnd] (ligne 306, fin d'un double-tap) et
/// [MapEventRotateEnd] (ligne 342, fin d'une rotation) — plus
/// [MapEventScrollWheelZoom] (ligne 283) : le paquet ne lui connaît pas de
/// variante `…End`, chaque cran de molette y est déjà un geste complet et
/// discret. Un événement intermédiaire (`MapEventMove`, émis à chaque frame
/// d'un glisser en cours) répond `false` : la marge proportionnelle
/// `defaultViewportMargin` (`lib/domain/geo/viewport_filter.dart`) couvre déjà
/// le déplacement jusqu'au prochain relâcher — charger à chaque frame
/// reconstruirait les 4 150 marqueurs pour rien (NFR-01).
bool shouldRefreshOn(MapEvent event) =>
    event is MapEventMoveEnd ||
    event is MapEventFlingAnimationEnd ||
    event is MapEventScrollWheelZoom ||
    event is MapEventDoubleTapZoomEnd ||
    event is MapEventRotateEnd;

/// Construit les couches de la carte, dans l'ordre où `FlutterMap` doit les
/// empiler — le fond de tuiles **premier**, les marqueurs ensuite. Fonction
/// pure, testable sans rendu ni accès réseau.
///
/// Ne refiltre pas [stations] à une emprise : le filtre fait foi côté dépôt
/// (`StationPointRepository`, marge `defaultViewportMargin` comprise) — le
/// dupliquer ici masquerait un bug de marge plutôt que de le révéler, et un
/// filtre à marge nulle supprimerait purement et simplement les marqueurs de
/// la marge que le dépôt vient de rapporter. [buildMapLayers] dessine
/// exactement ce que le ViewModel lui donne.
///
/// Une couche de marqueurs **vide n'est pas ajoutée** : au moins une station
/// visible est nécessaire pour que `MarkerLayer` apparaisse dans la liste.
///
/// [onStationTap] est appelé avec le code de la station tapée. Nommé et
/// **optionnel** : le `Marker` existe déjà sans lui — la carte de T0 n'était
/// pas interactive — et un appelant qui ne veut pas de tap n'a rien à
/// fournir. Sans rappel, le marqueur reste inerte : `GestureDetector` sans
/// `onTap` ne participe pas au test de toucher, même en
/// [HitTestBehavior.opaque].
///
/// [stateOf] rend l'état d'affichage d'une station — en production,
/// `MapViewModel.stateOf`. Il a une **valeur par défaut**
/// ([_alwaysUnloaded], donc [NonChargee] partout) plutôt que d'être requis :
/// une carte qui ne sait rien de ses stations est exactement ce que décrit
/// [NonChargee] (`BR-007`), et les appelants qui n'affichent pas d'état —
/// les tests de tuiles, de tap et de taille — n'ont pas à fabriquer une
/// fonction pour le dire.
List<Widget> buildMapLayers({
  required List<StationPoint> stations,
  void Function(StationCode code)? onStationTap,
  StationMapState Function(StationCode code) stateOf = _alwaysUnloaded,
}) {
  // Copié dans un local `final` : la promotion de type survit ainsi dans la
  // fermeture construite pour chaque marqueur.
  final void Function(StationCode code)? handleTap = onStationTap;
  final List<Widget> layers = <Widget>[
    TileLayer(
      urlTemplate: ignTileUrlTemplate,
      tileDimension: ignTileDimension,
      maxNativeZoom: ignMaxNativeZoom,
      userAgentPackageName: ignUserAgentPackageName,
    ),
  ];

  if (stations.isNotEmpty) {
    layers.add(
      MarkerLayer(
        markers: stations
            .map(
              (StationPoint station) => Marker(
                // ⚠️ GeoJSON range les coordonnées [longitude, latitude] ;
                // `LatLng` prend la latitude EN PREMIER. `StationPoint` a
                // déjà absorbé cet écart à l'analyse (stations_asset.dart) —
                // ici, `station.latitude`/`station.longitude` sont déjà dans
                // l'ordre attendu par `LatLng`.
                point: LatLng(station.latitude, station.longitude),
                // Le marqueur mesure la ZONE DE TAP (44 pt, `04-ui.md`
                // § 3) ; la pastille de 12 px reste centrée dedans. Les
                // deux tailles sont distinctes à dessein : ce qui se voit
                // et ce qui se touche n'ont pas la même exigence.
                width: stationMarkerTapTarget,
                height: stationMarkerTapTarget,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleTap == null
                      ? null
                      : () => handleTap(station.code),
                  child: Semantics(
                    button: true,
                    label: _markerSemanticLabel(station, stateOf(station.code)),
                    // ⚠️ `excludeSemantics` : [StationMarkerDot] porte son
                    // PROPRE `Semantics` — c'est ce qui rend la pastille
                    // annonçable telle quelle en légende, où elle n'a pas de
                    // station à nommer. Sur la carte, le marqueur reprend
                    // l'annonce pour y joindre le nom de la station, et
                    // masque celle de la pastille : un marqueur, un seul
                    // nœud sémantique. Sans cela chaque station en porterait
                    // deux, et le lecteur d'écran annoncerait l'état deux
                    // fois.
                    excludeSemantics: true,
                    child: Center(
                      child: SizedBox(
                        width: stationMarkerSize,
                        height: stationMarkerSize,
                        child: StationMarkerDot(state: stateOf(station.code)),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  return layers;
}

/// L'annonce d'un marqueur au lecteur d'écran : le **nom de la station**,
/// puis son libellé d'état quand il y en a un.
///
/// « La Loire à Blois » pour une mesure fraîche ou une station pas encore
/// chargée — ni l'une ni l'autre n'ont d'état à annoncer (`BR-005`,
/// `BR-007`) — et « La Loire à Blois, Aucune donnée disponible ici. » quand
/// l'état parle. `04-ui.md` § 3 donne l'annonce attendue : elle **nomme la
/// station**, un marqueur muet ne dit pas où l'on est.
///
/// Le libellé d'état vient du domaine (`stationMapStateLabel`), jamais d'une
/// recopie locale.
///
/// ⚠️ **Dette assumée** : `BR-008` demande que l'annonce préfixe l'échelle
/// active (« écoulement : à sec »). Elle ne le fait pas encore — l'échelle
/// n'est pas connue de [buildMapLayers], et `U3` pose la bascule d'échelle
/// avec les marqueurs ONDE. À trancher là.
String _markerSemanticLabel(StationPoint station, StationMapState state) {
  final String stateLabel = stationMapStateLabel(state);
  return stateLabel.isEmpty ? station.label : '${station.label}, $stateLabel';
}

/// Construit les surcouches de la carte, dans l'ordre où elles doivent être
/// empilées PAR-DESSUS le `FlutterMap`. Fonction pure, testable sans rendre
/// de carte — même esprit que [buildMapLayers], et pour la même raison :
/// l'environnement de test refuse le chargement de tuiles.
///
/// Dans l'ordre :
/// 1. **la légende, toujours** (`MapLegend`, en haut à droite) — `BR-008` en
///    fait une pièce obligatoire : les trois échelles du produit réutilisent
///    les mêmes teintes, et c'est elle qui nomme celle qui est active. Elle
///    est rendue quel que soit [error] : une carte en panne reste une carte
///    qu'on lit ;
/// 2. le **bandeau d'erreur**, seulement si [error] n'est pas nul
///    (`BR-007` : jamais une carte muette). Posé en haut à **gauche**, la
///    largeur bornée par [legendMaxWidth] réservée à la légende : il
///    n'empiète jamais dessus ;
/// 3. le **panneau de fiche**, s'il est fourni, en bas à gauche ;
/// 4. l'**attribution IGN**, toujours, en bas à droite — une condition
///    d'usage de la Licence Ouverte, jamais une finition (`04-ui.md` § 3).
List<Widget> buildMapOverlays({
  required MapScaleKind scale,
  required Object? error,
  Widget? stationSheet,
}) {
  final Object? bannerError = error;
  final Widget? sheet = stationSheet;

  return <Widget>[
    Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(_overlayPadding),
        child: MapLegend(scale: scale),
      ),
    ),
    if (bannerError != null)
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          // La marge de droite réserve toute la place de la légende, plus
          // les deux marges qui l'encadrent : le bandeau peut envelopper
          // son texte, il ne peut pas passer dessous.
          padding: const EdgeInsets.fromLTRB(
            _overlayPadding,
            _overlayPadding,
            legendMaxWidth + 2 * _overlayPadding,
            _overlayPadding,
          ),
          child: MapErrorBanner(error: bannerError),
        ),
      ),
    if (sheet != null)
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          // Marge basse plus épaisse : elle dégage le bandeau d'attribution
          // IGN, qui reste lisible en toutes circonstances (Licence
          // Ouverte, `04-ui.md` § 3).
          padding: const EdgeInsets.fromLTRB(
            _overlayPadding,
            _overlayPadding,
            _overlayPadding,
            _sheetBottomPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
            child: sheet,
          ),
        ),
      ),
    const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.all(_overlayPadding),
        child: IgnAttributionBadge(),
      ),
    ),
  ];
}

/// Marge d'une surcouche au bord de la carte, en pixels logiques.
const double _overlayPadding = 8;

/// Marge basse du panneau de fiche : elle dégage l'attribution IGN.
const double _sheetBottomPadding = 32;

/// Largeur maximale du panneau de fiche, en pixels logiques.
const double _sheetMaxWidth = 420;

/// Bandeau d'erreur minimal (`BR-007`) : affiché à la place d'une carte
/// muette quand le dépôt n'a pas pu répondre — panne de lecture de l'asset
/// aujourd'hui, panne réseau en T1. Widget séparé, testable sans monter de
/// `FlutterMap` (même contrainte que [IgnAttributionBadge]).
class MapErrorBanner extends StatelessWidget {
  const MapErrorBanner({required this.error, super.key});

  /// L'erreur à afficher. Son `toString()` est montré tel quel : ce n'est
  /// pas un message pensé pour l'utilisateur final, mais T0 n'a rien de
  /// mieux tant que les avertissements (`BR-012`, `BR-013`) ne sont pas
  /// arrivés.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.red),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          "Les stations n'ont pas pu être chargées : $error",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Bandeau d'attribution IGN Géoplateforme, exigé par la Licence Ouverte.
/// Porte son propre fond opaque : un texte posé directement sur un fond de
/// carte quelconque ne tient aucun contraste (`04-ui.md` § 3). Entièrement
/// `const` : rien ici ne dépend de l'état de l'écran.
class IgnAttributionBadge extends StatelessWidget {
  const IgnAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(ignAttribution, style: TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// L'écran carte : fond IGN, attribution, et les marqueurs de stations du
/// viewport. N'appelle aucun dépôt — il observe [viewModel] et lui demande
/// des emprises.
class MapView extends StatefulWidget {
  /// [onStationTap] et [stationSheet] restent **optionnels** — la carte de
  /// T0 n'était pas interactive, et ses tests les omettent toujours — mais
  /// ils ne sont pas indépendants : une fiche sans tap ne s'ouvrirait
  /// jamais, un tap sans fiche n'afficherait rien. L'assert fait échouer
  /// tout de suite un câblage à moitié fait, plutôt que de laisser un écran
  /// silencieusement inerte.
  const MapView({
    required this.viewModel,
    this.onStationTap,
    this.stationSheet,
    super.key,
  }) : assert(
         (onStationTap == null) == (stationSheet == null),
         'onStationTap et stationSheet vont ensemble : une fiche sans tap '
         "ne s'ouvre jamais, un tap sans fiche n'affiche rien",
       );

  /// Le ViewModel de la tranche carte, construit dans `main.dart`
  /// (asset → dépôts → ViewModel → vue). La vue ne le **possède pas** :
  /// c'est la racine de composition qui le crée et qui le disposera — cette
  /// vue ne doit pas disposer un objet dont elle n'est pas propriétaire.
  final MapViewModel viewModel;

  /// Appelé avec le code de la station tapée. Injecté par `main.dart`, qui
  /// le branche sur `StationSheetViewModel.open` : la carte ne connaît ni ce
  /// ViewModel ni sa tranche (règle `feature-vers-feature`).
  final void Function(StationCode code)? onStationTap;

  /// Le panneau de la fiche station, déjà composé avec son ViewModel par
  /// `main.dart`, et affiché en bas de la carte. `null` tant qu'aucune fiche
  /// n'est branchée — la carte reste alors ce qu'elle était en T0.
  ///
  /// La fiche ne se ferme que par son propre bouton (et par
  /// `StationSheetViewModel.close`) : un tap sur la carte hors marqueur ne
  /// la ferme pas.
  final Widget? stationSheet;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// Construites une seule fois : `MapOptions ==` (paquet flutter_map
  /// 8.3.2, `options.dart`) compare chaque callback par égalité de
  /// fonction, et les tear-offs de méthodes d'instance ci-dessous restent
  /// égaux d'un accès à l'autre — contrairement à des fermetures inline
  /// recréées à chaque `build`, qui auraient fait remplacer l'état interne
  /// du contrôleur `flutter_map` à chaque frame (NFR-01).
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: const LatLng(
      initialMapCenterLatitude,
      initialMapCenterLongitude,
    ),
    initialZoom: initialMapZoom,
    minZoom: minimumMapZoom,
    maxZoom: maximumMapZoom,
    onMapEvent: _handleMapEvent,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadThenPreload(widget.viewModel.loadInitial()));
  }

  /// Câblé à `MapOptions.onMapEvent` : ne déclenche un chargement que pour
  /// les événements de fin de geste ([shouldRefreshOn]), jamais à chaque
  /// frame d'un glisser en cours.
  void _handleMapEvent(MapEvent event) {
    if (!shouldRefreshOn(event)) {
      return;
    }

    final LatLngBounds visible = event.camera.visibleBounds;
    unawaited(
      _loadThenPreload(
        widget.viewModel.loadFor(
          Bounds(
            west: visible.west,
            south: visible.south,
            east: visible.east,
            north: visible.north,
          ),
        ),
      ),
    );
  }

  /// Enchaîne un chargement de points et le préchargement du débit des
  /// stations visibles.
  ///
  /// C'est bien la **vue** qui déclenche le préchargement : `loadFor` annule
  /// celui qui tourne (une emprise quittée n'a plus de valeur, `NFR-07`,
  /// `C-15`) mais n'en relance aucun de lui-même, pour qu'un écran qui n'en
  /// veut pas n'ait pas à l'annuler (V2). Le branchement était explicitement
  /// laissé à `U2`.
  ///
  /// L'attente est nécessaire : `preloadVisibleStations` choisit les vingt
  /// stations les plus proches du centre de l'emprise **déjà chargée**. La
  /// lancer avant que les points soient là ne précharge rien.
  ///
  /// La relancer à chaque fin de geste ne coûte rien quand rien n'a changé :
  /// le ViewModel **saute les stations dont l'état est déjà connu** et ne
  /// notifie qu'à un changement effectif. Un relâchement de geste sur la
  /// même emprise ne fait donc ni requête ni reconstruction des 4 150
  /// marqueurs (`NFR-01`) ; et la borne de vingt portant sur les requêtes et
  /// non sur les stations regardées, un second geste sur la même emprise
  /// précharge les **vingt suivantes**, de proche en proche.
  Future<void> _loadThenPreload(Future<void> load) async {
    await load;
    await widget.viewModel.preloadVisibleStations();
  }

  @override
  Widget build(BuildContext context) {
    // Tout est DANS le `ListenableBuilder` : la légende doit basculer avec
    // l'échelle à l'instant du geste (`BR-008`, `UC-001 A6`), et le bandeau
    // d'erreur apparaître dès que le ViewModel le pose. Le panneau de fiche,
    // lui, est une instance de widget CONSTANTE d'une reconstruction à
    // l'autre (`widget.stationSheet`) : `Element.updateChild` court-circuite
    // sur un widget identique, le replacer ici ne le reconstruit donc pas —
    // il porte son propre `ListenableBuilder` sur le ViewModel de la fiche.
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              FlutterMap(
                options: _mapOptions,
                children: buildMapLayers(
                  stations: widget.viewModel.stations,
                  onStationTap: widget.onStationTap,
                  stateOf: widget.viewModel.stateOf,
                ),
              ),
              ...buildMapOverlays(
                scale: widget.viewModel.scale,
                error: widget.viewModel.error,
                stationSheet: widget.stationSheet,
              ),
            ],
          );
        },
      ),
    );
  }
}
