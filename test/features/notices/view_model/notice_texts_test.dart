// Les textes des avis reçus (N1 de T5), en Dart pur : un cas par ligne du
// cadrage § 11.2 et de PD12, le texte entier comparé. Les niveaux 2 à 4 et un
// changement d'arrêté n'ont jamais été observés en production (VC-04) : ce
// sont des cas construits dans ce fichier.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';
import 'package:martinpecheur/domain/follow_up/follow_up.dart';
import 'package:martinpecheur/domain/follow_up/received_notice.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/domain/restrictions/zone_kind.dart';
import 'package:martinpecheur/features/notices/view_model/notice_texts.dart';

import '../../../project/vocabulary_lists.dart';

/// Heure d'été fixe : +2 h, pour que le résultat ne dépende pas du fuseau de
/// la machine.
Duration _plusTwoHours(DateTime utcInstant) => const Duration(hours: 2);

final DateTime _info = DateTime.utc(2026, 10, 14, 13, 55);
final DateTime _received = DateTime.utc(2026, 10, 14, 14, 2);
final DateTime _decree = DateTime.utc(2026, 10, 2);

final RegExp _instructionVerbs = RegExp(
  r'(?<!\p{L})(arrosez|arroser|baignez|baignade possible|naviguez|'
  r'traversez|pouvez arroser|pouvez naviguer|pouvez vous baigner)(?!\p{L})',
  caseSensitive: false,
  unicode: true,
);

String _title(ReceivedNotice n) => noticeTitle(n);
List<String> _body(ReceivedNotice n) => noticeBody(n, offsetOf: _plusTwoHours);

FloodLevelChanged _flood(
  FloodVigilanceLevel before,
  FloodVigilanceLevel after,
) => FloodLevelChanged(
  placeLabel: 'Blavet',
  before: before,
  after: after,
  informationDate: _info,
  receivedAt: _received,
);

DroughtZoneChanged _zone({
  DroughtSeverity? before,
  DroughtSeverity? after,
  String name = 'Scorff',
  ZoneKind kind = const EauxSuperficielles(),
  DateTime? decreeValidFrom,
}) => DroughtZoneChanged(
  placeLabel: 'Station du Scorff',
  zoneName: name,
  zoneKind: kind,
  before: before,
  after: after,
  decreeValidFrom: decreeValidFrom,
  receivedAt: _received,
);

CheckImpossible _impossible(
  FollowUpSource source,
  CheckFailureCause cause,
  String label,
) => CheckImpossible(
  source: source,
  cause: cause,
  placeLabels: <String>[label],
  receivedAt: _received,
);

List<ReceivedNotice> _everyNotice() => <ReceivedNotice>[
  FloodFollowUpStarted(
    placeLabel: 'Blavet',
    level: const Orange(),
    informationDate: _info,
    threshold: FloodThreshold.orange,
    receivedAt: _received,
  ),
  FloodFollowUpStarted(
    placeLabel: 'Blavet',
    level: const NiveauCruesInconnu('9'),
    informationDate: _info,
    threshold: FloodThreshold.jaune,
    receivedAt: _received,
  ),
  DroughtFollowUpStarted(
    placeLabel: 'Station du Scorff',
    zones: <KnownZone>[
      KnownZone(
        name: 'Scorff',
        kind: const EauxSuperficielles(),
        severity: const Alerte(),
        decreeValidFrom: _decree,
      ),
    ],
    readAt: _received,
    receivedAt: _received,
  ),
  DroughtFollowUpStarted(
    placeLabel: 'Station du Scorff',
    zones: const <KnownZone>[],
    readAt: _received,
    receivedAt: _received,
  ),
  _flood(const Jaune(), const Orange()),
  _flood(const Orange(), const Vert()),
  _flood(const Jaune(), const NiveauCruesInconnu(null)),
  _flood(const NiveauCruesInconnu('x'), const Rouge()),
  _zone(
    before: const Vigilance(),
    after: const Alerte(),
    decreeValidFrom: _decree,
  ),
  _zone(after: const Crise(), decreeValidFrom: _decree),
  _zone(before: const AlerteRenforcee()),
  _zone(
    before: const Alerte(),
    after: const GraviteInconnue('?'),
    decreeValidFrom: _decree,
  ),
  for (final FollowUpSource s in FollowUpSource.values)
    for (final CheckFailureCause c in CheckFailureCause.values)
      _impossible(s, c, 'Blavet'),
  PlaceNotVerifiable(
    placeLabel: 'Blavet',
    reason: SectionAbsent(_info),
    receivedAt: _received,
  ),
  PlaceNotVerifiable(
    placeLabel: 'Blavet',
    reason: SectionMaybeUnreadable(_info),
    receivedAt: _received,
  ),
  PlaceNotVerifiable(
    placeLabel: 'Station du Scorff',
    reason: const StationAbsent(),
    receivedAt: _received,
  ),
];

void main() {
  group('constantes', () {
    test('titre de l\'écran et marque des non lus', () {
      expect(noticesScreenTitle, 'Avis reçus');
      expect(noticeNewMark, 'Nouveau');
    });

    test(
      'un avis illisible dit le texte de Q3, calqué sur celui des favoris',
      () {
        expect(
          unreadableNoticeText,
          "Avis non lisible par cette version de l'application",
        );
        const UnreadableNotice notice = UnreadableNotice(raw: '{"x":1}');
        expect(_title(notice), unreadableNoticeText);
        expect(_body(notice), isEmpty);
      },
    );
  });

  group('« Suivi commencé »', () {
    test('crues : le niveau lu, sa date, son attribution, puis le rappel', () {
      final ReceivedNotice n = FloodFollowUpStarted(
        placeLabel: 'Blavet',
        level: const Orange(),
        informationDate: _info,
        threshold: FloodThreshold.orange,
        receivedAt: _received,
      );
      expect(_title(n), 'Suivi commencé');
      expect(_body(n), <String>[
        'Blavet',
        'Vigilance orange — information de vigilance du 14/10/2026 à 15:55 '
            '— © VIGICRUES.',
        "Prévenu : vigilance crues à partir de l'orange",
      ]);
    });

    test('crues, niveau non reconnu : « Niveau de vigilance non reconnu »', () {
      final ReceivedNotice n = FloodFollowUpStarted(
        placeLabel: 'Blavet',
        level: const NiveauCruesInconnu('9'),
        informationDate: _info,
        threshold: FloodThreshold.rouge,
        receivedAt: _received,
      );
      expect(_body(n), <String>[
        'Blavet',
        'Niveau de vigilance non reconnu — information de vigilance du '
            '14/10/2026 à 15:55 — © VIGICRUES.',
        'Prévenu : vigilance crues à partir du rouge',
      ]);
    });

    test('sécheresse : une ligne par zone, gravité, type et arrêté', () {
      final ReceivedNotice n = DroughtFollowUpStarted(
        placeLabel: 'Station du Scorff',
        zones: <KnownZone>[
          KnownZone(
            name: 'Scorff',
            kind: const EauxSuperficielles(),
            severity: const Alerte(),
            decreeValidFrom: _decree,
          ),
          KnownZone(
            name: 'Nappe du Blavet',
            kind: const EauxSouterraines(),
            severity: const Vigilance(),
            decreeValidFrom: DateTime.utc(2026, 9, 20),
          ),
        ],
        readAt: _received,
        receivedAt: _received,
      );
      expect(_title(n), 'Suivi commencé');
      expect(_body(n), <String>[
        'Station du Scorff',
        'Zone « Scorff » (Eaux superficielles) : Alerte d\'après VigiEau, '
            'arrêté en vigueur depuis le 02/10/2026.',
        'Zone « Nappe du Blavet » (Eaux souterraines) : Vigilance d\'après '
            'VigiEau, arrêté en vigueur depuis le 20/09/2026.',
      ]);
    });

    test('sécheresse sans zone : le silence se dit, sans dire l\'absence', () {
      final ReceivedNotice n = DroughtFollowUpStarted(
        placeLabel: 'Station du Scorff',
        zones: const <KnownZone>[],
        readAt: _received,
        receivedAt: _received,
      );
      expect(_body(n), <String>[
        'Station du Scorff',
        "VigiEau ne cite aucune zone d'alerte à cet endroit. Cela ne dit pas "
            "qu'aucune restriction ne s'y applique.",
      ]);
    });
  });

  group('avis de crue (cas construits, jamais observés — VC-04)', () {
    test('« Vigilance crues orange » avec « Avant : vigilance jaune. »', () {
      final ReceivedNotice n = _flood(const Jaune(), const Orange());
      expect(_title(n), 'Vigilance crues orange');
      expect(_body(n), <String>[
        'Blavet',
        'Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. '
            'Avant : vigilance jaune.',
      ]);
    });

    test('les quatre adjectifs de niveau, et rien pour un niveau inconnu', () {
      expect(floodLevelAdjective(const Vert()), 'verte');
      expect(floodLevelAdjective(const Jaune()), 'jaune');
      expect(floodLevelAdjective(const Orange()), 'orange');
      expect(floodLevelAdjective(const Rouge()), 'rouge');
      expect(floodLevelAdjective(const NiveauCruesInconnu('x')), isNull);
      expect(
        _title(_flood(const Orange(), const Vert())),
        'Vigilance crues verte',
      );
      expect(
        _title(_flood(const Orange(), const Rouge())),
        'Vigilance crues rouge',
      );
    });

    test(
      'nouveau niveau non reconnu : titre, phrase de la fiche, « Avant »',
      () {
        final ReceivedNotice n = _flood(
          const Jaune(),
          const NiveauCruesInconnu(null),
        );
        expect(_title(n), 'Niveau de vigilance non reconnu');
        expect(_body(n), <String>[
          'Blavet',
          floodUnknownLevelText,
          'Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. '
              'Avant : vigilance jaune.',
        ]);
      },
    );

    test('ancien niveau non reconnu : « Avant : niveau de vigilance non '
        'reconnu. »', () {
      final ReceivedNotice n = _flood(
        const NiveauCruesInconnu('x'),
        const Rouge(),
      );
      expect(_title(n), 'Vigilance crues rouge');
      expect(_body(n), <String>[
        'Blavet',
        'Information de vigilance du 14/10/2026 à 15:55 — © VIGICRUES. '
            'Avant : niveau de vigilance non reconnu.',
      ]);
    });
  });

  group('avis de sécheresse (cas construits, jamais observés)', () {
    test('gravité changée', () {
      final ReceivedNotice n = _zone(
        before: const Vigilance(),
        after: const Alerte(),
        decreeValidFrom: _decree,
      );
      expect(_title(n), 'Restrictions sécheresse : Alerte');
      expect(_body(n), <String>[
        'Station du Scorff',
        'Zone « Scorff » (Eaux superficielles) : Alerte d\'après VigiEau, '
            'arrêté en vigueur depuis le 02/10/2026. Avant : Vigilance. '
            "L'arrêté fait foi.",
      ]);
    });

    test('zone nouvelle', () {
      final ReceivedNotice n = _zone(
        name: 'Ellé',
        after: const Crise(),
        decreeValidFrom: _decree,
      );
      expect(_title(n), 'Restrictions sécheresse : Crise');
      expect(_body(n), <String>[
        'Station du Scorff',
        'Zone « Ellé » (Eaux superficielles) : Crise d\'après VigiEau, '
            'arrêté en vigueur depuis le 02/10/2026. Avant : cette zone '
            "n'était pas citée à cet endroit. L'arrêté fait foi.",
      ]);
    });

    test('zone plus citée : la levée n\'est pas dite', () {
      final ReceivedNotice n = _zone(
        name: 'Nappe du Blavet',
        kind: const EauxSouterraines(),
        before: const Alerte(),
      );
      expect(_title(n), 'Restrictions sécheresse : zone plus citée');
      expect(_body(n), <String>[
        'Station du Scorff',
        'VigiEau ne cite plus la zone « Nappe du Blavet » (Eaux souterraines) '
            'à cet endroit. Avant : Alerte. Cela ne dit pas que les '
            "restrictions sont levées : l'arrêté fait foi.",
      ]);
    });

    test('une gravité non reconnue se dit « Non renseigné »', () {
      final ReceivedNotice n = _zone(
        before: const Alerte(),
        after: const GraviteInconnue('?'),
        decreeValidFrom: _decree,
      );
      expect(_title(n), 'Restrictions sécheresse : Non renseigné');
    });
  });

  group('« Vérification impossible » (six causes)', () {
    final Map<(FollowUpSource, CheckFailureCause), String> expected =
        <(FollowUpSource, CheckFailureCause), String>{
          (FollowUpSource.floods, CheckFailureCause.unreachable):
              "Vigicrues n'a pas répondu : aucun avis de crue n'a pu être "
              'donné pour Blavet. Cela ne dit rien du risque de crue.',
          (FollowUpSource.floods, CheckFailureCause.refused):
              "Vigicrues a refusé la demande : aucun avis de crue n'a pu être "
              'donné pour Blavet. Cela ne dit rien du risque de crue.',
          (FollowUpSource.floods, CheckFailureCause.unreadable):
              "La vigilance publiée par Vigicrues n'a pas pu être lue : aucun "
              "avis de crue n'a pu être donné pour Blavet. Cela ne dit rien "
              'du risque de crue.',
          (FollowUpSource.drought, CheckFailureCause.unreachable):
              "VigiEau n'a pas répondu : aucun avis de restrictions n'a pu "
              'être donné pour Station du Scorff. Cela ne dit rien des '
              'restrictions en vigueur.',
          (FollowUpSource.drought, CheckFailureCause.refused):
              'VigiEau a refusé la demande pour Station du Scorff : aucun '
              "avis de restrictions n'a pu être donné. Cela ne dit rien des "
              'restrictions en vigueur.',
          (FollowUpSource.drought, CheckFailureCause.unreadable):
              "La réponse de VigiEau n'a pas pu être lue pour Station du "
              "Scorff : aucun avis de restrictions n'a pu être donné. Cela ne "
              'dit rien des restrictions en vigueur.',
        };
    for (final MapEntry<(FollowUpSource, CheckFailureCause), String> e
        in expected.entries) {
      test('${e.key.$1.name} / ${e.key.$2.name}', () {
        final ReceivedNotice n = _impossible(
          e.key.$1,
          e.key.$2,
          e.key.$1 == FollowUpSource.floods ? 'Blavet' : 'Station du Scorff',
        );
        expect(_title(n), 'Vérification impossible');
        expect(_body(n), <String>[e.value]);
      });
    }

    test('plusieurs lieux : la liste se joint', () {
      final ReceivedNotice n = CheckImpossible(
        source: FollowUpSource.floods,
        cause: CheckFailureCause.unreachable,
        placeLabels: const <String>['Blavet', 'Scorff'],
        receivedAt: _received,
      );
      expect(_body(n), <String>[
        "Vigicrues n'a pas répondu : aucun avis de crue n'a pu être donné "
            'pour Blavet et Scorff. Cela ne dit rien du risque de crue.',
      ]);
    });
  });

  group('« Lieu non vérifiable » (trois raisons)', () {
    PlaceNotVerifiable notice(String label, NotVerifiableReason reason) =>
        PlaceNotVerifiable(
          placeLabel: label,
          reason: reason,
          receivedAt: _received,
        );

    test('tronçon absent de la vigilance publiée', () {
      final ReceivedNotice n = notice('Blavet', SectionAbsent(_info));
      expect(_title(n), 'Lieu non vérifiable');
      expect(_body(n), <String>[
        "Blavet : ce tronçon n'est pas dans la vigilance publiée par "
            'Vigicrues le 14/10/2026 à 15:55. Aucun avis de crue ne peut être '
            'donné pour lui.',
      ]);
    });

    test('tronçon peut-être parmi les entités illisibles', () {
      final ReceivedNotice n = notice('Blavet', SectionMaybeUnreadable(_info));
      expect(_title(n), 'Lieu non vérifiable');
      expect(_body(n), <String>[
        "Blavet : ce tronçon n'a pas pu être lu dans la vigilance publiée par "
            'Vigicrues le 14/10/2026 à 15:55. Aucun avis de crue ne peut être '
            'donné pour lui.',
      ]);
    });

    test('station absente du référentiel embarqué', () {
      final ReceivedNotice n = notice(
        'Station du Scorff',
        const StationAbsent(),
      );
      expect(_title(n), 'Lieu non vérifiable');
      expect(_body(n), <String>[
        "Station du Scorff : cette station n'est pas dans le référentiel "
            'embarqué. Aucun avis de restrictions ne peut être donné pour '
            'elle.',
      ]);
    });
  });

  group('joinPlaceLabels', () {
    test('un, deux, trois et quatre lieux', () {
      expect(joinPlaceLabels(<String>['A']), 'A');
      expect(joinPlaceLabels(<String>['A', 'B']), 'A et B');
      expect(joinPlaceLabels(<String>['A', 'B', 'C']), 'A, B et C');
      expect(joinPlaceLabels(<String>['A', 'B', 'C', 'D']), 'A, B, C et D');
    });
  });

  group('dates', () {
    test('« Reçu le » convertit l\'instant par offsetOf', () {
      final ReadableNotice n = _flood(const Jaune(), const Orange());
      expect(
        noticeReceivedLine(n, offsetOf: _plusTwoHours),
        'Reçu le 14/10/2026 à 16:02',
      );
      expect(
        noticeReceivedLine(n, offsetOf: (DateTime _) => Duration.zero),
        'Reçu le 14/10/2026 à 14:02',
      );
    });

    test('la date d\'arrêté se lit en UTC, sans conversion de fuseau', () {
      final ReceivedNotice n = _zone(
        before: const Vigilance(),
        after: const Alerte(),
        decreeValidFrom: DateTime.utc(2026, 10, 2, 23, 30),
      );
      expect(
        noticeBody(n, offsetOf: (DateTime _) => const Duration(hours: 5))[1],
        contains('arrêté en vigueur depuis le 02/10/2026.'),
      );
    });
  });

  group('vocabulaire', () {
    test(
      'aucun texte ne porte un mot proscrit, de garantie ou une consigne',
      () {
        final List<String> texts = <String>[
          noticesScreenTitle,
          noticeNewMark,
          unreadableNoticeText,
          floodUnknownLevelText,
          for (final ReceivedNotice n in _everyNotice()) ...<String>[
            _title(n),
            ..._body(n),
            if (n is ReadableNotice)
              noticeReceivedLine(n, offsetOf: _plusTwoHours)!,
          ],
        ];
        for (final String text in texts) {
          for (final String mot in <String>[
            ...forbiddenFlowWords,
            ...forbiddenGuaranteeWords,
          ]) {
            expect(
              RegExp(
                '(?<!\\p{L})${RegExp.escape(mot)}(?!\\p{L})',
                caseSensitive: false,
                unicode: true,
              ).hasMatch(text),
              isFalse,
              reason: '« $text » contient « $mot »',
            );
          }
          expect(_instructionVerbs.hasMatch(text), isFalse, reason: text);
          for (final String bannie in <String>[
            'fin de vigilance',
            'danger écarté',
            'restrictions levées',
          ]) {
            expect(text.toLowerCase(), isNot(contains(bannie)), reason: text);
          }
        }
      },
    );
  });
}
