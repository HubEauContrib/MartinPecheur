// Le port d'ouverture de lien (T2, B2) est un contrat du domaine, Dart pur :
// il rend un booleen, jamais une exception de plateforme. Ce test verrouille
// sa forme — un double en memoire l'implemente sans rien d'autre que
// `dart:core`.

import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/links/external_link_opener.dart';

final class _EnMemoire implements ExternalLinkOpener {
  final List<Uri> recues = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    recues.add(uri);
    return uri.scheme == 'https';
  }
}

void main() {
  test('open(Uri) rend vrai si la plateforme a accepte d ouvrir', () async {
    final _EnMemoire opener = _EnMemoire();

    expect(await opener.open(Uri.parse('https://example.org/a.pdf')), isTrue);
    expect(await opener.open(Uri.parse('ftp://example.org/a.pdf')), isFalse);
    expect(opener.recues, hasLength(2));
  });
}
