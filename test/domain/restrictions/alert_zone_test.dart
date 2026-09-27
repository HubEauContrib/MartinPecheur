// Verrouille DocumentLink, RestrictionDecree, RestrictedUsage et AlertZone
// (conception T2 § 2.4-2.6) : lien d'arrete affiche tel que recu, jamais
// decode ni repare (BR-014) ; usages non modifiables, filtres par profil
// dans l'ordre de la source, sans tri ni dedoublonnage ; dates de validite
// en UTC exclusivement (BR-001).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';

DateTime _utc(int year, int month, int day) => DateTime.utc(year, month, day);

RestrictionDecree _decree({DateTime? validFrom}) =>
    RestrictionDecree(validFrom: validFrom ?? _utc(2026, 6, 25));

void main() {
  group('DocumentLink.openableUri — seulement une URL absolue http/https', () {
    test('une URL https absolue est ouvrable', () {
      const DocumentLink lien = DocumentLink(
        'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/37008/'
        'AP-75Vigilance-Zone1_0623_sign%C3%83%C2%A9.pdf',
      );

      expect(lien.openableUri, isNotNull);
    });

    test('une URL http absolue est ouvrable', () {
      const DocumentLink lien = DocumentLink('http://exemple.test/arrete.pdf');

      expect(lien.openableUri, isNotNull);
    });

    test('un chemin relatif n est pas ouvrable', () {
      expect(const DocumentLink('arrete.pdf').openableUri, isNull);
    });

    test('un schema non http n est pas ouvrable', () {
      expect(const DocumentLink('ftp://h/a.pdf').openableUri, isNull);
    });

    test('javascript: n est pas ouvrable', () {
      expect(const DocumentLink('javascript:alert(1)').openableUri, isNull);
    });

    test('une chaine vide n est pas ouvrable', () {
      expect(const DocumentLink('').openableUri, isNull);
    });

    test('un http(s) absolu sans hote n est pas ouvrable', () {
      expect(const DocumentLink('https:foo').openableUri, isNull);
    });

    test('lien de Paris : raw inchange, rien n est decode ni repare', () {
      const String brut =
          'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/'
          '37008/AP-75Vigilance-Zone1_0623_sign%C3%83%C2%A9.pdf';
      const DocumentLink lien = DocumentLink(brut);

      expect(lien.raw, brut);
      expect(lien.openableUri!.toString(), contains('%C3%83%C2%A9'));
    });
  });

  group('RestrictedUsage', () {
    test('concerns() lit concernedProfiles', () {
      final RestrictedUsage usage = RestrictedUsage(
        name: 'Arrosage des golfs',
        theme: 'Arroser',
        description: 'Interdiction totale',
        concernedProfiles: const <UserProfile>{
          UserProfile.particulier,
          UserProfile.entreprise,
        },
      );

      expect(usage.concerns(UserProfile.particulier), isTrue);
      expect(usage.concerns(UserProfile.exploitation), isFalse);
    });

    test('concernedProfiles n est pas modifiable', () {
      final RestrictedUsage usage = RestrictedUsage(
        name: 'x',
        theme: 'y',
        description: 'z',
        concernedProfiles: const <UserProfile>{UserProfile.particulier},
      );

      expect(
        () => usage.concernedProfiles.add(UserProfile.entreprise),
        throwsUnsupportedError,
      );
    });
  });

  group(
    'AlertZone.usagesFor — ordre de la source, sans tri ni dedoublonnage',
    () {
      test(
        'rend les usages qui concernent le profil, dans l ordre de la source',
        () {
          final RestrictedUsage golf = RestrictedUsage(
            name: 'Arrosage des golfs',
            theme: 'Arroser',
            description: 'Interdit',
            concernedProfiles: const <UserProfile>{UserProfile.particulier},
          );
          final RestrictedUsage abreuvement = RestrictedUsage(
            name: 'Abreuvement des animaux',
            theme: 'Abreuver',
            description: 'Autorise',
            concernedProfiles: const <UserProfile>{UserProfile.exploitation},
          );
          final RestrictedUsage doublon = RestrictedUsage(
            name: 'Arrosage des golfs',
            theme: 'Arroser',
            description: 'Interdit',
            concernedProfiles: const <UserProfile>{UserProfile.particulier},
          );
          final AlertZone zone = AlertZone(
            name: 'Zone 3',
            kind: const EauxSuperficielles(),
            severity: const Alerte(),
            decree: _decree(),
            usages: <RestrictedUsage>[golf, abreuvement, doublon],
          );

          expect(zone.usagesFor(UserProfile.particulier), <RestrictedUsage>[
            golf,
            doublon,
          ]);
        },
      );

      test('une liste d usages vide est valide', () {
        final AlertZone zone = AlertZone(
          name: 'Zone vide',
          kind: const EauPotable(),
          severity: const Vigilance(),
          decree: _decree(),
          usages: const <RestrictedUsage>[],
        );

        expect(zone.usages, isEmpty);
        expect(zone.usagesFor(UserProfile.particulier), isEmpty);
      });

      test('usages n est pas modifiable', () {
        final AlertZone zone = AlertZone(
          name: 'Zone',
          kind: const EauPotable(),
          severity: const Vigilance(),
          decree: _decree(),
          usages: const <RestrictedUsage>[],
        );

        expect(
          () => zone.usages.add(
            RestrictedUsage(
              name: 'x',
              theme: 'y',
              description: 'z',
              concernedProfiles: const <UserProfile>{},
            ),
          ),
          throwsUnsupportedError,
        );
      });
    },
  );

  group('RestrictionDecree — dates de validite en UTC exclusivement', () {
    test('validFrom local leve ArgumentError', () {
      expect(
        () => RestrictionDecree(validFrom: DateTime(2026, 6, 25)),
        throwsArgumentError,
      );
    });

    test('validUntil local leve ArgumentError', () {
      expect(
        () => RestrictionDecree(
          validFrom: _utc(2026, 6, 25),
          validUntil: DateTime(2026, 10, 31),
        ),
        throwsArgumentError,
      );
    });

    test('validFrom et validUntil en UTC se construisent sans lever', () {
      final RestrictionDecree arrete = RestrictionDecree(
        validFrom: _utc(2026, 6, 25),
        validUntil: _utc(2026, 10, 31),
      );

      expect(arrete.validFrom, _utc(2026, 6, 25));
      expect(arrete.validUntil, _utc(2026, 10, 31));
    });

    test('validUntil, document et frameworkDocument sont optionnels', () {
      final RestrictionDecree arrete = RestrictionDecree(
        validFrom: _utc(2026, 6, 25),
      );

      expect(arrete.validUntil, isNull);
      expect(arrete.document, isNull);
      expect(arrete.frameworkDocument, isNull);
    });
  });

  group('Egalite structurelle', () {
    RestrictedUsage usage({
      String name = 'x',
      Set<UserProfile> concernedProfiles = const <UserProfile>{
        UserProfile.particulier,
      },
    }) => RestrictedUsage(
      name: name,
      theme: 'y',
      description: 'z',
      concernedProfiles: concernedProfiles,
    );
    AlertZone zone({
      List<RestrictedUsage>? usages,
      RestrictionDecree? decree,
    }) => AlertZone(
      name: 'Zone 3',
      kind: const EauxSuperficielles(),
      severity: const Alerte(),
      decree: decree ?? _decree(),
      usages: usages ?? <RestrictedUsage>[usage()],
    );

    test('deux AlertZone aux memes champs sont egales', () {
      expect(zone(), zone());
      expect(zone().hashCode, zone().hashCode);
    });

    test(
      'deux AlertZone dont l ordre des usages differe ne sont pas egales',
      () {
        final RestrictedUsage golf = usage(name: 'golf');
        final RestrictedUsage jardin = usage(name: 'jardin');

        final AlertZone a = zone(usages: <RestrictedUsage>[golf, jardin]);
        final AlertZone b = zone(usages: <RestrictedUsage>[jardin, golf]);

        expect(a, isNot(b));
      },
    );

    test('deux AlertZone dont un usage a des profils differents ne sont pas egales', () {
      final AlertZone a = zone(
        usages: <RestrictedUsage>[
          usage(
            concernedProfiles: const <UserProfile>{UserProfile.particulier},
          ),
        ],
      );
      final AlertZone b = zone(
        usages: <RestrictedUsage>[
          usage(concernedProfiles: const <UserProfile>{UserProfile.entreprise}),
        ],
      );

      expect(a, isNot(b));
    });

    test('deux AlertZone dont l arrete a un validUntil different ne sont pas egales', () {
      final RestrictionDecree sansFin = RestrictionDecree(
        validFrom: _utc(2026, 6, 25),
      );
      final RestrictionDecree avecFin = RestrictionDecree(
        validFrom: _utc(2026, 6, 25),
        validUntil: _utc(2026, 10, 31),
      );

      expect(zone(decree: sansFin), isNot(zone(decree: avecFin)));
      expect(sansFin, isNot(avecFin));
    });

    test('deux DocumentLink au meme raw sont egaux', () {
      expect(const DocumentLink('a.pdf'), const DocumentLink('a.pdf'));
      expect(const DocumentLink('a.pdf'), isNot(const DocumentLink('b.pdf')));
    });
  });
}
