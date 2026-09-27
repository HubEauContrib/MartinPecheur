// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// Vérifie que le gabarit Windows pose une taille minimale de fenêtre
// (décision 8 du plan T1, tâche K3) : sous 800 × 700, la colonne
// « contrôle « ⚠ Avertissement » + légende » (`04-ui.md § 3`) n'a plus la
// place de tenir sans chevauchement — ce n'est plus un bandeau qui se
// tronque (amendement `W3c` du 2026-09-23), mais l'exigence de ne rien faire
// se recouvrir reste posée par la même contrainte de fenêtre.
//
// Amendement du commanditaire, 2026-09-23 : 600 → 700. À 800 × 600, la
// légende de l'échelle débit (phrase `BR-003`) recouvrait les contrôles de
// zoom — chiffres mesurés dans
// `test/features/map/view/map_view_test.dart` (test « RAISON DE
// L'AMENDEMENT »).
//
// Ce test LIT le fichier C++ (`windows/runner/win32_window.cpp`), il ne
// compile ni n'exécute rien — le bac à sable ne construit pas de natif.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Retire les commentaires `//` (une ligne, comme tout ce fichier C++ en
/// écrit) : sans ce nettoyage, une mutation qui retire l'APPEL réel
/// survivrait tant que le commentaire qui LE DÉCRIT en langage naturel reste
/// au-dessus — un `contains` sur le texte brut ne verrait pas la
/// différence. Relecture du coordinateur du 2026-09-23 : trois mutations
/// avaient survécu pour exactement cette raison.
String _sansCommentaires(String source) =>
    source.replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  group('Taille minimale de la fenêtre Windows (K3, décision 8)', () {
    late String contenu;
    late String code;

    setUpAll(() {
      final File fichier = File('windows/runner/win32_window.cpp');
      expect(
        fichier.existsSync(),
        isTrue,
        reason: 'windows/runner/win32_window.cpp doit exister',
      );
      contenu = fichier.readAsStringSync();
      code = _sansCommentaires(contenu);
    });

    test('le message WM_GETMINMAXINFO est traité', () {
      expect(contenu, contains('WM_GETMINMAXINFO'));
    });

    test('la contrainte est posée sur ptMinTrackSize', () {
      expect(contenu, contains('ptMinTrackSize'));
    });

    test(
      'des constantes nommées portent 800 et 700 (pas de nombre magique)',
      () {
        expect(
          contenu,
          contains(RegExp(r'constexpr\s+int\s+kMinWindowWidth\s*=\s*800')),
          reason: 'largeur minimale nommée, valeur 800 (décision 8)',
        );
        expect(
          contenu,
          contains(RegExp(r'constexpr\s+int\s+kMinWindowHeight\s*=\s*700')),
          reason:
              'hauteur minimale nommée, valeur 700 (décision 8, amendée le '
              "2026-09-23 par le commanditaire : à 600, la légende de "
              "l'échelle débit recouvrait les contrôles de zoom)",
        );
      },
    );

    test('la contrainte porte sur la ZONE CLIENTE, pas seulement sur la '
        'fenêtre extérieure (AdjustWindowRectExForDpi, amendement du '
        '2026-09-23)', () {
      expect(
        code,
        contains('AdjustWindowRectExForDpi'),
        reason:
            'ptMinTrackSize contraint la fenêtre EXTÉRIEURE (bordures et '
            'barre de titre comprises) ; sans conversion, la ZONE '
            'CLIENTE visible pour puces/légende/contrôles serait plus '
            'petite que 800 × 700. AdjustWindowRectExForDpi (Win32, '
            'documentée) convertit une zone cliente désirée en taille '
            'de fenêtre extérieure, au DPI donné.',
      );
    });

    group('preuve par mutation (relecture du coordinateur du 2026-09-23) — '
        'chaque expression EST le code, pas seulement citée dans un '
        'commentaire au-dessus', () {
      /// Le sous-texte du bloc `case WM_GETMINMAXINFO`, SANS commentaires
      /// — c'est sur CE sous-texte que chaque expression doit être
      /// trouvée, jamais sur `contenu` en entier : un commentaire au-dessus
      /// du bloc, ou ailleurs dans le fichier, ne doit jamais faire
      /// passer un test dont l'APPEL réel aurait été retiré ou changé.
      late String blocGetMinMaxInfo;

      setUpAll(() {
        final int debut = code.indexOf('case WM_GETMINMAXINFO');
        expect(
          debut,
          greaterThanOrEqualTo(0),
          reason: 'case WM_GETMINMAXINFO doit exister (hors commentaire)',
        );
        final int find = code.indexOf('return DefWindowProc', debut);
        blocGetMinMaxInfo = code.substring(
          debut,
          find >= 0 ? find : code.length,
        );
      });

      test('AdjustWindowRectExForDpi est appelé avec &client_rect', () {
        expect(
          blocGetMinMaxInfo,
          contains('AdjustWindowRectExForDpi(&client_rect'),
          reason:
              'mutation testée : l\'appel retiré — ce test doit devenir '
              'rouge si `AdjustWindowRectExForDpi(&client_rect` disparaît '
              'du CODE (pas seulement du commentaire qui le décrit)',
        );
      });

      test('la largeur minimale passe par Scale(kMinWindowWidth', () {
        expect(
          blocGetMinMaxInfo,
          contains('Scale(kMinWindowWidth'),
          reason:
              'mutation testée : remplacer kMinWindowWidth par une '
              'valeur écrite en dur (ex. Scale(640…)) doit rendre ce '
              'test rouge',
        );
      });

      test('la hauteur minimale passe par Scale(kMinWindowHeight', () {
        expect(
          blocGetMinMaxInfo,
          contains('Scale(kMinWindowHeight'),
          reason:
              'mutation testée : remplacer kMinWindowHeight par une '
              'valeur écrite en dur (ex. Scale(480…)) doit rendre ce '
              'test rouge',
        );
      });

      test('ptMinTrackSize.x est calculé depuis client_rect.right - '
          'client_rect.left', () {
        expect(
          blocGetMinMaxInfo,
          contains('ptMinTrackSize.x = client_rect.right - client_rect.left'),
        );
      });

      test('ptMinTrackSize.y est calculé depuis client_rect.bottom - '
          'client_rect.top', () {
        expect(
          blocGetMinMaxInfo,
          contains('ptMinTrackSize.y = client_rect.bottom - client_rect.top'),
          reason:
              'mutation testée : `ptMinTrackSize.y = 0` (ou toute '
              'valeur qui ne dérive plus de client_rect) doit rendre '
              'ce test rouge',
        );
      });
    });

    test('les constantes sont bien celles utilisées pour ptMinTrackSize, pas '
        'des constantes orphelines', () {
      expect(code, contains('kMinWindowWidth'));
      expect(code, contains('kMinWindowHeight'));
      final int indexGetMinMaxInfo = code.indexOf('case WM_GETMINMAXINFO');
      final int indexPtMinTrackSizeX = code.indexOf(
        'ptMinTrackSize.x',
        indexGetMinMaxInfo,
      );
      final int indexPtMinTrackSizeY = code.indexOf(
        'ptMinTrackSize.y',
        indexGetMinMaxInfo,
      );
      expect(
        indexPtMinTrackSizeX,
        greaterThan(indexGetMinMaxInfo),
        reason: 'ptMinTrackSize.x doit être posé DANS le bloc WM_GETMINMAXINFO',
      );
      expect(
        indexPtMinTrackSizeY,
        greaterThan(indexGetMinMaxInfo),
        reason: 'ptMinTrackSize.y doit être posé DANS le bloc WM_GETMINMAXINFO',
      );
    });
  });
}
