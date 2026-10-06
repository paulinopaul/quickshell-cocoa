pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property real volume: 0.0
    property bool isMuted: false
    property bool isMicMuted: false

    signal volumeChangedExplicitly()
    signal micToggled()

    property var statusFile: FileView { path: "/tmp/cocoa_status.txt" }

    // Sondeo de alta frecuencia a buffer en memoria RAM (/tmp)
    property Timer pollTimer: Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.statusFile.reload();
            let out = root.statusFile.text() || "";
            if (!out) return;
            
            let parts = out.split('|');
            let sinkStr = parts[0] || "";
            let srcStr = parts[1] || "";

            let volMatch = sinkStr.match(/Volume:\s+([0-9\.]+)/);
            if (volMatch) {
                let newVol = parseFloat(volMatch[1]);
                if (Math.abs(root.volume - newVol) > 0.005) {
                    root.volume = newVol;
                    root.volumeChangedExplicitly();
                }
            }

            let newMute = sinkStr.includes("MUTED");
            if (root.isMuted !== newMute) {
                root.isMuted = newMute;
                root.volumeChangedExplicitly();
            }

            let newMicMute = srcStr.includes("MUTED");
            if (root.isMicMuted !== newMicMute) {
                root.isMicMuted = newMicMute;
                root.micToggled();
            }
        }
    }

    // Despacho directo a PipeWire sin overhead de sub-shell bash
    property Process setVolProc: Process {
        property string volToSet: ""
        command: volToSet !== "" ? ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volToSet] : ["true"]
        running: false
    }
    property Process toggleSinkProc: Process {
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        running: false
    }
    property Process toggleSourceProc: Process {
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        running: false
    }
    
    function toggleMute() {
        root.isMuted = !root.isMuted;
        root.volumeChangedExplicitly();
        toggleSinkProc.running = false;
        toggleSinkProc.running = true;
    }

    function toggleMicMute() {
        root.isMicMuted = !root.isMicMuted;
        root.micToggled();
        toggleSourceProc.running = false;
        toggleSourceProc.running = true;
    }
    
    // Actualización optimista de latencia cero para scroll interactivo
    function setVolume(pct) {
        pct = Math.max(0.0, Math.min(1.0, pct));
        if (Math.abs(root.volume - pct) > 0.001) {
            root.volume = pct;
            if (root.isMuted && pct > 0) {
                root.isMuted = false;
            }
            root.volumeChangedExplicitly();
        }
        setVolProc.running = false;
        setVolProc.volToSet = pct.toFixed(2);
        setVolProc.running = true;
    }
}
