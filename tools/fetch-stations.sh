#!/usr/bin/env bash
# tools/fetch-stations.sh — fige le référentiel des stations hydrométriques en service.
# size plafonne à 10000 (HTTP 400 au-delà, constaté le 2026-07-31). count observé : 4140.
set -euo pipefail

OUT="assets/referentiel/stations.geojson"
URL="https://hubeau.eaufrance.fr/api/v2/hydrometrie/referentiel/stations?en_service=1&size=10000&format=geojson"

mkdir -p "$(dirname "$OUT")"
status=$(curl -s -o "$OUT" -w "%{http_code}" "$URL")

# 206 est un succès (C-06) : le refuser casserait à la première pagination.
if [ "$status" != "200" ] && [ "$status" != "206" ]; then
  echo "Echec HTTP $status" >&2
  exit 1
fi

echo "HTTP $status — $(wc -c < "$OUT") octets — $OUT"
