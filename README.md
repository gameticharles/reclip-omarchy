# 📋 ReClip for Omarchy

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Shell_Plugin-blue)](https://omarchyplugins.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Dependencies](https://img.shields.io/badge/Dependencies-Verified-brightgreen)](install-deps.sh)

**ReClip** is an advanced, keyboard-driven clipboard manager, media studio, and snippet library built natively for **Omarchy** and **Hyprland**. It combines high-speed clipboard history, proactive QR code reading, an inline image editor, text transformers, a diff viewer, sequential paste queues, and privacy protection into a unified desktop panel.

---

## ✨ Features

- **📋 Multi-Type History & Universal Search**
  - Instant search across text, links, code snippets, colors, and image clips.
  - Proactive full-text indexing of text decoded from QR codes and OCR.
  - Smart deduplication and revision stacking for iterative edits.

- **󰄲 Unified QR Studio & Local Wi-Fi Sharing**
  - **Generator & Styler**: Customizable finder patterns, dot/rounded module shapes, timing tracks, alignment patterns, and center logo presets.
  - **Scanner & Extractor**: Instant QR and barcode decoding from clipboard images or screen region captures (`slurp` + `grim`), with one-click URL opening and generator handoff.
  - **Bidirectional Wi-Fi File Sharing (QR Drop)**: Share files and entire directories over local Wi-Fi via a high-performance multithreaded HTTP server with zero cloud dependencies. Connected devices can download files directly or upload/drop files straight onto your desktop.

- **🎨 Image Studio & Color Palette Engine**
  - Inline annotations (arrows, rectangles, ellipses, text, highlights, spotlight, blur, pixelate).
  - Floating canvas zoom dock (`−`, `%`, `+`, `Fit`) for fast viewport control.
  - Dedicated layer management panel, font picker, and live property inspector.
  - Lossless transforms: crop, rotate, flip, resize, and color filters.
  - Automatic dominant color palette extraction from copied images.
  - Integrated system eyedropper (`hyprpicker`).

- **📌 Pin & Window Inhibit Protection**
  - Dedicated panel pin toggle (`󰐃`) to prevent dismissal when clicking outside.
  - Automatic focus-loss protection while working in sub-editors (Image Editor, Text Editor, Color Studio, QR Sharing).

- **⚡ Text Transformers & Diff Studio**
  - Over 30 instant transformers: JSON beautify/minify, Base64 encode/decode, case switching, hashing, slugify, markdown to HTML, and URL encoding.
  - Side-by-side and unified diff viewers with inline syntax highlighting.

- **⌨️ Paste Queue & Number-Slot Pasting**
  - Stage clips in sequential order and paste them one-by-one into active windows.
  - Number slot pasting: quickly paste items 1–9 using configurable keyboard shortcuts (`SUPER + CTRL + SHIFT + 1..9`).

- **🛡️ Privacy & Password Manager Protection**
  - Automatically suppresses clipboard capture when password managers (KeePass, 1Password, Bitwarden, Vault) are focused.
  - Custom per-app blacklist and one-click incognito mode.
  - Configurable retention limits and auto-pruning.

- **󰚥 Built-In System Health Check**
  - Real-time dependency prober in Settings with 1-click automated terminal installation for missing packages.

---

## 📦 Prerequisites

ReClip runs on **Omarchy 4.x** (Arch Linux). Install the required tools via `pacman`:

```bash
sudo pacman -S --needed \
    wl-clipboard \
    jq \
    qrencode \
    zbar \
    imagemagick \
    hyprpicker \
    slurp \
    grim \
    wtype \
    tesseract \
    tesseract-data-eng \
    libnotify \
    python \
    python-pillow \
    perl \
    util-linux
```

Alternatively, run the included interactive installer:

```bash
./install-deps.sh
```

---

## 🚀 Installation

### Via Omarchy CLI

```bash
omarchy plugin add https://github.com/rein22/reclip-omarchy --enable
```

### Via Omaplug (Plugin Manager)

1. Open **Omaplug** from the Omarchy bar.
2. Click **Add Plugin** and enter the repository URL.
3. Toggle **Enable** and select your preferred bar placement (`right`).

---

## ⌨️ Default Keybindings

ReClip automatically synchronizes keybindings with `~/.config/hypr/bindings.lua`:

| Shortcut | Action |
|---|---|
| `SUPER + SHIFT + V` | Open / Toggle ReClip Panel |
| `SUPER + CTRL + SHIFT + 1..9` | Quick Paste Clipboard Slot 1 through 9 |
| `Ctrl + C` | Copy selected clip to clipboard |
| `Ctrl + E` | Edit in Text Editor or Image Editor |
| `Ctrl + Q` | Open in Unified QR Studio |
| `Ctrl + T` | Open in Text Transformers |
| `Ctrl + D` | Diff against current clipboard |
| `Delete` | Delete clip from history |
| `Esc` | Close panel or active modal |

---

## 🛠️ CLI Utilities

ReClip includes standalone command-line tools you can bind to custom Hyprland hotkeys:

- **`qr-decode.sh`**: Decode QR codes from an image file or interactive screen selection (`slurp`):
  ```bash
  qr-decode.sh                     # Select screen region and decode to clipboard
  qr-decode.sh /path/to/image.png  # Decode specific image file
  ```

- **`ocr-capture.sh`**: Extract text from a screen region with OCR:
  ```bash
  ocr-capture.sh                   # Select screen region and copy text
  ```

- **`reclip-paste-index.sh`**: Paste a numbered slot into the focused application:
  ```bash
  reclip-paste-index 1             # Pastes slot 1 directly
  ```

---

## ⚙️ Configuration & Diagnostics

Access **Settings & Preferences** (`󰒓`) directly from the ReClip panel header to configure:
- **Retention**: History capacity (up to 10,000 clips) and expiration pruning (7, 30, 90 days, or unlimited).
- **Privacy**: Ignore password managers, sensitive data hints, and custom app blacklists.
- **Shortcuts**: Custom toggle hotkeys and quick paste modifier combinations.
- **System**: Live status of all 15 system tools with 1-click terminal install for missing packages.

---

## 📄 License

MIT License © 2026 Charles Gameti
