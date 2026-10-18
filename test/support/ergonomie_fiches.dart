// Aides partagées des tests de la disposition de la carte (tranche
// d'ergonomie) : la fiche station RÉELLE de La Loire à Blois, et la question
// « la mise en page de la carte peint-elle cette pièce ? » (repli 6).
// Employées par `map_layout_invariants_test.dart` et
// `map_designation_reticle_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/observation/freshness.dart';
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/units/quantities.dart';
import 'package:martinpecheur/features/map/view/map_layout.dart';
import 'package:martinpecheur/features/shared/favorite_star.dart';
import 'package:martinpecheur/features/station_sheet/view/station_summary_sheet.dart';
import 'package:martinpecheur/features/station_sheet/view_model/station_sheet_view_model.dart';

/// La fiche station RÉELLE de La Loire à Blois, prête, avec son étoile.
Widget ficheStationBlois({Key? key}) {
  final StationCode code = StationCode('K447001001');
  final DateTime mesure = DateTime.utc(2026, 8, 27, 8);
  const Qualification qualification = Qualification(
    statusCode: 12,
    statusLabel: 'Pré-validée',
    qualificationCode: 20,
    qualificationLabel: 'Bonne',
  );
  return StationSheetPanel(
    key: key,
    state: Prete(
      StationSheetData(
        station: Station(
          code: code,
          label: 'La Loire à Blois',
          latitude: 47.584957074,
          longitude: 1.335147948,
          departement: DepartementCode('41'),
          riverLabel: 'la Loire',
          inService: true,
        ),
        discharge: HydroObservation(
          station: code,
          measuredAt: mesure,
          grandeur: Grandeur.debit,
          discharge: const CubicMetresPerSecond(47.8),
          level: null,
          qualification: qualification,
        ),
        level: HydroObservation(
          station: code,
          measuredAt: mesure,
          grandeur: Grandeur.hauteur,
          discharge: null,
          level: const Metres(-1.232),
          qualification: qualification,
        ),
        freshness: Freshness.fraiche,
        statusLabel: 'Pré-validée',
        qualificationLabel: 'Bonne',
        stalenessNotice: null,
      ),
    ),
    onClose: () {},
    favoriteStar: const FavoriteStar(filled: false, enabled: true),
    onToggleFavorite: () {},
    utcOffsetOf: (_) => const Duration(hours: 2),
  );
}

/// La mise en page de la carte ([RenderMapLayout]) peint-elle la pièce qui
/// porte [f] ? Le repli 6 retire bande et réticule : posés à taille nulle, ni
/// peints ni touchables, mais dans l'arbre. Une pièce hors de la mise en page
/// est tenue pour peinte.
bool peintParLaCarte(WidgetTester tester, Finder f) {
  RenderObject? ro = tester.renderObject(f);
  while (ro != null) {
    final RenderObject? parent = ro.parent;
    if (parent is RenderMapLayout && ro is RenderBox) {
      return parent.paintsChild(ro);
    }
    ro = parent;
  }
  return true;
}
