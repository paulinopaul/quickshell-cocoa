#!/usr/bin/env python3
"""
audio_manager.py — PipeWire & wpctl Audio Device Manager for Cocoa Shell.
Provides JSON enumeration of audio Sinks (Outputs) and Sources (Inputs/Microphones),
and allows setting default devices, volume, and mute states.
"""

import json
import re
import subprocess
import sys
from typing import Any, Dict, List


def parse_wpctl_status(output: str) -> Dict[str, List[Dict[str, Any]]]:
    sinks: List[Dict[str, Any]] = []
    sources: List[Dict[str, Any]] = []

    current_section = None
    in_audio = False

    for line in output.splitlines():
        trimmed = line.strip()

        if "Audio" in line and "Devices:" in output:
            in_audio = True

        if not in_audio:
            continue

        if "Video" in line:
            break

        if "Sinks:" in line:
            current_section = "sinks"
            continue
        elif "Sources:" in line:
            current_section = "sources"
            continue
        elif "Filters:" in line or "Streams:" in line:
            current_section = None
            continue

        if current_section in ("sinks", "sources"):
            # Match lines like: │  *   58. Audio Interno Estéreo analógico   [vol: 0.00]
            # or:               │      58. Audio Interno Estéreo analógico   [vol: 0.00 MUTED]
            m = re.search(r"([*]?)\s*(\d+)\.\s*(.*?)\s*\[vol:\s*([0-9.]+)(?:\s*(MUTED))?\]", line)
            if m:
                is_default = bool(m.group(1))
                device_id = int(m.group(2))
                name = m.group(3).strip()
                vol = float(m.group(4))
                is_muted = bool(m.group(5))

                entry = {
                    "id": device_id,
                    "name": name,
                    "isDefault": is_default,
                    "volume": vol,
                    "isMuted": is_muted,
                }

                if current_section == "sinks":
                    sinks.append(entry)
                else:
                    sources.append(entry)

    return {"sinks": sinks, "sources": sources}


def get_audio_devices() -> Dict[str, List[Dict[str, Any]]]:
    try:
        proc = subprocess.run(["wpctl", "status"], capture_output=True, text=True, timeout=4)
        if proc.returncode == 0:
            return parse_wpctl_status(proc.stdout)
    except Exception as e:
        print(f"Error querying wpctl status: {e}", file=sys.stderr)

    return {"sinks": [], "sources": []}


def set_default(device_id: int) -> bool:
    try:
        proc = subprocess.run(["wpctl", "set-default", str(device_id)], capture_output=True, timeout=3)
        return proc.returncode == 0
    except Exception:
        return False


def set_volume(device_id: int, vol: float) -> bool:
    try:
        vol_clamped = max(0.0, min(1.5, vol))
        proc = subprocess.run(["wpctl", "set-volume", str(device_id), f"{vol_clamped:.2f}"], capture_output=True, timeout=3)
        return proc.returncode == 0
    except Exception:
        return False


def toggle_mute(device_id: int) -> bool:
    try:
        proc = subprocess.run(["wpctl", "set-mute", str(device_id), "toggle"], capture_output=True, timeout=3)
        return proc.returncode == 0
    except Exception:
        return False


def main():
    if len(sys.argv) < 2:
        print("Uso: audio_manager.py <list|set-default <id>|set-volume <id> <vol>|toggle-mute <id>>")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "list":
        devs = get_audio_devices()
        print(json.dumps(devs, separators=(',', ':')))
    elif cmd == "set-default":
        if len(sys.argv) < 3:
            sys.exit(1)
        ok = set_default(int(sys.argv[2]))
        print(json.dumps({"success": ok}))
    elif cmd == "set-volume":
        if len(sys.argv) < 4:
            sys.exit(1)
        ok = set_volume(int(sys.argv[2]), float(sys.argv[3]))
        print(json.dumps({"success": ok}))
    elif cmd == "toggle-mute":
        if len(sys.argv) < 3:
            sys.exit(1)
        ok = toggle_mute(int(sys.argv[2]))
        print(json.dumps({"success": ok}))
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
