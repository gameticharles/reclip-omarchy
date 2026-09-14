#!/usr/bin/env bash
# sync-keybindings.sh
# Synchronizes ReClip keybindings with ~/.config/hypr/bindings.lua
# Can be run manually, or automatically by ReClip on startup & settings change.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY=false

for arg in "$@"; do
  if [[ "$arg" == "--notify" ]]; then
    NOTIFY=true
  fi
done

python3 - <<EOF
import json
import os
import re
import subprocess
import sys

state_dir = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
settings_path = os.path.join(state_dir, "reclip", "settings.json")
bindings_path = os.path.expanduser("~/.config/hypr/bindings.lua")
home = os.path.expanduser("~")

toggle_shortcut = "SUPER + SHIFT + V"
paste_modifiers = "SUPER + CTRL + SHIFT"
enable_quick_paste = True

if os.path.isfile(settings_path):
    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            s = json.load(f)
            if s.get("toggleShortcut") and str(s["toggleShortcut"]).strip():
                toggle_shortcut = str(s["toggleShortcut"]).strip()
            if s.get("pasteModifiers") and str(s["pasteModifiers"]).strip():
                paste_modifiers = str(s["pasteModifiers"]).strip()
            if s.get("enableQuickPaste") is not None:
                enable_quick_paste = bool(s["enableQuickPaste"])
    except Exception as e:
        sys.stderr.write(f"Warning: could not read {settings_path}: {e}\n")

# 1. Ensure ~/.local/bin/reclip-paste-index is installed
local_bin = os.path.join(home, ".local", "bin")
os.makedirs(local_bin, exist_ok=True)
src_script = os.path.join("${PLUGIN_DIR}", "reclip-paste-index.sh")
dst_script = os.path.join(local_bin, "reclip-paste-index")
if os.path.isfile(src_script):
    import shutil
    shutil.copy2(src_script, dst_script)
    os.chmod(dst_script, 0o755)

# 2. Read existing bindings.lua
existing_content = ""
if os.path.isfile(bindings_path):
    with open(bindings_path, "r", encoding="utf-8") as f:
        existing_content = f.read()
else:
    os.makedirs(os.path.dirname(bindings_path), exist_ok=True)

# 3. Build the ReClip block
block_lines = [
    "-- >>> BEGIN RECLIP SHORTCUTS >>>",
    "-- Managed automatically by ReClip plugin. Edits inside this block may be overwritten.",
    f'pcall(function() hl.unbind("{toggle_shortcut}") end)',
    f'o.bind("{toggle_shortcut}", "ReClip Clipboard Manager", "omarchy-shell reclip toggle")'
]

if enable_quick_paste:
    block_lines.append("")
    block_lines.append("-- Quick Paste Items 1-9")
    block_lines.append("for i = 1, 9 do")
    block_lines.append(f'  local key = "{paste_modifiers} + code:" .. tostring(i + 9)')
    block_lines.append("  pcall(function() hl.unbind(key) end)")
    block_lines.append('  o.bind(key, "Paste clip item " .. i, "reclip-paste-index " .. i)')
    block_lines.append("end")

block_lines.append("-- <<< END RECLIP SHORTCUTS <<<")
reclip_block = "\n".join(block_lines)

# Remove any existing ReClip block
pattern = r"-- >>> BEGIN RECLIP SHORTCUTS >>>[\s\S]*?-- <<< END RECLIP SHORTCUTS <<<"
cleaned = re.sub(pattern, "", existing_content)

# Also remove legacy un-tagged ReClip bindings if present
legacy_patterns = [
    r'o\.bind\(\s*"SUPER\s*\+\s*SHIFT\s*\+\s*V"\s*,\s*"ReClip"\s*,\s*"omarchy-shell\s+reclip\s+toggle"\s*\)',
    r"-- ReClip Quick Paste Items 1-9[\s\S]*?reclip-paste-index\s*\"?\s*\.\.\s*i[\s\S]*?end\s*"
]
for lp in legacy_patterns:
    cleaned = re.sub(lp, "", cleaned)

cleaned = cleaned.rstrip()
new_content = cleaned + "\n\n" + reclip_block + "\n"

if new_content != existing_content:
    with open(bindings_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    print("SYNC_CHANGED")
else:
    print("SYNC_UNCHANGED")
EOF

if [[ "$NOTIFY" == "true" ]]; then
  notify-send -a "ReClip" "Shortcuts Synchronized" "Hyprland keybindings have been updated and reloaded." 2>/dev/null || true
fi
