// La répartition de la hauteur de la carte visible (`S5` d'Ergonomie, spec
// § 5.6 et § 6.5, arbitrage 11 du commanditaire) : une fonction pure, qui
// reçoit les hauteurs intrinsèques des pièces et la hauteur disponible, et
// rend la hauteur de chaque pièce en jouant les six replis dans l'ordre
// arbitré. Elle ne connaît aucune taille d'écran : aucun seuil de taille n'y
// décide d'un repli, seules les hauteurs mesurées le décident.
//
// Arbitrages du commanditaire du 2026-10-18, relevés par la porte de
// faisabilité (`S6`) : à 360 × 640 et 200 %, là où l'ordre de repli ne suffit
// pas, la partie fixe défile (13) — `overflows`, aucun repli de plus ; le
// repli 6 s'étend au-delà du téléphone (14) — en mode, fiche ouverte, une
// bande du bouton qui ne tient pas en largeur à côté de la colonne du bas se
// retire avec le réticule (`MapLayoutInput.bandFits`). Arbitrage 15 (« le
// réticule reste fixe ») : en mode, bande du réticule posée et fiche du bas
// comptée (hors panel), les replis continus jouent dans l'ordre 1 (légende),
// 3 (avis), 2 (corps de la fiche), et le surplus d'un repli tout ou rien
// revient à la fiche, puis aux avis, puis à la légende : la fiche, qui place
// la bande et donc le réticule, ne dépend plus de la partie variable.
// Partout ailleurs : 1, 2, 3, et le surplus aux avis, à la fiche, à la
// légende. `folds` garde les numéros, en ordre croissant.
//
// Aucun import, ni Flutter ni `dart:ui` : elle s'éprouve seule, sur des
// nombres. Le `RenderObject` de la carte (`D1`) lit les intrinsèques de ses
// enfants, l'appelle, et pose chaque enfant avec la hauteur rendue.

/// Largeur de fenêtre à partir de laquelle le bloc de lecture se pose en haut
/// à gauche et le bas de la carte en colonne (spec § 5.1). Constante nommée,
/// révisable sur constat d'écran : c'est une largeur, pas un seuil de repli.
const double mapWideLayoutMinWidth = 600;

/// Largeur de fenêtre à partir de laquelle la fiche se pose en panneau
/// latéral (spec § 5.1). Révisable sur constat d'écran.
const double mapSidePanelMinWidth = 800;

/// Largeur du panneau latéral (spec § 5.1, § 6.5).
const double mapSidePanelWidth = 380;

/// Largeur maximale du bloc de lecture au-delà du téléphone (spec § 5.1).
const double mapReadingBlockMaxWidth = 480;

/// Les trois largeurs de la carte (spec § 5.1). Une énumération de mise en
/// page, pas une nomenclature venue d'une API : un `switch` exhaustif suffit.
enum MapLayoutWidth {
  /// Moins de [mapWideLayoutMinWidth] : bloc sur toute la largeur, bas en
  /// rangée, fiche du bas.
  compact,

  /// De [mapWideLayoutMinWidth] à moins de [mapSidePanelMinWidth] : bloc en
  /// haut à gauche, bas en colonne, fiche du bas.
  wide,

  /// [mapSidePanelMinWidth] et plus : la fiche en panneau latéral, à côté.
  panel,
}

/// La largeur de mise en page d'une fenêtre de [width] px de large.
MapLayoutWidth mapLayoutWidthFor(double width) {
  if (width < mapWideLayoutMinWidth) return MapLayoutWidth.compact;
  if (width < mapSidePanelMinWidth) return MapLayoutWidth.wide;
  return MapLayoutWidth.panel;
}

/// Les largeurs des pièces de la carte (spec § 5.1, § 5.5, § 6.5), et les deux
/// drapeaux de [MapLayoutInput] qui en dépendent. Rendues par
/// [mapLayoutWidths], la seule source de ces règles : la mise en page de la
/// carte (`D1`) pose ses enfants à ces largeurs, la porte de faisabilité
/// (`S6`, `mesurerPieces`) y mesure les vraies pièces.
final class MapLayoutWidths {
  const MapLayoutWidths({
    required this.width,
    required this.visible,
    required this.block,
    required this.bottom,
    required this.band,
    required this.sheet,
    required this.blockOverBottom,
    required this.bandFits,
    required this.reticleUnderBlock,
  });

  final MapLayoutWidth width;

  /// La carte visible : la surface moins le panneau latéral quand une fiche y
  /// est ouverte ; toute la surface sinon (fiche du bas, ou aucune).
  final double visible;

  /// Le bloc de lecture : la carte visible moins deux marges en compact ;
  /// au-delà, [mapReadingBlockMaxWidth] au plus.
  final double block;

  /// Le bas : la rangée, la surface moins deux marges, en compact ; au-delà,
  /// la colonne à sa largeur intrinsèque maximale, bornée à la carte visible
  /// moins deux marges (l'attribution passe alors à la ligne).
  final double bottom;

  /// La bande du bouton : au-dessus de la rangée, la carte visible moins deux
  /// marges, en compact ; au-delà, à gauche de la colonne — la carte visible
  /// moins la marge gauche, l'écart avec la colonne, la colonne et sa marge
  /// droite. Jamais négative : une bande qui ne tient pas vaut 0, et
  /// [bandFits] le dit.
  final double band;

  /// La fiche : toute la surface en fiche du bas, [mapSidePanelWidth] en
  /// panneau.
  final double sheet;

  /// [MapLayoutInput.blockOverBottom] : toujours vrai en compact ; au-delà,
  /// le bloc et la colonne se recouvrent en largeur, écart compris —
  /// `marge + bloc + marge > carte visible − marge − colonne`.
  final bool blockOverBottom;

  /// [MapLayoutInput.bandFits] : toujours vrai en compact ; au-delà, la
  /// largeur laissée à la bande atteint sa largeur intrinsèque minimale.
  final bool bandFits;

  /// [MapLayoutInput.reticleUnderBlock] : toujours vrai en compact (bloc
  /// pleine largeur) ; au-delà, l'étendue horizontale du réticule — centre
  /// de la carte visible ± `reticleWidth / 2` — recoupe celle du bloc
  /// [marge ; marge + bloc]. Bord à bord n'est pas un recouvrement.
  final bool reticleUnderBlock;
}

/// Les largeurs des pièces dans une fenêtre de [width] px de large (la
/// largeur qui choisit [MapLayoutWidth]). Les pièces se posent dans la zone
/// sûre, large de [safeWidth] px (la fenêtre moins les marges système
/// latérales ; [width] par défaut).
///
/// [sheetOpen] : une fiche est ouverte. [bottomMaxIntrinsicWidth] : la
/// largeur intrinsèque maximale du bas, attribution comprise (lue au-delà du
/// téléphone seulement). [bandMinIntrinsicWidth] : la largeur intrinsèque
/// minimale de la bande du bouton. [reticleWidth] : la largeur du réticule.
/// [padding] : la marge au bord de la carte visible, et l'écart entre la bande
/// et la colonne.
///
/// Aucune largeur rendue n'est négative.
MapLayoutWidths mapLayoutWidths({
  required double width,
  required bool sheetOpen,
  required double bottomMaxIntrinsicWidth,
  required double bandMinIntrinsicWidth,
  required double padding,
  required double reticleWidth,
  double? safeWidth,
}) {
  final MapLayoutWidth layout = mapLayoutWidthFor(width);
  final double surface = safeWidth ?? width;
  final double visible = switch (layout) {
    MapLayoutWidth.panel when sheetOpen => surface - mapSidePanelWidth,
    MapLayoutWidth.compact ||
    MapLayoutWidth.wide ||
    MapLayoutWidth.panel => surface,
  };
  final double block = switch (layout) {
    MapLayoutWidth.compact => visible - 2 * padding,
    MapLayoutWidth.wide || MapLayoutWidth.panel => _min(
      mapReadingBlockMaxWidth,
      visible - 2 * padding,
    ),
  };
  final double bottom = switch (layout) {
    MapLayoutWidth.compact => surface - 2 * padding,
    MapLayoutWidth.wide || MapLayoutWidth.panel => _min(
      bottomMaxIntrinsicWidth,
      visible - 2 * padding,
    ),
  };
  final double band = switch (layout) {
    MapLayoutWidth.compact => visible - 2 * padding,
    MapLayoutWidth.wide ||
    MapLayoutWidth.panel => visible - 3 * padding - bottom,
  };
  final double sheet = switch (layout) {
    MapLayoutWidth.compact || MapLayoutWidth.wide => surface,
    MapLayoutWidth.panel => mapSidePanelWidth,
  };
  final bool compact = switch (layout) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => false,
  };
  return MapLayoutWidths(
    width: layout,
    visible: _nonNegative(visible),
    block: _nonNegative(block),
    bottom: _nonNegative(bottom),
    band: _nonNegative(band),
    sheet: _nonNegative(sheet),
    blockOverBottom:
        compact || padding + block + padding > visible - padding - bottom,
    bandFits: compact || band >= bandMinIntrinsicWidth,
    reticleUnderBlock:
        compact ||
        (visible / 2 - reticleWidth / 2 < padding + block &&
            visible / 2 + reticleWidth / 2 > padding),
  );
}

/// [MapLayoutInput.available] : la hauteur de la zone sûre, [safeHeight],
/// moins les marges de surcouche. Deux marges, en haut et en bas de la carte
/// visible ; une seule quand une fiche du BAS est ouverte (compact, wide) :
/// collée au bas de la zone sûre, elle n'a pas de marge sous elle, et la marge
/// basse de la carte visible est l'écart qui la sépare du bas. Le panneau
/// latéral est à côté : deux marges. Jamais négative. La seule source de cette
/// règle : la mise en page de la carte (`D1`) et la porte de faisabilité
/// (`S6`, `mesurerPieces`) l'appellent toutes deux.
double mapLayoutAvailableHeight({
  required double safeHeight,
  required MapLayoutWidth width,
  required bool sheetOpen,
  required double padding,
}) {
  final bool bottomSheet =
      sheetOpen &&
      switch (width) {
        MapLayoutWidth.compact || MapLayoutWidth.wide => true,
        MapLayoutWidth.panel => false,
      };
  return _nonNegative(safeHeight - (bottomSheet ? 1 : 2) * padding);
}

/// Les deux hauteurs intrinsèques d'une pièce, à sa largeur : [min], sa
/// hauteur repliée ; [max], sa hauteur entière (note d'architecture, 1).
final class PieceHeights {
  const PieceHeights({required this.min, required this.max});

  /// Une pièce qui ne se replie pas : min = max.
  const PieceHeights.fixed(double height) : min = height, max = height;

  /// Une pièce absente.
  static const PieceHeights none = PieceHeights.fixed(0);

  final double min;
  final double max;
}

/// Ce que [allocateMapLayout] répartit. Toutes les hauteurs sont mesurées à
/// la largeur réelle de la pièce ; une hauteur négative compte pour 0.
final class MapLayoutInput {
  const MapLayoutInput({
    required this.available,
    required this.width,
    required this.blockOverBottom,
    required this.bandFits,
    required this.reticleUnderBlock,
    required this.designation,
    required this.sheetOpen,
    required this.blockFixed,
    required this.notices,
    required this.legend,
    required this.bottom,
    required this.band,
    required this.reticleBand,
    required this.sheet,
    required this.gap,
  });

  /// La hauteur de la zone sûre moins les marges de surcouche :
  /// [mapLayoutAvailableHeight].
  final double available;

  final MapLayoutWidth width;

  /// Le bloc et le bas se superposent en largeur : toujours en compact (où ce
  /// drapeau n'est pas lu) ; au-delà, quand la largeur du bloc atteint la
  /// colonne. Faux, le bas n'entre pas dans la somme, mais il borne quand même
  /// (règle : [allocateMapLayout]).
  final bool blockOverBottom;

  /// La bande du bouton tient en largeur : faux quand, au-delà du téléphone,
  /// la largeur laissée à la bande à côté de la colonne du bas est inférieure
  /// à sa largeur intrinsèque minimale ; toujours vrai en compact, où la bande
  /// passe au-dessus de la rangée. Hors mode, non lu.
  ///
  /// Quand il est faux :
  /// - en mode, fiche ouverte, la bande et la bande du réticule sont retirées
  ///   d'emblée, à toute largeur (repli 6 étendu, arbitrage 14 du
  ///   commanditaire, 2026-10-18) ;
  /// - en mode sans fiche, la bande ne peut ni se poser ni se retirer :
  ///   [MapLayoutAllocation.overflows] ; l'appelant passe [band] à
  ///   [PieceHeights.none] — la bande n'a pas de place.
  final bool bandFits;

  /// Le réticule passe sous le bloc en largeur ([MapLayoutWidths]) : en
  /// mode, quand la bande du réticule est là ET qu'il passe sous le bloc, la
  /// partie variable (avis + légende) compte DEUX FOIS — elle s'arrête
  /// au-dessus de la bande du réticule, pour que rien ne se peigne sur lui
  /// (spec § 5.5) ; sinon, une fois (spec § 5.6 : rien ne cède tant que
  /// tout tient). Hors mode, non lu.
  final bool reticleUnderBlock;

  /// Le mode « Restrictions » : bande du bouton et bande du réticule posées.
  /// Hors mode, l'appelant passe [band] et [reticleBand] nuls.
  final bool designation;

  /// Une fiche est ouverte. Seul le repli 6 le lit ; une fiche fermée se
  /// passe en [PieceHeights.none].
  final bool sheetOpen;

  /// La partie fixe du bloc : titres seuls ([PieceHeights.min]) ou avec les
  /// sous-titres ([PieceHeights.max]).
  final PieceHeights blockFixed;

  /// Les avis : une seule hauteur, ils cèdent en défilant.
  final double notices;

  /// La légende : une seule hauteur, elle cède en défilant.
  final double legend;

  /// Le bas de la carte (rangée ou colonne, attribution) : ne cède jamais.
  final double bottom;

  /// La bande du bouton de désignation : pilule seule ou pilule et indice.
  final PieceHeights band;

  /// La bande du réticule : le réticule et sa marge (spec § 5.6). Elle porte
  /// ses marges : aucun écart de part et d'autre.
  final double reticleBand;

  /// La fiche : en-tête seul ou fiche entière. En panel, non comptée : elle
  /// est à côté.
  final PieceHeights sheet;

  /// L'écart entre deux groupes non nuls, et entre la bande et la rangée en
  /// compact (règle complète : [allocateMapLayout]).
  final double gap;
}

/// La hauteur rendue à chaque pièce, et les replis joués. Le bas ne figure
/// pas : il ne cède jamais.
final class MapLayoutAllocation {
  const MapLayoutAllocation({
    required this.blockFixed,
    required this.notices,
    required this.legend,
    required this.sheet,
    required this.band,
    required this.reticleBand,
    required this.subtitlesFolded,
    required this.hintFolded,
    required this.bandWithdrawn,
    required this.overflows,
    required this.folds,
  });

  final double blockFixed;
  final double notices;
  final double legend;

  /// En panel, la hauteur entière de la fiche, non répartie : elle est à côté.
  final double sheet;

  final double band;
  final double reticleBand;

  /// Repli 4 : la partie fixe passe à sa hauteur repliée.
  final bool subtitlesFolded;

  /// Repli 5 : la bande passe à sa pilule seule.
  final bool hintFolded;

  /// Repli 6 : bande et bande du réticule retirées — faute de hauteur au
  /// téléphone, ou faute de largeur, fiche ouverte, à toute largeur
  /// (arbitrage 14).
  final bool bandWithdrawn;

  /// La place ne suffit pas, en HAUTEUR ou en LARGEUR. Trois causes :
  /// - hauteur : même après les six replis, la somme dépasse la hauteur
  ///   disponible — la partie fixe reçoit ce qui reste et défilera ;
  /// - hauteur : la colonne du bas, qui ne cède jamais, ne tient pas avec
  ///   l'en-tête de la fiche du bas (wide, bloc étroit) ou seule (panneau, ou
  ///   sans fiche) ;
  /// - largeur : en mode sans fiche, la bande ne tient pas
  ///   ([MapLayoutInput.bandFits] faux) et ne peut ni se poser ni se retirer.
  /// Dans ces deux derniers cas, le reste est réparti comme d'habitude. `overflows` ne dit donc pas, à lui seul, que la partie
  /// fixe est rognée. Aux quatre tailles, il ne se rencontre qu'à 360 × 640
  /// et 200 %, où la partie fixe qui défile est acceptée (arbitrage 13 du
  /// commanditaire, 2026-10-18).
  final bool overflows;

  /// Les replis en vigueur dans la répartition rendue, dans l'ordre :
  /// sous-ensemble de 1 à 6. Un repli qui n'a rien pris n'y est pas.
  final List<int> folds;

  @override
  bool operator ==(Object other) =>
      other is MapLayoutAllocation &&
      other.blockFixed == blockFixed &&
      other.notices == notices &&
      other.legend == legend &&
      other.sheet == sheet &&
      other.band == band &&
      other.reticleBand == reticleBand &&
      other.subtitlesFolded == subtitlesFolded &&
      other.hintFolded == hintFolded &&
      other.bandWithdrawn == bandWithdrawn &&
      other.overflows == overflows &&
      _sameFolds(other.folds, folds);

  @override
  int get hashCode => Object.hash(
    blockFixed,
    notices,
    legend,
    sheet,
    band,
    reticleBand,
    subtitlesFolded,
    hintFolded,
    bandWithdrawn,
    overflows,
    Object.hashAll(folds),
  );

  @override
  String toString() =>
      'MapLayoutAllocation(blockFixed: $blockFixed, notices: $notices, '
      'legend: $legend, sheet: $sheet, band: $band, '
      'reticleBand: $reticleBand, folds: $folds, overflows: $overflows)';
}

/// Répartit [MapLayoutInput.available] entre les pièces de la carte visible.
///
/// Les écarts se comptent par groupe, du haut vers le bas :
/// [bloc = partie fixe + avis + légende] · [bande du réticule] ·
/// [zone du bas : en compact, bande + gap + rangée quand les deux sont non
/// nulles ; au-delà, max(bande, blockOverBottom ? bas : 0)] ·
/// [fiche, hors panel].
/// Un [MapLayoutInput.gap] entre deux groupes consécutifs non nuls, sauf
/// quand l'un d'eux est la bande du réticule (elle porte ses marges). Aucun
/// écart dans le bloc (une carte continue). Un groupe tombé à 0 — la bande du
/// réticule retirée par le repli 6, par exemple — n'a plus d'écart, et ses
/// deux voisins deviennent consécutifs.
///
/// En mode, tant que la bande du réticule est là ET que le réticule passe
/// sous le bloc en largeur ([MapLayoutInput.reticleUnderBlock]), la partie
/// variable du bloc (avis + légende) compte DEUX FOIS dans la somme
/// (amendement de `D1`, spec § 5.5) : le réticule est au milieu de [bas de la
/// partie fixe ; haut de la bande], et avis et légende s'arrêtent au-dessus de
/// la bande du réticule pour que rien ne se peigne sur lui — avec H cette
/// hauteur et R la bande du réticule, V ≤ (H − R) / 2. Les replis 1 et 3
/// prennent donc la moitié de ce qui manque, et le surplus leur revient au
/// même poids. Hors mode, réticule à côté du bloc (rien ne cède tant que tout
/// tient, spec § 5.6) ou bande retirée (repli 6), elle compte une fois.
///
/// Le bas hors de la somme (au-delà du téléphone, `blockOverBottom` faux) ne
/// cède pas pour autant (spec § 5.6, § 6.5) :
/// - en wide, fiche du bas ouverte, il se pose au-dessus d'elle et la
///   plafonne avant toute répartition : la fiche reçoit au plus
///   `available − bas − gap`. Un plafond qui la réduit est le repli 2 ; un
///   plafond sous son en-tête ([PieceHeights.min]) donne `overflows`, la fiche
///   à son en-tête, et le reste se répartit comme si de rien n'était ;
/// - sans fiche du bas (panel, ou fiche fermée), un bas plus haut que
///   `available` donne `overflows`.
/// La somme reste linéaire : aucun max(bloc, bas) n'y entre.
///
/// Tout au plus haut d'abord. Puis, si la somme dépasse la hauteur
/// disponible, les replis jouent dans l'ordre (spec § 5.6), chacun seulement
/// s'il le faut et seulement de ce qu'il faut :
/// 1. la légende, 2. la fiche jusqu'à son en-tête, 3. les avis — par degrés ;
/// 4. les sous-titres, 5. l'indice, 6. au téléphone, en mode, fiche ouverte,
///    la bande et le réticule — tout ou rien, et seulement s'ils libèrent une
///    hauteur.
/// Repli 6 étendu (arbitrage 14 du commanditaire, 2026-10-18) : en mode,
/// fiche ouverte, une bande qui ne tient pas en largeur
/// ([MapLayoutInput.bandFits] faux) est retirée d'emblée avec la bande du
/// réticule, à toute largeur, avant toute répartition : le repli 6 est alors
/// en vigueur même si la hauteur ne manque pas. En mode sans fiche, une bande
/// qui ne tient pas donne `overflows` et le reste se répartit comme
/// d'habitude.
/// Un repli tout ou rien peut libérer plus qu'il ne manque : ce surplus revient
/// aux replis par degrés, le plus tardif d'abord (avis, fiche, légende ; en
/// mode, bande du réticule posée et fiche du bas comptée : fiche, avis,
/// légende — arbitrage 15, le réticule reste fixe) ; un
/// repli tout ou rien joué n'est jamais défait. Si les six ne suffisent pas,
/// [MapLayoutAllocation.overflows] est vrai et la partie fixe reçoit ce qui
/// reste. Aucune hauteur rendue n'est négative ; aucune exception. Les
/// comparaisons ignorent un écart de [_tolerance] (1e-6 px).
MapLayoutAllocation allocateMapLayout(MapLayoutInput input) {
  final bool sheetCounted = switch (input.width) {
    MapLayoutWidth.compact || MapLayoutWidth.wide => true,
    MapLayoutWidth.panel => false,
  };
  final bool withdrawable =
      input.designation &&
      input.sheetOpen &&
      switch (input.width) {
        MapLayoutWidth.compact => true,
        MapLayoutWidth.wide || MapLayoutWidth.panel => false,
      };
  // Repli 6 étendu (arbitrage 14) : en mode, une bande qui ne tient pas en
  // largeur se retire d'emblée si une fiche est ouverte, à toute largeur ;
  // sans fiche, elle ne peut ni se poser ni se retirer.
  final bool bandMisfits = input.designation && !input.bandFits;
  final bool withdrawnAtOnce = bandMisfits && input.sheetOpen;
  final bool bandOverflows = bandMisfits && !input.sheetOpen;
  final bool bottomCounted = switch (input.width) {
    MapLayoutWidth.compact => true,
    MapLayoutWidth.wide || MapLayoutWidth.panel => input.blockOverBottom,
  };
  final double bottom = _nonNegative(input.bottom);
  final double gap = _nonNegative(input.gap);
  final _Stack stack = _Stack(
    width: input.width,
    designation: input.designation,
    reticleUnderBlock: input.reticleUnderBlock,
    bottom: bottomCounted ? bottom : 0,
    gap: gap,
  );
  final double available = _nonNegative(input.available);
  final PieceHeights blockFixed = _sanitized(input.blockFixed);
  final PieceHeights band = _sanitized(input.band);
  final PieceHeights sheet = _sanitized(input.sheet);
  final double notices = _nonNegative(input.notices);
  final double legend = _nonNegative(input.legend);

  // Le bas hors de la somme borne quand même : au-dessus d'une fiche du bas,
  // il la plafonne (repli 2) ; sans fiche du bas, il doit tenir seul.
  double sheetMax = sheet.max;
  bool bottomOverflows = false;
  if (!bottomCounted && bottom > 0) {
    if (sheetCounted && sheet.max > 0) {
      final double cap = available - bottom - gap;
      bottomOverflows = sheet.min > cap + _tolerance;
      sheetMax = cap >= sheet.max - _tolerance
          ? sheet.max
          : _max(sheet.min, cap);
    } else {
      bottomOverflows = bottom > available + _tolerance;
    }
  }

  _Heights heights = _Heights(
    blockFixed: blockFixed.max,
    notices: notices,
    legend: legend,
    reticleBand: withdrawnAtOnce ? 0 : _nonNegative(input.reticleBand),
    band: withdrawnAtOnce ? 0 : band.max,
    sheet: sheetCounted ? sheetMax : 0,
  );

  // Replis 1 à 3 au plus bas d'abord : ce qu'ils n'auront pas eu à donner,
  // ils le reprennent plus bas.
  if (stack.total(heights) > available + _tolerance) {
    heights = heights.copyWith(
      legend: 0,
      sheet: sheetCounted ? sheet.min : 0,
      notices: 0,
    );
  }

  // Replis 4 à 6 : chacun seulement si la somme dépasse encore, et s'il
  // libère une hauteur.
  bool play(_Heights folded) {
    final double before = stack.total(heights);
    if (before <= available + _tolerance) return false;
    if (stack.total(folded) > before - _tolerance) return false;
    heights = folded;
    return true;
  }

  final bool subtitlesFolded = play(
    heights.copyWith(blockFixed: blockFixed.min),
  );
  final bool hintFolded =
      !withdrawnAtOnce && play(heights.copyWith(band: band.min));
  final bool bandWithdrawn =
      withdrawnAtOnce ||
      (withdrawable && play(heights.copyWith(band: 0, reticleBand: 0)));

  final bool stackOverflows = stack.total(heights) > available + _tolerance;
  if (stackOverflows) {
    // La partie fixe reçoit ce qui reste : elle défilera.
    heights = stack.grow(
      heights,
      available,
      floor: 0,
      max: heights.blockFixed,
      set: (_Heights h, double v) => h.copyWith(blockFixed: v),
    );
  } else {
    // Le surplus revient aux replis par degrés, le plus tardif d'abord :
    // avis, fiche, légende. Arbitrage 15 (le réticule reste fixe) : en mode,
    // bande du réticule posée et fiche du bas comptée, la fiche passe avant
    // les avis — elle place la bande, donc le réticule, qui ne doit dépendre
    // ni des avis ni de la légende.
    _Heights growNotices(_Heights h) => stack.grow(
      h,
      available,
      floor: 0,
      max: notices,
      set: (_Heights h, double v) => h.copyWith(notices: v),
      weight: stack.variableWeight(h),
    );
    _Heights growSheet(_Heights h) => sheetCounted
        ? stack.grow(
            h,
            available,
            floor: sheet.min,
            max: sheetMax,
            set: (_Heights h, double v) => h.copyWith(sheet: v),
          )
        : h;
    final bool reticleFixed =
        input.designation &&
        sheetCounted &&
        sheet.max > 0 &&
        heights.reticleBand > 0;
    heights = reticleFixed
        ? growNotices(growSheet(heights))
        : growSheet(growNotices(heights));
    heights = stack.grow(
      heights,
      available,
      floor: 0,
      max: legend,
      set: (_Heights h, double v) => h.copyWith(legend: v),
      weight: stack.variableWeight(heights),
    );
  }

  return MapLayoutAllocation(
    blockFixed: heights.blockFixed,
    notices: heights.notices,
    legend: heights.legend,
    sheet: sheetCounted ? heights.sheet : sheet.max,
    band: heights.band,
    reticleBand: heights.reticleBand,
    subtitlesFolded: subtitlesFolded,
    hintFolded: hintFolded,
    bandWithdrawn: bandWithdrawn,
    overflows: stackOverflows || bottomOverflows || bandOverflows,
    folds: List<int>.unmodifiable(<int>[
      if (heights.legend < legend) 1,
      if (sheetCounted && heights.sheet < sheet.max) 2,
      if (heights.notices < notices) 3,
      if (subtitlesFolded) 4,
      if (hintFolded) 5,
      if (bandWithdrawn) 6,
    ]),
  );
}

/// Les hauteurs en cours de répartition des pièces qui peuvent céder.
final class _Heights {
  const _Heights({
    required this.blockFixed,
    required this.notices,
    required this.legend,
    required this.reticleBand,
    required this.band,
    required this.sheet,
  });

  final double blockFixed;
  final double notices;
  final double legend;
  final double reticleBand;
  final double band;
  final double sheet;

  _Heights copyWith({
    double? blockFixed,
    double? notices,
    double? legend,
    double? reticleBand,
    double? band,
    double? sheet,
  }) => _Heights(
    blockFixed: blockFixed ?? this.blockFixed,
    notices: notices ?? this.notices,
    legend: legend ?? this.legend,
    reticleBand: reticleBand ?? this.reticleBand,
    band: band ?? this.band,
    sheet: sheet ?? this.sheet,
  );
}

/// L'empilement des pièces et sa hauteur totale.
final class _Stack {
  const _Stack({
    required this.width,
    required this.designation,
    required this.reticleUnderBlock,
    required this.bottom,
    required this.gap,
  });

  final MapLayoutWidth width;

  /// Le mode « Restrictions » ([MapLayoutInput.designation]) : avec la bande
  /// du réticule, la partie variable compte deux fois ([variableWeight]).
  final bool designation;

  /// [MapLayoutInput.reticleUnderBlock] : sans lui, le doublement ne joue pas.
  final bool reticleUnderBlock;

  /// Le bas, déjà nul au-delà du téléphone quand il ne passe pas sous le
  /// bloc. En panel, la fiche vaut 0 dans [_Heights.sheet].
  final double bottom;

  final double gap;

  /// Le poids de la partie variable (avis + légende) dans [total] : 2 en
  /// mode, quand le réticule passe sous le bloc en largeur et tant que la
  /// bande du réticule est là ; 1 sinon (hors mode, réticule à
  /// côté du bloc — rien ne cède tant que tout tient, spec § 5.6 —, ou bande
  /// retirée par le repli 6). Le réticule est au milieu de [bas de la partie
  /// fixe ; haut de la bande] et la partie variable s'arrête au-dessus de la
  /// bande du réticule (spec § 5.5) : avec H cette hauteur, R la bande du
  /// réticule et V la partie variable, il faut V ≤ (H − R) / 2, donc
  /// H ≥ 2V + R.
  double variableWeight(_Heights h) =>
      designation && reticleUnderBlock && h.reticleBand > 0 ? 2 : 1;

  /// La hauteur des quatre groupes — bloc, bande du réticule, zone du bas,
  /// fiche —, plus un écart entre deux groupes consécutifs non nuls dont
  /// aucun n'est la bande du réticule (règle : [allocateMapLayout]). La
  /// partie variable du bloc y pèse [variableWeight].
  double total(_Heights h) {
    final double bottomZone = switch (width) {
      MapLayoutWidth.compact =>
        h.band + bottom + (h.band > 0 && bottom > 0 ? gap : 0),
      MapLayoutWidth.wide || MapLayoutWidth.panel => _max(h.band, bottom),
    };
    double sum = 0;
    bool afterGroup = false;
    bool afterReticle = false;
    for (final (double height, bool reticle) in <(double, bool)>[
      (h.blockFixed + variableWeight(h) * (h.notices + h.legend), false),
      (h.reticleBand, true),
      (bottomZone, false),
      (h.sheet, false),
    ]) {
      if (height <= 0) continue;
      if (afterGroup && !afterReticle && !reticle) sum += gap;
      sum += height;
      afterGroup = true;
      afterReticle = reticle;
    }
    return sum;
  }

  /// La pièce que [set] désigne, posée à la plus grande hauteur entre [floor]
  /// et [max] qui tienne dans [available], les autres gardant la leur. Chaque
  /// pixel de la pièce coûte [weight] pixels de la somme (la partie variable,
  /// en mode : [variableWeight]). Une pièce qui passe de 0 à une hauteur non
  /// nulle coûte aussi l'écart que son groupe gagne, s'il en gagne un (aucun
  /// dans un bloc déjà non nul).
  _Heights grow(
    _Heights heights,
    double available, {
    required double floor,
    required double max,
    required _Heights Function(_Heights h, double v) set,
    double weight = 1,
  }) {
    final _Heights atFloor = set(heights, floor);
    final double slack = available - total(atFloor);
    if (slack <= _tolerance || max <= floor) return atFloor;
    if (floor > 0) return set(heights, _upTo(max, floor + slack / weight));
    final double gapCost =
        total(set(heights, max)) - total(atFloor) - weight * max;
    final double room = (slack - gapCost) / weight;
    return room > _tolerance ? set(heights, _upTo(max, room)) : atFloor;
  }
}

/// L'écart que les comparaisons de hauteurs ignorent : invisible à l'écran, il
/// couvre le bruit des flottants et des hauteurs mesurées par des chemins
/// différents. Un dépassement plus petit ne fait jouer aucun repli.
const double _tolerance = 1e-6;

/// [value], sans dépasser [max] — ramené à [max] s'il n'en est qu'à la
/// [_tolerance] près.
double _upTo(double max, double value) =>
    value >= max - _tolerance ? max : value;

bool _sameFolds(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// [value], ou 0 s'il est négatif (ou n'est pas un nombre).
double _nonNegative(double value) => value > 0 ? value : 0;

/// [heights], chaque hauteur ramenée à 0 au moins, la repliée jamais au-dessus
/// de l'entière.
PieceHeights _sanitized(PieceHeights heights) {
  final double max = _nonNegative(heights.max);
  return PieceHeights(min: _min(_nonNegative(heights.min), max), max: max);
}

double _min(double a, double b) => a < b ? a : b;

double _max(double a, double b) => a > b ? a : b;
