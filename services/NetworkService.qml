pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool isConnected: false
    property bool isWifi: false
    property string ssid: ""
    property string displayString: "Offline"

    property var networks: []
    property bool isScanning: false
    property bool isConnecting: false
    property bool isDisconnecting: false
    property string connectionError: ""
    property string connectionSuccess: ""

    // Per-user IPC directory: prefers $XDG_RUNTIME_DIR, else /tmp/cocoa-$UID,
    // fail-soft to legacy /tmp. One-shot probe at startup; bash/python writers
    // (scripts/cocoa_ipc.sh, scripts/cocoa_ipc.py) resolve the same directory.
    property string _ipcDir: "/tmp"
    property Process _ipcDetect: Process {
        running: true
        command: ["sh", "-c", "if [ -n \"$XDG_RUNTIME_DIR\" ] && mkdir -p \"$XDG_RUNTIME_DIR\" 2>/dev/null && [ -w \"$XDG_RUNTIME_DIR\" ]; then printf '%s' \"$XDG_RUNTIME_DIR\"; else d=\"/tmp/cocoa-$(id -u 2>/dev/null || echo 0)\"; if mkdir -p \"$d\" 2>/dev/null && [ -w \"$d\" ]; then printf '%s' \"$d\"; else printf /tmp; fi; fi"]
        onExited: {
            let raw = stdout ? stdout.join("") : "";
            let dir = raw.trim();
            if (dir !== "") root._ipcDir = dir;
        }
    }

    property var statusFile: FileView { path: root._ipcDir + "/cocoa_status.txt" }
    property var wifiListFile: FileView { path: root._ipcDir + "/cocoa_wifi_list.json" }
    property var wifiStatusFile: FileView { path: root._ipcDir + "/cocoa_wifi_status.json" }

    // Portable script path: resolved relative to this file, no hardcoded home.
    readonly property string _wifiScript: Qt.resolvedUrl("../scripts/wifi_manager.py").toString().replace("file://", "")

    property Process scanProc: Process {
        command: ["python3", root._wifiScript, "scan"]
        running: false
        onExited: (exitCode) => {
            root.isScanning = false;
            root._loadWifiList();
        }
    }

    property Process connectProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.isConnecting = false;
            root._loadWifiStatus();
            root.scanNetworks();
        }
    }

    property Process disconnectProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.isDisconnecting = false;
            root._loadWifiStatus();
            root.scanNetworks();
        }
    }

    function _loadWifiList() {
        wifiListFile.reload();
        let raw = wifiListFile.text() || "";
        if (!raw.trim()) return;
        try {
            let data = JSON.parse(raw);
            if (Array.isArray(data)) {
                root.networks = data;
            }
        } catch (e) {}
    }

    function _loadWifiStatus() {
        wifiStatusFile.reload();
        let raw = wifiStatusFile.text() || "";
        if (!raw.trim()) return;
        try {
            let data = JSON.parse(raw);
            if (data.success) {
                root.connectionSuccess = data.message || "Conectado";
                root.connectionError = "";
            } else {
                root.connectionError = data.message || "Error al conectar";
                root.connectionSuccess = "";
            }
        } catch (e) {}
    }

    function scanNetworks() {
        if (isScanning) return;
        isScanning = true;
        scanProc.running = true;
    }

    function connectToNetwork(targetSsid, password) {
        if (isConnecting || !targetSsid) return;
        isConnecting = true;
        connectionError = "";

        connectionSuccess = "";
        let args = ["python3", root._wifiScript, "connect", targetSsid];
        if (password && password.trim() !== "") {
            args.push(password.trim());
        }
        connectProc.command = args;
        connectProc.running = true;
    }

    function disconnectFromNetwork(targetSsid) {
        if (isDisconnecting) return;
        isDisconnecting = true;
        connectionError = "";
        connectionSuccess = "";
        let args = ["python3", root._wifiScript, "disconnect"];
        if (targetSsid && targetSsid.trim() !== "") {
            args.push(targetSsid.trim());
        }
        disconnectProc.command = args;
        disconnectProc.running = true;
    }

    property Timer pollTimer: Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            root.statusFile.reload();
            let out = root.statusFile.text() || "";
            if (!out) return;
            
            let parts = out.split('|');
            let wifiStr = parts[2] || "";
            let ethStr = parts[3] || "0";

            if (ethStr.trim() === "1") {
                root.isConnected = true;
                root.isWifi = false;
                root.ssid = "Ethernet";
                root.displayString = "LAN";
            } else if (wifiStr.trim() !== "") {
                root.isConnected = true;
                root.isWifi = true;
                root.ssid = wifiStr.trim();
                root.displayString = root.ssid.substring(0, 10);
            } else {
                root.isConnected = false;
                root.isWifi = false;
                root.ssid = "";
                root.displayString = "Off";
            }
        }
    }
}

