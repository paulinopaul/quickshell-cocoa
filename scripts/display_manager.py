#!/usr/bin/env python3
"""
display_manager.py — Monitor & Resolution Manager for Cocoa Shell on Hyprland.
Queries connected monitors, available resolutions, refresh rates, and scaling,
and applies changes live via hyprctl while updating hyprland.conf.
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

HYPR_CONF = Path.home() / ".config/hypr/hyprland.conf"


def get_monitors() -> List[Dict[str, Any]]:
    try:
        proc = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0:
            data = json.loads(proc.stdout)
            result = []
            for m in data:
                result.append({
                    "id": m.get("id", 0),
                    "name": m.get("name", "eDP-1"),
                    "description": m.get("description", ""),
                    "width": m.get("width", 1920),
                    "height": m.get("height", 1080),
                    "refreshRate": round(float(m.get("refreshRate", 60.0)), 1),
                    "scale": float(m.get("scale", 1.0)),
                    "availableModes": m.get("availableModes", ["1920x1080@144.00Hz", "1920x1080@60.00Hz"]),
                    "focused": m.get("focused", False),
                })
            return result
    except Exception as e:
        print(f"Error querying monitors: {e}", file=sys.stderr)

    return [{
        "id": 0,
        "name": "eDP-1",
        "description": "Default Display",
        "width": 1920,
        "height": 1080,
        "refreshRate": 144.0,
        "scale": 1.0,
        "availableModes": ["1920x1080@144.00Hz", "1920x1080@60.00Hz"],
        "focused": True,
    }]


def set_monitor_config(name: str, width: int, height: int, refresh_rate: float, scale: float) -> bool:
    res_str = f"{width}x{height}@{int(refresh_rate)}"
    rule_str = f"{name},{res_str},0x0,{scale}"

    # Live hyprctl apply
    try:
        subprocess.run(["hyprctl", "keyword", "monitor", rule_str], capture_output=True, timeout=3)
    except Exception as e:
        print(f"Error executing hyprctl: {e}", file=sys.stderr)

    # Persist in hyprland.conf
    if HYPR_CONF.exists():
        try:
            content = HYPR_CONF.read_text(encoding="utf-8")
            pattern = re.compile(rf"^monitor\s*=\s*{re.escape(name)},.*$", re.MULTILINE)
            new_line = f"monitor={name},{res_str},0x0,{scale}"
            if pattern.search(content):
                updated = pattern.sub(new_line, content)
            else:
                updated = content.replace("# --- Monitor ---", f"# --- Monitor ---\n{new_line}")
            HYPR_CONF.write_text(updated, encoding="utf-8")
            return True
        except Exception as e:
            print(f"Error saving to hyprland.conf: {e}", file=sys.stderr)

    return True


def main():
    if len(sys.argv) < 2:
        print("Uso: display_manager.py <list|set <name> <width> <height> <hz> <scale>>")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "list":
        mons = get_monitors()
        print(json.dumps(mons, separators=(',', ':')))
    elif cmd == "set":
        if len(sys.argv) < 7:
            print("Faltan parámetros", file=sys.stderr)
            sys.exit(1)
        name = sys.argv[2]
        w = int(sys.argv[3])
        h = int(sys.argv[4])
        hz = float(sys.argv[5])
        scale = float(sys.argv[6])
        ok = set_monitor_config(name, w, h, hz, scale)
        print(json.dumps({"success": ok}))
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
