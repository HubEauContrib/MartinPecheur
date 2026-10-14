// Verrouille DecreeDocument : les documents distincts cites par les zones
// d'un point (dedoublonnage par adresse EXACTE et par role), l'arrete-cadre
// aux memes zones que l'unique arrete de restriction, et les dates de
// validite partagees. Conditions transcrites de la vue des restrictions
// (R1 de T3) : l'identite des zones se compare par `identical`.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/decree_documents.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

const String _d = 'https://exemple.test/arretes/d.pdf';
const String _e = 'https://exemple.test/arretes/e.pdf';
const String _f = 'https://exemple.test/cadres/f.pdf';
const String _g = 'https://exemple.test/cadres/g.pdf';

AlertZone _zone(
  String name, {
  String? doc,
  String? cadre,
  DateTime? validFrom,
  DateTime? validUntil,
}) => AlertZone(
  name: name,
  kind: const EauxSuperficielles(),
  severity: const Alerte(),
  decree: RestrictionDecree(
    validFrom: validFrom ?? DateTime.utc(2026, 8, 20),
    validUntil: validUntil,
    document: doc == null ? null : DocumentLink(doc),
    frameworkDocument: cadre == null ? null : DocumentLink(cadre),
  ),
  usages: const <RestrictedUsage>[],
);

/// Vrai si [actual] porte exactement les instances de [expected], dans
/// l'ordre.
void _expectSameZones(List<AlertZone> actual, List<AlertZone> expected) {
  expect(actual, hasLength(expected.length));
  for (int i = 0; i < expected.length; i++) {
    expect(actual[i], same(expected[i]), reason: 'zone de rang $i');
  }
}

void _expectDocument(
  DecreeDocument document, {
  required bool isFramework,
  required String raw,
  required List<AlertZone> zones,
}) {
  expect(document.isFramework, isFramework, reason: 'role de $raw');
  expect(document.link.raw, raw);
  _expectSameZones(document.zones, zones);
}

DecreeDocument _only(List<DecreeDocument> all, {required bool isFramework}) =>
    all.singleWhere((DecreeDocument d) => d.isFramework == isFramework);

void main() {
  group('decreeDocumentsOf', () {
    test('aucune zone : aucun document', () {
      expect(decreeDocumentsOf(<AlertZone>[]), isEmpty);
    });

    test('une zone, un arrete et un cadre : deux documents, l arrete '
        'd abord', () {
      final AlertZone z = _zone('z', doc: _d, cadre: _f);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: _d, zones: [z]);
      _expectDocument(all[1], isFramework: true, raw: _f, zones: [z]);
    });

    test('trois zones de meme arrete et de meme cadre : deux documents, les '
        'trois zones dans l ordre passe', () {
      final AlertZone ainSou = _zone('Ain souterraines', doc: _d, cadre: _f);
      final AlertZone ainSup = _zone('Ain superficielles', doc: _d, cadre: _f);
      final AlertZone ainAep = _zone('Ain eau potable', doc: _d, cadre: _f);
      final List<AlertZone> zones = <AlertZone>[ainSou, ainSup, ainAep];

      final List<DecreeDocument> all = decreeDocumentsOf(zones);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: _d, zones: zones);
      _expectDocument(all[1], isFramework: true, raw: _f, zones: zones);
    });

    test('restrictions d abord, puis cadres, chacun dans l ordre de premiere '
        'citation', () {
      final AlertZone z1 = _zone('z1', doc: _e, cadre: _f);
      final AlertZone z2 = _zone('z2', doc: _d, cadre: _g);
      final AlertZone z3 = _zone('z3', doc: _e, cadre: _g);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        z1,
        z2,
        z3,
      ]);

      expect(all, hasLength(4));
      _expectDocument(all[0], isFramework: false, raw: _e, zones: [z1, z3]);
      _expectDocument(all[1], isFramework: false, raw: _d, zones: [z2]);
      _expectDocument(all[2], isFramework: true, raw: _f, zones: [z1]);
      _expectDocument(all[3], isFramework: true, raw: _g, zones: [z2, z3]);
    });

    test('deux adresses qui ne different que par la casse : deux '
        'documents', () {
      const String lower = 'https://exemple.test/arretes/a.pdf';
      const String upper = 'https://exemple.test/arretes/A.pdf';
      final AlertZone z1 = _zone('z1', doc: lower);
      final AlertZone z2 = _zone('z2', doc: upper);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z1, z2]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: lower, zones: [z1]);
      _expectDocument(all[1], isFramework: false, raw: upper, zones: [z2]);
    });

    test('deux adresses qui ne different que d une espace finale : deux '
        'documents', () {
      const String bare = 'https://exemple.test/arretes/a.pdf';
      const String spaced = 'https://exemple.test/arretes/a.pdf ';
      final AlertZone z1 = _zone('z1', doc: bare);
      final AlertZone z2 = _zone('z2', doc: spaced);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z1, z2]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: bare, zones: [z1]);
      _expectDocument(all[1], isFramework: false, raw: spaced, zones: [z2]);
    });

    test('une zone sans arrete mais avec un cadre : un seul document, le '
        'cadre', () {
      final AlertZone z = _zone('z', cadre: _f);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z]);

      expect(all, hasLength(1));
      _expectDocument(all[0], isFramework: true, raw: _f, zones: [z]);
    });

    test('une zone sans arrete ni cadre : aucun document', () {
      expect(decreeDocumentsOf(<AlertZone>[_zone('z')]), isEmpty);
    });

    test('la meme adresse citee comme arrete par une zone et comme cadre par '
        'une autre : deux documents de roles differents', () {
      final AlertZone z1 = _zone('z1', doc: _d);
      final AlertZone z2 = _zone('z2', cadre: _d);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z1, z2]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: _d, zones: [z1]);
      _expectDocument(all[1], isFramework: true, raw: _d, zones: [z2]);
    });

    test('la meme adresse citee par la meme zone pour les deux roles : deux '
        'documents de roles differents', () {
      final AlertZone z = _zone('z', doc: _d, cadre: _d);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: _d, zones: [z]);
      _expectDocument(all[1], isFramework: true, raw: _d, zones: [z]);
    });

    test('les zones d un document ne sont pas modifiables', () {
      final AlertZone z = _zone('z', doc: _d, cadre: _f);
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z]);

      expect(() => all[0].zones.add(_zone('x')), throwsUnsupportedError);
      expect(() => all[1].zones.add(_zone('x')), throwsUnsupportedError);
    });

    test('la liste rendue n est pas modifiable', () {
      final AlertZone z = _zone('z', doc: _d, cadre: _f);
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[z]);

      expect(() => all.add(all.first), throwsUnsupportedError);
      expect(
        () => decreeDocumentsOf(<AlertZone>[]).addAll(all),
        throwsUnsupportedError,
      );
    });
  });

  group('DecreeDocument.sharedValidity', () {
    final DateTime from = DateTime.utc(2026, 8, 20);
    final DateTime until = DateTime.utc(2026, 10, 31);

    DecreeDocument restrictionOf(List<AlertZone> zones) =>
        _only(decreeDocumentsOf(zones), isFramework: false);

    test('une zone datee du 2026-08-20 au 2026-10-31 : ce couple', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z', doc: _d, validFrom: from, validUntil: until),
      ]);

      expect(document.sharedValidity, (validFrom: from, validUntil: until));
    });

    test('une zone sans date de fin : le debut, et null', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z', doc: _d, validFrom: from),
      ]);

      expect(document.sharedValidity, (validFrom: from, validUntil: null));
    });

    test('deux zones aux memes dates : le couple', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z1', doc: _d, validFrom: from, validUntil: until),
        _zone('z2', doc: _d, validFrom: from, validUntil: until),
      ]);

      expect(document.sharedValidity, (validFrom: from, validUntil: until));
    });

    test('deux zones aux debuts differents : null', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z1', doc: _d, validFrom: from, validUntil: until),
        _zone(
          'z2',
          doc: _d,
          validFrom: from.add(const Duration(days: 1)),
          validUntil: until,
        ),
      ]);

      expect(document.sharedValidity, isNull);
    });

    test('une fin nulle et l autre non : null', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z1', doc: _d, validFrom: from),
        _zone('z2', doc: _d, validFrom: from, validUntil: until),
      ]);

      expect(document.sharedValidity, isNull);
    });

    test('la premiere fin datee, la seconde nulle : null', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z1', doc: _d, validFrom: from, validUntil: until),
        _zone('z2', doc: _d, validFrom: from),
      ]);

      expect(document.sharedValidity, isNull);
    });

    test('deux fins nulles et meme debut : le debut, et null', () {
      final DecreeDocument document = restrictionOf(<AlertZone>[
        _zone('z1', doc: _d, validFrom: from),
        _zone('z2', doc: _d, validFrom: from),
      ]);

      expect(document.sharedValidity, (validFrom: from, validUntil: null));
    });
  });

  group('coversSameZonesAsSoleRestrictionDecree', () {
    test('un arrete de restriction : faux', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z', doc: _d, cadre: _f),
      ]);

      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: false),
          all,
        ),
        isFalse,
      );
    });

    test('une zone, un arrete et un cadre : vrai pour le cadre', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z', doc: _d, cadre: _f),
      ]);

      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: true),
          all,
        ),
        isTrue,
      );
    });

    test('trois zones de meme arrete et de meme cadre : vrai pour le '
        'cadre', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('Ain souterraines', doc: _d, cadre: _f),
        _zone('Ain superficielles', doc: _d, cadre: _f),
        _zone('Ain eau potable', doc: _d, cadre: _f),
      ]);

      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: true),
          all,
        ),
        isTrue,
      );
    });

    test('deux arretes de restriction : faux pour chaque cadre', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z1', doc: _e, cadre: _f),
        _zone('z2', doc: _d, cadre: _g),
        _zone('z3', doc: _e, cadre: _g),
      ]);
      final List<DecreeDocument> cadres = all
          .where((DecreeDocument d) => d.isFramework)
          .toList();

      expect(cadres.map((DecreeDocument d) => d.link.raw), <String>[_f, _g]);
      expect(coversSameZonesAsSoleRestrictionDecree(cadres[0], all), isFalse);
      expect(coversSameZonesAsSoleRestrictionDecree(cadres[1], all), isFalse);
    });

    test('aucun arrete de restriction : faux', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z', cadre: _f),
      ]);

      expect(coversSameZonesAsSoleRestrictionDecree(all.single, all), isFalse);
    });

    test('un seul arrete de restriction, le cadre cite moins de zones : '
        'faux', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z1', doc: _d, cadre: _f),
        _zone('z2', doc: _d),
      ]);

      expect(_only(all, isFramework: false).zones, hasLength(2));
      expect(_only(all, isFramework: true).zones, hasLength(1));
      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: true),
          all,
        ),
        isFalse,
      );
    });

    test('un seul arrete de restriction, le cadre cite plus de zones : '
        'faux', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z1', doc: _d, cadre: _f),
        _zone('z2', cadre: _f),
      ]);

      expect(_only(all, isFramework: false).zones, hasLength(1));
      expect(_only(all, isFramework: true).zones, hasLength(2));
      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: true),
          all,
        ),
        isFalse,
      );
    });

    test('un seul arrete de restriction, meme nombre de zones mais zones '
        'differentes : faux', () {
      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[
        _zone('z1', doc: _d),
        _zone('z2', cadre: _f),
      ]);

      expect(_only(all, isFramework: false).zones, hasLength(1));
      expect(_only(all, isFramework: true).zones, hasLength(1));
      expect(
        coversSameZonesAsSoleRestrictionDecree(
          _only(all, isFramework: true),
          all,
        ),
        isFalse,
      );
    });

    test('deux zones structurellement egales, instances distinctes, meme '
        'arrete et meme cadre : chacune gardee, et vrai pour le cadre', () {
      final AlertZone a = _zone('jumelle', doc: _d, cadre: _f);
      final AlertZone b = _zone('jumelle', doc: _d, cadre: _f);
      expect(a, b);
      expect(identical(a, b), isFalse);

      final List<DecreeDocument> all = decreeDocumentsOf(<AlertZone>[a, b]);

      expect(all, hasLength(2));
      _expectDocument(all[0], isFramework: false, raw: _d, zones: [a, b]);
      _expectDocument(all[1], isFramework: true, raw: _f, zones: [a, b]);
      expect(coversSameZonesAsSoleRestrictionDecree(all[1], all), isTrue);
    });
  });
}
