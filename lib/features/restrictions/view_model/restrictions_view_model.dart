// Le ViewModel de l'ecran des restrictions (MVVM, ADR-014) : a la
// designation d'un point sur la carte, il interroge `RestrictionSource` et
// porte l'etat que la vue affiche. Meme style que `StationSheetViewModel` —
// jeton de generation contre une reponse tardive, `_disposed` contre une
// notification apres `dispose()`.
//
// ⚠️ Un ViewModel ne connait aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Le verrou est
// `test/architecture/layers_test.dart` (regle `view-model-sans-widget`).
//
// Un etat par reponse de la source (conception T2 § 6, BR-007) : aucune
// reponse n'est rabattue sur un etat par defaut. `ZonesTrouvees` et
// `AucuneZone` sont deux issues POSITIVES distinctes — la seconde n'est pas
// un echec (`200 []`). `RestrictionsEnEchec` porte la cause telle que la
// source l'a levee, sans jamais l'interpreter ici : la vue nomme la source
// depuis `source_names.dart`, jamais depuis `cause.toString()`.
//
// Le profil vit ICI, pour la SESSION (Q2-A) : jamais preselectionne, jamais
// ecrit (aucune dependance de persistance au constructeur), et il survit a
// `close()`/`open()` puisque ce ViewModel est possede par `main.dart` et vit
// aussi longtemps que l'app — jamais au relancement.
//
// L'encart renforce (BR-013) n'est PAS un etat : il est affiche d'emblee et
// dans tous les etats par la vue elle-meme, ce ViewModel n'a rien a en dire.
//
// Les liens (T2, B2) — l'arrete en PDF, l'arrete-cadre et le site public de
// la source — s'ouvrent hors de l'application par le port
// `ExternalLinkOpener`, injecte par `main.dart` : aucune bibliotheque
// d'ouverture n'est importee ici. Un lien qui ne s'ouvre pas n'est pas une
// exception : [UnopenedLink] garde son adresse brute, sa cible et le numero de
// l'echec dans [RestrictionsViewModel.unopenedLink], pour que la vue
// l'affiche (`UC-002 A6`), sans pretendre que le document existe.

import 'package:flutter/foundation.dart'
    show ChangeNotifier, FlutterError, FlutterErrorDetails;
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';

/// Etat de l'ecran des restrictions. `sealed` + `switch` exhaustif
/// (BR-011) : une sous-classe ajoutee sans branche ailleurs devient une
/// erreur de compilation, jamais un oubli silencieux a l'ecran.
sealed class RestrictionsState {
  const RestrictionsState();
}

/// Aucun point n'est designe, ou l'ecran vient d'etre ferme.
final class RestrictionsFermees extends RestrictionsState {
  const RestrictionsFermees();
}

/// Le point [point] est en cours d'interrogation : ni succes, ni echec.
final class RestrictionsEnCours extends RestrictionsState {
  const RestrictionsEnCours(this.point);

  /// Point designe, en cours d'interrogation.
  final GeoPoint point;
}

/// La source a rendu au moins une zone pour le point interroge.
final class ZonesTrouvees extends RestrictionsState {
  const ZonesTrouvees(this.zones);

  /// Toutes les zones du point, telles que rendues par la source — ce
  /// ViewModel ne filtre pas, la vue appelle `AlertZone.usagesFor`.
  final ZonesAtPoint zones;
}

/// La source a repondu, sans aucune zone pour ce point (`200 []`) : une
/// reponse valide, pas un echec (`BR-007`).
final class AucuneZone extends RestrictionsState {
  const AucuneZone({required this.point, required this.retrievedAt});

  /// Point interroge.
  final GeoPoint point;

  /// Instant ou la source a repondu.
  final DateTime retrievedAt;
}

/// L'interrogation du point [point] a echoue, pour [cause] — une des trois
/// branches fermees de `RestrictionLookupFailure`, gardee telle que la
/// source l'a levee.
final class RestrictionsEnEchec extends RestrictionsState {
  const RestrictionsEnEchec({required this.point, required this.cause});

  /// Point dont l'interrogation a echoue.
  final GeoPoint point;

  /// Cause de l'echec, telle que levee par la source appelee.
  final RestrictionLookupFailure cause;
}

/// L'interrogation du point [point] a echoue pour une raison que la source
/// n'a PAS levee (une `Exception`, une `Error` ou tout autre objet leve
/// imprevu) : la vue ne peut pas affirmer que la source est en cause, donc ne
/// la nomme pas (Q-5d de C1, conception T2 § 5.4). Aucun autre champ : le
/// diagnostic n'a pas de porteur ici, une `Error` est remontee a
/// `FlutterError.reportError`.
final class RestrictionsNonObtenues extends RestrictionsState {
  const RestrictionsNonObtenues(this.point);

  /// Point dont l'interrogation n'a pas abouti.
  final GeoPoint point;
}

/// Ce que l'usager a demande d'ouvrir : le site public de la source, un arrete
/// de restriction ou un arrete-cadre. Une adresse brute ne dit pas laquelle
/// des trois : une zone peut citer la meme pour l'arrete et pour le cadre.
enum LinkTarget { publicSite, decree, frameworkDecree }

/// Le dernier lien qui n'a pas pu s'ouvrir (`UC-002 A6`) : son adresse BRUTE,
/// ce que l'usager avait demande d'ouvrir, et le numero de l'echec.
final class UnopenedLink {
  const UnopenedLink({
    required this.raw,
    required this.target,
    required this.failureNumber,
  });

  /// Adresse brute, telle que recue (`BR-014`).
  final String raw;

  /// Ce que l'usager avait demande d'ouvrir.
  final LinkTarget target;

  /// Numero de l'echec, croissant pour la vie du ViewModel.
  final int failureNumber;

  /// Vrai si ce lien est celui de [target] a l'adresse [raw] : la cible ET
  /// l'adresse, car une zone peut citer la meme adresse pour son arrete et
  /// pour son arrete-cadre.
  bool concerns(LinkTarget target, String raw) =>
      this.target == target && this.raw == raw;
}

/// ViewModel de l'ecran des restrictions : porte l'etat de l'ecran, le
/// profil choisi pour la session, et le seul chemin par lequel l'un et
/// l'autre changent.
final class RestrictionsViewModel extends ChangeNotifier {
  RestrictionsViewModel({required this._source, required this._links});

  final RestrictionSource _source;

  final ExternalLinkOpener _links;

  UnopenedLink? _unopenedLink;

  /// Numero du dernier echec d'ouverture ; ne revient jamais a zero.
  int _failureCount = 0;

  /// Le dernier lien qui n'a pas pu s'ouvrir (`UC-002 A6`), ou `null`. Remis
  /// a `null` par la reussite de CE lien (meme cible, meme adresse : celle d'un
  /// autre lien ne le retire pas), par [open] et par [close].
  UnopenedLink? get unopenedLink => _unopenedLink;

  RestrictionsState _state = const RestrictionsFermees();

  /// Etat courant de l'ecran.
  RestrictionsState get state => _state;

  /// Profil choisi pour la session, `null` au depart — jamais
  /// preselectionne (Q2-A). Survit a `close()`/`open()`, jamais ecrit.
  UserProfile? _profile;

  /// Profil choisi pour la session, ou `null` si aucun choix n'a encore ete
  /// fait.
  UserProfile? get profile => _profile;

  /// Leve par [dispose] : une reponse qui arrive apres coup ne doit plus
  /// toucher l'etat ni appeler `notifyListeners`.
  bool _disposed = false;

  /// Numero du dernier chargement demande. Une reponse dont le numero n'est
  /// plus le dernier appartient a un `open()` abandonne — par un `close()`
  /// ou par un `open()` plus recent — et n'ecrit rien (meme garde que
  /// `StationSheetViewModel._generation`).
  int _generation = 0;

  /// Interroge la source pour le point [point] : `RestrictionsEnCours`
  /// d'abord, notifie avant toute reponse, puis l'issue de la source —
  /// `ZonesTrouvees`, `AucuneZone`, `RestrictionsEnEchec` (cause nommee par
  /// la source) ou `RestrictionsNonObtenues` (echec imprevu).
  Future<void> open(GeoPoint point) async {
    final int generation = ++_generation;
    _unopenedLink = null;
    _emit(generation, RestrictionsEnCours(point));

    try {
      final ZonesAtPoint zones = await _source.zonesAt(point);
      if (zones.zones.isEmpty) {
        _emit(
          generation,
          AucuneZone(point: point, retrievedAt: zones.retrievedAt),
        );
        return;
      }
      _emit(generation, ZonesTrouvees(zones));
    } on RestrictionLookupFailure catch (failure) {
      _emit(generation, RestrictionsEnEchec(point: point, cause: failure));
    } on Error catch (error, stackTrace) {
      // Une `Error` signale un bug (assertion, etat incoherent) : meme etat
      // neutre a l'ecran, mais l'erreur est signalee au canal de diagnostic
      // de Flutter, jamais affichee a l'usager.
      _emit(generation, RestrictionsNonObtenues(point));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'restrictions',
        ),
      );
    } on Object {
      // Tout le reste : une `Exception` que la source n'a pas nommee (pas une
      // panne de la source : etat distinct, Q-5d de C1), ou un objet qui
      // n'est ni l'une ni l'autre — Dart permet `throw 'texte'`. Aucun
      // n'echappe : l'ecran ne reste jamais en `RestrictionsEnCours` sans
      // fin. Rien n'est remonte. Cette clause suit `on Error` : l'ordre
      // compte, `Error` est un `Object`.
      _emit(generation, RestrictionsNonObtenues(point));
    }
  }

  /// Choisit [profile] pour la session : notifie, sauf si c'est deja le
  /// profil courant, ou si ce ViewModel est [dispose]d.
  void chooseProfile(UserProfile profile) {
    if (_disposed || _profile == profile) {
      return;
    }
    _profile = profile;
    notifyListeners();
  }

  /// Reinterroge le point d'un echec courant. Sans effet hors de
  /// [RestrictionsEnEchec] et [RestrictionsNonObtenues] — en particulier
  /// apres [close] (l'ecran est ferme, il n'y a plus de point a reinterroger) et depuis
  /// [ZonesTrouvees]/[AucuneZone] (une reponse deja recue ne se reinterroge
  /// pas d'elle-meme).
  Future<void> retry() async {
    final RestrictionsState current = _state;
    final GeoPoint? point = switch (current) {
      RestrictionsEnEchec() => current.point,
      RestrictionsNonObtenues() => current.point,
      RestrictionsFermees() ||
      RestrictionsEnCours() ||
      ZonesTrouvees() ||
      AucuneZone() => null,
    };
    if (point == null) {
      return;
    }
    await open(point);
  }

  /// Ferme l'ecran : toute reponse d'un `open()` en cours devient tardive
  /// et n'ecrira plus rien (le jeton de generation change ici aussi).
  void close() {
    final int generation = ++_generation;
    _unopenedLink = null;
    _emit(generation, const RestrictionsFermees());
  }

  /// Ouvre hors de l'application le PDF [link] : [target] dit s'il s'agit de
  /// l'arrete ([LinkTarget.decree]) ou de l'arrete-cadre
  /// ([LinkTarget.frameworkDecree]) — le site public a sa methode,
  /// [openPublicSite] : [LinkTarget.publicSite] est refuse ici (assertion en
  /// debogage), car aucune carte de l'ecran ne porterait l'avis de son echec.
  /// Sans adresse ouvrable (`DocumentLink.openableUri` nul), l'ouvreur n'est
  /// pas appele et l'adresse brute devient [unopenedLink].
  Future<void> openDocument(DocumentLink link, LinkTarget target) async {
    assert(
      target != LinkTarget.publicSite,
      'Le site public a sa methode : appeler openPublicSite(), pas '
      'openDocument(link, LinkTarget.publicSite).',
    );
    final Uri? uri = link.openableUri;
    if (uri == null) {
      _recordFailure(_generation, link.raw, target);
      return;
    }
    await _openLink(uri, link.raw, target);
  }

  /// Ouvre hors de l'application le site public de la source des
  /// restrictions — dans tous les etats, echec compris (`BR-013`).
  Future<void> openPublicSite() => _openLink(
    Uri.parse(restrictionsPublicSiteUrl),
    restrictionsPublicSiteUrl,
    LinkTarget.publicSite,
  );

  /// Demande l'ouverture de [uri] au port ; [raw] et [target] deviennent
  /// [unopenedLink] si elle n'aboutit pas. Rien ne fuit : une `Exception` est
  /// un echec d'ouverture, tout autre objet leve aussi, et une `Error` de
  /// meme, mais signalee au canal de diagnostic de Flutter (meme regle que
  /// [open], arbitrage du 2026-09-27).
  Future<void> _openLink(Uri uri, String raw, LinkTarget target) async {
    final int generation = _generation;
    bool opened;
    try {
      opened = await _links.open(uri);
    } on Error catch (error, stackTrace) {
      opened = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'restrictions',
        ),
      );
    } on Object {
      // `Exception`, ou tout objet leve qui n'est pas une `Error` : un echec
      // d'ouverture, rien d'autre. Apres `on Error`, dont l'ordre compte.
      opened = false;
    }
    if (opened) {
      _clearUnopenedLink(generation, raw, target);
      return;
    }
    _recordFailure(generation, raw, target);
  }

  /// Retire [unopenedLink] si c'est celui du lien qui vient de s'ouvrir —
  /// [target] a l'adresse [raw] : l'avis d'un AUTRE lien reste (une ouverture
  /// lente qui aboutit apres l'echec d'un autre lien ne le rend pas ouvert,
  /// pas plus que l'autre cible citant la meme adresse). Meme garde de
  /// generation et de `dispose` que [_recordFailure].
  void _clearUnopenedLink(int generation, String raw, LinkTarget target) {
    final UnopenedLink? current = _unopenedLink;
    if (_disposed ||
        generation != _generation ||
        current == null ||
        !current.concerns(target, raw)) {
      return;
    }
    _unopenedLink = null;
    notifyListeners();
  }

  /// Note l'echec d'ouverture de [raw] pour [target] : [unopenedLink] devient
  /// un nouvel etat, numerote, et ce ViewModel notifie A CHAQUE echec — meme
  /// celui du lien deja en echec : la vue y reconnait un nouvel avis, a
  /// amener dans le champ. Rien si [generation] n'est plus la derniere (un
  /// [open] ou un [close] survenu entre-temps a remis l'avis a `null`, une
  /// reponse tardive ne le reecrit pas) ou si ce ViewModel est dispose.
  void _recordFailure(int generation, String raw, LinkTarget target) {
    if (_disposed || generation != _generation) {
      return;
    }
    _unopenedLink = UnopenedLink(
      raw: raw,
      target: target,
      failureNumber: ++_failureCount,
    );
    notifyListeners();
  }

  /// Applique [next] si [generation] est toujours la derniere demandee et
  /// que ce ViewModel n'est pas dispose ; notifie dans ce seul cas.
  void _emit(int generation, RestrictionsState next) {
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
