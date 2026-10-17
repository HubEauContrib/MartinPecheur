// Niveau de vigilance crues publie pour un troncon (T4, BR-015 : l'application
// relaie le niveau publie, elle n'en calcule aucun).
//
// sealed class et non enumeration : NiveauCruesInconnu doit porter la valeur
// brute recue (BR-011), ce qu'une valeur d'enum ne sait pas faire. Elle ne
// s'appelle pas `Inconnu` (`FlowCategory`) et les niveaux ne portent pas les
// noms de la gravite secheresse (`Vigilance`). La traduction du code publie
// vers ces branches se fait une seule fois, dans le mapper de la couche data.

/// Niveau de vigilance crues d'un troncon, tel que publie.
sealed class FloodVigilanceLevel {
  const FloodVigilanceLevel();
}

/// Vert.
final class Vert extends FloodVigilanceLevel {
  const Vert();

  @override
  bool operator ==(Object other) => other is Vert;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Jaune.
final class Jaune extends FloodVigilanceLevel {
  const Jaune();

  @override
  bool operator ==(Object other) => other is Jaune;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Orange.
final class Orange extends FloodVigilanceLevel {
  const Orange();

  @override
  bool operator ==(Object other) => other is Orange;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Rouge.
final class Rouge extends FloodVigilanceLevel {
  const Rouge();

  @override
  bool operator ==(Object other) => other is Rouge;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Niveau absent ou non reconnu. Porte la valeur brute [raw], telle que
/// recue, `null` compris — jamais normalisee (BR-011).
final class NiveauCruesInconnu extends FloodVigilanceLevel {
  const NiveauCruesInconnu(this.raw);

  /// La valeur telle que recue de la source.
  final Object? raw;

  @override
  bool operator ==(Object other) =>
      other is NiveauCruesInconnu && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => 'NiveauCruesInconnu($raw)';
}

/// Libelle court d'un niveau (etiquette, legende).
///
/// `switch` exhaustif : une branche ajoutee sans libelle est une erreur de
/// compilation (BR-011).
String floodLevelLabel(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'Vert',
  Jaune() => 'Jaune',
  Orange() => 'Orange',
  Rouge() => 'Rouge',
  NiveauCruesInconnu() => 'Niveau non reconnu',
};

/// Titre d'un niveau sur la fiche d'un troncon.
String floodVigilanceTitle(FloodVigilanceLevel level) => switch (level) {
  Vert() => 'Vigilance verte',
  Jaune() => 'Vigilance jaune',
  Orange() => 'Vigilance orange',
  Rouge() => 'Vigilance rouge',
  NiveauCruesInconnu() => 'Niveau de vigilance non reconnu',
};

/// Rang de dessin : le plus grave au-dessus, l'inconnu par-dessus tout.
int floodDrawingRank(FloodVigilanceLevel level) => switch (level) {
  Vert() => 0,
  Jaune() => 1,
  Orange() => 2,
  Rouge() => 3,
  NiveauCruesInconnu() => 4,
};
