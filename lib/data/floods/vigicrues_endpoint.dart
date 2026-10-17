// L'adresse et le delai de Vigicrues (W2 de T4, cadrage § 6). Seul endroit,
// avec le mapper, qui connait l'hote d'API et le chemin du GeoJSON national
// (ADR-016, confinement du vocabulaire de l'API).
import 'package:http/http.dart' as http;
import 'package:martinpecheur/data/http/json_http_client.dart';

/// Adresse FINALE du GeoJSON national de l'information de vigilance, sans la
/// redirection de l'ancien chemin versionne (`VC-01`).
final Uri vigicruesInformationUri = Uri.parse(
  'https://www.vigicrues.gouv.fr/services/InfoVigiCru.geojson',
);

/// Duree maximale d'UNE tentative : 20 s (arbitrage, R3). Le fichier national
/// pese 2,2 Mo non compresses, sur un reseau mobile possiblement lent. Avec
/// quatre tentatives et les attentes de rejeu, le pire cas avant l'echec est
/// de 83,5 a 87 s, comme Hub'Eau.
const Duration vigicruesRequestTimeout = Duration(seconds: 20);

/// Transport partage (`JsonHttpClient`) regle sur le delai de Vigicrues.
JsonHttpClient vigicruesJsonClient(http.Client httpClient) => JsonHttpClient(
  httpClient: httpClient,
  requestTimeout: vigicruesRequestTimeout,
);
