#!/usr/bin/env python3
"""
theme_manager.py — Centralized Theme Engine & Wallpaper-Theme Binding Architecture for Cocoa Shell.

Features:
1. Curated Named Palettes (NeoNord, Catppuccin, Tokyo Night, Gruvbox, Rose Pine, Cyberpunk, etc.).
2. Persistent Wallpaper-to-Theme Mappings (~/.config/quickshell/cocoa/theme/wallpaper_themes.json).
3. Dynamic theme generation from wallpapers (Pillow extraction).
4. Synchronous compositor updates via Hyprland IPC and theme.conf.
"""

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

COCOA_DIR = Path.home() / ".config/quickshell/cocoa"
THEME_JSON = COCOA_DIR / "theme/current_theme.json"
WALLPAPER_THEMES_JSON = COCOA_DIR / "theme/wallpaper_themes.json"
CURRENT_WALLPAPER_FILE = COCOA_DIR / "theme/current_wallpaper.txt"
HYPR_THEME_CONF = Path.home() / ".config/hypr/theme.conf"
EXTRACTOR_SCRIPT = COCOA_DIR / "scripts/extract_colors.py"


def _normalize_wall_key(path: str) -> str:
    """Portable wallpaper key: expand ~/$HOME, then absolute-resolve.

    Tracked mapping keys use `~`-relative form (no hardcoded username);
    runtime paths are absolute. Normalizing both sides lets a shipped mapping
    match on any machine with the standard symlink layout.
    """
    expanded = os.path.expandvars(os.path.expanduser((path or "").strip()))
    if not expanded:
        return ""
    return str(Path(expanded).resolve())


def _portable_wall_key(abs_path: str) -> str:
    """Inverse of _normalize_wall_key: collapse $HOME to ~ so newly written
    mapping keys stay portable (no username leaks into the tracked file)."""
    home = str(Path.home())
    if abs_path == home or abs_path.startswith(home + os.sep):
        return "~" + abs_path[len(home):]
    return abs_path


def _lookup_mapping(mappings: Dict[str, Any], wallpaper_path: str) -> Optional[Dict[str, Any]]:
    """Finds a bound theme by exact key, falling back to normalized compare."""
    resolved = _normalize_wall_key(wallpaper_path)
    if not resolved:
        return None
    if resolved in mappings:
        theme = mappings[resolved]
        return theme if isinstance(theme, dict) else None
    for key, theme in mappings.items():
        if isinstance(theme, dict) and _normalize_wall_key(key) == resolved:
            return theme
    return None

NAMED_PRESETS: Dict[str, Dict[str, str]] = {
    "NeoNord": {
        "name": "NeoNord",
        "terminalTheme": "Onenord",
        "accent": "#88c0d0",
        "surface": "#242933",
        "surfaceDark": "#1e222a",
        "surfaceRaised": "#2e3440",
        "surfaceBorder": "#434c5e",
        "surfaceHover": "#3b4252",
        "background": "#191c22",
        "text": "#eceff4",
        "textMuted": "#81a1c1",
        "textDim": "#4c566a",
        "description": "Arctic Nord frost blue palette",
    },
    "Catppuccin Mocha": {
        "name": "Catppuccin Mocha",
        "terminalTheme": "Catppuccin Mocha",
        "accent": "#cba6f7",
        "surface": "#1e1e2e",
        "surfaceDark": "#181825",
        "surfaceRaised": "#252538",
        "surfaceBorder": "#45475a",
        "surfaceHover": "#313244",
        "background": "#11111b",
        "text": "#cdd6f4",
        "textMuted": "#89b4fa",
        "textDim": "#585b70",
        "description": "Soothing pastel lavender and sapphire",
    },
    "Tokyo Night": {
        "name": "Tokyo Night",
        "terminalTheme": "TokyoNight Night",
        "accent": "#7aa2f7",
        "surface": "#1a1b26",
        "surfaceDark": "#16161e",
        "surfaceRaised": "#24283b",
        "surfaceBorder": "#383e5a",
        "surfaceHover": "#2f354f",
        "background": "#13141c",
        "text": "#c0caf5",
        "textMuted": "#7dcfff",
        "textDim": "#565f89",
        "description": "Clean neon blue on deep dark night",
    },
    "Gruvbox Retro": {
        "name": "Gruvbox Retro",
        "terminalTheme": "Gruvbox Dark",
        "accent": "#d79921",
        "surface": "#282828",
        "surfaceDark": "#1d2021",
        "surfaceRaised": "#32302f",
        "surfaceBorder": "#504945",
        "surfaceHover": "#3c3836",
        "background": "#141617",
        "text": "#fbf1c7",
        "textMuted": "#fabd2f",
        "textDim": "#665c54",
        "description": "Warm retro golden amber hues",
    },
    "Rose Pine": {
        "name": "Rose Pine",
        "terminalTheme": "Rose Pine",
        "accent": "#eb6f92",
        "surface": "#191724",
        "surfaceDark": "#14121f",
        "surfaceRaised": "#211f30",
        "surfaceBorder": "#393552",
        "surfaceHover": "#26233a",
        "background": "#0f0e17",
        "text": "#e0def4",
        "textMuted": "#c4a7e7",
        "textDim": "#6e6a86",
        "description": "Soft pine rose and lilac undertones",
    },
    "Cyberpunk Neon": {
        "name": "Cyberpunk Neon",
        "terminalTheme": "Cyberpunk",
        "accent": "#00f0ff",
        "surface": "#0f1322",
        "surfaceDark": "#090b14",
        "surfaceRaised": "#181e33",
        "surfaceBorder": "#253456",
        "surfaceHover": "#1d2745",
        "background": "#06080d",
        "text": "#ffffff",
        "textMuted": "#00f0ff",
        "textDim": "#ff003c",
        "description": "High-voltage electric cyan & magenta",
    },
    "Emerald Forest": {
        "name": "Emerald Forest",
        "terminalTheme": "Everforest Dark Hard",
        "accent": "#10b981",
        "surface": "#11221a",
        "surfaceDark": "#0c1712",
        "surfaceRaised": "#183327",
        "surfaceBorder": "#27523f",
        "surfaceHover": "#1f4233",
        "background": "#070e0b",
        "text": "#f0fdf4",
        "textMuted": "#34d399",
        "textDim": "#374151",
        "description": "Lush vibrant botanical green",
    },
    "Sunset Glow": {
        "name": "Sunset Glow",
        "terminalTheme": "Kanagawa Wave",
        "accent": "#f59e0b",
        "surface": "#201612",
        "surfaceDark": "#17100d",
        "surfaceRaised": "#2e1f1a",
        "surfaceBorder": "#473229",
        "surfaceHover": "#382720",
        "background": "#0f0a08",
        "text": "#fffbeb",
        "textMuted": "#fb923c",
        "textDim": "#4b5563",
        "description": "Golden twilight orange and warm flame",
    },
    "Cocoa Classic": {
        "name": "Cocoa Classic",
        "terminalTheme": "Monokai Pro",
        "accent": "#d4af37",
        "surface": "#1c1815",
        "surfaceDark": "#14110e",
        "surfaceRaised": "#29241f",
        "surfaceBorder": "#423a32",
        "surfaceHover": "#362f28",
        "background": "#0d0b09",
        "text": "#ffffff",
        "textMuted": "#b59b49",
        "textDim": "#5f5840",
        "description": "Signature luxurious gold and brass",
    },
}


def load_database() -> Dict[str, Any]:
    """Loads wallpaper-to-theme mappings and user-created custom themes."""
    if not WALLPAPER_THEMES_JSON.exists():
        initial = {
            "mappings": {},
            "activeTheme": "Auto",
            "customThemes": {},
        }
        save_database(initial)
        return initial

    try:
        with open(WALLPAPER_THEMES_JSON, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"mappings": {}, "activeTheme": "Auto", "customThemes": {}}


def save_database(data: Dict[str, Any]) -> None:
    WALLPAPER_THEMES_JSON.parent.mkdir(parents=True, exist_ok=True)
    tmp = WALLPAPER_THEMES_JSON.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, WALLPAPER_THEMES_JSON)


def get_all_themes() -> Dict[str, Dict[str, str]]:
    db = load_database()
    combined = dict(NAMED_PRESETS)
    combined.update(db.get("customThemes", {}))
    return combined


def write_theme_json(theme: Dict[str, str]) -> None:
    THEME_JSON.parent.mkdir(parents=True, exist_ok=True)
    tmp = THEME_JSON.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(theme, f, indent=2)
    os.replace(tmp, THEME_JSON)


def sync_hyprland(accent_hex: str, muted_hex: Optional[str] = None, dim_hex: Optional[str] = None) -> None:
    """Synchronizes Hyprland borders via the canonical theme.conf writer.

    Delegates to scripts/hypr_theme_conf.py (single schema, single header);
    this function keeps its signature so existing callers are unaffected.
    """
    try:
        try:
            from scripts.hypr_theme_conf import write_theme_conf, sync_live_border
        except ImportError:  # standalone execution (scripts/ is sys.path[0])
            from hypr_theme_conf import write_theme_conf, sync_live_border
    except ImportError:
        return

    try:
        write_theme_conf(accent_hex, muted_hex, dim_hex)
    except Exception:
        pass

    try:
        sync_live_border(accent_hex)
    except Exception:
        pass


def apply_theme_by_name(theme_name: str) -> Dict[str, str]:
    all_themes = get_all_themes()
    if theme_name in all_themes:
        theme = dict(all_themes[theme_name])
        theme["mode"] = theme_name
        write_theme_json(theme)
        sync_hyprland(theme["accent"])

        db = load_database()
        db["activeTheme"] = theme_name
        save_database(db)
        return theme

    raise ValueError(f"Tema no encontrado: '{theme_name}'")


def bind_wallpaper(wallpaper_path: str, theme_name_or_palette: Any) -> Dict[str, Any]:
    """Binds a specific wallpaper to a named theme or custom palette."""
    resolved_wall = _normalize_wall_key(wallpaper_path)
    if not resolved_wall:
        raise ValueError(f"Ruta de wallpaper inválida: '{wallpaper_path}'")
    stored_key = _portable_wall_key(resolved_wall)
    db = load_database()

    if isinstance(theme_name_or_palette, str):
        all_themes = get_all_themes()
        if theme_name_or_palette in all_themes:
            payload = {
                "themeName": theme_name_or_palette,
                **all_themes[theme_name_or_palette],
            }
        else:
            from scripts.apply_custom_theme import derive_palette_from_accent
            payload = derive_palette_from_accent(theme_name_or_palette)
            payload["themeName"] = f"Custom ({theme_name_or_palette})"
    elif isinstance(theme_name_or_palette, dict):
        payload = theme_name_or_palette
    else:
        raise ValueError("Formato de tema inválido")

    db["mappings"][stored_key] = payload
    save_database(db)

    # If this is the current active wallpaper, apply it immediately
    curr_wall = get_current_wallpaper()
    if curr_wall and _normalize_wall_key(curr_wall) == resolved_wall:
        apply_for_wallpaper(resolved_wall)

    return payload


def unbind_wallpaper(wallpaper_path: str) -> bool:
    resolved_wall = _normalize_wall_key(wallpaper_path)
    db = load_database()
    mappings = db.get("mappings", {})
    for key in list(mappings.keys()):
        if key == resolved_wall or _normalize_wall_key(key) == resolved_wall:
            del mappings[key]
            save_database(db)
            return True
    return False


def get_current_wallpaper() -> str:
    if CURRENT_WALLPAPER_FILE.exists():
        try:
            # Expand ~ so portable tracked defaults resolve on any machine.
            return os.path.expanduser(CURRENT_WALLPAPER_FILE.read_text(encoding="utf-8").strip())
        except Exception:
            pass
    return ""


def create_theme_from_wallpaper(wallpaper_path: str, custom_name: Optional[str] = None) -> Dict[str, str]:
    """Extracts palette using extract_colors.py and registers it as a reusable theme."""
    import subprocess
    resolved = _normalize_wall_key(wallpaper_path)
    if not resolved:
        raise ValueError(f"Ruta de wallpaper inválida: '{wallpaper_path}'")
    if not Path(resolved).exists():
        raise FileNotFoundError(f"Wallpaper no encontrado: {resolved}")

    proc = subprocess.run(
        ["python3", str(EXTRACTOR_SCRIPT), resolved],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Error extrayendo colores: {proc.stderr}")

    theme = json.loads(proc.stdout)
    name = custom_name or f"Tema de {Path(resolved).stem}"
    theme["name"] = name
    theme["description"] = f"Generado a partir de {Path(resolved).name}"

    db = load_database()
    db["customThemes"][name] = theme
    # Also bind to this wallpaper (portable key: no hardcoded username)
    db["mappings"][_portable_wall_key(resolved)] = {"themeName": name, **theme}
    save_database(db)

    # Apply immediately
    write_theme_json(theme)
    sync_hyprland(theme["accent"])
    return theme


def apply_for_wallpaper(wallpaper_path: str) -> Dict[str, str]:
    """
    Core entrypoint called on wallpaper change:
    1. Checks if wallpaper is bound to a theme preset.
    2. If bound, applies the bound theme!
    3. If not, extracts colors dynamically from the wallpaper.
    """
    resolved = _normalize_wall_key(wallpaper_path)
    db = load_database()
    mappings = db.get("mappings", {})

    theme = _lookup_mapping(mappings, resolved)
    if theme is not None:
        clean_theme = {
            "mode": theme.get("themeName", "mapped"),
            "text": theme.get("text", "#ffffff"),
            "textMuted": theme.get("textMuted", "#81a1c1"),
            "textDim": theme.get("textDim", "#4c566a"),
            "accent": theme.get("accent", "#88c0d0"),
        }
        write_theme_json(clean_theme)
        sync_hyprland(clean_theme["accent"])
        return clean_theme

    # Fallback to dynamic extraction
    import subprocess
    proc = subprocess.run(
        ["python3", str(EXTRACTOR_SCRIPT), resolved],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if proc.returncode == 0:
        theme = json.loads(proc.stdout)
        theme["mode"] = "auto"
        write_theme_json(theme)
        sync_hyprland(theme.get("accent", "#74c5d6"))
        return theme

    return {"mode": "auto", "text": "#ffffff", "textMuted": "#b8b8b8", "textDim": "#606060", "accent": "#d0d0d0"}


def main():
    if len(sys.argv) < 2:
        print("Uso: theme_manager.py <list-presets|get-db|apply <name>|apply-for-wallpaper <path>|bind <wall> <theme>|unbind <wall>|create-from-wall <wall> [name]>")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "list-presets":
        print(json.dumps(get_all_themes(), indent=2))
    elif cmd == "get-db":
        print(json.dumps(load_database(), indent=2))
    elif cmd == "apply":
        if len(sys.argv) < 3:
            print("Error: falta nombre del tema", file=sys.stderr)
            sys.exit(1)
        res = apply_theme_by_name(sys.argv[2])
        print(json.dumps(res, indent=2))
    elif cmd == "apply-for-wallpaper":
        if len(sys.argv) < 3:
            print("Error: falta ruta del wallpaper", file=sys.stderr)
            sys.exit(1)
        res = apply_for_wallpaper(sys.argv[2])
        print(json.dumps(res, indent=2))
    elif cmd == "bind":
        if len(sys.argv) < 4:
            print("Error: falta ruta del wallpaper o tema", file=sys.stderr)
            sys.exit(1)
        res = bind_wallpaper(sys.argv[2], sys.argv[3])
        print(json.dumps(res, indent=2))
    elif cmd == "unbind":
        if len(sys.argv) < 3:
            print("Error: falta ruta del wallpaper", file=sys.stderr)
            sys.exit(1)
        ok = unbind_wallpaper(sys.argv[2])
        print(json.dumps({"success": ok}, indent=2))
    elif cmd == "create-from-wall":
        if len(sys.argv) < 3:
            print("Error: falta ruta del wallpaper", file=sys.stderr)
            sys.exit(1)
        name = sys.argv[3] if len(sys.argv) > 3 else None
        res = create_theme_from_wallpaper(sys.argv[2], name)
        print(json.dumps(res, indent=2))
    else:
        print(f"Comando desconocido: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
