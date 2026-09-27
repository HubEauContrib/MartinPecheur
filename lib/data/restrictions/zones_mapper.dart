// Le SEUL point de conversion entre une reponse de `/zones` de VigiEau et le
// domaine des restrictions (conception T2 § 4.4). Aucune valeur filaire
// (`alerte_renforcee`, `SUP`, `concerneParticulier`…) n'en sort : la vue ne
// recoit que des nomenclatures scellees et des textes cites.
//
// Deux sortes de traitement, jamais confondues :
// - TOLERANCE DE NOMENCLATURE (BR-011) pour `type` et `niveauGravite` : une
//   valeur inconnue, `null` ou absente donne la branche inconnue, avec la
//   valeur brute ; un champ supplementaire est ignore ; `code` n'est pas lu
//   (il vaut `null` sur la zone `AEP` d'Ariege et se repete entre types dans
//   l'Ain et a Paris : il n'identifie rien).
// - RUPTURE DE STRUCTURE (dernier invariant de BR-011) pour les champs sans
//   lesquels l'ecran ne peut rien dire de juste : racine non tableau,
//   element non objet, `nom` de zone, `arrete`, `arrete.dateDebutValidite`,
//   `usages`, et pour chaque usage `nom`, `thematique`, `description` et les
//   quatre booleens `concerne*`. La reponse ENTIERE est alors illisible —
//   tout ou rien (AR-2, arbitre le 2026-09-27) : aucune zone lisible n'est
//   rendue seule a cote d'une zone perdue, pour qu'aucune omission ne passe
//   en silence. Un booleen `concerne*` manquant n'a aucune valeur sure :
//   `false` cacherait une restriction a un profil concerne, `true` en
//   attribuerait une a qui elle ne vise pas.
//
// Transformations admises, et seulement celles-ci :
// - chaine → nomenclature (`trim` + minuscules pour la gravite, `trim` +
//   majuscules pour le type ; valeur brute gardee dans la branche inconnue) ;
// - quatre booleens → `Set<UserProfile>` ;
// - ISO 8601 → `DateTime` UTC ;
// - lien vide → `null` ;
// - `\r\n` → `\n` dans `nom`, `thematique` et `description`. AUCUN `trim` des
//   textes : ce sont les mots du prefet, cites (BR-014) — espaces de fin et
//   tirets de liste compris.
//
// Un champ optionnel (`dateFinValidite`, `cheminFichier`,
// `cheminFichierArreteCadre`) absent ou `null` est une absence ; PRESENT mais
// mal type ou illisible, c'est une rupture de structure : le lire comme une
// absence ferait dire a l'ecran « la source ne le fournit pas », ce qui
// serait faux.
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// Convertit le corps decode de `GET /zones?lat=&lon=` en [ZonesAtPoint].
///
/// [point] est le point interroge (celui de la requete) ; [retrievedAt],
/// l'instant ou la source a repondu, en UTC. Un tableau vide rend une
/// reponse sans zone — un resultat valide, pas un echec (`BR-007`).
///
/// Leve [ReponseIllisible] pour TOUTE la reponse des qu'un champ
/// obligatoire manque ou est mal type dans une seule zone (AR-2).
ZonesAtPoint mapZones(
  Object? json, {
  required GeoPoint point,
  required DateTime retrievedAt,
}) {
  if (json is! List<Object?>) {
    throw ReponseIllisible(
      'racine : un tableau est attendu, recu ${_describe(json)}',
    );
  }
  final List<AlertZone> zones = <AlertZone>[
    for (int index = 0; index < json.length; index++)
      _zone(json[index], 'zones[$index]'),
  ];
  return ZonesAtPoint(point: point, retrievedAt: retrievedAt, zones: zones);
}

AlertZone _zone(Object? raw, String path) {
  final Map<String, Object?> zone = _object(raw, path);
  final Object? usages = zone['usages'];
  if (usages is! List<Object?>) {
    throw ReponseIllisible(
      '$path.usages : un tableau est attendu, recu ${_describe(usages)}',
    );
  }
  return AlertZone(
    name: _citedText(zone, 'nom', path),
    kind: _zoneKind(zone['type']),
    severity: _severity(zone['niveauGravite']),
    decree: _decree(zone['arrete'], '$path.arrete'),
    usages: <RestrictedUsage>[
      for (int index = 0; index < usages.length; index++)
        _usage(usages[index], '$path.usages[$index]'),
    ],
  );
}

RestrictionDecree _decree(Object? raw, String path) {
  final Map<String, Object?> decree = _object(raw, path);
  final DateTime? validFrom = _optionalDate(decree, 'dateDebutValidite', path);
  if (validFrom == null) {
    throw ReponseIllisible('$path.dateDebutValidite : absente');
  }
  return RestrictionDecree(
    validFrom: validFrom,
    validUntil: _optionalDate(decree, 'dateFinValidite', path),
    document: _optionalLink(decree, 'cheminFichier', path),
    frameworkDocument: _optionalLink(decree, 'cheminFichierArreteCadre', path),
  );
}

RestrictedUsage _usage(Object? raw, String path) {
  final Map<String, Object?> usage = _object(raw, path);
  return RestrictedUsage(
    name: _citedText(usage, 'nom', path),
    theme: _citedText(usage, 'thematique', path),
    description: _citedText(usage, 'description', path),
    concernedProfiles: <UserProfile>{
      if (_flag(usage, 'concerneParticulier', path)) UserProfile.particulier,
      if (_flag(usage, 'concerneExploitation', path)) UserProfile.exploitation,
      if (_flag(usage, 'concerneCollectivite', path)) UserProfile.collectivite,
      if (_flag(usage, 'concerneEntreprise', path)) UserProfile.entreprise,
    },
  );
}

DroughtSeverity _severity(Object? raw) {
  final String? value = _nomenclatureValue(raw);
  return switch (value?.trim().toLowerCase()) {
    'vigilance' => const Vigilance(),
    'alerte' => const Alerte(),
    'alerte_renforcee' => const AlerteRenforcee(),
    'crise' => const Crise(),
    _ => GraviteInconnue(value),
  };
}

ZoneKind _zoneKind(Object? raw) {
  final String? value = _nomenclatureValue(raw);
  return switch (value?.trim().toUpperCase()) {
    'SUP' => const EauxSuperficielles(),
    'SOU' => const EauxSouterraines(),
    'AEP' => const EauPotable(),
    _ => TypeZoneInconnu(value),
  };
}

/// Valeur brute d'une nomenclature : jamais un echec (BR-011). Une valeur
/// non textuelle est gardee sous sa forme ecrite, pour la branche inconnue.
String? _nomenclatureValue(Object? raw) => switch (raw) {
  null => null,
  final String text => text,
  _ => '$raw',
};

Map<String, Object?> _object(Object? raw, String path) {
  if (raw is! Map<String, Object?>) {
    throw ReponseIllisible(
      '$path : un objet est attendu, recu ${_describe(raw)}',
    );
  }
  return raw;
}

/// Texte cite (BR-014) : seule la fin de ligne `\r\n` est normalisee.
String _citedText(Map<String, Object?> object, String key, String path) {
  final Object? value = object[key];
  if (value is! String) {
    throw ReponseIllisible(
      '$path.$key : un texte est attendu, recu ${_describe(value)}',
    );
  }
  return value.replaceAll('\r\n', '\n');
}

bool _flag(Map<String, Object?> object, String key, String path) {
  final Object? value = object[key];
  if (value is! bool) {
    throw ReponseIllisible(
      '$path.$key : un booleen est attendu, recu ${_describe(value)}',
    );
  }
  return value;
}

/// Date ISO 8601, rendue en UTC. Absente ou `null` : `null`. Une date sans
/// fuseau est lue comme deja en UTC, jamais en heure locale du poste : les
/// dates de validite sont des dates calendaires (conception T2 § 2.5).
DateTime? _optionalDate(Map<String, Object?> object, String key, String path) {
  final Object? value = object[key];
  if (value == null) {
    return null;
  }
  final DateTime? parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw ReponseIllisible(
      '$path.$key : une date ISO 8601 est attendue, recu ${_describe(value)}',
    );
  }
  if (parsed.isUtc) {
    return parsed;
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

/// Lien de document, garde tel que recu (ni decode ni repare). Absent,
/// `null` ou vide : `null`.
DocumentLink? _optionalLink(
  Map<String, Object?> object,
  String key,
  String path,
) {
  final Object? value = object[key];
  if (value == null || value == '') {
    return null;
  }
  if (value is! String) {
    throw ReponseIllisible(
      '$path.$key : un texte est attendu, recu ${_describe(value)}',
    );
  }
  return DocumentLink(value);
}

/// Description courte d'une valeur recue, pour le diagnostic (jamais
/// affiche a l'usager).
String _describe(Object? value) => switch (value) {
  null => 'null',
  String() => 'le texte « $value »',
  _ => 'un ${value.runtimeType}',
};
