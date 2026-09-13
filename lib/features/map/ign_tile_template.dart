// Le gabarit de tuiles IGN Géoplateforme (WMTS KVP), plan `PLANIGNV2` sur le
// jeu `PM` — le seul adressable en `{z}/{x}/{y}` (F1, 2026-09-09). Intervertir
// `TILECOL` et `TILEROW` produit une carte qui s'affiche, transposée : aucune
// erreur, aucune tuile manquante — une panne silencieuse que seul un test
// attrape. Au-delà de `ignMaxNativeZoom`, la couche agrandit le niveau 18
// plutôt que de demander un niveau inexistant au serveur.
//
// Dart pur : aucun `package:flutter`, `package:flutter_map` ni
// `package:latlong2`. Le module qui construit le `TileLayer` (features/map)
// lit ces constantes ; il ne les recopie jamais.

/// Gabarit d'URL des tuiles IGN Géoplateforme, en WMTS KVP. `{z}`, `{x}` et
/// `{y}` sont substitués par l'appelant (`flutter_map` ou un test).
/// `TILECOL={x}` et `TILEROW={y}` : les intervertir transpose la carte sans
/// lever d'erreur.
const String ignTileUrlTemplate =
    'https://data.geopf.fr/wmts?SERVICE=WMTS&VERSION=1.0.0'
    '&REQUEST=GetTile&LAYER=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&STYLE=normal'
    '&TILEMATRIXSET=PM&FORMAT=image/png&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

/// Taille de tuile en pixels. Une valeur erronée décale le fond sans lever
/// d'erreur.
const int ignTileDimension = 256;

/// Niveau de zoom natif maximal du plan IGN ; au-delà, la couche agrandit le
/// niveau 18 plutôt que d'interroger un niveau inexistant.
///
/// Vérifié le 2026-09-13 par appel réel sur Paris (lat 48.85, lon 2.35,
/// Pseudo-Mercator) : `z18` (`TILECOL=132783&TILEROW=90192`) → HTTP 200,
/// `image/png`, 34 147 octets ; `z19` (`TILECOL=265566&TILEROW=180384`) →
/// HTTP 200, `image/png`, 32 250 octets. **Le niveau 19 existe aussi** côté
/// serveur : `18` reste un choix de charge (moins de tuiles demandées), pas
/// une limite constatée du service — à revoir en T1 si le rendu au zoom rue
/// justifie d'aller plus loin.
const int ignMaxNativeZoom = 18;

/// Attribution exigée par la Licence Ouverte — une constante du module,
/// jamais une chaîne recopiée dans un widget.
const String ignAttribution = '© IGN Géoplateforme — Licence Ouverte';

/// Agent utilisateur nommant l'appelant auprès du serveur de tuiles (C-12).
const String ignUserAgentPackageName = 'fr.martinpecheur.app';
