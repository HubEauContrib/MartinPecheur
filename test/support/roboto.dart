// Le chargeur de Roboto des tests qui mesurent (`S1` d'Ergonomie, décision de
// la boucle principale du 2026-10-18) : la fonction `_chargerRoboto` de
// `test/features/map/view/map_overlays_phone_test.dart`, DÉPLACÉE telle
// quelle, pour qu'aucun nouveau fichier n'en recopie une version privée. Les
// copies privées encore présentes disparaissent avec leurs fichiers (`D2`).
// `S6` y ajoute ce qui lui manque.
//
// dart:io est autorisé ici (test/support/), jamais sous lib/domain/.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart' show fail;

/// Charge ROBOTO — toutes les graisses `Roboto-*.ttf` du SDK Flutter — sous la
/// famille `Roboto`, celle que Material demande sur Android, et enregistre les
/// mêmes octets aussi sous « Segoe UI », en substitut.
///
/// Le dossier est celui des polices du SDK, `bin/cache/artifacts/material_fonts`,
/// trouvé par la variable d'environnement `FLUTTER_ROOT` que `flutter test`
/// définit : aucun chemin de poste dans le dépôt. Si la variable, le dossier
/// ou les polices manquent, le fichier ÉCHOUE avec un message clair — jamais
/// de repli silencieux sur la police de test : tous les pixels de ce fichier
/// seraient faux.
///
/// La police chargée vaut pour tout le processus de test de CE fichier. Un
/// précédent existe : `restrictions_scale_text_test.dart` charge lui aussi
/// Roboto (depuis `bc81efe`), avec une autre politique — Regular et Bold
/// seulement, et ses tests sont IGNORÉS (`markTestSkipped`) quand
/// `FLUTTER_ROOT` est absent hors intégration continue. Ici, toutes les
/// graisses, et jamais d'ignorance : les pixels de ce fichier sont tous des
/// mesures. Les autres fichiers de test gardent la police de test.
Future<void> chargerRoboto() async {
  final String? racine = Platform.environment['FLUTTER_ROOT'];
  if (racine == null || racine.isEmpty) {
    fail(
      'FLUTTER_ROOT est absent : les polices Roboto du SDK Flutter sont '
      'introuvables. Ce fichier mesure en Roboto, jamais en police de test : '
      'lancer les tests par `flutter test`.',
    );
  }
  final Directory dossier = Directory(
    '$racine/bin/cache/artifacts/material_fonts',
  );
  if (!dossier.existsSync()) {
    fail(
      '${dossier.path} est introuvable : lancer `flutter precache`. Ce '
      'fichier mesure en Roboto, jamais en police de test.',
    );
  }
  // `Roboto-*.ttf` : « Roboto-Regular », « Roboto-BoldItalic »… mais ni
  // `RobotoCondensed-*` ni les icônes. La casse des noms varie selon la
  // version du SDK.
  final List<File> polices = dossier.listSync().whereType<File>().where((
    File f,
  ) {
    final String nom = f.uri.pathSegments.last.toLowerCase();
    return nom.startsWith('roboto-') && nom.endsWith('.ttf');
  }).toList();
  if (polices.isEmpty) {
    fail(
      'Aucune police Roboto-*.ttf dans ${dossier.path} : lancer '
      '`flutter precache`. Ce fichier mesure en Roboto, jamais en police de '
      'test.',
    );
  }
  // Les mêmes octets sont chargés sous deux familles : « Roboto », celle que
  // Material demande sur Android, et « Segoe UI », celle qu'il demande sur
  // Windows (`Typography.material2021`, `blackRedmond`). Segoe UI n'est PAS
  // chargée ici — la police de Windows n'est pas dans le SDK : les tests de la
  // section « Windows » mesurent donc en Roboto, un SUBSTITUT de Segoe UI, pas
  // sa mesure. Sans lui, Windows retomberait sur la police de test (un carré
  // par glyphe) et chaque largeur de texte serait fausse.
  final List<Future<ByteData>> octets = <Future<ByteData>>[
    for (final File police in polices)
      Future<ByteData>.value(ByteData.sublistView(police.readAsBytesSync())),
  ];
  for (final String famille in <String>['Roboto', 'Segoe UI']) {
    final FontLoader chargeur = FontLoader(famille);
    for (final Future<ByteData> police in octets) {
      chargeur.addFont(police);
    }
    await chargeur.load();
  }
}
