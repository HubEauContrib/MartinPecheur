// Le ViewModel de la fiche station (MVVM, ADR-014) : au tap d'un point, il
// charge la station puis ses deux dernières observations (débit, hauteur)
// et porte l'état que la vue affiche. Même style que `MapViewModel` — jeton
// de génération contre une réponse tardive, `_disposed` contre une
// notification après `dispose()`.
//
// ⚠️ Un ViewModel ne connaît aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Le verrou est
// `test/architecture/layers_test.dart` (règle `view-model-sans-widget`).
//
// Aucun formatage de NOMBRE ici (BR-002 : le mapper convertit une seule
// fois, ce ViewModel ne reconvertit rien) — [StationSheetData] expose des
// types du domaine, la vue formate leur valeur. La seule mise en forme
// tenue ici est une DATE ou une durée en heures entières, dans
// [StationSheetData.stalenessNotice] : préfixe commun avec
// `stationMapStateLabel` (« Dernière mesure … »), mais la fiche donne
// l'âge RÉEL de la mesure là où la carte se contente de la borne franchie.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Libellé de repli quand `libelle_statut` est absent ou vide (BR-006,
/// BR-011) : jamais une chaîne vide à l'écran.
const String _statusFallback = 'non renseigné';

/// Libellé de repli quand `libelle_qualification` est absent ou vide
/// (BR-006, BR-011).
const String _qualificationFallback = 'non qualifiée';

/// État de l'écran fiche station. `sealed` + `switch` exhaustif (BR-011) :
/// une sous-classe ajoutée sans branche ailleurs devient une erreur de
/// compilation, jamais un oubli silencieux à l'écran.
sealed class StationSheetState {
  const StationSheetState();
}

/// Aucune station n'est demandée, ou la fiche vient d'être fermée.
final class Fermee extends StationSheetState {
  const Fermee();
}

/// La station [code] est en cours de chargement : ni succès, ni échec.
final class EnCours extends StationSheetState {
  const EnCours(this.code);

  /// Code de la station demandée.
  final StationCode code;
}

/// La station et ses observations ont été chargées avec succès.
final class Prete extends StationSheetState {
  const Prete(this.data);

  /// Données prêtes pour l'affichage.
  final StationSheetData data;
}

/// La station [code] est sur la carte mais **absente du référentiel
/// embarqué** : `assets/referentiel/stations.json` porte 4 150 points et
/// seulement 4 113 entités complètes — 37 stations en service n'ont pas de
/// `code_departement` (stations transfrontalières, plus deux corses) et sont
/// écartées plutôt que de recevoir un département inventé (fait constaté le
/// 2026-09-13, `test/data/referentiel/stations_asset_test.dart`).
///
/// ⚠️ **Aucun appel réseau n'a eu lieu** : `AssetStationRepository` lit un
/// asset embarqué. Cet état est donc distinct d'[EnEchec], qui ne porte que
/// les échecs de dépôt — nommer Hub'Eau ici serait une accusation fausse
/// (`BR-007`, `UC-001 A4`).
final class Introuvable extends StationSheetState {
  const Introuvable(this.code);

  /// Code de la station demandée, absente du référentiel embarqué.
  final StationCode code;
}

/// Le chargement de [code] a échoué, pour [cause] (UC-001 A4) : une panne du
/// dépôt — réseau, lecture d'asset — jamais une simple absence, qui est
/// [Introuvable]. La vue nomme la source défaillante depuis [code] et son
/// PROPRE libellé — jamais depuis `cause.toString()`, qui reste une donnée
/// de diagnostic technique, pas un texte à afficher.
final class EnEchec extends StationSheetState {
  const EnEchec(this.code, this.cause);

  /// Code de la station dont le chargement a échoué.
  final StationCode code;

  /// Cause de l'échec, telle que levée par le dépôt appelé.
  final Object cause;
}

/// Données prêtes pour la fiche station. Types du domaine uniquement —
/// aucune valeur brute d'API, aucun nombre pré-formaté (BR-002).
final class StationSheetData {
  const StationSheetData({
    required this.station,
    required this.discharge,
    required this.level,
    required this.freshness,
    required this.statusLabel,
    required this.qualificationLabel,
    required this.stalenessNotice,
  });

  /// Station affichée.
  final Station station;

  /// Dernière observation de débit connue. `null` si la station n'a
  /// transmis aucune mesure de débit (BR-007) — jamais un zéro.
  final HydroObservation? discharge;

  /// Dernière observation de hauteur connue. `null` si la station n'a
  /// transmis aucune mesure de hauteur (BR-007) — jamais un zéro.
  final HydroObservation? level;

  /// Fraîcheur du débit, ou `null` si [discharge] est absent : sans mesure,
  /// il n'y a rien à dater.
  final Freshness? freshness;

  /// Libellé de statut du débit, replié sur [_statusFallback] si absent ou
  /// vide, y compris quand [discharge] est `null`.
  final String statusLabel;

  /// Libellé de qualification du débit, replié sur
  /// [_qualificationFallback] si absent ou vide, y compris quand
  /// [discharge] est `null`.
  final String qualificationLabel;

  /// Avis de fraîcheur, préfixé comme `stationMapStateLabel`
  /// (« Dernière mesure … ») mais avec l'âge RÉEL de la mesure — la fiche
  /// dit « il y a 3 h » quand la carte se contenterait de la borne
  /// franchie (« plus de 2 h »). `null` si [discharge] est absent ou si la
  /// mesure est [Freshness.fraiche] — une mesure fraîche ne porte aucune
  /// mention (BR-005).
  final String? stalenessNotice;
}

/// ViewModel de la fiche station : porte l'état de l'écran et le seul
/// chemin par lequel il est chargé.
final class StationSheetViewModel extends ChangeNotifier {
  StationSheetViewModel({
    required this._observations,
    required this._stations,
    DateTime Function()? now,
    UtcOffsetOf? utcOffsetOf,
  }) : _now = now ?? DateTime.now,
       _utcOffsetOf = utcOffsetOf ?? systemUtcOffsetOf;

  final HydroObservationRepository _observations;
  final StationRepository _stations;
  final DateTime Function() _now;
  final UtcOffsetOf _utcOffsetOf;

  StationSheetState _state = const Fermee();

  /// État courant de la fiche.
  StationSheetState get state => _state;

  /// Levé par [dispose] : une réponse qui arrive après coup ne doit plus
  /// toucher l'état ni appeler `notifyListeners`.
  bool _disposed = false;

  /// Numéro du dernier chargement demandé. Une réponse dont le numéro
  /// n'est plus le dernier appartient à un `open()` abandonné — par un
  /// `close()` ou par un `open()` plus récent — et n'écrit rien (même
  /// garde que `MapViewModel._generation`).
  int _generation = 0;

  /// Charge la station [code] : la station d'abord (`stations.findByCode`),
  /// puis ses deux dernières observations (débit, hauteur), les deux
  /// toujours demandées — si l'une des deux lève, l'état final est
  /// [EnEchec], quelle que soit celle qui a levé.
  ///
  /// Deux issues négatives, jamais confondues : `findByCode` qui rend `null`
  /// donne [Introuvable] — une absence du référentiel embarqué, sans aucun
  /// appel réseau — là où un dépôt qui LÈVE donne [EnEchec].
  Future<void> open(StationCode code) async {
    final int generation = ++_generation;
    _emit(generation, EnCours(code));

    try {
      final Station? station = await _stations.findByCode(code);
      if (station == null) {
        // Absence, pas panne : le dépôt a répondu, et il a répondu « je ne
        // l'ai pas ». Les 37 stations sans `code_departement` sont dans ce
        // cas — sur la carte, pas dans le référentiel. Aucun appel réseau
        // n'a eu lieu, donc aucune source distante n'est mise en cause
        // (`BR-007`).
        _emit(generation, Introuvable(code));
        return;
      }

      // `Future.sync` enveloppe un appel qui lèverait de façon SYNCHRONE :
      // sans lui, une levée immédiate du premier appel empêcherait le
      // second d'être même construit, et la hauteur ne serait jamais
      // demandée — contraire à l'invariant "les deux observations sont
      // demandées" (`CachedHydroObservationRepository.findLatest` n'est
      // pas `async` et peut lever ainsi). `Future.wait` garde son
      // `eagerError` par défaut (`false`) : `open` attend que les DEUX
      // appels se terminent avant de basculer en échec.
      final List<HydroObservation?> results =
          await Future.wait<HydroObservation?>(<Future<HydroObservation?>>[
            Future<HydroObservation?>.sync(
              () => _observations.findLatest(code, Grandeur.debit),
            ),
            Future<HydroObservation?>.sync(
              () => _observations.findLatest(code, Grandeur.hauteur),
            ),
          ]);
      final HydroObservation? discharge = results[0];
      final HydroObservation? level = results[1];

      final DateTime now = _now();
      final Freshness? freshness = discharge?.freshnessAt(now);

      _emit(
        generation,
        Prete(
          StationSheetData(
            station: station,
            discharge: discharge,
            level: level,
            freshness: freshness,
            statusLabel: _orFallback(
              discharge?.qualification.statusLabel,
              _statusFallback,
            ),
            qualificationLabel: _orFallback(
              discharge?.qualification.qualificationLabel,
              _qualificationFallback,
            ),
            stalenessNotice: _stalenessNotice(
              freshness: freshness,
              measuredAt: discharge?.measuredAt,
              now: now,
              offsetOf: _utcOffsetOf,
            ),
          ),
        ),
      );
    } on Object catch (error) {
      _emit(generation, EnEchec(code, error));
    }
  }

  /// Ferme la fiche : toute réponse d'un `open()` en cours devient tardive
  /// et n'écrira plus rien (le jeton de génération change ici aussi).
  void close() {
    final int generation = ++_generation;
    _emit(generation, const Fermee());
  }

  /// Applique [next] si [generation] est toujours la dernière demandée et
  /// que ce ViewModel n'est pas disposé ; notifie dans ce seul cas.
  void _emit(int generation, StationSheetState next) {
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

/// Rend [label] s'il est non nul et non vide, sinon [fallback].
String _orFallback(String? label, String fallback) {
  if (label == null || label.isEmpty) {
    return fallback;
  }
  return label;
}

/// Avis de fraîcheur affichable, ou `null` si aucune mention n'est due
/// (pas de mesure, ou mesure [Freshness.fraiche]). Même préfixe que
/// `stationMapStateLabel` (« Dernière mesure … »), mais l'âge RÉEL plutôt
/// que la borne franchie : « il y a N h » pour une mesure ancienne, une
/// date JJ/MM/AAAA pour une mesure périmée — jamais un nombre nu (BR-005).
/// `Duration.inHours` tronque vers zéro, comme dans `stationMapStateLabel` :
/// à 2 h 59 de mesure, l'avis affiche encore « il y a 2 h ».
String? _stalenessNotice({
  required Freshness? freshness,
  required DateTime? measuredAt,
  required DateTime now,
  required UtcOffsetOf offsetOf,
}) {
  if (freshness == null || measuredAt == null) {
    return null;
  }
  return switch (freshness) {
    Freshness.fraiche => null,
    Freshness.ancienne =>
      'Dernière mesure il y a ${now.difference(measuredAt).inHours} h',
    Freshness.perimee =>
      'Dernière mesure le '
          '${formatLocalDateTime(measuredAt, offsetOf: offsetOf)}',
  };
}
