#!/usr/bin/env python3
"""
hyprland_config_manager.py — Hyprland Core Config Editor for Cocoa Shell.

Curated config surface exposed by the "Hyprland y Sistema" settings tab:
- Gaps: general:gaps_in / general:gaps_out (0-30 / 0-60 sliders in the UI).
- Keyboard layout: input:kb_layout.
- Misc flags: misc:focus_on_activate, misc:disable_hyprland_logo, misc:disable_splash_rendering.
- Autostart: exec-once commands (deduped add / remove).

Persistence mirrors visual_config_manager.py: regex section rewrite inside
hyprland.conf + live hyprctl keyword application. All hyprctl failures are
caught and reported inside the JSON result — never crash the process.

CLI:
  get                                                       -> curated values as JSON
  set <key> <value>                                         -> apply + persist one key
  autostart <add|remove> <command>                          -> manage exec-once entries
  --config <path>                                           -> optional conf path (tests)
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

DEFAULT_CONF_PATH = Path.home() / ".config/hypr/hyprland.conf"

# key -> hyprctl option, value kind, conf line regex, owning section
CURATED: Dict[str, Dict[str, str]] = {
    "gaps_in": {
        "option": "general:gaps_in",
        "kind": "int",
        "regex": r"^[ \t]*gaps_in[ \t]*=[ \t]*(\d+)",
        "section": "general",
    },
    "gaps_out": {
        "option": "general:gaps_out",
        "kind": "int",
        "regex": r"^[ \t]*gaps_out[ \t]*=[ \t]*(\d+)",
        "section": "general",
    },
    "kb_layout": {
        "option": "input:kb_layout",
        "kind": "str",
        "regex": r"^[ \t]*kb_layout[ \t]*=[ \t]*(\S+)",
        "section": "input",
    },
    "focus_on_activate": {
        "option": "misc:focus_on_activate",
        "kind": "bool",
        "regex": r"^[ \t]*focus_on_activate[ \t]*=[ \t]*(true|false|1|0)",
        "section": "misc",
    },
    "disable_hyprland_logo": {
        "option": "misc:disable_hyprland_logo",
        "kind": "bool",
        "regex": r"^[ \t]*disable_hyprland_logo[ \t]*=[ \t]*(true|false|1|0)",
        "section": "misc",
    },
    "disable_splash_rendering": {
        "option": "misc:disable_splash_rendering",
        "kind": "bool",
        "regex": r"^[ \t]*disable_splash_rendering[ \t]*=[ \t]*(true|false|1|0)",
        "section": "misc",
    },
}

AUTOSTART_RE = re.compile(r"^[ \t]*exec-once[ \t]*=[ \t]*(.+?)\s*$", re.MULTILINE)


def _getoption_value(option: str, kind: str) -> Optional[Any]:
    """Reads a value via hyprctl getoption -j; None on any failure."""
    try:
        proc = subprocess.run(["hyprctl", "getoption", option, "-j"], capture_output=True, text=True, timeout=2)
        if proc.returncode != 0:
            return None
        data = json.loads(proc.stdout)
    except Exception:
        return None
    if kind == "int":
        if "int" in data:
            return data["int"]
        # gaps options come back as custom: "5 5 5 5" — first number is the value
        raw = data.get("custom") or data.get("str") or ""
        m = re.match(r"-?\d+", str(raw).strip())
        return int(m.group(0)) if m else None
    if kind == "bool":
        return bool(data.get("int", 0)) if "int" in data else None
    return data.get("str") or data.get("custom")


def _parse_conf_value(key: str, content: str) -> Optional[Any]:
    """Parses one curated key from hyprland.conf text; None when absent."""
    info = CURATED[key]
    m = re.search(info["regex"], content, re.MULTILINE)
    if not m:
        return None
    raw = m.group(1)
    if info["kind"] == "int":
        return int(raw)
    if info["kind"] == "bool":
        return raw.lower() in ("true", "1", "yes")
    return raw.strip()


def _parse_autostart(content: str) -> List[str]:
    """Extracts the list of exec-once commands (commented lines are ignored)."""
    return [m.group(1).strip() for m in AUTOSTART_RE.finditer(content)]


def _read_conf(config_path: Optional[str]) -> str:
    path = Path(config_path) if config_path else DEFAULT_CONF_PATH
    try:
        return path.read_text(encoding="utf-8") if path.exists() else ""
    except Exception:
        return ""


def _write_conf(config_path: Optional[str], content: str) -> None:
    path = Path(config_path) if config_path else DEFAULT_CONF_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def get_values(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Returns the curated values; prefers hyprctl getoption, falls back to conf parse."""
    content = _read_conf(config_path)
    values: Dict[str, Any] = {}
    source = "hyprctl"
    for key, info in CURATED.items():
        val = _getoption_value(info["option"], info["kind"])
        if val is None:
            source = "conf"
            val = _parse_conf_value(key, content)
            if val is None:
                val = 0 if info["kind"] == "int" else (False if info["kind"] == "bool" else "")
        values[key] = val
    values["autostart"] = _parse_autostart(content)
    values["source"] = source
    return values


def _live_keyword(option: str, value: str) -> Dict[str, Any]:
    """hyprctl keyword; never raises."""
    try:
        proc = subprocess.run(["hyprctl", "keyword", option, value], capture_output=True, text=True, timeout=2)
        return {"applied": proc.returncode == 0, "output": (proc.stdout or "").strip()[:200]}
    except Exception as e:
        return {"applied": False, "error": str(e)}


def _section_bounds(content: str, section: str) -> Optional[Any]:
    """Returns (start, end) of a '{ ... }' section, or None if the section is absent."""
    m = re.search(rf"^[ \t]*{re.escape(section)}[ \t]*\{{", content, re.MULTILINE)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    while i < len(content) and depth > 0:
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
        i += 1
    return (start, i - 1) if depth == 0 else (start, None)


def _rewrite_option(content: str, key: str, info: Dict[str, str], conf_text: str) -> str:
    """Regex-updates the key line in hyprland.conf; creates the section when missing."""
    line_re = re.compile(rf"^([ \t]*){re.escape(key)}[ \t]*=.*$", re.MULTILINE)
    if line_re.search(content):
        return line_re.sub(lambda m: f"{m.group(1)}{key} = {conf_text}", content, count=1)
    entry = f"    {key} = {conf_text}"
    bounds = _section_bounds(content, info["section"])
    if bounds and bounds[1] is not None:
        start, end = bounds
        return content[:end] + entry + "\n" + content[end:]
    if content and not content.endswith("\n"):
        content += "\n"
    return content + f"{info['section']} {{\n{entry}\n}}\n"


def set_value(key: str, raw_value: str, config_path: Optional[str] = None) -> Dict[str, Any]:
    """Applies one curated key live via hyprctl keyword and persists it. Fail-soft."""
    key = key.lower()
    if key not in CURATED:
        return {"success": False, "error": f"Opción desconocida: {key}"}
    info = CURATED[key]
    kind = info["kind"]
    if kind == "int":
        try:
            value = int(raw_value)
        except ValueError:
            return {"success": False, "error": f"{key} debe ser un número entero"}
        conf_text = str(value)
    elif kind == "bool":
        lowered = raw_value.strip().lower()
        if lowered in ("true", "1", "yes", "on"):
            value, conf_text = True, "true"
        elif lowered in ("false", "0", "no", "off"):
            value, conf_text = False, "false"
        else:
            return {"success": False, "error": f"{key} debe ser true o false"}
    else:
        value = " ".join(raw_value.split()) if raw_value else ""
        conf_text = value
    if not conf_text:
        return {"success": False, "error": f"{key} no puede estar vacío"}

    live = _live_keyword(info["option"], conf_text)
    content = _read_conf(config_path)
    try:
        _write_conf(config_path, _rewrite_option(content, key, info, conf_text))
    except Exception as e:
        return {"success": False, "error": f"No se pudo escribir la configuración: {e}"}

    result: Dict[str, Any] = {"success": True, "key": key, "value": value, "applied": live.get("applied", False)}
    if not live.get("applied") and "error" in live:
        result["warning"] = f"hyprctl: {live['error']}"
    return result


def manage_autostart(action: str, command: str, config_path: Optional[str] = None) -> Dict[str, Any]:
    """Adds (deduped) or removes an exec-once command in hyprland.conf. No live apply."""
    action = action.lower()
    command = command.strip()
    if not command:
        return {"success": False, "error": "Comando vacío"}
    if action not in ("add", "remove"):
        return {"success": False, "error": f"Acción desconocida: {action} (use add|remove)"}
    content = _read_conf(config_path)
    lines = content.split("\n")
    removed = 0
    if action == "add":
        for line in lines:
            m = AUTOSTART_RE.match(line)
            if m and m.group(1).strip().lower() == command.lower():
                return {"success": True, "action": "add", "duplicate": True, "removed": 0}
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append(f"exec-once = {command}")
    else:
        kept: List[str] = []
        for line in lines:
            m = AUTOSTART_RE.match(line)
            if m and m.group(1).strip().lower() == command.lower():
                removed += 1
                continue
            kept.append(line)
        lines = kept
    new_content = "\n".join(lines)
    if new_content and not new_content.endswith("\n"):
        new_content += "\n"
    try:
        _write_conf(config_path, new_content)
    except Exception as e:
        return {"success": False, "error": f"No se pudo escribir la configuración: {e}"}
    result: Dict[str, Any] = {"success": True, "action": action, "removed": removed}
    if action == "add":
        result["duplicate"] = False
    return result


def _parse_common_args(argv: List[str]) -> Any:
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
    if not args:
        print(json.dumps({"success": False, "error": "Uso: hyprland_config_manager.py <get|set|autostart> [args] [--config <path>]"}))
        sys.exit(1)
    cmd = args[0].lower()
    if cmd == "get":
        print(json.dumps(get_values(config_path), separators=(',', ':')))
    elif cmd == "set":
        if len(args) < 3:
            print(json.dumps({"success": False, "error": "Uso: set <key> <value>"}))
            sys.exit(1)
        result = set_value(args[1], " ".join(args[2:]), config_path)
        print(json.dumps(result, separators=(',', ':')))
    elif cmd == "autostart":
        if len(args) < 3:
            print(json.dumps({"success": False, "error": "Uso: autostart <add|remove> <comando>"}))
            sys.exit(1)
        result = manage_autostart(args[1], " ".join(args[2:]), config_path)
        print(json.dumps(result, separators=(',', ':')))
    else:
        print(json.dumps({"success": False, "error": f"Comando desconocido: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()