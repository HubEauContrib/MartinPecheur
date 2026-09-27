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

import 'package:flutter/foundation.dart'
    show ChangeNotifier, FlutterError, FlutterErrorDetails;
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

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

/// ViewModel de l'ecran des restrictions : porte l'etat de l'ecran, le
/// profil choisi pour la session, et le seul chemin par lequel l'un et
/// l'autre changent.
final class RestrictionsViewModel extends ChangeNotifier {
  RestrictionsViewModel({required this._source});

  final RestrictionSource _source;

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
  /// `ZonesTrouvees`, `AucuneZone` ou `RestrictionsEnEchec`.
  Future<void> open(GeoPoint point) async {
    final int generation = ++_generation;
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
    } on Exception catch (error) {
      // Un echec non nomme par la source n'est pas une absence de panne :
      // il est traite comme une source qui n'a pas repondu (meme regle que
      // le `switch` exhaustif de `RestrictionLookupFailure`, dernier
      // recours). Arbitrage du commanditaire du 2026-09-27 : echec neutre a
      // l'ecran, ERREUR remontee — voir la clause `on Error` ci-dessous
      // pour ce qui distingue les deux.
      _emit(
        generation,
        RestrictionsEnEchec(
          point: point,
          cause: SourceInjoignable('${error.runtimeType}: $error'),
        ),
      );
    } on Error catch (error, stackTrace) {
      // Arbitrage du commanditaire du 2026-09-27 : « echec neutre, et
      // erreur remontee ». Une `Error` (par opposition a une `Exception`)
      // signale un bug — assertion, etat incoherent, appel invalide — pas
      // une panne attendue du reseau ou de la source. L'ecran ne doit
      // jamais rester blanc (`BR-007`) : il recoit le MEME etat d'echec
      // neutre qu'une `Exception`. Mais l'erreur ne doit plus disparaitre
      // en silence : elle est signalee au canal de diagnostic de Flutter,
      // pour que le commanditaire la voie, sans jamais l'afficher a
      // l'usager (`cause.diagnostic` reste reserve au journal).
      _emit(
        generation,
        RestrictionsEnEchec(
          point: point,
          cause: SourceInjoignable('${error.runtimeType}: $error'),
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'restrictions',
        ),
      );
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
  /// [RestrictionsEnEchec] — en particulier apres [close] (l'ecran est
  /// ferme, il n'y a plus de point a reinterroger) et depuis
  /// [ZonesTrouvees]/[AucuneZone] (une reponse deja recue ne se reinterroge
  /// pas d'elle-meme).
  Future<void> retry() async {
    final RestrictionsState current = _state;
    if (current is! RestrictionsEnEchec) {
      return;
    }
    await open(current.point);
  }

  /// Ferme l'ecran : toute reponse d'un `open()` en cours devient tardive
  /// et n'ecrira plus rien (le jeton de generation change ici aussi).
  void close() {
    final int generation = ++_generation;
    _emit(generation, const RestrictionsFermees());
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
