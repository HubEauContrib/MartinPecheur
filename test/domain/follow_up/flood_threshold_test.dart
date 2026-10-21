// Le seuil de suivi d'un tronçon et les rappels du réglage (M2 de T5).
import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/follow_up/flood_threshold.dart';

void main() {
  test('trois seuils, dans cet ordre, et aucun inconnu', () {
    expect(FloodThreshold.values, <FloodThreshold>[
      FloodThreshold.jaune,
      FloodThreshold.orange,
      FloodThreshold.rouge,
    ]);
  });

  test('les trois rappels sont exacts', () {
    expect(
      floodFollowUpReminder(FloodThreshold.jaune),
      'Prévenu : vigilance crues à partir du jaune',
    );
    expect(
      floodFollowUpReminder(FloodThreshold.orange),
      "Prévenu : vigilance crues à partir de l'orange",
    );
    expect(
      floodFollowUpReminder(FloodThreshold.rouge),
      'Prévenu : vigilance crues à partir du rouge',
    );
    expect(droughtFollowUpReminder, 'Prévenu : restrictions sécheresse');
  });
}
