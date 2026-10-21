// Test de non-régression sur la configuration du projet (pas sur le domaine
// métier) : dart:io est autorisé ici, jamais sous lib/domain/.
//
// Décision du commanditaire du 2026-10-21 : l'application et le Microsoft
// Store portent la même icône, le martin-pêcheur de windows/store/ (ADR-018).
// Le logo de Flutter, que le gabarit posait sur les trois cibles, est un
// produit tiers : la politique 10.1.1 du Store l'interdit.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Empreinte FNV-1a sur 64 bits : assez pour reconnaître un fichier connu.
int empreinte(List<int> octets) {
  int h = 0xcbf29ce484222325;
  for (final int o in octets) {
    h ^= o;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h;
}

int entierPng(List<int> b, int debut) =>
    (b[debut] << 24) |
    (b[debut + 1] << 16) |
    (b[debut + 2] << 8) |
    b[debut + 3];

/// Les empreintes des icônes du gabarit Flutter, relevées le 2026-10-21 sur
/// les fichiers du dépôt avant leur remplacement.
const Map<String, int> gabaritFlutter = <String, int>{
  'windows/runner/resources/app_icon.ico': -0x36904f23d0864c0b,
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': -0x337f7ddbf8227b97,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': -0x73e2201e0716aadf,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': -0x4af40dfbf7398a45,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 0x54e861a18f6f9c34,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 0x25b98cf0ac669cff,
  '$ios/Icon-App-1024x1024@1x.png': 0x31e6ae51786d7700,
  '$ios/Icon-App-20x20@1x.png': -0x0e72a5d2f8a84c89,
  '$ios/Icon-App-20x20@2x.png': 0x6384c95103bb8634,
  '$ios/Icon-App-20x20@3x.png': -0x76970575d726dfaf,
  '$ios/Icon-App-29x29@1x.png': -0x57c8f24cd5ed895b,
  '$ios/Icon-App-29x29@2x.png': -0x399519dbe3e57da9,
  '$ios/Icon-App-29x29@3x.png': 0x400a13aa612b751f,
  '$ios/Icon-App-40x40@1x.png': 0x6384c95103bb8634,
  '$ios/Icon-App-40x40@2x.png': -0x4a0964d5241a3edd,
  '$ios/Icon-App-40x40@3x.png': -0x43ac71ce97174bb3,
  '$ios/Icon-App-60x60@2x.png': -0x43ac71ce97174bb3,
  '$ios/Icon-App-60x60@3x.png': -0x0c8578ff1c5545b8,
  '$ios/Icon-App-76x76@1x.png': -0x0e9e44d7132b5cd8,
  '$ios/Icon-App-76x76@2x.png': 0x1cc28fb4ff389af8,
  '$ios/Icon-App-83.5x83.5@2x.png': -0x105375124ff8cb9f,
};

const String ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  group(
    "aucune icône de l'application n'est plus celle du gabarit Flutter",
    () {
      for (final MapEntry<String, int> e in gabaritFlutter.entries) {
        test(e.key, () {
          final File fichier = File(e.key);
          expect(fichier.existsSync(), isTrue);
          expect(
            empreinte(fichier.readAsBytesSync()),
            isNot(e.value),
            reason: "c'est encore le logo de Flutter",
          );
        });
      }
    },
  );

  group('icônes Android : PNG carrés aux tailles des densités', () {
    for (final (String densite, int cote) in <(String, int)>[
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      test('mipmap-$densite : $cote × $cote', () {
        final List<int> b = File(
          'android/app/src/main/res/mipmap-$densite/ic_launcher.png',
        ).readAsBytesSync();
        expect(b.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
        expect(<int>[entierPng(b, 16), entierPng(b, 20)], <int>[cote, cote]);
      });
    }
  });

  group('icônes iOS : taille tirée du nom, sans couche alpha', () {
    for (final String nom in gabaritFlutter.keys.where(
      (String k) => k.startsWith(ios),
    )) {
      test(nom.substring(ios.length + 1), () {
        final RegExpMatch m = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$')
            .firstMatch(nom)!;
        final int cote = (double.parse(m.group(1)!) * int.parse(m.group(2)!))
            .round();
        final List<int> b = File(nom).readAsBytesSync();
        expect(<int>[entierPng(b, 16), entierPng(b, 20)], <int>[cote, cote]);
        expect(b[25], 2, reason: "type de couleur 2 : RGB, sans couche alpha");
      });
    }
  });

  test("app_icon.ico porte les tailles 16 à 256 px de Windows", () {
    final List<int> b = File('windows/runner/resources/app_icon.ico')
        .readAsBytesSync();
    expect(<int>[b[0], b[1], b[2], b[3]], <int>[0, 0, 1, 0]);
    final int nombre = b[4] | (b[5] << 8);
    final Set<int> tailles = <int>{
      for (int i = 0; i < nombre; i++) b[6 + 16 * i] == 0 ? 256 : b[6 + 16 * i],
    };
    expect(tailles, containsAll(<int>[16, 24, 32, 48, 64, 128, 256]));
  });
}
