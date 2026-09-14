#!/usr/bin/env bash
# ReClip QR Code & Barcode Decoding Tool
# Usage:
#   qr-decode.sh                  -> Screen region selection via slurp & decode
#   qr-decode.sh /path/to/img.png -> Decode existing image file

set -euo pipefail

TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
IMG_PATH=""
CLEANUP_IMG=false

if [ $# -ge 1 ] && [ -f "$1" ]; then
  IMG_PATH="$1"
else
  GEO=$(slurp 2>/dev/null || true)
  if [ -z "$GEO" ]; then
    exit 0
  fi
  IMG_PATH="$TMP_DIR/reclip-qr-$$.png"
  grim -g "$GEO" "$IMG_PATH"
  CLEANUP_IMG=true
fi

if [ ! -f "$IMG_PATH" ]; then
  exit 0
fi

if ! command -v zbarimg &>/dev/null; then
  notify-send -a "ReClip QR" -i "dialog-warning" "QR Scanner Error" "zbarimg utility not found. Please install zbar."
  exit 1
fi

EXTRACTED=$(zbarimg -q --raw "$IMG_PATH" 2>/dev/null || (magick "$IMG_PATH" -negate png:- 2>/dev/null | zbarimg -q --raw - 2>/dev/null) || true)

if [ -n "$EXTRACTED" ]; then
  echo -n "$EXTRACTED" | wl-copy
  PREVIEW=$(echo "$EXTRACTED" | head -n 1 | cut -c 1-50)
  if [ ${#EXTRACTED} -gt 50 ]; then
    PREVIEW="${PREVIEW}..."
  fi
  notify-send -a "ReClip QR" -i "edit-find" "QR Code Decoded" "Copied to clipboard: $PREVIEW"
else
  notify-send -a "ReClip QR" -i "dialog-information" "QR Scanner" "No QR code or barcode detected in image"
fi

if [ "$CLEANUP_IMG" = true ]; then
  rm -f "$IMG_PATH"
fi
