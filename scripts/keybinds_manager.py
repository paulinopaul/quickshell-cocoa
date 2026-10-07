#!/usr/bin/env python3
"""
keybinds_manager.py — Hyprland Keybindings Parser and Editor for Cocoa Shell.
Reads active compositor shortcuts via hyprctl binds -j and presents them in clean,
structured categories (Launchers, Windows, Workspaces, Media, System).

Editing surface (used by the Cocoa settings keybinds editor):
- list                 -> same read-only JSON the view depends on (default when no subcommand).
- add <mods> <key> <dispatcher> <arg>   -> persists "bind = ..." inside a managed section of
                                           hyprland.conf and applies it live via hyprctl bind.
- remove <mods> <key>                   -> deletes the matching managed line(s) and applies
                                           the removal live via hyprctl unbind.
- --config <path>       -> optional override of the hyprland.conf path (tests use temp files).

hyprctl failures are caught and reported as JSON, never crash the process.
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_CONF_PATH = Path.home() / ".config/hypr/hyprland.conf"
MANAGED_SECTION_MARKER = "# --- Keybindings gestionados por Cocoa ---"


def modmask_to_string(modmask: int) -> str:
    parts = []
    # Hyprland bitmasks:
    # 1: SHIFT, 4: CTRL, 8: ALT, 64: SUPER
    if modmask & 64:
        parts.append("SUPER")
    if modmask & 4:
        parts.append("CTRL")
    if modmask & 8:
        parts.append("ALT")
    if modmask & 1:
        parts.append("SHIFT")
    return " + ".join(parts)


def categorize_bind(dispatcher: str, arg: str, key: str) -> str:
    arg_lower = arg.lower()
    if "quickshell" in arg_lower or "launcher" in arg_lower or "flameshot" in arg_lower or dispatcher == "exec":
        return "Lanzadores y Aplicaciones"
    if "workspace" in dispatcher:
        return "Navegación de Escritorios"
    if dispatcher in ("killactive", "togglefloating", "fullscreen", "pin", "pseudo", "splitratio"):
        return "Gestión de Ventanas"
    if "volume" in arg_lower or "brightness" in arg_lower or "audiomic" in arg_lower:
        return "Multimedia y Hardware"
    return "Sistema y Otros"


def get_formatted_binds() -> List[Dict[str, Any]]:
    try:
        proc = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0:
            raw_binds = json.loads(proc.stdout)
            result = []
            seen = set()
            for b in raw_binds:
                mod_str = modmask_to_string(b.get("modmask", 0))
                key = b.get("key", "")
                if not key:
                    continue

                combo = f"{mod_str} + {key}" if mod_str else key
                dispatcher = b.get("dispatcher", "")
                arg = b.get("arg", "")
                desc = b.get("description", "")

                # Deduplicate exact combo + arg
                pair = (combo, dispatcher, arg)
                if pair in seen:
                    continue
                seen.add(pair)

                # Generate friendly explanation if description empty
                if not desc:
                    if "settings_dialog" in arg:
                        desc = "Abrir Configuración de Cocoa"
                    elif "wallpaper_selector" in arg:
                        desc = "Selector de Fondos de Pantalla"
                    elif "center_panel" in arg:
                        desc = "Panel Central / Flyout Telemetría"
                    elif "launcher" in arg:
                        desc = "Lanzador de Aplicaciones Cocoa"
                    elif "killactive" in dispatcher:
                        desc = "Cerrar ventana activa"
                    elif dispatcher == "workspace":
                        desc = f"Cambiar al escritorio {arg}"
                    elif dispatcher == "movetoworkspace":
                        desc = f"Mover ventana al escritorio {arg}"
                    elif "flameshot" in arg:
                        desc = "Captura de pantalla (Flameshot)"
                    elif "terminal" in arg or arg == "ghostty":
                        desc = "Lanzar Terminal"
                    elif "dolphin" in arg:
                        desc = "Gestor de Archivos (Dolphin)"
                    else:
                        desc = f"{dispatcher}: {arg}" if arg else dispatcher

                category = categorize_bind(dispatcher, arg, key)

                result.append({
                    "combo": combo,
                    "key": key,
                    "modifiers": mod_str,
                    "dispatcher": dispatcher,
                    "arg": arg,
                    "description": desc,
                    "category": category,
                })
            return result
    except Exception as e:
        print(f"Error parsing binds: {e}", file=sys.stderr)

    return []


def normalize_modifiers(raw: str) -> str:
    """Normalizes a comma/plus/space separated modifier string to Hyprland's space form.

    'SUPER,SHIFT' / 'SUPER+SHIFT' / 'SUPER SHIFT' -> 'SUPER SHIFT'; empty -> ''.
    """
    if not raw:
        return ""
    parts = re.split(r"[\s,+]", raw.strip().upper())
    return " ".join(p for p in parts if p)


def _parse_managed_bind(line: str) -> Optional[Tuple[str, str]]:
    """Parses a managed 'bind = MODS, KEY, ...' line into (mods, key)."""
    m = re.match(r"^[ \t]*bind[ \t]*=[ \t]*(.*)$", line)
    if not m:
        return None
    parts = m.group(1).split(",", 2)
    if len(parts) < 2:
        return None
    return normalize_modifiers(parts[0]), parts[1].strip()


def _ensure_managed_section(content: str) -> str:
    """Creates the managed keybind section once, after the last bind line, if absent."""
    if MANAGED_SECTION_MARKER in content:
        return content
    lines = content.split("\n")
    last_bind = -1
    for i, line in enumerate(lines):
        if re.match(r"^[ \t]*bindl?[ \t]*=", line):
            last_bind = i
    if last_bind >= 0:
        insert_idx = last_bind + 1
        while insert_idx < len(lines) and lines[insert_idx].strip() == "":
            insert_idx += 1
        lines.insert(insert_idx, "")
        lines.insert(insert_idx, MANAGED_SECTION_MARKER)
    else:
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append(MANAGED_SECTION_MARKER)
    return "\n".join(lines)


def _insert_managed_bind(content: str, line: str) -> str:
    """Inserts a bind line inside the managed section, right after its last bind."""
    content = _ensure_managed_section(content)
    if not content.endswith("\n"):
        content += "\n"
    lines = content.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    marker_idx = None
    last_managed_idx = None
    for i, l in enumerate(lines):
        if MANAGED_SECTION_MARKER in l:
            marker_idx = i
        elif marker_idx is not None and re.match(r"^[ \t]*bind[ \t]*=", l):
            last_managed_idx = i
    anchor = last_managed_idx if last_managed_idx is not None else marker_idx
    if anchor is None:
        lines.append(line)
    else:
        insert_idx = anchor + 1
        while insert_idx < len(lines) and lines[insert_idx].strip() == "":
            insert_idx += 1
        lines.insert(insert_idx, line)
    return "\n".join(lines) + "\n"


def _live_apply(parts: List[str]) -> Dict[str, Any]:
    """Runs a hyprctl command; never raises. Reports {'applied': bool, ...}."""
    try:
        proc = subprocess.run(["hyprctl"] + parts, capture_output=True, text=True, timeout=3)
        return {"applied": proc.returncode == 0, "output": (proc.stdout or "").strip()[:200]}
    except Exception as e:
        return {"applied": False, "error": str(e)}


def add_bind(mods_raw: str, key: str, dispatcher: str, arg: str, config_path: Optional[str] = None) -> Dict[str, Any]:
    """Persists a bind in the managed section and applies it live. Fail-soft."""
    mods = normalize_modifiers(mods_raw)
    key = key.strip()
    dispatcher = dispatcher.strip()
    arg = arg.strip()
    if not key or not dispatcher:
        return {"success": False, "error": "Tecla y disparador son obligatorios"}
    line = f"bind = {mods}, {key}, {dispatcher}, {arg}"
    path = Path(config_path) if config_path else DEFAULT_CONF_PATH
    try:
        content = path.read_text(encoding="utf-8") if path.exists() else ""
    except Exception as e:
        return {"success": False, "error": f"No se pudo leer {path}: {e}"}
    duplicate = bool(re.search(re.escape(line), content, re.IGNORECASE))
    if not duplicate:
        content = _insert_managed_bind(content, line)
        try:
            path.write_text(content, encoding="utf-8")
        except Exception as e:
            return {"success": False, "error": f"No se pudo escribir {path}: {e}"}
    live = _live_apply(["bind", f"{mods}, {key}, {dispatcher}, {arg}"])
    result: Dict[str, Any] = {
        "success": True,
        "duplicate": duplicate,
        "applied": live.get("applied", False),
    }
    if not live.get("applied") and "error" in live:
        result["warning"] = f"hyprctl: {live['error']}"
    return result


def remove_bind(mods_raw: str, key: str, config_path: Optional[str] = None) -> Dict[str, Any]:
    """Deletes matching managed bind line(s) and applies the removal live. Fail-soft."""
    mods = normalize_modifiers(mods_raw)
    key = key.strip()
    path = Path(config_path) if config_path else DEFAULT_CONF_PATH
    if not path.exists():
        return {"success": False, "error": f"No existe {path}"}
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as e:
        return {"success": False, "error": f"No se pudo leer {path}: {e}"}
    kept: List[str] = []
    removed = 0
    in_section = False
    for line in content.split("\n"):
        if MANAGED_SECTION_MARKER in line:
            in_section = True
            kept.append(line)
            continue
        if in_section:
            parts = _parse_managed_bind(line)
            if parts is None:
                if line.strip() != "":
                    in_section = False  # managed section ended
                kept.append(line)
                continue
            p_mods, p_key = parts
            if p_mods == mods and p_key.lower() == key.lower():
                removed += 1
                continue
        kept.append(line)
    try:
        path.write_text("\n".join(kept), encoding="utf-8")
    except Exception as e:
        return {"success": False, "error": f"No se pudo escribir {path}: {e}"}
    live = _live_apply(["unbind", f"{mods}, {key}"])
    result: Dict[str, Any] = {
        "success": True,
        "removed": removed,
        "applied": live.get("applied", False),
    }
    if not live.get("applied") and "error" in live:
        result["warning"] = f"hyprctl: {live['error']}"
    return result


def _parse_common_args(argv: List[str]) -> Tuple[Optional[str], List[str]]:
    """Extracts --config <path> from argv; returns (config_path, remaining args)."""
    config_path = None
    rest = list(argv)
    if "--config" in rest:
        i = rest.index("--config")
        if i + 1 < len(rest):
            config_path = rest[i + 1]
            del rest[i:i + 2]
        else:
            del rest[i]
    return config_path, rest


def main(argv: Optional[List[str]] = None) -> None:
    args = list(sys.argv[1:] if argv is None else argv)
    config_path, args = _parse_common_args(args)

    # No subcommand (or explicit "list") keeps the original read-only behavior,
    # byte-compatible with the JSON KeybindsView parses.
    if not args or args[0].lower() == "list":
        binds = get_formatted_binds()
        print(json.dumps(binds, separators=(',', ':')))
        return

    cmd = args[0].lower()
    if cmd == "add":
        if len(args) < 5:
            print(json.dumps({"success": False, "error": "Uso: add <mods> <key> <dispatcher> <arg>"}))
            sys.exit(1)
        result = add_bind(args[1], args[2], args[3], args[4], config_path)
        print(json.dumps(result, separators=(',', ':')))
    elif cmd == "remove":
        if len(args) < 3:
            print(json.dumps({"success": False, "error": "Uso: remove <mods> <key>"}))
            sys.exit(1)
        result = remove_bind(args[1], args[2], config_path)
        print(json.dumps(result, separators=(',', ':')))
    else:
        print(json.dumps({"success": False, "error": f"Comando desconocido: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
