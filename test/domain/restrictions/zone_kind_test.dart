// Verrouille la nomenclature des types de zone d'alerte : trois types connus
// (eaux superficielles, eaux souterraines, eau potable) et une branche
// inconnue qui porte la valeur brute (BR-011). Aucun libelle ici : ils sont
// fixes par la conception d'ecran (C1) et ajoutes par E2.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

/// `switch` exhaustif SANS `default` : une branche ajoutee a [ZoneKind] sans
/// cas ici casse la compilation (BR-011).
String _exhaustive(ZoneKind kind) => switch (kind) {
  EauxSuperficielles() => 'SUP',
  EauxSouterraines() => 'SOU',
  EauPotable() => 'AEP',
  TypeZoneInconnu() => 'inconnu',
};

void main() {
  group('ZoneKind — egalite par type pour les branches connues', () {
    test('instance non constante comprise', () {
      // ignore: prefer_const_constructors
      expect(EauxSuperficielles(), const EauxSuperficielles());
      // ignore: prefer_const_constructors
      expect(EauxSouterraines(), const EauxSouterraines());
      // ignore: prefer_const_constructors
      expect(EauPotable(), const EauPotable());
      expect(
        // ignore: prefer_const_constructors
        EauPotable().hashCode,
        const EauPotable().hashCode,
      );
    });

    test('deux types differents ne sont pas egaux', () {
      expect(const EauxSuperficielles(), isNot(const EauxSouterraines()));
      expect(const EauxSouterraines(), isNot(const EauPotable()));
      expect(const EauPotable(), isNot(const EauxSuperficielles()));
    });
  });

  group('TypeZoneInconnu — la valeur brute est portee (BR-011)', () {
    test('egalite par valeur brute', () {
      expect(const TypeZoneInconnu('X'), const TypeZoneInconnu('X'));
      expect(
        const TypeZoneInconnu('X').hashCode,
        const TypeZoneInconnu('X').hashCode,
      );
      expect(const TypeZoneInconnu('X'), isNot(const TypeZoneInconnu('x')));
      expect(const TypeZoneInconnu('SUP'), isNot(const EauxSuperficielles()));
    });

    test('null se construit sans lever', () {
      expect(() => const TypeZoneInconnu(null), returnsNormally);
      expect(const TypeZoneInconnu(null).rawValue, isNull);
    });

    test('la valeur brute est gardee telle que recue', () {
      expect(const TypeZoneInconnu(' sup ').rawValue, ' sup ');
    });
  });

  test('switch exhaustif sans default sur ZoneKind (BR-011)', () {
    expect(_exhaustive(const EauxSuperficielles()), 'SUP');
    expect(_exhaustive(const TypeZoneInconnu(null)), 'inconnu');
  });

  test('aucun libelle ni rang expose ici (libelles : C1 puis E2)', () {
    final String source = File('lib/domain/restrictions/zone_kind.dart')
        .readAsStringSync();

    expect(source, isNot(contains('zoneKindLabel')));
    expect(
      source,
      isNot(matches(RegExp(r'compareTo|Comparable|\brank|\bindex\b'))),
    );
  });
}
