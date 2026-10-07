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

    property var statusFile: FileView { path: "/tmp/cocoa_status.txt" }
    property var wifiListFile: FileView { path: "/tmp/cocoa_wifi_list.json" }
    property var wifiStatusFile: FileView { path: "/tmp/cocoa_wifi_status.json" }

    property Process scanProc: Process {
        command: ["python3", "/home/paul/.config/quickshell/cocoa/scripts/wifi_manager.py", "scan"]
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
        let args = ["python3", "/home/paul/.config/quickshell/cocoa/scripts/wifi_manager.py", "connect", targetSsid];
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
        let args = ["python3", "/home/paul/.config/quickshell/cocoa/scripts/wifi_manager.py", "disconnect"];
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

