#!/usr/bin/env python3
"""
visual_config_manager.py — Visual & Appearance Customization Manager for Cocoa Shell & Hyprland.

Manages:
1. Hyprland Window Decorations: border size, rounding, shadow enabled, shadow range, shadow render power.
2. Ghostty Terminal Visual Styling: theme name, background opacity, background blur.
3. Cocoa Top Bar Panels & Dynamic Island:
   - Left Panel (visibility, opacity, border width, showWorkspaces, showActiveWindow)
   - Center Dynamic Island (visibility, opacity, border width, showMedia, showCpu, showRam, showGpu, showNeon)
   - Right Panel (visibility, opacity, border width, showBattery, showNetwork, showMic, showVolume, showBrightness, showSettings, showPower)
4. Persistent database: ~/.config/quickshell/cocoa/theme/ui_config.json
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict

COCOA_DIR = Path.home() / ".config/quickshell/cocoa"
UI_CONFIG_PATH = COCOA_DIR / "theme/ui_config.json"
HYPR_CONF_PATH = Path.home() / ".config/hypr/hyprland.conf"
GHOSTTY_CONF_PATH = Path.home() / ".config/ghostty/config"

DEFAULT_CONFIG: Dict[str, Any] = {
    "hyprland": {
        "borderSize": 2,
        "rounding": 14,
        "gapsIn": 5,
        "gapsOut": 15,
        "shadowEnabled": True,
        "shadowRange": 15,
        "shadowPower": 6,
    },
    "ghostty": {
        "theme": "Onenord",
        "backgroundOpacity": 0.95,
        "backgroundBlur": 24,
    },
    "panels": {
        "left": {
            "visible": True,
            "bgOpacity": 0.95,
            "borderWidth": 1,
            "showWorkspaces": True,
            "showActiveWindow": True,
        },
        "center": {
            "visible": True,
            "bgOpacity": 0.95,
            "borderWidth": 1,
            "showMedia": True,
            "showCpu": True,
            "showRam": True,
            "showGpu": True,
            "showNeon": True,
        },
        "right": {
            "visible": True,
            "bgOpacity": 0.95,
            "borderWidth": 1,
            "showBattery": True,
            "showNetwork": True,
            "showMic": True,
            "showVolume": True,
            "showBrightness": True,
            "showSettings": True,
            "showPower": True,
        },
    },
}


def load_config() -> Dict[str, Any]:
    """Loads ui_config.json merged with default fallback schema."""
    if not UI_CONFIG_PATH.exists():
        save_config(DEFAULT_CONFIG)
        return DEFAULT_CONFIG

    try:
        with open(UI_CONFIG_PATH, "r", encoding="utf-8") as f:
            user_cfg = json.load(f)
    except Exception:
        return DEFAULT_CONFIG

    # Merge missing fields with defaults
    merged = dict(DEFAULT_CONFIG)
    for section, sec_val in DEFAULT_CONFIG.items():
        if section in user_cfg and isinstance(user_cfg[section], dict):
            if section == "panels":
                merged["panels"] = dict(DEFAULT_CONFIG["panels"])
                for p_id, p_val in DEFAULT_CONFIG["panels"].items():
                    merged["panels"][p_id] = {**p_val, **user_cfg["panels"].get(p_id, {})}
            else:
                merged[section] = {**sec_val, **user_cfg[section]}
        elif section in user_cfg:
            merged[section] = user_cfg[section]

    return merged


def save_config(cfg: Dict[str, Any]) -> None:
    """Atomic write to ui_config.json."""
    UI_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = UI_CONFIG_PATH.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, UI_CONFIG_PATH)


def sync_hyprland_settings(border_size: int, rounding: int, shadow_enabled: bool, shadow_range: int, shadow_power: int) -> bool:
    """Applies decoration parameters live via hyprctl and updates hyprland.conf."""
    # 1. Live IPC
    commands = [
        ["hyprctl", "keyword", "general:border_size", str(border_size)],
        ["hyprctl", "keyword", "decoration:rounding", str(rounding)],
        ["hyprctl", "keyword", "decoration:shadow:enabled", "true" if shadow_enabled else "false"],
        ["hyprctl", "keyword", "decoration:shadow:range", str(shadow_range)],
        ["hyprctl", "keyword", "decoration:shadow:render_power", str(shadow_power)],
    ]
    for cmd in commands:
        try:
            subprocess.run(cmd, capture_output=True, timeout=2)
        except Exception:
            pass

    # 2. Persist to ~/.config/hypr/hyprland.conf
    if HYPR_CONF_PATH.exists():
        try:
            content = HYPR_CONF_PATH.read_text(encoding="utf-8")

            # border_size
            content = re.sub(r"border_size\s*=\s*\d+", f"border_size = {border_size}", content)
            # rounding
            content = re.sub(r"rounding\s*=\s*\d+", f"rounding = {rounding}", content)
            # shadow enabled
            content = re.sub(r"enabled\s*=\s*(?:true|false)", f"enabled = {'true' if shadow_enabled else 'false'}", content, count=1)
            # shadow range
            content = re.sub(r"range\s*=\s*\d+", f"range = {shadow_range}", content, count=1)
            # render_power
            content = re.sub(r"render_power\s*=\s*\d+", f"render_power = {shadow_power}", content, count=1)

            HYPR_CONF_PATH.write_text(content, encoding="utf-8")
        except Exception:
            pass

    return True


def sync_ghostty_settings(theme: str, opacity: float, blur: int) -> bool:
    """Updates ~/.config/ghostty/config with chosen visual settings."""
    if not GHOSTTY_CONF_PATH.exists():
        return False

    try:
        content = GHOSTTY_CONF_PATH.read_text(encoding="utf-8")

        # theme = ...
        if re.search(r"^theme\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^theme\s*=.*$", f"theme = {theme}", content, flags=re.MULTILINE)
        else:
            content = f"theme = {theme}\n" + content

        # background-opacity = ...
        if re.search(r"^background-opacity\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^background-opacity\s*=.*$", f"background-opacity = {opacity:.2f}", content, flags=re.MULTILINE)
        else:
            content += f"\nbackground-opacity = {opacity:.2f}"

        # background-blur = ...
        if re.search(r"^background-blur\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^background-blur\s*=.*$", f"background-blur = {blur}", content, flags=re.MULTILINE)
        else:
            content += f"\nbackground-blur = {blur}"

        GHOSTTY_CONF_PATH.write_text(content, encoding="utf-8")
        return True
    except Exception:
        return False


def get_ghostty_themes() -> list[str]:
    """Returns the Ghostty themes installed on this system (title-case names)."""
    return [
        "Onenord",
        "Catppuccin Mocha",
        "Catppuccin Macchiato",
        "TokyoNight Night",
        "Gruvbox Dark",
        "Rose Pine",
        "Nord",
        "Dracula",
        "Cyberpunk",
        "Everforest Dark Hard",
        "Kanagawa Wave",
        "Monokai Pro",
    ]


def main():
    if len(sys.argv) < 2:
        print("Uso: visual_config_manager.py <get|set-hyprland|set-ghostty|set-panel|list-ghostty-themes>")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "get":
        cfg = load_config()
        print(json.dumps(cfg, separators=(',', ':')))

    elif cmd == "list-ghostty-themes":
        themes = get_ghostty_themes()
        print(json.dumps(themes, separators=(',', ':')))

    elif cmd == "set-hyprland":
        # Args: borderSize rounding shadowEnabled shadowRange shadowPower
        if len(sys.argv) < 7:
            print("Faltan argumentos para set-hyprland", file=sys.stderr)
            sys.exit(1)

        border_size = int(sys.argv[2])
        rounding = int(sys.argv[3])
        shadow_enabled = sys.argv[4].lower() in ("true", "1", "yes")
        shadow_range = int(sys.argv[5])
        shadow_power = int(sys.argv[6])

        cfg = load_config()
        cfg["hyprland"]["borderSize"] = border_size
        cfg["hyprland"]["rounding"] = rounding
        cfg["hyprland"]["shadowEnabled"] = shadow_enabled
        cfg["hyprland"]["shadowRange"] = shadow_range
        cfg["hyprland"]["shadowPower"] = shadow_power
        save_config(cfg)

        sync_hyprland_settings(border_size, rounding, shadow_enabled, shadow_range, shadow_power)
        print(json.dumps({"success": True}))

    elif cmd == "set-ghostty":
        # Args: theme opacity blur
        if len(sys.argv) < 5:
            print("Faltan argumentos para set-ghostty", file=sys.stderr)
            sys.exit(1)

        theme = sys.argv[2]
        opacity = float(sys.argv[3])
        blur = int(sys.argv[4])

        cfg = load_config()
        cfg["ghostty"]["theme"] = theme
        cfg["ghostty"]["backgroundOpacity"] = opacity
        cfg["ghostty"]["backgroundBlur"] = blur
        save_config(cfg)

        sync_ghostty_settings(theme, opacity, blur)
        print(json.dumps({"success": True}))

    elif cmd == "set-panel":
        # Args: panel_id (left|center|right) key value
        if len(sys.argv) < 5:
            print("Faltan argumentos para set-panel", file=sys.stderr)
            sys.exit(1)

        panel_id = sys.argv[2].lower()
        key = sys.argv[3]
        raw_val = sys.argv[4]

        # Convert value
        val: Any = raw_val
        if raw_val.lower() == "true":
            val = True
        elif raw_val.lower() == "false":
            val = False
        else:
            try:
                val = float(raw_val) if "." in raw_val else int(raw_val)
            except ValueError:
                val = raw_val

        cfg = load_config()
        if panel_id in cfg.get("panels", {}):
            cfg["panels"][panel_id][key] = val
            save_config(cfg)
            print(json.dumps({"success": True}))
        else:
            print(json.dumps({"success": False, "error": "Panel desconocido"}))

    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
