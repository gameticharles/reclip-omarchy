#!/bin/bash
# ReClip image palette extractor
# Extracts dominant colors from an image using ImageMagick
# Emits JSON array of hex strings: ["#RRGGBB", ...]

set -eo pipefail

IMAGE="$1"
LIMIT="${2:-12}"

if [[ -z "$IMAGE" || ! -f "$IMAGE" ]]; then
  echo "[]"
  exit 0
fi

FETCH_COUNT=$(( LIMIT * 3 ))
if (( FETCH_COUNT < 20 )); then
  FETCH_COUNT=20
fi

if command -v magick &>/dev/null; then
  colors=$(magick "$IMAGE" -resize 64x64\! -quantize RGB +dither -colors "$FETCH_COUNT" -unique-colors txt:- 2>/dev/null \
    | grep -oE '#[0-9A-Fa-f]{6}' | tr '[:lower:]' '[:upper:]' | awk '!seen[$0]++' | head -n "$LIMIT" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  echo "$colors"
elif command -v convert &>/dev/null; then
  colors=$(convert "$IMAGE" -resize 64x64\! -quantize RGB +dither -colors "$FETCH_COUNT" -unique-colors txt:- 2>/dev/null \
    | grep -oE '#[0-9A-Fa-f]{6}' | tr '[:lower:]' '[:upper:]' | awk '!seen[$0]++' | head -n "$LIMIT" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  echo "$colors"
else
  echo "[]"
fi
