#!/usr/bin/env bash
# install-deps.sh - Dependency Checker & Installer for ReClip Omarchy
# Usage:
#   install-deps.sh          -> Interactive dependency check & install prompt
#   install-deps.sh --json   -> Machine-readable JSON output for ReClip UI health check
#   install-deps.sh --check  -> Non-interactive terminal check & exit code

set -eo pipefail

check_tool() {
  local id="$1"
  local binary="$2"
  local package="$3"
  local category="$4"
  local name="$5"
  local desc="$6"
  local custom_test="${7:-}"

  local installed=false
  if [[ -n "$custom_test" ]]; then
    if eval "$custom_test" &>/dev/null; then
      installed=true
    fi
  elif command -v "$binary" &>/dev/null; then
    installed=true
  fi

  echo "$id|$binary|$package|$category|$name|$desc|$installed"
}

get_all_deps() {
  check_tool "wl-clipboard" "wl-paste" "wl-clipboard" "core" "Wayland Clipboard" "Clipboard capture daemon & paste mechanism"
  check_tool "jq" "jq" "jq" "core" "JSON Processor" "Metadata parsing & history indexing"
  check_tool "hyprland" "hyprctl" "hyprland" "core" "Hyprland Compositor" "Window attribution & password manager protection"
  check_tool "util-linux" "setpriv" "util-linux" "core" "Process Management" "Watcher lifecycle & death signal management"
  check_tool "perl" "perl" "perl" "core" "Perl 5" "Fast heuristic text encoding detection (UTF-8/16)"
  check_tool "zbar" "zbarimg" "zbar" "qr" "ZBar QR & Barcode Scanner" "Proactive detection & QR decoding studio"
  check_tool "qrencode" "qrencode" "qrencode" "qr" "QR Code Generator" "QR matrix creation & export"
  check_tool "python-pillow" "python3" "python-pillow" "qr" "Python Pillow (PIL)" "Custom QR eyes, module shapes, tracks & logos" "python3 -c 'import PIL' 2>/dev/null"
  check_tool "imagemagick" "magick" "imagemagick" "image" "ImageMagick" "Dominant palette extraction & image transforms" "command -v magick || command -v convert"
  check_tool "hyprpicker" "hyprpicker" "hyprpicker" "image" "Hyprpicker" "Screen eyedropper for colors & themes"
  check_tool "wtype" "wtype" "wtype" "tools" "Wtype Wayland Typer" "Direct app pasting & sequential Paste Queue"
  check_tool "tesseract" "tesseract" "tesseract tesseract-data-eng" "tools" "Tesseract OCR" "Optical text recognition from images"
  check_tool "slurp" "slurp" "slurp" "tools" "Slurp Region Selector" "Interactive screen area selection"
  check_tool "grim" "grim" "grim" "tools" "Grim Screenshotter" "Screen grabber for OCR and QR scanning"
  check_tool "libnotify" "notify-send" "libnotify" "tools" "Desktop Notifications" "Action feedback & background alerts"
}

if [[ "${1:-}" == "--json" ]]; then
  python3 -c '
import sys, json

items = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split("|")
    if len(parts) >= 7:
        items.append({
            "id": parts[0],
            "binary": parts[1],
            "package": parts[2],
            "category": parts[3],
            "name": parts[4],
            "desc": parts[5],
            "installed": (parts[6].lower() == "true")
        })

print(json.dumps(items))
' < <(get_all_deps)
  exit 0
fi

# Terminal formatted output
echo -e "\033[1;36m====================================================\033[0m"
echo -e "\033[1;36m   ReClip for Omarchy — System Dependency Check     \033[0m"
echo -e "\033[1;36m====================================================\033[0m"

missing_pkgs=()
installed_count=0
total_count=0

while IFS='|' read -r id binary package category name desc installed; do
  ((total_count++)) || true
  if [[ "$installed" == "true" ]]; then
    ((installed_count++)) || true
    echo -e " \033[1;32m[✓]\033[0m \033[1m$name\033[0m ($package) — $desc"
  else
    echo -e " \033[1;31m[✕]\033[0m \033[1m$name\033[0m (\033[1;33m$package\033[0m) — $desc"
    for p in $package; do
      if [[ ! " ${missing_pkgs[*]} " =~ " ${p} " ]]; then
        missing_pkgs+=("$p")
      fi
    done
  fi
done < <(get_all_deps)

echo -e "\033[1;36m----------------------------------------------------\033[0m"
echo -e "Status: \033[1m$installed_count/$total_count\033[0m dependencies installed."

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
  echo -e "\033[1;32mAll required & recommended packages are installed! ReClip is fully ready.\033[0m"
  exit 0
fi

echo -e "\n\033[1;33mMissing packages:\033[0m ${missing_pkgs[*]}"
echo -e "Install command:"
echo -e "  \033[1;32msudo pacman -S --needed ${missing_pkgs[*]}\033[0m\n"

if [[ "${1:-}" == "--check" ]]; then
  exit 1
fi

# Interactive prompt if running in terminal
if [[ -t 0 && -t 1 ]]; then
  read -r -p "Would you like to install the missing packages with pacman now? [Y/n] " answer
  case "${answer:-Y}" in
    [yY][eE][sS]|[yY])
      echo -e "\nRunning: sudo pacman -S --needed ${missing_pkgs[*]}"
      sudo pacman -S --needed "${missing_pkgs[@]}"
      echo -e "\n\033[1;32mDone! Dependencies installed successfully.\033[0m"
      ;;
    *)
      echo "Installation skipped."
      ;;
  esac
fi
