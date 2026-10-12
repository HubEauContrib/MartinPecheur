// Les deux assistants de plateforme (`N1` de T3) : chacun pose SA plateforme
// pendant le corps du test, explicitement, et la retire ensuite. La cible
// tactile (`minimumTapTarget` : 48 sur Android, 44 ailleurs) est le premier
// effet visible de la plateforme, c'est elle qu'on lit ici.
//
// L'ordre des cas compte : le troisième lit l'état laissé par les deux
// premiers.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/features/shared/tap_target.dart';

import 'android_platform.dart';
import 'windows_platform.dart';

void main() {
  testWidgetsOnAndroid(
    'Android : le corps du test tourne sous Android, cible tactile de 48',
    (WidgetTester tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      expect(minimumTapTarget, 48);
    },
  );

  testWidgetsOnWindows(
    'le corps du test tourne sous Windows, cible tactile de 44',
    (WidgetTester tester) async {
      expect(defaultTargetPlatform, TargetPlatform.windows);
      expect(minimumTapTarget, 44);
    },
  );

  test('après eux, aucune plateforme ne reste forcée', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
