// Profil d'usager — conception T2 § 2.7. Un enum SANS branche inconnue, et
// ce n'est pas un ecart a BR-011 : BR-011 vise une valeur RECUE d'une API,
// alors que le profil est CHOISI par l'usager dans un ensemble que nous
// fermons. La source expose quatre booleens nommes ; un profil qu'elle
// ajouterait arriverait par un champ nouveau, que le mapper ignore.
//
// Aucune valeur n'est envoyee a la source (AR-1) : l'appel se fait sans
// profil, le filtrage a lieu dans le domaine.

/// Profil de l'usager, dans l'ordre d'`UC-002`, etape 4.
enum UserProfile { particulier, exploitation, collectivite, entreprise }

/// Libelle affichable d'un [UserProfile] — le SEUL du projet (Q-5b de C1,
/// arbitre le 2026-09-27 ; `O9` clos). `switch` exhaustif.
String userProfileLabel(UserProfile profile) => switch (profile) {
  UserProfile.particulier => 'Particulier',
  UserProfile.exploitation => 'Exploitation',
  UserProfile.collectivite => 'Collectivité',
  UserProfile.entreprise => 'Entreprise',
};
