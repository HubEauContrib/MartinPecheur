// Zones de test de l'ecran des restrictions (E2 de T2). Les tests de vue ne
// lisent PAS `lib/data/` : ces `ZonesAtPoint` sont construits a la main,
// avec des valeurs RECOPIEES des fixtures capturees le 2026-09-27
// (`test/fixtures/vigieau/`, `test/fixtures/CAPTURES.md`) — noms de zone,
// niveaux, dates de validite, adresses d'arrete, et un SOUS-ENSEMBLE des
// usages (nom, thematique, description et profils concernes recopies tels
// quels, dans l'ordre de la source).
//
// Les echantillons « synthetiques » (gravite ou type inconnu, zone sans
// arrete, adresse non ouvrable) partent d'une zone recopiee et n'en changent
// QU'UN champ, dit dans leur commentaire : aucune fixture ne porte ces cas.

import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

// --- Ain, Bourg-en-Bresse : /zones?lat=46.2&lon=5.226, 11:25:24 UTC -------

/// Point de la fixture de l'Ain (`zones_ain_bourg-en-bresse_sans_profil_…`).
GeoPoint pointAin() => GeoPoint(latitude: 46.2, longitude: 5.226);

/// Instant de capture de la fixture de l'Ain (`CAPTURES.md`).
final DateTime retrievedAtAin = DateTime.utc(2026, 9, 27, 11, 25, 24);

/// `arrete.cheminFichier` des trois zones de l'Ain (identique, K-3).
const String decreeUrlAin =
    'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/37846/'
    '4b41a716-ee95-4651-a961-73bab4e58109/'
    '20260820ApSecheresseRaaCompletLight.pdf';

/// `arrete.cheminFichierArreteCadre` des trois zones de l'Ain.
const String frameworkUrlAin =
    'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-cadre/30660/'
    '20260303ACSdSansAnnexesSigneRaaAvecAnnexe_Compress.pdf';

RestrictionDecree decreeAin() => RestrictionDecree(
  validFrom: DateTime.utc(2026, 8, 20),
  validUntil: DateTime.utc(2026, 10, 31),
  document: const DocumentLink(decreeUrlAin),
  frameworkDocument: const DocumentLink(frameworkUrlAin),
);

/// Premier usage des trois zones de l'Ain dans la reponse (zone SUP/AEP).
RestrictedUsage abreuvementSup() => RestrictedUsage(
  name: 'Abreuvement des animaux',
  theme: 'Abreuver',
  description: 'Pas de limitation, sauf arrêté spécifique.',
  concernedProfiles: <UserProfile>{UserProfile.exploitation},
);

RestrictedUsage fontainesSup() => RestrictedUsage(
  name: 'Alimentation des fontaines publiques et privées d’ornement',
  theme: 'Alimenter des fontaines et autres usages de loisirs',
  description:
      'Interdit si techniquement possible. Interdiction de prélèvement sauf '
      'abreuvement des animaux.',
  concernedProfiles: <UserProfile>{
    UserProfile.entreprise,
    UserProfile.particulier,
    UserProfile.collectivite,
  },
);

RestrictedUsage equestresSup() => RestrictedUsage(
  name: 'Arrosage des centres équestres et carrières équestres',
  theme: 'Arroser',
  description: 'Interdiction de 10h à 18h.',
  concernedProfiles: <UserProfile>{
    UserProfile.entreprise,
    UserProfile.particulier,
    UserProfile.collectivite,
    UserProfile.exploitation,
  },
);

/// Zone `SUP` de l'Ain : « Rivières de Bresse », alerte.
AlertZone ainSup() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauxSuperficielles(),
  severity: const Alerte(),
  decree: decreeAin(),
  usages: <RestrictedUsage>[abreuvementSup(), fontainesSup(), equestresSup()],
);

/// Zone `SOU` de l'Ain : « Dombes - Certines - Nord », vigilance — son seul
/// usage recopie ne concerne que l'exploitation.
AlertZone ainSou() => AlertZone(
  name: 'Dombes - Certines - Nord',
  kind: const EauxSouterraines(),
  severity: const Vigilance(),
  decree: decreeAin(),
  usages: <RestrictedUsage>[
    RestrictedUsage(
      name: 'Abreuvement des animaux',
      theme: 'Abreuver',
      description: 'Prévenir les agriculteurs',
      concernedProfiles: <UserProfile>{UserProfile.exploitation},
    ),
  ],
);

/// Zone `AEP` de l'Ain : « Rivières de Bresse », alerte.
AlertZone ainAep() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauPotable(),
  severity: const Alerte(),
  decree: decreeAin(),
  usages: <RestrictedUsage>[abreuvementSup(), equestresSup()],
);

/// Les trois zones de l'Ain, dans l'ordre de la source (SOU, SUP, AEP).
ZonesAtPoint zonesAin() => ZonesAtPoint(
  point: pointAin(),
  retrievedAt: retrievedAtAin,
  zones: <AlertZone>[ainSou(), ainSup(), ainAep()],
);

// --- Paris : /zones?lat=48.8566&lon=2.3522, 11:26:07 UTC ------------------

GeoPoint pointParis() => GeoPoint(latitude: 48.8566, longitude: 2.3522);

/// Adresse de la fixture de Paris, encodage abime compris (`sign%C3%83%C2%A9`,
/// BR-014 : jamais « repare »).
const String decreeUrlParis =
    'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/37008/'
    'AP-75Vigilance-Zone1_0623_sign%C3%83%C2%A9.pdf';

const String frameworkUrlParis =
    'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-cadre/30555/'
    'ACI_PPC_2024_sign%C3%83%C2%A9_VF.pdf';

AlertZone _paris(ZoneKind kind) => AlertZone(
  name: 'Bassins de la Marne et de la Seine',
  kind: kind,
  severity: const Vigilance(),
  decree: RestrictionDecree(
    validFrom: DateTime.utc(2026, 6, 25),
    validUntil: DateTime.utc(2026, 10, 31),
    document: const DocumentLink(decreeUrlParis),
    frameworkDocument: const DocumentLink(frameworkUrlParis),
  ),
  usages: <RestrictedUsage>[
    RestrictedUsage(
      name: 'Alimentation des fontaines publiques et privées d’ornement',
      theme: 'Alimenter des fontaines et autres usages de loisirs',
      description:
          'En raison de la situation hydrologique, il est demandé à tous '
          "d'avoir un usage économe et responsable de l'eau.",
      concernedProfiles: <UserProfile>{
        UserProfile.entreprise,
        UserProfile.particulier,
        UserProfile.collectivite,
      },
    ),
  ],
);

/// Les trois zones de Paris (SUP, AEP, SOU), meme arrete et meme
/// arrete-cadre pour les trois (K-3).
ZonesAtPoint zonesParis() => ZonesAtPoint(
  point: pointParis(),
  retrievedAt: DateTime.utc(2026, 9, 27, 11, 26, 7),
  zones: <AlertZone>[
    _paris(const EauxSuperficielles()),
    _paris(const EauPotable()),
    _paris(const EauxSouterraines()),
  ],
);

// --- Ariege, Foix : /zones?lat=42.9648&lon=1.6052, 11:26:31 UTC ------------

GeoPoint pointAriege() => GeoPoint(latitude: 42.9648, longitude: 1.6052);

/// Description recopiee a l'identique : `\n` interne et espace de fin.
const String descriptionIrrigationAriege =
    '- Interdiction de tous les prélèvements \n'
    "- Toute mesure d'anticipation éventuellement proposée par l'OUGC";

/// Zone `SUP` de l'Ariege, crise, avec deux usages dont les chaines portent
/// un espace de fin (`nom` et `description`).
AlertZone ariegeSup() => AlertZone(
  name: "Zone d'alerte n°4.3_Les affluents de l'Ariège aval",
  kind: const EauxSuperficielles(),
  severity: const Crise(),
  decree: RestrictionDecree(
    validFrom: DateTime.utc(2026, 9, 21),
    validUntil: DateTime.utc(2026, 10, 31),
    document: const DocumentLink(
      'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-restriction/38114/'
      'a52c0020-b0b7-428a-b0bc-06f4d36aa23c/'
      '20260918_AP_secheresse_DDT-SER-2026-078.pdf',
    ),
    frameworkDocument: const DocumentLink(
      'https://regleau.s3.gra.perf.cloud.ovh.net/arrete-cadre/30849/'
      '20260710_ACI_secheresse_DDT-SER-2026-058.pdf',
    ),
  ),
  usages: <RestrictedUsage>[
    RestrictedUsage(
      name:
          "Alimentation des fontaines d'ornement en circuit ouvert "
          '(publiques et privées) ',
      theme: 'Alimenter des fontaines et autres usages de loisirs',
      description: 'Interdiction totale ',
      concernedProfiles: <UserProfile>{
        UserProfile.entreprise,
        UserProfile.particulier,
        UserProfile.collectivite,
        UserProfile.exploitation,
      },
    ),
    RestrictedUsage(
      name: 'Irrigation agricole des cultures (sauf retenues déconnectées) ',
      theme: 'Irriguer',
      description: descriptionIrrigationAriege,
      concernedProfiles: <UserProfile>{UserProfile.exploitation},
    ),
  ],
);

ZonesAtPoint zonesAriege() => ZonesAtPoint(
  point: pointAriege(),
  retrievedAt: DateTime.utc(2026, 9, 27, 11, 26, 31),
  zones: <AlertZone>[ariegeSup()],
);

// --- Guyane : /zones?lat=4.9&lon=-52.3, 11:26:03 UTC, reponse `[]` ---------

GeoPoint pointGuyane() => GeoPoint(latitude: 4.9, longitude: -52.3);

final DateTime retrievedAtGuyane = DateTime.utc(2026, 9, 27, 11, 26, 3);

// --- Synthetiques : une zone recopiee, UN champ change -------------------

/// [ainSup] dont la gravite est inconnue (`niveauGravite` absent) — aucune
/// fixture ne porte ce cas.
AlertZone ainSupGraviteInconnue() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauxSuperficielles(),
  severity: const GraviteInconnue(null),
  decree: decreeAin(),
  usages: <RestrictedUsage>[abreuvementSup()],
);

/// [ainAep] dont le type est inconnu (`type` = `XYZ`) — aucune fixture.
AlertZone ainTypeInconnu() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const TypeZoneInconnu('XYZ'),
  severity: const Alerte(),
  decree: decreeAin(),
  usages: const <RestrictedUsage>[],
);

/// [ainSup] sans `cheminFichier` ni arrete-cadre — aucune fixture.
AlertZone ainSupSansArrete() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauxSuperficielles(),
  severity: const Alerte(),
  decree: RestrictionDecree(
    validFrom: DateTime.utc(2026, 8, 20),
    validUntil: DateTime.utc(2026, 10, 31),
  ),
  usages: <RestrictedUsage>[equestresSup()],
);

/// [ainSup] sans date de fin (`dateFinValidite` absente) — aucune fixture.
AlertZone ainSupSansDateDeFin() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauxSuperficielles(),
  severity: const Alerte(),
  decree: RestrictionDecree(
    validFrom: DateTime.utc(2026, 8, 20),
    document: const DocumentLink(decreeUrlAin),
  ),
  usages: <RestrictedUsage>[equestresSup()],
);

/// Adresse relative, sans schema ni hote : `openableUri` nul — aucune
/// fixture.
const String relativeDecreeUrl = 'arrete-restriction/37846/arrete.pdf';

/// [ainSup] dont l'arrete a une adresse non ouvrable — aucune fixture.
AlertZone ainSupAdresseNonOuvrable() => AlertZone(
  name: 'Rivières de Bresse',
  kind: const EauxSuperficielles(),
  severity: const Alerte(),
  decree: RestrictionDecree(
    validFrom: DateTime.utc(2026, 8, 20),
    validUntil: DateTime.utc(2026, 10, 31),
    document: const DocumentLink(relativeDecreeUrl),
  ),
  usages: <RestrictedUsage>[equestresSup()],
);

/// Des zones de l'Ain, au point et a l'instant de sa fixture.
ZonesAtPoint zonesAinWith(List<AlertZone> zones) =>
    ZonesAtPoint(point: pointAin(), retrievedAt: retrievedAtAin, zones: zones);
