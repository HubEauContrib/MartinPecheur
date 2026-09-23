// Les depots restent betes : ils lisent, ils n'orchestrent pas, et ils ne
// decident pas de la politique de cache — cela reste au seul decorateur
// CachePolicy (`lib/data/cache/cache_policy.dart`). Un widget n'appelle
// jamais un depot : il passe par le ViewModel de sa tranche, qui appelle le
// depot directement et de facon typee (R3/R4, arbitrage 2026-09-13 —
// ADR-014 remplace le volet CQRS leger d'ADR-008).
//
// Bounds ne vit plus ici mais dans `lib/domain/geo/bounds.dart` (relecture du
// 2026-09-13) : la vue en construit une a chaque relachement de geste, et elle
// n'a pas a importer les contrats de depot pour cela.

import 'package:martinpecheur/domain/geo/bounds.dart';
import 'package:martinpecheur/domain/geo/viewport_filter.dart'
    show defaultViewportMargin;
import 'package:martinpecheur/domain/observation/hydro_observation.dart';
import 'package:martinpecheur/domain/onde/onde_observation.dart';
import 'package:martinpecheur/domain/onde/onde_station_code.dart';
import 'package:martinpecheur/domain/station/station.dart';
import 'package:martinpecheur/domain/station/station_point.dart';

/// Depot du referentiel des stations. Lit, ne decide de rien : ni cache, ni
/// orchestration.
///
/// Une seule methode, et elle suffit (YAGNI) : `findWithinBounds` et
/// `findByDepartement` ont ete retirees a la relecture du 2026-09-13 — rien
/// ne les appelait. La carte passe par [StationPointRepository] ; un filtre
/// par departement viendra avec l'ecran qui le demande, pas avant.
abstract interface class StationRepository {
  /// La station de code [code], ou `null` si aucune station ne porte ce
  /// code (BR-007) — jamais une erreur pour une absence attendue. Premier
  /// appelant : la fiche station (T1).
  Future<Station?> findByCode(StationCode code);
}

/// Depot des points de carte du referentiel : la projection [StationPoint],
/// pas l'entite [Station] complete.
///
/// Un depot a lui seul, et non une methode de plus sur [StationRepository]
/// (R3, arbitrage 2026-09-13) : c'est une segregation d'interface (le `I` de
/// SOLID). La carte n'a besoin que de code, libelle et coordonnees, et la
/// marge d'emprise n'a de sens que pour elle — la fiche station, qui lit une
/// [Station] complete par son code, n'a rien a faire d'une emprise elargie
/// et ne doit pas dependre d'une methode qu'elle n'appelle jamais.
abstract interface class StationPointRepository {
  /// Les points dont les coordonnees tombent dans [bounds], elargie de
  /// [margin] fois sa hauteur et sa largeur de chaque cote.
  ///
  /// [margin] est proportionnel, jamais un nombre de degres fixe (voir
  /// `stationsWithinViewport`) : c'est le seul endroit ou la marge par
  /// defaut est nommee dans un contrat de depot. Une liste vide est une
  /// absence, jamais une erreur (BR-007).
  Future<List<StationPoint>> withinBounds(
    Bounds bounds, {
    double margin = defaultViewportMargin,
  });
}

/// Depot des observations hydrometriques. Lit la derniere observation
/// connue, ne calcule ni fraicheur ni conversion — deja faites en amont
/// (mapper, BR-002).
abstract interface class HydroObservationRepository {
  /// La derniere observation connue pour [station] et [grandeur].
  /// [grandeur] est obligatoire : une hauteur et un debit ne sont jamais
  /// confondus.
  Future<HydroObservation?> findLatest(StationCode station, Grandeur grandeur);
}

/// Le résultat d'UN balayage d'emprise ONDE : les observations lisibles, et
/// le nombre de lignes que la source a rendues sans qu'on sache les lire.
///
/// Le compte est **rattaché à l'appel**, jamais à une instance de dépôt
/// (`U6`, correctif `T-14`). C'est ce qui le rend affichable : « N points
/// d'observation non lisibles sur cette emprise » décrit l'emprise que
/// l'usager regarde. Un compteur cumulé sur la durée de vie du dépôt aurait
/// décrit la session — un chiffre exact que personne ne peut situer, donc
/// inutilisable pour expliquer une absence (BR-007).
///
/// Pourquoi un type et non un simple couple : ces deux valeurs voyagent
/// ensemble du dépôt HTTP jusqu'à l'écran, en traversant le décorateur de
/// cache, qui les met en cache **ensemble** — le compte est une propriété de
/// la page lue, pas de la lecture. Deux champs nommés se lisent mieux qu'un
/// `record` anonyme à chaque `await`.
///
/// [unreadableRows] vaut zéro quand rien n'a été refusé. Zéro n'est jamais
/// un défaut de commodité : c'est le fait constaté sur cette emprise — une
/// page vide qui n'a rien refusé le dit avec `observations` vide ET
/// `unreadableRows` nul, et l'écran ne dira pas la même chose dans les deux
/// cas.
final class OndeSweep {
  const OndeSweep({required this.observations, required this.unreadableRows});

  /// Les observations lisibles de l'emprise, une par station. Jamais
  /// `null` : une absence est une liste vide (BR-007). Ne doit pas être
  /// modifiée en place — copier avant de trier, comme pour les deux
  /// méthodes du dépôt.
  final List<OndeObservation> observations;

  /// Nombre de lignes que la source a rendues et que le mapper n'a pas su
  /// lire, **sur cet appel**. Positif, zéro compris.
  final int unreadableRows;
}

/// Depot des observations d'ecoulement ONDE. Lit, ne decide de rien : le
/// TTL saisonnier reste au seul decorateur de cache (`lib/data/onde/
/// cached_onde_observation_repository.dart`), jamais ici. Le regroupement
/// d'une observation par station, lui, est un fait de lecture — pas une
/// politique de cache : il vit dans `latestWithinBounds` du depot HTTP
/// (`lib/data/onde/http_onde_observation_repository.dart`), au meme titre
/// que la conversion d'unites faite par le mapper. Contrat des deux
/// methodes : la liste rendue ne doit jamais etre modifiee en place (une
/// implementation peut la rendre immuable) ; copier avant de trier.
abstract interface class OndeObservationRepository {
  /// Les dernieres observations dont les stations tombent dans [bounds],
  /// filtrees sur `date_observation_min` = [since] (BR-010 : la carte ne
  /// remonte jamais plus loin qu'une campagne recente). [since] est
  /// INCLUSIF : une observation datee exactement a [since] est retenue,
  /// comme le fait l'API sur `date_observation_min`. Un balayage sans
  /// observation est une absence, jamais une erreur (BR-007).
  ///
  /// Rend un [OndeSweep] et non une liste : le nombre de lignes illisibles
  /// voyage AVEC les observations qu'il explique (`U6`, `T-14`). C'est
  /// l'emprise qui a un compte, pas le depot.
  Future<OndeSweep> latestWithinBounds(
    Bounds bounds, {
    required DateTime since,
  });

  /// L'historique des [limit] dernieres observations connues pour
  /// [station], le plus recent en tete. [limit] vaut 5 par defaut : c'est
  /// ce que la fiche station ONDE (T1) affiche. Chaque observation rendue
  /// porte le meme `OndePoint` (D8) : l'API le repete sur chaque ligne, et
  /// c'est assume ici plutot que factorise — un second appel pour ne lire
  /// le point qu'une fois coterait plus qu'il n'economise.
  Future<List<OndeObservation>> historyFor(
    OndeStationCode station, {
    int limit = 5,
  });
}

/// Depot de l'acquittement de l'avertissement initial (BR-012). Lit et
/// ecrit une **version** — une chaine de texte, jamais un booleen : c'est ce
/// qui permet de faire relire l'avertissement quand son texte change
/// (`UC-006 A3`), la ou un booleen ne distinguerait jamais « acquitte une
/// fois » de « acquitte CETTE version ».
///
/// Le depot reste bete (meme principe que les autres depots de ce fichier) :
/// une valeur stockee inattendue — par exemple une chaine vide — est rendue
/// **telle quelle**. C'est `WarningsViewModel` qui decide ce qu'elle signifie
/// (`feat V4`), jamais ce depot.
///
/// L'implementation arrive en `W1`, sous `lib/data/` : `shared_preferences`
/// est le candidat retenu par `ADR-011` pour cette preference simple. Cette
/// interface, elle, vit dans le domaine des `V4` — pas apres — car
/// `WarningsViewModel` en depend directement (inversion des dependances,
/// `test/architecture/layers_test.dart`, regle `features-vers-data`).
abstract interface class AcknowledgementRepository {
  /// La version du texte d'avertissement acquittee, ou `null` si aucune
  /// n'a jamais ete ecrite (premier lancement). Une chaine vide, si elle est
  /// stockee, est rendue telle quelle — ce n'est pas au depot de decider
  /// qu'elle ne vaut pas acquittement.
  Future<String?> readAcknowledgedVersion();

  /// Persiste [version] comme version acquittee. Ecrase toute valeur
  /// precedente : un seul acquittement est retenu a la fois.
  Future<void> writeAcknowledgedVersion(String version);
}
