pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AntigravityService — Consumidor del estado canónico de Antigravity.
//
// Lee /tmp/agy_state.json generado por agy_state_writer.sh (hook de AGY).
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

    // ── Lectura del archivo de estado ─────────────────────────────────────
    property FileView stateFile: FileView {
        path: "/tmp/agy_state.json"
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
