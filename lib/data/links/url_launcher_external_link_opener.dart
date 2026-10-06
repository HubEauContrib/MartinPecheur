// Implementation du port d'ouverture de lien (T2, B2) autour de
// `url_launcher` 6.3.2 — seul fichier de `lib/` a importer la bibliotheque
// (verrou : `test/data/links/url_launcher_external_link_opener_test.dart`).
//
// Signatures lues dans le paquet installe, jamais de memoire :
// - `lib/src/url_launcher_uri.dart` : `Future<bool> launchUrl(Uri url,
//   {LaunchMode mode = LaunchMode.platformDefault, WebViewConfiguration
//   webViewConfiguration, BrowserConfiguration browserConfiguration,
//   String? webOnlyWindowName})` — « Returns true if the URL was launched
//   successfully, otherwise either returns false or throws a
//   [PlatformException] depending on the failure. »
// - `lib/src/types.dart` : `LaunchMode.externalApplication` — « Passes the
//   URL to the OS to be handled by another application. » C'est le mode
//   « hors de l'application » : le PDF et le site public s'ouvrent dans
//   l'application par defaut du systeme, pas dans une vue web embarquee.
//
// La fonction de lancement est INJECTEE, la vraie par defaut : un test
// n'appelle jamais la plateforme.

import 'package:martinpecheur/domain/links/external_link_opener.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// Forme de `launchUrl` que cette implementation utilise : l'adresse et le
/// mode. La vraie fonction, qui accepte d'autres parametres nommes
/// facultatifs, en est un sous-type.
typedef LaunchUrl = Future<bool> Function(Uri url, {LaunchMode mode});

/// Ouvre une adresse hors de l'application par `url_launcher`.
final class UrlLauncherExternalLinkOpener implements ExternalLinkOpener {
  /// [launch] vaut `launchUrl` de la bibliotheque ; un test en injecte un
  /// double.
  const UrlLauncherExternalLinkOpener({this._launch = launchUrl});

  final LaunchUrl _launch;

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await _launch(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // `PlatformException` d'apres la documentation de `launchUrl` : un
      // echec d'ouverture est un resultat, il ne fuit pas (`UC-002 A6`).
      return false;
    }
  }
}
