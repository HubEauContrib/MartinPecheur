// Le seuil d'un tronçon suivi (M2 de T5) : un niveau PUBLIÉ, choisi par
// l'usager, comparé à un autre niveau publié (BR-016). L'application ne calcule
// aucun niveau.
//
// Un enum sans branche inconnue : c'est une valeur de l'usager, pas une donnée
// reçue d'une source (R2). Le vert n'est pas un seuil.

/// À partir de quel niveau publié l'usager veut être prévenu.
enum FloodThreshold { jaune, orange, rouge }

/// Le rappel affiché sous le réglage d'un tronçon : ce qui est suivi, dit tel
/// que réglé.
String floodFollowUpReminder(FloodThreshold threshold) => switch (threshold) {
  FloodThreshold.jaune => 'Prévenu : vigilance crues à partir du jaune',
  FloodThreshold.orange => "Prévenu : vigilance crues à partir de l'orange",
  FloodThreshold.rouge => 'Prévenu : vigilance crues à partir du rouge',
};

/// Le rappel affiché sous le réglage d'une station ou d'un point ONDE.
const String droughtFollowUpReminder = 'Prévenu : restrictions sécheresse';
