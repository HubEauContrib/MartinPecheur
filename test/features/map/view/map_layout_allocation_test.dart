// La répartition de la hauteur de la carte visible (`S5` d'Ergonomie, spec
// § 5.6 et § 6.5, arbitrage 11) : `allocateMapLayout`, une fonction pure,
// éprouvée seule sur des nombres — aucune pièce d'écran, aucun rendu.
//
// Ce que ces tests prouvent :
// - rien ne cède tant que tout tient ; puis les replis jouent dans l'ordre
//   arbitré (1. légende · 2. fiche · 3. avis · 4. sous-titres · 5. indice ·
//   6. au téléphone, en mode, fiche ouverte : bande et réticule), chacun
//   seulement de ce qu'il faut ;
// - le repli 6 étendu (arbitrage 14) : en mode, fiche ouverte, une bande qui
//   ne tient pas en largeur (`bandFits` faux) se retire d'emblée, à toute
//   largeur ; sans fiche, elle donne `overflows` ;
// - les écarts se comptent par groupe — bloc (partie fixe, avis, légende),
//   bande du réticule, zone du bas, fiche — : un `gap` entre deux groupes
//   consécutifs non nuls, aucun dans le bloc, aucun de part et d'autre de la
//   bande du réticule, un entre la bande et la rangée en compact ; un groupe
//   tombé à 0 n'a plus d'écart (repli 6) ;
// - un repli qui n'a rien à prendre n'est pas compté ;
// - le surplus d'un repli tout-ou-rien (4, 5, 6) revient aux pièces qui
//   cèdent par degrés, la plus tardive d'abord (avis, puis fiche, puis
//   légende) ;
// - en panneau latéral, la fiche est à côté : hors de la somme ; au-delà du
//   téléphone, le bas n'entre dans la somme que s'il passe sous le bloc ;
//   sinon, en wide, fiche du bas ouverte, la colonne plafonne la fiche
//   (`available − bas − gap`, repli 2) et `overflows` dit qu'elles ne
//   tiennent pas ensemble ;
// - toutes les comparaisons se font à `1e-6` près ;
// - quand rien ne suffit, la partie fixe reçoit ce qui reste ; rien n'est
//   jamais négatif, aucune exception.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/map_layout_allocation.dart';

/// Une entrée dont chaque pièce non nommée est nulle — sauf la partie fixe
/// (100 repliée, 150 entière) et le bas (60), présents sur toute carte.
MapLayoutInput _input({
  required double available,
  MapLayoutWidth width = MapLayoutWidth.compact,
  bool blockOverBottom = true,
  bool designation = false,
  bool sheetOpen = false,
  PieceHeights blockFixed = const PieceHeights(min: 100, max: 150),
  double notices = 0,
  double legend = 0,
  double bottom = 60,
  PieceHeights band = PieceHeights.none,
  double reticleBand = 0,
  PieceHeights sheet = PieceHeights.none,
  double gap = 8,
  bool bandFits = true,
  bool reticleUnderBlock = true,
}) => MapLayoutInput(
  available: available,
  width: width,
  blockOverBottom: blockOverBottom,
  bandFits: bandFits,
  reticleUnderBlock: reticleUnderBlock,
  designation: designation,
  sheetOpen: sheetOpen,
  blockFixed: blockFixed,
  notices: notices,
  legend: legend,
  bottom: bottom,
  band: band,
  reticleBand: reticleBand,
  sheet: sheet,
  gap: gap,
);

/// Toutes les pièces, au téléphone, en mode, fiche ouverte. Entières : bloc
/// 150 + 40 + 100 = 290, bande du réticule 56 (sans écart autour), zone du bas
/// 80 + 8 + 60 = 148, écart, fiche 300 — 290 + 56 + 148 + 8 + 300 = 802 ;
/// en mode, la partie variable (40 + 100) compte deux fois tant que la bande
/// du réticule est là (le réticule au milieu, `D1`) : 942.
MapLayoutInput _everyPiece({
  required double available,
  MapLayoutWidth width = MapLayoutWidth.compact,
}) => _input(
  available: available,
  width: width,
  designation: true,
  sheetOpen: true,
  notices: 40,
  legend: 100,
  reticleBand: 56,
  band: const PieceHeights(min: 48, max: 80),
  sheet: const PieceHeights(min: 80, max: 300),
);

void main() {
  group('Le réticule sous le bloc, en largeur (mapLayoutWidths)', () {
    MapLayoutWidths at(double width, {bool sheetOpen = false}) =>
        mapLayoutWidths(
          width: width,
          sheetOpen: sheetOpen,
          bottomMaxIntrinsicWidth: 60,
          bandMinIntrinsicWidth: 120,
          padding: 8,
          reticleWidth: 48,
        );

    test('compact : toujours (bloc pleine largeur)', () {
      expect(at(360).reticleUnderBlock, isTrue);
      expect(at(599).reticleUnderBlock, isTrue);
    });

    test('1 280 sans fiche : réticule 616–664, bloc 8–488 — non', () {
      expect(at(1280).block, 480);
      expect(at(1280).reticleUnderBlock, isFalse);
    });

    test('1 280, panneau ouvert : carte visible 900, réticule 426–474, bloc '
        '8–488 — oui', () {
      final MapLayoutWidths widths = at(1280, sheetOpen: true);
      expect(widths.visible, 900);
      expect(widths.reticleUnderBlock, isTrue);
    });

    test('800 sans fiche et wide : le bloc de 480 atteint le centre — oui', () {
      expect(at(800).reticleUnderBlock, isTrue);
      expect(at(700).reticleUnderBlock, isTrue);
    });

    test('bord à bord n\'est pas un recouvrement : réticule 488–536 à côté '
        'd\'un bloc 8–488', () {
      // Carte visible 1 024 : centre 512, réticule 488–536.
      expect(at(1024).reticleUnderBlock, isFalse);
      expect(at(1023).reticleUnderBlock, isTrue);
    });
  });

  group('La hauteur disponible (mapLayoutAvailableHeight)', () {
    double at(
      MapLayoutWidth width, {
      required bool sheetOpen,
      double h = 640,
    }) => mapLayoutAvailableHeight(
      safeHeight: h,
      width: width,
      sheetOpen: sheetOpen,
      padding: 8,
    );

    test(
      'fiche du bas ouverte : une seule marge, la fiche est collée au bas',
      () {
        expect(at(MapLayoutWidth.compact, sheetOpen: true), 632);
        expect(at(MapLayoutWidth.wide, sheetOpen: true), 632);
      },
    );

    test('aucune fiche, ou le panneau à côté : deux marges', () {
      expect(at(MapLayoutWidth.compact, sheetOpen: false), 624);
      expect(at(MapLayoutWidth.wide, sheetOpen: false), 624);
      expect(at(MapLayoutWidth.panel, sheetOpen: true), 624);
      expect(at(MapLayoutWidth.panel, sheetOpen: false), 624);
    });

    test('jamais négative', () {
      expect(at(MapLayoutWidth.compact, sheetOpen: false, h: 10), 0);
    });
  });

  group('Les largeurs', () {
    test('les quatre largeurs nommées de la spec § 5.1', () {
      expect(mapWideLayoutMinWidth, 600);
      expect(mapSidePanelMinWidth, 800);
      expect(mapSidePanelWidth, 380);
      expect(mapReadingBlockMaxWidth, 480);
    });

    test('599 → compact, 600 → wide, 799 → wide, 800 → panel', () {
      expect(mapLayoutWidthFor(599), MapLayoutWidth.compact);
      expect(mapLayoutWidthFor(600), MapLayoutWidth.wide);
      expect(mapLayoutWidthFor(799), MapLayoutWidth.wide);
      expect(mapLayoutWidthFor(800), MapLayoutWidth.panel);
    });
  });

  group('Rien ne cède tant que tout tient', () {
    test('942 pour 942, en mode : aucun repli, chaque pièce à son max', () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 942),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.blockFixed, 150);
      expect(allocation.notices, 40);
      expect(allocation.legend, 100);
      expect(allocation.reticleBand, 56);
      expect(allocation.band, 80);
      expect(allocation.sheet, 300);
      expect(allocation.subtitlesFolded, isFalse);
      expect(allocation.hintFolded, isFalse);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.overflows, isFalse);
    });
  });

  group('Chaque repli seulement de ce qu\'il faut', () {
    test('il manque 30 px, légende de 100 : repli 1, légende 70', () {
      // Bloc 150 + 100, écart, rangée 60 : 318, pour 288.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 288, legend: 100),
      );

      expect(allocation.folds, <int>[1]);
      expect(allocation.legend, 70);
      expect(allocation.blockFixed, 150);
      expect(allocation.overflows, isFalse);
    });

    test('la légende passée à 0, il manque encore 100 : replis 1 et 2, fiche '
        '200', () {
      // Bloc 150 + 50, écart, rangée 60, écart, fiche 300 : 576. La légende à
      // 0 rend 50 : 526 ; pour 426, il manque encore 100, que la fiche
      // (300, au plus bas 80) donne.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 426,
          sheetOpen: true,
          legend: 50,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, <int>[1, 2]);
      expect(allocation.legend, 0);
      expect(allocation.sheet, 200);
      expect(allocation.overflows, isFalse);
    });

    test('légende nulle à l\'entrée : le repli 1 n\'a rien à prendre, il '
        'n\'est pas compté', () {
      // Bloc 150, écart, rangée 60, écart, fiche 300 : 526, pour 426.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 426,
          sheetOpen: true,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, <int>[2]);
      expect(allocation.sheet, 200);
    });
  });

  group('L\'ordre de repli', () {
    test('au téléphone, en mode, fiche ouverte : les six replis, dans l\'ordre '
        '1 à 6', () {
      // 942 entières. Légende, avis et fiche au plus bas : 150 + 56 +
      // (80 + 8 + 60) + 8 + 80 = 442. Repli 4 : 392. Repli 5 : 360. Repli 6 :
      // bande et bande du réticule retirées, l'écart de la bande avec elles ;
      // le bloc et la rangée, voisins, prennent un écart : 100 + 8 + 60 + 8 +
      // 80 = 256, pour 256.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 256),
      );

      expect(allocation.folds, <int>[1, 2, 3, 4, 5, 6]);
      expect(allocation.legend, 0);
      expect(allocation.sheet, 80);
      expect(allocation.notices, 0);
      expect(allocation.blockFixed, 100);
      expect(allocation.subtitlesFolded, isTrue);
      expect(allocation.hintFolded, isTrue);
      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
      expect(allocation.overflows, isFalse);
    });

    test('le même cas en wide : pas de repli 6, débordement ; la partie fixe '
        'reçoit ce qui reste', () {
      // En wide, la bande est à côté de la colonne : zone du bas
      // max(80, 60) = 80. Au plus bas : 150 + 56 + 80 + 8 + 80 = 374.
      // Repli 4 : 324. Repli 5 : max(48, 60) = 60, 304 > 256. La partie fixe
      // reçoit 256 − (56 + 60 + 8 + 80) = 52 : aucun écart contre la bande
      // du réticule.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 256, width: MapLayoutWidth.wide),
      );

      expect(allocation.folds, <int>[1, 2, 3, 4, 5]);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.band, 48);
      expect(allocation.reticleBand, 56);
      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 52);
    });

    test('au téléphone, en mode, fiche fermée : pas de repli 6 ; le repli 2 '
        'n\'a rien à prendre', () {
      // 150 + 56 + (80 + 8 + 60) = 354. Repli 4 : 304. Repli 5 : 272 > 200.
      // La partie fixe reçoit 200 − (56 + 48 + 8 + 60) = 28.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 200,
          designation: true,
          legend: 100,
          notices: 40,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(allocation.folds, <int>[1, 3, 4, 5]);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.band, 48);
      expect(allocation.reticleBand, 56);
      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 28);
    });

    test('repli 5 seul après le 4 : la bande passe à sa pilule', () {
      // 150 + 56 + (80 + 8 + 60) = 354. Repli 4 : 304 > 300. Repli 5 : 272.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 300,
          designation: true,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(allocation.folds, <int>[4, 5]);
      expect(allocation.blockFixed, 100);
      expect(allocation.band, 48);
      expect(allocation.hintFolded, isTrue);
      expect(allocation.overflows, isFalse);
    });

    test('au-delà du téléphone, un repli 5 qui ne libère rien (bande à côté '
        'd\'une colonne plus haute) n\'est pas joué', () {
      // Wide : zone du bas max(80, 120) = 120, et max(48, 120) = 120 après
      // le repli 5. 150 + 56 + 120 = 326. Repli 4 : 276 > 260. La partie
      // fixe reçoit 260 − (56 + 120) = 84.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 260,
          width: MapLayoutWidth.wide,
          designation: true,
          bottom: 120,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(allocation.folds, <int>[4]);
      expect(allocation.hintFolded, isFalse);
      expect(allocation.band, 80);
      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 84);
    });
  });

  group('Le surplus d\'un repli tout-ou-rien', () {
    test('revient aux avis d\'abord, puis à la fiche ; la légende en dernier — '
        'replis 1, 2, 4 en vigueur, les avis entiers', () {
      // Bloc 160 + 40 + 100, écart, rangée 60, écart, fiche 300 : 676. Au
      // plus bas : 160 + 8 + 60 + 8 + 80 = 316 > 314 : le repli 4 joue
      // (− 60) : 256. Surplus 58 : les avis reprennent 40 (aucun écart dans
      // le bloc), la fiche les 18 restants ; le repli 3 n'est plus en
      // vigueur.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 314,
          sheetOpen: true,
          blockFixed: const PieceHeights(min: 100, max: 160),
          notices: 40,
          legend: 100,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, <int>[1, 2, 4]);
      expect(allocation.blockFixed, 100);
      expect(allocation.notices, 40);
      expect(allocation.sheet, 98);
      expect(allocation.legend, 0);
      expect(allocation.overflows, isFalse);
    });
  });

  group('Ce qui n\'entre pas dans la somme', () {
    test('panel, fiche ouverte : la fiche est à côté, hors de la somme', () {
      // Bloc 150 + 100, écart, colonne 60 : 318, pour 318 ; la fiche de 600
      // n'y est pas.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 318,
          width: MapLayoutWidth.panel,
          sheetOpen: true,
          legend: 100,
          sheet: const PieceHeights(min: 80, max: 600),
        ),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.legend, 100);
      expect(allocation.sheet, 600);
      expect(allocation.overflows, isFalse);
    });

    test('wide, bloc étroit (blockOverBottom faux) : le bas n\'entre pas dans '
        'la somme', () {
      // Sans le bas : le bloc seul, 150 + 100 = 250, pour 400.
      final MapLayoutAllocation narrow = allocateMapLayout(
        _input(
          available: 400,
          width: MapLayoutWidth.wide,
          blockOverBottom: false,
          legend: 100,
          bottom: 200,
        ),
      );
      // Avec le bas sous le bloc : 250, écart, 200 : 458, il manque 58 :
      // légende 42.
      final MapLayoutAllocation wide = allocateMapLayout(
        _input(
          available: 400,
          width: MapLayoutWidth.wide,
          legend: 100,
          bottom: 200,
        ),
      );

      expect(narrow.folds, isEmpty);
      expect(narrow.legend, 100);
      expect(wide.folds, <int>[1]);
      expect(wide.legend, 42);
    });
  });

  group('Le bas hors de la somme borne quand même', () {
    test('compact, blockOverBottom faux : le bas compte quand même', () {
      // Bloc 150 + 100, écart, rangée 60 : 318, pour 288 → légende 70. Sans
      // la rangée, 250 tiendrait.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 288, blockOverBottom: false, legend: 100),
      );

      expect(allocation.folds, <int>[1]);
      expect(allocation.legend, 70);
    });

    test('wide, bloc étroit, fiche ouverte : la colonne borne la fiche — 584 → '
        'fiche 288, repli 2, légende entière', () {
      // La colonne (288) se pose au-dessus de la fiche du bas : la fiche
      // reçoit au plus 584 − 288 − 8 = 288. Bloc 110 + 60, écart, fiche 288 :
      // 466, qui tient.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 584,
          width: MapLayoutWidth.wide,
          blockOverBottom: false,
          sheetOpen: true,
          blockFixed: const PieceHeights(min: 90, max: 110),
          legend: 60,
          bottom: 288,
          sheet: const PieceHeights(min: 70, max: 320),
        ),
      );

      expect(allocation.folds, <int>[2]);
      expect(allocation.sheet, 288);
      expect(allocation.legend, 60);
      expect(allocation.blockFixed, 110);
      expect(allocation.overflows, isFalse);
    });

    test('640 × 360 : l\'en-tête de fiche et la colonne ne tiennent pas '
        'ensemble — débordement, fiche à son en-tête', () {
      // Plafond 344 − 288 − 8 = 48, sous l'en-tête de 70. Le bloc, lui,
      // tient : 110 + 60, écart, 70 = 248.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 344,
          width: MapLayoutWidth.wide,
          blockOverBottom: false,
          sheetOpen: true,
          blockFixed: const PieceHeights(min: 90, max: 110),
          legend: 60,
          bottom: 288,
          sheet: const PieceHeights(min: 70, max: 320),
        ),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.sheet, 70);
      expect(allocation.folds, <int>[2]);
      expect(allocation.legend, 60);
      expect(allocation.blockFixed, 110);
    });

    test('panel, bloc étroit : une colonne plus haute que la carte visible '
        'déborde', () {
      // Le bloc (150) tient dans 200 ; la colonne de 300, à côté, non.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 200,
          width: MapLayoutWidth.panel,
          blockOverBottom: false,
          bottom: 300,
        ),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.folds, isEmpty);
      expect(allocation.blockFixed, 150);
    });
  });

  group('Rien de négatif, aucune exception', () {
    test('available = 0 : débordement, partie fixe 0', () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 0),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.folds, <int>[1, 2, 3, 4, 5, 6]);
      expect(allocation.blockFixed, 0);
      expect(allocation.notices, 0);
      expect(allocation.legend, 0);
      expect(allocation.sheet, 80);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
    });

    test('available négatif : même chose', () {
      // Wide : pas de repli 6, la bande reste à sa pilule et le réticule.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: -50, width: MapLayoutWidth.wide),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.folds, <int>[1, 2, 3, 4, 5]);
      expect(allocation.blockFixed, 0);
      expect(allocation.notices, 0);
      expect(allocation.legend, 0);
      expect(allocation.sheet, 80);
      expect(allocation.band, 48);
      expect(allocation.reticleBand, 56);
    });

    test('des hauteurs négatives à l\'entrée comptent pour 0', () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 100,
          blockFixed: const PieceHeights(min: -10, max: -5),
          notices: -20,
          legend: -30,
          bottom: -40,
          band: const PieceHeights(min: -1, max: -2),
          reticleBand: -3,
          sheet: const PieceHeights(min: -4, max: -6),
          gap: -8,
        ),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.overflows, isFalse);
      expect(allocation.blockFixed, 0);
      expect(allocation.notices, 0);
      expect(allocation.legend, 0);
      expect(allocation.sheet, 0);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
    });
  });

  group('Tolérance de calcul', () {
    test('218.17 pour 150 + 8 + 60.17 : aucun repli pour un bruit de '
        'flottant', () {
      // En flottants, 150 + 8 + 60.17 vaut 218.17000000000002.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 218.17, bottom: 60.17),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.subtitlesFolded, isFalse);
      expect(allocation.blockFixed, 150);
      expect(allocation.overflows, isFalse);
    });
  });

  group('Les écarts, par groupe', () {
    test('aucun écart dans le bloc : partie fixe, avis et légende, puis un '
        'écart et la rangée — 358 tient dans 358', () {
      // Bloc : 150 + 40 + 100 = 290, d'un seul tenant (B1 : une carte
      // continue). Puis un écart et la rangée : 290 + 8 + 60 = 358.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 358, notices: 40, legend: 100),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.notices, 40);
      expect(allocation.legend, 100);
    });

    test('la légende tombée à 0 ne rend que sa hauteur, sans écart : il manque '
        '120, la légende en rend 100, les avis 20', () {
      // 358, pour 238. Si la légende avait un écart, elle rendrait 108 et
      // les avis ne donneraient que 12.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 238, notices: 40, legend: 100),
      );

      expect(allocation.folds, <int>[1, 3]);
      expect(allocation.legend, 0);
      expect(allocation.notices, 20);
    });

    test('aucun écart de part et d\'autre de la bande du réticule : elle porte '
        'ses marges', () {
      // Compact : bloc 150, bande du réticule 56, zone du bas 80 + 8 + 60 =
      // 148 : 354. Wide : zone du bas max(80, 60) = 80 : 286.
      final MapLayoutAllocation compact = allocateMapLayout(
        _input(
          available: 354,
          designation: true,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );
      final MapLayoutAllocation wide = allocateMapLayout(
        _input(
          available: 286,
          width: MapLayoutWidth.wide,
          designation: true,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(compact.folds, isEmpty);
      expect(wide.folds, isEmpty);
    });

    test('en compact, un écart entre la bande et la rangée : 354 tient, 350 ne '
        'tient plus', () {
      // 150 + 56 + (80 + 8 + 60) = 354. Sans cet écart, 346 tiendrait dans
      // 350 ; avec lui, le repli 4 joue.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(
          available: available,
          designation: true,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(at(354).folds, isEmpty);
      expect(at(350).folds, <int>[4]);
    });

    test('le repli 6 retire la bande avec son écart ; le bloc et la rangée, '
        'devenus voisins, en prennent un', () {
      // Après les replis 1 à 5 : 100 + 56 + (48 + 8 + 60) + 8 + 80 = 360.
      // Repli 6 : 100 + 8 + 60 + 8 + 80 = 256 — l'écart de la bande part
      // avec elle, un écart sépare désormais le bloc de la rangée. Pour 264,
      // les 8 de surplus reviennent aux avis, sans écart dans le bloc.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 264),
      );

      expect(allocation.folds, <int>[1, 2, 3, 4, 5, 6]);
      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
      expect(allocation.notices, 8);
      expect(allocation.sheet, 80);
      expect(allocation.legend, 0);
      expect(allocation.overflows, isFalse);
    });
  });

  group('Le repli 6 étendu : la bande qui ne tient pas en largeur (arbitrage 14)', () {
    test("panel, en mode, fiche ouverte, bande trop large pour sa place : "
        "bande et réticule retirés d'emblée, repli 6, rien ne déborde", () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 600,
          width: MapLayoutWidth.panel,
          blockOverBottom: false,
          designation: true,
          sheetOpen: true,
          reticleBand: 64,
          band: const PieceHeights(min: 48, max: 80),
          sheet: const PieceHeights(min: 80, max: 300),
          bandFits: false,
        ),
      );

      expect(allocation.folds, <int>[6]);
      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
      expect(allocation.blockFixed, 150);
      expect(allocation.overflows, isFalse);
    });

    test(
      "wide, en mode, fiche du bas ouverte : le même retrait, à toute "
      "largeur — 150 + 8 + 60 + 8 + 300 = 526 tient dans 600 sans autre repli",
      () {
        final MapLayoutAllocation allocation = allocateMapLayout(
          _input(
            available: 600,
            width: MapLayoutWidth.wide,
            designation: true,
            sheetOpen: true,
            reticleBand: 64,
            band: const PieceHeights(min: 48, max: 80),
            sheet: const PieceHeights(min: 80, max: 300),
            bandFits: false,
          ),
        );

        expect(allocation.folds, <int>[6]);
        expect(allocation.bandWithdrawn, isTrue);
        expect(allocation.sheet, 300);
        expect(allocation.overflows, isFalse);
      },
    );

    test("panel, en mode, SANS fiche, bande trop large : elle ne peut ni se "
        "poser ni se retirer — débordement, pas de repli 6", () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 600,
          width: MapLayoutWidth.panel,
          blockOverBottom: false,
          designation: true,
          reticleBand: 64,
          band: const PieceHeights(min: 48, max: 80),
          bandFits: false,
        ),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.folds, isNot(contains(6)));
      // Ni posée ni retirée : la bande garde ses hauteurs dans la
      // répartition (150 + 64 + 80 = 294 tient dans 600).
      expect(allocation.band, 80);
      expect(allocation.reticleBand, 64);
    });

    test("panel, en mode, fiche ouverte, bande trop large ET hauteur qui "
        "manque : repli 6 d'emblée, puis 1 et 4 ; le repli 5 ne joue pas", () {
      // Bande et réticule retirés : bloc 150 + 100, écart, bas 60 = 318 pour
      // 200. Repli 1 : 150 + 8 + 60 = 218 ; repli 4 : 100 + 8 + 60 = 168 ;
      // les 32 de surplus reviennent à la légende.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 200,
          width: MapLayoutWidth.panel,
          designation: true,
          sheetOpen: true,
          legend: 100,
          reticleBand: 64,
          band: const PieceHeights(min: 48, max: 80),
          sheet: const PieceHeights(min: 80, max: 300),
          bandFits: false,
        ),
      );

      expect(allocation.folds, <int>[1, 4, 6]);
      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.hintFolded, isFalse);
      expect(allocation.subtitlesFolded, isTrue);
      expect(allocation.band, 0);
      expect(allocation.reticleBand, 0);
      expect(allocation.blockFixed, 100);
      expect(allocation.legend, 32);
      expect(allocation.overflows, isFalse);
    });

    test("bande qui tient (bandFits vrai) : même répartition qu'avant — en "
        "panel, fiche ouverte, aucun repli", () {
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 600,
          width: MapLayoutWidth.panel,
          blockOverBottom: false,
          designation: true,
          sheetOpen: true,
          reticleBand: 64,
          band: const PieceHeights(min: 48, max: 80),
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.band, 80);
      expect(allocation.overflows, isFalse);
    });
  });

  group('Égalité par valeur', () {
    test('deux répartitions des mêmes nombres sont égales', () {
      final MapLayoutAllocation first = allocateMapLayout(
        _everyPiece(available: 260),
      );
      final MapLayoutAllocation second = allocateMapLayout(
        _everyPiece(available: 260),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(allocateMapLayout(_everyPiece(available: 942))));
    });
  });

  group('Arbitrage 15 : le réticule reste fixe', () {
    // En mode, bande du réticule posée et fiche du bas comptée, les replis
    // continus jouent dans l'ordre 1, 3, 2 : la fiche — qui place la bande,
    // donc le réticule — ne dépend plus des avis ni de la légende.

    /// Compact, fiche du bas 80/300. En mode : bande 48/80, bande du réticule
    /// 56 ; au plus bas, 150 + 56 + (80 + 8 + 60) + 8 + 80 = 442.
    MapLayoutInput entree({
      required double available,
      required double notices,
      bool designation = true,
    }) => _input(
      available: available,
      designation: designation,
      sheetOpen: true,
      notices: notices,
      reticleBand: designation ? 56 : 0,
      band: designation
          ? const PieceHeights(min: 48, max: 80)
          : PieceHeights.none,
      sheet: const PieceHeights(min: 80, max: 300),
    );

    test('en mode, avis 0 puis 40 : la fiche garde la même hauteur ; le '
        'surplus va à la fiche avant les avis', () {
      final MapLayoutAllocation sansAvis = allocateMapLayout(
        entree(available: 500, notices: 0),
      );
      final MapLayoutAllocation avecAvis = allocateMapLayout(
        entree(available: 500, notices: 40),
      );

      expect(sansAvis.sheet, 138);
      expect(avecAvis.sheet, sansAvis.sheet);
      expect(avecAvis.notices, 0);
      expect(avecAvis.folds, <int>[2, 3]);
    });

    test('en mode, assez de place pour la fiche entière : le reste revient '
        'aux avis, puis à la légende', () {
      // Fiche entière : 150 + 56 + 148 + 8 + 300 = 662 ; 22 de plus, comptés
      // deux fois : avis 11.
      final MapLayoutAllocation allocation = allocateMapLayout(
        entree(available: 684, notices: 40),
      );

      expect(allocation.sheet, 300);
      expect(allocation.notices, 11);
      expect(allocation.folds, <int>[3]);
    });

    test('hors mode : inchangé — les avis avant la fiche', () {
      // Au plus bas : 150 + 8 + 60 + 8 + 80 = 306 ; surplus 94 : les avis
      // reprennent 40, la fiche 54.
      final MapLayoutAllocation avecAvis = allocateMapLayout(
        entree(available: 400, notices: 40, designation: false),
      );
      final MapLayoutAllocation sansAvis = allocateMapLayout(
        entree(available: 400, notices: 0, designation: false),
      );

      expect(avecAvis.notices, 40);
      expect(avecAvis.sheet, 134);
      expect(sansAvis.sheet, 174);
      expect(avecAvis.folds, <int>[2]);
    });

    test('en mode, bande retirée (repli 6) : inchangé — les avis avant la '
        'fiche', () {
      // Le cas « le repli 6 retire la bande avec son écart » : surplus 8,
      // aux avis.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 264),
      );

      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.notices, 8);
      expect(allocation.sheet, 80);
    });
  });

  group('En mode, la partie variable compte deux fois (amendement de D1)', () {
    // Le réticule est au milieu de [bas de la partie fixe ; haut de la bande]
    // (spec § 5.5) et la partie variable (avis + légende) s'arrête au-dessus
    // de la bande du réticule : avec H = haut de la bande − bas de la partie
    // fixe, R la bande du réticule et V la partie variable, V ≤ (H − R) / 2.
    // En mode, tant que la bande du réticule est là, V compte donc DEUX FOIS
    // dans la somme ; hors mode, ou bande retirée (repli 6), une fois.

    /// Compact, en mode, sans fiche : partie fixe 150, avis 40, légende 100,
    /// bande du réticule 56, zone du bas 80 + 8 + 60 = 148. Une fois : 494 ;
    /// deux fois : 634.
    MapLayoutInput enMode(double available) => _input(
      available: available,
      designation: true,
      notices: 40,
      legend: 100,
      reticleBand: 56,
      band: const PieceHeights(min: 48, max: 80),
    );

    test('634 pour 634 : aucun repli ; 633 ne tient plus', () {
      expect(allocateMapLayout(enMode(634)).folds, isEmpty);
      expect(allocateMapLayout(enMode(633)).folds, <int>[1]);
    });

    test('il manque 100 : la légende en rend 50, comptés deux fois', () {
      final MapLayoutAllocation allocation = allocateMapLayout(enMode(534));

      expect(allocation.folds, <int>[1]);
      expect(allocation.legend, 50);
      expect(allocation.notices, 40);
      expect(allocation.blockFixed, 150);
      expect(allocation.overflows, isFalse);
    });

    test('la légende à 0, les avis par degrés, eux aussi deux fois : 374 → '
        'avis 10', () {
      // 150 + 2 × avis + 56 + 148 = 374 : avis 10.
      final MapLayoutAllocation allocation = allocateMapLayout(enMode(374));

      expect(allocation.folds, <int>[1, 3]);
      expect(allocation.legend, 0);
      expect(allocation.notices, 10);
      expect(allocation.overflows, isFalse);
    });

    test('hors mode, la même partie variable ne compte qu\'une fois', () {
      // 150 + 40 + 100, écart, rangée 60 = 358.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(available: 358, notices: 40, legend: 100),
      );

      expect(allocation.folds, isEmpty);
    });

    test('bande retirée (repli 6) : la partie variable revient à une fois — '
        'le surplus revient aux avis à son poids simple', () {
      // Au téléphone, en mode, fiche ouverte : après le repli 6, 100 + 8 +
      // 60 + 8 + 80 = 256 ; pour 276, les avis reprennent 20, comptés une
      // fois (sans le retrait, 20 d'avis coûteraient 40).
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 276),
      );

      expect(allocation.bandWithdrawn, isTrue);
      expect(allocation.notices, 20);
      expect(allocation.legend, 0);
      expect(allocation.overflows, isFalse);
    });

    test('le réticule hors du bloc en largeur (reticleUnderBlock faux) : la '
        'partie variable ne compte qu\'une fois — 494 tient', () {
      // Spec § 5.6 : rien ne cède tant que tout tient. 150 + 140 + 56 + 148.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 494,
          designation: true,
          reticleUnderBlock: false,
          notices: 40,
          legend: 100,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
        ),
      );

      expect(allocation.folds, isEmpty);
      expect(allocation.legend, 100);
      expect(allocation.notices, 40);
    });

    test('le repli 6 étendu (bandFits faux) retire aussi le doublement', () {
      // Panel, fiche ouverte, bande trop large : retirée d'emblée. 150 + 40 +
      // 100, écart, colonne 60 = 358 tient dans 358 : V une fois.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 358,
          width: MapLayoutWidth.panel,
          designation: true,
          sheetOpen: true,
          notices: 40,
          legend: 100,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
          sheet: const PieceHeights(min: 80, max: 300),
          bandFits: false,
        ),
      );

      expect(allocation.folds, <int>[6]);
      expect(allocation.legend, 100);
      expect(allocation.notices, 40);
    });

    test('wide, en mode, la partie fixe qui déborde reçoit ce qui reste après '
        'la bande du réticule — V à 0 n\'y change rien', () {
      // Repris de « le même cas en wide » : V est tombée à 0, le doublement
      // ne coûte rien ; la partie fixe reçoit 52.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 256, width: MapLayoutWidth.wide),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.notices, 0);
      expect(allocation.legend, 0);
      expect(allocation.blockFixed, 52);
    });
  });
}
