#!/usr/bin/env python3
"""
default_apps_manager.py — Default Applications Query & Setter for Cocoa Shell.
Manages Terminal, Web Browser, File Manager, and Code Editor preferences across
Hyprland configuration ($terminal) and XDG MIME associations.
"""

import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

HYPR_CONF = Path.home() / ".config/hypr/hyprland.conf"


def find_installed_apps() -> List[Dict[str, str]]:
    """Discovers installed applications from desktop entry files."""
    desktop_dirs = [
        Path("/usr/share/applications"),
        Path.home() / ".local/share/applications",
    ]
    apps: Dict[str, Dict[str, str]] = {}

    for d in desktop_dirs:
        if not d.exists():
            continue
        for p in d.glob("*.desktop"):
            try:
                name = None
                exec_cmd = None
                categories = ""
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        if line.startswith("Name=") and not name:
                            name = line.split("=", 1)[1].strip()
                        elif line.startswith("Exec=") and not exec_cmd:
                            raw = line.split("=", 1)[1].strip()
                            exec_cmd = re.sub(r"%[a-zA-Z]", "", raw).strip()
                        elif line.startswith("Categories="):
                            categories = line.split("=", 1)[1].strip()
                if name and exec_cmd:
                    apps[p.stem] = {
                        "id": p.stem,
                        "name": name,
                        "exec": exec_cmd,
                        "categories": categories,
                        "desktopFile": p.name,
                    }
            except Exception:
                pass

    return list(apps.values())


def get_current_defaults() -> Dict[str, Any]:
    defaults = {
        "terminal": "ghostty",
        "browser": "google-chrome-stable",
        "fileManager": "dolphin",
        "editor": "code",
    }

    # 1. Parse hyprland.conf for $terminal and other vars
    if HYPR_CONF.exists():
        try:
            content = HYPR_CONF.read_text(encoding="utf-8")
            m_term = re.search(r"^\$terminal\s*=\s*(.+)$", content, re.MULTILINE)
            if m_term:
                defaults["terminal"] = m_term.group(1).strip()
            m_fm = re.search(r"^\$fileManager\s*=\s*(.+)$", content, re.MULTILINE)
            if m_fm:
                defaults["fileManager"] = m_fm.group(1).strip()
            m_br = re.search(r"^\$browser\s*=\s*(.+)$", content, re.MULTILINE)
            if m_br:
                defaults["browser"] = m_br.group(1).strip()
            m_ed = re.search(r"^\$editor\s*=\s*(.+)$", content, re.MULTILINE)
            if m_ed:
                defaults["editor"] = m_ed.group(1).strip()
        except Exception:
            pass

    # 2. Query xdg-mime for browser and fileManager
    try:
        proc_br = subprocess.run(["xdg-mime", "query", "default", "x-scheme-handler/https"], capture_output=True, text=True, timeout=2)
        if proc_br.returncode == 0 and proc_br.stdout.strip():
            defaults["browser"] = proc_br.stdout.strip().replace(".desktop", "")
    except Exception:
        pass

    try:
        proc_fm = subprocess.run(["xdg-mime", "query", "default", "inode/directory"], capture_output=True, text=True, timeout=2)
        if proc_fm.returncode == 0 and proc_fm.stdout.strip():
            defaults["fileManager"] = proc_fm.stdout.strip().replace(".desktop", "")
    except Exception:
        pass

    # Candidates
    candidates = {
        "terminal": ["ghostty", "alacritty", "kitty", "foot", "wezterm", "gnome-terminal"],
        "browser": ["google-chrome", "google-chrome-stable", "firefox", "brave-browser", "chromium", "zen-browser"],
        "fileManager": ["dolphin", "nautilus", "thunar", "nemo", "pcmanfm"],
        "editor": ["code", "cursor", "nvim", "kate", "gedit", "sublime_text"],
    }

    # Filter candidates by what's actually installed in PATH
    installed_candidates = {}
    for cat, list_apps in candidates.items():
        found = []
        for app in list_apps:
            cmd = app.split()[0]
            if subprocess.run(["which", cmd], capture_output=True).returncode == 0:
                found.append(app)
        if not found:
            found = list_apps[:2]
        installed_candidates[cat] = found

    return {
        "current": defaults,
        "candidates": installed_candidates,
    }


def set_default_app(category: str, app_name: str) -> bool:
    app_clean = app_name.strip()

    if category == "terminal":
        # Update hyprland.conf $terminal and env = TERMINAL
        if HYPR_CONF.exists():
            content = HYPR_CONF.read_text(encoding="utf-8")
            content = re.sub(r"^\$terminal\s*=.*$", f"$terminal = {app_clean}", content, flags=re.MULTILINE)
            content = re.sub(r"^env\s*=\s*TERMINAL,.*$", f"env = TERMINAL,{app_clean}", content, flags=re.MULTILINE)
            HYPR_CONF.write_text(content, encoding="utf-8")
        return True

    elif category == "browser":
        desktop_file = app_clean if app_clean.endswith(".desktop") else f"{app_clean}.desktop"
        subprocess.run(["xdg-mime", "default", desktop_file, "x-scheme-handler/http"], capture_output=True)
        subprocess.run(["xdg-mime", "default", desktop_file, "x-scheme-handler/https"], capture_output=True)
        subprocess.run(["xdg-mime", "default", desktop_file, "text/html"], capture_output=True)
        return True

    elif category == "fileManager":
        desktop_file = app_clean if app_clean.endswith(".desktop") else f"{app_clean}.desktop"
        subprocess.run(["xdg-mime", "default", desktop_file, "inode/directory"], capture_output=True)
        return True

    elif category == "editor":
        desktop_file = app_clean if app_clean.endswith(".desktop") else f"{app_clean}.desktop"
        subprocess.run(["xdg-mime", "default", desktop_file, "text/plain"], capture_output=True)
        return True

    return False


def main():
    if len(sys.argv) < 2:
        print("Uso: default_apps_manager.py <get|set <category> <app>>")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "get":
        print(json.dumps(get_current_defaults(), separators=(',', ':')))
    elif cmd == "set":
        if len(sys.argv) < 4:
            sys.exit(1)
        ok = set_default_app(sys.argv[2], sys.argv[3])
        print(json.dumps({"success": ok}))
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
