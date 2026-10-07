pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AntigravityService — Consumidor del estado canónico de Antigravity.
//
// Lee <ipc-dir>/agy_state.json generado por agy_state_writer.sh (hook de AGY),
// donde <ipc-dir> es el directorio IPC por usuario ($XDG_RUNTIME_DIR o
// /tmp/cocoa-$UID, fail-soft a /tmp legacy).
// Expone propiedades reactivas para CenterCapsule y CenterFlyout.
//
// Estados posibles:
//   "idle"               — AGY en reposo
//   "thinking"           — AGY procesando (entre herramientas)
//   "working"            — AGY ejecutando una herramienta
//   "awaiting_approval"  — AGY esperando confirmación del usuario

QtObject {
    id: root

    // ── Propiedades públicas ──────────────────────────────────────────────
    readonly property bool isActive:            state !== "idle"
    readonly property bool isWorking:           state === "working"
    readonly property bool isThinking:          state === "thinking"
    readonly property bool awaitingApproval:    state === "awaiting_approval"

    property string state:          "idle"
    property string action:         "Listo."
    property string tool:           ""
    property string command:        ""
    property string summary:        ""
    property var    history:        []
    property int    lastTs:         0

    // ── Lectura del archivo de estado (directorio IPC por usuario) ─────────
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
    property FileView stateFile: FileView {
        path: root._ipcDir + "/agy_state.json"
    }

    // ── Polling a 500ms ───────────────────────────────────────────────────
    property Timer pollTimer: Timer {
        interval: 500
        running:  true
        repeat:   true
        onTriggered: {
            root.stateFile.reload();
            let raw = root.stateFile.text() || "";
            if (raw.trim() === "") return;

            let data;
            try {
                data = JSON.parse(raw);
            } catch (e) {
                return; // JSON malformado — ignorar sin romper
            }

            // Ignorar si el timestamp no cambió (evita re-renders innecesarios)
            if (data.ts === root.lastTs) return;
            root.lastTs = data.ts || 0;

            root.state   = data.state   || "idle";
            root.action  = data.action  || "Listo.";
            root.tool    = data.tool    || "";
            root.command = data.command || "";
            root.summary = data.summary || "";
            root.history = data.history || [];
        }
    }
}
