// Verrouille SharedPreferencesAcknowledgementRepository (W1) : la
// persistance de la version acquittee, jamais un booleen (BR-012). Le depot
// reste bete — une valeur inattendue (chaine vide) est rendue telle quelle,
// ce n'est pas a lui de decider qu'elle ne vaut pas acquittement.
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/data/preferences/shared_preferences_acknowledgement_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stockage vide -> readAcknowledgedVersion() rend null', () async {
    final SharedPreferencesAcknowledgementRepository repository =
        SharedPreferencesAcknowledgementRepository();

    final String? version = await repository.readAcknowledgedVersion();

    expect(version, isNull);
  });

  test('ecriture puis relecture rend la version ecrite', () async {
    final SharedPreferencesAcknowledgementRepository repository =
        SharedPreferencesAcknowledgementRepository();

    await repository.writeAcknowledgedVersion('2026-09-13.1');
    final String? version = await repository.readAcknowledgedVersion();

    expect(version, '2026-09-13.1');
  });

  test('une nouvelle instance du depot relit la valeur persistee — ce n\'est '
      'pas un cache memoire', () async {
    final SharedPreferencesAcknowledgementRepository premiere =
        SharedPreferencesAcknowledgementRepository();
    await premiere.writeAcknowledgedVersion('2026-09-13.1');

    final SharedPreferencesAcknowledgementRepository seconde =
        SharedPreferencesAcknowledgementRepository();
    final String? version = await seconde.readAcknowledgedVersion();

    expect(version, '2026-09-13.1');
  });

  test('une chaine vide stockee est rendue telle quelle — le depot ne decide '
      'de rien', () async {
    final SharedPreferencesAcknowledgementRepository repository =
        SharedPreferencesAcknowledgementRepository();

    await repository.writeAcknowledgedVersion('');
    final String? version = await repository.readAcknowledgedVersion();

    expect(version, '');
  });
}
