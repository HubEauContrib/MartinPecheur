// Verrouille [FollowUpToggle] (`V2` de T5) : l'état d'affichage de
// l'interrupteur « Me prévenir des restrictions sécheresse », en Dart pur, que
// deux ViewModels de fiche produisent. Sans rendu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/follow_up_toggle.dart';

void main() {
  group('FollowUpToggle', () {
    test('writeFailed vaut false par défaut', () {
      const FollowUpToggle toggle = FollowUpToggle(on: true, enabled: true);

      expect(toggle.writeFailed, isFalse);
    });

    test('égalité par valeur sur les trois champs', () {
      const FollowUpToggle base = FollowUpToggle(
        on: true,
        enabled: true,
        writeFailed: true,
      );

      expect(
        base,
        const FollowUpToggle(on: true, enabled: true, writeFailed: true),
      );
      expect(
        base.hashCode,
        const FollowUpToggle(
          on: true,
          enabled: true,
          writeFailed: true,
        ).hashCode,
      );
      expect(
        base,
        isNot(
          const FollowUpToggle(on: false, enabled: true, writeFailed: true),
        ),
      );
      expect(
        base,
        isNot(
          const FollowUpToggle(on: true, enabled: false, writeFailed: true),
        ),
      );
      expect(
        base,
        isNot(
          const FollowUpToggle(on: true, enabled: true, writeFailed: false),
        ),
      );
    });

    test('toString nomme les trois champs', () {
      const FollowUpToggle toggle = FollowUpToggle(on: true, enabled: false);

      expect(toggle.toString(), contains('on: true'));
      expect(toggle.toString(), contains('enabled: false'));
      expect(toggle.toString(), contains('writeFailed: false'));
    });
  });

  test('le texte de l échec d écriture est celui de Q2', () {
    expect(followUpWriteFailedText, "Le réglage n'a pas pu être enregistré.");
  });

  group('follow_up_toggle.dart — Dart pur', () {
    test('le fichier ne contient aucune directive import : aucun '
        'package:flutter, un ViewModel peut donc le prendre', () {
      final String source = File('lib/features/shared/follow_up_toggle.dart')
          .readAsStringSync();

      final RegExp importDirective = RegExp(r'^\s*import\s', multiLine: true);

      expect(importDirective.hasMatch(source), isFalse);
      expect(source, isNot(contains('package:flutter')));
    });
  });
}
