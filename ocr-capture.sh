#!/usr/bin/env bash
# ReClip OCR Text Extraction Tool
# Usage:
#   ocr-capture.sh                  -> Screen region selection via slurp & OCR
#   ocr-capture.sh /path/to/img.png -> OCR existing image file

set -euo pipefail

TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
IMG_PATH=""
CLEANUP_IMG=false

if [ $# -ge 1 ]; then
  # An argument was given, so this is the "OCR an existing file" mode. A
  # mistyped or unreadable path used to fall through to the region-selection
  # branch, silently grabbing a screenshot of the screen instead of reporting
  # the bad path.
  if [ ! -f "$1" ]; then
    notify-send -a "ReClip OCR" -i "dialog-error" "OCR Error" "No such file: $1"
    exit 1
  fi
  if [ ! -r "$1" ]; then
    notify-send -a "ReClip OCR" -i "dialog-error" "OCR Error" "File not readable: $1"
    exit 1
  fi
  IMG_PATH="$1"
else
  GEO=$(slurp 2>/dev/null || true)
  if [ -z "$GEO" ]; then
    exit 0
  fi
  IMG_PATH="$TMP_DIR/reclip-ocr-$$.png"
  grim -g "$GEO" "$IMG_PATH"
  CLEANUP_IMG=true
fi

if [ ! -f "$IMG_PATH" ]; then
  exit 0
fi

TXT_BASE="$TMP_DIR/reclip-ocr-txt-$$"
tesseract "$IMG_PATH" "$TXT_BASE" --oem 1 -l eng 2>/dev/null || true

if [ -f "${TXT_BASE}.txt" ]; then
  EXTRACTED=$(cat "${TXT_BASE}.txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -n "$EXTRACTED" ]; then
    echo -n "$EXTRACTED" | wl-copy
    WORD_COUNT=$(echo "$EXTRACTED" | wc -w)
    notify-send -a "ReClip OCR" -i "accessories-text-editor" "Text Recognized" "Copied $WORD_COUNT words to clipboard"
  else
    notify-send -a "ReClip OCR" -i "dialog-information" "OCR" "No text recognized in image"
  fi
  rm -f "${TXT_BASE}.txt"
fi

if [ "$CLEANUP_IMG" = true ]; then
  rm -f "$IMG_PATH"
fi
