# Source — IGN Géoplateforme (fond de carte)

Base URL : `https://data.geopf.fr/wmts` · WMTS 1.0.0, KVP · aucune authentification ·
Licence Ouverte — **attribution obligatoire** (`ignAttribution`,
`lib/features/map/ign_tile_template.dart`). Rôle : fond de plan (`LAYER=`
`GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2`), jeu `TILEMATRIXSET=PM` (Pseudo-Mercator, le seul
adressable en `{z}/{x}/{y}`).

## Faits constatés

- **2026-09-13** (commit `1c74c9d`, vérifié deux fois — cadrage et commit) :
  `TILEMATRIX=9&TILECOL=253&TILEROW=180` → HTTP **200**, `image/png`, **31 087 octets**.
- **2026-09-13** (relecture M1, Paris lat 48.85/lon 2.35, Pseudo-Mercator) :
  `TILEMATRIX=18&TILECOL=132783&TILEROW=90192` → HTTP **200**, `image/png`,
  **34 147 octets** ; `TILEMATRIX=19&TILECOL=265566&TILEROW=180384` → HTTP **200**,
  `image/png`, **32 250 octets**. Le niveau **19 existe** côté serveur ;
  `ignMaxNativeZoom = 18` reste un choix de charge, pas une limite constatée — à revoir
  en T1.
- Intervertir `TILECOL` et `TILEROW` transpose la carte **sans erreur** — aucune tuile
  manquante, panne silencieuse que seul un test attrape (`lib/features/map/ign_tile_template.dart`).

## Comportement du client

Cache de tuiles **intégré à `flutter_map` depuis 8.2** (`BuiltInMapCachingProvider`,
1 Go), actif par défaut hors web. 🔄 **Comportement hors réseau jamais exécuté** —
constaté dans la doc seulement à ce stade ; c'est ce que `UC-001 A3` doit décrire.

## Non vérifié

- Aucun SLA ni quota chiffré rencontré (`C-15`) — throttle client à l'aveugle, comme pour
  Hub'Eau et VigiEau.
- Le comportement du cache intégré en coupure réseau réelle.
