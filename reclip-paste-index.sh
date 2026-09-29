#!/bin/bash
# Usage: reclip-paste-index <1-9>
set -euo pipefail

INDEX=${1:-1}
# Reject anything non-numeric before arithmetic: "08" and "1e1" otherwise emit
# a raw bash error into the Hyprland log.
[[ "$INDEX" =~ ^[1-9]$ ]] || exit 1
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
  # The stored history schema uses "text"; "fullText" only ever appears on the
  # display rows built for the UI, which are not written to this file. Reading
  # .fullText was a dead fallback that could never match.
  TEXT=$(echo "$ITEM" | jq -r '.text // empty')
  # Mirror ClipboardHistory.normalizeEntry(), which rejects a whitespace-only
  # value instead of storing it. -n alone would accept "   ", silently copy
  # blank space to the clipboard and paste nothing.
  if [[ -n "${TEXT//[[:space:]]/}" ]]; then
    printf '%s' "$TEXT" | wl-copy
    sleep 0.15
    wtype -M shift -k Insert -m shift 2>/dev/null || true
  fi
fi
