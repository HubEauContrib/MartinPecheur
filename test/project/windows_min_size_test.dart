// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// Vérifie que le gabarit Windows pose une taille minimale de fenêtre
// (décision 8 du plan T1, tâche K3) : sous 800 × 740, la colonne
// « contrôle « ⚠ Avertissement » + légende » (`04-ui.md § 3`) n'a plus la
// place de tenir sans chevauchement — ce n'est plus un bandeau qui se
// tronque (amendement `W3c` du 2026-09-23), mais l'exigence de ne rien faire
// se recouvrir reste posée par la même contrainte de fenêtre.
//
// Amendement du commanditaire, 2026-09-29 : 700 → 740 (le bouton de
// désignation de `E1` fait recouvrir la légende débit sur 30 px à 800 × 700).
//
// Amendement du commanditaire, 2026-09-23 : 600 → 700. À 800 × 600, la
// légende de l'échelle débit (phrase `BR-003`) recouvrait les contrôles de
// zoom — chiffres mesurés dans
// `test/features/map/view/map_view_test.dart` (test « RAISON DE
// L'AMENDEMENT »).
//
// Ce test LIT les fichiers C++ (`windows/runner/win32_window.cpp` et
// `windows/runner/main.cpp`), il ne compile ni n'exécute rien — le bac à
// sable ne construit pas de natif.
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
      'des constantes nommées portent 800 et 740 (pas de nombre magique)',
      () {
        expect(
          contenu,
          contains(RegExp(r'constexpr\s+int\s+kMinWindowWidth\s*=\s*800')),
          reason: 'largeur minimale nommée, valeur 800 (décision 8)',
        );
        expect(
          contenu,
          contains(RegExp(r'constexpr\s+int\s+kMinWindowHeight\s*=\s*740')),
          reason:
              'hauteur minimale nommée, valeur 740 (décision 8, amendée le '
              "2026-09-29 par le commanditaire ; 600 → 700 le 2026-09-23 : à 600, la légende de "
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
            'petite que 800 × 740. AdjustWindowRectExForDpi (Win32, '
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

    // Arbitrage du commanditaire du 2026-10-17 (R23 du cadrage de la
    // tranche d'ergonomie) : le minimum ne valait qu'au redimensionnement.
    // `Create` passait 1 280 × 720 HORS TOUT à `CreateWindow`, et le premier
    // WM_GETMINMAXINFO arrive avant WM_NCCREATE, quand le runner ne connaît
    // pas encore son instance : la zone cliente de lancement mesurait
    // 1 264 × 681 à 100 % (reproduction hors Flutter du 2026-10-17). `Create`
    // reçoit désormais une ZONE CLIENTE, relevée au minimum.
    group('zone cliente au lancement (R23, arbitrage du 2026-10-17)', () {
      /// Le corps de `Win32Window::Create`, sans commentaires.
      late String blocCreate;

      /// L'appel de conversion, au style passé à `CreateWindow`.
      final RegExp appelConversion = RegExp(
        r'AdjustWindowRectExForDpi\(\s*&frame\s*,\s*WS_OVERLAPPEDWINDOW'
        r'\s*,\s*FALSE\s*,\s*0\s*,\s*dpi\s*\)',
      );

      setUpAll(() {
        final int debut = code.indexOf('bool Win32Window::Create(');
        expect(
          debut,
          greaterThanOrEqualTo(0),
          reason: 'Win32Window::Create doit exister (hors commentaire)',
        );
        final int fin = code.indexOf('return OnCreate();', debut);
        expect(fin, greaterThan(debut), reason: 'Create finit par OnCreate');
        blocCreate = code.substring(debut, fin);
      });

      test('la taille demandée est convertie de zone cliente en fenêtre '
          'extérieure, au style de CreateWindow', () {
        expect(
          blocCreate,
          contains(appelConversion),
          reason:
              'mutation testée : sans cet appel, CreateWindow reçoit une '
              'taille hors tout et la zone cliente perd le cadre et la '
              'barre de titre (39 px de haut à 100 %)',
        );
      });

      test('la largeur demandée est relevée à kMinWindowWidth avant mise à '
          "l'échelle", () {
        expect(
          blocCreate,
          contains(
            RegExp(
              r'Scale\(\s*std::max<int>\(\s*size\.width\s*,\s*'
              r'kMinWindowWidth\s*\)\s*,\s*scale_factor\s*\)',
            ),
          ),
          reason:
              'mutation testée : sans ce plancher, une largeur de départ '
              'sous 800 dans main.cpp relancerait sous le minimum',
        );
      });

      test('la hauteur demandée est relevée à kMinWindowHeight avant mise à '
          "l'échelle", () {
        expect(
          blocCreate,
          contains(
            RegExp(
              r'Scale\(\s*std::max<int>\(\s*size\.height\s*,\s*'
              r'kMinWindowHeight\s*\)\s*,\s*scale_factor\s*\)',
            ),
          ),
          reason:
              'mutation testée : sans ce plancher, une hauteur de départ '
              'sous 740 dans main.cpp relancerait sous le minimum',
        );
      });

      test('le RECT converti porte la largeur, puis la hauteur', () {
        expect(
          blocCreate,
          contains(
            RegExp(
              r'RECT\s+frame\s*=\s*\{\s*0\s*,\s*0\s*,\s*'
              r'Scale\(\s*std::max<int>\(\s*size\.width\s*,\s*'
              r'kMinWindowWidth\s*\)\s*,\s*scale_factor\s*\)\s*,\s*'
              r'Scale\(\s*std::max<int>\(\s*size\.height\s*,\s*'
              r'kMinWindowHeight\s*\)\s*,\s*scale_factor\s*\)\s*\}',
            ),
          ),
          reason:
              'mutation testée : largeur et hauteur interverties dans le '
              'RECT donneraient 740 × 1 280, sous la largeur minimale',
        );
      });

      test('CreateWindow reçoit la taille extérieure calculée, et non plus '
          'la taille demandée telle quelle', () {
        final int debutAppel = blocCreate.indexOf('CreateWindow(');
        expect(debutAppel, greaterThanOrEqualTo(0));
        final String appel = blocCreate.substring(
          debutAppel,
          blocCreate.indexOf(');', debutAppel),
        );
        expect(
          appelConversion.firstMatch(blocCreate)?.start,
          lessThan(debutAppel),
          reason: 'la conversion précède la création de la fenêtre',
        );
        expect(
          appel,
          contains('WS_OVERLAPPEDWINDOW'),
          reason: 'le style converti est celui de la fenêtre créée',
        );
        expect(
          appel,
          contains(
            RegExp(
              r'frame\.right - frame\.left\s*,\s*frame\.bottom - frame\.top',
            ),
          ),
          reason:
              'mutation testée : largeur et hauteur interverties dans '
              "l'appel",
        );
        expect(
          appel,
          isNot(contains(RegExp(r'Scale\(\s*size\.'))),
          reason:
              'mutation testée : revenir à Scale(size.width, …) dans '
              "l'appel rend la taille hors tout",
        );
      });

      test('main.cpp demande 1 280 × 740 de zone cliente au départ', () {
        final String mainCpp = _sansCommentaires(
          File('windows/runner/main.cpp').readAsStringSync(),
        );
        final RegExpMatch? taille = RegExp(
          r'Win32Window::Size\s+size\(\s*(\d+)\s*,\s*(\d+)\s*\)',
        ).firstMatch(mainCpp);
        expect(taille, isNotNull, reason: 'taille de départ introuvable');
        expect(
          <String?>[taille!.group(1), taille.group(2)],
          <String>['1280', '740'],
          reason:
              'arbitrage du 2026-10-17 : la hauteur minimale, qui tient sur '
              'un écran 1080p à 125 % (calcul : 788 des 816 px logiques de '
              'zone de travail)',
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
