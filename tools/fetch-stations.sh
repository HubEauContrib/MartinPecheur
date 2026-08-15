#!/usr/bin/env bash
# tools/fetch-stations.sh — fige le référentiel des stations hydrométriques en service.
# size plafonne à 10000 (HTTP 400 au-delà, constaté le 2026-07-31). count observé : 4140.
set -euo pipefail

OUT="assets/referentiel/stations.geojson"
URL="https://hubeau.eaufrance.fr/api/v2/hydrometrie/referentiel/stations?en_service=1&size=10000&format=geojson"

mkdir -p "$(dirname "$OUT")"

# On écrit d'abord à côté. `curl -o` tronque sa cible AVANT de connaître le
# statut : viser $OUT directement ferait qu'un simple 503 remplacerait les
# 6,6 Mo de référentiel versionné par un corps d'erreur, et l'asset serait
# perdu avant même qu'on puisse le constater.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

status=$(curl -s -o "$TMP" -w "%{http_code}" "$URL")

# 206 est un succès (C-06) : le refuser casserait à la première pagination.
if [ "$status" != "200" ] && [ "$status" != "206" ]; then
  echo "Echec HTTP $status — $OUT laissé intact" >&2
  exit 1
fi

# Garde-fou minimal : une réponse vide ou tronquée n'est pas un référentiel.
if ! grep -q '"FeatureCollection"' "$TMP"; then
  echo "Reponse HTTP $status mais ce n'est pas un GeoJSON — $OUT laissé intact" >&2
  exit 1
fi

# `mktemp` crée en mode 600 et `mv` conserve ce mode : sans ce chmod, l'asset
# régénéré devient illisible pour les autres utilisateurs — un CI tournant sous
# un autre compte, par exemple. Git ne suit pas ce bit : la régression
# n'apparaîtrait dans aucun diff.
chmod 644 "$TMP"
mv "$TMP" "$OUT"
trap - EXIT

echo "HTTP $status — $(wc -c < "$OUT") octets — $OUT"
