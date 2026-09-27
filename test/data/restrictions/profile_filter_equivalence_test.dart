// Verrouille l'equivalence AR-1 (conception T2 § 10.1, obligatoire) : sur la
// fixture de l'Ain, le filtrage cote domaine (`AlertZone.usagesFor`) rend,
// zone par zone (appariees par type — une seule zone par type sur ce point),
// exactement les memes usages (nom, thematique, description), DANS L'ORDRE,
// que ceux que le serveur rend en filtrant lui-meme par profil. Pour
// `collectivite`, la reference est la fixture SANS accent : `collectivité`
// accentue, la valeur du schema, rend zero usage (piege documente au § 1 et
// § 2.7 de la conception).
//
// ⚠️ Si ce test est rouge : ARRET. Ne pas ajuster ce test ni le filtrage du
// domaine — question fermee au commanditaire (retour possible au filtrage
// serveur, conception T2 § 8, alternative A1).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/zones_mapper.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

const String _sansProfil =
    'zones_ain_bourg-en-bresse_sans_profil_2026-09-27.json';

final GeoPoint _point = GeoPoint(latitude: 46.2044, longitude: 5.2258);
final DateTime _retrievedAt = DateTime.utc(2026, 9, 27, 12, 0, 0);

Object? _fixtureJson(String name) =>
    jsonDecode(File('test/fixtures/vigieau/$name').readAsStringSync());

ZonesAtPoint _mapFixture(String name) =>
    mapZones(_fixtureJson(name), point: _point, retrievedAt: _retrievedAt);

/// Cle de type stable pour apparier deux zones du meme point : sur la
/// fixture de l'Ain, `SUP`/`SOU`/`AEP` ne se repetent pas (une zone par
/// type).
String _typeKey(AlertZone zone) => switch (zone.kind) {
  EauxSuperficielles() => 'SUP',
  EauxSouterraines() => 'SOU',
  EauPotable() => 'AEP',
  TypeZoneInconnu() => 'INCONNU',
};

List<(String, String, String)> _projection(List<RestrictedUsage> usages) =>
    <(String, String, String)>[
      for (final RestrictedUsage usage in usages)
        (usage.name, usage.theme, usage.description),
    ];

void _verifieEquivalence(UserProfile profil, String fixtureReference) {
  final ZonesAtPoint sansProfil = _mapFixture(_sansProfil);
  final ZonesAtPoint reference = _mapFixture(fixtureReference);

  expect(
    sansProfil.zones.map(_typeKey).toSet(),
    reference.zones.map(_typeKey).toSet(),
    reason: 'les deux reponses doivent porter les memes zones, par type',
  );
  expect(
    sansProfil.zones.length,
    reference.zones.length,
    reason:
        'meme nombre de zones : un type en double dans une des deux '
        'fixtures romprait l appariement (ecraserait une zone) sans que '
        'la comparaison des ensembles de types seule le voie',
  );
  expect(
    sansProfil.zones.map(_typeKey).toSet().length,
    sansProfil.zones.length,
    reason:
        'aucun type en double dans la fixture sans profil : chaque '
        'type y identifie une seule zone',
  );
  expect(
    reference.zones.map(_typeKey).toSet().length,
    reference.zones.length,
    reason:
        'aucun type en double dans la fixture de reference : chaque '
        'type y identifie une seule zone',
  );

  final Map<String, AlertZone> referenceParType = <String, AlertZone>{
    for (final AlertZone zone in reference.zones) _typeKey(zone): zone,
  };

  for (final AlertZone zoneSansProfil in sansProfil.zones) {
    final String cle = _typeKey(zoneSansProfil);
    final AlertZone zoneReference = referenceParType[cle]!;
    expect(
      _projection(zoneSansProfil.usagesFor(profil)),
      _projection(zoneReference.usages),
      reason: 'zone $cle, profil $profil',
    );
  }
}

void main() {
  group('Equivalence du filtrage par profil (AR-1, obligatoire)', () {
    test('particulier', () {
      _verifieEquivalence(
        UserProfile.particulier,
        'zones_ain_bourg-en-bresse_profil_particulier_2026-09-27.json',
      );
    });

    test('exploitation', () {
      _verifieEquivalence(
        UserProfile.exploitation,
        'zones_ain_bourg-en-bresse_profil_exploitation_2026-09-27.json',
      );
    });

    test('entreprise', () {
      _verifieEquivalence(
        UserProfile.entreprise,
        'zones_ain_bourg-en-bresse_profil_entreprise_2026-09-27.json',
      );
    });

    test('collectivite (reference : fixture sans accent)', () {
      _verifieEquivalence(
        UserProfile.collectivite,
        'zones_ain_bourg-en-bresse_profil_collectivite_sans_accent_2026-09-27.json',
      );
    });
  });
}
