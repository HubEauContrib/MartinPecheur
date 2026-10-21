// ViewModel de la fiche tronçon (T4, F1 ; cadrage § 8). Aucun appel réseau :
// tout est dans le tronçon et la date de la carte lue (BR-015 : on relaie).
//
// Une fiche ouverte garde le tronçon et la date avec lesquels elle s'est
// ouverte, même si une nouvelle carte arrive (D12).
//
// T5 (V1) y ajoute ce que la fiche sait du LIEU : l'étoile de favori
// ([FavoriteStar], sur le modèle de la fiche station) et le choix du seuil
// « Me prévenir » ([FloodFollowUpChoice]). Ils vivent HORS de [state] : lire
// ou écrire l'étoile ou le suivi notifie, mais ne remplace jamais [state] — la
// racine ne doit pas y lire une nouvelle ouverture. Le seuil est un niveau
// PUBLIÉ choisi par l'usager (BR-016) : rien n'est calculé ici.
//
// ⚠️ Aucun widget, aucun fichier de `lib/data/`, aucune autre tranche.

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/favorites/favorite.dart';
import 'package:martinpecheur/domain/favorites/favorite_repository.dart';
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/follow_up_repository.dart';
import 'package:martinpecheur/domain/follow_up/followed_place.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';

/// Etat de la fiche troncon.
sealed class FloodSheetState {
  const FloodSheetState();
}

/// Aucune fiche troncon.
final class FicheTronconFermee extends FloodSheetState {
  const FicheTronconFermee();
}

/// Fiche ouverte sur [section], datee de [informationDate].
final class FicheTronconOuverte extends FloodSheetState {
  const FicheTronconOuverte({
    required this.section,
    required this.informationDate,
    this.unopenedBulletinCount = 0,
  });

  /// Troncon tel que la carte le portait a l'ouverture.
  final FloodSection section;

  /// Date de la carte de vigilance lue a l'ouverture.
  final DateTime informationDate;

  /// Nombre d'echecs d'ouverture du bulletin ; l'avis est recree a chaque
  /// echec pour se reannoncer.
  final int unopenedBulletinCount;

  /// Adresse du bulletin du territoire du troncon.
  Uri get bulletinUri => floodBulletinUri(section.territoryCode);
}

/// Fiche ouverte sur un favori troncon que la carte de vigilance lue ne porte
/// pas (T5, V1) : le code et le nom copiés à l'ajout, la date de la carte.
final class FicheTronconAbsente extends FloodSheetState {
  const FicheTronconAbsente({
    required this.code,
    required this.name,
    required this.informationDate,
  });

  /// Code publié du tronçon, tel que le favori le garde.
  final FloodSectionCode code;

  /// Nom publié du tronçon, copié à l'ajout du favori.
  final String name;

  /// Date de la carte de vigilance lue, où le tronçon ne figure pas.
  final DateTime informationDate;
}

/// Le réglage « Me prévenir » d'un tronçon en favori, tel que la fiche
/// l'affiche : le seuil choisi (`null` : « Non »), s'il répond, et si la
/// dernière écriture a échoué.
final class FloodFollowUpChoice {
  const FloodFollowUpChoice({
    required this.selected,
    required this.enabled,
    this.writeFailed = false,
  });

  /// Le seuil choisi ; `null` veut dire « Non ».
  final FloodThreshold? selected;

  /// Le réglage répond au toucher et au clavier ; sinon il garde sa forme,
  /// atténuée (écriture en cours, suivi illisible).
  final bool enabled;

  /// La dernière écriture du réglage a échoué.
  final bool writeFailed;

  @override
  bool operator ==(Object other) =>
      other is FloodFollowUpChoice &&
      other.selected == selected &&
      other.enabled == enabled &&
      other.writeFailed == writeFailed;

  @override
  int get hashCode => Object.hash(selected, enabled, writeFailed);

  @override
  String toString() =>
      'FloodFollowUpChoice(selected: $selected, enabled: $enabled, '
      'writeFailed: $writeFailed)';
}

/// Porte l'etat de la fiche troncon, l'ouverture de son bulletin, son etoile
/// de favori et son reglage « Me prevenir ».
final class FloodSheetViewModel extends ChangeNotifier {
  FloodSheetViewModel({
    required this._links,
    required this._favorites,
    required this._followUps,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ExternalLinkOpener _links;
  final FavoriteRepository _favorites;
  final FollowUpRepository _followUps;
  final DateTime Function() _now;

  FloodSheetState _state = const FicheTronconFermee();

  /// Etat courant.
  FloodSheetState get state => _state;

  bool _disposed = false;

  /// Génération de la fiche : incrémentée par chaque [open], [openAbsent] et
  /// chaque [close] qui change l'état ; une réponse de lien, de lecture ou
  /// d'écriture d'une autre génération est ignorée.
  int _generation = 0;

  /// Vrai dès que les deux lectures (favoris, suivi) de l'ouverture courante
  /// ont abouti — en valeur ou en échec. Tant qu'il est faux, ni étoile ni
  /// réglage ne sont dus.
  bool _placeRead = false;

  /// La liste des favoris n'a pas pu être lue : rien n'est su du lieu, et
  /// rien ne s'écrit par-dessus.
  bool _favoritesUnreadable = false;

  /// Le suivi n'a pas pu être lu : le réglage est inactif.
  bool _followUpUnreadable = false;

  /// Le favori du tronçon ouvert, tel que lu ou tel qu'ajouté ; `null` : il
  /// n'est pas en favori.
  FloodSectionFavorite? _favorite;

  /// Le seuil stocké pour le tronçon ouvert ; `null` : « Non ».
  FloodThreshold? _selected;

  /// Une écriture du favori (ajout ou retrait) court.
  bool _writing = false;

  /// La dernière écriture du favori a échoué.
  bool _starWriteFailed = false;

  /// Une écriture du seuil court.
  bool _followWriting = false;

  /// La dernière écriture du seuil a échoué.
  bool _followWriteFailed = false;

  /// Le code et le nom du tronçon ouvert, ou `null` si la fiche est fermée.
  ({FloodSectionCode code, String name})? get _place => switch (_state) {
    FicheTronconFermee() => null,
    FicheTronconOuverte(:final section) => (
      code: section.code,
      name: section.name,
    ),
    FicheTronconAbsente(:final code, :final name) => (code: code, name: name),
  };

  /// L'étoile de favori à dessiner, ou `null` : fiche fermée ou lectures pas
  /// encore faites. Présente dans les deux états ouverts : l'ajout n'exige que
  /// le code et le nom, que les deux états portent.
  FavoriteStar? get favoriteStar {
    if (_place == null || !_placeRead) {
      return null;
    }
    if (_favoritesUnreadable) {
      return const FavoriteStar(filled: false, enabled: false);
    }
    return FavoriteStar(
      filled: _favorite != null,
      enabled: !_writing && !_followWriting,
      writeFailed: _starWriteFailed,
    );
  }

  /// Le réglage « Me prévenir », ou `null` si le tronçon n'est pas en favori
  /// ou si le suivi n'est pas encore lu. Suivi illisible : inactif, sur
  /// « Non ».
  FloodFollowUpChoice? get followUpChoice {
    if (_place == null || !_placeRead || _favorite == null) {
      return null;
    }
    if (_followUpUnreadable) {
      return FloodFollowUpChoice(
        selected: null,
        enabled: false,
        writeFailed: _followWriteFailed,
      );
    }
    return FloodFollowUpChoice(
      selected: _selected,
      enabled: !_writing && !_followWriting,
      writeFailed: _followWriteFailed,
    );
  }

  /// Ouvre la fiche sur [section], datee de [informationDate], et lance la
  /// lecture des favoris et du suivi.
  void open(FloodSection section, DateTime informationDate) {
    final int generation = ++_generation;
    _resetPlace();
    _state = FicheTronconOuverte(
      section: section,
      informationDate: informationDate,
    );
    notifyListeners();
    unawaited(_readPlace(generation, section.code));
  }

  /// Ouvre la fiche sur [favorite], un favori que la carte lue ne porte pas,
  /// datee de [informationDate], et lance la lecture des favoris et du suivi.
  void openAbsent(FloodSectionFavorite favorite, DateTime informationDate) {
    final int generation = ++_generation;
    _resetPlace();
    _state = FicheTronconAbsente(
      code: favorite.code,
      name: favorite.name,
      informationDate: informationDate,
    );
    notifyListeners();
    unawaited(_readPlace(generation, favorite.code));
  }

  /// Ferme la fiche ; sans effet si elle est deja fermee.
  void close() {
    if (_state is FicheTronconFermee) {
      return;
    }
    _generation++;
    _resetPlace();
    _state = const FicheTronconFermee();
    notifyListeners();
  }

  /// Ouvre le bulletin hors de l'application. Un echec se compte ; une
  /// reponse arrivee apres [close] ou apres l'ouverture d'un autre troncon
  /// n'ecrit rien.
  Future<void> openBulletin() async {
    final FloodSheetState before = _state;
    if (before is! FicheTronconOuverte) {
      return;
    }
    final int generation = _generation;
    final bool opened = await _links.open(before.bulletinUri);
    if (opened || _disposed) {
      return;
    }
    final FloodSheetState now = _state;
    if (generation != _generation || now is! FicheTronconOuverte) {
      return;
    }
    _state = FicheTronconOuverte(
      section: now.section,
      informationDate: now.informationDate,
      unopenedBulletinCount: now.unopenedBulletinCount + 1,
    );
    notifyListeners();
  }

  /// Ajoute le tronçon aux favoris, ou l'en retire. Sans effet quand aucune
  /// étoile n'est due, qu'elle est inactive ou que ce ViewModel est disposé.
  ///
  /// L'ajout éteint ensuite le suivi du tronçon, et le retrait aussi : un
  /// suivi resté d'un ancien favori ne revient jamais (PD20) quand cette
  /// extinction réussit. À l'AJOUT, son échec se dit : le favori est ajouté, le
  /// réglage garde le seuil réellement stocké et porte `writeFailed`, qui
  /// retombe au prochain choix réussi. Au RETRAIT, son échec est ignoré — le
  /// suivi orphelin tombe à la vérification suivante. L'échec d'écriture du
  /// favori se lit dans `favoriteStar.writeFailed`.
  Future<void> toggleFavorite() async {
    if (_disposed) {
      return;
    }
    final FavoriteStar? star = favoriteStar;
    final ({FloodSectionCode code, String name})? place = _place;
    if (star == null || !star.enabled || place == null) {
      return;
    }
    final FloodSectionFavorite? current = _favorite;
    final int generation = _generation;
    _change(generation, () {
      _writing = true;
      _starWriteFailed = false;
    });

    FloodSectionFavorite? next;
    try {
      if (current != null) {
        await _favorites.remove(current);
      } else {
        // Construit DANS le `try` : un nom blanc lève, et l'ajout qui ne peut
        // pas se faire est un ajout en échec.
        final FloodSectionFavorite added = FloodSectionFavorite(
          code: place.code,
          name: place.name,
          addedAt: _now().toUtc(),
        );
        await _favorites.add(added);
        next = added;
      }
    } on Object {
      _change(generation, () {
        _writing = false;
        _starWriteFailed = true;
      });
      return;
    }

    bool unfollowed = true;
    try {
      await _followUps.unfollow(FloodSectionPlace(place.code));
    } on Object {
      unfollowed = false;
    }
    _change(generation, () {
      _writing = false;
      _favorite = next;
      if (unfollowed) {
        _selected = null;
      } else if (next != null) {
        // Une écriture en échec se dit toujours : à l'ajout, le réglage porte
        // `writeFailed` et garde le seuil réellement stocké.
        _followWriteFailed = true;
      }
    });
  }

  /// Choisit le seuil « Me prévenir » : `null` éteint le suivi, un seuil
  /// l'écrit. Sans effet si le réglage n'est pas dû, pas actif, ou déjà sur le
  /// choix demandé. L'échec se lit dans `followUpChoice.writeFailed`.
  Future<void> chooseThreshold(FloodThreshold? threshold) async {
    if (_disposed) {
      return;
    }
    final FloodFollowUpChoice? choice = followUpChoice;
    final ({FloodSectionCode code, String name})? place = _place;
    if (choice == null ||
        !choice.enabled ||
        place == null ||
        threshold == choice.selected) {
      return;
    }
    final int generation = _generation;
    _change(generation, () {
      _followWriting = true;
      _followWriteFailed = false;
    });
    final FloodSectionPlace followed = FloodSectionPlace(place.code);
    try {
      if (threshold == null) {
        await _followUps.unfollow(followed);
      } else {
        await _followUps.followFlood(followed, threshold);
      }
    } on Object catch (error) {
      _change(generation, () {
        _followWriting = false;
        _followWriteFailed = true;
        if (error is SuiviIllisible) {
          _followUpUnreadable = true;
        }
      });
      return;
    }
    _change(generation, () {
      _followWriting = false;
      _selected = threshold;
    });
  }

  /// Lit les favoris et le suivi pour l'ouverture de numéro [generation].
  /// Toute levée vaut « illisible ». Ne lève jamais. Les deux lectures sont
  /// publiées ENSEMBLE : l'étoile ne répond qu'une fois le suivi connu.
  Future<void> _readPlace(int generation, FloodSectionCode code) async {
    FloodSectionFavorite? favorite;
    bool favoritesUnreadable = false;
    FloodThreshold? selected;
    bool followUpUnreadable = false;

    Future<void> readFavorites() async {
      try {
        favorite = floodSectionFavoriteIn(await _favorites.readAll(), code);
      } on Object {
        favoritesUnreadable = true;
      }
    }

    Future<void> readFollowUp() async {
      try {
        final FollowUpBook book = await _followUps.read();
        final FollowUp? followUp = followUpOf(
          book.followUps,
          FloodSectionPlace(code),
        );
        selected = followUp is FloodFollowUp ? followUp.threshold : null;
      } on Object {
        followUpUnreadable = true;
      }
    }

    await Future.wait<void>(<Future<void>>[readFavorites(), readFollowUp()]);
    _change(generation, () {
      _placeRead = true;
      _favoritesUnreadable = favoritesUnreadable;
      _followUpUnreadable = followUpUnreadable;
      _favorite = favorite;
      _selected = selected;
    });
  }

  /// Oublie ce qui était su du lieu : une ouverture relit, une fermeture n'a
  /// plus d'étoile. Ne notifie pas — l'appelant émet l'état juste après.
  void _resetPlace() {
    _placeRead = false;
    _favoritesUnreadable = false;
    _followUpUnreadable = false;
    _favorite = null;
    _selected = null;
    _writing = false;
    _starWriteFailed = false;
    _followWriting = false;
    _followWriteFailed = false;
  }

  /// Applique [change] à ce qui est su du lieu si [generation] est toujours la
  /// dernière demandée et que ce ViewModel n'est pas disposé ; ne notifie que
  /// si l'étoile ou le réglage en sortent changés. Ne touche jamais [_state].
  void _change(int generation, void Function() change) {
    if (_disposed || generation != _generation) {
      return;
    }
    final FavoriteStar? starBefore = favoriteStar;
    final FloodFollowUpChoice? choiceBefore = followUpChoice;
    change();
    if (favoriteStar != starBefore || followUpChoice != choiceBefore) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
