// Verrouille l'implementation du port d'ouverture de lien autour de
// `url_launcher` (T2, B2), sans jamais appeler la plateforme : la fonction de
// lancement est injectee. Signatures lues dans le paquet installe
// (url_launcher 6.3.2, `lib/src/url_launcher_uri.dart` et `lib/src/types.dart`) :
// `Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault, ...})`,
// `LaunchMode.externalApplication` — « Passes the URL to the OS to be handled
// by another application ».
//
// `dart:io` est autorise ici pour lire `lib/`, jamais sous lib/domain/.

import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/links/url_launcher_external_link_opener.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

void main() {
  final Uri arrete = Uri.parse('https://example.org/arretes/2026-08-20.pdf');

  test('la fonction injectee recoit l Uri inchangee et le mode hors de '
      'l application', () async {
    final List<Uri> urls = <Uri>[];
    final List<LaunchMode> modes = <LaunchMode>[];
    final ExternalLinkOpener opener = UrlLauncherExternalLinkOpener(
      launch: (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
        urls.add(url);
        modes.add(mode);
        return true;
      },
    );

    final bool opened = await opener.open(arrete);

    expect(opened, isTrue);
    expect(urls, <Uri>[arrete]);
    expect(identical(urls.single, arrete), isTrue);
    expect(modes, <LaunchMode>[LaunchMode.externalApplication]);
  });

  test('la plateforme refuse -> false', () async {
    final ExternalLinkOpener opener = UrlLauncherExternalLinkOpener(
      launch: (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async =>
          false,
    );

    expect(await opener.open(arrete), isFalse);
  });

  test(
    'la plateforme leve (PlatformException) -> false, rien ne fuit',
    () async {
      final ExternalLinkOpener opener = UrlLauncherExternalLinkOpener(
        launch: (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) =>
            Future<bool>.error(PlatformException(code: 'ACTIVITY_NOT_FOUND')),
      );

      expect(await opener.open(arrete), isFalse);
    },
  );

  test('sans parametre, la vraie fonction de la bibliotheque est gardee : '
      'le constructeur par defaut se construit sans rien appeler', () {
    expect(UrlLauncherExternalLinkOpener.new, returnsNormally);
  });

  test('package:url_launcher n est importe que sous lib/data/links/', () {
    final List<String> fautifs = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where(
          (File f) => f.readAsStringSync().contains('package:url_launcher'),
        )
        .map((File f) => f.path.replaceAll(r'\', '/'))
        .where((String path) => !path.startsWith('lib/data/links/'))
        .toList();

    expect(fautifs, isEmpty);
  });
}
