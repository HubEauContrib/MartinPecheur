import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_level.dart';

/// Compile seulement si les cinq branches sont couvertes sans `default`
/// (BR-011).
int _exhaustive(FloodVigilanceLevel level) => switch (level) {
  Vert() => 0,
  Jaune() => 1,
  Orange() => 2,
  Rouge() => 3,
  NiveauCruesInconnu() => 4,
};

void main() {
  const List<FloodVigilanceLevel> levels = <FloodVigilanceLevel>[
    Vert(),
    Jaune(),
    Orange(),
    Rouge(),
    NiveauCruesInconnu(9),
  ];

  test('libellés', () {
    expect(levels.map(floodLevelLabel), <String>[
      'Vert',
      'Jaune',
      'Orange',
      'Rouge',
      'Niveau non reconnu',
    ]);
  });

  test('titres', () {
    expect(levels.map(floodVigilanceTitle), <String>[
      'Vigilance verte',
      'Vigilance jaune',
      'Vigilance orange',
      'Vigilance rouge',
      'Niveau de vigilance non reconnu',
    ]);
  });

  test(
    'rangs de dessin : le plus grave au-dessus, l\'inconnu par-dessus tout',
    () {
      expect(levels.map(floodDrawingRank), <int>[0, 1, 2, 3, 4]);
      expect(levels.map(_exhaustive), <int>[0, 1, 2, 3, 4]);
    },
  );

  test('égalité par type et par valeur brute', () {
    expect(const Vert(), const Vert());
    expect(const Vert(), isNot(const Jaune()));
    expect(const NiveauCruesInconnu(7), const NiveauCruesInconnu(7));
    expect(
      const NiveauCruesInconnu(7).hashCode,
      const NiveauCruesInconnu(7).hashCode,
    );
    expect(const NiveauCruesInconnu(7), isNot(const NiveauCruesInconnu('7')));
    expect(const NiveauCruesInconnu(7), isNot(const NiveauCruesInconnu(null)));
    expect(const NiveauCruesInconnu(7).raw, 7);
    expect(const NiveauCruesInconnu(7).toString(), 'NiveauCruesInconnu(7)');
  });
}
