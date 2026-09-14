#!/usr/bin/env python3
"""
qr_styler.py - Advanced Multi-Part QR Code Generator, Styler & Vector Engine for ReClip Omarchy

Features:
- Position Markers / Finder Patterns (Outer Eye & Inner Eye styling: Square, Rounded, Circle, Squircle)
- Module shapes (Square, Rounded, Dots, Fluid/Connected)
- Dynamic Gradients (Linear Horizontal, Vertical, Diagonal, Radial)
- "SCAN ME" Card Frames & Banners with Dual-Text (Main CTA + Subtitle) and adjustable corner radius
- Comprehensive Center Logo Studio:
  - Shapes: Circle, Squircle/Rounded, Square, Floating/Borderless
  - Scales: 16% (Compact), 22% (Standard), 28% (Prominent), 32% (Max Safe)
  - Colors: Badge Fill, Badge Border color & width, Inner padding, Icon tinting
  - 15 Built-in Vector Preset Icons (Dev, Connectivity, Commerce/Life)
  - System pixmaps & custom image support
- Scalable SVG Vector Export with embedded badges, icons, and base64 images
- Auto-adjusted Error Correction (boosts to Level H when logo is active)
- Quiet Zone margin (0, 1, 2, 4 modules)
"""

import sys
import os
import io
import json
import math
import base64
import subprocess
import shutil
import xml.sax.saxutils as saxutils
from PIL import Image, ImageDraw, ImageFont

ALIGNMENT_TABLE = {
    1: [],
    2: [6, 18],
    3: [6, 22],
    4: [6, 26],
    5: [6, 30],
    6: [6, 34],
    7: [6, 22, 38],
    8: [6, 24, 42],
    9: [6, 26, 46],
    10: [6, 28, 50],
    11: [6, 30, 54],
    12: [6, 32, 58],
    13: [6, 34, 62],
    14: [6, 26, 46, 66],
    15: [6, 26, 48, 70],
    16: [6, 26, 50, 74],
    17: [6, 30, 54, 78],
    18: [6, 30, 56, 82],
    19: [6, 30, 58, 86],
    20: [6, 34, 62, 90],
    21: [6, 28, 50, 72, 94],
    22: [6, 26, 50, 74, 98],
    23: [6, 30, 54, 78, 102],
    24: [6, 28, 54, 80, 106],
    25: [6, 32, 58, 84, 110],
    26: [6, 30, 58, 86, 114],
    27: [6, 34, 62, 90, 118],
    28: [6, 26, 50, 74, 98, 122],
    29: [6, 30, 54, 78, 102, 126],
    30: [6, 26, 52, 78, 104, 130],
    31: [6, 30, 56, 82, 108, 134],
    32: [6, 34, 60, 86, 112, 138],
    33: [6, 30, 58, 86, 114, 142],
    34: [6, 34, 62, 90, 118, 146],
    35: [6, 30, 54, 78, 102, 126, 150],
    36: [6, 24, 50, 76, 102, 128, 154],
    37: [6, 28, 54, 80, 106, 132, 158],
    38: [6, 32, 58, 84, 110, 136, 162],
    39: [6, 26, 54, 82, 110, 138, 166],
    40: [6, 30, 58, 86, 114, 142, 170]
}

def parse_color(c, default=(0, 0, 0, 255)):
    if not c:
        return default
    c = str(c).strip().lower()
    if c == "transparent" or c == "#00000000" or c == "rgba(0,0,0,0)":
        return (0, 0, 0, 0)
    if c.startswith("#"):
        c = c[1:]
    if len(c) == 3:
        return (int(c[0]*2, 16), int(c[1]*2, 16), int(c[2]*2, 16), 255)
    if len(c) == 6:
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)
    if len(c) == 8:
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), int(c[6:8], 16))
    return default

def color_to_hex(c):
    if not c or c[3] == 0:
        return "none"
    return f"#{c[0]:02x}{c[1]:02x}{c[2]:02x}"

def get_gradient_color(r, c, N, fg_col, grad_col, grad_type):
    if grad_type == "none" or not grad_col:
        return fg_col
    if grad_type == "linear_horizontal":
        t = c / max(1, N - 1)
    elif grad_type == "linear_vertical":
        t = r / max(1, N - 1)
    elif grad_type == "linear_diagonal":
        t = (r + c) / max(1, 2 * (N - 1))
    elif grad_type == "radial":
        cx, cy = (N - 1) / 2.0, (N - 1) / 2.0
        dist = math.sqrt((r - cx)**2 + (c - cy)**2)
        max_dist = math.sqrt(2 * (cx**2))
        t = min(1.0, dist / max(0.001, max_dist))
    else:
        return fg_col

    r_out = int(fg_col[0] + (grad_col[0] - fg_col[0]) * t)
    g_out = int(fg_col[1] + (grad_col[1] - fg_col[1]) * t)
    b_out = int(fg_col[2] + (grad_col[2] - fg_col[2]) * t)
    a_out = int(fg_col[3] + (grad_col[3] - fg_col[3]) * t)
    return (r_out, g_out, b_out, a_out)

def classify_cell(r, c, N, version):
    # 1. Finder patterns (3 corners)
    for f_r, f_c in [(0, 0), (0, N - 7), (N - 7, 0)]:
        dr = r - f_r
        dc = c - f_c
        if 0 <= dr < 7 and 0 <= dc < 7:
            if dr == 0 or dr == 6 or dc == 0 or dc == 6:
                return "finder_outer"
            if dr == 1 or dr == 5 or dc == 1 or dc == 5:
                return "finder_sep"
            return "finder_inner"

    # 2. Timing patterns: row 6 or col 6 between 8 and N-9
    if (r == 6 and 8 <= c <= N - 9) or (c == 6 and 8 <= r <= N - 9):
        return "timing"

    # 3. Alignment patterns (version >= 2)
    coords = ALIGNMENT_TABLE.get(version, [])
    for ar in coords:
        for ac in coords:
            if ar <= 8 and ac <= 8:
                continue
            if ar <= 8 and ac >= N - 9:
                continue
            if ar >= N - 9 and ac <= 8:
                continue
            dr = abs(r - ar)
            dc = abs(c - ac)
            if dr <= 2 and dc <= 2:
                if dr == 2 or dc == 2:
                    return "alignment_outer"
                if dr == 1 or dc == 1:
                    return "alignment_sep"
                return "alignment_inner"

    return "data"

def draw_preset_icon(draw, icon_name, cx, cy, size, fg_col):
    """Draw clean vector preset icons in center badge."""
    half = size / 2.0
    lw = max(2, int(size * 0.10))

    if icon_name == "star":
        pts = []
        r_out = half * 0.95
        r_in = half * 0.42
        for i in range(10):
            ang = i * math.pi / 5.0 - math.pi / 2.0
            r = r_out if i % 2 == 0 else r_in
            pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
        draw.polygon(pts, fill=fg_col)
    elif icon_name == "heart":
        r = half * 0.48
        draw.ellipse([cx - half * 0.9, cy - half * 0.7, cx - half * 0.9 + 2*r, cy - half * 0.7 + 2*r], fill=fg_col)
        draw.ellipse([cx + half * 0.9 - 2*r, cy - half * 0.7, cx + half * 0.9, cy - half * 0.7 + 2*r], fill=fg_col)
        draw.polygon([(cx - half * 0.85, cy - half * 0.2), (cx + half * 0.85, cy - half * 0.2), (cx, cy + half * 0.9)], fill=fg_col)
    elif icon_name == "wifi":
        draw.arc([cx - half*0.9, cy - half*0.8, cx + half*0.9, cy + half*1.0], start=210, end=330, fill=fg_col, width=lw)
        draw.arc([cx - half*0.55, cy - half*0.45, cx + half*0.55, cy + half*0.65], start=210, end=330, fill=fg_col, width=lw)
        draw.ellipse([cx - lw*1.2, cy + half*0.4 - lw*1.2, cx + lw*1.2, cy + half*0.4 + lw*1.2], fill=fg_col)
    elif icon_name == "link":
        w = int(size * 0.65)
        h = int(size * 0.35)
        draw.rounded_rectangle([cx - w//2, cy - h//2, cx + w//2, cy + h//2], radius=h//2, outline=fg_col, width=lw)
        draw.line([cx - w//4, cy, cx + w//4, cy], fill=fg_col, width=lw)
    elif icon_name == "code":
        draw.line([cx - half*0.6, cy, cx - half*0.2, cy - half*0.5], fill=fg_col, width=lw)
        draw.line([cx - half*0.6, cy, cx - half*0.2, cy + half*0.5], fill=fg_col, width=lw)
        draw.line([cx - half*0.1, cy + half*0.6, cx + half*0.1, cy - half*0.6], fill=fg_col, width=lw)
        draw.line([cx + half*0.6, cy, cx + half*0.2, cy - half*0.5], fill=fg_col, width=lw)
        draw.line([cx + half*0.6, cy, cx + half*0.2, cy + half*0.5], fill=fg_col, width=lw)
    elif icon_name == "terminal":
        draw.line([cx - half*0.7, cy - half*0.4, cx - half*0.2, cy - half*0.1], fill=fg_col, width=lw)
        draw.line([cx - half*0.7, cy + half*0.2, cx - half*0.2, cy - half*0.1], fill=fg_col, width=lw)
        draw.line([cx, cy + half*0.25, cx + half*0.7, cy + half*0.25], fill=fg_col, width=lw)
    elif icon_name == "phone":
        pw = int(size * 0.45)
        ph = int(size * 0.75)
        plw = max(2, int(size * 0.08))
        draw.rounded_rectangle([cx - pw//2, cy - ph//2, cx + pw//2, cy + ph//2], radius=int(pw * 0.25), outline=fg_col, width=plw)
        draw.ellipse([cx - 2, cy + ph//2 - int(ph * 0.15) - 2, cx + 2, cy + ph//2 - int(ph * 0.15) + 2], fill=fg_col)
    elif icon_name == "email":
        ew = int(size * 0.75)
        eh = int(size * 0.50)
        draw.rectangle([cx - ew//2, cy - eh//2, cx + ew//2, cy + eh//2], outline=fg_col, width=lw)
        draw.line([cx - ew//2, cy - eh//2, cx, cy], fill=fg_col, width=lw)
        draw.line([cx + ew//2, cy - eh//2, cx, cy], fill=fg_col, width=lw)
    elif icon_name == "lock":
        bw = int(size * 0.55)
        bh = int(size * 0.45)
        by = cy - bh//2 + int(size * 0.12)
        sw = int(size * 0.35)
        sh = int(size * 0.35)
        draw.rounded_rectangle([cx - sw//2, by - sh + 2, cx + sw//2, by + 4], radius=sw//2, outline=fg_col, width=lw)
        draw.rectangle([cx - bw//2, by, cx + bw//2, by + bh], fill=fg_col)
        draw.ellipse([cx - lw, by + bh//3 - lw, cx + lw, by + bh//3 + lw], fill=(255, 255, 255, 255))
    elif icon_name == "cart":
        draw.line([cx - half*0.7, cy - half*0.4, cx - half*0.5, cy - half*0.4], fill=fg_col, width=lw)
        draw.line([cx - half*0.5, cy - half*0.4, cx - half*0.3, cy + half*0.2], fill=fg_col, width=lw)
        draw.line([cx - half*0.3, cy + half*0.2, cx + half*0.5, cy + half*0.2], fill=fg_col, width=lw)
        draw.line([cx + half*0.5, cy + half*0.2, cx + half*0.6, cy - half*0.3], fill=fg_col, width=lw)
        draw.line([cx + half*0.6, cy - half*0.3, cx - half*0.45, cy - half*0.3], fill=fg_col, width=lw)
        wr = max(2, int(size * 0.08))
        draw.ellipse([cx - half*0.2 - wr, cy + half*0.45 - wr, cx - half*0.2 + wr, cy + half*0.45 + wr], fill=fg_col)
        draw.ellipse([cx + half*0.4 - wr, cy + half*0.45 - wr, cx + half*0.4 + wr, cy + half*0.45 + wr], fill=fg_col)
    elif icon_name == "location":
        pr = half * 0.45
        py = cy - half * 0.25
        draw.ellipse([cx - pr, py - pr, cx + pr, py + pr], fill=fg_col)
        draw.polygon([(cx - pr*0.9, py), (cx + pr*0.9, py), (cx, cy + half*0.8)], fill=fg_col)
        draw.ellipse([cx - pr*0.4, py - pr*0.4, cx + pr*0.4, py + pr*0.4], fill=(255, 255, 255, 255))
    elif icon_name == "crypto":
        pts = [(cx, cy - half*0.85), (cx + half*0.65, cy), (cx, cy + half*0.85), (cx - half*0.65, cy)]
        draw.polygon(pts, outline=fg_col)
        draw.line([cx - half*0.65, cy, cx + half*0.65, cy], fill=fg_col, width=lw)
        draw.line([cx, cy - half*0.85, cx, cy + half*0.85], fill=fg_col, width=lw)
    elif icon_name == "arch":
        pts = [(cx, cy - half*0.85), (cx + half*0.75, cy + half*0.75), (cx, cy + half*0.35), (cx - half*0.75, cy + half*0.75)]
        draw.polygon(pts, fill=fg_col)
    elif icon_name == "github":
        draw.ellipse([cx - half*0.65, cy - half*0.4, cx + half*0.65, cy + half*0.7], fill=fg_col)
        draw.polygon([(cx - half*0.6, cy - half*0.1), (cx - half*0.7, cy - half*0.7), (cx - half*0.2, cy - half*0.4)], fill=fg_col)
        draw.polygon([(cx + half*0.6, cy - half*0.1), (cx + half*0.7, cy - half*0.7), (cx + half*0.2, cy - half*0.4)], fill=fg_col)
    elif icon_name == "omarchy":
        draw.ellipse([cx - half*0.75, cy - half*0.75, cx + half*0.75, cy + half*0.75], outline=fg_col, width=lw)
        draw.line([cx, cy - half*0.5, cx, cy + half*0.5], fill=fg_col, width=lw)
        draw.line([cx - half*0.4, cy, cx + half*0.4, cy], fill=fg_col, width=lw)
    else:
        draw.ellipse([cx - half*0.6, cy - half*0.6, cx + half*0.6, cy + half*0.6], fill=fg_col)

def load_system_font(size, bold=True):
    paths = [
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/noto/NotoSans-Bold.ttf" if bold else "/usr/share/fonts/noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/TTF/OpenSans-Bold.ttf" if bold else "/usr/share/fonts/TTF/OpenSans-Regular.ttf"
    ]
    for p in paths:
        if os.path.isfile(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()

def generate_svg(matrix, N, S, W, quiet_zone, detected_version, config):
    """Generate clean, scalable XML SVG vector representation."""
    fg_col = parse_color(config.get("fg_color", "#000000"))
    bg_col = parse_color(config.get("bg_color", "#FFFFFF"))
    outer_eye_col = parse_color(config.get("outer_eye_color"), fg_col)
    inner_eye_col = parse_color(config.get("inner_eye_color"), fg_col)
    timing_col = parse_color(config.get("timing_color"), fg_col)
    alignment_col = parse_color(config.get("alignment_color"), fg_col)
    module_shape = config.get("module_shape", "square").lower()
    eye_shape = config.get("eye_shape", "square").lower()
    grad_type = config.get("gradient_type", "none").lower()
    grad_col = parse_color(config.get("gradient_color"), fg_col) if grad_type != "none" else None

    # Card Frame
    frame_style = config.get("frame_style", "none").lower()
    frame_text = config.get("frame_text", "SCAN ME").strip()
    frame_subtext = config.get("frame_subtext", "").strip()
    frame_radius = int(config.get("frame_radius", 0))
    frame_col = parse_color(config.get("frame_color"), fg_col)
    frame_txt_col = parse_color(config.get("frame_text_color", "#FFFFFF"))

    # Logo Setup
    logo_preset = config.get("logo_preset", "none").lower()
    logo_path = config.get("logo_path", "").strip()
    if logo_preset == "none":
        has_logo = False
    elif logo_preset == "custom":
        has_logo = bool(logo_path) and os.path.isfile(logo_path)
    else:
        has_logo = True
    logo_shape = config.get("logo_shape", "rounded").lower()
    try:
        logo_size_scale = float(config.get("logo_size", 0.22))
    except Exception:
        logo_size_scale = 0.22
    logo_bg_col = parse_color(config.get("logo_bg_color"), (255, 255, 255, 255) if bg_col[3] == 0 else bg_col)
    logo_border_col = parse_color(config.get("logo_border_color"), outer_eye_col)
    logo_border_w = int(config.get("logo_border_width", 2))
    logo_padding_ratio = float(config.get("logo_padding", 0.70))
    logo_tint_col = parse_color(config.get("logo_tint_color"), fg_col)

    total_w = W
    total_h = W
    qr_x_offset = 0
    qr_y_offset = 0
    banner_y = 0
    banner_h = 0
    pad = 0

    if frame_style in ["bottom_banner", "top_banner", "framed_card"]:
        banner_h = max(45, int(W * 0.16)) if frame_subtext else max(40, int(W * 0.14))
        pad = max(16, int(W * 0.05))
        total_w = W + 2 * pad
        total_h = W + 2 * pad + banner_h
        if frame_style == "top_banner":
            qr_y_offset = pad + banner_h
            banner_y = pad // 2
        else:
            qr_y_offset = pad
            banner_y = W + pad + int(pad * 0.2)
        qr_x_offset = pad

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_w} {total_h}" width="{total_w}" height="{total_h}">'
    ]

    # Overall Background
    scaled_frame_radius = max(0, int(frame_radius * (W / 600.0)))
    if bg_col[3] > 0:
        if scaled_frame_radius > 0:
            lines.append(f'  <rect width="100%" height="100%" rx="{scaled_frame_radius}" fill="{color_to_hex(bg_col)}"/>')
        else:
            lines.append(f'  <rect width="100%" height="100%" fill="{color_to_hex(bg_col)}"/>')

    # Modules
    for r in range(N):
        for c in range(N):
            is_finder = (r < 7 and c < 7) or (r < 7 and c >= N - 7) or (r >= N - 7 and c < 7)
            if is_finder:
                continue

            if matrix[r][c] == 1:
                part = classify_cell(r, c, N, detected_version)
                if part == "timing":
                    col = color_to_hex(timing_col)
                elif part.startswith("alignment"):
                    col = color_to_hex(alignment_col)
                else:
                    col = color_to_hex(get_gradient_color(r, c, N, fg_col, grad_col, grad_type))

                x0 = qr_x_offset + (c + quiet_zone) * S
                y0 = qr_y_offset + (r + quiet_zone) * S

                if module_shape in ["dot", "circle"]:
                    cx = x0 + S / 2.0
                    cy = y0 + S / 2.0
                    rad = (S - max(1, S // 8)) / 2.0
                    lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{rad}" fill="{col}"/>')
                elif module_shape in ["rounded", "fluid"]:
                    rad = max(2, S // 3)
                    lines.append(f'  <rect x="{x0}" y="{y0}" width="{S}" height="{S}" rx="{rad}" fill="{col}"/>')
                else:
                    lines.append(f'  <rect x="{x0}" y="{y0}" width="{S}" height="{S}" fill="{col}"/>')

    # Finder Patterns
    finder_corners = [(0, 0), (0, N - 7), (N - 7, 0)]
    for fr, fc in finder_corners:
        x0 = qr_x_offset + (fc + quiet_zone) * S
        y0 = qr_y_offset + (fr + quiet_zone) * S
        outer_w = 7 * S
        outer_col = color_to_hex(outer_eye_col)
        inner_col = color_to_hex(inner_eye_col)
        bg_hex = color_to_hex(bg_col) if bg_col[3] > 0 else "#ffffff"

        if eye_shape in ["circle", "bullseye"]:
            cx = x0 + 3.5 * S
            cy = y0 + 3.5 * S
            lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{3.5*S}" fill="{outer_col}"/>')
            lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{2.5*S}" fill="{bg_hex}"/>')
            lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{1.5*S}" fill="{inner_col}"/>')
        elif eye_shape == "squircle":
            rad_out = int(S * 2.4)
            rad_sep = int(S * 1.6)
            rad_in = int(S * 1.1)
            lines.append(f'  <rect x="{x0}" y="{y0}" width="{outer_w}" height="{outer_w}" rx="{rad_out}" fill="{outer_col}"/>')
            lines.append(f'  <rect x="{x0+S}" y="{y0+S}" width="{5*S}" height="{5*S}" rx="{rad_sep}" fill="{bg_hex}"/>')
            lines.append(f'  <rect x="{x0+2*S}" y="{y0+2*S}" width="{3*S}" height="{3*S}" rx="{rad_in}" fill="{inner_col}"/>')
        elif eye_shape == "rounded":
            rad_out = int(S * 1.6)
            rad_sep = int(S * 1.1)
            rad_in = int(S * 0.8)
            lines.append(f'  <rect x="{x0}" y="{y0}" width="{outer_w}" height="{outer_w}" rx="{rad_out}" fill="{outer_col}"/>')
            lines.append(f'  <rect x="{x0+S}" y="{y0+S}" width="{5*S}" height="{5*S}" rx="{rad_sep}" fill="{bg_hex}"/>')
            lines.append(f'  <rect x="{x0+2*S}" y="{y0+2*S}" width="{3*S}" height="{3*S}" rx="{rad_in}" fill="{inner_col}"/>')
        else:
            lines.append(f'  <rect x="{x0}" y="{y0}" width="{outer_w}" height="{outer_w}" fill="{outer_col}"/>')
            lines.append(f'  <rect x="{x0+S}" y="{y0+S}" width="{5*S}" height="{5*S}" fill="{bg_hex}"/>')
            lines.append(f'  <rect x="{x0+2*S}" y="{y0+2*S}" width="{3*S}" height="{3*S}" fill="{inner_col}"/>')

    # Center Logo Embedding in SVG
    if has_logo:
        badge_w = int(W * logo_size_scale)
        cx = qr_x_offset + W / 2.0
        cy = qr_y_offset + W / 2.0
        bx0 = cx - badge_w / 2.0
        by0 = cy - badge_w / 2.0
        badge_bg_hex = color_to_hex(logo_bg_col)
        badge_brd_hex = color_to_hex(logo_border_col)

        # Badge Outline / Container
        if logo_shape not in ["floating", "borderless"]:
            if logo_shape == "circle":
                lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{badge_w/2.0}" fill="{badge_bg_hex}" stroke="{badge_brd_hex}" stroke-width="{logo_border_w}"/>')
            elif logo_shape == "square":
                lines.append(f'  <rect x="{bx0}" y="{by0}" width="{badge_w}" height="{badge_w}" fill="{badge_bg_hex}" stroke="{badge_brd_hex}" stroke-width="{logo_border_w}"/>')
            else: # rounded / squircle
                brad = int(badge_w * 0.28)
                lines.append(f'  <rect x="{bx0}" y="{by0}" width="{badge_w}" height="{badge_w}" rx="{brad}" fill="{badge_bg_hex}" stroke="{badge_brd_hex}" stroke-width="{logo_border_w}"/>')

        # Icon or Image content
        icon_dim = int(badge_w * logo_padding_ratio)
        ix0 = cx - icon_dim / 2.0
        iy0 = cy - icon_dim / 2.0

        if logo_preset == "custom":
            if logo_path and os.path.isfile(logo_path):
                try:
                    with open(logo_path, "rb") as img_file:
                        b64_data = base64.b64encode(img_file.read()).decode("ascii")
                        ext = os.path.splitext(logo_path)[1].lower().replace(".", "")
                        mime = f"image/{ext}" if ext in ["png", "jpeg", "jpg", "svg+xml", "webp"] else "image/png"
                        lines.append(f'  <image href="data:{mime};base64,{b64_data}" x="{ix0}" y="{iy0}" width="{icon_dim}" height="{icon_dim}"/>')
                except Exception:
                    pass
        elif logo_preset != "none":
            ic_hex = color_to_hex(logo_tint_col)
            if logo_preset == "star":
                pts = []
                r_out = icon_dim * 0.48
                r_in = icon_dim * 0.21
                for i in range(10):
                    ang = i * math.pi / 5.0 - math.pi / 2.0
                    r = r_out if i % 2 == 0 else r_in
                    pts.append(f"{cx + r * math.cos(ang):.1f},{cy + r * math.sin(ang):.1f}")
                pts_str = " ".join(pts)
                lines.append(f'  <polygon points="{pts_str}" fill="{ic_hex}"/>')
            elif logo_preset == "heart":
                lines.append(f'  <path d="M {cx} {cy + icon_dim*0.35} C {cx - icon_dim*0.5} {cy} {cx - icon_dim*0.5} {cy - icon_dim*0.35} {cx} {cy - icon_dim*0.15} C {cx + icon_dim*0.5} {cy - icon_dim*0.35} {cx + icon_dim*0.5} {cy} {cx} {cy + icon_dim*0.35} Z" fill="{ic_hex}"/>')
            elif logo_preset == "omarchy":
                r = icon_dim * 0.38
                lw = max(2, int(icon_dim * 0.08))
                lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <line x1="{cx}" y1="{cy - r*0.6}" x2="{cx}" y2="{cy + r*0.6}" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <line x1="{cx - r*0.5}" y1="{cy}" x2="{cx + r*0.5}" y2="{cy}" stroke="{ic_hex}" stroke-width="{lw}"/>')
            elif logo_preset == "arch":
                lines.append(f'  <polygon points="{cx},{cy - icon_dim*0.42} {cx + icon_dim*0.38},{cy + icon_dim*0.38} {cx},{cy + icon_dim*0.18} {cx - icon_dim*0.38},{cy + icon_dim*0.38}" fill="{ic_hex}"/>')
            elif logo_preset == "github":
                lines.append(f'  <ellipse cx="{cx}" cy="{cy + icon_dim*0.05}" rx="{icon_dim*0.35}" ry="{icon_dim*0.32}" fill="{ic_hex}"/>')
                lines.append(f'  <polygon points="{cx - icon_dim*0.3},{cy - icon_dim*0.05} {cx - icon_dim*0.35},{cy - icon_dim*0.35} {cx - icon_dim*0.1},{cy - icon_dim*0.2}" fill="{ic_hex}"/>')
                lines.append(f'  <polygon points="{cx + icon_dim*0.3},{cy - icon_dim*0.05} {cx + icon_dim*0.35},{cy - icon_dim*0.35} {cx + icon_dim*0.1},{cy - icon_dim*0.2}" fill="{ic_hex}"/>')
            elif logo_preset == "wifi":
                lw = max(2, int(icon_dim * 0.08))
                lines.append(f'  <circle cx="{cx}" cy="{cy + icon_dim*0.22}" r="{lw*1.2}" fill="{ic_hex}"/>')
                lines.append(f'  <path d="M {cx - icon_dim*0.25} {cy + icon_dim*0.05} A {icon_dim*0.25} {icon_dim*0.25} 0 0 1 {cx + icon_dim*0.25} {cy + icon_dim*0.05}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <path d="M {cx - icon_dim*0.42} {cy - icon_dim*0.12} A {icon_dim*0.42} {icon_dim*0.42} 0 0 1 {cx + icon_dim*0.42} {cy - icon_dim*0.12}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
            elif logo_preset == "code":
                lw = max(2, int(icon_dim * 0.08))
                lines.append(f'  <polyline points="{cx - icon_dim*0.18},{cy - icon_dim*0.25} {cx - icon_dim*0.35},{cy} {cx - icon_dim*0.18},{cy + icon_dim*0.25}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <polyline points="{cx + icon_dim*0.18},{cy - icon_dim*0.25} {cx + icon_dim*0.35},{cy} {cx + icon_dim*0.18},{cy + icon_dim*0.25}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <line x1="{cx + icon_dim*0.08}" y1="{cy - icon_dim*0.3}" x2="{cx - icon_dim*0.08}" y2="{cy + icon_dim*0.3}" stroke="{ic_hex}" stroke-width="{lw}"/>')
            elif logo_preset == "terminal":
                lw = max(2, int(icon_dim * 0.08))
                lines.append(f'  <polyline points="{cx - icon_dim*0.35},{cy - icon_dim*0.2} {cx - icon_dim*0.1},{cy - icon_dim*0.05} {cx - icon_dim*0.35},{cy + icon_dim*0.1}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <line x1="{cx}" y1="{cy + icon_dim*0.1}" x2="{cx + icon_dim*0.35}" y2="{cy + icon_dim*0.1}" stroke="{ic_hex}" stroke-width="{lw}"/>')
            elif logo_preset == "lock":
                bw = icon_dim * 0.55
                bh = icon_dim * 0.45
                lines.append(f'  <rect x="{cx - bw/2.0}" y="{cy - icon_dim*0.05}" width="{bw}" height="{bh}" rx="3" fill="{ic_hex}"/>')
                lines.append(f'  <path d="M {cx - bw*0.3} {cy - icon_dim*0.05} A {bw*0.3} {bw*0.3} 0 0 1 {cx + bw*0.3} {cy - icon_dim*0.05}" fill="none" stroke="{ic_hex}" stroke-width="{max(2, int(icon_dim*0.08))}"/>')
            elif logo_preset == "phone":
                pw = icon_dim * 0.45
                ph = icon_dim * 0.75
                lines.append(f'  <rect x="{cx - pw/2.0}" y="{cy - ph/2.0}" width="{pw}" height="{ph}" rx="{pw*0.2}" fill="none" stroke="{ic_hex}" stroke-width="{max(2, int(icon_dim*0.08))}"/>')
            elif logo_preset == "email":
                ew = icon_dim * 0.75
                eh = icon_dim * 0.50
                lw = max(2, int(icon_dim * 0.08))
                lines.append(f'  <rect x="{cx - ew/2.0}" y="{cy - eh/2.0}" width="{ew}" height="{eh}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
                lines.append(f'  <polyline points="{cx - ew/2.0},{cy - eh/2.0} {cx},{cy} {cx + ew/2.0},{cy - eh/2.0}" fill="none" stroke="{ic_hex}" stroke-width="{lw}"/>')
            else:
                lines.append(f'  <circle cx="{cx}" cy="{cy}" r="{icon_dim*0.35}" fill="{ic_hex}"/>')

    # Card Banner Frame
    if frame_style in ["bottom_banner", "top_banner", "framed_card"] and frame_text:
        bx = pad
        by = banner_y
        bw = total_w - 2 * pad
        bh = banner_h - int(pad * 0.4)
        brad = max(4, int(bh * 0.25))
        b_col = color_to_hex(frame_col)
        t_col = color_to_hex(frame_txt_col)
        esc_title = saxutils.escape(frame_text)
        esc_sub = saxutils.escape(frame_subtext)

        lines.append(f'  <rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="{brad}" fill="{b_col}"/>')
        if frame_subtext:
            f_title = max(13, int(bh * 0.38))
            f_sub = max(9, int(bh * 0.22))
            lines.append(f'  <text x="{total_w / 2.0}" y="{by + bh * 0.38}" fill="{t_col}" font-family="sans-serif" font-weight="bold" font-size="{f_title}" text-anchor="middle">{esc_title}</text>')
            lines.append(f'  <text x="{total_w / 2.0}" y="{by + bh * 0.76}" fill="{t_col}" opacity="0.85" font-family="sans-serif" font-size="{f_sub}" text-anchor="middle">{esc_sub}</text>')
        else:
            f_size = max(14, int(bh * 0.42))
            lines.append(f'  <text x="{total_w / 2.0}" y="{by + bh / 2.0}" fill="{t_col}" font-family="sans-serif" font-weight="bold" font-size="{f_size}" text-anchor="middle" dominant-baseline="central">{esc_title}</text>')

    lines.append('</svg>\n')
    return "".join(lines)

def chunk_text(text, max_chunk_size=500):
    text = str(text or "").strip()
    if not text:
        return []
    if len(text) <= max_chunk_size:
        return [{"part": 1, "total": 1, "text": text, "body": text}]

    # Rough estimate of total parts to know prefix overhead
    est_total = max(2, (len(text) + max_chunk_size - 1) // max_chunk_size)
    prefix_overhead = len(f"[{est_total}/{est_total}]\n")
    target = max(50, max_chunk_size - prefix_overhead)

    raw_chunks = []
    idx = 0
    while idx < len(text):
        if len(text) - idx <= target:
            raw_chunks.append(text[idx:])
            break

        # Look for natural split points within the search window
        search_window = text[idx:idx + target]
        split_pos = -1

        # 1. Paragraph break
        p_idx = search_window.rfind("\n\n")
        if p_idx >= int(target * 0.4):
            split_pos = p_idx + 2

        # 2. Line break
        if split_pos == -1:
            l_idx = search_window.rfind("\n")
            if l_idx >= int(target * 0.4):
                split_pos = l_idx + 1

        # 3. Sentence end
        if split_pos == -1:
            for punct in [". ", "! ", "? "]:
                s_idx = search_window.rfind(punct)
                if s_idx >= int(target * 0.4):
                    split_pos = s_idx + len(punct)
                    break

        # 4. Word boundary
        if split_pos == -1:
            w_idx = search_window.rfind(" ")
            if w_idx >= int(target * 0.4):
                split_pos = w_idx + 1

        # 5. Hard boundary if no separator found
        if split_pos == -1:
            split_pos = target

        raw_chunks.append(text[idx:idx + split_pos])
        idx += split_pos

    total = len(raw_chunks)
    res = []
    for i, chunk in enumerate(raw_chunks):
        res.append({
            "part": i + 1,
            "total": total,
            "body": chunk,
            "text": f"[{i+1}/{total}]\n{chunk}"
        })
    return res

def render_single_qr(text, config, output_path, svg_output=None):
    text = str(text or "").strip()
    if not text:
        return {"error": "Empty text to encode"}

    ecc = config.get("ecc", "M").upper()
    if ecc not in ["L", "M", "Q", "H"]:
        ecc = "M"

    version = int(config.get("version", 0))
    quiet_zone = int(config.get("quiet_zone", 1))
    if quiet_zone < 0:
        quiet_zone = 0

    fg_col = parse_color(config.get("fg_color", "#000000"), (0, 0, 0, 255))
    bg_col = parse_color(config.get("bg_color", "#FFFFFF"), (255, 255, 255, 255))

    outer_eye_col = parse_color(config.get("outer_eye_color"), fg_col)
    inner_eye_col = parse_color(config.get("inner_eye_color"), fg_col)
    timing_col = parse_color(config.get("timing_color"), fg_col)
    alignment_col = parse_color(config.get("alignment_color"), fg_col)

    module_shape = config.get("module_shape", "square").lower()
    eye_shape = config.get("eye_shape", "square").lower()
    grad_type = config.get("gradient_type", "none").lower()
    grad_col = parse_color(config.get("gradient_color"), fg_col) if grad_type != "none" else None

    # Card Frame
    frame_style = config.get("frame_style", "none").lower()
    frame_text = config.get("frame_text", "SCAN ME").strip()
    frame_subtext = config.get("frame_subtext", "").strip()
    frame_radius = int(config.get("frame_radius", 0))
    frame_col = parse_color(config.get("frame_color"), fg_col)
    frame_txt_col = parse_color(config.get("frame_text_color", "#FFFFFF"), (255, 255, 255, 255))

    # Logo Setup
    logo_preset = config.get("logo_preset", "none").lower()
    logo_path = config.get("logo_path", "").strip()
    if logo_preset == "none":
        has_logo = False
    elif logo_preset == "custom":
        has_logo = bool(logo_path) and os.path.isfile(logo_path)
    else:
        has_logo = True
    logo_shape = config.get("logo_shape", "rounded").lower()
    try:
        logo_size_scale = float(config.get("logo_size", 0.22))
    except Exception:
        logo_size_scale = 0.22
    logo_bg_col = parse_color(config.get("logo_bg_color"), (255, 255, 255, 255) if bg_col[3] == 0 else bg_col)
    logo_border_col = parse_color(config.get("logo_border_color"), outer_eye_col)
    logo_border_w = int(config.get("logo_border_width", 2))
    logo_padding_ratio = float(config.get("logo_padding", 0.70))
    logo_tint_col = parse_color(config.get("logo_tint_color"), fg_col)

    # Automatically boost ECC to H when logo is requested
    if has_logo and ecc in ["L", "M"]:
        ecc = "H"

    # Run qrencode
    cmd = ["qrencode", "-t", "ASCII", "-m", "0", "-l", ecc]
    if version > 0:
        cmd.extend(["-v", str(version)])
    cmd.append(text)

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        ascii_art = proc.stdout
    except subprocess.CalledProcessError as e:
        return {"error": f"qrencode execution failed: {e.stderr}"}
    except FileNotFoundError:
        return {"error": "qrencode not installed"}

    lines = [l for l in ascii_art.splitlines() if l]
    if not lines:
        return {"error": "Empty qrencode output"}

    N = len(lines)
    detected_version = (N - 21) // 4 + 1

    matrix = []
    for line in lines:
        padded = line.ljust(2 * N)
        matrix.append([1 if padded[i*2:i*2+2] == "##" else 0 for i in range(N)])

    total_modules = N + 2 * quiet_zone
    target_size = int(config.get("resolution", 600))
    if target_size < 300:
        target_size = 600
    S = max(4, target_size // total_modules)
    W = total_modules * S

    img = Image.new("RGBA", (W, W), bg_col)
    draw = ImageDraw.Draw(img)

    # Render non-finder modules
    for r in range(N):
        for c in range(N):
            is_finder = (r < 7 and c < 7) or (r < 7 and c >= N - 7) or (r >= N - 7 and c < 7)
            if is_finder:
                continue

            if matrix[r][c] == 1:
                part = classify_cell(r, c, N, detected_version)
                if part == "timing":
                    col = timing_col
                elif part.startswith("alignment"):
                    col = alignment_col
                else:
                    col = get_gradient_color(r, c, N, fg_col, grad_col, grad_type)

                x0 = (c + quiet_zone) * S
                y0 = (r + quiet_zone) * S
                x1 = x0 + S - 1
                y1 = y0 + S - 1

                if module_shape in ["dot", "circle"]:
                    p = max(1, S // 8)
                    draw.ellipse([x0 + p, y0 + p, x1 - p, y1 - p], fill=col)
                elif module_shape == "fluid":
                    top = (r > 0 and matrix[r-1][c] == 1 and classify_cell(r-1, c, N, detected_version) == part)
                    bottom = (r < N-1 and matrix[r+1][c] == 1 and classify_cell(r+1, c, N, detected_version) == part)
                    left = (c > 0 and matrix[r][c-1] == 1 and classify_cell(r, c-1, N, detected_version) == part)
                    right = (c < N-1 and matrix[r][c+1] == 1 and classify_cell(r, c+1, N, detected_version) == part)
                    tl = not top and not left
                    tr = not top and not right
                    br = not bottom and not right
                    bl = not bottom and not left
                    safe_rad = min(max(1, S // 3), max(1, (S - 3) // 2))
                    try:
                        draw.rounded_rectangle([x0, y0, x1, y1], radius=safe_rad, fill=col, corners=(tl, tr, br, bl))
                    except Exception:
                        draw.rectangle([x0, y0, x1, y1], fill=col)
                elif module_shape == "rounded":
                    rad = max(1, min(S // 3, (x1 - x0) // 2))
                    draw.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=col)
                else:
                    draw.rectangle([x0, y0, x1, y1], fill=col)

    # Render Finder Patterns
    finder_corners = [(0, 0), (0, N - 7), (N - 7, 0)]
    for fr, fc in finder_corners:
        x0 = (fc + quiet_zone) * S
        y0 = (fr + quiet_zone) * S
        x1 = x0 + 7 * S
        y1 = y0 + 7 * S

        draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=bg_col)

        if eye_shape in ["circle", "bullseye"]:
            draw.ellipse([x0, y0, x1 - 1, y1 - 1], fill=outer_eye_col)
            draw.ellipse([x0 + S, y0 + S, x1 - S - 1, y1 - S - 1], fill=bg_col)
            draw.ellipse([x0 + 2*S, y0 + 2*S, x1 - 2*S - 1, y1 - 2*S - 1], fill=inner_eye_col)
        elif eye_shape == "squircle":
            rad_out = int(S * 2.4)
            rad_sep = int(S * 1.6)
            rad_in = int(S * 1.1)
            draw.rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius=rad_out, fill=outer_eye_col)
            draw.rounded_rectangle([x0 + S, y0 + S, x1 - S - 1, y1 - S - 1], radius=rad_sep, fill=bg_col)
            draw.rounded_rectangle([x0 + 2*S, y0 + 2*S, x1 - 2*S - 1, y1 - 2*S - 1], radius=rad_in, fill=inner_eye_col)
        elif eye_shape == "rounded":
            rad_out = int(S * 1.6)
            rad_sep = int(S * 1.1)
            rad_in = int(S * 0.8)
            draw.rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius=rad_out, fill=outer_eye_col)
            draw.rounded_rectangle([x0 + S, y0 + S, x1 - S - 1, y1 - S - 1], radius=rad_sep, fill=bg_col)
            draw.rounded_rectangle([x0 + 2*S, y0 + 2*S, x1 - 2*S - 1, y1 - 2*S - 1], radius=rad_in, fill=inner_eye_col)
        else:
            draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=outer_eye_col)
            draw.rectangle([x0 + S, y0 + S, x1 - S - 1, y1 - S - 1], fill=bg_col)
            draw.rectangle([x0 + 2*S, y0 + 2*S, x1 - 2*S - 1, y1 - 2*S - 1], fill=inner_eye_col)

    # Center Logo Rendering
    if has_logo:
        cx, cy = W // 2, W // 2
        badge_w = int(W * logo_size_scale)
        badge_h = badge_w
        bx0 = cx - badge_w // 2
        by0 = cy - badge_h // 2
        bx1 = bx0 + badge_w
        by1 = by0 + badge_h

        badge_bg = logo_bg_col
        badge_border = logo_border_col

        if logo_shape not in ["floating", "borderless"]:
            if logo_shape == "circle":
                draw.ellipse([bx0, by0, bx1, by1], fill=badge_bg, outline=badge_border, width=logo_border_w)
            elif logo_shape == "square":
                draw.rectangle([bx0, by0, bx1, by1], fill=badge_bg, outline=badge_border, width=logo_border_w)
            else: # squircle / rounded
                draw.rounded_rectangle(
                    [bx0, by0, bx1, by1],
                    radius=int(badge_w * 0.28),
                    fill=badge_bg,
                    outline=badge_border,
                    width=logo_border_w
                )

        icon_size = int(badge_w * logo_padding_ratio)
        loaded_image = None

        if logo_preset == "custom":
            if logo_path and os.path.isfile(logo_path):
                ext = os.path.splitext(logo_path)[1].lower()
                if ext == ".svg":
                    try:
                        proc = subprocess.run(
                            ["rsvg-convert", "-w", str(icon_size * 2), "-h", str(icon_size * 2), "--keep-aspect-ratio", logo_path],
                            capture_output=True, check=True
                        )
                        loaded_image = Image.open(io.BytesIO(proc.stdout)).convert("RGBA")
                    except Exception:
                        try:
                            proc = subprocess.run(
                                ["magick", "-density", "300", logo_path, "png:-"],
                                capture_output=True, check=True
                            )
                            loaded_image = Image.open(io.BytesIO(proc.stdout)).convert("RGBA")
                        except Exception:
                            pass
                else:
                    try:
                        loaded_image = Image.open(logo_path).convert("RGBA")
                    except Exception:
                        pass
        elif logo_preset != "none":
            draw_preset_icon(draw, logo_preset, cx, cy, icon_size, logo_tint_col)

        if loaded_image is not None:
            loaded_image.thumbnail((icon_size, icon_size), Image.Resampling.LANCZOS)
            iw, ih = loaded_image.size
            img.paste(loaded_image, (cx - iw // 2, cy - ih // 2), mask=loaded_image)

    # Card Frame & Call-to-Action Banner
    final_output_img = img
    if frame_style in ["bottom_banner", "top_banner", "framed_card"]:
        banner_h = max(45, int(W * 0.16)) if frame_subtext else max(40, int(W * 0.14))
        pad = max(16, int(W * 0.05))
        total_w = W + 2 * pad
        total_h = W + 2 * pad + banner_h

        card_bg = (255, 255, 255, 255) if bg_col[3] == 0 else bg_col
        card_img = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
        cdraw = ImageDraw.Draw(card_img)

        # Background with optional corner radius
        scaled_frame_radius = max(0, int(frame_radius * (W / 600.0)))
        if scaled_frame_radius > 0:
            cdraw.rounded_rectangle([0, 0, total_w - 1, total_h - 1], radius=scaled_frame_radius, fill=card_bg)
        else:
            cdraw.rectangle([0, 0, total_w - 1, total_h - 1], fill=card_bg)

        # Paste QR
        if frame_style == "top_banner":
            qr_y = pad + banner_h
            banner_box_y = pad // 2
        else:
            qr_y = pad
            banner_box_y = W + pad + int(pad * 0.2)

        card_img.paste(img, (pad, qr_y), mask=img)

        # Draw Banner
        if frame_text:
            bx0 = pad
            by0 = banner_box_y
            bx1 = total_w - pad
            by1 = by0 + banner_h - int(pad * 0.4)
            brad = max(4, int((by1 - by0) * 0.25))

            cdraw.rounded_rectangle([bx0, by0, bx1, by1], radius=brad, fill=frame_col)

            if frame_subtext:
                f_title_sz = max(13, int((by1 - by0) * 0.36))
                f_sub_sz = max(9, int((by1 - by0) * 0.22))
                font_title = load_system_font(f_title_sz, bold=True)
                font_sub = load_system_font(f_sub_sz, bold=False)

                bbox_t = cdraw.textbbox((0, 0), frame_text, font=font_title)
                tw = bbox_t[2] - bbox_t[0]
                th = bbox_t[3] - bbox_t[1]
                tx = (total_w - tw) // 2
                ty = by0 + int((by1 - by0) * 0.16)
                cdraw.text((tx, ty), frame_text, font=font_title, fill=frame_txt_col)

                bbox_s = cdraw.textbbox((0, 0), frame_subtext, font=font_sub)
                sw = bbox_s[2] - bbox_s[0]
                sx = (total_w - sw) // 2
                sy = ty + th + max(3, int((by1 - by0) * 0.08))
                sub_col = (frame_txt_col[0], frame_txt_col[1], frame_txt_col[2], int(frame_txt_col[3] * 0.85))
                cdraw.text((sx, sy), frame_subtext, font=font_sub, fill=sub_col)
            else:
                font_size = max(14, int((by1 - by0) * 0.42))
                font = load_system_font(font_size, bold=True)
                bbox = cdraw.textbbox((0, 0), frame_text, font=font)
                tw = bbox[2] - bbox[0]
                th = bbox[3] - bbox[1]
                tx = (total_w - tw) // 2
                ty = by0 + ((by1 - by0) - th) // 2 - int(th * 0.1)
                cdraw.text((tx, ty), frame_text, font=font, fill=frame_txt_col)

        final_output_img = card_img

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    final_output_img.save(output_path, "PNG")

    # SVG Export if requested
    svg_res = None
    if svg_output:
        try:
            svg_content = generate_svg(matrix, N, S, W, quiet_zone, detected_version, config)
            os.makedirs(os.path.dirname(os.path.abspath(svg_output)), exist_ok=True)
            with open(svg_output, "w", encoding="utf-8") as sf:
                sf.write(svg_content)
            svg_res = svg_output
        except Exception as se:
            sys.stderr.write(f"Warning: SVG export failed: {se}\n")

    return {
        "success": True,
        "version": detected_version,
        "matrix_size": N,
        "ecc": ecc,
        "quiet_zone": quiet_zone,
        "modules": N * N,
        "width": final_output_img.width,
        "height": final_output_img.height,
        "output": output_path,
        "svg_output": svg_res
    }

def generate(config):
    raw_text = config.get("text", "").strip()
    if not raw_text:
        return {"error": "Empty text to encode"}

    output_path = config.get("output", "/tmp/reclip-qr-display.png")
    svg_output = config.get("svg_output", "").strip()

    auto_split = bool(config.get("auto_split", True))
    try:
        max_chunk_size = int(config.get("max_chunk_size", 500))
    except Exception:
        max_chunk_size = 500

    out_dir = os.path.dirname(os.path.abspath(output_path))
    os.makedirs(out_dir, exist_ok=True)

    # Check if chunking is needed
    if auto_split and len(raw_text) > max_chunk_size:
        chunks = chunk_text(raw_text, max_chunk_size)
    else:
        chunks = [{"part": 1, "total": 1, "text": raw_text, "body": raw_text}]

    if len(chunks) <= 1:
        # Standard Single QR Mode
        res = render_single_qr(raw_text, config, output_path, svg_output)
        if "error" in res:
            return res
        res["is_series"] = False
        res["total_parts"] = 1
        res["current_part"] = 1
        res["chunk_size"] = max_chunk_size
        res["parts"] = [{
            "part": 1,
            "total": 1,
            "image": output_path,
            "svg": svg_output if svg_output else None,
            "length": len(raw_text),
            "preview": raw_text[:60].replace("\n", " ")
        }]
        return res

    # Multi-Part Series Mode
    base_prefix = "reclip-qr-part"
    parts_meta = []
    primary_res = None

    for c in chunks:
        p_num = c["part"]
        p_img = os.path.join(out_dir, f"{base_prefix}-{p_num}.png")
        p_svg = os.path.join(out_dir, f"{base_prefix}-{p_num}.svg") if svg_output else None

        part_res = render_single_qr(c["text"], config, p_img, p_svg)
        if "error" in part_res:
            return part_res

        if p_num == 1:
            primary_res = part_res
            try:
                shutil.copyfile(p_img, output_path)
                if svg_output and p_svg:
                    shutil.copyfile(p_svg, svg_output)
            except Exception:
                pass

        parts_meta.append({
            "part": p_num,
            "total": len(chunks),
            "image": p_img,
            "svg": p_svg,
            "length": len(c["text"]),
            "body_length": len(c["body"]),
            "preview": c["text"][:60].replace("\n", " ")
        })

    return {
        "success": True,
        "is_series": True,
        "total_parts": len(chunks),
        "current_part": 1,
        "chunk_size": max_chunk_size,
        "parts": parts_meta,
        "version": primary_res.get("version", 1) if primary_res else 1,
        "matrix_size": primary_res.get("matrix_size", 21) if primary_res else 21,
        "ecc": primary_res.get("ecc", "M") if primary_res else "M",
        "modules": primary_res.get("modules", 441) if primary_res else 441,
        "width": primary_res.get("width", 600) if primary_res else 600,
        "height": primary_res.get("height", 600) if primary_res else 600,
        "output": output_path,
        "svg_output": svg_output if svg_output else None
    }

def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg.startswith("{"):
            try:
                cfg = json.loads(arg)
            except Exception as e:
                print(json.dumps({"error": f"Invalid JSON: {e}"}))
                sys.exit(1)
        elif os.path.isfile(arg):
            with open(arg, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        else:
            cfg = {"text": arg}
    else:
        stdin_data = sys.stdin.read().strip()
        if stdin_data.startswith("{"):
            cfg = json.loads(stdin_data)
        else:
            cfg = {"text": stdin_data}

    res = generate(cfg)
    print(json.dumps(res))
    if "error" in res:
        sys.exit(1)

if __name__ == "__main__":
    main()
