// Le ViewModel de la fiche station (MVVM, ADR-014) : au tap d'un point, il
// charge la station puis ses deux dernieres observations (debit, hauteur) et
// porte l'etat que la vue affiche. Meme style que `MapViewModel` — jeton de
// generation contre une reponse tardive, `_disposed` contre une notification
// apres `dispose()`.
//
// ⚠️ Un ViewModel ne connait aucun widget : ce fichier n'importe ni
// `package:flutter/material.dart`, ni `widgets.dart`, ni `cupertino.dart` —
// seul `foundation.dart`, pour [ChangeNotifier]. Le verrou est
// `test/architecture/layers_test.dart` (regle `view-model-sans-widget`).
//
// Aucun formatage de NOMBRE ici (BR-002 : le mapper convertit une seule
// fois, ce ViewModel ne reconvertit rien) — [StationSheetData] expose des
// types du domaine, la vue formate leur valeur. La seule mise en forme
// tenue ici est une DATE ou une duree en heures entieres, dans
// [StationSheetData.stalenessNotice], sur le meme vocabulaire que
// `stationMapStateLabel` (`domain/observation/station_map_state.dart`).

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/repositories/repositories.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Libelle de repli quand `libelle_statut` est absent ou vide (BR-006,
/// BR-011) : jamais une chaine vide a l'ecran.
const String _statutNonRenseigne = 'non renseigné';

/// Libelle de repli quand `libelle_qualification` est absent ou vide
/// (BR-006, BR-011).
const String _qualificationNonRenseignee = 'non qualifiée';

/// Etat de l'ecran fiche station. `sealed` + `switch` exhaustif (BR-011) :
/// une sous-classe ajoutee sans branche ailleurs devient une erreur de
/// compilation, jamais un oubli silencieux a l'ecran.
sealed class StationSheetState {
  const StationSheetState();
}

/// Aucune station n'est demandee, ou la fiche vient d'etre fermee.
final class Fermee extends StationSheetState {
  const Fermee();
}

/// La station [code] est en cours de chargement : ni succes, ni echec.
final class EnCours extends StationSheetState {
  const EnCours(this.code);

  /// Code de la station demandee.
  final StationCode code;
}

/// La station et ses observations ont ete chargees avec succes.
final class Prete extends StationSheetState {
  const Prete(this.data);

  /// Donnees pretes pour l'affichage.
  final StationSheetData data;
}

/// Le chargement de [code] a echoue, pour [cause] — la vue nommera la
/// source defaillante (UC-001 A4).
final class EnEchec extends StationSheetState {
  const EnEchec(this.code, this.cause);

  /// Code de la station dont le chargement a echoue.
  final StationCode code;

  /// Cause de l'echec, telle que levee par le depot appele.
  final Object cause;
}

/// Donnees pretes pour la fiche station. Types du domaine uniquement —
/// aucune valeur brute d'API, aucun nombre pre-formate (BR-002).
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

  /// Station affichee.
  final Station station;

  /// Derniere observation de debit connue. `null` si la station n'a
  /// transmis aucune mesure de debit (BR-007) — jamais un zero.
  final HydroObservation? discharge;

  /// Derniere observation de hauteur connue. `null` si la station n'a
  /// transmis aucune mesure de hauteur (BR-007) — jamais un zero.
  final HydroObservation? level;

  /// Fraicheur du debit, ou `null` si [discharge] est absent : sans mesure,
  /// il n'y a rien a dater.
  final Freshness? freshness;

  /// Libelle de statut du debit, replie sur [_statutNonRenseigne] si absent
  /// ou vide, y compris quand [discharge] est `null`.
  final String statusLabel;

  /// Libelle de qualification du debit, replie sur
  /// [_qualificationNonRenseignee] si absent ou vide, y compris quand
  /// [discharge] est `null`.
  final String qualificationLabel;

  /// Avis de fraicheur, dans le meme vocabulaire que
  /// `stationMapStateLabel` : « Dernière mesure il y a N h » (ancienne) ou
  /// « Dernière mesure le JJ/MM/AAAA à HH:MM UTC » (perimee). `null` si
  /// [discharge] est absent ou si la mesure est [Freshness.fraiche] — une
  /// mesure fraiche ne porte aucune mention (BR-005).
  final String? stalenessNotice;
}

/// ViewModel de la fiche station : porte l'etat de l'ecran et le seul
/// chemin par lequel il est charge.
final class StationSheetViewModel extends ChangeNotifier {
  StationSheetViewModel({
    required HydroObservationRepository observations,
    required StationRepository stations,
    DateTime Function()? now,
  }) : _observations = observations, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _stations = stations,
       _now = now ?? DateTime.now;

  final HydroObservationRepository _observations;
  final StationRepository _stations;
  final DateTime Function() _now;

  StationSheetState _state = const Fermee();

  /// Etat courant de la fiche.
  StationSheetState get state => _state;

  /// Leve par [dispose] : une reponse qui arrive apres coup ne doit plus
  /// toucher l'etat ni appeler `notifyListeners`.
  bool _disposed = false;

  /// Numero du dernier chargement demande. Une reponse dont le numero n'est
  /// plus le dernier appartient a un `open()` abandonne — par un `close()`
  /// ou par un `open()` plus recent — et n'ecrit rien (meme garde que
  /// `MapViewModel._generation`).
  int _generation = 0;

  /// Charge la station [code] : la station d'abord (`stations.findByCode`),
  /// puis ses deux dernieres observations (debit, hauteur), les deux
  /// toujours demandees — si l'une des deux leve, l'etat final est
  /// [EnEchec], quelle que soit celle qui a leve.
  Future<void> open(StationCode code) async {
    final int generation = ++_generation;
    _emit(generation, EnCours(code));

    try {
      final Station? station = await _stations.findByCode(code);
      if (station == null) {
        _emit(
          generation,
          EnEchec(code, StateError('Station inconnue : ${code.value}')),
        );
        return;
      }

      // `Future.sync` enveloppe un appel qui leverait de facon SYNCHRONE :
      // sans lui, une levee immediate du premier appel empecherait le
      // second d'etre meme construit, et la hauteur ne serait jamais
      // demandee — contraire a l'invariant "les deux observations sont
      // demandees".
      final List<HydroObservation?> resultats =
          await Future.wait<HydroObservation?>(<Future<HydroObservation?>>[
            Future<HydroObservation?>.sync(
              () => _observations.findLatest(code, Grandeur.debit),
            ),
            Future<HydroObservation?>.sync(
              () => _observations.findLatest(code, Grandeur.hauteur),
            ),
          ]);
      final HydroObservation? discharge = resultats[0];
      final HydroObservation? level = resultats[1];

      final DateTime now = _now();
      final Freshness? freshness = discharge == null
          ? null
          : freshnessOf(measuredAt: discharge.measuredAt, now: now);

      _emit(
        generation,
        Prete(
          StationSheetData(
            station: station,
            discharge: discharge,
            level: level,
            freshness: freshness,
            statusLabel: _replie(
              discharge?.qualification.statusLabel,
              _statutNonRenseigne,
            ),
            qualificationLabel: _replie(
              discharge?.qualification.qualificationLabel,
              _qualificationNonRenseignee,
            ),
            stalenessNotice: _avisDeFraicheur(
              freshness: freshness,
              mesureLe: discharge?.measuredAt,
              maintenant: now,
            ),
          ),
        ),
      );
    } on Object catch (erreur) {
      _emit(generation, EnEchec(code, erreur));
    }
  }

  /// Ferme la fiche : toute reponse d'un `open()` en cours devient tardive
  /// et n'ecrira plus rien (le jeton de generation change ici aussi).
  void close() {
    final int generation = ++_generation;
    _emit(generation, const Fermee());
  }

  /// Applique [next] si [generation] est toujours la derniere demandee et
  /// que ce ViewModel n'est pas dispose ; notifie dans ce seul cas.
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

/// Rend [libelle] s'il est non nul et non vide, sinon [repli].
String _replie(String? libelle, String repli) {
  if (libelle == null || libelle.isEmpty) {
    return repli;
  }
  return libelle;
}

/// Avis de fraicheur affichable, ou `null` si aucune mention n'est due
/// (pas de mesure, ou mesure [Freshness.fraiche]). Vocabulaire partage avec
/// `stationMapStateLabel` : « il y a N h » pour une mesure ancienne, une
/// date JJ/MM/AAAA pour une mesure perimee — jamais un nombre nu (BR-005).
String? _avisDeFraicheur({
  required Freshness? freshness,
  required DateTime? mesureLe,
  required DateTime maintenant,
}) {
  if (freshness == null || mesureLe == null) {
    return null;
  }
  return switch (freshness) {
    Freshness.fraiche => null,
    Freshness.ancienne =>
      'Dernière mesure il y a ${maintenant.difference(mesureLe).inHours} h',
    Freshness.perimee => 'Dernière mesure le ${_dateEtHeureUtc(mesureLe)}',
  };
}

/// Formate [instant] en `JJ/MM/AAAA à HH:MM UTC` — la seule mise en forme
/// admise dans ce ViewModel : une date, jamais un nombre (BR-002 reste
/// tenu : aucune unite physique n'est convertie ici).
String _dateEtHeureUtc(DateTime instant) {
  final DateTime utc = instant.toUtc();
  final String jour = _deuxChiffres(utc.day);
  final String mois = _deuxChiffres(utc.month);
  final String heure = _deuxChiffres(utc.hour);
  final String minute = _deuxChiffres(utc.minute);
  return '$jour/$mois/${utc.year} à $heure:$minute UTC';
}

String _deuxChiffres(int valeur) => valeur.toString().padLeft(2, '0');
