// ViewModel de la fiche tronçon (T4, F1 ; cadrage § 8). Aucun appel réseau :
// tout est dans le tronçon et la date de la carte lue (BR-015 : on relaie).
//
// Une fiche ouverte garde le tronçon et la date avec lesquels elle s'est
// ouverte, même si une nouvelle carte arrive (D12).
//
// ⚠️ Aucun widget, aucun fichier de `lib/data/`, aucune autre tranche.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:martinpecheur/domain/sources/source_names.dart';

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

/// Porte l'etat de la fiche troncon et l'ouverture de son bulletin.
final class FloodSheetViewModel extends ChangeNotifier {
  FloodSheetViewModel({required this._links});

  final ExternalLinkOpener _links;

  FloodSheetState _state = const FicheTronconFermee();

  /// Etat courant.
  FloodSheetState get state => _state;

  bool _disposed = false;

  /// Génération de la fiche : incrémentée par chaque [open] et chaque [close]
  /// qui change l'état ; une réponse de lien d'une autre génération est ignorée.
  int _generation = 0;

  /// Ouvre la fiche sur [section], datee de [informationDate].
  void open(FloodSection section, DateTime informationDate) {
    _generation++;
    _state = FicheTronconOuverte(
      section: section,
      informationDate: informationDate,
    );
    notifyListeners();
  }

  /// Ferme la fiche ; sans effet si elle est deja fermee.
  void close() {
    if (_state is FicheTronconFermee) {
      return;
    }
    _generation++;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
