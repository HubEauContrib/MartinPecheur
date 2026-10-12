// Les documents distincts cites par les zones d'un point : dedoublonnage
// par adresse exacte et par role, arrete-cadre aux memes zones que l'unique
// arrete de restriction, dates de validite partagees. Trois decisions
// prises jusqu'ici dans la vue des restrictions, devenues des fonctions
// pures de la reponse (R1 de T3). Dart pur : aucun paquet d'infrastructure.

import 'package:martinpecheur/domain/restrictions/alert_zone.dart';

/// Un document distinct cité par les zones d'un point : son rôle, son
/// adresse telle que reçue, et les zones qui le citent.
final class DecreeDocument {
  DecreeDocument._({
    required this.isFramework,
    required this.link,
    required List<AlertZone> zones,
  }) : zones = List<AlertZone>.unmodifiable(zones);

  /// Vrai pour un arrêté-cadre, faux pour un arrêté de restriction.
  final bool isFramework;
  final DocumentLink link;

  /// Les zones qui citent ce document, dans l'ordre reçu. Jamais vide.
  final List<AlertZone> zones;

  /// Les dates de validité si TOUTES les zones les partagent, sinon `null` :
  /// rien n'est choisi à la place d'un désaccord de la source.
  ({DateTime validFrom, DateTime? validUntil})? get sharedValidity {
    final RestrictionDecree first = zones.first.decree;
    final bool shared = zones.every(
      (AlertZone zone) =>
          zone.decree.validFrom == first.validFrom &&
          zone.decree.validUntil == first.validUntil,
    );
    if (!shared) {
      return null;
    }
    return (validFrom: first.validFrom, validUntil: first.validUntil);
  }
}

/// Arrêtés de restriction puis arrêtés-cadres, chacun une fois par adresse
/// EXACTE et par rôle, dans l'ordre de première citation.
///
/// La clé est `DocumentLink.raw` tel que reçu, sans aucune normalisation :
/// deux adresses qui diffèrent d'une casse ou d'une espace sont deux
/// documents. La liste rendue n'est pas modifiable.
List<DecreeDocument> decreeDocumentsOf(List<AlertZone> zones) {
  final Map<String, _Citations> decrees = <String, _Citations>{};
  final Map<String, _Citations> frameworks = <String, _Citations>{};
  for (final AlertZone zone in zones) {
    final DocumentLink? document = zone.decree.document;
    if (document != null) {
      decrees
          .putIfAbsent(document.raw, () => _Citations(document))
          .zones
          .add(zone);
    }
    final DocumentLink? framework = zone.decree.frameworkDocument;
    if (framework != null) {
      frameworks
          .putIfAbsent(framework.raw, () => _Citations(framework))
          .zones
          .add(zone);
    }
  }
  return List<DecreeDocument>.unmodifiable(<DecreeDocument>[
    for (final _Citations citations in decrees.values)
      DecreeDocument._(
        isFramework: false,
        link: citations.link,
        zones: citations.zones,
      ),
    for (final _Citations citations in frameworks.values)
      DecreeDocument._(
        isFramework: true,
        link: citations.link,
        zones: citations.zones,
      ),
  ]);
}

/// Vrai si [document] est un arrêté-cadre dont les zones sont exactement
/// celles de l'UNIQUE arrêté de restriction de [all].
///
/// Dès qu'il y a plusieurs arrêtés de restriction (après le dédoublonnage
/// par adresse exacte), on ne saurait pas « les mêmes que lesquelles » : faux
/// (arbitrage du commanditaire du 2026-10-06). Les zones se comparent par
/// identité d'instance, pas par égalité de valeur.
bool coversSameZonesAsSoleRestrictionDecree(
  DecreeDocument document,
  List<DecreeDocument> all,
) {
  if (!document.isFramework) {
    return false;
  }
  final List<DecreeDocument> restrictions = all
      .where((DecreeDocument other) => !other.isFramework)
      .toList();
  if (restrictions.length != 1) {
    return false;
  }
  final DecreeDocument only = restrictions.single;
  return only.zones.length == document.zones.length &&
      document.zones.every(
        (AlertZone zone) => only.zones.any((AlertZone o) => identical(o, zone)),
      );
}

/// Les citations d'une adresse pendant le parcours des zones : la première
/// adresse reçue pour cette clé, et les zones dans l'ordre.
final class _Citations {
  _Citations(this.link);

  final DocumentLink link;
  final List<AlertZone> zones = <AlertZone>[];
}
