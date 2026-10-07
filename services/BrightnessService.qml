pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property real brightness: 1.0
    signal brightnessChangedExplicitly()

    // Direct sysfs read (Linux kernel: 0ms latency, 0 subprocesses).
    // Portable backlight lookup: at startup a one-shot probe globs
    // /sys/class/backlight/* and picks the first entry with a readable
    // max_brightness (preferring intel_backlight / amdgpu_bl*). Falls back
    // to the previous hardcoded path when the glob is empty (fail-soft).
    property string sysfsPath: "/sys/class/backlight/intel_backlight"
    property var actualBrightnessFile: FileView { path: root.sysfsPath + "/actual_brightness" }
    property var maxBrightnessFile: FileView { path: root.sysfsPath + "/max_brightness" }
    property real maxBrightness: 96000.0

    // One-shot backlight detection at startup. stdout arrives as an array
    // of chunks (same pattern as HyprlandService cwdProc).
    property Process backlightDetect: Process {
        running: true
        command: ["sh", "-c", "best=''; for d in /sys/class/backlight/*; do [ -r \"$d/max_brightness\" ] || continue; n=$(basename \"$d\"); case \"$n\" in intel_backlight|amdgpu_bl*) printf '%s' \"$d\"; exit 0;; esac; [ -z \"$best\" ] && best=\"$d\"; done; printf '%s' \"$best\""]
        onExited: {
            let raw = stdout ? stdout.join("") : "";
            let found = raw.trim();
            if (found !== "" && found !== root.sysfsPath) {
                root.sysfsPath = found;
            }
            root._reloadFromSysfs();
        }
    }

    // Temporizador de alta frecuencia para detectar teclas de hardware (Fn + Brillo)
    property Timer pollTimer: Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.actualBrightnessFile.reload();
            let txt = root.actualBrightnessFile.text() || "";
            if (txt) {
                let actual = parseFloat(txt.trim());
                if (!isNaN(actual) && root.maxBrightness > 0) {
                    let newBrightness = actual / root.maxBrightness;
                    if (Math.abs(root.brightness - newBrightness) > 0.005) {
                        root.brightness = Math.max(0.01, Math.min(1.0, newBrightness));
                        root.brightnessChangedExplicitly();
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root._reloadFromSysfs();
    }

    function _reloadFromSysfs() {
        root.maxBrightnessFile.reload();
        let maxTxt = root.maxBrightnessFile.text() || "";
        if (maxTxt) {
            let maxVal = parseFloat(maxTxt.trim());
            if (!isNaN(maxVal) && maxVal > 0) {
                root.maxBrightness = maxVal;
            }
        }
        root.actualBrightnessFile.reload();
        let actTxt = root.actualBrightnessFile.text() || "";
        if (actTxt) {
            let actVal = parseFloat(actTxt.trim());
            if (!isNaN(actVal) && root.maxBrightness > 0) {
                root.brightness = Math.max(0.01, Math.min(1.0, actVal / root.maxBrightness));
            }
        }
    }

    // Despacho directo a hardware sin sub-shell bash
    property Process setProc: Process {
        property string valToSet: ""
        command: valToSet !== "" ? ["brightnessctl", "s", valToSet] : ["true"]
        running: false
    }

    // Actualización optimista de latencia cero para scroll interactivo
    function setBrightness(pct) {
        pct = Math.max(0.01, Math.min(1.0, pct));
        if (Math.abs(root.brightness - pct) > 0.001) {
            root.brightness = pct;
            root.brightnessChangedExplicitly();
        }
        let pctInt = Math.round(pct * 100);
        setProc.running = false;
        setProc.valToSet = pctInt + "%";
        setProc.running = true;
    }
}
