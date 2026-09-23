// Le socle commun des deux tests de rendu de référence de `U5`.
//
// ## Pourquoi un golden, alors que tout le reste se teste sans rendu
//
// `docs/plan-de-tests.md` § 1 place cet étage **au-dessus** de
// `test/features/` : il coûte des secondes là où une règle coûte des
// millisecondes, et il ne remplace aucun test de règle. Il prouve la seule
// chose qu'aucun autre étage ne sait prouver — **ce qui se voit** : que
// l'atténuation d'une donnée périmée (`BR-005`) est réellement visible, que
// le halo de 2 px (`04-ui.md` § 3, `NFR-04`) reste intact sur les deux
// états, et que les formes de l'échelle 1 restent séparables en niveaux de
// gris, c'est-à-dire en achromatopsie (`04-ui.md` § 3). Un test de peintre
// vérifie qu'on a demandé une opacité de 0,4 ; il ne dit pas si l'œil la
// distingue de 1.
//
// ## Ce qui rend une image reproductible
//
// Tout ce qui influence le rendu est fixé ici, une seule fois, plutôt que
// recopié dans chaque fichier : deux harnais qui divergent d'un demi-pixel
// produisent deux séries d'images qu'on ne peut plus comparer.
//
// - `devicePixelRatio = 1` : sans lui, la densité du poste entre dans
//   l'image et un autre écran produit une autre taille.
// - Taille de vue **fixe et explicite** par image, jamais celle par défaut.
// - Fond **blanc explicite** : le seul fond de carte du projet est le plan
//   IGN, un fond clair — c'est contre lui que le halo noir de `04-ui.md` § 3
//   doit tenir.
// - **Aucun texte** dans une image de référence. Les polices varient d'un
//   système à l'autre ; un `Text` rendrait les goldens illisibles hors de ce
//   poste. Les libellés des marqueurs ne sont d'ailleurs pas peints — ils
//   sont portés par `Semantics`, et `station_marker_test.dart` /
//   `onde_marker_test.dart` les vérifient déjà.
// - Les ombres sont désactivées par `TestWidgetsFlutterBinding`
//   (`debugDisableShadows`), et aucun des deux peintres n'en dessine.
//
// ## Les marqueurs sont AGRANDIS, et ce n'est pas la taille de la carte
//
// ⚠️ À l'écran, une pastille et un marqueur ONDE mesurent
// [stationMarkerSize] — **12 px logiques** ; c'est la taille que la carte
// peint, et la seule (`station_marker.dart`, `onde_marker.dart`). Ni
// `StationMarkerDot` ni `OndeMarkerShape` n'acceptent de taille : le
// `CustomPaint` qu'ils montent est fixé à 12 px. Les images de référence les
// rendent donc à travers un `Transform.scale` de
// [facteurDAgrandissement] — une mise à l'échelle du **canevas**, donc des
// tracés eux-mêmes, jamais un agrandissement d'image : le résultat reste net
// et strictement proportionnel à ce que la carte dessine. Un défaut visible
// ici est un défaut réel ; l'inverse n'est pas vrai, un détail lisible à
// 48 px peut ne pas l'être à 12.
//
// ## ⚠️ Ces images sont PLATEFORME-DÉPENDANTES
//
// Elles ont été produites sur **Windows**, la seule cible construite du
// projet. Le rastériseur (Skia / Impeller), l'anticrénelage et le rendu
// sous-pixel diffèrent d'un système à l'autre : la même suite peut rendre
// rouge sur macOS ou Linux **sans qu'aucun code ait changé**.
//
// Un écart se règle en **regardant l'image produite** — `flutter test`
// dépose un `*_testImage.png`, un `*_masterImage.png` et un `*_isolatedDiff.
// png` sous `test/features/goldens/failures/` — puis, s'il s'agit bien d'une
// différence de plateforme et non d'une régression, en régénérant avec
// `flutter test --update-goldens`. **Jamais à l'aveugle** : régénérer sans
// regarder fige un défaut au lieu de le détecter, ce qui retire à cet étage
// la seule raison qu'il a d'exister.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/map/view/station_marker.dart';

/// Agrandissement appliqué aux marqueurs dans les images de référence.
/// Quatre fois 12 px font 48 px : assez pour qu'un halo de 2 px (8 px une
/// fois agrandi) et un contour pointillé se voient à l'œil nu sur l'image.
const double facteurDAgrandissement = 4;

/// Côté d'une case, en pixels logiques : les 48 px du marqueur agrandi, plus
/// 8 px de marge de chaque côté pour que le halo ne touche pas le bord.
const double coteDUneCase = 64;

/// La zone effectivement capturée. `RepaintBoundary` isole une couche de
/// composition, ce dont `matchesGoldenFile` a besoin pour lire des pixels.
const Key cleDeLImage = Key('image-de-reference');

/// Le fond des images : blanc. Le plan IGN Géoplateforme, seul fond de carte
/// du projet, est un fond clair — c'est contre un fond clair que le halo
/// noir de `04-ui.md` § 3 doit tenir.
const Color fondDesImages = Color(0xFFFFFFFF);

/// Conversion en niveaux de gris par les coefficients de luminance de la
/// recommandation UIT-R BT.709 — `0,2126 R + 0,7152 V + 0,0722 B`, les mêmes
/// que ceux dont dérivent les ratios de contraste de WCAG, donc de
/// `04-ui.md` § 3.
///
/// Simuler l'**achromatopsie** : la couleur disparaît entièrement, et ce qui
/// reste — forme, motif, contraste de luminance — doit suffire à distinguer
/// les états. `04-ui.md` § 3 : « La distinction reste assurée par la forme
/// même en achromatopsie ».
const ColorFilter filtreNiveauxDeGris = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Une case de [coteDUneCase] px contenant [marqueur], peint à
/// [facteurDAgrandissement] × sa taille de carte ([stationMarkerSize]).
///
/// Le `SizedBox` intérieur donne au marqueur sa taille RÉELLE — celle de la
/// carte ; c'est le `Transform.scale` qui agrandit le tracé, à la façon d'une
/// loupe posée sur le canevas.
Widget caseAgrandie(Widget marqueur) => SizedBox(
  width: coteDUneCase,
  height: coteDUneCase,
  child: Center(
    child: Transform.scale(
      scale: facteurDAgrandissement,
      child: SizedBox(
        width: stationMarkerSize,
        height: stationMarkerSize,
        child: marqueur,
      ),
    ),
  ),
);

/// Une rangée de cases, sans marge supplémentaire : la largeur de l'image
/// vaut exactement `cases.length × coteDUneCase`.
Widget rangee(List<Widget> cases) =>
    Row(mainAxisSize: MainAxisSize.min, children: cases);

/// Monte [contenu] dans une vue de [taille] px logiques, à densité 1, sur
/// fond blanc — et rien d'autre. Voir l'en-tête pour le pourquoi de chaque
/// réglage.
Future<void> pompeLImage(
  WidgetTester tester, {
  required Widget contenu,
  required Size taille,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: cleDeLImage,
        child: ColoredBox(
          color: fondDesImages,
          child: Center(child: contenu),
        ),
      ),
    ),
  );
}

/// Compare la zone capturée au fichier [nomDeFichier], voisin du test.
///
/// À plat sous `test/features/goldens/`, sans sous-dossier `goldens/` : cet
/// étage de la pyramide ne contient QUE des images de référence et les deux
/// tests qui les produisent, un second niveau n'aurait rien à séparer.
Future<void> verifieLImage(String nomDeFichier) =>
    expectLater(find.byKey(cleDeLImage), matchesGoldenFile(nomDeFichier));
