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
import hmac
import hashlib
import signal
import stat
from http.server import HTTPServer, BaseHTTPRequestHandler

PREFERRED_PORTS = [53317, 53318, 8080, 8000, 8888, 0]

# Clipboard beam throttling: bounds how often a single client may rewrite the
# host clipboard (and fire a desktop notification) per rolling window.
BEAM_MAX_PER_WINDOW = 5
BEAM_WINDOW = 10.0

# Maximum number of folder ZIPs retained on disk for the session. Each entry is
# a real temp file, so the cache is capped and evicted LRU.
FOLDER_ZIP_CACHE_MAX = 10
# ext4 caps a single path component at 255 bytes (NAME_MAX); the upload
# filename is trimmed to this so open() cannot fail with ENAMETOOLONG.
UPLOAD_NAME_MAX_BYTES = 180

# Free-space headroom required before writing a multi-hundred-MB payload.
DISK_SPACE_MARGIN_BYTES = 256 * 1024 * 1024

# A failed-PIN record older than this is pruned from the lockout table.
FAILED_ATTEMPT_RECORD_TTL_SEC = 1800

# Ceiling on a single upload's overall transfer deadline, derived from the
# declared content length plus a floor rate. Unrelated to the lockout TTL.
UPLOAD_DEADLINE_MAX_SEC = 1800.0

# Default lifetime of a share session before the server exits.
DEFAULT_SERVER_TIMEOUT_SEC = 1800

# Suffixes for the in-flight upload markers this server creates, and the age a
# marker must reach before the crash sweep may remove it. The markers are
# namespaced to ReClip so the sweep can prove a file is ours before unlinking
# it: save_dir is a real user directory (~/Downloads/ReClip-Drop by default),
# and a bare ".part"/".reserve" suffix also matches unrelated files that the
# user or another application put there.
RESERVE_MARKER_SUFFIX = ".reclip-reserve"
PART_MARKER_SUFFIX = ".reclip-part"
STALE_MARKER_MAX_AGE_SEC = 3600


def is_reclip_upload_marker(name):
    """True only for upload marker names this server itself writes."""
    if not name.startswith("."):
        return False
    if name.endswith(RESERVE_MARKER_SUFFIX):
        return True
    if name.endswith(PART_MARKER_SUFFIX):
        # Shape is ".<sanitized name>.<8 hex token>.reclip-part".
        token = name[:-len(PART_MARKER_SUFFIX)].rsplit(".", 1)[-1]
        return len(token) == 8 and all(c in "0123456789abcdef" for c in token)
    return False

def iter_share_files(root):
    """Yield (abs_path, rel_path) for regular files under root, never escaping it.

    os.walk() alone is not enough: followlinks=False stops it from *descending*
    into symlinked directories but still reports them in dirnames, and symlinked
    *files* still appear in filenames. Either one lets a symlink planted inside
    a shared folder pull /etc/shadow (or any host file) into a ZIP served to a
    remote peer. So directory symlinks are pruned explicitly, file symlinks are
    skipped, and every resolved path is confirmed to remain under root as
    defence in depth against TOCTOU swaps during the walk.
    """
    root_real = os.path.realpath(root)
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        # Prune symlinked subdirectories in place so os.walk never yields them.
        dirnames[:] = [d for d in dirnames
                       if not os.path.islink(os.path.join(dirpath, d))]
        for fn in filenames:
            fp = os.path.join(dirpath, fn)
            try:
                st = os.lstat(fp)
            except OSError:
                continue
            # Skip anything that is not a plain regular file (symlinks, FIFOs,
            # sockets, devices) -- only real content should leave the host.
            if not stat.S_ISREG(st.st_mode):
                continue
            # Final containment check against the resolved real path.
            try:
                real = os.path.realpath(fp)
                if os.path.commonpath([real, root_real]) != root_real:
                    continue
            except (OSError, ValueError):
                continue
            yield fp, os.path.relpath(fp, root)

def content_disposition_value(disposition, download_name):
    """Build a header-safe Content-Disposition value (RFC 6266).

    BaseHTTPRequestHandler.send_header() writes header lines verbatim, so a
    filename containing a double quote or CRLF would otherwise break out of the
    filename= parameter and let a crafted shared-file name inject arbitrary
    response headers. The quoted ASCII fallback is therefore stripped of quotes,
    CR, LF and other control characters; the exact UTF-8 name still reaches
    modern clients through the RFC 5987 filename* parameter, which is
    percent-encoded and cannot terminate the header.
    """
    ascii_name = "".join(
        ch if 0x20 <= ord(ch) < 0x7F else "_" for ch in download_name
    ).replace('"', "'").replace("\\", "_").strip()
    if not ascii_name or ascii_name in (".", ".."):
        ascii_name = "download"
    encoded_name = urllib.parse.quote(download_name, safe="")
    return f"{disposition}; filename=\"{ascii_name}\"; filename*=UTF-8''{encoded_name}"

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

_emit_lock = threading.Lock()

def emit_event(event_dict):
    """Emit JSON event line to stdout and flush (thread-safe)."""
    try:
        line = json.dumps(event_dict)
        with _emit_lock:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
    except Exception:
        pass

def _escape_pango(text):
    """Escape Pango markup metacharacters so notification text renders literally.

    notify-send parses the summary and body as Pango markup, so a beamed snippet
    or an uploaded filename containing markup would otherwise be interpreted.
    notify-send 0.8.x (the version shipped on most Omarchy installs) has no
    --no-markup flag, so escaping the input is the portable fix.
    """
    return (text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;"))

def send_desktop_notification(title, message, icon="document-save"):
    """Spawn background notify-send to avoid blocking request thread."""
    def _notify():
        try:
            subprocess.run(
                ["notify-send", _escape_pango(title), _escape_pango(message), f"--icon={icon}"],
                check=False, timeout=3,
            )
        except Exception:
            pass
    threading.Thread(target=_notify, daemon=True).start()

def constant_time_equals(presented, expected):
    """Constant-time comparison that tolerates any input.

    secrets.compare_digest() raises TypeError when given two str values
    containing non-ASCII characters. Token and PIN checks sit in the
    pre-authentication path, so a request carrying e.g. "?token=café" raised
    TypeError inside the handler, killed the request thread and dropped the
    connection before any response could be sent -- an unauthenticated way to
    break every request.

    Comparing the UTF-8 encodings keeps the constant-time guarantee (falling
    back to == would leak the secret through timing) and makes the result False
    for any input that simply is not the secret. Mismatched lengths still fail
    fast, which leaks nothing: the secret is fixed-length and the length is not
    a secret.
    """
    if not isinstance(presented, str) or not isinstance(expected, str):
        return False
    try:
        return secrets.compare_digest(presented.encode("utf-8"), expected.encode("utf-8"))
    except (UnicodeError, AttributeError):
        return False


def unique_display_name(bname, used):
    """Return a name not already in `used`, recording it.

    Two shared paths can share a basename (A/same.txt and B/same.txt). The name
    is both the download URL and the visible card label, so a duplicate made
    two cards fetch the same file and silently dropped one. Disambiguating here
    keeps every entry reachable, and keeping the helper at module level makes it
    directly testable.
    """
    if bname not in used:
        used.add(bname)
        return bname
    stem, ext = os.path.splitext(bname)
    counter = 2
    while f"{stem} ({counter}){ext}" in used:
        counter += 1
    final = f"{stem} ({counter}){ext}"
    used.add(final)
    return final


def set_desktop_clipboard(text):
    """Copy text to Linux clipboard using wl-copy or xclip."""
    # Popen + communicate(timeout) leaves the child running when the timeout
    # fires; it must be killed and reaped, or every slow clipboard write leaks
    # a process and a wl-copy holding the selection. The sibling helpers use
    # subprocess.run(timeout=...), which reaps for us.
    for cmd in (["wl-copy"], ["xclip", "-selection", "clipboard"]):
        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            try:
                proc.communicate(input=text.encode("utf-8"), timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.communicate()
            return True
        except Exception:
            continue
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
        self._sweep_stale_uploads()
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
        self.folder_zip_cache = {}          # folder_path -> temp_zip_path
        self._folder_zip_cache_order = []   # LRU insertion order
        self.zip_cache_lock = threading.Lock()
        self.download_count = 0

        # Beam rate limiting: BEAM_MAX_PER_WINDOW beams per BEAM_WINDOW seconds
        # per client IP, bounding clipboard-rewrite and notification flooding.
        self.beam_lock = threading.Lock()
        self.beam_rate = {}                 # client_ip -> list of timestamps

        # Rate limiting and lockout state
        self.attempt_lock = threading.Lock()
        self.failed_attempts = {}       # client_ip -> {"count": int, "locked_until": float}
        self.global_failed_attempts = 0
        self.global_locked_until = 0.0

        # Upload serialization: guards session_uploaded_bytes, disk-space checks,
        # and destination-filename reservation so concurrent uploads cannot
        # collectively exceed quota or silently overwrite one another.
        self.upload_lock = threading.Lock()

        # Guards the remaining cross-thread session state (download_count,
        # download_completed, completion_time) so increments are not lost and
        # single-shot completion is never observed half-written. Deliberately
        # separate from upload_lock so a completed download never contends with
        # an in-flight multi-gigabyte quota reservation.
        self.state_lock = threading.Lock()

    def csrf_token(self):
        """Derive the per-session CSRF token from the auth token via HMAC.

        Deterministic for the life of the session, so it can be embedded in the
        portal HTML without any extra round-trip, and unforgeable without the
        server token.
        """
        return hmac.new(self.token.encode("utf-8"), b"reclip-csrf-v1", hashlib.sha256).hexdigest()

    def _sweep_stale_uploads(self):
        """Remove leftover upload markers from a previous crashed session.

        Without this, a hard kill mid-upload leaves hidden placeholders behind
        that permanently block those destination filenames in the collision loop.

        Only markers this server wrote are eligible: save_dir is an ordinary
        user directory, so a name that merely ends in ".part"/".reserve" proves
        nothing. Anything that is not a namespaced ReClip marker, is not a
        regular file (a symlink or directory is never ours to delete), or is
        younger than STALE_MARKER_MAX_AGE_SEC is left strictly alone.
        """
        now = time.time()
        try:
            entries = os.scandir(self.save_dir)
        except OSError:
            return
        with entries:
            for entry in entries:
                if not is_reclip_upload_marker(entry.name):
                    continue
                try:
                    # follow_symlinks=False makes a symlink report False here,
                    # so links are skipped rather than followed and unlinked.
                    if not entry.is_file(follow_symlinks=False):
                        continue
                    if (now - entry.stat(follow_symlinks=False).st_mtime) < STALE_MARKER_MAX_AGE_SEC:
                        continue
                    os.unlink(entry.path)
                except OSError:
                    pass

    def _discard_zip_cache(self):
        """Unlink and clear the shared single-file bundle archive, if any.

        Callers must hold zip_cache_lock. server_close() deliberately does not,
        since the server is already torn down at that point.
        """
        path = self.zip_cache_path
        if not path:
            return
        self.zip_cache_path = None
        try:
            os.unlink(path)
        except OSError:
            pass

    def cache_folder_zip(self, folder_path, temp_zip):
        """Insert a folder ZIP into the cache, evicting the oldest beyond the cap.

        Unbounded growth matters here: every cached entry is a real temp file
        held open on disk for the whole session, so a client walking many shared
        folders would otherwise accumulate GBs in the system temp directory.
        """
        with self.zip_cache_lock:
            if folder_path in self.folder_zip_cache:
                self._folder_zip_cache_order.remove(folder_path)
            self.folder_zip_cache[folder_path] = temp_zip
            self._folder_zip_cache_order.append(folder_path)
            while len(self._folder_zip_cache_order) > FOLDER_ZIP_CACHE_MAX:
                evicted = self._folder_zip_cache_order.pop(0)
                old = self.folder_zip_cache.pop(evicted, None)
                if old and old != temp_zip:
                    try:
                        os.unlink(old)
                    except OSError:
                        pass

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
  padding: calc(0.75rem + env(safe-area-inset-top, 0px)) 1.25rem 0.75rem;
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
  padding: 1.5rem 1.25rem calc(3rem + env(safe-area-inset-bottom, 0px)) 1.25rem;
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
.dropzone:focus-visible, .dropzone.focused {
  outline: 2px solid var(--accent);
  outline-offset: 3px;
  border-color: var(--accent);
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
.session-banner {
  background: rgba(244, 63, 94, 0.12);
  border: 1px solid rgba(244, 63, 94, 0.4);
  border-radius: var(--radius-sm);
  color: #fda4af;
  font-size: 0.85rem;
  font-weight: 600;
  padding: 0.7rem 0.85rem;
  margin-bottom: 0.75rem;
}
.upload-queue {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}
/* Aggregate header for the batch. Sending 30 photos one at a time gives 30
   rows and no answer to "is it done yet?", which is the only question the
   person actually has. */
.queue-summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  font-size: 0.8rem;
  color: var(--text-muted);
  margin-bottom: 0.15rem;
}
.queue-summary-title {
  font-weight: 600;
  color: var(--text-main);
}
.queue-clear {
  background: transparent;
  border: 1px solid var(--card-border);
  border-radius: var(--radius-sm);
  color: var(--text-muted);
  font-size: 0.7rem;
  font-weight: 600;
  padding: 0.3rem 0.6rem;
  cursor: pointer;
  transition: all 0.15s ease;
}
.queue-clear:hover, .queue-clear:focus-visible {
  color: var(--text-main);
  border-color: var(--card-border-hover);
  outline: none;
}
.queue-summary[hidden] {
  display: none;
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
  gap: 0.4rem;
  margin-bottom: 0.4rem;
}
.upload-cancel {
  flex: 0 0 auto;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 50%;
  border: 1px solid var(--card-border);
  background: transparent;
  color: var(--text-muted);
  font-size: 0.8rem;
  line-height: 1;
  cursor: pointer;
  transition: all 0.15s ease;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.upload-cancel:hover, .upload-cancel:focus-visible {
  color: #fda4af;
  border-color: rgba(244, 63, 94, 0.5);
  background: rgba(244, 63, 94, 0.12);
  outline: none;
}
.upload-item-name {
  font-size: 0.85rem;
  font-weight: 600;
  flex: 1 1 auto;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.upload-item-stat {
  font-size: 0.75rem;
  font-family: monospace;
  color: var(--text-muted);
  flex: 0 0 auto;
  white-space: nowrap;
  text-align: right;
  max-width: 55%;
  overflow: hidden;
  text-overflow: ellipsis;
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
/* Visually hidden but exposed to screen readers: a placeholder is not a label,
   and it disappears the moment the user types. */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
.search-clear {
  position: absolute;
  right: 0.4rem;
  top: 50%;
  transform: translateY(-50%);
  width: 1.5rem;
  height: 1.5rem;
  display: none;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: 50%;
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1;
  cursor: pointer;
}
.search-clear:hover, .search-clear:focus-visible {
  color: var(--text-main);
  outline: none;
}
.search-clear.is-visible {
  display: flex;
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

/* Download lifecycle states.
   A plain <a download> gives the user nothing: the tap looks identical whether
   the file is 2 KB or 2 GB, and a server-side ZIP that takes 40s to build looks
   exactly like a dead link. These states give every download a visible outcome. */
.btn.is-working {
  opacity: 0.75;
  pointer-events: none;
}
.btn-dl.is-working .dl-label,
.btn-dl.is-done .dl-label {
  display: none;
}
.btn-dl.is-working::after {
  content: "Starting…";
}
.btn-dl.is-done {
  background: var(--success);
  color: #ffffff;
}
.btn-dl.is-done::after {
  content: "✓ Started";
}
/* A prepared ZIP: the server is still deflating, so no bytes have moved yet. */
.btn-dl.is-preparing::after {
  content: "Preparing ZIP…";
}
.btn-dl.is-failed {
  background: #f43f5e;
  color: #ffffff;
}
.btn-dl.is-failed::after {
  content: "Failed — retry";
}
.card.is-done {
  border-color: var(--success);
}
.card-dl-status {
  display: none;
  font-size: 0.7rem;
  font-weight: 600;
  color: var(--text-muted);
  margin-top: 0.35rem;
}
.card-dl-status.is-visible {
  display: block;
}
.card-dl-status.is-error {
  color: #f43f5e;
}

/* No-match state for search + category filtering. */
.no-results {
  display: none;
  text-align: center;
  padding: 2.5rem 1rem;
  color: var(--text-muted);
  border: 1px dashed var(--card-border);
  border-radius: var(--radius-md);
  background: var(--card-bg);
}
.no-results.is-visible {
  display: block;
}
.no-results-icon {
  font-size: 1.75rem;
  margin-bottom: 0.5rem;
  opacity: 0.6;
}
.no-results-title {
  font-weight: 700;
  color: var(--text-main);
  margin-bottom: 0.2rem;
}
.no-results-hint {
  font-size: 0.8rem;
}
.no-results-clear {
  margin-top: 0.9rem;
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
  bottom: calc(1.5rem + env(safe-area-inset-bottom, 0px));
  left: 50%;
  max-width: min(92vw, 30rem);
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
  text-align: center;
  justify-content: center;
}
.toast-box.show {
  transform: translateX(-50%) translateY(0);
  opacity: 1;
}
.toast-box.is-error {
  border-color: #f43f5e;
  color: #fda4af;
  background: rgba(244, 63, 94, 0.14);
}
.toast-box.is-success {
  border-color: var(--success);
  color: var(--success);
  background: rgba(52, 211, 153, 0.12);
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
  padding-bottom: calc(1rem + env(safe-area-inset-bottom, 0px));
}
.lightbox[hidden] {
  display: none;
}
.lightbox-content {
  max-width: 90vw;
  max-height: 85vh;
  object-fit: contain;
  border-radius: var(--radius-sm);
  box-shadow: 0 12px 48px rgba(0, 0, 0, 0.5);
}
.lightbox-close {
  position: absolute;
  top: calc(0.75rem + env(safe-area-inset-top, 0px));
  right: 0.75rem;
  width: 2.75rem;
  height: 2.75rem;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 50%;
  color: #ffffff;
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
  z-index: 2;
}
.lightbox-close:hover, .lightbox-close:focus-visible {
  background: rgba(255, 255, 255, 0.2);
  outline: none;
}
.lightbox-caption {
  position: absolute;
  bottom: calc(0.75rem + env(safe-area-inset-bottom, 0px));
  left: 50%;
  transform: translateX(-50%);
  max-width: 90vw;
  padding: 0.35rem 0.85rem;
  background: rgba(0, 0, 0, 0.6);
  border-radius: var(--radius-sm);
  color: #f8fafc;
  font-size: 0.78rem;
  text-align: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* PIN Lock Screen CSS */
.pin-body {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: var(--bg);
  padding: 1.5rem;
  padding-top: calc(1.5rem + env(safe-area-inset-top, 0px));
  padding-bottom: calc(1.5rem + env(safe-area-inset-bottom, 0px));
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
  .portal-container { padding: 1rem 0.75rem calc(3rem + env(safe-area-inset-bottom, 0px)) 0.75rem; }
  .nav-inner { padding: calc(0.5rem + env(safe-area-inset-top, 0px)) 0.75rem 0.5rem; gap: 0.4rem; }
  .brand-title { font-size: 0.95rem; }
  .brand-tag { display: none; }
  .nav-pin-badge { font-size: 0.7rem; padding: 0.2rem 0.45rem; }
  .nav-pill { font-size: 0.7rem; padding: 0.2rem 0.45rem; }
  .bundle-banner { flex-direction: column; align-items: stretch; }
  .file-grid { grid-template-columns: 1fr; }
  .dropzone { padding: 1.25rem 0.75rem; }
  /* Touch targets: 44px is the smallest reliably tappable size on a phone,
     and this page is almost always viewed on one. */
  .btn { padding: 0.7rem 1rem; font-size: 0.9rem; min-height: 2.75rem; }
  .btn-sm { padding: 0.55rem 0.8rem; font-size: 0.8rem; min-height: 2.5rem; }
  .filter-chip { padding: 0.5rem 0.85rem; font-size: 0.8rem; min-height: 2.25rem; }
  .quickbar-btn { padding: 0.6rem 0.9rem; min-height: 2.5rem; }
  .theme-toggle-btn { width: 2.5rem; height: 2.5rem; }
  .pin-theme-btn { top: calc(0.75rem + env(safe-area-inset-top, 0px)); right: 0.75rem; }
  .upload-item { padding: 0.85rem; }
  .beam-textarea { font-size: 0.9rem; min-height: 96px; }
  .search-input { font-size: 0.9rem; min-height: 2.5rem; }
  .toast-box { font-size: 0.82rem; padding: 0.75rem 1rem; }
  .queue-clear { padding: 0.45rem 0.75rem; min-height: 2.25rem; }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
  .pulse-dot { animation: none; }
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

var toastTimer = null;

function showToast(msg, type) {
  var t = document.getElementById('toast');
  if (!t) return;
  // textContent, not innerHTML: this string can carry a filename, and the
  // page holds the CSRF token.
  t.textContent = msg;
  // `type` was accepted and ignored, so every failure rendered in the same
  // green-ish neutral box as a success. Colour is what a user scans first.
  t.className = 'toast-box show' + (type ? ' is-' + type : '');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(function() {
    t.className = 'toast-box';
    toastTimer = null;
  }, 3200);
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
// Wrapping the img is what makes the image itself tappable: without it the
// click landed on the backdrop and closed the viewer the instant it opened.
function openLightbox(src, title) {
  var lb = document.getElementById('lightbox');
  var img = document.getElementById('lightbox-img');
  if (!lb || !img) return;
  img.src = src;
  img.alt = title || 'Preview';
  var cap = document.getElementById('lightbox-caption');
  if (cap) {
    cap.textContent = title || '';
    cap.style.display = title ? 'block' : 'none';
  }
  lb.hidden = false;
  lb.style.display = 'flex';
  var close = document.getElementById('lightbox-close');
  if (close) close.focus();
}
function closeLightbox() {
  var lb = document.getElementById('lightbox');
  if (!lb) return;
  lb.hidden = true;
  lb.style.display = 'none';
  var img = document.getElementById('lightbox-img');
  // Release the decoded bitmap; a phone that just streamed a 12 MP photo
  // should not hold it for the rest of the session.
  if (img) img.removeAttribute('src');
}

// Download lifecycle
// The download button is a real <a download>, so there is no XHR to hook and
// no progress event to read. What we can do is stop the tap from looking
// identical whether the file is 2 KB or 2 GB, and tell the user when the
// browser has taken the file.
function markDownload(anchor, stateName, statusText) {
  if (!anchor) return;
  anchor.classList.remove('is-working', 'is-done', 'is-preparing', 'is-failed');
  if (stateName) anchor.classList.add(stateName);
  var card = anchor.closest ? anchor.closest('.file-card') : null;
  var status = card ? card.querySelector('.card-dl-status') : null;
  if (status) {
    status.textContent = statusText || '';
    status.classList.toggle('is-visible', !!statusText);
    status.classList.toggle('is-error', stateName === 'is-failed');
  }
  if (card && stateName === 'is-done') card.classList.add('is-done');
}

function onDownloadTap(ev) {
  var anchor = ev.target && ev.target.closest ? ev.target.closest('a.btn-dl') : null;
  if (!anchor) return;
  // A folder/bundle ZIP is deflated server-side before the first byte moves,
  // which can take tens of seconds. Say so, or it reads as a dead link.
  var href = anchor.getAttribute('href') || '';
  var isZip = href.indexOf('bundle') !== -1 || href.indexOf('zip') !== -1;
  markDownload(anchor, isZip ? 'is-preparing' : 'is-working',
    isZip ? 'Building ZIP on the PC — this can take a moment…' : 'Starting download…');
  haptic(8);
  // The browser takes over from here. If the transfer never lands, the status
  // line is the user's cue to re-tap, so it has to persist rather than vanish.
  setTimeout(function() {
    markDownload(anchor, 'is-done', isZip ? 'ZIP download started' : 'Download started — check your browser downloads');
  }, 900);
}

function onPreviewTap(ev) {
  var btn = ev.target && ev.target.closest ? ev.target.closest('.js-preview-image') : null;
  if (!btn) return;
  openLightbox(btn.getAttribute('data-src'), btn.getAttribute('data-name'));
}

function initDownloadTracking() {
  var grid = document.getElementById('file-grid');
  if (grid) {
    grid.addEventListener('click', onDownloadTap);
    grid.addEventListener('click', onPreviewTap);
  }
  var bundle = document.querySelector('.bundle-banner a[href="/bundle"]');
  if (bundle) {
    bundle.addEventListener('click', function() {
      showToast('Building ZIP on the PC — large shares can take a moment', 'success');
      haptic(8);
    });
  }
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
  chips.forEach(function(c) {
    var on = c === btn;
    c.classList.toggle('active', on);
    // A chip is a toggle; without aria-pressed a screen reader announces every
    // category identically and gives no way to tell what is currently applied.
    c.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  applyFilters();
}
function clearFilters() {
  currentFilter = 'all';
  currentSearch = '';
  var input = document.querySelector('.search-input');
  if (input) input.value = '';
  var clear = document.querySelector('.search-clear');
  if (clear) clear.classList.remove('is-visible');
  var chips = document.querySelectorAll('.filter-chip');
  chips.forEach(function(c) {
    var on = c.getAttribute('data-cat') === 'all';
    c.classList.toggle('active', on);
    c.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  applyFilters();
}
function applyFilters() {
  var cards = document.querySelectorAll('.file-card');
  var visible = 0;
  cards.forEach(function(card) {
    var cat = card.getAttribute('data-cat') || 'other';
    var name = (card.getAttribute('data-name') || '').toLowerCase();
    var matchCat = (currentFilter === 'all' || cat === currentFilter);
    var matchSearch = (!currentSearch || name.indexOf(currentSearch) !== -1);
    var show = (matchCat && matchSearch);
    card.style.display = show ? 'flex' : 'none';
    if (show) visible += 1;
  });

  // Filtering to nothing used to leave a blank page with no explanation.
  var empty = document.getElementById('no-results');
  if (empty) {
    var filtered = (currentFilter !== 'all' || !!currentSearch);
    if (visible === 0 && filtered) {
      empty.classList.add('is-visible');
      var hint = document.getElementById('no-results-hint');
      if (hint) {
        hint.textContent = currentSearch
          ? 'Nothing matches "' + currentSearch + '".'
          : 'No files in this category.';
      }
    } else {
      empty.classList.remove('is-visible');
    }
  }

  var count = document.getElementById('result-count');
  if (count) {
    count.textContent = (visible === cards.length)
      ? ''
      : visible + ' of ' + cards.length + ' shown';
  }
  var clear = document.querySelector('.search-clear');
  if (clear) clear.classList.toggle('is-visible', !!currentSearch);
}

function initFilters() {
  var chips = document.querySelectorAll('.filter-chip');
  chips.forEach(function(c) {
    var on = c.classList.contains('active');
    c.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  applyFilters();
}

// P1: Reverse Drop File Uploads
var uploadQueue = [];
var activeJobs = {};            // uid -> job currently in flight
var activeUploads = 0;
var batchTotal = 0;             // files ever added to this batch
var batchDone = 0;              // files that reached a terminal success
var batchFailed = 0;            // files that gave up for good
var batchCancelled = 0;         // files the user cancelled before they sent
var batchBytes = 0;             // bytes handed to the server this batch
var MAX_CONCURRENT_UPLOADS = 2;
var MAX_RETRIES = 3;
var RETRY_BASE_MS = 1200;
var STALL_TIMEOUT_MS = 20000;   // no byte progress for this long => socket is dead
var ABSOLUTE_TIMEOUT_MS = 45 * 60 * 1000;
var RETRYABLE_STATUS = [0, 408, 425, 429, 500, 502, 503, 504];
var wakeLock = null;
var wakePending = false;
var consecutiveNetErrors = 0;

// Server limits, injected as meta tags. Used to reject hopeless uploads before
// spending minutes streaming a body that the server will 413 anyway.
function reclipConfig() {
  function meta(name) {
    var m = document.querySelector('meta[name="' + name + '"]');
    return m ? (m.getAttribute('content') || '') : '';
  }
  function num(name) {
    var v = parseInt(meta(name), 10);
    return isNaN(v) ? 0 : v;
  }
  return {
    maxUploadSize: num('reclip-max-upload-size'),
    maxSessionQuota: num('reclip-max-session-quota'),
    sessionUsed: num('reclip-session-used'),
    maxConcurrent: num('reclip-max-concurrent-uploads'),
    singleShot: meta('reclip-single-shot') === '1'
  };
}

function haptic(pattern) {
  try { if (navigator.vibrate) navigator.vibrate(pattern); } catch (e) {}
}

function acquireWakeLock() {
  if (wakeLock || wakePending || !navigator.wakeLock || activeUploads === 0) return;
  wakePending = true;
  var request;
  try {
    request = navigator.wakeLock.request('screen');
  } catch (e) {
    wakePending = false;
    return;
  }
  Promise.resolve(request).then(function(lock) {
    wakePending = false;
    // The transfer can finish while the wake-lock prompt is still pending. If
    // that happened, hand it straight back instead of holding the screen awake
    // for the rest of the session.
    if (activeUploads === 0) {
      try { lock.release(); } catch (e) {}
      return;
    }
    wakeLock = lock;
    lock.addEventListener('release', function() { wakeLock = null; });
  }).catch(function() {
    wakePending = false;
  });
}

function releaseWakeLock() {
  if (!wakeLock) return;
  try { wakeLock.release(); } catch (e) {}
  wakeLock = null;
}

function setSessionState(state, msg) {
  var b = document.getElementById('session-banner');
  if (!b) return;
  if (state === 'ok') {
    b.style.display = 'none';
    b.textContent = '';
    return;
  }
  b.textContent = msg || 'Reconnecting…';
  b.style.display = 'block';
}

function serverErrorText(xhr, fallback) {
  try {
    var data = JSON.parse(xhr.responseText);
    if (data && typeof data.error === 'string' && data.error) return data.error;
  } catch (e) {}
  return fallback || ('Upload failed (HTTP ' + (xhr.status || 0) + ')');
}

function setStat(uid, text, color) {
  var el = document.getElementById(uid + '_stat');
  if (!el) return;
  el.textContent = text;
  el.style.color = color || '';
}

function setFill(uid, pct, cls) {
  var el = document.getElementById(uid + '_fill');
  if (!el) return;
  if (pct !== null) el.style.width = pct + '%';
  if (cls !== undefined) {
    el.classList.remove('success', 'error');
    if (cls) el.classList.add(cls);
  }
}

function buildUploadItem(uid, file) {
  // Built with createElement + textContent on purpose: interpolating file.name
  // into innerHTML lets a crafted filename inject live markup, and the CSRF
  // token now lives in this document.
  var item = document.createElement('div');
  item.className = 'upload-item';
  item.id = uid;

  var header = document.createElement('div');
  header.className = 'upload-item-header';

  var nameEl = document.createElement('span');
  nameEl.className = 'upload-item-name';
  nameEl.textContent = file.name;
  nameEl.title = file.name;

  var cancelBtn = document.createElement('button');
  cancelBtn.type = 'button';
  cancelBtn.className = 'upload-cancel';
  cancelBtn.setAttribute('aria-label', 'Cancel upload of ' + file.name);
  cancelBtn.textContent = '\u2715';
  cancelBtn.addEventListener('click', function() { cancelUpload(uid); });

  var statEl = document.createElement('span');
  statEl.className = 'upload-item-stat';
  statEl.id = uid + '_stat';
  statEl.textContent = 'Queued';

  header.appendChild(nameEl);
  header.appendChild(cancelBtn);
  header.appendChild(statEl);

  var track = document.createElement('div');
  track.className = 'prog-bar-track';
  var fill = document.createElement('div');
  fill.className = 'prog-bar-fill';
  fill.id = uid + '_fill';
  track.appendChild(fill);

  item.appendChild(header);
  item.appendChild(track);
  return item;
}

function removeUploadItem(uid) {
  var el = document.getElementById(uid);
  if (el && el.parentNode) el.parentNode.removeChild(el);
}

function cancelUpload(uid) {
  for (var i = 0; i < uploadQueue.length; i++) {
    if (uploadQueue[i].uid === uid) {
      uploadQueue[i].cancelled = true;
      removeUploadItem(uid);
      // This file was counted into batchTotal when queued, so it must be
      // counted as settled here. Without this the summary could never reach
      // settled === batchTotal: it stayed on "Sending 2 of 3…" for the rest of
      // the session and the final toast never fired. Cancellations are their
      // own outcome rather than failures, so they are not shown as errors.
      batchCancelled += 1;
      updateBatchSummary();
      showToast('Upload cancelled');
      haptic(10);
      return;
    }
  }
  var job = activeJobs[uid];
  if (job && job.xhr) {
    job.cancelled = true;
    setStat(uid, 'Cancelling…', 'var(--text-muted)');
    try { job.xhr.abort(); } catch (e) {}
  }
}

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
  // Keyboard activation: the dropzone is a div, so it needs explicit wiring to
  // be reachable at all without a pointer.
  dz.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') {
      e.preventDefault();
      var input = document.getElementById('file-input');
      if (input) input.click();
    }
  });
  dz.addEventListener('focus', function() { dz.classList.add('focused'); });
  dz.addEventListener('blur', function() { dz.classList.remove('focused'); });
}

function handleFilesSelected(files) {
  if (!files || files.length === 0) return;
  var queueList = document.getElementById('upload-queue');
  if (!queueList) return;

  var added = 0;
  for (var i = 0; i < files.length; i++) {
    var file = files[i];
    var uid = 'up_' + Date.now() + '_' + i + '_' + Math.random().toString(36).substr(2, 5);
    uploadQueue.push({ uid: uid, file: file, cancelled: false, attempt: 0, xhr: null, finished: false });
    // appendChild, not prepend: the queue is processed FIFO, so prepending made
    // the newest file appear on top while the oldest was the one transferring.
    // The list has to read top-to-bottom in the order work actually happens.
    queueList.appendChild(buildUploadItem(uid, file));
    batchTotal += 1;
    added += 1;
  }
  if (added > 0) {
    haptic(8);
    updateBatchSummary();
    processUploadQueue();
  }
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// CSRF token derived server-side from the session token and embedded in the
// page head. A cross-origin page cannot read this document, so it cannot forge
// the header a cookie-authenticated POST requires.
function csrfToken() {
  var m = document.querySelector('meta[name="reclip-csrf"]');
  return m ? m.getAttribute('content') : '';
}

function releaseSlot(job) {
  // Guarded so a double release can never decrement twice.
  if (activeJobs[job.uid] !== job) return;
  delete activeJobs[job.uid];
  activeUploads = Math.max(0, activeUploads - 1);
  if (activeUploads === 0) releaseWakeLock();
}

function updateBatchSummary() {
  var el = document.getElementById('queue-summary');
  if (!el) return;
  if (batchTotal === 0) {
    el.hidden = true;
    return;
  }
  el.hidden = false;
  var settled = batchDone + batchFailed + batchCancelled;
  var title = document.getElementById('queue-summary-title');
  if (title) {
    if (settled < batchTotal) {
      title.textContent = 'Sending ' + settled + ' of ' + batchTotal +
        (batchBytes ? ' · ' + formatBytes(batchBytes) : '') + '…';
    } else if (batchFailed === 0 && batchCancelled === 0) {
      title.textContent = '✓ All ' + batchDone + ' file' + (batchDone === 1 ? '' : 's') +
        ' sent' + (batchBytes ? ' · ' + formatBytes(batchBytes) : '');
    } else {
      title.textContent = '✓ ' + batchDone + ' sent' +
        (batchFailed ? ', ' + batchFailed + ' failed' : '') +
        (batchCancelled ? ', ' + batchCancelled + ' cancelled' : '') +
        (batchBytes ? ' · ' + formatBytes(batchBytes) : '');
    }
  }
  // One summary beats N toasts when 20 photos land in a few seconds.
  if (settled === batchTotal && batchTotal > 1) {
    if (batchFailed === 0) showToast('✓ All ' + batchDone + ' files sent to PC', 'success');
    else showToast(batchDone + ' sent, ' + batchFailed + ' failed', 'error');
    haptic([15, 40, 15]);
  }
}

function clearFinishedUploads() {
  // Drop the rows that reached a terminal state so a 40-file batch does not
  // leave the user scrolling through history.
  var items = document.querySelectorAll('.upload-item');
  for (var i = 0; i < items.length; i++) {
    var el = items[i];
    if (el.getAttribute('data-state') === 'done' || el.getAttribute('data-state') === 'failed' ||
        el.getAttribute('data-state') === 'cancelled') {
      if (el.parentNode) el.parentNode.removeChild(el);
    }
  }
  var remaining = document.querySelectorAll('.upload-item');
  if (remaining.length === 0) {
    batchTotal = 0;
    batchDone = 0;
    batchFailed = 0;
    batchCancelled = 0;
    batchBytes = 0;
  }
  updateBatchSummary();
}

function finishJob(job, state) {
  if (job.finished) return;
  job.finished = true;
  if (state === 'done') batchDone += 1;
  else if (state === 'failed') batchFailed += 1;
  else if (state === 'cancelled') batchCancelled += 1;
  var el = document.getElementById(job.uid);
  if (el && state) el.setAttribute('data-state', state);
  releaseSlot(job);
  updateBatchSummary();
  processUploadQueue();
}

function failJob(job, message, retryable) {
  setFill(job.uid, null, 'error');
  setStat(job.uid, message, '#f43f5e');
  showToast(message, 'error');
  haptic([40, 60, 40]);
  if (retryable && job.attempt < MAX_RETRIES && !job.cancelled) {
    var wait = job.retryAfterMs || (RETRY_BASE_MS * Math.pow(2, job.attempt));
    job.attempt += 1;
    // Keep the reason visible: "retrying" on its own hides whether the PC went
    // away, the server said 503, or the transfer simply stalled.
    var reason = message.length > 52 ? message.slice(0, 51) + '…' : message;
    setStat(job.uid, reason + ' · retry ' + job.attempt + '/' + MAX_RETRIES, 'var(--text-muted)');
    // Release the concurrency slot immediately: a backing-off job must not
    // occupy one, or two failures would stall every other queued file.
    releaseSlot(job);
    // Hand the freed slot to whatever is waiting, without waiting out the
    // backoff, so a retry never blocks unrelated files.
    processUploadQueue();
    setTimeout(function() {
      if (job.cancelled) { removeUploadItem(job.uid); return; }
      // The retry jumps to the head of the queue, so move its row to the top
      // too. Leaving it in place would show the list in an order the queue
      // does not actually follow.
      var row = document.getElementById(job.uid);
      if (row && row.parentNode) row.parentNode.insertBefore(row, row.parentNode.firstChild);
      uploadQueue.unshift(job);
      processUploadQueue();
    }, wait);
    return;
  }
  finishJob(job, 'failed');
}

function processUploadQueue() {
  var cap = reclipConfig().maxConcurrent || MAX_CONCURRENT_UPLOADS;
  while (activeUploads < cap && uploadQueue.length > 0) {
    var job = uploadQueue.shift();
    if (job.cancelled) { removeUploadItem(job.uid); continue; }
    if (job.finished) continue;
    startUpload(job);
  }
  if (activeUploads === 0 && uploadQueue.length === 0) releaseWakeLock();
}

function startUpload(job) {
  var file = job.file;
  var cfg = reclipConfig();

  // Reject before touching the socket: streaming a body the server is going to
  // refuse wastes the user's time and the session quota for nothing.
  if (cfg.maxUploadSize > 0 && file.size > cfg.maxUploadSize) {
    setStat(job.uid, 'Too large', '#f43f5e');
    setFill(job.uid, null, 'error');
    showToast(file.name + ' is larger than the ' + formatBytes(cfg.maxUploadSize) + ' limit', 'error');
    haptic([40, 60, 40]);
    finishJob(job, 'failed');
    return;
  }
  if (cfg.maxSessionQuota > 0 && cfg.sessionUsed + file.size > cfg.maxSessionQuota) {
    setStat(job.uid, 'Over session quota', '#f43f5e');
    setFill(job.uid, null, 'error');
    showToast('This file would exceed the session upload quota', 'error');
    haptic([40, 60, 40]);
    finishJob(job, 'failed');
    return;
  }

  activeUploads += 1;
  activeJobs[job.uid] = job;
  job.finished = false;
  job.xhr = null;
  acquireWakeLock();
  attemptUpload(job);
}

function attemptUpload(job) {
  var file = job.file;
  var uid = job.uid;
  var xhr = new XMLHttpRequest();
  job.xhr = xhr;
  job.retryAfterMs = 0;

  var startTime = Date.now();
  var stallTimer = null;
  var settled = false;

  function bumpWatchdog() {
    if (stallTimer) clearTimeout(stallTimer);
    stallTimer = setTimeout(function() {
      if (settled) return;
      job.stalled = true;
      try { xhr.abort(); } catch (e) {}
      // If abort somehow did not settle us, fail it by hand rather than let the
      // slot leak -- this is the deadlock that used to brick the whole queue.
      if (!settled) { settled = true; failJob(job, 'Transfer stalled', true); }
    }, STALL_TIMEOUT_MS);
  }

  function retryAfterMs() {
    var h = xhr.getResponseHeader('Retry-After');
    if (!h) return 0;
    var secs = parseInt(h, 10);
    return isNaN(secs) ? 0 : Math.min(secs * 1000, 60000);
  }

  function done() {
    if (settled) return false;
    settled = true;
    if (stallTimer) clearTimeout(stallTimer);
    return true;
  }

  xhr.open('POST', '/upload', true);
  xhr.setRequestHeader('X-Filename', encodeURIComponent(file.name));

  xhr.setRequestHeader('X-CSRF-Token', csrfToken());
  xhr.timeout = ABSOLUTE_TIMEOUT_MS;

  setStat(uid, job.attempt > 0 ? ('Retrying (' + job.attempt + '/' + MAX_RETRIES + ')…') : 'Uploading…', 'var(--text-muted)');
  setFill(uid, '0%', null);
  bumpWatchdog();

  xhr.upload.onprogress = function(e) {
    bumpWatchdog();
    if (!e.lengthComputable) return;
    var pct = Math.round((e.loaded / e.total) * 100);
    var elapsed = (Date.now() - startTime) / 1000;
    var speed = elapsed > 0 ? (e.loaded / elapsed) : 0;
    setFill(uid, pct + '%', null);
    setStat(uid, pct + '% · ' + formatBytes(speed) + '/s', '');
  };

  xhr.onload = function() {
    if (!done()) return;
    if (xhr.status >= 200 && xhr.status < 300) {
      consecutiveNetErrors = 0;
      setSessionState('ok');
      setFill(uid, '100%', 'success');
      var done2 = xhr.responseText;
      var label = '✓ Sent';
      try {
        var parsed = JSON.parse(done2);
        if (parsed && parsed.size_str) label += ' (' + parsed.size_str + ')';
      } catch (e) {}
      setStat(uid, label, 'var(--success)');
      // One toast per file turns a 20-photo send into 20 stacked toasts that
      // overwrite each other; the batch summary carries the aggregate instead.
      if (batchTotal <= 1) showToast('✓ ' + file.name + ' sent to PC', 'success');
      batchBytes += file.size;
      haptic([12]);
      finishJob(job, 'done');
      return;
    }
    job.retryAfterMs = retryAfterMs();
    var retryable = RETRYABLE_STATUS.indexOf(xhr.status) !== -1;
    failJob(job, serverErrorText(xhr), retryable);
  };

  xhr.onerror = function() {
    if (!done()) return;
    consecutiveNetErrors += 1;
    if (consecutiveNetErrors >= 2) {
      setSessionState('lost',
        'Cannot reach the PC — the ReClip session may have ended. Re-scan the QR code to reconnect.');
    }
    failJob(job, 'Network error — ' + (navigator.onLine ? 'PC unreachable' : 'device offline'), true);
  };

  xhr.ontimeout = function() {
    if (!done()) return;
    failJob(job, 'Transfer timed out', true);
  };

  xhr.onabort = function() {
    if (!done()) return;
    if (job.cancelled) {
      setFill(uid, null, null);
      setStat(uid, 'Cancelled', 'var(--text-muted)');
      removeUploadItem(uid);
      showToast('Upload cancelled');
      finishJob(job, 'cancelled');
      return;
    }
    // Aborted by our own stall watchdog.
    failJob(job, job.stalled ? 'Transfer stalled — retrying' : 'Upload aborted', true);
  };

  try {
    xhr.send(file);
  } catch (e) {
    if (done()) failJob(job, 'Could not start upload', true);
  }
}

document.addEventListener('visibilitychange', function() {
  // The OS drops the wake lock whenever the page is hidden; take it back so a
  // backgrounded upload is not throttled.
  if (document.visibilityState === 'visible' && activeUploads > 0) acquireWakeLock();
});

window.addEventListener('online', function() {
  consecutiveNetErrors = 0;
  setSessionState('ok');
});

// P2: Clipboard Beam
// Turns a non-2xx API response into a real message. The server explains itself
// ("Beam limit reached — try again in 12s"); the UI used to throw that away and
// show a generic failure.
function apiError(res) {
  return res.json().catch(function() { return {}; }).then(function(data) {
    if (data && data.error) return new Error(data.error);
    return new Error('HTTP ' + res.status);
  });
}

function beamTextToPC() {
  var ta = document.getElementById('beam-textarea');
  if (!ta) return;
  var text = ta.value;
  if (!text.trim()) {
    showToast('Please enter text to beam', 'error');
    ta.focus();
    return;
  }
  // Mirrors the server's 128 KB cap. Catching it here saves a doomed upload
  // and tells the user why, instead of a bare 413 from the far end.
  if (text.length > 131072) {
    showToast('Text is too large to beam (max 128KB)', 'error');
    return;
  }
  fetch('/api/beam-text', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken() },
    body: JSON.stringify({ text: text })
  }).then(function(res) {
    if (!res.ok) return apiError(res).then(function(err) { throw err; });
    return res.json();
  }).then(function(data) {
    if (data.success) {
      showToast('⚡ Text beamed to PC clipboard!', 'success');
      ta.value = '';
      ta.focus();
      haptic([12]);
    } else {
      showToast('⚠ Failed to beam text', 'error');
    }
  }).catch(function(err) {
    showToast('⚠ ' + (err && err.message ? err.message : err), 'error');
  });
}

function fetchPCClipboard() {
  fetch('/api/beam-text').then(function(res) {
    if (!res.ok) return apiError(res).then(function(err) { throw err; });
    return res.json();
  }).then(function(data) {
    var box = document.getElementById('pc-clip-display');
    var txt = document.getElementById('pc-clip-text');
    if (box && txt) {
      txt.textContent = data.text || '(empty clipboard)';
      box.style.display = 'block';
      showToast('Fetched PC clipboard', 'success');
    }
  }).catch(function(err) {
    showToast('⚠ ' + (err && err.message ? err.message : err), 'error');
  });
}

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') closeLightbox();
});

document.addEventListener('DOMContentLoaded', function() {
  initDropzone();
  initFilters();
  initDownloadTracking();
  var clearBtn = document.getElementById('queue-clear');
  if (clearBtn) clearBtn.addEventListener('click', clearFinishedUploads);
  var searchClear = document.querySelector('.search-clear');
  if (searchClear) searchClear.addEventListener('click', clearFilters);
  var noResultsClear = document.getElementById('no-results-clear');
  if (noResultsClear) noResultsClear.addEventListener('click', clearFilters);
});
"""

PIN_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
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
      <input type="tel" inputmode="numeric" pattern="[0-9]*" maxlength="1" class="pin-digit" id="p0" autocomplete="one-time-code" autofocus>
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
        // Do not assume a JSON body: send_error() replies with an HTML error
        // page (used for the 413 oversize-PIN path), and res.json() would
        // reject and drop the real reason into the generic "Connection
        // error" catch below. Fall back to the status line instead.
        return res.text().then(function(text) {
          var data = null;
          try { data = JSON.parse(text); } catch (e) { data = null; }
          if (!data) {
            data = { success: false, error: (res.status === 413)
              ? 'PIN request too large'
              : ('Verification failed (HTTP ' + res.status + ')') };
          }
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

    def check_csrf(self):
        """Validate the X-CSRF-Token header for cookie-authenticated requests.

        Returns True when the request may proceed. Requests authenticated by the
        ?token= query parameter, an Authorization bearer, or X-ReClip-Token are
        exempt: those already require the caller to know the secret token, so a
        cross-site forgery adds no capability. Only ambient cookie auth -- the
        case a malicious page can ride on -- must present the CSRF token.
        """
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        token_q = query.get("token", [""])[0]
        if token_q and constant_time_equals(token_q, self.server.token):
            return True
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer ") and constant_time_equals(auth_header[7:].strip(), self.server.token):
            return True
        x_token = self.headers.get("X-ReClip-Token", "").strip()
        if x_token and constant_time_equals(x_token, self.server.token):
            return True

        presented = self.headers.get("X-CSRF-Token", "").strip()
        return bool(presented) and constant_time_equals(presented, self.server.csrf_token())

    def is_authenticated(self):
        """Check if request is authorized via query token or session cookie."""
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)

        # 1. Query parameter ?token=...
        token_q = query.get("token", [""])[0]
        if token_q and constant_time_equals(token_q, self.server.token):
            return True, True

        # 2. Cookie reclip_auth=...
        cookie_header = self.headers.get("Cookie", "")
        if cookie_header:
            for part in cookie_header.split(";"):
                part = part.strip()
                if part.startswith("reclip_auth="):
                    val = part[len("reclip_auth="):].strip()
                    if constant_time_equals(val, self.server.token):
                        return True, False

        # 3. Header Authorization / X-ReClip-Token
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            bearer_tok = auth_header[7:].strip()
            if bearer_tok and constant_time_equals(bearer_tok, self.server.token):
                return True, False
        x_token = self.headers.get("X-ReClip-Token", "").strip()
        if x_token and constant_time_equals(x_token, self.server.token):
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
            self._send_json(401, {"success": False, "error": "Authentication required. Enter PIN."})
            return

        # CSRF: reject ambient cookie-authenticated forgeries. /api/verify-pin is
        # exempt because it is the pre-auth credential check itself.
        if not self.check_csrf():
            self._send_json(403, {"success": False, "error": "Missing or invalid CSRF token."})
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
                       if now > data.get("locked_until", 0.0) and (now - data.get("last_attempt", 0.0) > FAILED_ATTEMPT_RECORD_TTL_SEC)]
            for ip in expired:
                self.server.failed_attempts.pop(ip, None)

            # Global lockout check
            if now < self.server.global_locked_until:
                retry_after = int(self.server.global_locked_until - now) + 1
                resp = json.dumps({
                    "success": False,
                    "error": f"Service temporarily locked due to excessive failed attempts. Please wait {retry_after}s."
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
                    "error": f"Too many failed PIN attempts. IP locked out for {retry_after}s."
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
            # Reply in the same JSON dialect the other verify-pin failures use,
            # so the PIN page can show the real reason. send_error() would emit
            # an HTML error page the client cannot parse.
            resp = json.dumps({
                "success": False,
                "error": "PIN request too large (limit 1KB)."
            }).encode("utf-8")
            self.send_response(413)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
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
        is_valid = constant_time_equals(pin_attempt, self.server.pin)

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
                # NOTE: no Secure attribute. The session token travels in clear
                # text because this is a plain-HTTP LAN server by design, so any
                # peer able to observe the traffic can capture the cookie. Adding
                # Secure would make the cookie unusable over http://. This is a
                # known, accepted risk of the zero-setup LAN design -- run ReClip
                # on a trusted network only. See the security notes in README.md.
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

        # Rate limit BEFORE reading the body so a spamming client cannot keep
        # this thread occupied reading 128 KB payloads indefinitely.
        now = time.time()
        with self.server.beam_lock:
            history = [t for t in self.server.beam_rate.get(client_ip, []) if now - t < BEAM_WINDOW]
            if len(history) >= BEAM_MAX_PER_WINDOW:
                retry_after = int(BEAM_WINDOW - (now - history[0])) + 1
                self.server.beam_rate[client_ip] = history
                retry = max(1, retry_after)
                resp = json.dumps({
                    "success": False,
                    "error": f"Too many beams. Try again in {retry}s."
                }).encode("utf-8")
                self.send_response(429)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp)))
                self.send_header("Retry-After", str(retry))
                self.end_headers()
                self.wfile.write(resp)
                return
            history.append(now)
            self.server.beam_rate[client_ip] = history
            # Drop idle client buckets so the dict cannot grow without bound.
            if len(self.server.beam_rate) > 64:
                cutoff = now - (BEAM_WINDOW * 2)
                self.server.beam_rate = {ip: ts for ip, ts in self.server.beam_rate.items() if ts and ts[-1] >= cutoff}

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
            # Publish under the lock so a concurrent GET never observes a
            # partially-published value and the field is always a whole string.
            with self.server.beam_lock:
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

    def _send_json(self, code, payload):
        """Write a complete JSON response with a correct Content-Length."""
        resp = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def handle_upload(self):
        """Streaming file upload from phone to ~/Downloads/ReClip-Drop with quota, disk space verification, read deadlines, and atomic partial-file cleanup."""
        client_ip = self.client_address[0]
        # NOTE: allow_upload is already enforced in do_POST() before dispatch here.

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

        # 3–5. Atomically check quota, disk space, and reserve a unique destination
        # filename — all under upload_lock so concurrent uploads cannot collectively
        # bypass the 5 GB session cap, exhaust disk, or collide on the same path.
        # Errors are recorded and responded to *after* the lock is released so a
        # slow socket write never blocks other upload threads.
        quota_reserved = False
        dest_path = None
        final_filename = None
        reserve_path = None
        reject = None

        with self.server.upload_lock:
            # 3. Session quota check-and-reserve
            if (self.server.session_uploaded_bytes + content_length) > self.server.max_session_upload_quota:
                reject = (413, {
                    "success": False,
                    "error": f"Upload rejected: Session quota of {format_size(self.server.max_session_upload_quota)} exceeded."
                })

            # 4. Disk space check — performed inside the same lock so inflight
            # reservations are already counted via session_uploaded_bytes.
            if reject is None:
                try:
                    disk_stat = shutil.disk_usage(self.server.save_dir)
                    # Require space for the file plus a 256 MB safety margin for the OS
                    min_required = content_length + DISK_SPACE_MARGIN_BYTES
                    if disk_stat.free < min_required:
                        reject = (507, {
                            "success": False,
                            "error": f"Insufficient disk space on host (Free: {format_size(disk_stat.free)}, Required: {format_size(min_required)})."
                        })
                except Exception:
                    pass

            if reject is None:
                # 5. Sanitize filename and atomically reserve a unique destination
                # path. Selection and reservation both happen inside the lock, and
                # the placeholder is created with O_EXCL so two threads uploading the
                # same filename can never select the same dest_path.
                raw_name = self.headers.get("X-Filename", "")
                if raw_name:
                    filename = urllib.parse.unquote(raw_name)
                else:
                    filename = f"reclip_drop_{int(time.time())}.bin"

                filename = os.path.basename(filename).replace("/", "_").replace("\\", "_").strip()
                filename = filename.lstrip(".")
                # X-Filename is attacker-controlled and the length was
                # uncapped, so an over-long name made open() fail with
                # ENAMETOOLONG and surfaced to the client as a 500. Keep the
                # stem short enough to still leave room for the collision
                # counter, the part marker and the reserve marker appended
                # later. The byte length is what ext4's NAME_MAX (255) checks.
                if len(filename.encode("utf-8")) > UPLOAD_NAME_MAX_BYTES:
                    base, ext = os.path.splitext(filename)
                    ext_budget = max(len(ext.encode("utf-8")), 0)
                    stem_budget = UPLOAD_NAME_MAX_BYTES - ext_budget
                    if stem_budget < 1:
                        filename = filename.encode("utf-8")[:UPLOAD_NAME_MAX_BYTES].decode(
                            "utf-8", "ignore"
                        )
                    else:
                        while len(base.encode("utf-8")) > stem_budget:
                            base = base[:-1]
                        filename = base + ext
                if not filename:
                    filename = f"reclip_drop_{int(time.time())}.bin"

                base, ext = os.path.splitext(filename)
                counter = 1
                while True:
                    cand = filename if counter == 1 else f"{base} ({counter}){ext}"
                    dest_path = os.path.join(self.server.save_dir, cand)
                    reserve_path = os.path.join(self.server.save_dir, f".{cand}{RESERVE_MARKER_SUFFIX}")
                    # Claim FIRST, then validate. The marker claim (O_EXCL) and
                    # the "already finalized?" check must be one atomic step:
                    # checking dest_path before claiming leaves a window where a
                    # peer renames its upload in and drops its marker, letting us
                    # claim a name that is already taken and overwrite it.
                    try:
                        fd = os.open(reserve_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                        os.close(fd)
                    except FileExistsError:
                        # Another upload holds this name in flight.
                        counter += 1
                        continue
                    except OSError as e:
                        reject = (500, {"success": False, "error": f"Upload failed: {str(e)}"})
                        dest_path = None
                        reserve_path = None
                        break
                    # We now own the name exclusively. Release and try the next
                    # counter if a completed upload already occupies it.
                    if os.path.exists(dest_path):
                        try:
                            os.unlink(reserve_path)
                        except OSError:
                            pass
                        counter += 1
                        continue
                    break

                if reject is None:
                    final_filename = os.path.basename(dest_path)
                    # Reserve quota now; it is released in finally if the upload fails.
                    self.server.session_uploaded_bytes += content_length
                    quota_reserved = True

        if reject is not None:
            self._send_json(reject[0], reject[1])
            return

        # Temporary partial upload path (.<name>.<token>.reclip-part)
        part_filename = f".{final_filename}.{secrets.token_hex(4)}{PART_MARKER_SUFFIX}"
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
        max_duration = min(UPLOAD_DEADLINE_MAX_SEC, max(60.0, (content_length / 10240) + 60.0))
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
            # The destination now exists on its own, so drop the reservation
            # marker immediately -- BEFORE replying 200. Waiting for the finally
            # block would let a client that lists the directory on success
            # observe the marker as stray debris. The finally block remains as
            # the safety net for every failure path.
            if reserve_path and os.path.exists(reserve_path):
                try:
                    os.unlink(reserve_path)
                except OSError:
                    pass
            reserve_path = None
            # Quota was pre-reserved by content_length; correct to actual bytes.
            with self.server.upload_lock:
                self.server.session_uploaded_bytes += (bytes_received - content_length)

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
            if not upload_succeeded:
                if os.path.exists(part_path):
                    try:
                        os.unlink(part_path)
                    except Exception:
                        pass
                # Release the pre-reserved quota so subsequent uploads are not
                # permanently blocked by a failed transfer.
                if quota_reserved:
                    with self.server.upload_lock:
                        self.server.session_uploaded_bytes -= content_length
            # Always remove the destination placeholder so the filename is not
            # permanently poisoned by a failed or cancelled upload.
            if reserve_path and os.path.exists(reserve_path):
                try:
                    os.unlink(reserve_path)
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
            # Snapshot the published text under the lock, but do NOT hold it
            # across get_desktop_clipboard() -- that spawns a 2 s subprocess and
            # would stall every concurrent beam and rate-limit check.
            with self.server.beam_lock:
                published = self.server.beam_text
            text = get_desktop_clipboard() or published
            resp = json.dumps({"success": True, "text": text}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            if need_cookie:
                self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax; HttpOnly")
            self.end_headers()
            if send_body:
                self.wfile.write(resp)
            return

        # 4. Status API
        if clean_path in ("api/status", "status.json"):
            # Strip the absolute "path" field: exposing the host's directory
            # layout to any authenticated peer discloses more than the share
            # itself, and nothing in the portal consumes it.
            public_files = [
                {k: v for k, v in item.items() if k != "path"}
                for item in self.server.files_meta
            ]
            status_data = {
                "status": "online",
                "ip": self.server.lan_ip,
                "count": len(self.server.files_meta),
                "total_size": sum(item["size"] for item in self.server.files_meta),
                "files": public_files
            }
            body = json.dumps(status_data, indent=2).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            if need_cookie:
                self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax; HttpOnly")
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

    def _estimate_tree_size(self, root, budget=8 * 1024 * 1024 * 1024):
        """Sum regular-file sizes under root, giving up once budget is exceeded.

        Used to refuse a bundle we already know cannot fit on the temp
        filesystem, instead of discovering it halfway through a multi-hour deflate.
        """
        total = 0
        try:
            for fp, _ in iter_share_files(root):
                try:
                    total += os.path.getsize(fp)
                except OSError:
                    continue
                if total > budget:
                    return total
        except OSError:
            pass
        return total

    def _temp_zip_ready(self, estimated_bytes, target_dir=None):
        """Verify free space for a ZIP before creating it; return bool."""
        where = target_dir or tempfile.gettempdir()
        try:
            free = shutil.disk_usage(where).free
        except OSError:
            return False
        # ZIP_DEFLATED on already-compressed media barely shrinks, so budget the
        # full estimated size plus a 256 MB margin rather than assuming a ratio.
        return free > estimated_bytes + DISK_SPACE_MARGIN_BYTES

    def _safe_temp_suffix(self, name):
        """Build a bounded, path-separator-free tempfile suffix from a name."""
        cleaned = "".join(c if (c.isalnum() or c in "._-") else "_" for c in name)
        cleaned = cleaned.strip("._")[:40] or "folder"
        return f"_{cleaned}.zip"

    def send_folder_zip(self, folder_path, folder_name, send_body=True):
        """Bundle a folder recursively into a ZIP archive and stream to client."""
        client_ip = self.client_address[0]
        temp_zip = self.server.folder_zip_cache.get(folder_path)
        if not temp_zip or not os.path.exists(temp_zip):
            estimated = self._estimate_tree_size(folder_path)
            if not self._temp_zip_ready(estimated):
                self.send_error(507, "Insufficient disk space to build folder archive")
                return
            emit_event({"event": "zipping", "client": client_ip, "folder": folder_name})
            # #12: the folder name is host-controlled but may still contain
            # separators, NULs, or exceed NAME_MAX; sanitize before it becomes
            # part of a temp path.
            tf = tempfile.NamedTemporaryFile(delete=False, suffix=self._safe_temp_suffix(folder_name))
            temp_zip = tf.name
            tf.close()
            parent_dir = os.path.dirname(os.path.abspath(folder_path))
            try:
                with zipfile.ZipFile(temp_zip, "w", zipfile.ZIP_DEFLATED) as zf:
                    # iter_share_files skips symlinks and cannot escape folder_path.
                    for fp, _ in iter_share_files(folder_path):
                        rel_path = os.path.relpath(fp, parent_dir)
                        try:
                            zf.write(fp, arcname=rel_path)
                        except Exception:
                            pass
            except Exception:
                try:
                    os.unlink(temp_zip)
                except OSError:
                    pass
                self.send_error(500, "Failed to build folder archive")
                return
            self.server.cache_folder_zip(folder_path, temp_zip)

        self.send_file(temp_zip, f"{folder_name}.zip", force_download=True, send_body=send_body, is_bundle=True)

    def send_zip_bundle(self, send_body=True):
        """Create or reuse single-file ZIP archive containing all shared files and folders."""
        client_ip = self.client_address[0]
        # The cache check, the build and the publish have to be atomic. Two
        # concurrent /bundle requests could both observe an empty cache and both
        # start building; the second one's _discard_zip_cache() then unlinked the
        # archive the first was still writing, so the first sent a truncated (or
        # entirely missing) zip with a 200, and the finished archive was
        # orphaned. zip_cache_lock only covered cache_folder_zip() before.
        #
        # Holding it across the build is what makes the cache correct: a second
        # request blocks, then finds the finished archive and reuses it. The lock
        # is released before send_file() streams the bytes, since reading a
        # completed archive needs no exclusive access.
        with self.server.zip_cache_lock:
            if not self.server.zip_cache_path or not os.path.exists(self.server.zip_cache_path):
                estimated = 0
                for item in self.server.files_meta:
                    ipath = item["path"]
                    if item.get("is_dir"):
                        estimated += self._estimate_tree_size(ipath)
                    else:
                        try:
                            estimated += os.path.getsize(ipath)
                        except OSError:
                            pass
                if not self._temp_zip_ready(estimated):
                    self.send_error(507, "Insufficient disk space to build archive")
                    return

                emit_event({"event": "zipping", "client": client_ip, "count": len(self.server.files_meta)})
                # A second /bundle request overwrites zip_cache_path, and
                # server_close() only unlinks the *latest* one, so every repeat
                # request orphaned a full archive in the system temp directory for
                # the life of the session. Retire the previous archive first.
                self.server._discard_zip_cache()
                tf = tempfile.NamedTemporaryFile(delete=False, suffix="_ReClip-Files.zip")
                self.server.zip_cache_path = tf.name
                tf.close()

                try:
                    with zipfile.ZipFile(self.server.zip_cache_path, "w", zipfile.ZIP_DEFLATED) as zf:
                        for item in self.server.files_meta:
                            ipath = item["path"]
                            if item.get("is_dir"):
                                parent_dir = os.path.dirname(os.path.abspath(ipath))
                                for fp, _ in iter_share_files(ipath):
                                    rel_path = os.path.relpath(fp, parent_dir)
                                    try:
                                        zf.write(fp, arcname=rel_path)
                                    except Exception:
                                        pass
                            else:
                                # A shared *file* is itself a legitimate symlink target
                                # chosen by the user, so it is resolved and bundled
                                # directly rather than skipped.
                                if os.path.exists(ipath):
                                    zf.write(ipath, arcname=item["name"])
                except Exception:
                    try:
                        os.unlink(self.server.zip_cache_path)
                    except OSError:
                        pass
                    self.server.zip_cache_path = None
                    self.send_error(500, "Failed to build archive")
                    return

            path = self.server.zip_cache_path

        # Outside the lock: the archive is complete and immutable, so several
        # clients can stream it concurrently.
        self.send_file(path, "ReClip-Files.zip", force_download=True, send_body=send_body, is_bundle=True)

    def _send_range_not_satisfiable(self, file_size):
        """Emit 416 with the mandatory Content-Range: bytes */<size>."""
        try:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{file_size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
        except Exception:
            pass

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

        # RFC 7233 Range header -- single range only, per §3.1.
        range_header = self.headers.get("Range")
        start = 0
        end = file_size - 1
        status_code = 200

        if range_header:
            spec = range_header.split("=", 1)
            if len(spec) != 2 or spec[0].strip().lower() != "bytes":
                self._send_range_not_satisfiable(file_size)
                return
            raw_range = spec[1].strip()
            # Multi-range requests are answered with the whole entity rather
            # than a multipart/byteranges body, which is explicitly permitted.
            if "," in raw_range:
                pass
            else:
                bounds = raw_range.split("-")
                if len(bounds) != 2:
                    self._send_range_not_satisfiable(file_size)
                    return
                first, last = bounds[0].strip(), bounds[1].strip()
                try:
                    if not first:
                        # Suffix range: last N bytes.
                        if not last:
                            raise ValueError("empty suffix range")
                        suffix = int(last)
                        if suffix <= 0:
                            self._send_range_not_satisfiable(file_size)
                            return
                        start = max(0, file_size - suffix)
                        end = file_size - 1
                    else:
                        start = int(first)
                        end = int(last) if last else file_size - 1
                except ValueError:
                    self._send_range_not_satisfiable(file_size)
                    return
                # Unsatisfiable per RFC 7233 §2.1: reject rather than silently
                # clamp, otherwise a client asking for 500-100 gets the wrong
                # bytes with a 206 and silently corrupts its file.
                if start >= file_size or end < start:
                    self._send_range_not_satisfiable(file_size)
                    return
                end = min(end, file_size - 1)
                status_code = 206

        content_length = (end - start) + 1

        try:
            self.send_response(status_code)
            self.send_header("Content-Type", mime_type)
            self.send_header("Content-Length", str(content_length))
            disposition = "attachment" if force_download else "inline"
            self.send_header("Content-Disposition", content_disposition_value(disposition, download_name))
            if not force_download:
                # Inline previews render user-supplied content inside the ReClip
                # origin. Without this, a shared .html/.svg file is stored XSS:
                # its script can fetch the portal, read the CSRF token out of
                # the DOM, and fire authenticated POSTs with the session cookie.
                # `sandbox` with no tokens means an opaque origin and no script
                # execution, while images/video/PDF still preview fine.
                self.send_header("Content-Security-Policy", "sandbox")
            self.send_header("X-Frame-Options", "DENY")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Connection", "close")
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
                # Guard the shared counters so concurrent downloads cannot lose
                # increments or observe a torn single-shot completion state.
                with self.server.state_lock:
                    self.server.download_count += 1
                    if self.server.single_shot and force_download:
                        if len(self.server.files_meta) == 1 or is_bundle:
                            self.server.download_completed = True
                            self.server.completion_time = time.time()
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
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
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
                if cat == "image":
                    # Images open in the in-page lightbox. Tapping through to a
                    # new tab loses the session context on mobile and costs a
                    # back-navigation for something the user can just look at.
                    # The src/name travel as data attributes rather than as an
                    # inline onclick: a filename containing a quote or an angle
                    # bracket would otherwise terminate the attribute and leave
                    # a syntax error behind.
                    preview_btn = f'''<button type="button" class="btn btn-secondary btn-sm js-preview-image" data-src="/preview/{enc_name}" data-name="{html.escape(name, quote=True)}" title="Open Preview">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
                </button>'''
                else:
                    preview_btn = f'''<a href="/preview/{enc_name}" target="_blank" rel="noopener" class="btn btn-secondary btn-sm" title="Open Preview">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
                </a>'''
                dl_action = f"/download/{enc_name}"
                dl_text = "Download"

            card = f'''
            <div class="file-card" data-cat="{cat}" data-name="{html.escape(name, quote=True)}">
              <div class="card-top">
                <div class="file-icon-wrap">{svg_icon}</div>
                <div class="card-info">
                  <div class="card-name" title="{html.escape(name, quote=True)}">{html.escape(name)}</div>
                  <div class="card-meta-row">
                    <span class="badge" style="background:{badge_color}22; color:{badge_color}; border:1px solid {badge_color}44;">{cat_label}</span>
                    <span>{meta_label}</span>
                  </div>
                </div>
              </div>
              <div class="card-bottom">
                <a href="{dl_action}" class="btn btn-primary btn-sm btn-dl" download>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                  <span class="dl-label">{dl_text}</span>
                </a>
                {preview_btn}
              </div>
              <div class="card-dl-status"></div>
            </div>
            '''
            cards_html.append(card)

        # Chips
        chip_order = ['folder', 'image', 'video', 'audio', 'archive', 'document', 'code', 'text', 'other']
        chips_html = ['<button type="button" class="filter-chip active" data-cat="all" aria-pressed="true" onclick="filterCategory(\'all\', this)">All</button>']
        for c in chip_order:
            if c in categories_present:
                lbl, _, _ = get_category_badge_info(c)
                chips_html.append(f'<button type="button" class="filter-chip" data-cat="{c}" aria-pressed="false" onclick="filterCategory(\'{c}\', this)">{lbl}</button>')

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
            reverse_drop_section_html = f"""    <!-- P1: Reverse Drop Section -->
    <section class="section-card" id="reverse-drop">
      <div class="section-header">
        <div class="section-icon-box">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
          </svg>
        </div>
        <div>
          <h2 class="section-title">Reverse Drop &middot; Send to PC</h2>
          <p class="section-desc">Drop or select files from your phone to send directly to <code>{html.escape(self.server.save_dir)}</code> on PC</p>
        </div>
      </div>

      <div class="session-banner" id="session-banner" role="status" aria-live="polite" style="display:none"></div>

      <div class="dropzone" id="dropzone" role="button" tabindex="0"
           aria-label="Choose files to send to the PC"
           aria-describedby="dropzone-sub"
           onclick="document.getElementById('file-input').click()">
        <input type="file" id="file-input" multiple style="display:none" onchange="handleFilesSelected(this.files)">
        <div class="dropzone-icon">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>
          </svg>
        </div>
        <div class="dropzone-prompt">Tap to choose photos, videos, or files</div>
        <div class="dropzone-sub" id="dropzone-sub">Files transfer locally at maximum Wi-Fi speed &middot; Zero cloud storage</div>
      </div>

      <div class="queue-summary" id="queue-summary" hidden>
        <span class="queue-summary-title" id="queue-summary-title"></span>
        <button type="button" class="queue-clear" id="queue-clear">Clear finished</button>
      </div>

      <div class="upload-queue" id="upload-queue" role="status" aria-live="polite" aria-relevant="additions text"></div>
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
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>{html.escape(page_title)}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <meta name="reclip-csrf" content="{self.server.csrf_token()}">
  <meta name="reclip-max-upload-size" content="{self.server.max_upload_size}">
  <meta name="reclip-max-session-quota" content="{self.server.max_session_upload_quota}">
  <meta name="reclip-session-used" content="{self.server.session_uploaded_bytes}">
  <meta name="reclip-single-shot" content="{'1' if self.server.single_shot else '0'}">
  <meta name="reclip-max-concurrent-uploads" content="2">
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
        <span class="nav-pin-badge" title="LAN session active">&#128274; PIN verified</span>
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
          <label class="sr-only" for="search-input">Filter shared files by name</label>
          <span class="search-icon">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
          </span>
          <input type="text" id="search-input" class="search-input" placeholder="Filter files..." autocomplete="off" oninput="onSearchInput(this.value)">
          <button type="button" class="search-clear" aria-label="Clear filter">&times;</button>
        </div>
        <div class="chip-group" role="group" aria-label="Filter by file type">
          {''.join(chips_html)}
        </div>
        <span class="sr-only" id="result-count" role="status" aria-live="polite"></span>
      </div>

      <div class="file-grid" id="file-grid">
        {''.join(cards_html)}
      </div>

      <div class="no-results" id="no-results">
        <div class="no-results-icon" aria-hidden="true">&#128269;</div>
        <div class="no-results-title">No matching files</div>
        <div class="no-results-hint" id="no-results-hint"></div>
        <button type="button" class="btn btn-secondary btn-sm no-results-clear" id="no-results-clear">Clear filters</button>
      </div>
    </section>

  </main>

  <!-- Lightbox Modal. The close handler is on the backdrop rather than the
       container so a tap on the image itself does not dismiss the viewer. -->
  <div class="lightbox" id="lightbox" role="dialog" aria-modal="true" aria-label="Image preview" hidden style="display:none;" onclick="if (event.target === this) closeLightbox();">
    <button type="button" class="lightbox-close" id="lightbox-close" aria-label="Close preview" onclick="closeLightbox();">&times;</button>
    <img src="" alt="" class="lightbox-content" id="lightbox-img" onclick="event.stopPropagation();">
    <div class="lightbox-caption" id="lightbox-caption" style="display:none;"></div>
  </div>

  <!-- Toast Notification Box -->
  <div class="toast-box" id="toast" role="status" aria-live="polite"></div>

  <script>
{PORTAL_JS}
  </script>
</body>
</html>'''

        data = html_content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        if need_cookie:
            self.send_header("Set-Cookie", f"reclip_auth={self.server.token}; Path=/; Max-Age=86400; SameSite=Lax; HttpOnly")
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
    parser.add_argument("--timeout", type=int, default=DEFAULT_SERVER_TIMEOUT_SEC, help="Server timeout in seconds (default: 1800s)")
    parser.add_argument("--token", type=str, default=None, help="Security session token")
    parser.add_argument("--pin", type=str, default=None, help="6-digit quick PIN")
    parser.add_argument("--save-dir", type=str, default=None, help="Directory to save reverse drop uploads")

    args = parser.parse_args()

    # Scan paths (support files and recursive directories - P5)
    files_meta = []
    used_names = set()

    for idx, path_arg in enumerate(args.files):
        abs_p = os.path.abspath(path_arg)
        if not os.path.exists(abs_p):
            continue

        if os.path.isdir(abs_p):
            file_count = 0
            dir_size = 0
            # Symlink-safe so a planted link cannot inflate the advertised size
            # or drag an unrelated subtree into the count.
            for fp, _ in iter_share_files(abs_p):
                try:
                    dir_size += os.path.getsize(fp)
                    file_count += 1
                except OSError:
                    pass
            bname = unique_display_name(os.path.basename(abs_p.rstrip("/")), used_names)
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
            bname = unique_display_name(os.path.basename(abs_p), used_names)
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
    # Two problems with the original loop:
    #  1. handle_request() blocks forever when no client is connected and no
    #     socket timeout is set, so the --timeout deadline was never reached
    #     on an idle server. Poll instead: each wake-up re-checks it.
    #  2. SIGTERM (how the QML stops a share) killed the process outright, so
    #     the finally-block cleanup never ran. Route it through should_stop.
    httpd.timeout = 1.0

    def _request_stop(signum, frame):
        httpd.should_stop = True

    try:
        signal.signal(signal.SIGTERM, _request_stop)
    except (ValueError, OSError):
        pass
    try:
        while not httpd.should_stop:
            httpd.handle_request()
            if time.time() - start_time > args.timeout:
                emit_event({"event": "timeout", "message": f"Server timed out after {args.timeout}s"})
                break
            # Read the completion pair atomically. The handler thread writes
            # download_completed before completion_time, so an unlocked read
            # could observe completed=True against a stale completion_time and
            # exit immediately, cutting off the 3s window the writer intends.
            with httpd.state_lock:
                completed = httpd.download_completed
                completed_at = httpd.completion_time
            if completed and (time.time() - completed_at > 3.0):
                emit_event({"event": "completed_exit"})
                break
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
        emit_event({"event": "stopped"})

if __name__ == "__main__":
    main()
