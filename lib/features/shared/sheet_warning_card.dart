// L'encart daté de tête (Task W4, emplacement 3 de `04-ui.md § 5`) : premier
// occupant de `lib/features/shared/` (arbitrage du commanditaire du
// 2026-09-18) — la seule tranche que `station_sheet` et `onde_sheet`
// peuvent toutes deux importer sans se voir l'une l'autre
// (`test/architecture/layers_test.dart`, règle `shared-sans-tranche`).
//
// ⚠️ Il reçoit un GENRE ([SheetWarningKind]) et une DATE, jamais un état de
// fiche : il n'importe ni `StationSheetState` ni `StationMapState`. Un
// widget partagé qui importerait l'état d'une seule tranche romprait
// aussitôt le partage (point 17 du plan T1, laissé ouvert).
//
// Couple de teintes repris de `map_warning_banner.dart` (`W3`) pour le
// contraste (`04-ui.md § 3`, ≥ 7:1) : texte noir sur fond blanc, 21:1.

import 'package:flutter/material.dart';
import 'package:martinpecheur/domain/formatting/display_date.dart';
import 'package:martinpecheur/domain/warnings/warning_texts.dart';

/// Fond de l'encart — même convention que le bandeau d'avertissement de la carte
/// (`map_warning_banner.dart`) et les avis de `map_empty_states.dart`.
const Color sheetWarningCardBackground = Colors.white;

/// Texte et icône de l'encart — 21:1 sur [sheetWarningCardBackground].
const Color sheetWarningCardForeground = Colors.black;

/// Clé de la région d'alerte que forme l'encart, pour qu'un test puisse le
/// retrouver sans dépendre de son texte.
const Key sheetWarningCardRegionKey = Key('sheet-warning-card-region');

/// L'encart daté de tête d'une fiche (`04-ui.md § 5`, emplacement 3,
/// `BR-001`) : [kind] choisit la version (station ou ONDE, cette dernière
/// plus insistante), [dataDate] est la date de la mesure ou de la campagne.
class SheetWarningCard extends StatelessWidget {
  const SheetWarningCard({
    required this.kind,
    required this.dataDate,
    this.utcOffsetOf = systemUtcOffsetOf,
    super.key,
  });

  /// La version de l'encart : station ou ONDE.
  final SheetWarningKind kind;

  /// La date de la mesure (un INSTANT, station) ou de la campagne (une DATE
  /// CALENDAIRE, ONDE) — jamais absente : un encart sans date manque à
  /// `BR-001`.
  final DateTime dataDate;

  /// Le décalage UTC → heure locale, demandé pour [dataDate] quand elle est
  /// un instant (`H1`) — sans effet pour la version ONDE.
  final UtcOffsetOf utcOffsetOf;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: sheetWarningCardRegionKey,
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: sheetWarningCardBackground,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: sheetWarningCardForeground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sheetWarningText(kind, dataDate, offsetOf: utcOffsetOf),
                  style: const TextStyle(color: sheetWarningCardForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
