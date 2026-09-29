// Verrouille la nomenclature des types de zone d'alerte : trois types connus
// (eaux superficielles, eaux souterraines, eau potable) et une branche
// inconnue qui porte la valeur brute (BR-011). Libelles fixes par la
// conception d'ecran (C1, Q-5a) et ajoutes par E2 : `zoneKindLabel`.
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

  group('zoneKindLabel — libelles de C1 (Q-5a), mot pour mot', () {
    test('les trois types connus', () {
      expect(zoneKindLabel(const EauxSuperficielles()), 'Eaux superficielles');
      expect(zoneKindLabel(const EauxSouterraines()), 'Eaux souterraines');
      expect(zoneKindLabel(const EauPotable()), 'Eau potable');
    });

    test('type inconnu : libelle fixe, la valeur brute n est pas affichee', () {
      expect(
        zoneKindLabel(const TypeZoneInconnu('XYZ')),
        'Type de zone non renseigné',
      );
      expect(
        zoneKindLabel(const TypeZoneInconnu(null)),
        'Type de zone non renseigné',
      );
      expect(
        zoneKindLabel(const TypeZoneInconnu('XYZ')),
        isNot(contains('XYZ')),
      );
    });
  });

  test('aucun rang expose ici', () {
    final String source = File('lib/domain/restrictions/zone_kind.dart')
        .readAsStringSync();

    expect(
      source,
      isNot(matches(RegExp(r'compareTo|Comparable|\brank|\bindex\b'))),
    );
  });
}
