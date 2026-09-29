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

# An unvalidated $LIMIT reached `head -n` verbatim, so a non-numeric argument
# failed the pipeline and, combined with the `|| echo "[]"` fallback below,
# emitted two JSON arrays. Callers parse this with jq, which then rejected the
# whole payload. Clamp to a sane integer range instead.
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 )); then
  LIMIT=12
fi
(( LIMIT > 64 )) && LIMIT=64

FETCH_COUNT=$(( LIMIT * 3 ))
if (( FETCH_COUNT < 20 )); then
  FETCH_COUNT=20
fi

CONVERTER=""
if command -v magick &>/dev/null; then
  CONVERTER="magick"
elif command -v convert &>/dev/null; then
  CONVERTER="convert"
fi

if [[ -z "$CONVERTER" ]]; then
  echo "[]"
  exit 0
fi

# Keep the pipeline's stdout only if it is a single well-formed JSON array.
# `jq -s .` can print "[]" and *then* fail under `set -e -o pipefail`, so a
# `|| echo "[]"` fallback would append a second array rather than replace it.
raw_colors=$("$CONVERTER" "$IMAGE" -resize 64x64\! -quantize RGB +dither -colors "$FETCH_COUNT" -unique-colors txt:- 2>/dev/null \
  | grep -oE '#[0-9A-Fa-f]{6}' | tr '[:lower:]' '[:upper:]' | awk '!seen[$0]++' | head -n "$LIMIT" \
  | jq -R . | jq -s . 2>/dev/null) || true

if [[ -n "$raw_colors" ]] && printf '%s' "$raw_colors" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "$raw_colors"
else
  echo "[]"
fi
