#!/usr/bin/env python3
"""
wifi_manager.py — Wi-Fi Network Scanner and Connection Manager for Cocoa Shell.
Interacts with NetworkManager via nmcli, producing clean JSON data for QML consumption.
"""

import json
import os
import subprocess
import sys
from typing import Dict, List, Optional

try:
    from scripts.cocoa_ipc import ipc_path
except ImportError:  # standalone execution (scripts/ is sys.path[0])
    from cocoa_ipc import ipc_path

WIFI_LIST_FILE = ipc_path("cocoa_wifi_list.json")
WIFI_STATUS_FILE = ipc_path("cocoa_wifi_status.json")


def parse_nmcli_wifi_list(output: str) -> List[Dict[str, object]]:
    """
    Parses nmcli multiline output (-m multiline -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list).
    Returns deduplicated list sorted by (inUse DESC, signal DESC).
    """
    if not output:
        return []

    networks: List[Dict[str, object]] = []
    current: Dict[str, object] = {}

    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or ":" not in line:
            continue

        key, val = line.split(":", 1)
        key = key.strip()
        val = val.strip()

        if key == "IN-USE":
            if current.get("ssid"):
                networks.append(current)
            current = {"inUse": (val == "*"), "ssid": "", "signal": 0, "security": ""}
        elif key == "SSID":
            current["ssid"] = val
        elif key == "SIGNAL":
            try:
                current["signal"] = max(0, min(100, int(val)))
            except ValueError:
                current["signal"] = 0
        elif key == "SECURITY":
            current["security"] = val

    if current.get("ssid"):
        networks.append(current)

    # Deduplicate by SSID, preferring connected network or higher signal
    unique_map: Dict[str, Dict[str, object]] = {}
    for net in networks:
        ssid = str(net.get("ssid", "")).strip()
        if not ssid or ssid == "--":
            continue

        if ssid not in unique_map:
            unique_map[ssid] = net
        else:
            existing = unique_map[ssid]
            # Replace if new is connected, or existing is not connected and new has better signal
            if net.get("inUse") or (not existing.get("inUse") and int(net.get("signal", 0)) > int(existing.get("signal", 0))):
                unique_map[ssid] = net

    result = list(unique_map.values())
    result.sort(key=lambda x: (not bool(x.get("inUse")), -int(x.get("signal", 0))))
    return result


def scan_networks() -> List[Dict[str, object]]:
    """Runs nmcli wifi scan and writes atomic JSON output."""
    cmd = [
        "nmcli",
        "-m", "multiline",
        "-f", "IN-USE,SSID,SIGNAL,SECURITY",
        "dev", "wifi", "list",
        "--rescan", "auto"
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
        networks = parse_nmcli_wifi_list(proc.stdout)
    except Exception as e:
        networks = []

    # Write atomic JSON
    tmp_path = WIFI_LIST_FILE + ".tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(networks, f, indent=2)
        os.replace(tmp_path, WIFI_LIST_FILE)
    except Exception:
        pass

    return networks


def connect_network(ssid: str, password: Optional[str] = None) -> Dict[str, object]:
    """Attempts connection to a given SSID using nmcli."""
    if not ssid or not ssid.strip():
        result = {"success": False, "message": "SSID vacío", "ssid": ""}
        _write_status(result)
        return result

    target_ssid = ssid.strip()
    cmd = ["nmcli", "dev", "wifi", "connect", target_ssid]
    if password and password.strip():
        cmd.extend(["password", password.strip()])

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if proc.returncode == 0:
            result = {
                "success": True,
                "message": f"Conectado a {target_ssid}",
                "ssid": target_ssid
            }
        else:
            err_msg = (proc.stderr or proc.stdout or "Error desconocido").strip()
            # Clean up common nmcli error messages for user-friendly display
            if "Secrets were required" in err_msg or "password" in err_msg.lower() or "contraseña" in err_msg.lower():
                err_msg = "Contraseña incorrecta o requerida"
            elif "no se encontró" in err_msg.lower() or "not found" in err_msg.lower():
                err_msg = "Red no encontrada o fuera de alcance"
            result = {
                "success": False,
                "message": err_msg,
                "ssid": target_ssid
            }
    except subprocess.TimeoutExpired:
        result = {
            "success": False,
            "message": "Tiempo de espera agotado al conectar",
            "ssid": target_ssid
        }
    except Exception as e:
        result = {
            "success": False,
            "message": str(e),
            "ssid": target_ssid
        }

    _write_status(result)
    # Refresh wifi list after connection attempt
    scan_networks()
    return result


def disconnect_network(target_ssid: Optional[str] = None) -> Dict[str, object]:
    """
    Disconnects the active Wi-Fi connection using nmcli.
    """
    try:
        if target_ssid:
            cmd = ["nmcli", "connection", "down", "id", target_ssid]
        else:
            # Query active wifi device
            dev_proc = subprocess.run(
                ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"],
                capture_output=True,
                text=True,
                timeout=5
            )
            wifi_dev = None
            for line in dev_proc.stdout.splitlines():
                parts = line.split(":")
                if len(parts) >= 3 and parts[1] == "wifi" and "connected" in parts[2]:
                    wifi_dev = parts[0]
                    break
            
            if wifi_dev:
                cmd = ["nmcli", "device", "disconnect", wifi_dev]
            else:
                cmd = ["nmcli", "device", "disconnect", "wlo1"]

        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        success = (proc.returncode == 0)
        msg = "Desconectado correctamente" if success else (proc.stderr or proc.stdout or "Error al desconectar").strip()
        result = {
            "success": success,
            "message": msg,
            "action": "disconnect"
        }
    except Exception as e:
        result = {
            "success": False,
            "message": str(e),
            "action": "disconnect"
        }

    _write_status(result)
    scan_networks()
    return result


def _write_status(data: Dict[str, object]) -> None:
    tmp_path = WIFI_STATUS_FILE + ".tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, WIFI_STATUS_FILE)
    except Exception:
        pass


def main():
    if len(sys.argv) < 2:
        print("Uso: wifi_manager.py <scan|connect|disconnect> [ssid] [password]")
        sys.exit(1)

    action = sys.argv[1].lower()
    if action == "scan":
        nets = scan_networks()
        print(json.dumps(nets, indent=2))
    elif action == "connect":
        if len(sys.argv) < 3:
            print("Error: falta SSID")
            sys.exit(1)
        ssid = sys.argv[2]
        pwd = sys.argv[3] if len(sys.argv) > 3 else None
        res = connect_network(ssid, pwd)
        print(json.dumps(res, indent=2))
        if not res["success"]:
            sys.exit(1)
    elif action == "disconnect":
        ssid = sys.argv[2] if len(sys.argv) > 2 else None
        res = disconnect_network(ssid)
        print(json.dumps(res, indent=2))
        if not res["success"]:
            sys.exit(1)
    else:
        print(f"Acción desconocida: {action}")
        sys.exit(1)


if __name__ == "__main__":
    main()
