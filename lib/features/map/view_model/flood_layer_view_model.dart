// Second ViewModel de l'écran carte (T4, L2 ; arbitrage 7, ADR-014 amendé) :
// l'état de la lecture Crues, qui a son propre cycle de chargement.
//
// C'est la vue qui le prévient — sélection de la puce « Vigilance crues »
// ([FloodLayerViewModel.activate]), relâchement de geste
// ([FloodLayerViewModel.onViewportChanged]), « Réessayer »
// ([FloodLayerViewModel.retry]) ; aucun ViewModel n'importe l'autre.
//
// Un seul chargement tant que le premier court ; après un échec sans carte
// lue, seul « Réessayer » relance (arbitrage 10). Une fois une carte lue,
// chaque geste relit la source : le décorateur de cache rend la carte gardée
// et, périmée, lance un rafraîchissement en fond (arbitrage 12). Ce ViewModel
// n'a aucune règle de temps. Étiquettes et emprise sont lues dans les règles
// du domaine (`flood_section_rules.dart`) ; le seuil de zoom n'est pas ici,
// l'appelant dit `individualLevel`.
//
// ⚠️ Aucun widget, aucun fichier de `lib/data/`, aucune autre tranche.

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:martinpecheur/domain/floods/flood_section.dart';
import 'package:martinpecheur/domain/floods/flood_section_rules.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';
import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';

/// État de la lecture Crues. Noms préfixés : `EnCours`, `Prete`, `EnEchec`
/// existent déjà dans la tranche fiche station (D5).
sealed class FloodLayerState {
  const FloodLayerState();
}

/// La lecture Crues n'a jamais été activée : rien n'est lu.
final class LectureCruesNonDemandee extends FloodLayerState {
  const LectureCruesNonDemandee();
}

/// Premier chargement en cours, aucune carte lue.
final class LectureCruesEnCours extends FloodLayerState {
  const LectureCruesEnCours();
}

/// Une carte de vigilance est lue.
final class LectureCruesPrete extends FloodLayerState {
  const LectureCruesPrete(this.map);

  /// La carte lue, avec sa date.
  final FloodVigilanceMap map;
}

/// Le chargement a échoué sans qu'aucune carte ait été lue.
final class LectureCruesEnEchec extends FloodLayerState {
  const LectureCruesEnEchec(this.cause);

  /// La cause, telle que levée par la source ; jamais affichée telle quelle.
  final Object cause;
}

/// Une étiquette à poser : le tronçon et son ancre dans l'emprise.
final class FloodLabel {
  const FloodLabel({required this.section, required this.anchor});

  /// Le tronçon étiqueté.
  final FloodSection section;

  /// Le point du trait visible où poser l'étiquette.
  final GeoPoint anchor;
}

/// Porte l'état de la lecture Crues, les étiquettes et la présence d'un
/// tronçon dans l'emprise retenue.
final class FloodLayerViewModel extends ChangeNotifier {
  /// L'argument se nomme `source` à l'appel.
  FloodLayerViewModel({required this._source});

  final FloodVigilanceSource _source;

  FloodLayerState _state = const LectureCruesNonDemandee();

  /// État courant.
  FloodLayerState get state => _state;

  List<FloodLabel> _labels = const <FloodLabel>[];

  /// Les étiquettes de la dernière emprise retenue, dans l'ordre de
  /// tabulation ; `const []` hors [LectureCruesPrete].
  List<FloodLabel> get labels => _labels;

  bool? _anySectionInBounds;

  /// Un tronçon touche-t-il la dernière emprise retenue ? `null` tant
  /// qu'aucune emprise n'est connue ou hors [LectureCruesPrete] : l'absence
  /// ne se dit que sur `false` (BR-007, D10).
  bool? get anySectionInBounds => _anySectionInBounds;

  /// Dernière emprise retenue, quel que soit l'état : celle donnée pendant le
  /// premier chargement sert à son aboutissement, sans nouveau geste.
  Bounds? _bounds;
  bool _individualLevel = false;

  /// Levé par [dispose] : une lecture qui aboutit après coup n'écrit rien.
  bool _disposed = false;

  /// Génération de lecture : incrémentée à chaque lecture lancée ; une
  /// lecture dépassée par une plus récente n'écrit rien.
  int _generation = 0;

  /// Sélection de la puce « Vigilance crues ».
  ///
  /// Depuis [LectureCruesNonDemandee] : passe en [LectureCruesEnCours] puis
  /// lit. Depuis [LectureCruesPrete] : relit sans repasser par
  /// [LectureCruesEnCours]. Depuis [LectureCruesEnCours] ou
  /// [LectureCruesEnEchec] : rien — aucun second téléchargement, seul
  /// [retry] relance.
  Future<void> activate() {
    switch (_state) {
      case LectureCruesNonDemandee():
        _state = const LectureCruesEnCours();
        notifyListeners();
        return _read();
      case LectureCruesPrete():
        return _read();
      case LectureCruesEnCours():
      case LectureCruesEnEchec():
        return Future<void>.value();
    }
  }

  /// Relâchement de geste : retient l'emprise et le niveau individuel ;
  /// en [LectureCruesPrete], recalcule étiquettes et présence (notifie si
  /// l'une change) puis relit la source. Ne relit rien dans les autres états.
  Future<void> onViewportChanged(
    Bounds bounds, {
    required bool individualLevel,
  }) {
    _bounds = bounds;
    _individualLevel = individualLevel;
    switch (_state) {
      case LectureCruesPrete(:final FloodVigilanceMap map):
        if (_recompute(map)) {
          notifyListeners();
        }
        return _read();
      case LectureCruesNonDemandee():
      case LectureCruesEnCours():
      case LectureCruesEnEchec():
        return Future<void>.value();
    }
  }

  /// « Réessayer » : seulement depuis [LectureCruesEnEchec], passe en
  /// [LectureCruesEnCours] puis lit.
  Future<void> retry() {
    switch (_state) {
      case LectureCruesEnEchec():
        _state = const LectureCruesEnCours();
        notifyListeners();
        return _read();
      case LectureCruesNonDemandee():
      case LectureCruesEnCours():
      case LectureCruesPrete():
        return Future<void>.value();
    }
  }

  /// Le tronçon de code [code] sur la carte lue ; `null` hors
  /// [LectureCruesPrete] ou s'il n'y est pas.
  FloodSection? sectionByCode(FloodSectionCode code) => switch (_state) {
    LectureCruesPrete(:final FloodVigilanceMap map) => map.sectionByCode(code),
    LectureCruesNonDemandee() => null,
    LectureCruesEnCours() => null,
    LectureCruesEnEchec() => null,
  };

  /// Lit la source ; l'appel part avant tout `await`.
  Future<void> _read() async {
    final int generation = ++_generation;
    final FloodVigilanceMap map;
    try {
      map = await _source.current();
    } on Object catch (cause) {
      if (_disposed || generation != _generation) {
        return;
      }
      switch (_state) {
        case LectureCruesPrete():
          // Une carte lue n'est jamais remplacée par un échec. Le décorateur
          // de cache absorbe déjà ce cas : ceinture et bretelles.
          return;
        case LectureCruesNonDemandee():
        case LectureCruesEnCours():
        case LectureCruesEnEchec():
          _state = LectureCruesEnEchec(cause);
          notifyListeners();
          return;
      }
    }
    if (_disposed || generation != _generation) {
      return;
    }
    switch (_state) {
      case LectureCruesPrete(map: final FloodVigilanceMap previous)
          when identical(previous, map):
        return;
      case LectureCruesPrete():
      case LectureCruesNonDemandee():
      case LectureCruesEnCours():
      case LectureCruesEnEchec():
        _state = LectureCruesPrete(map);
        _recompute(map);
        notifyListeners();
    }
  }

  /// Recalcule étiquettes et présence sur la dernière emprise retenue ;
  /// rend `true` si l'une a changé.
  bool _recompute(FloodVigilanceMap map) {
    final Bounds? bounds = _bounds;
    final List<FloodLabel> labels;
    final bool? any;
    if (bounds == null) {
      labels = const <FloodLabel>[];
      any = null;
    } else {
      labels = List<FloodLabel>.unmodifiable(
        floodLabelsFor(
          map.sections,
          bounds,
          individualLevel: _individualLevel,
        ).map(
          ((FloodSection, GeoPoint) e) =>
              FloodLabel(section: e.$1, anchor: e.$2),
        ),
      );
      any = map.sections.any(
        (FloodSection section) => floodSectionTouches(section, bounds),
      );
    }
    final bool changed =
        any != _anySectionInBounds || !_sameLabels(labels, _labels);
    _labels = labels;
    _anySectionInBounds = any;

    return changed;
  }

  static bool _sameLabels(List<FloodLabel> a, List<FloodLabel> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i].section, b[i].section) ||
          a[i].anchor != b[i].anchor) {
        return false;
      }
    }

    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
