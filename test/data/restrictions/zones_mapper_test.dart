// Verrouille `mapZones`, seul point de conversion entre une reponse de
// `/zones` et le domaine (conception T2 § 4.4).
//
// Tous les cas partent des fixtures REELLES de `test/fixtures/vigieau/`,
// capturees le 2026-09-27 (`test/fixtures/CAPTURES.md`). Aucune fixture n'est
// fabriquee : les cas illisibles et les valeurs de nomenclature jamais vues
// en reponse `/zones` (`alerte_renforcee`, O4 ; un type inedit) sont des
// VARIANTES EN MEMOIRE de la fixture d'Ariege, un seul champ modifie par
// cas, dans une seule zone — le reste de la reponse reste la reponse reelle.
//
// Tout ou rien (AR-2) : un champ obligatoire manquant ou mal type dans UNE
// zone rend TOUTE la reponse illisible — aucune zone lisible n'est rendue a
// cote d'une zone perdue.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/restrictions/zones_mapper.dart';
import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/restriction_source.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

const String _ain = 'zones_ain_bourg-en-bresse_sans_profil_2026-09-27.json';
const String _ariege = 'zones_ariege_foix_crise_2026-09-27.json';
const String _paris = 'zones_paris_vigilance_2026-09-27.json';
const String _collectiviteAccentue =
    'zones_ain_bourg-en-bresse_profil_collectivite_accentue_2026-09-27.json';

/// Les neuf fixtures `200` non vides (conception T2 § 2.5, comptage du
/// 2026-09-27).
const List<String> _nonEmptyFixtures = <String>[
  _ain,
  'zones_ain_bourg-en-bresse_profil_particulier_2026-09-27.json',
  'zones_ain_bourg-en-bresse_profil_exploitation_2026-09-27.json',
  'zones_ain_bourg-en-bresse_profil_entreprise_2026-09-27.json',
  _collectiviteAccentue,
  'zones_ain_bourg-en-bresse_profil_collectivite_sans_accent_2026-09-27.json',
  'zones_corse_ajaccio_2026-09-27.json',
  _paris,
  _ariege,
];

/// Decode une fixture reelle — une nouvelle copie a chaque appel : une
/// variante modifiee ne contamine pas le cas suivant.
Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/vigieau/$name').readAsStringSync());

/// La fixture d'Ariege, en liste de zones modifiables.
List<Map<String, dynamic>> _ariegeZones() =>
    (_fixture(_ariege)! as List<dynamic>).cast<Map<String, dynamic>>();

Map<String, dynamic> _arrete(Map<String, dynamic> zone) =>
    zone['arrete'] as Map<String, dynamic>;

Map<String, dynamic> _firstUsage(Map<String, dynamic> zone) =>
    (zone['usages'] as List<dynamic>).first as Map<String, dynamic>;

final GeoPoint _point = GeoPoint(latitude: 42.9648, longitude: 1.6052);
final DateTime _retrievedAt = DateTime.utc(2026, 9, 27, 11, 26, 31);

ZonesAtPoint _map(Object? json) =>
    mapZones(json, point: _point, retrievedAt: _retrievedAt);

/// Variante d'Ariege : [mutate] recoit la zone d'indice [zoneIndex] (0 :
/// `AEP`, 1 : `SUP`) et la modifie ; l'autre zone reste celle de la
/// fixture.
ZonesAtPoint _mapAriegeVariant(
  void Function(Map<String, dynamic> zone) mutate, {
  int zoneIndex = 1,
}) {
  final List<Map<String, dynamic>> zones = _ariegeZones();
  mutate(zones[zoneIndex]);
  return _map(zones);
}

Matcher get _illisible => throwsA(isA<ReponseIllisible>());

void main() {
  group('mapZones — fixtures reelles', () {
    test('les neuf fixtures 200 non vides se lisent, avec un arrete-cadre '
        'sur chaque zone', () {
      for (final String name in _nonEmptyFixtures) {
        final ZonesAtPoint result = _map(_fixture(name));

        expect(result.zones, isNotEmpty, reason: name);
        for (final AlertZone zone in result.zones) {
          expect(zone.decree.frameworkDocument, isNotNull, reason: name);
          expect(zone.decree.document, isNotNull, reason: name);
        }
      }
    });

    test('les textes ne perdent que leurs \\r\\n, rien d autre (BR-014), '
        'et les profils suivent les quatre booleens — sur les neuf '
        'fixtures', () {
      for (final String name in _nonEmptyFixtures) {
        final List<dynamic> raw = _fixture(name)! as List<dynamic>;
        final ZonesAtPoint result = _map(raw);

        expect(result.zones, hasLength(raw.length), reason: name);
        for (int z = 0; z < raw.length; z++) {
          final Map<String, dynamic> rawZone = raw[z] as Map<String, dynamic>;
          final AlertZone zone = result.zones[z];
          expect(
            zone.name,
            (rawZone['nom'] as String).replaceAll('\r\n', '\n'),
            reason: name,
          );
          final List<dynamic> rawUsages = rawZone['usages'] as List<dynamic>;
          expect(zone.usages, hasLength(rawUsages.length), reason: name);
          for (int u = 0; u < rawUsages.length; u++) {
            final Map<String, dynamic> rawUsage =
                rawUsages[u] as Map<String, dynamic>;
            final RestrictedUsage usage = zone.usages[u];
            String cleaned(String key) =>
                (rawUsage[key] as String).replaceAll('\r\n', '\n');
            expect(usage.name, cleaned('nom'), reason: name);
            expect(usage.theme, cleaned('thematique'), reason: name);
            expect(usage.description, cleaned('description'), reason: name);
            expect(usage.description, isNot(contains('\r')), reason: name);
            expect(usage.concernedProfiles, <UserProfile>{
              if (rawUsage['concerneParticulier'] == true)
                UserProfile.particulier,
              if (rawUsage['concerneExploitation'] == true)
                UserProfile.exploitation,
              if (rawUsage['concerneCollectivite'] == true)
                UserProfile.collectivite,
              if (rawUsage['concerneEntreprise'] == true)
                UserProfile.entreprise,
            }, reason: name);
          }
        }
      }
    });

    test('Ain sans profil : SOU, SUP, AEP dans l ordre de la source', () {
      final ZonesAtPoint result = _map(_fixture(_ain));

      expect(result.zones.map((AlertZone z) => z.kind), <ZoneKind>[
        const EauxSouterraines(),
        const EauxSuperficielles(),
        const EauPotable(),
      ]);
      expect(result.zones.map((AlertZone z) => z.severity), <DroughtSeverity>[
        const Vigilance(),
        const Alerte(),
        const Alerte(),
      ]);
      expect(result.zones.map((AlertZone z) => z.usages.length), <int>[
        45,
        27,
        19,
      ]);

      final RestrictionDecree sou = result.zones.first.decree;
      expect(sou.validFrom, DateTime.utc(2026, 8, 20));
      expect(sou.validFrom.isUtc, isTrue);
      expect(sou.validUntil, DateTime.utc(2026, 10, 31));
      expect(sou.validUntil!.isUtc, isTrue);
    });

    test('Ariege : AEP (code null, sans effet) puis SUP, toutes deux en '
        'crise depuis le 2026-09-21', () {
      final ZonesAtPoint result = _map(_fixture(_ariege));

      expect(result.zones.map((AlertZone z) => z.kind), <ZoneKind>[
        const EauPotable(),
        const EauxSuperficielles(),
      ]);
      for (final AlertZone zone in result.zones) {
        expect(zone.severity, const Crise());
        expect(zone.decree.validFrom, DateTime.utc(2026, 9, 21));
      }
      expect(result.zones.first.name, 'UDI_crise');
    });

    test('Ariege : le \\r\\n de la description devient \\n, et rien '
        'd autre', () {
      final ZonesAtPoint result = _map(_fixture(_ariege));

      for (final AlertZone zone in result.zones) {
        final RestrictedUsage lavage = zone.usages.firstWhere(
          (RestrictedUsage u) =>
              u.name ==
              'Lavage de véhicules et engins nautiques par les professionnels',
        );
        expect(
          lavage.description,
          'Interdiction totale sauf impératif sanitaire\n'
          ' + Affichage obligatoire de l’arrêté de restriction en vigueur',
        );
      }
    });

    test('Ariege : ni trim ni retouche — espaces de fin gardes', () {
      final AlertZone aep = _map(_fixture(_ariege)).zones.first;
      final RestrictedUsage fontaines = aep.usages.first;

      expect(fontaines.description, 'Interdiction totale ');
      expect(
        fontaines.name,
        "Alimentation des fontaines d'ornement en circuit ouvert "
        '(publiques et privées) ',
      );
    });

    test('Paris : trois zones en vigilance, meme nom, lien a encodage abime '
        'garde a l identique', () {
      final List<dynamic> raw = _fixture(_paris)! as List<dynamic>;
      final ZonesAtPoint result = _map(raw);

      expect(result.zones, hasLength(3));
      for (int z = 0; z < 3; z++) {
        final AlertZone zone = result.zones[z];
        expect(zone.severity, const Vigilance());
        expect(zone.name, 'Bassins de la Marne et de la Seine');
        expect(zone.decree.document!.raw, contains('sign%C3%83%C2%A9'));
        expect(
          zone.decree.document!.raw,
          _arrete(raw[z] as Map<String, dynamic>)['cheminFichier'],
        );
      }
    });

    test('profil collectivite accentue : usages vides sur les trois zones, '
        'reponse valide', () {
      final ZonesAtPoint result = _map(_fixture(_collectiviteAccentue));

      expect(result.zones, hasLength(3));
      for (final AlertZone zone in result.zones) {
        expect(zone.usages, isEmpty);
      }
    });

    test('Guyane et Atlantique : aucune zone, point et date conserves', () {
      for (final String name in <String>[
        'zones_guyane_aucune_zone_2026-09-27.json',
        'zones_atlantique_hors_france_2026-09-27.json',
      ]) {
        final ZonesAtPoint result = _map(_fixture(name));

        expect(result.zones, isEmpty, reason: name);
        expect(result.point, _point, reason: name);
        expect(result.retrievedAt, _retrievedAt, reason: name);
      }
    });

    test('point et retrievedAt sont ceux passes, pas ceux de la reponse', () {
      final ZonesAtPoint result = _map(_fixture(_ain));

      expect(result.point, _point);
      expect(result.retrievedAt, _retrievedAt);
    });
  });

  group('mapZones — tolerance de nomenclature (BR-011), variantes en '
      'memoire de la fixture d Ariege', () {
    DroughtSeverity severityOf(Object? value) => _mapAriegeVariant(
      (Map<String, dynamic> zone) => zone['niveauGravite'] = value,
    ).zones[1].severity;

    ZoneKind kindOf(Object? value) =>
        _mapAriegeVariant((Map<String, dynamic> zone) => zone['type'] = value)
            .zones[1]
            .kind;

    test('gravite inedite → GraviteInconnue, valeur brute gardee', () {
      expect(severityOf('extreme'), const GraviteInconnue('extreme'));
      expect(severityOf(' Extreme '), const GraviteInconnue(' Extreme '));
    });

    test('gravite null ou absente → GraviteInconnue(null)', () {
      expect(severityOf(null), const GraviteInconnue(null));
      expect(
        _mapAriegeVariant(
          (Map<String, dynamic> zone) => zone.remove('niveauGravite'),
        ).zones[1].severity,
        const GraviteInconnue(null),
      );
    });

    test('gravite apres trim et minuscules', () {
      expect(severityOf(' CRISE '), const Crise());
      expect(severityOf('Vigilance'), const Vigilance());
      expect(severityOf('alerte'), const Alerte());
    });

    test('alerte_renforcee → AlerteRenforcee (O4 : couverte par une valeur, '
        'aucune reponse /zones ne l a portee)', () {
      expect(severityOf('alerte_renforcee'), const AlerteRenforcee());
    });

    test('type inedit → TypeZoneInconnu, en fin des autres zones', () {
      final ZonesAtPoint result = _mapAriegeVariant(
        (Map<String, dynamic> zone) => zone['type'] = 'xyz',
      );

      expect(result.zones[1].kind, const TypeZoneInconnu('xyz'));
      expect(result.surfaceWaterZones, isEmpty);
      expect(result.otherZones.map((AlertZone z) => z.kind), <ZoneKind>[
        const EauPotable(),
        const TypeZoneInconnu('xyz'),
      ]);
    });

    test('type apres trim et majuscules', () {
      expect(kindOf('sup'), const EauxSuperficielles());
      expect(kindOf(' sou '), const EauxSouterraines());
      expect(kindOf('Aep'), const EauPotable());
    });

    test('type null ou absent → TypeZoneInconnu(null)', () {
      expect(kindOf(null), const TypeZoneInconnu(null));
      expect(
        _mapAriegeVariant((Map<String, dynamic> zone) => zone.remove('type'))
            .zones[1]
            .kind,
        const TypeZoneInconnu(null),
      );
    });

    test('type non textuel → TypeZoneInconnu, jamais un echec', () {
      expect(kindOf(42), const TypeZoneInconnu('42'));
    });

    test('champs supplementaires ignores, sur la zone, l arrete et '
        'l usage', () {
      final ZonesAtPoint original = _map(_ariegeZones());
      final ZonesAtPoint withExtras = _mapAriegeVariant((
        Map<String, dynamic> zone,
      ) {
        zone['champInedit'] = <String, Object?>{'a': 1};
        _arrete(zone)['autreChamp'] = 'x';
        _firstUsage(zone)['concerneAutreProfil'] = true;
      });

      expect(withExtras, original);
    });
  });

  group('mapZones — champs optionnels, variantes d Ariege', () {
    test('cheminFichier vide ou null → aucun document', () {
      for (final Object? value in <Object?>['', null]) {
        final AlertZone zone = _mapAriegeVariant(
          (Map<String, dynamic> zone) => _arrete(zone)['cheminFichier'] = value,
        ).zones[1];
        expect(zone.decree.document, isNull, reason: '$value');
        expect(zone.decree.frameworkDocument, isNotNull);
      }
    });

    test('cheminFichierArreteCadre vide ou absent → aucun arrete-cadre', () {
      expect(
        _mapAriegeVariant(
          (Map<String, dynamic> zone) =>
              _arrete(zone)['cheminFichierArreteCadre'] = '',
        ).zones[1].decree.frameworkDocument,
        isNull,
      );
      expect(
        _mapAriegeVariant(
          (Map<String, dynamic> zone) =>
              _arrete(zone).remove('cheminFichierArreteCadre'),
        ).zones[1].decree.frameworkDocument,
        isNull,
      );
    });

    test('dateFinValidite null ou absente → validUntil null, rien '
        'd invente', () {
      expect(
        _mapAriegeVariant(
          (Map<String, dynamic> zone) =>
              _arrete(zone)['dateFinValidite'] = null,
        ).zones[1].decree.validUntil,
        isNull,
      );
      expect(
        _mapAriegeVariant(
          (Map<String, dynamic> zone) =>
              _arrete(zone).remove('dateFinValidite'),
        ).zones[1].decree.validUntil,
        isNull,
      );
    });

    test('une heure non nulle garde la date UTC (O5)', () {
      final DateTime validFrom = _mapAriegeVariant(
        (Map<String, dynamic> zone) =>
            _arrete(zone)['dateDebutValidite'] = '2026-09-21T13:30:00.000Z',
      ).zones[1].decree.validFrom;

      expect(validFrom, DateTime.utc(2026, 9, 21, 13, 30));
      expect(validFrom.isUtc, isTrue);
    });

    test('une date sans fuseau est lue en UTC, jamais en heure locale', () {
      final DateTime validFrom = _mapAriegeVariant(
        (Map<String, dynamic> zone) =>
            _arrete(zone)['dateDebutValidite'] = '2026-09-21T00:00:00',
      ).zones[1].decree.validFrom;

      expect(validFrom, DateTime.utc(2026, 9, 21));
    });

    // Les cas ci-dessous sont des chaines ECRITES dans le test : aucune
    // reponse reelle de VigiEau n'a jamais porte un decalage explicite (la
    // seule forme constatee est `...Z`, `test/fixtures/CAPTURES.md`). Une
    // date de validite est une date calendaire : on la garde TELLE QU'ECRITE,
    // jamais convertie de fuseau (conception T2 § 2.5, arbitrage du
    // 2026-10-06). `DateTime.parse` accepte, en suffixe de fuseau, `Z`/`z`
    // ou un decalage signe `±HH`, `±HHMM`, `±HH:MM`, chacun eventuellement
    // precede d'une espace (SDK, `date_time.dart`).
    DateTime validFromWrittenAs(Object? written) => _mapAriegeVariant(
      (Map<String, dynamic> zone) =>
          _arrete(zone)['dateDebutValidite'] = written,
    ).zones[1].decree.validFrom;

    test('un decalage positif garde la date ecrite : minuit +02:00 reste le '
        '20, pas le 19', () {
      final DateTime validFrom = validFromWrittenAs(
        '2026-08-20T00:00:00+02:00',
      );

      expect(validFrom, DateTime.utc(2026, 8, 20));
      expect(validFrom.isUtc, isTrue);
    });

    test('un decalage explicite ne decale pas l heure : 02:00 +02:00 reste '
        '02:00', () {
      expect(
        validFromWrittenAs('2026-08-20T02:00:00+02:00'),
        DateTime.utc(2026, 8, 20, 2),
      );
    });

    test('un decalage negatif garde la date ecrite : 23:30 -05:00 reste le '
        '20, pas le 21', () {
      final DateTime validFrom = validFromWrittenAs(
        '2026-08-20T23:30:00-05:00',
      );

      expect(validFrom, DateTime.utc(2026, 8, 20, 23, 30));
      expect(validFrom.isUtc, isTrue);
    });

    test('toutes les ecritures de decalage que DateTime.parse accepte gardent '
        'les composantes de la chaine', () {
      final Map<String, DateTime> written = <String, DateTime>{
        '2026-08-20T00:00:00+0200': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00+02': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00 +02:00': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00+05:30': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00+00:00': DateTime.utc(2026, 8, 20),
        '2026-08-20T23:30:00-0500': DateTime.utc(2026, 8, 20, 23, 30),
        '2026-08-20T23:30:00-05': DateTime.utc(2026, 8, 20, 23, 30),
        '2026-08-20T23:30:00 -05:00': DateTime.utc(2026, 8, 20, 23, 30),
        '2026-08-20 02:00:00+02:00': DateTime.utc(2026, 8, 20, 2),
        '2026-08-20T02:00+02:00': DateTime.utc(2026, 8, 20, 2),
        '2026-08-20T02+02:00': DateTime.utc(2026, 8, 20, 2),
        '20260820T020000+0200': DateTime.utc(2026, 8, 20, 2),
        '2026-08-20T02:00:00.123+02:00': DateTime.utc(
          2026,
          8,
          20,
          2,
          0,
          0,
          123,
        ),
      };
      for (final MapEntry<String, DateTime> entry in written.entries) {
        expect(validFromWrittenAs(entry.key), entry.value, reason: entry.key);
      }
    });

    test('la forme en Z, la seule constatee dans une reponse reelle, garde '
        'ses composantes', () {
      final Map<String, DateTime> written = <String, DateTime>{
        '2026-08-20T00:00:00.000Z': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00Z': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00z': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00 Z': DateTime.utc(2026, 8, 20),
        '2026-08-20T23:30:00Z': DateTime.utc(2026, 8, 20, 23, 30),
      };
      for (final MapEntry<String, DateTime> entry in written.entries) {
        final DateTime validFrom = validFromWrittenAs(entry.key);

        expect(validFrom, entry.value, reason: entry.key);
        expect(validFrom.isUtc, isTrue, reason: entry.key);
      }
    });

    test('une date sans fuseau, avec ou sans heure, garde ses composantes', () {
      final Map<String, DateTime> written = <String, DateTime>{
        '2026-08-20': DateTime.utc(2026, 8, 20),
        '20260820': DateTime.utc(2026, 8, 20),
        '2026-08-20T00:00:00': DateTime.utc(2026, 8, 20),
        '2026-08-20T23:30:00': DateTime.utc(2026, 8, 20, 23, 30),
        '2026-08-20 23:30': DateTime.utc(2026, 8, 20, 23, 30),
      };
      for (final MapEntry<String, DateTime> entry in written.entries) {
        final DateTime validFrom = validFromWrittenAs(entry.key);

        expect(validFrom, entry.value, reason: entry.key);
        expect(validFrom.isUtc, isTrue, reason: entry.key);
      }
    });

    test('dateFinValidite suit la meme regle que dateDebutValidite', () {
      final DateTime? validUntil = _mapAriegeVariant(
        (Map<String, dynamic> zone) =>
            _arrete(zone)['dateFinValidite'] = '2026-10-31T00:00:00+02:00',
      ).zones[1].decree.validUntil;

      expect(validUntil, DateTime.utc(2026, 10, 31));
    });

    test('une chaine qui n est pas une date reste illisible, decalage '
        'compris', () {
      for (final String written in <String>[
        'pas une date',
        '',
        '2026-08-20+02:00', // un fuseau sans heure : refuse par DateTime.parse
        '2026-08-20T00:00:00+2:00',
        '2026-08-20T00:00:00+02:00 pas une date',
      ]) {
        expect(() => validFromWrittenAs(written), _illisible, reason: written);
      }
    });
  });

  group('mapZones — tout ou rien (AR-2) : un seul champ casse dans une '
      'seule zone rend toute la reponse illisible', () {
    test('racine objet', () {
      expect(
        () => _map(<String, Object?>{'zones': _ariegeZones()}),
        _illisible,
      );
    });

    test('racine null ou texte', () {
      expect(() => _map(null), _illisible);
      expect(() => _map('[]'), _illisible);
    });

    test('element non objet', () {
      final List<Object?> zones = <Object?>[..._ariegeZones(), 42];
      expect(() => _map(zones), _illisible);
    });

    test('zone sans nom, ou nom non textuel', () {
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z.remove('nom')),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z['nom'] = null),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z['nom'] = 4),
        _illisible,
      );
    });

    test('zone sans arrete, ou arrete non objet', () {
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z.remove('arrete')),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z['arrete'] = null),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z['arrete'] = 'x'),
        _illisible,
      );
    });

    test('dateDebutValidite absente, null, non textuelle ou illisible', () {
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) => _arrete(z).remove('dateDebutValidite'),
        ),
        _illisible,
      );
      for (final Object? value in <Object?>[null, 20260921, 'pas une date']) {
        expect(
          () => _mapAriegeVariant(
            (Map<String, dynamic> z) => _arrete(z)['dateDebutValidite'] = value,
          ),
          _illisible,
          reason: '$value',
        );
      }
    });

    test('dateFinValidite presente mais illisible : pas une absence', () {
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) =>
              _arrete(z)['dateFinValidite'] = 'pas une date',
        ),
        _illisible,
      );
    });

    test('lien d arrete present mais non textuel', () {
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) => _arrete(z)['cheminFichier'] = 42,
        ),
        _illisible,
      );
    });

    test('usages absent, null ou non liste', () {
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z.remove('usages')),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant((Map<String, dynamic> z) => z['usages'] = null),
        _illisible,
      );
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) => z['usages'] = <String, Object?>{},
        ),
        _illisible,
      );
    });

    test('usage non objet', () {
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) => (z['usages'] as List<dynamic>).add('x'),
        ),
        _illisible,
      );
    });

    test('usage sans nom, thematique ou description', () {
      for (final String key in <String>['nom', 'thematique', 'description']) {
        expect(
          () => _mapAriegeVariant(
            (Map<String, dynamic> z) => _firstUsage(z).remove(key),
          ),
          _illisible,
          reason: key,
        );
      }
    });

    test('chacun des quatre concerne* absent', () {
      for (final String key in <String>[
        'concerneParticulier',
        'concerneExploitation',
        'concerneCollectivite',
        'concerneEntreprise',
      ]) {
        expect(
          () => _mapAriegeVariant(
            (Map<String, dynamic> z) => _firstUsage(z).remove(key),
          ),
          _illisible,
          reason: key,
        );
      }
    });

    test('concerneParticulier en chaine "true", ou null', () {
      for (final Object? value in <Object?>['true', null, 1]) {
        expect(
          () => _mapAriegeVariant(
            (Map<String, dynamic> z) =>
                _firstUsage(z)['concerneParticulier'] = value,
          ),
          _illisible,
          reason: '$value',
        );
      }
    });

    test('la zone cassee peut etre la premiere : aucune zone n est rendue '
        'seule', () {
      expect(
        () => _mapAriegeVariant(
          (Map<String, dynamic> z) => z.remove('nom'),
          zoneIndex: 0,
        ),
        _illisible,
      );
    });
  });
}
