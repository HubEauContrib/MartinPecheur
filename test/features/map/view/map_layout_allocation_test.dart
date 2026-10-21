// La répartition de la hauteur de la carte visible (`S5` d'Ergonomie, spec
// § 5.6 et § 6.5, arbitrage 11) : `allocateMapLayout`, une fonction pure,
// éprouvée seule sur des nombres — aucune pièce d'écran, aucun rendu.
//
// Ce que ces tests prouvent :
// - rien ne cède tant que tout tient ; puis les replis jouent dans l'ordre
//   arbitré (1. légende · 2. fiche · 3. avis · 4. sous-titres · 5. indice ·
//   6. au téléphone, en mode, fiche ouverte : bande et réticule), chacun
//   seulement de ce qu'il faut ; fiche du BAS ouverte, les sous-titres et
//   l'indice cèdent avant le corps de la fiche (arbitrage 17) : 1, 4, 2, 3
//   hors mode ou bande retirée d'emblée ; 1, 3, 4, 5, 2 en mode, bande du
//   réticule posée ; le repli 6 reste le dernier ;
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
//   cèdent par degrés déjà jouées, la plus tardive d'abord (avis, puis fiche,
//   puis légende ; en mode, bande du réticule posée : fiche, avis, légende) ;
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
///
/// [sheetFeatured] nulle : la fiche n'a pas d'autre mesure mise en avant que
/// son en-tête (`sheet.min`), comme avant l'arbitrage 18 ; [blockFixedFloor]
/// à 0 par défaut. Ces deux défauts rendent la répartition d'avant `D7` (le
/// groupe « Arbitrage 19 » le vérifie). [bottomFolded] nulle : le bas ne se
/// replie pas (min = max) ; [sheetFirstRow] nulle : l'en-tête de la fiche ne
/// cède pas (sa première rangée est l'en-tête entier) — les répartitions
/// d'avant `D8` (arbitrages 21 à 24).
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
  double? sheetFeatured,
  double blockFixedFloor = 0,
  double? bottomFolded,
  double? sheetFirstRow,
}) => MapLayoutInput(
  available: available,
  width: width,
  blockOverBottom: blockOverBottom,
  bandFits: bandFits,
  reticleUnderBlock: reticleUnderBlock,
  designation: designation,
  sheetOpen: sheetOpen,
  blockFixed: blockFixed,
  blockFixedFloor: blockFixedFloor,
  notices: notices,
  legend: legend,
  bottom: PieceHeights(min: bottomFolded ?? bottom, max: bottom),
  band: band,
  reticleBand: reticleBand,
  sheet: sheet,
  sheetFeatured: sheetFeatured ?? sheet.min,
  sheetFirstRow: sheetFirstRow ?? sheet.min,
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
  double? sheetFeatured,
  double blockFixedFloor = 0,
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
  sheetFeatured: sheetFeatured,
  blockFixedFloor: blockFixedFloor,
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

    test('la légende passée à 0, il manque encore 100 : replis 1, 4 et 2, '
        'fiche 250', () {
      // Bloc 150 + 50, écart, rangée 60, écart, fiche 300 : 576. La légende à
      // 0 rend 50 : 526 ; pour 426, il manque encore 100. Fiche du bas
      // ouverte, les sous-titres cèdent avant le corps (arbitrage 17) : 476 ;
      // la fiche (300, au plus bas 80) donne les 50 restants.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 426,
          sheetOpen: true,
          legend: 50,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, <int>[1, 2, 4]);
      expect(allocation.legend, 0);
      expect(allocation.blockFixed, 100);
      expect(allocation.sheet, 250);
      expect(allocation.overflows, isFalse);
    });

    test('légende nulle à l\'entrée : le repli 1 n\'a rien à prendre, il '
        'n\'est pas compté', () {
      // Bloc 150, écart, rangée 60, écart, fiche 300 : 526, pour 426. Repli
      // 4 (arbitrage 17) : 476 ; la fiche donne 50.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 426,
          sheetOpen: true,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      expect(allocation.folds, <int>[2, 4]);
      expect(allocation.sheet, 250);
    });
  });

  group('L\'ordre de repli', () {
    test('au téléphone, en mode, fiche du bas ouverte : les six replis jouent, '
        'dans l\'ordre 1, 3, 4, 5, 2, 6 (arbitrage 17 ; folds trié)', () {
      // 942 entières (partie variable comptée deux fois). Légende à 0 : 742.
      // Avis à 0 : 662. Repli 4 : 612. Repli 5 : 580. Fiche à son en-tête :
      // 360. Repli 6 : bande et bande du réticule retirées, l'écart de la
      // bande avec elles ; le bloc et la rangée, voisins, prennent un écart :
      // 100 + 8 + 60 + 8 + 80 = 256, pour 256. L'ordre de jeu, palier par
      // palier : groupe « L'ordre de jeu, palier par palier ».
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
      // max(80, 60) = 80. Entières : 150 + 2 × 140 + 56 + 80 + 8 + 300 = 874.
      // Dans l'ordre 1, 3, 4, 5, 2 : légende à 0, 674 ; avis à 0, 594 ;
      // repli 4, 544 ; repli 5, zone du bas max(48, 60) = 60, 524 ; fiche à
      // son en-tête, 304 > 256 — pas de repli 6 en wide. La partie fixe
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

    // Arbitrage 23 (2026-10-18, `D8`) : remplace « en mode, SANS fiche, bande
    // trop large : elle ne peut ni se poser ni se retirer — débordement, pas de
    // repli 6 » (R15). Une bande qui n'a pas de place, donc 0 px, se retire
    // comme au repli 6 — ni peinte, ni touchable, ni atteinte par Tab, ni
    // annoncée (la pose et la vue lisent `bandWithdrawn`).
    test(
      "panel, en mode, SANS fiche, bande trop large : elle reçoit 0 px, elle "
      "se retire comme au repli 6, avec le réticule — rien ne déborde "
      "(arbitrage 23)",
      () {
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

        expect(allocation.folds, <int>[6]);
        expect(allocation.bandWithdrawn, isTrue);
        expect(allocation.band, 0);
        expect(allocation.reticleBand, 0);
        expect(allocation.blockFixed, 150);
        expect(allocation.overflows, isFalse);
      },
    );

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

    test('en mode, avis 0 puis 40 : la fiche garde la même hauteur ; l\'avis '
        'cède avant les sous-titres, l\'indice et la fiche', () {
      // Fiche entière : 150 + 56 + 148 + 8 + 300 = 662, pour 500. Replis 3
      // (avis, s'il y en a), 4 (612), 5 (580), puis 2 (arbitrage 17) : la
      // fiche donne 80, elle garde 220.
      final MapLayoutAllocation sansAvis = allocateMapLayout(
        entree(available: 500, notices: 0),
      );
      final MapLayoutAllocation avecAvis = allocateMapLayout(
        entree(available: 500, notices: 40),
      );

      expect(sansAvis.sheet, 220);
      expect(sansAvis.folds, <int>[2, 4, 5]);
      expect(avecAvis.sheet, sansAvis.sheet);
      expect(avecAvis.notices, 0);
      expect(avecAvis.folds, <int>[2, 3, 4, 5]);
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

    test('hors mode : la fiche cède avant les avis (1, 4, 2, 3)', () {
      // Avec l'avis : 150 + 40 + 8 + 60 + 8 + 300 = 566, pour 400. Repli 4
      // (arbitrage 17) : 516 ; la fiche donne 116, les avis restent entiers.
      // Sans avis : 476 après le repli 4, la fiche donne 76.
      final MapLayoutAllocation avecAvis = allocateMapLayout(
        entree(available: 400, notices: 40, designation: false),
      );
      final MapLayoutAllocation sansAvis = allocateMapLayout(
        entree(available: 400, notices: 0, designation: false),
      );

      expect(avecAvis.notices, 40);
      expect(avecAvis.sheet, 184);
      expect(sansAvis.sheet, 224);
      expect(avecAvis.folds, <int>[2, 4]);
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

  group('Arbitrage 17 : fiche du bas ouverte, les sous-titres et l\'indice '
      'cèdent avant le corps de la fiche', () {
    /// Compact, hors mode, fiche du bas 80/300 : partie fixe 100/150, avis
    /// 40, légende 100. Entières : 150 + 140 + 8 + 60 + 8 + 300 = 666.
    MapLayoutInput horsMode(double available) => _input(
      available: available,
      sheetOpen: true,
      notices: 40,
      legend: 100,
      sheet: const PieceHeights(min: 80, max: 300),
    );

    test('hors mode, il manque 166 : la légende, puis les sous-titres, puis '
        'le corps — 1, 4, 2 ; les avis entiers', () {
      // Légende à 0 : 566, pour 500. Repli 4 : 516. La fiche donne 16 : 284.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(500));

      expect(allocation.folds, <int>[1, 2, 4]);
      expect(allocation.legend, 0);
      expect(allocation.subtitlesFolded, isTrue);
      expect(allocation.blockFixed, 100);
      expect(allocation.sheet, 284);
      expect(allocation.notices, 40);
      expect(allocation.overflows, isFalse);
    });

    test('hors mode, le surplus du repli 4 revient à la légende seule ; la '
        'fiche reste entière', () {
      // Légende à 0 : 566, pour 540. Repli 4 : 516 ; 24 de surplus.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(540));

      expect(allocation.folds, <int>[1, 4]);
      expect(allocation.legend, 24);
      expect(allocation.sheet, 300);
      expect(allocation.notices, 40);
    });

    test('hors mode, la légende suffit : le repli 4 ne joue pas', () {
      // Il manque 96 : la légende en rend 96.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(570));

      expect(allocation.folds, <int>[1]);
      expect(allocation.subtitlesFolded, isFalse);
      expect(allocation.legend, 4);
      expect(allocation.sheet, 300);
    });

    test('hors mode, jusqu\'au bout : 1, 4, 2, puis 3 — les avis cèdent les '
        'derniers', () {
      // Après 1, 4 et 2 : 100 + 40 + 8 + 60 + 8 + 80 = 296, pour 270 : les
      // avis donnent 26.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(270));

      expect(allocation.folds, <int>[1, 2, 3, 4]);
      expect(allocation.sheet, 80);
      expect(allocation.notices, 14);
      expect(allocation.overflows, isFalse);
    });

    test('en mode, bande du réticule posée : 1, 3, 4, 5, puis 2 — la fiche '
        'cède après l\'indice', () {
      // 942 entières (partie variable comptée deux fois). Légende à 0 : 742 ;
      // avis à 0 : 662 ; repli 4 : 612 ; repli 5 : 580, pour 500 : la fiche
      // donne 80, elle garde 220.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 500),
      );

      expect(allocation.folds, <int>[1, 2, 3, 4, 5]);
      expect(allocation.sheet, 220);
      expect(allocation.band, 48);
      expect(allocation.blockFixed, 100);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.overflows, isFalse);
    });

    test('en mode, le surplus du repli 4 revient aux avis, au poids double ; '
        'l\'indice et la fiche restent entiers', () {
      // Avis à 0 : 662, pour 640. Repli 4 : 612 ; 28 de surplus, 14 d'avis.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 640),
      );

      expect(allocation.folds, <int>[1, 3, 4]);
      expect(allocation.notices, 14);
      expect(allocation.hintFolded, isFalse);
      expect(allocation.band, 80);
      expect(allocation.sheet, 300);
    });

    test('en mode, le surplus du repli 5 revient aux avis ; la fiche reste '
        'entière', () {
      // Repli 4 : 612, pour 600. Repli 5 : 580 ; 20 de surplus, 10 d'avis.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _everyPiece(available: 600),
      );

      expect(allocation.folds, <int>[1, 3, 4, 5]);
      expect(allocation.notices, 10);
      expect(allocation.band, 48);
      expect(allocation.sheet, 300);
    });

    test('en mode, le repli 6 reste le dernier : après le corps, et son '
        'surplus revient aux avis d\'abord', () {
      // 1, 3, 4, 5 : 580 ; 2 : 360 ; 6 : 256, pour 264 : avis 8.
      final MapLayoutAllocation sixieme = allocateMapLayout(
        _everyPiece(available: 264),
      );
      // Pour 360, le corps suffit : pas de repli 6.
      final MapLayoutAllocation sansSixieme = allocateMapLayout(
        _everyPiece(available: 360),
      );

      expect(sixieme.folds, <int>[1, 2, 3, 4, 5, 6]);
      expect(sixieme.notices, 8);
      expect(sixieme.sheet, 80);
      expect(sansSixieme.folds, <int>[1, 2, 3, 4, 5]);
      expect(sansSixieme.bandWithdrawn, isFalse);
      expect(sansSixieme.sheet, 80);
    });

    test('en mode, bande retirée d\'emblée (bandFits faux, wide) : l\'ordre de '
        'hors mode, 1, 4, 2, 3', () {
      // Bande et réticule retirés : 150 + 140 + 8 + 60 + 8 + 300 = 666, pour
      // 500. Comme hors mode : légende, sous-titres, puis 16 de la fiche.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 500,
          width: MapLayoutWidth.wide,
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

      expect(allocation.folds, <int>[1, 2, 4, 6]);
      expect(allocation.sheet, 284);
      expect(allocation.notices, 40);
      expect(allocation.hintFolded, isFalse);
    });

    test('sans fiche du bas, l\'ordre ne change pas : 1, 3, puis 4 — fiche '
        'fermée, ou en panneau', () {
      // Bloc 150 + 140, écart, rangée 60 : 358. Pour 250 : légende et avis
      // au plus bas, 218 ; les avis reprennent 32. Pour 200 : 218 dépasse,
      // repli 4 : 168 ; les avis reprennent 32.
      MapLayoutAllocation at(double available, {bool panel = false}) =>
          allocateMapLayout(
            _input(
              available: available,
              width: panel ? MapLayoutWidth.panel : MapLayoutWidth.compact,
              sheetOpen: panel,
              notices: 40,
              legend: 100,
              sheet: panel
                  ? const PieceHeights(min: 80, max: 600)
                  : PieceHeights.none,
            ),
          );

      for (final bool panel in <bool>[false, true]) {
        final MapLayoutAllocation large = at(250, panel: panel);
        final MapLayoutAllocation etroit = at(200, panel: panel);
        expect(large.folds, <int>[1, 3]);
        expect(large.notices, 32);
        expect(large.legend, 0);
        expect(large.blockFixed, 150);
        expect(etroit.folds, <int>[1, 3, 4]);
        expect(etroit.notices, 32);
        expect(etroit.blockFixed, 100);
      }
    });
  });

  group('L\'ordre de jeu, palier par palier (arbitrage 17)', () {
    // `folds` est trié : il ne dit pas dans quel ordre les replis ont joué. Un
    // manque d'un pixel au-dessus de chaque palier le dit : seul le repli qui
    // joue à ce palier s'ajoute, ceux qui le suivent ne jouent pas.

    test('en mode, fiche du bas ouverte, bande posée : 1, 3, 4, 5, 2, 6', () {
      // Paliers : 942 → légende 742 → avis 662 → sous-titres 612 → indice 580
      // → fiche 360 → bande et réticule 256.
      MapLayoutAllocation at(double available) =>
          allocateMapLayout(_everyPiece(available: available));

      // 663 : les avis suffisent (3 avant 4 et avant 2) ; le surplus d'un
      // pixel leur revient, compté deux fois.
      final MapLayoutAllocation p3 = at(663);
      expect(p3.folds, <int>[1, 3]);
      expect(p3.notices, 0.5);
      expect(p3.subtitlesFolded, isFalse);
      expect(p3.sheet, 300);

      // 661 : les sous-titres jouent, la fiche reste entière (4 avant 2) ;
      // l'indice ne joue pas (4 avant 5). Surplus 49 : 24,5 d'avis.
      final MapLayoutAllocation p4 = at(661);
      expect(p4.folds, <int>[1, 3, 4]);
      expect(p4.hintFolded, isFalse);
      expect(p4.sheet, 300);
      expect(p4.notices, 24.5);

      // 611 : l'indice joue, la fiche reste entière (5 avant 2).
      final MapLayoutAllocation p5 = at(611);
      expect(p5.folds, <int>[1, 3, 4, 5]);
      expect(p5.sheet, 300);
      expect(p5.notices, 15.5);

      // 579 : la fiche donne un pixel ; la bande reste (2 avant 6).
      final MapLayoutAllocation p2 = at(579);
      expect(p2.folds, <int>[1, 2, 3, 4, 5]);
      expect(p2.sheet, 299);
      expect(p2.bandWithdrawn, isFalse);
      expect(p2.notices, 0);

      // 359 : le repli 6 joue, le dernier. 256 ; surplus 103, rendu aux avis
      // d'abord (au poids simple, la bande partie : 40), puis à la fiche (63).
      final MapLayoutAllocation p6 = at(359);
      expect(p6.folds, <int>[1, 2, 4, 5, 6]);
      expect(p6.bandWithdrawn, isTrue);
      expect(p6.notices, 40);
      expect(p6.sheet, 143);
      expect(p6.legend, 0);
    });

    test('hors mode, fiche du bas ouverte : 1, 4, 2, 3', () {
      // Paliers : 666 → légende 566 → sous-titres 516 → fiche 296 → avis 256.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(
          available: available,
          sheetOpen: true,
          notices: 40,
          legend: 100,
          sheet: const PieceHeights(min: 80, max: 300),
        ),
      );

      // 567 : la légende suffit, elle garde un pixel.
      final MapLayoutAllocation p1 = at(567);
      expect(p1.folds, <int>[1]);
      expect(p1.legend, 1);

      // 565 : les sous-titres jouent avant la fiche (4 avant 2) ; le surplus
      // de 49 revient à la légende.
      final MapLayoutAllocation p4 = at(565);
      expect(p4.folds, <int>[1, 4]);
      expect(p4.sheet, 300);
      expect(p4.legend, 49);

      // 515 : la fiche donne un pixel, les avis restent entiers (2 avant 3).
      final MapLayoutAllocation p2 = at(515);
      expect(p2.folds, <int>[1, 2, 4]);
      expect(p2.sheet, 299);
      expect(p2.notices, 40);

      // 295 : les avis cèdent les derniers, d'un pixel.
      final MapLayoutAllocation p3 = at(295);
      expect(p3.folds, <int>[1, 2, 3, 4]);
      expect(p3.sheet, 80);
      expect(p3.notices, 39);
    });

    test('sans fiche du bas : 1, 3, puis 4 — inchangé', () {
      // Fiche fermée : 358 → légende 258 → avis 218 → sous-titres 168.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(available: available, notices: 40, legend: 100),
      );

      // 219 : les avis suffisent (3 avant 4), ils gardent un pixel.
      final MapLayoutAllocation p3 = at(219);
      expect(p3.folds, <int>[1, 3]);
      expect(p3.subtitlesFolded, isFalse);
      expect(p3.notices, 1);

      // 217 : les sous-titres jouent ; leur surplus de 49 revient aux avis
      // (entiers, 40), puis à la légende (9).
      final MapLayoutAllocation p4 = at(217);
      expect(p4.folds, <int>[1, 4]);
      expect(p4.notices, 40);
      expect(p4.legend, 9);
    });
  });

  group('Arbitrages 18 et 19 : la fiche du bas garde sa mesure mise en avant ; '
      'la partie fixe défile jusqu\'à son plancher', () {
    /// Compact, hors mode, fiche du bas : en-tête 80, mesure mise en avant
    /// 200, entière 300 ; partie fixe 100/150, avis 40, légende 100 ; plancher
    /// 44. Paliers, dans l'ordre 1, 4, 2, 3 (arbitrage 17) : 666 → légende 566
    /// → sous-titres 516 → fiche jusqu'à sa mesure 416 → avis 376.
    MapLayoutInput horsMode(double available, {double sheetFeatured = 200}) =>
        _input(
          available: available,
          sheetOpen: true,
          notices: 40,
          legend: 100,
          sheet: const PieceHeights(min: 80, max: 300),
          sheetFeatured: sheetFeatured,
          blockFixedFloor: 44,
        );

    test(
      'le repli 2 s\'arrête à la mesure mise en avant : il manque encore 16, '
      'les avis les donnent',
      () {
        // 416 pour 400 : les avis cèdent ; 376, et leur reviennent 24. Avant
        // l'arbitrage 18, la fiche serait descendue à 184 et les avis entiers.
        final MapLayoutAllocation allocation = allocateMapLayout(horsMode(400));

        expect(allocation.folds, <int>[1, 2, 3, 4]);
        expect(allocation.sheet, 200);
        expect(allocation.notices, 24);
        expect(allocation.legend, 0);
        expect(allocation.blockFixed, 100);
        expect(allocation.overflows, isFalse);
      },
    );

    test('les six replis ne suffisent pas : la partie fixe défile, la fiche '
        'garde sa mesure mise en avant', () {
      // 376 pour 350 : la partie fixe reçoit 350 − (8 + 60 + 8 + 200) = 74,
      // au-dessus de son plancher.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(350));

      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 74);
      expect(allocation.sheet, 200);
      expect(allocation.folds, <int>[1, 2, 3, 4]);
    });

    test('la partie fixe à son plancher : le corps cède sous sa mesure mise en '
        'avant (arbitrage 19)', () {
      // Partie fixe à 44 : 44 + 8 + 60 + 8 + 200 = 320 pour 300 ; la fiche
      // donne 20, elle garde 180, au-dessus de son en-tête.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(300));

      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 44);
      expect(allocation.sheet, 180);
    });

    test('la fiche à son en-tête : la partie fixe passe sous son plancher (en '
        'deçà des quatre tailles)', () {
      // 44 + 8 + 60 + 8 + 80 = 200 pour 180 : la partie fixe reçoit le reste,
      // 24, son écart avec la rangée compris.
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(180));

      expect(allocation.overflows, isTrue);
      expect(allocation.sheet, 80);
      expect(allocation.blockFixed, 24);
    });

    test('un plancher plus haut que la partie fixe repliée ne la grandit pas : '
        'elle reste repliée, le corps cède', () {
      // Partie fixe 30/40, ni avis ni légende : 40 + 8 + 60 + 8 + 300 = 416.
      // Pour 280 : repli 4 (30), fiche à sa mesure : 306 ; la partie fixe
      // reste à 30, sous le plancher de 44 ; la fiche garde 174.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 280,
          sheetOpen: true,
          blockFixed: const PieceHeights(min: 30, max: 40),
          sheet: const PieceHeights(min: 80, max: 300),
          sheetFeatured: 200,
          blockFixedFloor: 44,
        ),
      );

      expect(allocation.overflows, isTrue);
      expect(allocation.blockFixed, 30);
      expect(allocation.sheet, 174);
    });

    test('en mode, bande posée : 1, 3, 4, 5, 2 jusqu\'à la mesure, puis 6 ; '
        'au-delà, la partie fixe défile jusqu\'à son plancher', () {
      // Paliers : 942 → … → indice 580 → fiche à sa mesure (200) 480 → bande
      // et réticule retirés 376. Pour 400, le repli 6 joue (il ne jouait pas
      // avant l'arbitrage 18 : la fiche descendait à 80) ; surplus 24, aux
      // avis, au poids simple. Pour 350, la partie fixe reçoit 74.
      final MapLayoutAllocation joue = allocateMapLayout(
        _everyPiece(available: 400, sheetFeatured: 200, blockFixedFloor: 48),
      );
      final MapLayoutAllocation defile = allocateMapLayout(
        _everyPiece(available: 350, sheetFeatured: 200, blockFixedFloor: 48),
      );

      expect(joue.folds, <int>[1, 2, 3, 4, 5, 6]);
      expect(joue.sheet, 200);
      expect(joue.notices, 24);
      expect(joue.bandWithdrawn, isTrue);
      expect(joue.overflows, isFalse);
      expect(defile.overflows, isTrue);
      expect(defile.blockFixed, 74);
      expect(defile.sheet, 200);
      expect(defile.bandWithdrawn, isTrue);
    });

    test('une mesure mise en avant hors de [en-tête ; fiche entière] y est '
        'ramenée', () {
      // Sous l'en-tête : comme l'en-tête. Au-dessus de la fiche entière : la
      // fiche ne cède rien au repli 2 ; à 450, après 1, 4 et 3 (476), la
      // partie fixe reçoit 450 − (8 + 60 + 8 + 300) = 74.
      expect(
        allocateMapLayout(horsMode(400, sheetFeatured: 20)),
        allocateMapLayout(horsMode(400, sheetFeatured: 80)),
      );
      final MapLayoutAllocation entiere = allocateMapLayout(
        horsMode(450, sheetFeatured: 999),
      );
      expect(entiere.sheet, 300);
      expect(entiere.folds, <int>[1, 3, 4]);
      expect(entiere.overflows, isTrue);
      expect(entiere.blockFixed, 74);
    });

    test(
      'wide, bloc étroit : la colonne, qui ne cède jamais, plafonne la fiche '
      'sous sa mesure mise en avant — la fiche s\'y arrête, rien ne défile '
      'pour elle',
      () {
        // Plafond 584 − 288 − 8 = 288, sous la mesure de 300 : la fiche à 288,
        // comme avant ; le bloc tient (110 + 60, écart, 288 = 466).
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
            sheetFeatured: 300,
            blockFixedFloor: 44,
          ),
        );

        expect(allocation.sheet, 288);
        expect(allocation.folds, <int>[2]);
        expect(allocation.blockFixed, 110);
        expect(allocation.legend, 60);
        expect(allocation.overflows, isFalse);
      },
    );

    test('sans fiche du bas (fermée, ou en panneau), mesure et plancher ne '
        'changent rien', () {
      for (double available = 0; available <= 700; available += 7) {
        for (final bool panel in <bool>[false, true]) {
          MapLayoutAllocation at({required bool d7}) => allocateMapLayout(
            _input(
              available: available,
              width: panel ? MapLayoutWidth.panel : MapLayoutWidth.compact,
              sheetOpen: panel,
              notices: 40,
              legend: 100,
              sheet: panel
                  ? const PieceHeights(min: 80, max: 600)
                  : PieceHeights.none,
              sheetFeatured: d7 && panel ? 200 : null,
              blockFixedFloor: d7 ? 44 : 0,
            ),
          );
          expect(
            at(d7: true),
            at(d7: false),
            reason: '${panel ? 'panneau' : 'sans fiche'}, $available',
          );
        }
      }
    });

    test('une fiche sans autre mesure que son en-tête : le plancher ne change '
        'rien, la répartition est celle d\'avant D7', () {
      for (double available = 0; available <= 960; available += 7) {
        expect(
          allocateMapLayout(
            _everyPiece(available: available, blockFixedFloor: 48),
          ),
          allocateMapLayout(_everyPiece(available: available)),
          reason: 'en mode, $available',
        );
        expect(
          allocateMapLayout(horsMode(available, sheetFeatured: 80)),
          allocateMapLayout(
            _input(
              available: available,
              sheetOpen: true,
              notices: 40,
              legend: 100,
              sheet: const PieceHeights(min: 80, max: 300),
            ),
          ),
          reason: 'hors mode, $available',
        );
      }
    });

    test('rien de négatif : available = 0, la fiche à son en-tête, la partie '
        'fixe à 0', () {
      final MapLayoutAllocation allocation = allocateMapLayout(horsMode(0));

      expect(allocation.overflows, isTrue);
      expect(allocation.sheet, 80);
      expect(allocation.blockFixed, 0);
    });
  });

  group('Arbitrages 21 à 24 (D8) : ce qui cède pour la partie fixe', () {
    // Ce qui cède pour elle, quand les six replis ne suffisent pas et qu'elle
    // est à son plancher, la fiche du bas à son en-tête : 1. la bande du
    // bouton et le réticule (repli 6 étendu, en mode même sans fiche) ; 2. à
    // la largeur de la colonne, la colonne du bas, qui défile jusqu'à sa
    // hauteur repliée (l'attribution reste) ; 3. l'en-tête de la fiche,
    // jamais sous sa première rangée. Au-delà seulement (garde-fou c), la
    // partie fixe passe sous son plancher.

    /// Wide, sans fiche, hors mode : partie fixe 104/140, avis 137, légende
    /// 63, colonne entière 300, repliée 28 (l'attribution et son écart),
    /// plancher 48 — les hauteurs de 640 × 360 à 100 % (Roboto, Android).
    MapLayoutInput colonne(double available) => _input(
      available: available,
      width: MapLayoutWidth.wide,
      blockFixed: const PieceHeights(min: 104, max: 140),
      notices: 137,
      legend: 63,
      bottom: 300,
      bottomFolded: 28,
      blockFixedFloor: 48,
    );

    test('sans fiche, à la largeur de la colonne : la colonne cède jusqu’à '
        'rendre son plancher à la partie fixe, pas plus (arbitrage 24)', () {
      // Replis 1, 3, 4 : 104 + 8 + 300 = 412 pour 344. Partie fixe à 48 :
      // 356 ; la colonne donne 12, elle garde 288.
      final MapLayoutAllocation allocation = allocateMapLayout(colonne(344));

      expect(allocation.folds, <int>[1, 3, 4]);
      expect(allocation.blockFixed, 48);
      expect(allocation.bottom, 288);
      expect(allocation.bandWithdrawn, isFalse);
      expect(allocation.overflows, isTrue);
    });

    test(
      'sans fiche, la place au-dessus du plancher : la partie fixe reçoit ce '
      'qui reste, la colonne reste entière',
      () {
        // 412 pour 400 : la partie fixe reçoit 400 − 308 = 92.
        final MapLayoutAllocation allocation = allocateMapLayout(colonne(400));

        expect(allocation.blockFixed, 92);
        expect(allocation.bottom, 300);
        expect(allocation.overflows, isTrue);
      },
    );

    test(
      'la colonne à sa hauteur repliée ne suffit pas : la partie fixe passe '
      'sous son plancher (garde-fou c), la colonne garde son attribution',
      () {
        // 48 + 8 + 28 = 84 pour 60 : la partie fixe reçoit 60 − 36 = 24.
        final MapLayoutAllocation allocation = allocateMapLayout(colonne(60));

        expect(allocation.bottom, 28);
        expect(allocation.blockFixed, 24);
        expect(allocation.overflows, isTrue);
      },
    );

    test('au téléphone, la rangée ne cède jamais, même repliable', () {
      // Compact, rangée 60 (repliée 20) : 100 + 8 + 60 = 168 pour 100 ; la
      // partie fixe reçoit 32, sous son plancher de 44 ; la rangée reste
      // entière.
      final MapLayoutAllocation allocation = allocateMapLayout(
        _input(
          available: 100,
          bottomFolded: 20,
          legend: 100,
          blockFixedFloor: 44,
        ),
      );

      expect(allocation.bottom, 60);
      expect(allocation.blockFixed, 32);
      expect(allocation.overflows, isTrue);
    });

    test('en mode, sans fiche, au téléphone : la bande et le réticule se '
        'retirent avant que la partie fixe passe sous son plancher (repli 6 '
        'étendu, arbitrage 21)', () {
      // Repris de « au téléphone, en mode, fiche fermée : pas de repli 6 » :
      // après 1, 3, 4, 5, la partie fixe recevait 28. Plancher 44 : bande et
      // réticule retirés, 100 + 8 + 60 = 168 tient dans 200 ; le surplus de 32
      // revient aux avis, au poids simple.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(
          available: available,
          designation: true,
          legend: 100,
          notices: 40,
          reticleBand: 56,
          band: const PieceHeights(min: 48, max: 80),
          blockFixedFloor: 44,
        ),
      );

      final MapLayoutAllocation retire = at(200);
      expect(retire.folds, <int>[1, 3, 4, 5, 6]);
      expect(retire.bandWithdrawn, isTrue);
      expect(retire.band, 0);
      expect(retire.reticleBand, 0);
      expect(retire.blockFixed, 100);
      expect(retire.notices, 32);
      expect(retire.overflows, isFalse);

      // 230 : la partie fixe reçoit 230 − 172 = 58, au-dessus de son
      // plancher : la bande reste.
      final MapLayoutAllocation garde = at(230);
      expect(garde.folds, <int>[1, 3, 4, 5]);
      expect(garde.bandWithdrawn, isFalse);
      expect(garde.blockFixed, 58);
    });

    test(
      'en mode, sans fiche, à la largeur de la colonne : d’abord la bande et '
      'le réticule, puis la colonne (arbitrage 24)',
      () {
        // 640 × 360 à 100 %, en mode : bande 52/88 à côté de la colonne, bande
        // du réticule 64. Replis 1, 3, 4 (le 5 ne libère rien à côté de la
        // colonne) : 104 + 64 + 300 = 468 pour 344. Partie fixe à 48 : 412,
        // encore trop — bande et réticule retirés : 104 + 8 + 300 = 412 ; la
        // partie fixe à 48 : 356 ; la colonne donne 12.
        final MapLayoutAllocation allocation = allocateMapLayout(
          _input(
            available: 344,
            width: MapLayoutWidth.wide,
            designation: true,
            blockFixed: const PieceHeights(min: 104, max: 140),
            notices: 137,
            legend: 63,
            bottom: 300,
            bottomFolded: 28,
            band: const PieceHeights(min: 52, max: 88),
            reticleBand: 64,
            blockFixedFloor: 48,
          ),
        );

        expect(allocation.folds, <int>[1, 3, 4, 6]);
        expect(allocation.bandWithdrawn, isTrue);
        expect(allocation.band, 0);
        expect(allocation.reticleBand, 0);
        expect(allocation.blockFixed, 48);
        expect(allocation.bottom, 288);
      },
    );

    test('fiche du bas ouverte, en mode, à la largeur de la colonne : la bande '
        'et le réticule, puis la colonne, puis l’en-tête de la fiche, jamais '
        'sous sa première rangée — palier par palier', () {
      // Partie fixe 100/150, colonne 300 (repliée 28), bande 48/80, bande du
      // réticule 56, fiche : en-tête 108 (sa première rangée 60), entière
      // 400 ; plancher 44. Après les replis 4 et 2 (le 5 ne libère rien) :
      // 100 + 56 + 300 + 8 + 108 = 572. La partie fixe à 44 : 516.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(
          available: available,
          width: MapLayoutWidth.wide,
          designation: true,
          sheetOpen: true,
          bottom: 300,
          bottomFolded: 28,
          band: const PieceHeights(min: 48, max: 80),
          reticleBand: 56,
          sheet: const PieceHeights(min: 108, max: 400),
          sheetFirstRow: 60,
          blockFixedFloor: 44,
        ),
      );

      // 516 : la partie fixe à son plancher suffit ; la bande reste.
      final MapLayoutAllocation plancher = at(516);
      expect(plancher.folds, <int>[2, 4]);
      expect(plancher.bandWithdrawn, isFalse);
      expect(plancher.blockFixed, 44);
      expect(plancher.bottom, 300);

      // 515 : bande et réticule retirés (100 + 8 + 300 + 8 + 108 = 524), le
      // surplus revient à la partie fixe : 91 ; la colonne reste entière.
      final MapLayoutAllocation bande = at(515);
      expect(bande.folds, <int>[2, 4, 6]);
      expect(bande.bandWithdrawn, isTrue);
      expect(bande.blockFixed, 91);
      expect(bande.bottom, 300);
      expect(bande.sheet, 108);

      // 467 : la partie fixe à 44 (468) — la colonne donne 1.
      final MapLayoutAllocation colonne = at(467);
      expect(colonne.blockFixed, 44);
      expect(colonne.bottom, 299);
      expect(colonne.sheet, 108);

      // 195 : la colonne à sa hauteur repliée (196) — l'en-tête donne 1.
      final MapLayoutAllocation enTete = at(195);
      expect(enTete.bottom, 28);
      expect(enTete.sheet, 107);
      expect(enTete.blockFixed, 44);

      // 147 : l'en-tête à sa première rangée (148) — la partie fixe passe
      // sous son plancher (garde-fou c).
      final MapLayoutAllocation garde = at(147);
      expect(garde.sheet, 60);
      expect(garde.bottom, 28);
      expect(garde.blockFixed, 43);
      expect(garde.overflows, isTrue);
    });

    test('fiche du bas ouverte, hors mode, au téléphone : la rangée ne cède '
        'pas, l’en-tête de la fiche cède jusqu’à sa première rangée, jamais '
        'dessous', () {
      // 360 × 300 à 200 % : partie fixe 341/485, avis 344, légende 216,
      // rangée 122, fiche : en-tête 162 (première rangée 68), mise en avant
      // 527, entière 946 ; plancher 48. La partie fixe à 48, la fiche à son
      // en-tête : 48 + 8 + 122 + 8 + 162 = 348 pour 292 — l'en-tête donne 56.
      MapLayoutAllocation at(double available) => allocateMapLayout(
        _input(
          available: available,
          sheetOpen: true,
          blockFixed: const PieceHeights(min: 341, max: 485),
          notices: 344,
          legend: 216,
          bottom: 122,
          sheet: const PieceHeights(min: 162, max: 946),
          sheetFeatured: 527,
          sheetFirstRow: 68,
          blockFixedFloor: 48,
        ),
      );

      final MapLayoutAllocation cede = at(292);
      expect(cede.folds, <int>[1, 2, 3, 4]);
      expect(cede.blockFixed, 48);
      expect(cede.sheet, 106);
      expect(cede.bottom, 122);
      expect(cede.overflows, isTrue);

      // 200 : l'en-tête à sa première rangée, 8 + 122 + 8 + 68 = 206 sans la
      // partie fixe — elle reçoit 0 (garde-fou c), l'en-tête garde 68.
      final MapLayoutAllocation garde = at(200);
      expect(garde.sheet, 68);
      expect(garde.blockFixed, 0);
    });

    test(
      'à la largeur de la colonne, bloc étroit : l’en-tête de la fiche passe '
      'devant la colonne, qui cède au-dessus de lui (arbitrage 22)',
      () {
        // Repris de « 640 × 360 : l'en-tête de fiche et la colonne ne tiennent
        // pas ensemble » : la fiche à son en-tête (70) ; la colonne (288,
        // repliée 28) reçoit 344 − 70 − 8 = 266 au lieu de descendre sur lui.
        final MapLayoutAllocation allocation = allocateMapLayout(
          _input(
            available: 344,
            width: MapLayoutWidth.wide,
            blockOverBottom: false,
            sheetOpen: true,
            blockFixed: const PieceHeights(min: 90, max: 110),
            legend: 60,
            bottom: 288,
            bottomFolded: 28,
            sheet: const PieceHeights(min: 70, max: 320),
            blockFixedFloor: 48,
          ),
        );

        expect(allocation.sheet, 70);
        expect(allocation.bottom, 266);
        expect(allocation.blockFixed, 110);
        expect(allocation.legend, 60);
        expect(allocation.overflows, isTrue);
      },
    );

    test('le bas posé compte dans l’égalité des répartitions', () {
      expect(
        allocateMapLayout(colonne(344)),
        isNot(allocateMapLayout(colonne(345))),
      );
      expect(allocateMapLayout(colonne(344)), allocateMapLayout(colonne(344)));
      expect(
        allocateMapLayout(colonne(344)).toString(),
        contains('bottom: 288.0'),
      );
    });
  });
}
