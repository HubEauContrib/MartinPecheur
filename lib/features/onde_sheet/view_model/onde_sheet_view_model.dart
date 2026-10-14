// Le ViewModel de la fiche ONDE (MVVM, ADR-014) : au tap d'un point
// d'écoulement, il charge l'historique des dernières campagnes et porte
// l'état que la vue affiche. Même style que `StationSheetViewModel` — jeton
// de génération contre une réponse tardive, `_disposed` contre une
// notification après `dispose()`.
//
// Il sait aussi si le point est en favori (`S6` de T3) : [FavoriteStar], lue à
// chaque ouverture, basculée par `toggleFavorite`.
//
// ⚠️ Un ViewModel ne connaît aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Il n'importe pas non plus
// `lib/data/` : il dépend de l'INTERFACE [OndeObservationRepository],
// déclarée dans le domaine. Le verrou est
// `test/architecture/layers_test.dart` (règles `view-model-sans-widget` et
// `features-vers-data`).
//
// Deux invariants de produit gouvernent ce fichier :
//
// 1. **La modalité officielle exacte reste visible** (`ADR-006`,
//    `UC-004 § 3`). Le regroupement en quatre catégories d'affichage sert la
//    lisibilité de la carte ; il ne se substitue jamais à la source. C'est
//    [OndeSheetData.officialModalityText] qui la porte — « code 3 — Assec » —
//    tandis que la catégorie AFFICHÉE reste `flowCategoryLabel`, qui dit
//    « À sec » : `docs/glossary.md` proscrit le mot « assec » côté interface,
//    sauf précisément quand on cite la source.
// 2. **L'âge de la campagne figure dans tous les cas** (`BR-010`), ainsi que
//    le rappel du rythme réel des campagnes ([OndeSheetData.seasonNotice]) —
//    y compris hors saison, et y compris quand aucune campagne n'est connue.
//
// Aucun formatage de nombre ni de date ici : la vue formate. Les seules
// chaînes construites sont celles que la spec demande, et elles ne
// contiennent ni valeur numérique mise en forme, ni verbe d'instruction sur
// un usage de l'eau (`BR-014`).

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/onde/campaign_age.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

/// Rappel permanent du rythme réel des campagnes ONDE, mot pour mot comme
/// `BR-010` et `UC-004 § 5` le fixent. Affiché dans TOUS les cas : c'est ce
/// qui empêche de lire un « eau qui coule » de septembre comme un fait de
/// février.
const String ondeSeasonNotice =
    'Campagnes de mai à septembre seulement, environ une par mois. Entre '
    "deux campagnes, personne n'observe ce point.";

/// Texte de [OndeSheetData.officialModalityText] quand aucune campagne n'est
/// connue pour le point (`UC-004 A4`). Jamais une chaîne vide : l'absence est
/// un état affiché, pas un blanc (`BR-007`).
const String _noCampaignText = 'Aucune campagne connue pour ce point.';

/// Texte de repli quand la campagne existe mais ne porte ni code ni libellé
/// de modalité (`BR-007`, `BR-011`).
const String _noModalityText = 'Modalité officielle non renseignée';

/// Repli du libellé officiel, quand seul le code est transmis.
const String _noOfficialLabelText = 'libellé non renseigné';

/// Repli du code officiel, quand seul le libellé est transmis.
const String _noFlowCodeText = 'code non renseigné';

/// État de l'écran fiche ONDE. `sealed` + `switch` exhaustif (`BR-011`) :
/// une sous-classe ajoutée sans branche ailleurs devient une erreur de
/// compilation, jamais un oubli silencieux à l'écran.
///
/// ⚠️ Les quatre états sont préfixés `OndeSheet` là où `StationSheetState`
/// nomme les siens `Fermee`/`EnCours`/`Prete`/`EnEchec` : c'est un écart
/// délibéré au plan, motivé sous `V3` (« Écart constaté »). `EnEchec` existe
/// déjà deux fois dans le projet — fiche station et `StationMapState` — et un
/// troisième jeu homonyme rendrait inutilisable tout fichier important deux
/// tranches sans `hide`.
sealed class OndeSheetState {
  const OndeSheetState();
}

/// Aucun point n'est demandé, ou la fiche vient d'être fermée.
final class OndeSheetFermee extends OndeSheetState {
  const OndeSheetFermee();
}

/// Le point [point] est en cours de chargement : ni succès, ni échec. Le
/// point est porté dès ici pour que la vue nomme le lieu pendant l'attente.
final class OndeSheetEnCours extends OndeSheetState {
  const OndeSheetEnCours(this.point);

  /// Point ONDE demandé.
  final OndePoint point;
}

/// L'historique du point a été lu avec succès — y compris quand il est vide
/// (`UC-004 A4`) : une absence de campagne est un succès de lecture, pas un
/// échec.
final class OndeSheetPrete extends OndeSheetState {
  const OndeSheetPrete(this.data);

  /// Données prêtes pour l'affichage.
  final OndeSheetData data;
}

/// Le chargement de [point] a échoué, pour [cause] (`UC-001 A4`). Le point
/// est conservé pour que la vue nomme le lieu ET la source défaillante depuis
/// son PROPRE libellé — jamais depuis `cause.toString()`, qui reste une
/// donnée de diagnostic technique, pas un texte à afficher.
final class OndeSheetEnEchec extends OndeSheetState {
  const OndeSheetEnEchec(this.point, this.cause);

  /// Point ONDE dont le chargement a échoué.
  final OndePoint point;

  /// Cause de l'échec, telle que levée par le dépôt appelé.
  final Object cause;
}

/// Données prêtes pour la fiche ONDE. Types du domaine uniquement — aucune
/// valeur brute d'API, aucun nombre pré-formaté (`BR-002`).
final class OndeSheetData {
  const OndeSheetData({
    required this.point,
    required this.latest,
    required this.history,
    required this.age,
    required this.ageInDays,
    required this.officialModalityText,
    required this.seasonNotice,
  });

  /// Point ONDE affiché, tel que la carte l'a passé à
  /// [OndeSheetViewModel.open] (D8) : il reste disponible même quand aucune
  /// campagne n'existe, ce qui permet d'afficher la fiche sans jamais retirer
  /// le point de la carte (`UC-004 A4`).
  final OndePoint point;

  /// Dernière campagne connue, ou `null` si le point n'en a aucune.
  ///
  /// ⚠️ Écart au plan `V3`, qui déclarait ce champ non nullable, tandis que
  /// `D8` exige de tenir l'état « aucune campagne » : plutôt que de
  /// fabriquer une observation `NonObserve` qu'aucune campagne n'a produite
  /// — une valeur inventée, ce que `BR-007` interdit — l'absence est dite
  /// par un `null`, et la vue l'affiche. Motif consigné sous `V3` du plan.
  final OndeObservation? latest;

  /// Les dernières campagnes connues, le plus récent en tête — l'ordre du
  /// dépôt, jamais retrié ici. Liste non modifiable : le contrat de
  /// [OndeObservationRepository] interdit d'altérer la liste rendue.
  /// [latest] en est le premier élément, ou `null` si elle est vide.
  final List<OndeObservation> history;

  /// Âge de la dernière campagne (`BR-010`). `null` seulement quand [latest]
  /// est `null` : sans campagne, il n'y a rien à dater — jamais un âge
  /// inventé (`BR-007`).
  final CampaignAge? age;

  /// Âge de la dernière campagne en jours calendaires (`BR-010`, `T-08`).
  /// `null` dans le seul cas où [latest] l'est aussi.
  final int? ageInDays;

  /// Modalité officielle exacte de la dernière campagne, telle que l'API l'a
  /// rendue — « code 3 — Assec » (`ADR-006`, `UC-004 § 3`). Le regroupement
  /// en quatre catégories ne s'y substitue jamais. Jamais une chaîne vide :
  /// une absence de campagne, de code ou de libellé y est dite en toutes
  /// lettres (`BR-007`).
  final String officialModalityText;

  /// Rappel du rythme réel des campagnes, présent dans tous les cas
  /// (`BR-010`, `UC-004 § 5`) : voir [ondeSeasonNotice].
  final String seasonNotice;
}

/// ViewModel de la fiche ONDE : porte l'état de l'écran et le seul chemin par
/// lequel il est chargé.
final class OndeSheetViewModel extends ChangeNotifier {
  OndeSheetViewModel({
    required this._onde,
    required this._favorites,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OndeObservationRepository _onde;
  final FavoriteRepository _favorites;
  final DateTime Function() _now;

  OndeSheetState _state = const OndeSheetFermee();

  /// État courant de la fiche.
  OndeSheetState get state => _state;

  /// Levé par [dispose] : une réponse qui arrive après coup ne doit plus
  /// toucher l'état ni appeler `notifyListeners`.
  bool _disposed = false;

  /// Numéro du dernier chargement demandé. Une réponse dont le numéro n'est
  /// plus le dernier appartient à un `open()` abandonné — par un `close()` ou
  /// par un `open()` plus récent — et n'écrit rien (même garde que
  /// `StationSheetViewModel` et `MapViewModel`).
  int _generation = 0;

  /// Le point de l'`open()` courant, tel que reçu : c'est lui, ENTIER, que
  /// [toggleFavorite] copie dans le favori. `null` fiche fermée.
  OndePoint? _point;

  /// Vrai dès que la lecture des favoris de l'`open()` courant a abouti —
  /// en liste ou en échec. Tant qu'il est faux, aucune étoile n'est due.
  bool _favoritesRead = false;

  /// La lecture des favoris de l'`open()` courant a levé : rien n'est su du
  /// point, et rien ne s'écrit par-dessus une liste illisible.
  bool _favoritesUnreadable = false;

  /// Le favori du point ouvert, tel que lu — ou tel qu'ajouté par
  /// [toggleFavorite] ; `null` : il n'est pas en favori.
  OndePointFavorite? _favorite;

  /// Une écriture (ajout ou retrait) court pour l'`open()` courant.
  bool _writing = false;

  /// La dernière écriture de l'`open()` courant a échoué.
  bool _writeFailed = false;

  /// L'étoile de favori à dessiner, ou `null` s'il n'y en a aucune : fiche
  /// fermée, ou favoris pas encore lus. Le point est connu dans les trois
  /// états visibles, donc l'étoile y est présente dans tous : vide ou pleine,
  /// active sauf pendant une écriture et quand la liste stockée est illisible.
  FavoriteStar? get favoriteStar {
    switch (_state) {
      case OndeSheetFermee():
        return null;
      case OndeSheetEnCours() || OndeSheetPrete() || OndeSheetEnEchec():
        break;
    }
    if (!_favoritesRead) {
      return null;
    }
    if (_favoritesUnreadable) {
      return const FavoriteStar(filled: false, enabled: false);
    }
    return FavoriteStar(
      filled: _favorite != null,
      enabled: !_writing,
      writeFailed: _writeFailed,
    );
  }

  /// Charge la fiche du point [point] : l'historique de ses dernières
  /// campagnes, par son code ONDE.
  ///
  /// [point] et non un simple code (`D8`) : la carte le porte déjà, et c'est
  /// ce qui permet d'afficher la fiche d'un point SANS campagne — le lieu se
  /// nomme depuis le point, pas depuis une observation qui n'existe pas
  /// (`UC-004 A4`).
  ///
  /// Un historique vide est un succès : l'état devient [OndeSheetPrete] avec
  /// [OndeSheetData.latest] à `null`. Seule une levée du dépôt fait basculer
  /// en [OndeSheetEnEchec].
  ///
  /// Les favoris sont relus EN MÊME TEMPS, à chaque appel (le dépôt n'a pas de
  /// mémo) : l'état de la fiche ne les attend pas, mais le futur rendu ne se
  /// complète qu'après les deux.
  Future<void> open(OndePoint point) async {
    final int generation = ++_generation;
    _point = point;
    _resetFavorite();
    _emit(generation, OndeSheetEnCours(point));

    final Future<void> favoritesRead = _readFavorite(generation, point);
    await _load(generation, point);
    await favoritesRead;
  }

  Future<void> _load(int generation, OndePoint point) async {
    try {
      // `Future.sync` enveloppe un appel qui lèverait de façon SYNCHRONE :
      // `CachedOndeObservationRepository.historyFor` n'est pas `async` et
      // peut lever avant tout `await`, ce qui ferait remonter l'exception à
      // l'appelant de `open` au lieu de produire un état [OndeSheetEnEchec].
      final List<OndeObservation> history =
          await Future<List<OndeObservation>>.sync(
            // `limit: 5` explicite : les « 5 dernières campagnes » de la
            // fiche (UC-004 § 4) ne dépendent plus du défaut de l'interface
            // `OndeObservationRepository.historyFor`, qui pourrait changer
            // sans toucher ce fichier.
            () => _onde.historyFor(point.code, limit: 5),
          );

      final OndeObservation? latest = history.isEmpty ? null : history.first;
      // `campaignAgeOf` compare des dates CALENDAIRES et exige que ses deux
      // instants soient dans le même fuseau : `observedAt` est rendu en UTC
      // par le mapper (T-08), `now` y est donc ramené ici. Sans ce
      // `toUtc()`, l'horloge par défaut (`DateTime.now`, locale) ferait
      // varier l'âge d'un jour selon l'heure de la journée.
      final DateTime now = _now().toUtc();

      _emit(
        generation,
        OndeSheetPrete(
          OndeSheetData(
            point: point,
            latest: latest,
            history: List<OndeObservation>.unmodifiable(history),
            age: latest == null
                ? null
                : campaignAgeOf(observedAt: latest.observedAt, now: now),
            ageInDays: latest == null
                ? null
                : campaignAgeInDays(observedAt: latest.observedAt, now: now),
            officialModalityText: _officialModalityText(latest),
            seasonNotice: ondeSeasonNotice,
          ),
        ),
      );
    } on Object catch (error) {
      _emit(generation, OndeSheetEnEchec(point, error));
    }
  }

  /// Lit les favoris pour l'`open()` de numéro [generation]. Toute levée —
  /// les deux branches de `FavoriteStorageFailure` comme une autre — vaut
  /// « liste illisible ». Ne lève jamais.
  Future<void> _readFavorite(int generation, OndePoint point) async {
    OndePointFavorite? favorite;
    bool unreadable = false;
    try {
      favorite = ondePointFavoriteIn(await _favorites.readAll(), point.code);
    } on Object {
      unreadable = true;
    }
    _changeStar(generation, () {
      _favoritesRead = true;
      _favoritesUnreadable = unreadable;
      _favorite = favorite;
    });
  }

  /// Ajoute le point aux favoris, ou l'en retire. Sans effet — et sans appel
  /// au dépôt — quand aucune étoile n'est due, qu'elle est inactive
  /// ([favoriteStar]) ou que ce ViewModel est disposé. L'échec ne se lève pas :
  /// il se lit dans `favoriteStar.writeFailed`, l'étoile gardant sa forme
  /// d'avant.
  Future<void> toggleFavorite() async {
    if (_disposed) {
      return;
    }
    final FavoriteStar? star = favoriteStar;
    final OndePoint? point = _point;
    if (star == null || !star.enabled || point == null) {
      return;
    }
    final OndePointFavorite? current = _favorite;
    final int generation = _generation;
    _changeStar(generation, () {
      _writing = true;
      _writeFailed = false;
    });

    OndePointFavorite? next;
    try {
      if (current != null) {
        await _favorites.remove(current);
      } else {
        // Le point TEL QUE REÇU, entier : la fiche s'ouvre avec lui depuis la
        // liste, sans référentiel ONDE embarqué.
        final OndePointFavorite added = OndePointFavorite(
          point: point,
          addedAt: _now().toUtc(),
        );
        await _favorites.add(added);
        next = added;
      }
    } on Object {
      _changeStar(generation, () {
        _writing = false;
        _writeFailed = true;
      });
      return;
    }
    _changeStar(generation, () {
      _writing = false;
      _favorite = next;
    });
  }

  /// Ferme la fiche : toute réponse d'un `open()` en cours devient tardive et
  /// n'écrira plus rien (le jeton de génération change ici aussi).
  void close() {
    final int generation = ++_generation;
    _point = null;
    _resetFavorite();
    _emit(generation, const OndeSheetFermee());
  }

  /// Oublie ce qui était su du favori : un `open()` relit, un `close()` n'a
  /// plus d'étoile. Ne notifie pas — l'appelant émet l'état juste après.
  void _resetFavorite() {
    _favoritesRead = false;
    _favoritesUnreadable = false;
    _favorite = null;
    _writing = false;
    _writeFailed = false;
  }

  /// Applique [change] à ce qui est su du favori si [generation] est toujours
  /// la dernière demandée et que ce ViewModel n'est pas disposé (même garde que
  /// [_emit]) ; ne notifie que si [favoriteStar] en sort changée.
  void _changeStar(int generation, void Function() change) {
    if (_disposed || generation != _generation) {
      return;
    }
    final FavoriteStar? before = favoriteStar;
    change();
    if (favoriteStar != before) {
      notifyListeners();
    }
  }

  /// Applique [next] si [generation] est toujours la dernière demandée et que
  /// ce ViewModel n'est pas disposé ; notifie dans ce seul cas.
  void _emit(int generation, OndeSheetState next) {
    if (_disposed || generation != _generation) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// La modalité officielle exacte de [latest], au format « code 3 — Assec »
/// (`ADR-006`, `UC-004 § 3`) : le code brut tel que reçu, jamais normalisé,
/// et le libellé officiel tel que l'API l'écrit — « Assec » y est cité comme
/// SOURCE, ce que `docs/glossary.md` distingue du libellé d'interface
/// (« À sec », rendu par `flowCategoryLabel`).
///
/// Ne rend jamais une chaîne vide ni un `null` mis en forme (`BR-007`) :
/// chaque absence — de campagne, de code, de libellé — a son texte.
String _officialModalityText(OndeObservation? latest) {
  if (latest == null) {
    return _noCampaignText;
  }

  final String? rawFlowCode = latest.rawFlowCode;
  final String? officialLabel = latest.officialLabel;
  if (rawFlowCode == null && officialLabel == null) {
    return _noModalityText;
  }

  final String code = rawFlowCode == null
      ? _noFlowCodeText
      : 'code $rawFlowCode';
  return '$code — ${officialLabel ?? _noOfficialLabelText}';
}
