// Le contrat des restrictions passe au domaine (T2, M4 ; conception T2 § 3) :
// un ViewModel ne pouvait pas l'importer depuis `lib/data/` sans violer la
// regle de couches `features-vers-data` (`ADR-014`). L'ancienne couture
// (`lib/data/restrictions/restriction_source.dart`, ADR-004 T0) filtrait les
// seules eaux superficielles avec `SurfaceWaterRestriction` ; elle n'avait
// aucun appelant et est remplacee ici.
//
// `RestrictionSource` garde son nom : il est cite dans l'invariant de
// `CLAUDE.md` sur le confinement de la source des restrictions, dans
// `ADR-004` et `context-map.md`. Le mot « source » dit ce que les autres
// depots ne disent pas : c'est la frontiere d'un service externe instable,
// en version 0.1 (`C-16`).
//
// L'echec est LEVE, jamais rendu comme une valeur scellee (conception T2
// § 3) : `withCachePolicy` n'ecrit en cache que ce que `load` rend, jamais ce
// qu'il leve. Un echec rendu serait ecrit en cache et servi jusqu'a
// expiration — un point injoignable resterait affiche « injoignable »
// pendant 6 h apres son retour. « Aucune zone » n'est PAS un echec : c'est
// une reponse valide, `ZonesAtPoint` a `zones` vide (`BR-007`).
//
// Trois branches fermees, pas un `message` unique : la vue distingue un
// point que la source n'a pas su servir (`RequeteRefusee`, elle a repondu)
// d'une source qui n'a pas repondu du tout (`SourceInjoignable`) ou d'une
// reponse qui ne se laisse pas lire (`ReponseIllisible`). Un `switch`
// exhaustif sur `RestrictionLookupFailure` est une erreur de compilation
// tant qu'une branche manque (BR-011).

import 'package:martinpecheur/domain/geo/geo_point.dart';
import 'package:martinpecheur/domain/restrictions/zones_at_point.dart';

/// Source des zones d'alerte secheresse et restrictions au point designe.
///
/// Implementee sous `lib/data/restrictions/` (donnees) : `RestrictionSource`
/// n'y est que le contrat, verifie par un double de test en memoire ici et
/// par l'implementation reelle sous `test/data/`.
abstract interface class RestrictionSource {
  /// Les zones d'alerte au point [point], telles que la source les rend a
  /// l'instant de la reponse.
  ///
  /// Leve une [RestrictionLookupFailure], ne la rend jamais : c'est ce qui
  /// empeche `CachePolicy` d'ecrire un echec en cache.
  Future<ZonesAtPoint> zonesAt(GeoPoint point);
}

/// Echec d'interrogation d'une [RestrictionSource], ferme a trois branches
/// (BR-011) : une quatrieme cause n'existe pas encore pour ce produit, en
/// ajouter une est une decision de conception, pas un detail d'ecran.
sealed class RestrictionLookupFailure implements Exception {
  const RestrictionLookupFailure(this.diagnostic);

  /// Diagnostic technique, jamais affiche tel quel a l'usager (l'ecran
  /// affiche le nom de la source et un lien vers son site public,
  /// `source_names.dart`).
  final String diagnostic;
}

/// La source n'a pas repondu : panne reseau ou TLS, ou `429`/`5xx`
/// persistant apres les rejeux du transport partage.
final class SourceInjoignable extends RestrictionLookupFailure {
  const SourceInjoignable(super.diagnostic);

  @override
  bool operator ==(Object other) =>
      other is SourceInjoignable && other.diagnostic == diagnostic;

  @override
  int get hashCode => diagnostic.hashCode;

  @override
  String toString() => 'SourceInjoignable($diagnostic)';
}

/// La source a repondu, mais a refuse ce point precis : tout statut non
/// rejouable hors succes (`400`, `404`, `409`…).
final class RequeteRefusee extends RestrictionLookupFailure {
  const RequeteRefusee({required this.statusCode, required String diagnostic})
    : super(diagnostic);

  /// Code de statut HTTP tel que recu, sans interpretation.
  final int statusCode;

  @override
  bool operator ==(Object other) =>
      other is RequeteRefusee &&
      other.statusCode == statusCode &&
      other.diagnostic == diagnostic;

  @override
  int get hashCode => Object.hash(statusCode, diagnostic);

  @override
  String toString() => 'RequeteRefusee(statusCode: $statusCode, $diagnostic)';
}

/// La reponse ne se laisse pas lire : corps non JSON, racine qui n'est pas
/// un tableau, ou un champ obligatoire absent ou mal type (conception T2
/// § 4.4, tout ou rien — `AR-2`).
final class ReponseIllisible extends RestrictionLookupFailure {
  const ReponseIllisible(super.diagnostic);

  @override
  bool operator ==(Object other) =>
      other is ReponseIllisible && other.diagnostic == diagnostic;

  @override
  int get hashCode => diagnostic.hashCode;

  @override
  String toString() => 'ReponseIllisible($diagnostic)';
}
