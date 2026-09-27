// La zone d'alerte, son arrete de restriction et les usages qu'il restreint
// — conception T2 § 2.4-2.6. Dart pur : aucun paquet d'infrastructure, y
// compris `package:flutter/foundation.dart` — l'egalite structurelle des
// collections est ecrite a la main dans `value_equality.dart`, verrouille
// par le test de confinement du domaine.
//
// `usages` et `concernedProfiles` sont copies et rendus non modifiables a
// la construction : un appelant qui garde la reference passee ne peut pas
// faire deriver la zone apres coup.

import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/value_equality.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// Lien vers un document PDF (arrete ou arrete-cadre), tel que recu de la
/// source — jamais decode, jamais « repare » (BR-014). Un encodage abime
/// (`sign%C3%83%C2%A9`) est affiche exactement ainsi : le corriger serait
/// une invention.
final class DocumentLink {
  const DocumentLink(this.raw);

  /// L'adresse telle que recue. Affichee telle quelle.
  final String raw;

  /// L'URI ouvrable, ou `null` si [raw] n'est pas une URL absolue en `http`
  /// ou `https` avec un hote — un chemin relatif, un autre schema (`ftp:`,
  /// `javascript:`), une forme sans hote (`https:foo`) ou une chaine vide
  /// ne proposent aucune action d'ouverture, mais [raw] reste affiche
  /// (`UC-002 A6`).
  Uri? get openableUri {
    final Uri? parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.isAbsolute) {
      return null;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return null;
    }
    if (parsed.host.isEmpty) {
      return null;
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) => other is DocumentLink && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => 'DocumentLink($raw)';
}

/// L'arrete de restriction d'une zone : ses dates de validite et les deux
/// PDF qui font foi (BR-014). `validFrom`/`validUntil` sont des dates
/// calendaires vues a minuit UTC, jamais converties de fuseau (§ 2.5).
final class RestrictionDecree {
  RestrictionDecree({
    required DateTime validFrom,
    DateTime? validUntil,
    this.document,
    this.frameworkDocument,
  }) : validFrom = requireUtc(validFrom, 'validFrom'),
       validUntil = validUntil == null
           ? null
           : requireUtc(validUntil, 'validUntil');

  /// Date de debut de validite, en UTC. Un niveau ne s'affiche pas sans
  /// elle (`BR-001`).
  final DateTime validFrom;

  /// Date de fin de validite, en UTC. `null` : la source ne la fournit pas
  /// — rien n'est invente a sa place.
  final DateTime? validUntil;

  /// PDF de l'arrete de restriction. `null` : la zone n'en a pas
  /// (`UC-002` « Une zone sans lien d'arrete le dit »).
  final DocumentLink? document;

  /// PDF de l'arrete-cadre. `null` : absent de la reponse.
  final DocumentLink? frameworkDocument;

  @override
  bool operator ==(Object other) =>
      other is RestrictionDecree &&
      other.validFrom == validFrom &&
      other.validUntil == validUntil &&
      other.document == document &&
      other.frameworkDocument == frameworkDocument;

  @override
  int get hashCode =>
      Object.hash(validFrom, validUntil, document, frameworkDocument);

  @override
  String toString() =>
      'RestrictionDecree(validFrom: $validFrom, validUntil: $validUntil, '
      'document: $document, frameworkDocument: $frameworkDocument)';
}

/// Un usage restreint par un arrete, cite tel quel (BR-014) : [name],
/// [theme] et [description] sont les mots du prefet, jamais reformules.
/// C'est l'exception voulue a « aucune valeur brute d'API n'atteint la
/// vue » — cet invariant vise les codes et les unites, pas une citation.
final class RestrictedUsage {
  RestrictedUsage({
    required this.name,
    required this.theme,
    required this.description,
    required Set<UserProfile> concernedProfiles,
  }) : concernedProfiles = Set<UserProfile>.unmodifiable(concernedProfiles);

  final String name;
  final String theme;
  final String description;

  /// Profils concernes par cet usage. Non modifiable.
  final Set<UserProfile> concernedProfiles;

  /// Vrai si [profile] est dans [concernedProfiles].
  bool concerns(UserProfile profile) => concernedProfiles.contains(profile);

  @override
  bool operator ==(Object other) =>
      other is RestrictedUsage &&
      other.name == name &&
      other.theme == theme &&
      other.description == description &&
      setEquals(other.concernedProfiles, concernedProfiles);

  @override
  int get hashCode =>
      Object.hash(name, theme, description, setHash(concernedProfiles));

  @override
  String toString() =>
      'RestrictedUsage(name: $name, theme: $theme, '
      'concernedProfiles: $concernedProfiles)';
}

/// Une zone d'alerte secheresse : son type, sa gravite, l'arrete qui la
/// regit et les usages qu'il restreint.
final class AlertZone {
  AlertZone({
    required this.name,
    required this.kind,
    required this.severity,
    required this.decree,
    required List<RestrictedUsage> usages,
  }) : usages = List<RestrictedUsage>.unmodifiable(usages);

  final String name;
  final ZoneKind kind;
  final DroughtSeverity severity;
  final RestrictionDecree decree;

  /// Usages restreints, dans l'ordre de la source. Non modifiable.
  final List<RestrictedUsage> usages;

  /// Les usages de [usages] qui concernent [profile], dans l'ordre de la
  /// source, sans tri ni dedoublonnage (deux usages de meme nom sont
  /// gardes). Une liste vide est un resultat valide (`BR-007`).
  List<RestrictedUsage> usagesFor(UserProfile profile) =>
      List<RestrictedUsage>.unmodifiable(
        usages.where((RestrictedUsage usage) => usage.concerns(profile)),
      );

  @override
  bool operator ==(Object other) =>
      other is AlertZone &&
      other.name == name &&
      other.kind == kind &&
      other.severity == severity &&
      other.decree == decree &&
      listEquals(other.usages, usages);

  @override
  int get hashCode =>
      Object.hash(name, kind, severity, decree, Object.hashAll(usages));

  @override
  String toString() =>
      'AlertZone(name: $name, kind: $kind, severity: $severity, '
      'usages: ${usages.length})';
}
