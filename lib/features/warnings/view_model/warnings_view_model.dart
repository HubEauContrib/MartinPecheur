// Le ViewModel de l'acquittement de l'avertissement initial (MVVM,
// ADR-014) : porte l'etat de l'ecran bloquant du premier lancement
// (`BR-012`, `UC-006`) et le seul chemin par lequel il change.
//
// ⚠️ Un ViewModel ne connait aucun widget : ce fichier n'importe que
// `foundation.dart`, pour [ChangeNotifier]. Il ne connait pas non plus
// `lib/data/` : sa seule dependance est l'INTERFACE [AcknowledgementRepository],
// declaree dans le domaine — l'implementation concrete, posee en `W1`
// (`SharedPreferencesAcknowledgementRepository`), est injectee par
// `main.dart` seul. Le verrou est
// `test/architecture/layers_test.dart` (regles `view-model-sans-widget` et
// `features-vers-data`).
//
// Ce fichier ne produit AUCUNE chaine destinee a l'ecran : ni libelle de
// bouton, ni corps de texte, ni message d'erreur mis en forme (le seul
// litteral est le message d'ArgumentError du constructeur, adresse au
// developpeur, jamais affiche). Le texte de l'avertissement (`BR-012`,
// `BR-014`) vit dans `lib/domain/warnings/warning_texts.dart` (tache `W2`
// du plan) — un balayage des mots bannis (`BR-003`) ou des verbes
// d'instruction (`BR-014`) n'aurait donc rien a balayer ici.
//
// C'est la VERSION du texte qui est persistee, jamais un booleen (`BR-012`) :
// un booleen ne distinguerait jamais « acquitte une fois » de « acquitte
// CETTE version », et ne permettrait donc jamais de faire relire un texte
// modifie (`UC-006 A3`). Un echec de LECTURE du stockage rebloque au lieu
// d'ouvrir — en cas de doute, l'usager relit les limites ; un echec
// d'ECRITURE, lui, laisse l'ecran bloque et EXPOSE l'echec par [error],
// jamais avale en silence (memes principes que `MapViewModel.error`).

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/repositories/repositories.dart';

/// Etat de l'ecran d'acquittement de l'avertissement initial (`BR-012`).
final class WarningsViewModel extends ChangeNotifier {
  /// [currentWarningVersion] est la version du texte d'avertissement
  /// actuellement en vigueur dans l'application (`warningTextVersion`,
  /// tache `W2`) : elle ne peut pas etre vide, sinon elle ne pourrait ni
  /// etre comparee a une version stockee, ni etre ecrite comme acquittement
  /// valide.
  WarningsViewModel({
    required this._acknowledgements,
    required String currentWarningVersion,
  }) : _currentWarningVersion = currentWarningVersion {
    if (currentWarningVersion.isEmpty) {
      throw ArgumentError.value(
        currentWarningVersion,
        'currentWarningVersion',
        'ne peut pas etre vide : une version vide ne peut etre ni comparee '
            'ni ecrite',
      );
    }
  }

  final AcknowledgementRepository _acknowledgements;
  final String _currentWarningVersion;

  /// Vrai tant que l'acquittement n'a pas ete lu ou obtenu : c'est aussi la
  /// valeur de depart, avant tout appel a [load] — en cas de doute, l'ecran
  /// reste bloque plutot que de s'ouvrir par defaut (BR-012).
  bool _requiresAcknowledgement = true;

  /// Faux tant que l'ecran bloquant doit etre presente avant tout acces a
  /// l'application (`BR-012`).
  bool get requiresAcknowledgement => _requiresAcknowledgement;

  bool _checkboxChecked = false;

  /// Etat de la case a cocher de l'ecran. Jamais precochee (`BR-012`).
  bool get checkboxChecked => _checkboxChecked;

  /// Vrai seulement quand la case est cochee : c'est ce qui active le
  /// bouton d'acquittement dans la vue. [acknowledge] refuse aussi
  /// d'ecrire tant que ce n'est pas vrai — defense en profondeur, la vue
  /// desactive deja le bouton.
  bool get canAcknowledge => _checkboxChecked;

  Object? _error;

  /// La derniere erreur survenue en ecrivant l'acquittement, ou `null`.
  /// Un echec d'ECRITURE n'est jamais avale en silence : l'ecran reste
  /// bloque et cette erreur est exposee, a charge pour la vue de proposer
  /// un nouvel essai. Un echec de LECTURE, lui, ne pose pas cette valeur —
  /// il se traduit uniquement par [requiresAcknowledgement] a vrai : on
  /// rebloque, on n'affiche rien de plus.
  Object? get error => _error;

  bool _disposed = false;

  /// Lit la version acquittee et la compare a [_currentWarningVersion]
  /// (`UC-006 A1`, `A3`) : identique → l'ecran ne reapparait pas ; absente,
  /// differente, ou vide → il se (re)bloque. Un echec de lecture rebloque
  /// egalement, sans poser [error] — c'est le cas d'ecriture qui l'expose.
  ///
  /// Notifie **toujours une fois** en fin de lecture, meme si
  /// [requiresAcknowledgement] ne change pas de valeur (stockage vide :
  /// vrai avant, vrai apres) : « la lecture est finie » est l'evenement que
  /// la vue attend pour cesser d'attendre — contrairement a [toggleCheckbox],
  /// qui ne notifie que sur changement effectif.
  Future<void> load() async {
    try {
      final String? stored = await _acknowledgements.readAcknowledgedVersion();
      if (_disposed) {
        return;
      }
      _requiresAcknowledgement = stored != _currentWarningVersion;
    } on Object {
      if (_disposed) {
        return;
      }
      // On rebloque, on n'ouvre pas : en cas de doute face a un stockage
      // illisible, l'usager relit les limites (BR-012).
      _requiresAcknowledgement = true;
    }
    notifyListeners();
  }

  /// Coche ou decoche la case. Ne notifie que si l'etat change reellement
  /// (une seule notification par changement effectif) : cocher deux fois de
  /// suite ne doit pas agiter la vue pour rien.
  void toggleCheckbox(bool value) {
    if (_checkboxChecked == value) {
      return;
    }
    _checkboxChecked = value;
    notifyListeners();
  }

  /// Persiste [_currentWarningVersion] comme version acquittee, si et
  /// seulement si la case est cochee — sans quoi rien n'est ecrit ni
  /// notifie : defense en profondeur, la vue desactive deja le bouton dans
  /// ce cas.
  ///
  /// Un echec d'ecriture laisse l'ecran a l'etat « a acquitter » et pose
  /// [error] ; un succes bascule [requiresAcknowledgement] a faux et efface
  /// une erreur precedente. Si la case est decochee pendant l'ecriture en
  /// vol, l'acquittement deja persiste l'emporte et l'ecran s'ouvre
  /// (`UC-006 § 6`) : decocher n'annule pas un acquittement engage.
  Future<void> acknowledge() async {
    if (!_checkboxChecked) {
      return;
    }

    try {
      await _acknowledgements.writeAcknowledgedVersion(_currentWarningVersion);
      if (_disposed) {
        return;
      }
      _requiresAcknowledgement = false;
      _error = null;
    } on Object catch (error) {
      if (_disposed) {
        return;
      }
      _error = error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
