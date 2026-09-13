// Le seul endroit qui décide ce qu'est un succès HTTP (C-06). Constaté le
// 2026-09-13 sur le même endpoint hydrométrie : size=2 renvoie 206, une
// réponse vide renvoie 200 — un client qui n'accepte que 200 casse dès la
// première pagination. Un `if (status == 200)` ailleurs dans le code passe la
// revue et casse en production : toute lecture de statut doit passer par ici.
//
// 204/304 ne sont pas des échecs mais n'apportent pas de corps JSON : les
// traiter en succès ferait échouer la désérialisation plus loin plutôt que la
// lecture du statut elle-même. Ils restent donc en dehors de [isSuccess].
//
// Un 4xx vient de notre requête, le rejouer martèle un service public
// gratuit sans quota chiffré et sans chance de succès (403 = API arrêtée,
// C-01 ; 409 = appel par commune, C-14). Seuls 429 et les 5xx sont rejouables
// (C-12) : aucun quota chiffré n'est publié, la charge peut être transitoire.
const Set<int> _success = <int>{200, 206};

/// `true` si [statusCode] est un succès au sens de ce produit : 200 (réponse
/// complète) ou 206 (réponse partielle, paginée). Rien d'autre.
bool isSuccess(int statusCode) => _success.contains(statusCode);

/// `true` si rejouer la requête a une chance raisonnable d'aboutir : 429
/// (aucun quota chiffré, C-12) ou un 5xx (défaillance côté serveur). Jamais
/// un 4xx autre que 429 — l'erreur vient de notre requête, la rejouer ne la
/// corrige pas.
bool isRetryable(int statusCode) => statusCode == 429 || statusCode >= 500;
