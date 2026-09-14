#!/bin/bash
# Usage: reclip-paste-index <1-9>

INDEX=${1:-1}
(( INDEX >= 1 && INDEX <= 9 )) || exit 1
ARRAY_INDEX=$(( INDEX - 1 ))

HISTORY_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/reclip/clipboard-history.json"
[[ -r "$HISTORY_FILE" ]] || exit 1

ITEM=$(jq -c ".[$ARRAY_INDEX] // empty" "$HISTORY_FILE" 2>/dev/null)
[[ -n "$ITEM" ]] || exit 0

TYPE=$(echo "$ITEM" | jq -r '.type // empty')

if [[ "$TYPE" == "image" ]]; then
  PATH_IMG=$(echo "$ITEM" | jq -r '.path // empty')
  MIME=$(echo "$ITEM" | jq -r '.mime // "image/png"')
  if [[ -r "$PATH_IMG" ]]; then
    wl-copy --type "$MIME" < "$PATH_IMG"
    sleep 0.15
    wtype -M shift -k Insert -m shift 2>/dev/null || true
  fi
else
  TEXT=$(echo "$ITEM" | jq -r '.text // .fullText // empty')
  if [[ -n "$TEXT" ]]; then
    printf '%s' "$TEXT" | wl-copy
    sleep 0.15
    wtype -M shift -k Insert -m shift 2>/dev/null || true
  fi
fi
