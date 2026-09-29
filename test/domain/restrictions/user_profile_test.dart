// Verrouille les profils d'usager : un enum ferme, choisi par l'usager et
// jamais recu d'une API — d'ou l'absence de branche inconnue, qui n'est pas
// un ecart a BR-011 (conception T2 § 2.7). Ordre : celui d'UC-002, etape 4.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/restrictions/user_profile.dart';

/// `switch` exhaustif SANS `default` : un profil ajoute sans cas ici casse
/// la compilation.
String _exhaustive(UserProfile profile) => switch (profile) {
  UserProfile.particulier => 'particulier',
  UserProfile.exploitation => 'exploitation',
  UserProfile.collectivite => 'collectivite',
  UserProfile.entreprise => 'entreprise',
};

void main() {
  test('UserProfile.values dans l ordre d UC-002, etape 4', () {
    expect(UserProfile.values, const <UserProfile>[
      UserProfile.particulier,
      UserProfile.exploitation,
      UserProfile.collectivite,
      UserProfile.entreprise,
    ]);
  });

  test('switch exhaustif sans default sur UserProfile', () {
    expect(UserProfile.values.map(_exhaustive), <String>[
      'particulier',
      'exploitation',
      'collectivite',
      'entreprise',
    ]);
  });

  test('userProfileLabel — libelles de C1 (Q-5b), mot pour mot', () {
    expect(UserProfile.values.map(userProfileLabel), <String>[
      'Particulier',
      'Exploitation',
      'Collectivité',
      'Entreprise',
    ]);
  });
}
