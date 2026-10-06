// Verrouille l'echelle en bande de l'ecran des restrictions a differentes
// largeurs et tailles de police : aucun libelle n'est coupe au milieu d'un
// mot, et les paliers de colonnes (1 sous ~300 px de contenu non agrandi, 2
// sous 480, 4 au-dessus).
//
// Ce fichier charge la VRAIE police Roboto du SDK (la police des tests, Ahem,
// fait 14 px par caractere et rendrait toute mesure de coupure fausse). Il est
// isole dans son propre fichier : la police chargee vaut pour tout le
// processus de test du fichier, et ne doit pas deplacer les mesures des autres
// tests de l'ecran.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/alert_zone.dart';
import 'package:martinpecheur/domain/restrictions/drought_severity.dart';
import 'package:martinpecheur/features/restrictions/view/restrictions_screen.dart';
import 'package:martinpecheur/features/restrictions/view_model/restrictions_view_model.dart';

import '../zones_samples.dart';

Duration _paris(DateTime _) => const Duration(hours: 2);

/// Charge Roboto (normal et gras) depuis le SDK Flutter.
///
/// Renvoie `false` SEULEMENT si `FLUTTER_ROOT` est absent hors integration
/// continue (les tests sont alors ignores, et le disent). `FLUTTER_ROOT`
/// present mais polices introuvables, ou variable `CI` definie sans SDK : le
/// test ECHOUE — jamais de faux vert.
Future<bool> _loadRoboto() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    if (Platform.environment.containsKey('CI')) {
      fail(
        'CI est defini mais FLUTTER_ROOT est absent : polices Roboto '
        'introuvables, les mesures ne peuvent pas etre ignorees',
      );
    }
    return false;
  }
  final String dir = '$root/bin/cache/artifacts/material_fonts';
  final List<File> found = <File>[];
  for (final String name in <String>['Roboto-Regular', 'Roboto-Bold']) {
    // La casse des noms varie selon la version du SDK.
    final File file = <File>[
      File('$dir/$name.ttf'),
      File('$dir/${name.toLowerCase()}.ttf'),
    ].firstWhere((File f) => f.existsSync(), orElse: () => File(''));
    if (file.path.isEmpty) {
      fail(
        'FLUTTER_ROOT=$root mais $dir/$name.ttf est introuvable : '
        'lancer `flutter precache`',
      );
    }
    found.add(file);
  }
  final FontLoader loader = FontLoader('Roboto');
  for (final File file in found) {
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
  return true;
}

/// Les mots de [label] coupes par un retour a la ligne AU MILIEU d'un mot :
/// un mot dont les boites de selection n'ont pas toutes le meme `top`.
List<String> _brokenWords(RenderParagraph paragraph, String label) {
  final List<String> broken = <String>[];
  int start = 0;
  for (final String word in label.split(' ')) {
    final Set<int> tops = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
        )
        .map((TextBox box) => box.top.round())
        .toSet();
    if (tops.length > 1) {
      broken.add(word);
    }
    start += word.length + 1;
  }
  return broken;
}

final List<AlertZone> _zones = <AlertZone>[
  ainSup(),
  ainSou(),
  ainAep(),
  ainSupGraviteInconnue(),
];

Future<void> _pumpAt(WidgetTester tester, Size window, double scale) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: RestrictionsScreen(
          state: ZonesTrouvees(zonesAinWith(_zones)),
          profile: null,
          onChooseProfile: (_) {},
          onRetry: () {},
          onOpenDocument: (_, _) {},
          onOpenPublicSite: () {},
          utcOffsetOf: _paris,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inScale(int index, Finder matching) => find.descendant(
  of: find.byKey(restrictionsScaleKey(index)),
  matching: matching,
);

const List<String> _labels = <String>[
  'Vigilance',
  'Alerte',
  'Alerte renforcée',
  'Crise',
];

void main() {
  bool fontsLoaded = false;

  setUpAll(() async {
    fontsLoaded = await _loadRoboto();
  });

  const List<Size> windows = <Size>[
    Size(360, 640),
    Size(390, 844),
    Size(800, 740),
  ];

  for (final Size window in windows) {
    for (final double scale in const <double>[1, 2]) {
      testWidgets('échelle à ${window.width.toInt()} x '
          '${window.height.toInt()}, police ${(scale * 100).toInt()} % : '
          'aucun libellé coupé au milieu d\'un mot', (
        WidgetTester tester,
      ) async {
        if (!fontsLoaded) {
          markTestSkipped('police Roboto du SDK introuvable');
          return;
        }
        await _pumpAt(tester, window, scale);
        expect(tester.takeException(), isNull);
        // Une zone par échelle : la dernière (gravité inconnue) comprise.
        for (int zone = 0; zone < _zones.length; zone++) {
          for (final String label in _labels) {
            final Finder text = _inScale(zone, find.text(label));
            expect(text, findsOneWidget);
            final RenderParagraph paragraph = tester.renderObject(text);
            // Aucun MOT n'est coupe (un retour a la ligne entre deux mots est
            // permis, « Alerte renfor / cée » ne l'est pas).
            expect(
              _brokenWords(paragraph, label),
              isEmpty,
              reason: '« $label » (zone $zone) coupé au milieu d un mot',
            );
          }
        }
      });
    }
  }

  testWidgets('le détecteur voit un mot coupé (« Alerte renfor / cée »)', (
    WidgetTester tester,
  ) async {
    if (!fontsLoaded) {
      markTestSkipped('police Roboto du SDK introuvable');
      return;
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 70,
            child: Text(
              'Alerte renforcée',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 28),
            ),
          ),
        ),
      ),
    );
    final RenderParagraph paragraph = tester.renderObject(
      find.text('Alerte renforcée'),
    );
    expect(_brokenWords(paragraph, 'Alerte renforcée'), isNotEmpty);
    // Et un mot entier sur sa ligne n'est pas signalé.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: Text(
              'Alerte renforcée',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 28),
            ),
          ),
        ),
      ),
    );
    expect(
      _brokenWords(
        tester.renderObject(find.text('Alerte renforcée')),
        'Alerte renforcée',
      ),
      isEmpty,
    );
  });

  testWidgets('palier 1 colonne : 360 de large, police 100 % '
      '(contenu non agrandi < 300)', (WidgetTester tester) async {
    if (!fontsLoaded) {
      markTestSkipped('police Roboto du SDK introuvable');
      return;
    }
    await _pumpAt(tester, const Size(360, 640), 1);
    final List<double> tops = <double>[
      for (final String l in _labels)
        tester.getTopLeft(_inScale(0, find.text(l))).dy,
    ];
    for (int i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1] + 10), reason: 'ligne $i');
    }
  });

  testWidgets('palier 1 colonne : 390 de large, police 200 %', (
    WidgetTester tester,
  ) async {
    if (!fontsLoaded) {
      markTestSkipped('police Roboto du SDK introuvable');
      return;
    }
    await _pumpAt(tester, const Size(390, 844), 2);
    final double vigilance = tester
        .getTopLeft(_inScale(0, find.text('Vigilance')))
        .dy;
    final double alerte = tester
        .getTopLeft(_inScale(0, find.text('Alerte')))
        .dy;
    expect(alerte, greaterThan(vigilance + 10));
  });

  testWidgets('palier 2 colonnes : 800 de large, police 200 %', (
    WidgetTester tester,
  ) async {
    if (!fontsLoaded) {
      markTestSkipped('police Roboto du SDK introuvable');
      return;
    }
    await _pumpAt(tester, const Size(800, 740), 2);
    double top(String l) => tester.getTopLeft(_inScale(0, find.text(l))).dy;
    expect(top('Alerte'), closeTo(top('Vigilance'), 3));
    expect(top('Crise'), closeTo(top('Alerte renforcée'), 3));
    expect(top('Alerte renforcée'), greaterThan(top('Vigilance') + 10));
  });

  testWidgets('la gravité inconnue n\'a toujours aucune case marquée', (
    WidgetTester tester,
  ) async {
    if (!fontsLoaded) {
      markTestSkipped('police Roboto du SDK introuvable');
      return;
    }
    await _pumpAt(tester, const Size(360, 640), 2);
    // Les eaux superficielles d'abord : l'ordre affiché est 0 (alerte),
    // 1 (gravité inconnue), puis les autres zones.
    expect(_inScale(1, find.text('← cette zone')), findsNothing);
    expect(_inScale(0, find.text('← cette zone')), findsOneWidget);
    expect(droughtSeverityScale, hasLength(4));
  });
}
