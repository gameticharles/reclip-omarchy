#!/usr/bin/env python3
"""
qr_file_server.py - Ephemeral Local Wi-Fi File Drop Micro-Server for ReClip Omarchy

Features:
- Dual-interface binding (0.0.0.0) for both localhost and LAN accessibility
- Smart firewall port selection: tries open UFW port 53317 first, then fallback ports
- P1: Two-Way Transfer ("Reverse Drop"): Upload files from phone/tablet to ~/Downloads/ReClip-Drop
- P2: Bidirectional Clipboard Text Beam: Beam text/links between PC and phone in real time
- P3: Live Transfer Progress & Speedometer: Real-time throughput (MB/s, %, ETA) for up/down
- P4: Security Token & 4-Digit Quick PIN: 1-tap QR auto-auth + brutalist PIN lock for scanners
- P5: Folder & Directory Sharing: Recursive folder tree preservation in streaming ZIP
- Rich media previews: image lightbox, audio/video players, text/code viewer with copy
- Search and category filter chips for multi-file drops
- On-the-fly streaming ZIP bundle for multi-file/folder drops
- Full HTTP Range support (RFC 7233) for chunked mobile downloads
- RFC 5987 / RFC 6266 UTF-8 attachment headers
- Real-time JSON events to stdout for QML reactive UI
- Threaded socket server for concurrent request handling
"""

import sys
import os
import time
import socket
import socketserver
import argparse
import json
import mimetypes
import urllib.parse
import tempfile
import zipfile
import html
import secrets
import subprocess
import threading
import shutil
from http.server import HTTPServer, BaseHTTPRequestHandler

PREFERRED_PORTS = [53317, 53318, 8080, 8000, 8888, 0]

def get_lan_ip():
    """Detect primary outbound LAN IP."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        try:
            s.connect(('8.8.8.8', 1))
            ip = s.getsockname()[0]
        except Exception:
            ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def format_size(size_bytes):
    """Format bytes into human-readable representation."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"

def format_speed(bps):
    """Format bytes per second into human-readable speed."""
    if bps < 1024:
        return f"{bps:.0f} B/s"
    elif bps < 1024 * 1024:
        return f"{bps / 1024:.1f} KB/s"
    elif bps < 1024 * 1024 * 1024:
        return f"{bps / (1024 * 1024):.1f} MB/s"
    else:
        return f"{bps / (1024 * 1024 * 1024):.2f} GB/s"

def format_eta(seconds):
    """Format remaining seconds into human-readable ETA."""
    if seconds <= 0:
        return "0s"
    elif seconds < 60:
        return f"{int(seconds)}s"
    elif seconds < 3600:
        m = int(seconds // 60)
        s = int(seconds % 60)
        return f"{m}m {s}s"
    else:
        h = int(seconds // 3600)
        m = int((seconds % 3600) // 60)
        return f"{h}h {m}m"

def get_file_category(filename, is_dir=False):
    if is_dir:
        return 'folder'
    ext = os.path.splitext(filename)[1].lower()
    if ext in ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico', '.avif', '.tiff'):
        return 'image'
    elif ext in ('.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v'):
        return 'video'
    elif ext in ('.mp3', '.flac', '.wav', '.ogg', '.m4a', '.aac', '.opus'):
        return 'audio'
    elif ext in ('.zip', '.tar', '.gz', '.bz2', '.xz', '.7z', '.rar'):
        return 'archive'
    elif ext in ('.pdf', '.doc', '.docx', '.odt', '.rtf'):
        return 'document'
    elif ext in ('.py', '.js', '.qml', '.json', '.sh', '.rs', '.go', '.c', '.cpp', '.h', '.html', '.css', '.ts', '.lua', '.yaml', '.yml', '.toml', '.sql'):
        return 'code'
    elif ext in ('.txt', '.md', '.log', '.csv', '.tsv', '.conf', '.ini', '.env'):
        return 'text'
    return 'other'

def get_category_badge_info(cat):
    badges = {
        'folder': ('Folder', '#38bdf8', '#e0f2fe'),
        'image': ('Image', '#f43f5e', '#ffe4e6'),
        'video': ('Video', '#e11d48', '#ffe4e6'),
        'audio': ('Audio', '#10b981', '#d1fae5'),
        'archive': ('Archive', '#f59e0b', '#fef3c7'),
        'document': ('Document', '#0ea5e9', '#e0f2fe'),
        'code': ('Code', '#8b5cf6', '#ede9fe'),
        'text': ('Text', '#38bdf8', '#f0f9ff'),
        'other': ('File', '#64748b', '#f1f5f9')
    }
    return badges.get(cat, ('File', '#64748b', '#f1f5f9'))

def get_svg_icon(category, size=24):
    icons = {
        'folder': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"/></svg>''',
        'image': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#f43f5e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="3"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/></svg>''',
        'video': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#e11d48" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="3"/><polygon points="10 9 15 12 10 15 10 9" fill="#e11d48"/></svg>''',
        'audio': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>''',
        'archive': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="5" x="2" y="3" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/></svg>''',
        'document': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#0ea5e9" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><line x1="10" y1="9" x2="8" y2="9"/></svg>''',
        'code': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#8b5cf6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>''',
        'text': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1-2.5-2.5Z"/><path d="M8 7h6"/><path d="M8 11h8"/></svg>''',
        'other': f'''<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/></svg>'''
    }
    return icons.get(category, icons['other'])

def get_text_preview(file_path, max_bytes=16384, max_lines=40):
    """Read first few lines of a text file for in-page preview."""
    try:
        if os.path.isdir(file_path):
            return None
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read(max_bytes)
            lines = content.splitlines()
            if len(lines) > max_lines:
                return "\n".join(lines[:max_lines]) + "\n... (more lines truncated)"
            elif len(content) >= max_bytes:
                return content + "\n... (truncated)"
            return content
    except Exception:
        return None

def emit_event(event_dict):
    """Emit JSON event line to stdout and flush."""
    try:
        line = json.dumps(event_dict)
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except Exception:
        pass

def send_desktop_notification(title, message, icon="document-save"):
    """Spawn background notify-send to avoid blocking request thread."""
    def _notify():
        try:
            subprocess.run(["notify-send", title, message, f"--icon={icon}"], check=False, timeout=3)
        except Exception:
            pass
    threading.Thread(target=_notify, daemon=True).start()

def set_desktop_clipboard(text):
    """Copy text to Linux clipboard using wl-copy or xclip."""
    try:
        proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        proc.communicate(input=text.encode("utf-8"), timeout=3)
        return True
    except Exception:
        try:
            proc = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE)
            proc.communicate(input=text.encode("utf-8"), timeout=3)
            return True
        except Exception:
            return False

def get_desktop_clipboard():
    """Read current desktop clipboard using wl-paste."""
    try:
        res = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            return res.stdout
    except Exception:
        pass
    return ""

class ThreadedFileShareServer(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 128  # Hardened TCP listen backlog for burst connections / simultaneous QR scans

    def __init__(self, server_address, RequestHandlerClass, files_meta, lan_ip, single_shot=False, token=None, pin=None, save_dir=None, allow_upload=True, allow_beam=True, max_upload_size=1024*1024*1024, max_session_quota=5*1024*1024*1024):
        super().__init__(server_address, RequestHandlerClass)
        self.files_meta = files_meta
        self.files_map = {item["name"]: item["path"] for item in files_meta}
        self.lan_ip = lan_ip
        self.single_shot = single_shot
        self.token = token or secrets.token_hex(16)
        # High-entropy 6-digit cryptographic PIN by default (1,000,000 combinations + rate limit & lockout)
        self.pin = str(pin).strip() if pin else f"{secrets.randbelow(900000) + 100000}"
        self.save_dir = os.path.expanduser(save_dir or "~/Downloads/ReClip-Drop")
        os.makedirs(self.save_dir, exist_ok=True)
        self.allow_upload = bool(allow_upload)
        self.allow_beam = bool(allow_beam)
        self.max_upload_size = int(max_upload_size)
        self.max_session_upload_quota = int(max_session_quota)
        self.session_uploaded_bytes = 0
        self.beam_text = ""
        self.should_stop = False
        self.download_completed = False
        self.completion_time = 0.0
        self.zip_cache_path = None
        self.folder_zip_cache = {}
        self.download_count = 0

        # Rate limiting and lockout state
        self.attempt_lock = threading.Lock()
        self.failed_attempts = {}       # client_ip -> {"count": int, "locked_until": float}
        self.global_failed_attempts = 0
        self.global_locked_until = 0.0

    def server_close(self):
        super().server_close()
        if self.zip_cache_path and os.path.exists(self.zip_cache_path):
            try:
                os.unlink(self.zip_cache_path)
            except Exception:
                pass
        for fzp in self.folder_zip_cache.values():
            if fzp and os.path.exists(fzp):
                try:
                    os.unlink(fzp)
                except Exception:
                    pass

FAVICON_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#181825"/><path d="M16 6v14m-5-5 5 5 5-5M8 24h16" stroke="#38bdf8" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>"""

PORTAL_CSS = """
:root {
  --bg: #0b0f17;
  --card-bg: rgba(22, 27, 38, 0.85);
  --card-hover: rgba(28, 35, 49, 0.95);
  --card-border: rgba(255, 255, 255, 0.08);
  --card-border-hover: rgba(56, 189, 248, 0.35);
  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --text-dim: #64748b;
  --accent: #38bdf8;
  --accent-hover: #0ea5e9;
  --accent-glow: rgba(56, 189, 248, 0.2);
  --btn-primary-text: #0b0f17;
  --success: #34d399;
  --success-hover: #10b981;
  --btn-secondary: #1e293b;
  --btn-secondary-border: rgba(255, 255, 255, 0.1);
  --code-bg: #090d16;
  --nav-bg: rgba(11, 15, 23, 0.92);
  --input-bg: rgba(11, 15, 23, 0.8);
  --drop-bg: rgba(56, 189, 248, 0.03);
  --bundle-grad: linear-gradient(135deg, rgba(56, 189, 248, 0.15) 0%, rgba(30, 41, 59, 0.8) 100%);
  --bundle-border: rgba(56, 189, 248, 0.35);
  --radius-lg: 12px;
  --radius-md: 8px;
  --radius-sm: 4px;
}

@media (prefers-color-scheme: light) {
  :root:not([data-theme="dark"]) {
    --bg: #f8fafc;
    --card-bg: #ffffff;
    --card-hover: #f1f5f9;
    --card-border: rgba(0, 0, 0, 0.09);
    --card-border-hover: rgba(2, 132, 199, 0.4);
    --text-main: #0f172a;
    --text-muted: #475569;
    --text-dim: #94a3b8;
    --accent: #0284c7;
    --accent-hover: #0369a1;
    --accent-glow: rgba(2, 132, 199, 0.18);
    --btn-primary-text: #ffffff;
    --success: #059669;
    --success-hover: #047857;
    --btn-secondary: #f1f5f9;
    --btn-secondary-border: rgba(0, 0, 0, 0.12);
    --code-bg: #f8fafc;
    --nav-bg: rgba(255, 255, 255, 0.92);
    --input-bg: #ffffff;
    --drop-bg: rgba(2, 132, 199, 0.03);
    --bundle-grad: linear-gradient(135deg, rgba(2, 132, 199, 0.12) 0%, rgba(241, 245, 249, 0.95) 100%);
    --bundle-border: rgba(2, 132, 199, 0.3);
  }
}

[data-theme="light"] {
  --bg: #f8fafc;
  --card-bg: #ffffff;
  --card-hover: #f1f5f9;
  --card-border: rgba(0, 0, 0, 0.09);
  --card-border-hover: rgba(2, 132, 199, 0.4);
  --text-main: #0f172a;
  --text-muted: #475569;
  --text-dim: #94a3b8;
  --accent: #0284c7;
  --accent-hover: #0369a1;
  --accent-glow: rgba(2, 132, 199, 0.18);
  --btn-primary-text: #ffffff;
  --success: #059669;
  --success-hover: #047857;
  --btn-secondary: #f1f5f9;
  --btn-secondary-border: rgba(0, 0, 0, 0.12);
  --code-bg: #f8fafc;
  --nav-bg: rgba(255, 255, 255, 0.92);
  --input-bg: #ffffff;
  --drop-bg: rgba(2, 132, 199, 0.03);
  --bundle-grad: linear-gradient(135deg, rgba(2, 132, 199, 0.12) 0%, rgba(241, 245, 249, 0.95) 100%);
  --bundle-border: rgba(2, 132, 199, 0.3);
}

[data-theme="dark"] {
  --bg: #0b0f17;
  --card-bg: rgba(22, 27, 38, 0.85);
  --card-hover: rgba(28, 35, 49, 0.95);
  --card-border: rgba(255, 255, 255, 0.08);
  --card-border-hover: rgba(56, 189, 248, 0.35);
  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --text-dim: #64748b;
  --accent: #38bdf8;
  --accent-hover: #0ea5e9;
  --accent-glow: rgba(56, 189, 248, 0.2);
  --btn-primary-text: #0b0f17;
  --success: #34d399;
  --success-hover: #10b981;
  --btn-secondary: #1e293b;
  --btn-secondary-border: rgba(255, 255, 255, 0.1);
  --code-bg: #090d16;
  --nav-bg: rgba(11, 15, 23, 0.92);
  --input-bg: rgba(11, 15, 23, 0.8);
  --drop-bg: rgba(56, 189, 248, 0.03);
  --bundle-grad: linear-gradient(135deg, rgba(56, 189, 248, 0.15) 0%, rgba(30, 41, 59, 0.8) 100%);
  --bundle-border: rgba(56, 189, 248, 0.35);
}

* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  background-color: var(--bg);
  color: var(--text-main);
  min-height: 100vh;
  line-height: 1.5;
  display: flex;
  flex-direction: column;
  -webkit-font-smoothing: antialiased;
  transition: background-color 0.2s ease, color 0.2s ease;
}
.top-navbar {
  position: sticky;
  top: 0;
  z-index: 50;
  background: var(--nav-bg);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--card-border);
  transition: background 0.2s ease, border-color 0.2s ease;
}
.nav-inner {
  max-width: 1100px;
  margin: 0 auto;
  padding: 0.75rem 1.25rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.nav-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  text-decoration: none;
  color: inherit;
}
.brand-logo-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  background: rgba(56, 189, 248, 0.1);
  border: 1px solid rgba(56, 189, 248, 0.3);
  border-radius: var(--radius-sm);
  color: var(--accent);
}
.brand-title {
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.brand-tag {
  font-size: 0.65rem;
  text-transform: uppercase;
  background: rgba(56, 189, 248, 0.15);
  color: var(--accent);
  padding: 2px 6px;
  border-radius: 2px;
  font-weight: 700;
  margin-left: 0.25rem;
}
.nav-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.nav-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.3rem 0.75rem;
  background: rgba(52, 211, 153, 0.1);
  border: 1px solid rgba(52, 211, 153, 0.3);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--success);
}
.pulse-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--success);
  box-shadow: 0 0 8px var(--success);
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0% { transform: scale(0.95); opacity: 0.8; }
  50% { transform: scale(1.15); opacity: 1; }
  100% { transform: scale(0.95); opacity: 0.8; }
}
.nav-pin-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.3rem 0.6rem;
  background: rgba(56, 189, 248, 0.1);
  border: 1px solid rgba(56, 189, 248, 0.3);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  font-weight: 700;
  font-family: monospace;
  color: var(--accent);
}
.theme-toggle-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: var(--btn-secondary);
  border: 1px solid var(--btn-secondary-border);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 0.95rem;
  color: var(--text-main);
  transition: all 0.15s ease;
  flex-shrink: 0;
}
.theme-toggle-btn:hover {
  border-color: var(--accent);
  background: var(--card-hover);
}
.pin-theme-btn {
  position: absolute;
  top: 1rem;
  right: 1rem;
}

.portal-container {
  flex: 1;
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 1.5rem 1.25rem 3rem 1.25rem;
}

/* Feature Navigation Tabs */
.feature-quickbar {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
  overflow-x: auto;
  padding-bottom: 4px;
}
.quickbar-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.85rem;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 600;
  text-decoration: none;
  white-space: nowrap;
  transition: all 0.15s ease;
}
.quickbar-btn:hover {
  background: var(--card-hover);
  color: var(--text-main);
  border-color: var(--card-border-hover);
}

/* Hero Section */
.hero-header {
  margin-bottom: 1.5rem;
}
.hero-title {
  font-size: 1.5rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  margin-bottom: 0.35rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.hero-subtitle {
  color: var(--text-muted);
  font-size: 0.9rem;
}

/* Section Cards */
.section-card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-md);
  padding: 1.25rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  transition: background 0.2s ease, border-color 0.2s ease;
}
.section-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
}
.section-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background: rgba(56, 189, 248, 0.12);
  border: 1px solid rgba(56, 189, 248, 0.25);
  border-radius: var(--radius-sm);
  color: var(--accent);
}
.section-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--text-main);
}
.section-desc {
  font-size: 0.8rem;
  color: var(--text-muted);
}

/* P1: Reverse Drop Upload Area */
.dropzone {
  border: 2px dashed rgba(56, 189, 248, 0.35);
  border-radius: var(--radius-md);
  padding: 1.75rem 1rem;
  text-align: center;
  background: var(--drop-bg);
  cursor: pointer;
  transition: all 0.2s ease;
}
.dropzone:hover, .dropzone.dragover {
  border-color: var(--accent);
  background: rgba(56, 189, 248, 0.09);
}
.dropzone-icon {
  margin: 0 auto 0.5rem auto;
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--accent);
  background: rgba(56, 189, 248, 0.1);
  border-radius: 50%;
}
.dropzone-prompt {
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--text-main);
  margin-bottom: 0.25rem;
}
.dropzone-sub {
  font-size: 0.75rem;
  color: var(--text-muted);
}
.upload-queue {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}
.upload-item {
  background: var(--input-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  padding: 0.75rem;
}
.upload-item-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.4rem;
}
.upload-item-name {
  font-size: 0.85rem;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 65%;
}
.upload-item-stat {
  font-size: 0.75rem;
  font-family: monospace;
  color: var(--text-muted);
}
.prog-bar-track {
  width: 100%;
  height: 6px;
  background: rgba(128, 128, 128, 0.15);
  border-radius: 3px;
  overflow: hidden;
}
.prog-bar-fill {
  height: 100%;
  width: 0%;
  background: var(--accent);
  transition: width 0.15s ease;
}
.prog-bar-fill.success {
  background: var(--success);
}
.prog-bar-fill.error {
  background: #f43f5e;
}

/* P2: Clipboard Beam Area */
.beam-textarea {
  width: 100%;
  background: var(--input-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  padding: 0.75rem;
  color: var(--text-main);
  font-family: inherit;
  font-size: 0.85rem;
  resize: vertical;
  min-height: 70px;
  margin-bottom: 0.75rem;
  outline: none;
  transition: border-color 0.15s ease;
}
.beam-textarea:focus {
  border-color: var(--accent);
}
.beam-btn-row {
  display: flex;
  gap: 0.6rem;
  flex-wrap: wrap;
}
.pc-clip-display {
  margin-top: 1rem;
  background: var(--input-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  padding: 0.75rem;
}
.pc-clip-display-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.4rem;
  font-size: 0.75rem;
  color: var(--text-muted);
}
.pc-clip-text {
  font-family: monospace;
  font-size: 0.8rem;
  max-height: 120px;
  overflow-y: auto;
  white-space: pre-wrap;
  word-break: break-all;
  color: var(--text-main);
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  padding: 0.55rem 1rem;
  font-size: 0.85rem;
  font-weight: 600;
  border-radius: var(--radius-sm);
  cursor: pointer;
  border: none;
  text-decoration: none;
  transition: all 0.15s ease;
}
.btn-primary {
  background: var(--accent);
  color: var(--btn-primary-text);
}
.btn-primary:hover {
  background: var(--accent-hover);
  box-shadow: 0 0 14px var(--accent-glow);
}
.btn-secondary {
  background: var(--btn-secondary);
  color: var(--text-main);
  border: 1px solid var(--btn-secondary-border);
}
.btn-secondary:hover {
  background: var(--card-hover);
  border-color: var(--card-border-hover);
}
.btn-success {
  background: var(--success);
  color: #ffffff;
}
.btn-success:hover {
  background: var(--success-hover);
}
.btn-sm {
  padding: 0.35rem 0.65rem;
  font-size: 0.75rem;
}

/* Search and Filter Row */
.filter-bar {
  display: flex;
  gap: 0.6rem;
  flex-wrap: wrap;
  margin-bottom: 1.25rem;
  align-items: center;
}
.search-box {
  flex: 1;
  min-width: 200px;
  position: relative;
}
.search-input {
  width: 100%;
  background: var(--input-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  padding: 0.5rem 0.75rem 0.5rem 2.2rem;
  color: var(--text-main);
  font-size: 0.85rem;
  outline: none;
}
.search-input:focus {
  border-color: var(--accent);
}
.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-dim);
  pointer-events: none;
}
.chip-group {
  display: flex;
  gap: 0.4rem;
  overflow-x: auto;
}
.filter-chip {
  padding: 0.35rem 0.7rem;
  font-size: 0.75rem;
  font-weight: 600;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  color: var(--text-muted);
  cursor: pointer;
  white-space: nowrap;
}
.filter-chip:hover, .filter-chip.active {
  color: var(--accent);
  border-color: var(--accent);
  background: rgba(56, 189, 248, 0.1);
}

/* Multi-File Download Grid */
.file-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(290px, 1fr));
  gap: 1rem;
}
.file-card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-md);
  padding: 1rem;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  transition: all 0.15s ease;
}
.file-card:hover {
  border-color: var(--card-border-hover);
  background: var(--card-hover);
  transform: translateY(-1px);
}
.card-top {
  display: flex;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}
.file-icon-wrap {
  width: 42px;
  height: 42px;
  background: rgba(128, 128, 128, 0.08);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.card-info {
  flex: 1;
  min-width: 0;
}
.card-name {
  font-size: 0.9rem;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text-main);
  margin-bottom: 0.2rem;
}
.card-meta-row {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.75rem;
  color: var(--text-muted);
}
.badge {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 2px;
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
}
.card-bottom {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.5rem;
}
.btn-dl {
  flex: 1;
}

/* Multi-file Bundle Banner */
.bundle-banner {
  background: var(--bundle-grad);
  border: 1px solid var(--bundle-border);
  border-radius: var(--radius-md);
  padding: 1.25rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}
.bundle-info h3 {
  font-size: 1.1rem;
  font-weight: 800;
  color: var(--text-main);
}
.bundle-info p {
  font-size: 0.8rem;
  color: var(--text-muted);
}

/* Toast */
.toast-box {
  position: fixed;
  bottom: 1.5rem;
  left: 50%;
  transform: translateX(-50%) translateY(100px);
  background: var(--card-bg);
  color: var(--text-main);
  border: 1px solid var(--card-border-hover);
  border-radius: var(--radius-sm);
  padding: 0.65rem 1.25rem;
  font-size: 0.85rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  z-index: 100;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.25);
  opacity: 0;
  pointer-events: none;
  transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}
.toast-box.show {
  transform: translateX(-50%) translateY(0);
  opacity: 1;
}

/* Lightbox Modal */
.lightbox {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.88);
  backdrop-filter: blur(8px);
  z-index: 99;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}
.lightbox-content {
  max-width: 90vw;
  max-height: 85vh;
  object-fit: contain;
}

/* PIN Lock Screen CSS */
.pin-body {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: var(--bg);
  padding: 1.5rem;
  position: relative;
}
.pin-card {
  max-width: 400px;
  width: 100%;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius-md);
  padding: 2.2rem 1.5rem 1.8rem 1.5rem;
  text-align: center;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
  position: relative;
}
.pin-icon {
  width: 54px;
  height: 54px;
  margin: 0 auto 1rem auto;
  background: rgba(56, 189, 248, 0.12);
  border: 1px solid rgba(56, 189, 248, 0.3);
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--accent);
}
.pin-title {
  font-size: 1.25rem;
  font-weight: 800;
  margin-bottom: 0.35rem;
}
.pin-desc {
  font-size: 0.85rem;
  color: var(--text-muted);
  margin-bottom: 1.5rem;
}
.pin-inputs {
  display: flex;
  justify-content: center;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}
.pin-digit {
  width: 44px;
  height: 54px;
  font-size: 1.5rem;
  font-family: monospace;
  font-weight: 800;
  text-align: center;
  background: var(--input-bg);
  border: 1.5px solid var(--card-border);
  border-radius: var(--radius-sm);
  color: var(--accent);
  outline: none;
  transition: all 0.15s ease;
}
@media (max-width: 400px) {
  .pin-inputs { gap: 0.35rem; }
  .pin-digit { width: 38px; height: 48px; font-size: 1.3rem; }
}
.pin-digit:focus {
  border-color: var(--accent);
  box-shadow: 0 0 10px var(--accent-glow);
}
.pin-error {
  color: #f43f5e;
  font-size: 0.8rem;
  font-weight: 600;
  margin-top: 0.75rem;
  min-height: 1.2rem;
}
.shake {
  animation: shakeAnim 0.35s ease;
}
@keyframes shakeAnim {
  0%, 100% { transform: translateX(0); }
  20%, 60% { transform: translateX(-8px); }
  40%, 80% { transform: translateX(8px); }
}

@media (max-width: 600px) {
  .portal-container { padding: 1rem 0.75rem 3rem 0.75rem; }
  .nav-inner { padding: 0.5rem 0.75rem; gap: 0.4rem; }
  .brand-title { font-size: 0.95rem; }
  .brand-tag { display: none; }
  .nav-pin-badge { font-size: 0.7rem; padding: 0.2rem 0.45rem; }
  .nav-pill { font-size: 0.7rem; padding: 0.2rem 0.45rem; }
  .bundle-banner { flex-direction: column; align-items: stretch; }
  .file-grid { grid-template-columns: 1fr; }
  .dropzone { padding: 1.25rem 0.75rem; }
}
"""
PORTAL_JS = """

// Theme Management (Light / Dark / System mode)
function getEffectiveTheme() {
  var saved = localStorage.getItem('reclip_theme');
  if (saved === 'light' || saved === 'dark') return saved;
  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
    return 'light';
  }
  return 'dark';
}

function updateThemeUI(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  var icons = document.querySelectorAll('.theme-toggle-icon');
  icons.forEach(function(icon) {
    icon.innerText = (theme === 'light') ? '🌙' : '☀️';
  });
}

function toggleTheme() {
  var current = document.documentElement.getAttribute('data-theme') || getEffectiveTheme();
  var next = (current === 'light') ? 'dark' : 'light';
  localStorage.setItem('reclip_theme', next);
  updateThemeUI(next);
  showToast('Switched to ' + (next === 'light' ? 'Light' : 'Dark') + ' theme');
}

if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', function(e) {
    if (!localStorage.getItem('reclip_theme')) {
      updateThemeUI(e.matches ? 'light' : 'dark');
    }
  });
}
updateThemeUI(getEffectiveTheme());

function showToast(msg, type) {
  var t = document.getElementById('toast');
  if (!t) return;
  t.innerText = msg;
  t.className = 'toast-box show';
  setTimeout(function() {
    t.className = 'toast-box';
  }, 2500);
}

function copyText(text, label) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(function() {
      showToast((label || 'Text') + ' copied to clipboard!');
    }).catch(function() {
      fallbackCopy(text, label);
    });
  } else {
    fallbackCopy(text, label);
  }
}

function fallbackCopy(text, label) {
  var ta = document.createElement('textarea');
  ta.value = text;
  document.body.appendChild(ta);
  ta.select();
  try {
    document.execCommand('copy');
    showToast((label || 'Text') + ' copied to clipboard!');
  } catch(e) {
    showToast('Failed to copy');
  }
  document.body.removeChild(ta);
}

// Lightbox
function openLightbox(src, title, size) {
  var lb = document.getElementById('lightbox');
  var img = document.getElementById('lightbox-img');
  if (!lb || !img) return;
  img.src = src;
  lb.style.display = 'flex';
}
function closeLightbox() {
  var lb = document.getElementById('lightbox');
  if (lb) lb.style.display = 'none';
}

// Search and Category Filter
var currentFilter = 'all';
var currentSearch = '';

function onSearchInput(val) {
  currentSearch = (val || '').toLowerCase().trim();
  applyFilters();
}
function filterCategory(cat, btn) {
  currentFilter = cat;
  var chips = document.querySelectorAll('.filter-chip');
  chips.forEach(function(c) { c.classList.remove('active'); });
  if (btn) btn.classList.add('active');
  applyFilters();
}
function applyFilters() {
  var cards = document.querySelectorAll('.file-card');
  cards.forEach(function(card) {
    var cat = card.getAttribute('data-cat') || 'other';
    var name = (card.getAttribute('data-name') || '').toLowerCase();
    var matchCat = (currentFilter === 'all' || cat === currentFilter);
    var matchSearch = (!currentSearch || name.indexOf(currentSearch) !== -1);
    card.style.display = (matchCat && matchSearch) ? 'flex' : 'none';
  });
}

// P1: Reverse Drop File Uploads
var uploadQueue = [];
var isUploading = false;

function initDropzone() {
  var dz = document.getElementById('dropzone');
  if (!dz) return;

  ['dragenter', 'dragover'].forEach(function(evt) {
    dz.addEventListener(evt, function(e) {
      e.preventDefault();
      e.stopPropagation();
      dz.classList.add('dragover');
    });
  });
  ['dragleave', 'drop'].forEach(function(evt) {
    dz.addEventListener(evt, function(e) {
      e.preventDefault();
      e.stopPropagation();
      dz.classList.remove('dragover');
    });
  });
  dz.addEventListener('drop', function(e) {
    if (e.dataTransfer && e.dataTransfer.files) {
      handleFilesSelected(e.dataTransfer.files);
    }
  });
}

function handleFilesSelected(files) {
  if (!files || files.length === 0) return;
  var queueList = document.getElementById('upload-queue');
  if (!queueList) return;

  for (var i = 0; i < files.length; i++) {
    var file = files[i];
    var uid = 'up_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
    uploadQueue.push({ file: file, uid: uid });

    var item = document.createElement('div');
    item.className = 'upload-item';
    item.id = uid;
    item.innerHTML = '<div class="upload-item-header">' +
      '<span class="upload-item-name">' + file.name + '</span>' +
      '<span class="upload-item-stat" id="' + uid + '_stat">Queued</span>' +
      '</div>' +
      '<div class="prog-bar-track">' +
      '<div class="prog-bar-fill" id="' + uid + '_fill"></div>' +
      '</div>';
    queueList.prepend(item);
  }
  processUploadQueue();
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function processUploadQueue() {
  if (isUploading || uploadQueue.length === 0) return;
  isUploading = true;
  var current = uploadQueue.shift();
  var file = current.file;
  var uid = current.uid;

  var stat = document.getElementById(uid + '_stat');
  var fill = document.getElementById(uid + '_fill');

  var xhr = new XMLHttpRequest();
  xhr.open('POST', '/upload', true);
  xhr.setRequestHeader('X-Filename', encodeURIComponent(file.name));
  xhr.setRequestHeader('X-File-Size', file.size);

  var startTime = Date.now();
  xhr.upload.onprogress = function(e) {
    if (e.lengthComputable) {
      var pct = Math.round((e.loaded / e.total) * 100);
      var elapsed = (Date.now() - startTime) / 1000;
      var speed = elapsed > 0 ? (e.loaded / elapsed) : 0;
      var speedStr = formatBytes(speed) + '/s';
      if (fill) fill.style.width = pct + '%';
      if (stat) stat.innerText = pct + '% · ' + speedStr;
    }
  };

  xhr.onload = function() {
    isUploading = false;
    if (xhr.status >= 200 && xhr.status < 300) {
      if (fill) { fill.style.width = '100%'; fill.classList.add('success'); }
      if (stat) { stat.innerText = '✓ Sent (' + formatBytes(file.size) + ')'; stat.style.color = 'var(--success)'; }
      showToast('✓ ' + file.name + ' uploaded to PC!');
    } else {
      if (fill) fill.classList.add('error');
      if (stat) { stat.innerText = '⚠ Error (' + xhr.status + ')'; stat.style.color = '#f43f5e'; }
      showToast('Upload failed: ' + file.name);
    }
    processUploadQueue();
  };

  xhr.onerror = function() {
    isUploading = false;
    if (fill) fill.classList.add('error');
    if (stat) { stat.innerText = '⚠ Network Error'; stat.style.color = '#f43f5e'; }
    showToast('Network error uploading ' + file.name);
    processUploadQueue();
  };

  xhr.send(file);
}

// P2: Clipboard Beam
function beamTextToPC() {
  var ta = document.getElementById('beam-textarea');
  if (!ta) return;
  var text = ta.value;
  if (!text.trim()) {
    showToast('Please enter text to beam');
    return;
  }
  fetch('/api/beam-text', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: text })
  }).then(function(res) {
    return res.json();
  }).then(function(data) {
    if (data.success) {
      showToast('⚡ Text beamed to PC clipboard!');
      ta.value = '';
    } else {
      showToast('⚠ Failed to beam text');
    }
  }).catch(function(err) {
    showToast('⚠ Error: ' + err);
  });
}

function fetchPCClipboard() {
  fetch('/api/beam-text').then(function(res) {
    return res.json();
  }).then(function(data) {
    var box = document.getElementById('pc-clip-display');
    var txt = document.getElementById('pc-clip-text');
    if (box && txt) {
      txt.innerText = data.text || '(empty clipboard)';
      box.style.display = 'block';
      showToast('Fetched PC clipboard');
    }
  }).catch(function(err) {
    showToast('⚠ Failed to fetch PC clipboard');
  });
}

document.addEventListener('DOMContentLoaded', function() {
  initDropzone();
});
"""

PIN_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>ReClip LAN Security &middot; Enter PIN</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <script>
    (function() {
      var p = new URLSearchParams(window.location.search);
      var q = p.get('theme');
      if (q === 'light' || q === 'dark') {
        localStorage.setItem('reclip_theme', q);
        document.documentElement.setAttribute('data-theme', q);
      } else {
        var s = localStorage.getItem('reclip_theme');
        var isLight = (s === 'light') || (!s && window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches);
        document.documentElement.setAttribute('data-theme', isLight ? 'light' : 'dark');
      }
    })();
  </script>
  <style>
""" + PORTAL_CSS + """
  </style>
</head>
<body class="pin-body">
  <div class="pin-card" id="pin-card">
    <button type="button" class="theme-toggle-btn pin-theme-btn" onclick="toggleTheme()" title="Switch Light/Dark Mode"><span class="theme-toggle-icon">☀️</span></button>
    <div class="pin-icon">
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>
        <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
      </svg>
    </div>
    <h1 class="pin-title">Protected Transfer</h1>
    <p class="pin-desc">Enter the 6-digit security PIN displayed in ReClip on your computer screen.</p>
    
    <div class="pin-inputs" id="pin-boxes">
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p0" autofocus>
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p1">
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p2">
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p3">
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p4">
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p5">
    </div>

    <button type="button" class="btn btn-primary" style="width: 100%;" onclick="submitPin()">
      <span>Unlock File Drop</span>
    </button>
    
    <div class="pin-error" id="pin-error"></div>
  </div>

  <script>
    
// Theme Management (Light / Dark / System mode)
function getEffectiveTheme() {
  var saved = localStorage.getItem('reclip_theme');
  if (saved === 'light' || saved === 'dark') return saved;
  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
    return 'light';
  }
  return 'dark';
}

function updateThemeUI(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  var icons = document.querySelectorAll('.theme-toggle-icon');
  icons.forEach(function(icon) {
    icon.innerText = (theme === 'light') ? '🌙' : '☀️';
  });
}

function toggleTheme() {
  var current = document.documentElement.getAttribute('data-theme') || getEffectiveTheme();
  var next = (current === 'light') ? 'dark' : 'light';
  localStorage.setItem('reclip_theme', next);
  updateThemeUI(next);
  if (typeof showToast === 'function') {
    showToast('Switched to ' + (next === 'light' ? 'Light' : 'Dark') + ' theme');
  }
}

if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', function(e) {
    if (!localStorage.getItem('reclip_theme')) {
      updateThemeUI(e.matches ? 'light' : 'dark');
    }
  });
}
updateThemeUI(getEffectiveTheme());

    var digits = [
      document.getElementById('p0'),
      document.getElementById('p1'),
      document.getElementById('p2'),
      document.getElementById('p3'),
      document.getElementById('p4'),
      document.getElementById('p5')
    ];
    var pinLen = digits.length;

    digits.forEach(function(inp, idx) {
      inp.addEventListener('input', function(e) {
        var v = inp.value.replace(/[^0-9]/g, '');
        inp.value = v ? v.slice(-1) : '';
        if (inp.value && idx < pinLen - 1) {
          digits[idx + 1].focus();
        }
        if (idx === pinLen - 1 && inp.value) {
          submitPin();
        }
      });
      inp.addEventListener('keydown', function(e) {
        if (e.key === 'Backspace' && !inp.value && idx > 0) {
          digits[idx - 1].focus();
        } else if (e.key === 'Enter') {
          submitPin();
        }
      });
      inp.addEventListener('paste', function(e) {
        e.preventDefault();
        var pasteData = (e.clipboardData || window.clipboardData).getData('text').trim().replace(/[^0-9]/g, '');
        if (pasteData) {
          for (var i = 0; i < pinLen; i++) {
            digits[i].value = pasteData[i] || '';
          }
          var nextFocus = Math.min(pasteData.length, pinLen - 1);
          digits[nextFocus].focus();
          if (pasteData.length >= pinLen) {
            submitPin();
          }
        }
      });
    });

    function submitPin() {
      var pin = digits.map(function(d) { return d.value; }).join('');
      var errBox = document.getElementById('pin-error');
      var card = document.getElementById('pin-card');
      if (pin.length < pinLen) {
        if (errBox) { errBox.style.color = '#f43f5e'; errBox.innerText = 'Please enter all ' + pinLen + ' digits'; }
        return;
      }
      if (errBox) { errBox.style.color = 'var(--text-muted)'; errBox.innerText = 'Verifying...'; }

      fetch('/api/verify-pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pin })
      }).then(function(res) {
        return res.json().then(function(data) {
          return { status: res.status, data: data };
        });
      }).then(function(result) {
        var data = result.data;
        if (data.success) {
          if (errBox) { errBox.style.color = 'var(--success)'; errBox.innerText = '✓ Verified! Loading...'; }
          setTimeout(function() {
            window.location.reload();
          }, 350);
        } else {
          if (errBox) { errBox.style.color = '#f43f5e'; errBox.innerText = data.error || 'Invalid PIN'; }
          card.classList.add('shake');
          setTimeout(function() { card.classList.remove('shake'); }, 400);
          if (result.status === 429) {
            digits.forEach(function(d) { d.disabled = true; });
          } else {
            digits.forEach(function(d) { d.value = ''; });
            digits[0].focus();
          }
        }
      }).catch(function(err) {
        if (errBox) { errBox.style.color = '#f43f5e'; errBox.innerText = 'Connection error. Try again.'; }
      });
    }
  </script>
</body>
</html>"""

class FileShareHandler(BaseHTTPRequestHandler):
    server_version = "ReClipFileDrop/3.0"

    def log_message(self, format, *args):
        pass

    def is_authenticated(self):
        """Check if request is authorized via query token or session cookie."""
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)

        # 1. Query parameter ?token=...
        token_q = query.get("token", [""])[0]
        if token_q and secrets.compare_digest(token_q, self.server.token):
            return True, True

        # 2. Cookie reclip_auth=...
        cookie_header = self.headers.get("Cookie", "")
        if cookie_header:
            for part in cookie_header.split(";"):
                part = part.strip()
                if part.startswith("reclip_auth="):
                    val = part[len("reclip_auth="):].strip()
                    if secrets.compare_digest(val, self.server.token):
                        return True, False

        # 3. Header Authorization / X-ReClip-Token
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            bearer_tok = auth_header[7:].strip()
            if bearer_tok and secrets.compare_digest(bearer_tok, self.server.token):
                return True, False
        x_token = self.headers.get("X-ReClip-Token", "").strip()
        if x_token and secrets.compare_digest(x_token, self.server.token):
            return True, False

        return False, False

    def do_HEAD(self):
        self.handle_get_or_head(send_body=False)

    def do_GET(self):
        self.handle_get_or_head(send_body=True)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        clean_path = urllib.parse.unquote(parsed.path).strip("/")

        # Route 1: Verify PIN (P4)
        if clean_path in ("api/verify-pin", "verify-pin"):
            self.handle_verify_pin()
            return

        # Check authentication for remaining POST endpoints
        auth, _ = self.is_authenticated()
        if not auth:
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": "Authentication required. Enter PIN."}).encode("utf-8"))
            return

        # Route 2: Two-Way Reverse Drop File Upload (P1)
        if clean_path in ("upload", "api/upload"):
            if not self.server.allow_upload:
                resp = json.dumps({"success": False, "error": "Uploads are disabled on this host."}).encode("utf-8")
                self.send_response(403)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
                return
            self.handle_upload()
            return

        # Route 3: Clipboard Text Beam (P2)
        if clean_path in ("api/beam-text", "beam-text"):
            if not self.server.allow_beam:
                resp = json.dumps({"success": False, "error": "Clipboard beam is disabled on this host."}).encode("utf-8")
                self.send_response(403)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
                return
            self.handle_beam_text_post()
            return

        self.send_error(404, "Endpoint not found")

    def handle_verify_pin(self):
        client_ip = self.client_address[0]
        now = time.time()

        # Enforce rate limiting and lockout state
        with self.server.attempt_lock:
            # Clean expired lockout records (> 30 min old)
            expired = [ip for ip, data in self.server.failed_attempts.items()
                       if now > data.get("locked_until", 0.0) and (now - data.get("last_attempt", 0.0) > 1800)]
            for ip in expired:
                self.server.failed_attempts.pop(ip, None)

            # Global lockout check
            if now < self.server.global_locked_until:
                retry_after = int(self.server.global_locked_until - now) + 1
                resp = json.dumps({
                    "success": False,
                    "error": f"Service temporarily locked due to excessive failed attempts. Please wait {retry_after}s.",
                    "retry_after": retry_after
                }).encode("utf-8")
                self.send_response(429)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.send_header("Retry-After", str(retry_after))
                self.end_headers()
                self.wfile.write(resp)
                return

            client_state = self.server.failed_attempts.get(client_ip, {"count": 0, "locked_until": 0.0, "last_attempt": now})
            if now < client_state.get("locked_until", 0.0):
                retry_after = int(client_state["locked_until"] - now) + 1
                resp = json.dumps({
                    "success": False,
                    "error": f"Too many failed PIN attempts. IP locked out for {retry_after}s.",
                    "retry_after": retry_after
                }).encode("utf-8")
                self.send_response(429)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.send_header("Retry-After", str(retry_after))
                self.end_headers()
                self.wfile.write(resp)
                return

        # Cap request body: at most 1024 bytes
        try:
            content_length = int(self.headers.get("Content-Length", 0))
        except (ValueError, TypeError):
            content_length = 0

        if content_length > 1024:
            self.send_error(413, "Request body too large for PIN verification")
            return

        # Read body with read deadline
        try:
            self.connection.settimeout(5.0)
            post_data = self.rfile.read(content_length) if content_length > 0 else b"{}"
        except Exception:
            post_data = b"{}"
        finally:
            try:
                self.connection.settimeout(None)
            except Exception:
                pass

        try:
            req = json.loads(post_data.decode("utf-8"))
            pin_attempt = str(req.get("pin", "")).strip()
        except Exception:
            pin_attempt = ""

        # Enforce artificial timing delay (0.5s) to throttle burst brute-force attacks
        time.sleep(0.5)

        # Constant-time comparison
        is_valid = secrets.compare_digest(pin_attempt, self.server.pin)

        with self.server.attempt_lock:
            if is_valid:
                # Reset failure counts for this client
                if client_ip in self.server.failed_attempts:
                    self.server.failed_attempts[client_ip]["count"] = 0
                    self.server.failed_attempts[client_ip]["locked_until"] = 0.0

                emit_event({
                    "event": "pin_verified",
                    "client": client_ip
                })
                resp = json.dumps({"success": True, "token": self.server.token}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax; HttpOnly")
                self.end_headers()
                self.wfile.write(resp)
            else:
                # Increment failed attempts
                if client_ip not in self.server.failed_attempts:
                    self.server.failed_attempts[client_ip] = {"count": 0, "locked_until": 0.0, "last_attempt": now}
                self.server.failed_attempts[client_ip]["count"] += 1
                self.server.failed_attempts[client_ip]["last_attempt"] = now
                self.server.global_failed_attempts += 1

                client_count = self.server.failed_attempts[client_ip]["count"]
                if client_count >= 5:
                    # 15 minutes lockout (900s)
                    self.server.failed_attempts[client_ip]["locked_until"] = now + 900.0

                if self.server.global_failed_attempts >= 20:
                    # 15 minutes global lockout
                    self.server.global_locked_until = now + 900.0

                emit_event({
                    "event": "pin_failed",
                    "client": client_ip,
                    "attempt": pin_attempt[:2] + "****" if len(pin_attempt) > 2 else "******"
                })

                if self.server.failed_attempts[client_ip]["locked_until"] > now:
                    retry_after = 900
                    resp = json.dumps({
                        "success": False,
                        "error": "Too many failed PIN attempts. IP locked out for 15 minutes.",
                        "retry_after": retry_after
                    }).encode("utf-8")
                    self.send_response(429)
                    self.send_header("Retry-After", str(retry_after))
                else:
                    remaining = max(0, 5 - client_count)
                    resp = json.dumps({
                        "success": False,
                        "error": f"Invalid PIN. {remaining} attempt{'s' if remaining != 1 else ''} remaining before lockout."
                    }).encode("utf-8")
                    self.send_response(401)

                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)

    def handle_beam_text_post(self):
        client_ip = self.client_address[0]
        if not self.server.allow_beam:
            self.send_error(403, "Clipboard beam is disabled on this host")
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0))
        except (ValueError, TypeError):
            content_length = 0

        # Cap text beam payload to 128 KB
        if content_length > 131072:
            self.send_error(413, "Clipboard beam payload too large (max 128KB)")
            return

        try:
            self.connection.settimeout(5.0)
            post_data = self.rfile.read(content_length) if content_length > 0 else b"{}"
        except Exception:
            post_data = b"{}"
        finally:
            try:
                self.connection.settimeout(None)
            except Exception:
                pass

        try:
            req = json.loads(post_data.decode("utf-8"))
            text = str(req.get("text", "")).strip()
        except Exception:
            text = ""

        if text:
            set_desktop_clipboard(text)
            self.server.beam_text = text
            preview = (text[:60] + "...") if len(text) > 60 else text
            emit_event({
                "event": "text_beamed",
                "client": client_ip,
                "text": text,
                "preview": preview,
                "length": len(text)
            })
            send_desktop_notification("ReClip Beam", f"Received snippet from phone:\n{preview}", "edit-paste")
            resp = json.dumps({"success": True}).encode("utf-8")
            self.send_response(200)
        else:
            resp = json.dumps({"success": False, "error": "Empty text"}).encode("utf-8")
            self.send_response(400)

        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def handle_upload(self):
        """Streaming file upload from phone to ~/Downloads/ReClip-Drop with quota, disk space verification, read deadlines, and atomic partial-file cleanup."""
        client_ip = self.client_address[0]
        if not self.server.allow_upload:
            resp = json.dumps({"success": False, "error": "Uploads are disabled on this host."}).encode("utf-8")
            self.send_response(403)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        # 1. Validate Content-Length header
        try:
            content_length = int(self.headers.get("Content-Length", 0))
        except (ValueError, TypeError):
            content_length = -1

        if content_length <= 0:
            resp = json.dumps({"success": False, "error": "Missing or invalid Content-Length header"}).encode("utf-8")
            self.send_response(411)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        # 2. Check per-file upload size cap
        if content_length > self.server.max_upload_size:
            resp = json.dumps({
                "success": False,
                "error": f"Upload rejected: File size ({format_size(content_length)}) exceeds maximum allowed limit ({format_size(self.server.max_upload_size)})."
            }).encode("utf-8")
            self.send_response(413)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        # 3. Check session upload quota
        if (self.server.session_uploaded_bytes + content_length) > self.server.max_session_upload_quota:
            resp = json.dumps({
                "success": False,
                "error": f"Upload rejected: Session quota of {format_size(self.server.max_session_upload_quota)} exceeded."
            }).encode("utf-8")
            self.send_response(413)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        # 4. Check available host disk space before creating any file on disk
        try:
            disk_stat = shutil.disk_usage(self.server.save_dir)
            # Require space for the file plus a 256MB safety margin for the operating system
            min_required = content_length + (256 * 1024 * 1024)
            if disk_stat.free < min_required:
                resp = json.dumps({
                    "success": False,
                    "error": f"Insufficient disk space on host (Free: {format_size(disk_stat.free)}, Required: {format_size(min_required)})."
                }).encode("utf-8")
                self.send_response(507)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
                return
        except Exception:
            pass

        # 5. Sanitize filename and prevent collision
        raw_name = self.headers.get("X-Filename", "")
        if raw_name:
            filename = urllib.parse.unquote(raw_name)
        else:
            filename = f"reclip_drop_{int(time.time())}.bin"

        filename = os.path.basename(filename).replace("/", "_").replace("\\", "_").strip()
        filename = filename.lstrip(".")
        if not filename:
            filename = f"reclip_drop_{int(time.time())}.bin"

        base, ext = os.path.splitext(filename)
        dest_path = os.path.join(self.server.save_dir, filename)
        counter = 1
        while os.path.exists(dest_path):
            dest_path = os.path.join(self.server.save_dir, f"{base} ({counter}){ext}")
            counter += 1

        final_filename = os.path.basename(dest_path)

        # Temporary partial upload path (.filename.token.part)
        part_filename = f".{final_filename}.{secrets.token_hex(4)}.part"
        part_path = os.path.join(self.server.save_dir, part_filename)

        emit_event({
            "event": "upload_started",
            "client": client_ip,
            "file_name": final_filename,
            "size": content_length
        })

        bytes_received = 0
        chunk_size = 64 * 1024
        start_time = time.time()
        last_emit = start_time
        # Max overall transfer deadline: at least 60s, or 10KB/s plus 60s buffer, capped at 1800s
        max_duration = min(1800.0, max(60.0, (content_length / 10240) + 60.0))
        upload_succeeded = False

        try:
            # Set socket read deadline (15s per chunk) to eliminate indefinitely hung threads
            self.connection.settimeout(15.0)

            with open(part_path, "wb") as out_f:
                remaining = content_length
                while remaining > 0:
                    if time.time() - start_time > max_duration:
                        raise TimeoutError(f"Upload exceeded maximum deadline of {int(max_duration)}s")

                    to_read = min(remaining, chunk_size)
                    chunk = self.rfile.read(to_read)
                    if not chunk:
                        raise ConnectionResetError(f"Premature end of stream: received {bytes_received}/{content_length} bytes")

                    out_f.write(chunk)
                    bytes_received += len(chunk)
                    remaining -= len(chunk)

                    now = time.time()
                    if now - last_emit >= 0.25:
                        elapsed = now - start_time
                        speed = bytes_received / elapsed if elapsed > 0 else 0
                        eta = (content_length - bytes_received) / speed if speed > 0 else 0
                        pct = int((bytes_received / content_length) * 100) if content_length > 0 else 0
                        emit_event({
                            "event": "upload_progress",
                            "client": client_ip,
                            "file_name": final_filename,
                            "received": bytes_received,
                            "total": content_length,
                            "percent": pct,
                            "speed": format_speed(speed),
                            "eta": format_eta(eta)
                        })
                        last_emit = now

            # Verify integrity
            if bytes_received != content_length:
                raise IOError(f"Incomplete upload: expected {content_length} bytes, received {bytes_received} bytes")

            # Atomic rename from .part to final destination
            os.replace(part_path, dest_path)
            upload_succeeded = True
            self.server.session_uploaded_bytes += bytes_received

            emit_event({
                "event": "upload_completed",
                "client": client_ip,
                "file_name": final_filename,
                "saved_path": dest_path,
                "size": bytes_received,
                "size_str": format_size(bytes_received)
            })

            send_desktop_notification(
                "ReClip File Drop",
                f"Received {final_filename} ({format_size(bytes_received)})\nSaved to ReClip-Drop",
                "document-save"
            )

            resp = json.dumps({
                "success": True,
                "filename": final_filename,
                "size": bytes_received,
                "size_str": format_size(bytes_received),
                "path": dest_path
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        except (TimeoutError, socket.timeout) as e:
            emit_event({"event": "upload_error", "client": client_ip, "message": f"Timeout: {str(e)}"})
            resp = json.dumps({"success": False, "error": f"Upload timed out: {str(e)}"}).encode("utf-8")
            try:
                self.send_response(408)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception:
                pass
        except Exception as e:
            emit_event({"event": "upload_error", "client": client_ip, "message": str(e)})
            resp = json.dumps({"success": False, "error": f"Upload failed: {str(e)}"}).encode("utf-8")
            try:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception:
                pass
        finally:
            try:
                self.connection.settimeout(None)
            except Exception:
                pass
            # Enforce deletion of partial files on EVERY incomplete or error path
            if not upload_succeeded and os.path.exists(part_path):
                try:
                    os.unlink(part_path)
                except Exception:
                    pass

    def handle_get_or_head(self, send_body=True):
        parsed = urllib.parse.urlparse(self.path)
        clean_path = urllib.parse.unquote(parsed.path).strip("/")
        query = urllib.parse.parse_qs(parsed.query)

        # 1. Favicon (no auth required)
        if clean_path in ("favicon.ico", "favicon.svg"):
            data = FAVICON_SVG.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "image/svg+xml")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.send_header("Connection", "close")
            self.end_headers()
            if send_body:
                self.wfile.write(data)
            return

        # 2. Authentication Check (P4)
        auth, need_cookie = self.is_authenticated()
        if not auth:
            # Show PIN lock page
            data = PIN_PAGE_HTML.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            if send_body:
                self.wfile.write(data)
            return

        # 3. Clipboard Beam GET (P2)
        if clean_path in ("api/beam-text", "beam-text"):
            if not self.server.allow_beam:
                self.send_error(403, "Clipboard beam is disabled on this host")
                return
            text = get_desktop_clipboard() or self.server.beam_text
            resp = json.dumps({"success": True, "text": text}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            if need_cookie:
                self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax")
            self.end_headers()
            if send_body:
                self.wfile.write(resp)
            return

        # 4. Status API
        if clean_path in ("api/status", "status.json"):
            status_data = {
                "status": "online",
                "ip": self.server.lan_ip,
                "count": len(self.server.files_meta),
                "total_size": sum(item["size"] for item in self.server.files_meta),
                "files": self.server.files_meta
            }
            body = json.dumps(status_data, indent=2).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            if need_cookie:
                self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax")
            self.end_headers()
            if send_body:
                self.wfile.write(body)
            return

        # 5. Root portal "/" or "/index.html"
        if not clean_path or clean_path == "index.html":
            self.send_portal_page(send_body=send_body, need_cookie=need_cookie)
            return

        # 6. ZIP bundle requested
        if clean_path in ("bundle", "bundle/ReClip-Files.zip", "ReClip-Files.zip", "bundle.zip", "__all__.zip"):
            self.send_zip_bundle(send_body=send_body)
            return

        # 7. Forced Download route "/download/<file_name>"
        if clean_path.startswith("download/"):
            target_name = clean_path[len("download/"):].strip("/")
            if target_name in self.server.files_map:
                item_path = self.server.files_map[target_name]
                if os.path.isdir(item_path):
                    self.send_folder_zip(item_path, target_name, send_body=send_body)
                else:
                    self.send_file(item_path, target_name, force_download=True, send_body=send_body)
                return

        # 8. Inline Preview route "/preview/<file_name>"
        for prefix in ("preview/", "view/", "raw/"):
            if clean_path.startswith(prefix):
                target_name = clean_path[len(prefix):].strip("/")
                if target_name in self.server.files_map:
                    item_path = self.server.files_map[target_name]
                    if not os.path.isdir(item_path):
                        self.send_file(item_path, target_name, force_download=False, send_body=send_body)
                        return

        # 9. Direct file or folder name "/<file_name>"
        if clean_path in self.server.files_map:
            item_path = self.server.files_map[clean_path]
            if os.path.isdir(item_path):
                self.send_folder_zip(item_path, clean_path, send_body=send_body)
            else:
                force_dl = not ("view" in query or "preview" in query or "raw" in query)
                self.send_file(item_path, clean_path, force_download=force_dl, send_body=send_body)
            return

        # 10. 404 Not Found
        self.send_404_page(clean_path, send_body=send_body)

    def send_folder_zip(self, folder_path, folder_name, send_body=True):
        """Bundle a folder recursively into a ZIP archive and stream to client."""
        client_ip = self.client_address[0]
        temp_zip = self.server.folder_zip_cache.get(folder_path)
        if not temp_zip or not os.path.exists(temp_zip):
            emit_event({"event": "zipping", "client": client_ip, "folder": folder_name})
            tf = tempfile.NamedTemporaryFile(delete=False, suffix=f"_{folder_name}.zip")
            temp_zip = tf.name
            tf.close()
            with zipfile.ZipFile(temp_zip, "w", zipfile.ZIP_DEFLATED) as zf:
                parent_dir = os.path.dirname(os.path.abspath(folder_path))
                for root_dir, _, filenames in os.walk(folder_path):
                    for fn in filenames:
                        fp = os.path.join(root_dir, fn)
                        rel_path = os.path.relpath(fp, parent_dir)
                        try:
                            zf.write(fp, arcname=rel_path)
                        except Exception:
                            pass
            self.server.folder_zip_cache[folder_path] = temp_zip

        self.send_file(temp_zip, f"{folder_name}.zip", force_download=True, send_body=send_body, is_bundle=True)

    def send_zip_bundle(self, send_body=True):
        """Create or reuse single-file ZIP archive containing all shared files and folders."""
        client_ip = self.client_address[0]
        if not self.server.zip_cache_path or not os.path.exists(self.server.zip_cache_path):
            emit_event({"event": "zipping", "client": client_ip, "count": len(self.server.files_meta)})
            tf = tempfile.NamedTemporaryFile(delete=False, suffix="_ReClip-Files.zip")
            self.server.zip_cache_path = tf.name
            tf.close()

            with zipfile.ZipFile(self.server.zip_cache_path, "w", zipfile.ZIP_DEFLATED) as zf:
                for item in self.server.files_meta:
                    ipath = item["path"]
                    if item.get("is_dir"):
                        parent_dir = os.path.dirname(os.path.abspath(ipath))
                        for root_dir, _, filenames in os.walk(ipath):
                            for fn in filenames:
                                fp = os.path.join(root_dir, fn)
                                rel_path = os.path.relpath(fp, parent_dir)
                                try:
                                    zf.write(fp, arcname=rel_path)
                                except Exception:
                                    pass
                    else:
                        if os.path.exists(ipath):
                            zf.write(ipath, arcname=item["name"])

        self.send_file(self.server.zip_cache_path, "ReClip-Files.zip", force_download=True, send_body=send_body, is_bundle=True)

    def send_file(self, file_path, download_name, force_download=True, send_body=True, is_bundle=False):
        client_ip = self.client_address[0]
        if not os.path.exists(file_path):
            self.send_error(404, "File not found")
            return

        file_size = os.path.getsize(file_path)
        mime_type, _ = mimetypes.guess_type(download_name)
        if not mime_type:
            mime_type = "application/zip" if download_name.endswith(".zip") else "application/octet-stream"

        emit_event({
            "event": "connecting",
            "client": client_ip,
            "path": self.path,
            "file_name": download_name,
            "size": file_size,
            "size_str": format_size(file_size),
            "is_bundle": is_bundle,
            "action": "download" if force_download else "preview"
        })

        # RFC 7233 Range header
        range_header = self.headers.get("Range")
        start = 0
        end = file_size - 1
        status_code = 200

        if range_header and range_header.startswith("bytes="):
            try:
                ranges = range_header[6:].split("-")
                if ranges[0]:
                    start = int(ranges[0])
                if len(ranges) > 1 and ranges[1]:
                    end = int(ranges[1])
                status_code = 206
            except Exception:
                start = 0
                end = file_size - 1
                status_code = 200

        start = max(0, min(start, file_size - 1))
        end = max(start, min(end, file_size - 1))
        content_length = (end - start) + 1

        try:
            self.send_response(status_code)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(content_length))
            encoded_name = urllib.parse.quote(download_name)
            disposition = "attachment" if force_download else "inline"
            self.send_header("Content-Disposition", f'{disposition}; filename="{download_name}"; filename*=UTF-8\'\'{encoded_name}')
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Connection", "close")
            self.send_header("Access-Control-Allow-Origin", "*")
            if status_code == 206:
                self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
            self.end_headers()

            if not send_body:
                return

            bytes_sent = 0
            chunk_size = 128 * 1024
            start_time = time.time()
            last_emit = start_time

            with open(file_path, "rb") as f:
                f.seek(start)
                remaining = content_length
                while remaining > 0:
                    to_read = min(remaining, chunk_size)
                    chunk = f.read(to_read)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    bytes_sent += len(chunk)
                    remaining -= len(chunk)

                    now = time.time()
                    if now - last_emit >= 0.25:
                        elapsed = now - start_time
                        speed = bytes_sent / elapsed if elapsed > 0 else 0
                        eta = (content_length - bytes_sent) / speed if speed > 0 else 0
                        pct = int((bytes_sent / content_length) * 100) if content_length > 0 else 0
                        emit_event({
                            "event": "download_progress",
                            "client": client_ip,
                            "file_name": download_name,
                            "sent": bytes_sent,
                            "total": content_length,
                            "percent": pct,
                            "speed": format_speed(speed),
                            "eta": format_eta(eta)
                        })
                        last_emit = now

            if end == file_size - 1 and bytes_sent == content_length:
                self.server.download_count += 1
                emit_event({
                    "event": "completed",
                    "client": client_ip,
                    "bytes_sent": bytes_sent,
                    "total_bytes": file_size,
                    "file_name": download_name,
                    "size_str": format_size(file_size),
                    "is_bundle": is_bundle,
                    "action": "download" if force_download else "preview"
                })
                if self.server.single_shot and force_download:
                    if len(self.server.files_meta) == 1 or is_bundle:
                        self.server.download_completed = True
                        self.server.completion_time = time.time()

        except (BrokenPipeError, ConnectionResetError):
            emit_event({"event": "client_disconnected", "client": client_ip})
        except Exception as e:
            emit_event({"event": "error", "message": str(e)})

    def send_404_page(self, clean_path, send_body=True):
        body = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>404 Not Found</title>
<style>{PORTAL_CSS}</style></head>
<body class="pin-body">
<div class="pin-card">
  <h2 class="pin-title">404 &middot; Not Found</h2>
  <p class="pin-desc">The requested resource "{html.escape(clean_path)}" was not found on this ReClip server.</p>
  <a href="/" class="btn btn-primary">Return to ReClip Drop</a>
</div></body></html>"""
        data = body.encode("utf-8")
        self.send_response(404)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if send_body:
            self.wfile.write(data)

    def send_portal_page(self, send_body=True, need_cookie=False):
        """Render the complete Omarchy Brutalist Web Portal for P1-P5 features."""
        count = len(self.server.files_meta)
        total_size = sum(item["size"] for item in self.server.files_meta)
        total_size_str = format_size(total_size)
        is_single = (count == 1)

        client_ip = self.client_address[0]
        emit_event({
            "event": "client_visiting",
            "client": client_ip,
            "count": count
        })

        categories_present = set()
        cards_html = []
        for item in self.server.files_meta:
            name = item["name"]
            enc_name = urllib.parse.quote(name)
            size_str = item["size_str"]
            is_dir = item.get("is_dir", False)
            cat = get_file_category(name, is_dir=is_dir)
            categories_present.add(cat)
            svg_icon = get_svg_icon(cat, size=24)
            cat_label, badge_color, _ = get_category_badge_info(cat)

            if is_dir:
                file_count = item.get("file_count", 0)
                meta_label = f"{file_count} item{'s' if file_count != 1 else ''} &middot; {size_str}"
                preview_btn = ""
                dl_action = f"/download/{enc_name}"
                dl_text = "Download Folder (ZIP)"
            else:
                meta_label = size_str
                preview_btn = f'''<a href="/preview/{enc_name}" target="_blank" class="btn btn-secondary btn-sm" title="Open Preview">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
                </a>'''
                dl_action = f"/download/{enc_name}"
                dl_text = "Download"

            card = f'''
            <div class="file-card" data-cat="{cat}" data-name="{html.escape(name)}">
              <div class="card-top">
                <div class="file-icon-wrap">{svg_icon}</div>
                <div class="card-info">
                  <div class="card-name" title="{html.escape(name)}">{html.escape(name)}</div>
                  <div class="card-meta-row">
                    <span class="badge" style="background:{badge_color}22; color:{badge_color}; border:1px solid {badge_color}44;">{cat_label}</span>
                    <span>{meta_label}</span>
                  </div>
                </div>
              </div>
              <div class="card-bottom">
                <a href="{dl_action}" class="btn btn-primary btn-sm btn-dl" download>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                  <span>{dl_text}</span>
                </a>
                {preview_btn}
              </div>
            </div>
            '''
            cards_html.append(card)

        # Chips
        chip_order = ['folder', 'image', 'video', 'audio', 'archive', 'document', 'code', 'text', 'other']
        chips_html = ['<button type="button" class="filter-chip active" onclick="filterCategory(\'all\', this)">All</button>']
        for c in chip_order:
            if c in categories_present:
                lbl, _, _ = get_category_badge_info(c)
                chips_html.append(f'<button type="button" class="filter-chip" onclick="filterCategory(\'{c}\', this)">{lbl}</button>')

        # Bundle Banner
        bundle_banner_html = ""
        if count > 1 or any(item.get("is_dir") for item in self.server.files_meta):
            bundle_banner_html = f'''
            <div class="bundle-banner">
              <div class="bundle-info">
                <h3>󰉋 Download Everything ({total_size_str})</h3>
                <p>One-tap download of all {count} files and folders bundled into an on-the-fly ZIP.</p>
              </div>
              <a href="/bundle" class="btn btn-primary" download="ReClip-Files.zip">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                <span>Download All as ZIP</span>
              </a>
            </div>
            '''

        page_title = f"ReClip Drop &middot; {self.server.files_meta[0]['name']}" if is_single else f"ReClip Drop &middot; {count} files"

        quickbar_items = []
        if self.server.allow_upload:
            quickbar_items.append("""      <a href="#reverse-drop" class="quickbar-btn">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
        <span>Send to PC</span>
      </a>""")
        if self.server.allow_beam:
            quickbar_items.append("""      <a href="#clipboard-beam" class="quickbar-btn">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>
        <span>Clipboard Beam</span>
      </a>""")
        quickbar_items.append(f"""      <a href="#files-section" class="quickbar-btn">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/></svg>
        <span>Files ({count})</span>
      </a>""")
        quickbar_html = "\n".join(quickbar_items)

        reverse_drop_section_html = ""
        if self.server.allow_upload:
            reverse_drop_section_html = """    <!-- P1: Reverse Drop Section -->
    <section class="section-card" id="reverse-drop">
      <div class="section-header">
        <div class="section-icon-box">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Reverse Drop &middot; Send to PC</h2>
          <p class="section-desc">Drop or select files from your phone to send directly to <code>~/Downloads/ReClip-Drop</code> on PC</p>
        </div>
      </div>

      <div class="dropzone" id="dropzone" onclick="document.getElementById('file-input').click()">
        <input type="file" id="file-input" multiple style="display:none" onchange="handleFilesSelected(this.files)">
        <div class="dropzone-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
          </svg>
        </div>
        <div class="dropzone-prompt">Tap to choose photos, videos, or files</div>
        <div class="dropzone-sub">Files transfer locally at maximum Wi-Fi speed &middot; Zero cloud storage</div>
      </div>

      <div class="upload-queue" id="upload-queue"></div>
    </section>"""

        clipboard_beam_section_html = ""
        if self.server.allow_beam:
            clipboard_beam_section_html = """    <!-- P2: Clipboard Beam Section -->
    <section class="section-card" id="clipboard-beam">
      <div class="section-header">
        <div class="section-icon-box">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Quick Clipboard Beam</h2>
          <p class="section-desc">Beam notes, URLs, or text snippets between your phone and computer in real time</p>
        </div>
      </div>

      <textarea class="beam-textarea" id="beam-textarea" placeholder="Paste a link, note, or code snippet to beam to your PC clipboard..."></textarea>
      
      <div class="beam-btn-row">
        <button type="button" class="btn btn-primary" onclick="beamTextToPC()">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 7-7 7 7"/><path d="M12 19V5"/></svg>
          <span>Beam to PC Clipboard</span>
        </button>
        <button type="button" class="btn btn-secondary" onclick="fetchPCClipboard()">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect width="8" height="4" x="8" y="2" rx="1" ry="1"/></svg>
          <span>Fetch PC Clipboard</span>
        </button>
      </div>

      <div class="pc-clip-display" id="pc-clip-display" style="display:none;">
        <div class="pc-clip-display-header">
          <span>Desktop Clipboard Content</span>
          <button type="button" class="btn btn-secondary btn-sm" onclick="copyText(document.getElementById(\'pc-clip-text\').innerText, \'PC Clipboard\')">Copy</button>
        </div>
        <div class="pc-clip-text" id="pc-clip-text"></div>
      </div>
    </section>"""

        html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>{html.escape(page_title)}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <script>
    (function() {{
      var p = new URLSearchParams(window.location.search);
      var q = p.get('theme');
      if (q === 'light' || q === 'dark') {{
        localStorage.setItem('reclip_theme', q);
        document.documentElement.setAttribute('data-theme', q);
      }} else {{
        var s = localStorage.getItem('reclip_theme');
        var isLight = (s === 'light') || (!s && window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches);
        document.documentElement.setAttribute('data-theme', isLight ? 'light' : 'dark');
      }}
    }})();
  </script>
  <style>
{PORTAL_CSS}
  </style>
</head>
<body>

  <nav class="top-navbar">
    <div class="nav-inner">
      <a href="/" class="nav-brand">
        <div class="brand-logo-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M16 6v14m-5-5 5 5 5-5M8 24h16"/>
          </svg>
        </div>
        <div class="brand-title">ReClip <span class="brand-tag">Wi-Fi Drop</span></div>
      </a>
      <div class="nav-status">
        <span class="nav-pin-badge" title="LAN Quick PIN">🔒 PIN: {self.server.pin}</span>
        <span class="nav-pill">
          <span class="pulse-dot"></span>
          <span>{self.server.lan_ip}</span>
        </span>
        <button type="button" class="theme-toggle-btn" onclick="toggleTheme()" title="Toggle Light / Dark Mode">
          <span class="theme-toggle-icon">☀️</span>
        </button>
      </div>
    </div>
  </nav>

  <main class="portal-container">

    <!-- Quick Navigation Bar -->
    <div class="feature-quickbar">
{quickbar_html}
    </div>

{reverse_drop_section_html}

{clipboard_beam_section_html}

    <!-- Download Files Section -->
    <section id="files-section">
      <div class="hero-header">
        <h1 class="hero-title">
          <span>Files Shared from PC</span>
          <span class="badge" style="background:rgba(56,189,248,0.15); color:var(--accent);">{count} Item{'s' if count != 1 else ''} &middot; {total_size_str}</span>
        </h1>
        <p class="hero-subtitle">High-speed peer-to-peer download straight from your Linux workstation over local Wi-Fi.</p>
      </div>

      {bundle_banner_html}

      <div class="filter-bar">
        <div class="search-box">
          <span class="search-icon">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
          </span>
          <input type="text" class="search-input" placeholder="Filter files..." oninput="onSearchInput(this.value)">
        </div>
        <div class="chip-group">
          {''.join(chips_html)}
        </div>
      </div>

      <div class="file-grid" id="file-grid">
        {''.join(cards_html)}
      </div>
    </section>

  </main>

  <!-- Lightbox Modal -->
  <div class="lightbox" id="lightbox" style="display:none;" onclick="closeLightbox()">
    <img src="" alt="Preview" class="lightbox-content" id="lightbox-img">
  </div>

  <!-- Toast Notification Box -->
  <div class="toast-box" id="toast"></div>

  <script>
{PORTAL_JS}
  </script>
</body>
</html>'''

        data = html_content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        if need_cookie:
            self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax")
        self.send_header("Connection", "close")
        self.end_headers()
        if send_body:
            self.wfile.write(data)

def start_server_on_ports(ports_to_try, handler_class, files_meta, lan_ip, single_shot=False, token=None, pin=None, save_dir=None, allow_upload=True, allow_beam=True, max_upload_size=1024*1024*1024, max_session_quota=5*1024*1024*1024):
    """Attempt binding to ports in sequence until successful."""
    for port in ports_to_try:
        try:
            server = ThreadedFileShareServer(
                ('0.0.0.0', port),
                handler_class,
                files_meta,
                lan_ip,
                single_shot=single_shot,
                token=token,
                pin=pin,
                save_dir=save_dir,
                allow_upload=allow_upload,
                allow_beam=allow_beam,
                max_upload_size=max_upload_size,
                max_session_quota=max_session_quota
            )
            actual_port = server.server_address[1]
            return server, actual_port
        except OSError:
            continue
    raise RuntimeError("Could not bind to any requested port")

def main():
    parser = argparse.ArgumentParser(description="ReClip Wi-Fi File Drop Micro Server")
    parser.add_argument("files", nargs="+", help="File(s) or folder(s) to serve")
    parser.add_argument("--port", type=int, default=0, help="Port to bind (default: try 53317, 53318, etc.)")
    parser.add_argument("--ip", type=str, default=None, help="Specific IP to advertise in QR")
    parser.add_argument("--no-single-shot", action="store_true", help="Keep server running after download")
    parser.add_argument("--no-upload", action="store_true", help="Disable reverse drop file uploads from peers")
    parser.add_argument("--no-beam", action="store_true", help="Disable peer clipboard beaming")
    parser.add_argument("--max-upload-size", type=int, default=1024*1024*1024, help="Max single file upload size in bytes (default: 1GB)")
    parser.add_argument("--max-session-quota", type=int, default=5*1024*1024*1024, help="Max total session uploads in bytes (default: 5GB)")
    parser.add_argument("--timeout", type=int, default=1800, help="Server timeout in seconds (default: 1800s)")
    parser.add_argument("--token", type=str, default=None, help="Security session token")
    parser.add_argument("--pin", type=str, default=None, help="6-digit quick PIN")
    parser.add_argument("--save-dir", type=str, default=None, help="Directory to save reverse drop uploads")

    args = parser.parse_args()

    # Scan paths (support files and recursive directories - P5)
    files_meta = []
    for idx, path_arg in enumerate(args.files):
        abs_p = os.path.abspath(path_arg)
        if not os.path.exists(abs_p):
            continue

        if os.path.isdir(abs_p):
            file_count = 0
            dir_size = 0
            for root_dir, _, filenames in os.walk(abs_p):
                for fn in filenames:
                    fp = os.path.join(root_dir, fn)
                    try:
                        dir_size += os.path.getsize(fp)
                        file_count += 1
                    except OSError:
                        pass
            bname = os.path.basename(abs_p.rstrip("/"))
            files_meta.append({
                "index": idx,
                "name": bname,
                "path": abs_p,
                "size": dir_size,
                "size_str": format_size(dir_size),
                "is_dir": True,
                "file_count": file_count,
                "category": "folder"
            })
        elif os.path.isfile(abs_p):
            sz = os.path.getsize(abs_p)
            bname = os.path.basename(abs_p)
            files_meta.append({
                "index": idx,
                "name": bname,
                "path": abs_p,
                "size": sz,
                "size_str": format_size(sz),
                "is_dir": False,
                "category": get_file_category(bname)
            })

    if not files_meta:
        emit_event({"event": "error", "message": "No valid files or directories provided"})
        sys.exit(1)

    lan_ip = args.ip or get_lan_ip()
    single_shot = not args.no_single_shot
    allow_upload = not args.no_upload
    allow_beam = not args.no_beam

    if args.port > 0:
        ports_to_try = [args.port]
    else:
        ports_to_try = PREFERRED_PORTS

    try:
        httpd, port = start_server_on_ports(
            ports_to_try,
            FileShareHandler,
            files_meta,
            lan_ip,
            single_shot=single_shot,
            token=args.token,
            pin=args.pin,
            save_dir=args.save_dir,
            allow_upload=allow_upload,
            allow_beam=allow_beam,
            max_upload_size=args.max_upload_size,
            max_session_quota=args.max_session_quota
        )
    except Exception as e:
        emit_event({"event": "error", "message": f"Failed to bind server: {str(e)}"})
        sys.exit(1)

    total_sz = sum(f["size"] for f in files_meta)
    
    # URL includes ?token=... for 1-tap seamless QR authentication (P4)
    auth_url = f"http://{lan_ip}:{port}/?token={httpd.token}"

    emit_event({
        "event": "started",
        "ip": lan_ip,
        "port": port,
        "url": auth_url,
        "token": httpd.token,
        "pin": httpd.pin,
        "save_dir": httpd.save_dir,
        "allow_upload": allow_upload,
        "allow_beam": allow_beam,
        "max_upload_size": args.max_upload_size,
        "count": len(files_meta),
        "total_size": total_sz,
        "total_size_str": format_size(total_sz),
        "single_shot": single_shot,
        "files": files_meta
    })

    start_time = time.time()
    try:
        while not httpd.should_stop:
            httpd.handle_request()
            if time.time() - start_time > args.timeout:
                emit_event({"event": "timeout", "message": f"Server timed out after {args.timeout}s"})
                break
            if httpd.download_completed and (time.time() - httpd.completion_time > 3.0):
                emit_event({"event": "completed_exit"})
                break
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
        emit_event({"event": "stopped"})

if __name__ == "__main__":
    main()
