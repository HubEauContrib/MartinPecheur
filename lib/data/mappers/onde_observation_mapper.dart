// Le mapper est le seul point de passage entre une ligne brute de
// `/ecoulement/observations` et le domaine (BR-002). `code_campagne` est
// l'écart le plus coûteux de cette API : un entier côté `/campagnes`, une
// chaîne côté `/observations` (T-07) — `/campagnes` n'a aucun appelant
// (retiré le 2026-09-14), mais `_campaignCode` reste tolérant aux deux
// formes puisque `code_campagne` peut en théorie arriver dans l'une ou
// l'autre selon la source. Il est donc lu en `Object?` et rendu en `String`
// sans jamais passer par un `as int` — un tel cast casserait sur l'une des
// deux formes, sans qu'aucun test de l'autre ne le voie. `date_observation`
// est une date sans heure (T-08) : aucune heure n'est inventée, la date est
// reconstruite en UTC minuit explicite à partir de ses seules composantes
// année/mois/jour, lues sur les dix premiers caractères `AAAA-MM-JJ`
// seulement — un suffixe d'heure ou de fuseau est ignoré, jamais converti.
// Tout champ texte passe par `_text` : un `as String?` nu lèverait un
// `TypeError` non documenté si l'API rendait un jour un entier là où une
// chaîne est attendue ; `_text` lève une `FormatException` à la place, et
// normalise la chaîne vide en `null` (BR-007, jamais une chaîne vide).
// `code_ecoulement` est lui aussi lu par `_text` puis délégué à
// `flowCategoryFromCode` (`lib/domain/nomenclature/flow_category.dart`),
// jamais recopié : un code non reconnu devient `Inconnu`, il ne fait jamais
// planter l'appelant (C-10, BR-011) — une chaîne vide devient `Inconnu(null)`
// et non `Inconnu('')`, `_text` l'ayant déjà normalisée en absence.

import 'package:martinpecheur/domain/geo/administrative_area.dart';
import 'package:martinpecheur/domain/nomenclature/flow_category.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_point.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';

/// Convertit une ligne brute de `/ecoulement/observations` en
/// [OndeObservation].
///
/// Lève une [FormatException] si `code_station` ou `date_observation` sont
/// absents ou illisibles, une [ArgumentError] si `code_station` est
/// entièrement blanc (via [OndeStationCode] — plus aucune validation de
/// forme depuis le 2026-09-14 : le code ONDE est une chaîne libre, `T-14`).
/// `code_ecoulement` inconnu ou
/// absent ne lève jamais : il devient [Inconnu] (BR-011) — y compris une
/// chaîne vide, normalisée en absence par [_text] (BR-007) : elle rend
/// `Inconnu(null)`, jamais `Inconnu('')`, une chaîne vide n'étant pas un
/// code.
///
/// [OndeObservation.point] est lu par [mapOndePoint], réutilisé, pas
/// recopié (D8) ; [OndeObservation.station] est dérivé de `point.code`, une
/// seule lecture de `code_station` pour les deux champs. D8 a ajouté que
/// l'absence ou l'illisibilité de `latitude`/`longitude` lève une
/// [FormatException], en plus de celle propre à `date_observation`.
///
/// ⚠️ Ces exceptions restent **par ligne** : depuis le 2026-09-14, c'est à
/// l'appelant de décider si une ligne illisible est fatale.
/// `HttpOndeObservationRepository` les ignore et les compte, plutôt que de
/// perdre une page entière pour une ligne (`T-14`, `BR-007`).
OndeObservation mapOndeObservation(Map<String, dynamic> raw) {
  final OndePoint point = mapOndePoint(raw);

  final DateTime observedAt = _dateOnly(raw, 'date_observation');

  final String? rawFlowCode = _text(raw, 'code_ecoulement');
  final FlowCategory category = flowCategoryFromCode(rawFlowCode);

  return OndeObservation(
    station: point.code,
    point: point,
    observedAt: observedAt,
    category: category,
    rawFlowCode: rawFlowCode,
    officialLabel: _text(raw, 'libelle_ecoulement'),
    campaignCode: _campaignCode(raw, 'code_campagne'),
  );
}

/// Convertit une ligne brute de `/ecoulement/observations` en [OndePoint].
///
/// `latitude`/`longitude` sont lues à plat ; `geometry` (GeoJSON) est
/// ignorée — deux sources concordantes, une seule lue (T-09). Lève une
/// [FormatException] si `code_station`, `latitude` ou `longitude` sont
/// absents ou illisibles : un point sans coordonnées n'est pas plaçable.
/// `libelle_station` absent ou vide replie [OndePoint.label] sur le code,
/// jamais une chaîne vide (BR-007).
OndePoint mapOndePoint(Map<String, dynamic> raw) {
  final OndeStationCode code = _stationCode(raw);

  final Object? rawLatitude = raw['latitude'];
  final Object? rawLongitude = raw['longitude'];
  if (rawLatitude is! num || rawLongitude is! num) {
    throw const FormatException(
      'latitude/longitude absentes ou illisibles — un point sans '
      'coordonnées n\'est pas plaçable',
    );
  }

  return OndePoint(
    code: code,
    label: _text(raw, 'libelle_station') ?? code.value,
    latitude: rawLatitude.toDouble(),
    longitude: rawLongitude.toDouble(),
    waterCourseLabel: _text(raw, 'libelle_cours_eau'),
    departement: _departementArea(raw),
    region: _regionArea(raw),
  );
}

/// Lit le département (ADR-015) sous forme d'[AdministrativeArea]. Le code
/// reste validé par [DepartementCode], comme avant `Z2` — un code mal formé
/// lève toujours, propagé tel quel. `libelle_departement` absent replie le
/// libellé sur le code : les fixtures capturées avant `T-16` ne portent pas
/// ce champ.
AdministrativeArea? _departementArea(Map<String, dynamic> raw) {
  final String? rawCode = _text(raw, 'code_departement');
  if (rawCode == null) {
    return null;
  }
  final DepartementCode code = DepartementCode(rawCode);
  final String label = _text(raw, 'libelle_departement') ?? code.value;
  return AdministrativeArea(code: code.value, label: label);
}

/// Lit la région (ADR-015). Aucun type dédié ne valide `code_region` — une
/// chaîne libre, comme l'asset la porte (`ADR-015`) : un `code_region`
/// numérique lève tout de même une [FormatException], via [_text], comme
/// n'importe quel autre champ texte. `libelle_region` absent replie le
/// libellé sur le code.
AdministrativeArea? _regionArea(Map<String, dynamic> raw) {
  final String? rawCode = _text(raw, 'code_region');
  if (rawCode == null) {
    return null;
  }
  final String label = _text(raw, 'libelle_region') ?? rawCode;
  return AdministrativeArea(code: rawCode, label: label);
}

/// Lit `code_station`, partagé par [mapOndeObservation] et [mapOndePoint].
/// Lève une [FormatException] si absent (ou vide — [_text] normalise la
/// chaîne vide en absence), une [ArgumentError] si le code est entièrement
/// blanc (via [OndeStationCode]). Aucune forme n'est exigée : le code est
/// conservé verbatim, espaces intérieurs et de bord compris (`T-14`).
OndeStationCode _stationCode(Map<String, dynamic> raw) {
  final String? rawStationCode = _text(raw, 'code_station');
  if (rawStationCode == null) {
    throw const FormatException(
      'code_station absent — la station ne peut pas être identifiée',
    );
  }
  return OndeStationCode(rawStationCode);
}

/// Lit un champ texte de [raw]. Rend `null` si absent ou vide — la chaîne
/// vide est normalisée en `null` (BR-007 : jamais une chaîne vide comme
/// valeur). Lève une [FormatException] si le champ est présent mais n'est
/// pas une chaîne : un `as String?` nu lèverait sinon un `TypeError` non
/// documenté à la frontière, la première fois que l'API rend un entier là
/// où une chaîne était attendue.
String? _text(Map<String, dynamic> raw, String field) {
  final Object? value = raw[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$field attendu textuel, reçu $value');
  }
  return value.isEmpty ? null : value;
}

/// Lit `code_campagne` dans [raw] sous la clé [field], rendu tantôt en
/// entier (`/campagnes`), tantôt en chaîne (`/observations`) — T-07. Aucun
/// `as int` n'apparaît ici : le contenu est distingué par son type, jamais
/// forcé. Une chaîne vide est normalisée en `null`, comme [_text] (BR-007).
String? _campaignCode(Map<String, dynamic> raw, String field) =>
    switch (raw[field]) {
      null => null,
      final String value => value.isEmpty ? null : value,
      final num value => value.toInt().toString(),
      final Object value => throw FormatException(
        '$field de type inattendu : $value',
      ),
    };

/// Motif d'une date sans heure `AAAA-MM-JJ`, ancré en début de chaîne : un
/// éventuel suffixe d'heure ou de fuseau (`T10:00:00`, `+02:00`…) n'est pas
/// capturé, donc jamais lu.
final RegExp _dateOnlyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Lit une date sans heure (l'API n'en donne pas, T-08) et la rend en UTC
/// minuit explicite. Seuls les dix premiers caractères `AAAA-MM-JJ` sont
/// lus, via [_dateOnlyPattern] : un suffixe d'heure ou de fuseau observé sur
/// certains flux est ignoré, jamais converti, pour ne jamais introduire de
/// décalage de jour au passage en UTC — `'2026-08-26T00:30:00+02:00'` reste
/// le 26, pas un recul au 25.
///
/// Lève une [FormatException] si `raw[field]` est absent, ne commence pas
/// par ce motif, ou si le mois ou le jour sont hors plage — y compris un
/// débordement que le garde `1..12`/`1..31` ne voit pas, comme le 31 février
/// (`'2026-02-31'`) : `DateTime.utc` déborde silencieusement vers le 3 mars
/// au lieu de lever, ce qui ferait ressortir une date fausse plutôt qu'une
/// erreur explicite (BR-001) — une date muette ferait sinon ressortir
/// l'observation ou la campagne comme la plus récente, l'état le moins
/// fiable. Le débordement est donc détecté après coup, en comparant la date
/// construite à ses composantes d'origine, et refusé.
DateTime _dateOnly(Map<String, dynamic> raw, String field) {
  final Object? value = raw[field];
  if (value is! String) {
    throw FormatException('$field absent ou illisible');
  }
  final RegExpMatch? match = _dateOnlyPattern.firstMatch(value);
  if (match == null) {
    throw FormatException('$field attendu au format AAAA-MM-JJ, reçu $value');
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw FormatException('$field hors plage : $value');
  }
  final DateTime date = DateTime.utc(year, month, day);
  if (date.month != month || date.day != day) {
    throw FormatException('$field hors plage : $value');
  }
  return date;
}
