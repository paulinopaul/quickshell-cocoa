#!/usr/bin/env python3
"""
apply_custom_theme.py — Custom Theme Generator and Hyprland Sync for Cocoa Shell.
Calculates harmonious color tokens (textMuted, textDim, accent) from a chosen hex accent,
persists the configuration to current_theme.json, and synchronizes Hyprland borders.
"""

import colorsys
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple

COCOA_DIR = Path.home() / ".config/quickshell/cocoa"
THEME_JSON = COCOA_DIR / "theme/current_theme.json"
HYPR_THEME_CONF = Path.home() / ".config/hypr/theme.conf"
CURRENT_WALLPAPER_FILE = COCOA_DIR / "theme/current_wallpaper.txt"


def parse_hex_color(hex_str: str) -> Tuple[int, int, int]:
    """Parses a hex color string into (R, G, B) tuple in 0-255 range."""
    cleaned = hex_str.strip().lstrip("#")
    if len(cleaned) == 3:
        cleaned = "".join(c * 2 for c in cleaned)
    if len(cleaned) != 6 or not re.match(r"^[0-9a-fA-F]{6}$", cleaned):
        raise ValueError(f"Color hexadecimal inválido: '{hex_str}'")
    r = int(cleaned[0:2], 16)
    g = int(cleaned[2:4], 16)
    b = int(cleaned[4:6], 16)
    return r, g, b


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{max(0, min(255, r)):02x}{max(0, min(255, g)):02x}{max(0, min(255, b)):02x}"


def clamp(val: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, val))


def hls_to_hex(h: float, l: float, s: float) -> str:
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return rgb_to_hex(int(r * 255), int(g * 255), int(b * 255))


def derive_palette_from_accent(accent_hex: str) -> Dict[str, str]:
    """
    Derives harmonious UI tokens from an accent color.
    Ensures legibility and elegance on dark surfaces (#0a0a0a).
    """
    r, g, b = parse_hex_color(accent_hex)
    normalized_accent = rgb_to_hex(r, g, b)

    # Convert to HLS
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)

    # Derive textMuted: same hue, moderated saturation & lightness
    s_muted = clamp(s * 0.65, 0.15, 0.45)
    l_muted = clamp(l * 0.85, 0.50, 0.72)
    text_muted = hls_to_hex(h, l_muted, s_muted)

    # Derive textDim: low saturation, darker for borders/placeholders
    s_dim = clamp(s * 0.30, 0.08, 0.25)
    l_dim = clamp(l * 0.60, 0.30, 0.50)
    text_dim = hls_to_hex(h, l_dim, s_dim)

    # Derive dynamic surfaces tinted with the accent's hue
    surface = hls_to_hex(h, 0.12, clamp(s * 0.30, 0.10, 0.28))
    surface_dark = hls_to_hex(h, 0.08, clamp(s * 0.30, 0.10, 0.28))
    surface_raised = hls_to_hex(h, 0.16, clamp(s * 0.30, 0.10, 0.28))
    surface_hover = hls_to_hex(h, 0.20, clamp(s * 0.30, 0.10, 0.28))
    surface_border = hls_to_hex(h, 0.26, clamp(s * 0.35, 0.12, 0.32))
    background = hls_to_hex(h, 0.06, clamp(s * 0.30, 0.08, 0.25))

    return {
        "mode": "custom",
        "surface": surface,
        "surfaceDark": surface_dark,
        "surfaceRaised": surface_raised,
        "surfaceHover": surface_hover,
        "surfaceBorder": surface_border,
        "background": background,
        "text": "#ffffff",
        "textMuted": text_muted,
        "textDim": text_dim,
        "accent": normalized_accent,
    }


def save_theme_json(theme: Dict[str, str], target_file: Optional[Path] = None) -> None:
    dest = target_file or THEME_JSON
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(theme, f, indent=2)
    os.replace(tmp, dest)


def sync_hyprland_border(accent_hex: str) -> None:
    """Updates Hyprland border via IPC and persists theme.conf.

    Delegates to the canonical writer (scripts/hypr_theme_conf.py: single
    schema, single header). The full palette is derived so the shared
    $wallpaper_muted/$wallpaper_dim variables stay populated.
    """
    try:
        theme = derive_palette_from_accent(accent_hex)
    except Exception as e:
        print(f"Advertencia al escribir theme.conf: {e}", file=sys.stderr)
        return

    try:
        try:
            from scripts.hypr_theme_conf import write_theme_conf, sync_live_border
        except ImportError:  # standalone execution (scripts/ is sys.path[0])
            from hypr_theme_conf import write_theme_conf, sync_live_border
    except ImportError as e:
        print(f"Advertencia al escribir theme.conf: {e}", file=sys.stderr)
        return

    try:
        write_theme_conf(theme["accent"], theme["textMuted"], theme["textDim"])
    except Exception as e:
        print(f"Advertencia al escribir theme.conf: {e}", file=sys.stderr)

    # Live hyprctl update (fail-soft inside the canonical helper).
    try:
        sync_live_border(theme["accent"])
    except Exception:
        pass


def _run_ghostty_sync() -> None:
    """Best-effort: keeps Ghostty in sync after a palette change (fail-soft)."""
    script = COCOA_DIR / "scripts/ghostty_sync.py"
    if not script.exists():
        return
    try:
        subprocess.run(["python3", str(script)], capture_output=True, timeout=10)
    except Exception:
        pass


def sync_with_wallpaper() -> Dict[str, str]:
    """Runs apply_wallpaper_theme.sh to restore wallpaper adaptive colors."""
    wall_path = ""
    if CURRENT_WALLPAPER_FILE.exists():
        try:
            wall_path = CURRENT_WALLPAPER_FILE.read_text(encoding="utf-8").strip()
        except Exception:
            pass

    script = Path.home() / ".config/hypr/scripts/apply_wallpaper_theme.sh"
    if script.exists() and os.access(script, os.X_OK):
        subprocess.run([str(script), wall_path] if wall_path else [str(script)], capture_output=True, timeout=10)

    # Read back current theme
    if THEME_JSON.exists():
        try:
            data = json.loads(THEME_JSON.read_text(encoding="utf-8"))
            data["mode"] = "auto"
            save_theme_json(data)
            _run_ghostty_sync()
            return data
        except Exception:
            pass

    return {"mode": "auto", "text": "#ffffff", "textMuted": "#b8b8b8", "textDim": "#606060", "accent": "#d0d0d0"}


def main():
    if len(sys.argv) < 2:
        print("Uso: apply_custom_theme.py <#hex_color> | --sync-wallpaper")
        sys.exit(1)

    arg = sys.argv[1].strip()

    if arg == "--sync-wallpaper":
        theme = sync_with_wallpaper()
        print(json.dumps(theme, indent=2))
        return

    try:
        theme = derive_palette_from_accent(arg)
        save_theme_json(theme)
        sync_hyprland_border(theme["accent"])
        _run_ghostty_sync()
        print(json.dumps(theme, indent=2))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
