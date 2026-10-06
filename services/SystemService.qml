pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

QtObject {
    id: root

    // Battery Integration via UPower
    readonly property bool hasBattery: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false
    readonly property int batteryPercent: {
        if (!hasBattery || !UPower.displayDevice) return 100;
        return Math.round(UPower.displayDevice.percentage * 100);
    }
    readonly property bool isCharging: {
        if (!hasBattery || !UPower.displayDevice) return false;
        const s = UPower.displayDevice.state;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge;
    }

    // Telemetry: CPU & RAM & GPU & Net & Serial
    property real cpuUsage: 0
    property real gpuNvidia: 0
    property real gpuIntel: 0.0
    property real ramUsage: 0.0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property string netSpeedString: "↓ 0 KB/s  ↑ 0 KB/s"
    property string serialDevice: "Sin conexión"

    // Internal state for CPU delta calculation
    property var _prevCpu: ({ total: 0, idle: 0 })
    property var _prevNet: ({ rx: 0, tx: 0, time: 0 })
    property var _prevRc6: ({ val: 0, time: 0 })

    // /proc/stat file reader
    property var _statFile: FileView {
        path: "/proc/stat"
    }

    // /proc/meminfo file reader
    property var _memFile: FileView {
        path: "/proc/meminfo"
    }

    // /proc/net/dev file reader
    property var _netFile: FileView {
        path: "/proc/net/dev"
    }

    // Intel GPU RC6 idle residency reader
    property var _intelRc6File: FileView {
        path: "/sys/class/drm/card1/power/rc6_residency_ms"
    }

    // Fallback Intel GPU active frequency reader
    property var _intelFreqFile: FileView {
        path: "/sys/class/drm/card1/gt_act_freq_mhz"
    }

    // Cocoa daemon status reader (NVIDIA & Serial port)
    property var _statusFile: FileView {
        path: "/tmp/cocoa_status.txt"
    }

    function _formatSpeed(bps) {
        if (bps >= 1024 * 1024) {
            return (bps / (1024 * 1024)).toFixed(1) + " MB/s";
        } else if (bps >= 1024) {
            return Math.round(bps / 1024) + " KB/s";
        } else {
            return Math.round(bps) + " B/s";
        }
    }

    function _updateTelemetry() {
        const now = Date.now();


        // --- 1. Parse CPU Usage ---
        _statFile.reload();
        const statText = _statFile.text();
        if (statText) {
            const firstLine = statText.split("\n")[0];
            if (firstLine && firstLine.startsWith("cpu ")) {
                const parts = firstLine.trim().split(/\s+/);
                if (parts.length >= 5) {
                    const user = parseInt(parts[1]) || 0;
                    const nice = parseInt(parts[2]) || 0;
                    const system = parseInt(parts[3]) || 0;
                    const idle = parseInt(parts[4]) || 0;
                    const iowait = parseInt(parts[5]) || 0;
                    const irq = parseInt(parts[6]) || 0;
                    const softirq = parseInt(parts[7]) || 0;
                    const steal = parseInt(parts[8]) || 0;

                    const idleTime = idle + iowait;
                    const totalTime = idleTime + user + nice + system + irq + softirq + steal;

                    const totalDelta = totalTime - _prevCpu.total;
                    const idleDelta = idleTime - _prevCpu.idle;

                    if (_prevCpu.total > 0 && totalDelta > 0) {
                        const usage = ((totalDelta - idleDelta) / totalDelta) * 100.0;
                        cpuUsage = Math.max(0.0, Math.min(100.0, Math.round(usage)));
                    }
                    _prevCpu = { total: totalTime, idle: idleTime };
                }
            }
        }

        // --- 2. Parse RAM Usage ---
        _memFile.reload();
        const memText = _memFile.text();
        if (memText) {
            let totalKb = 0;
            let availKb = 0;
            const lines = memText.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                if (line.startsWith("MemTotal:")) {
                    const match = line.match(/\d+/);
                    if (match) totalKb = parseInt(match[0]);
                } else if (line.startsWith("MemAvailable:")) {
                    const match = line.match(/\d+/);
                    if (match) availKb = parseInt(match[0]);
                }
                if (totalKb > 0 && availKb > 0) break;
            }

            if (totalKb > 0) {
                const usedKb = totalKb - availKb;
                ramUsage = Math.round((usedKb / totalKb) * 100);
                ramUsedGb = Math.round((usedKb / (1024 * 1024)) * 10) / 10;
                ramTotalGb = Math.round((totalKb / (1024 * 1024)) * 10) / 10;
            }
        }

        // --- 3. Parse Network Speed ---
        _netFile.reload();
        const netText = _netFile.text();
        if (netText) {
            let totalRx = 0;
            let totalTx = 0;
            const netLines = netText.split("\n");
            for (let i = 0; i < netLines.length; i++) {
                const line = netLines[i];
                if (!line.includes(":")) continue;
                const colonIdx = line.indexOf(":");
                const iface = line.substring(0, colonIdx).trim();
                if (iface === "lo") continue;
                const fields = line.substring(colonIdx + 1).trim().split(/\s+/);
                if (fields.length >= 9) {
                    totalRx += parseInt(fields[0]) || 0;
                    totalTx += parseInt(fields[8]) || 0;
                }
            }

            if (_prevNet.time > 0 && now > _prevNet.time) {
                const dtSec = (now - _prevNet.time) / 1000.0;
                const rxDelta = Math.max(0, totalRx - _prevNet.rx);
                const txDelta = Math.max(0, totalTx - _prevNet.tx);
                const rxRate = rxDelta / dtSec;
                const txRate = txDelta / dtSec;
                netSpeedString = "↓ " + _formatSpeed(rxRate) + "  ↑ " + _formatSpeed(txRate);
            }
            _prevNet = { rx: totalRx, tx: totalTx, time: now };
        }

        // --- 4. Parse Intel GPU Load ---
        _intelRc6File.reload();
        const rc6Raw = (_intelRc6File.text() || "").trim();
        if (rc6Raw && /^\d+$/.test(rc6Raw)) {
            const currRc6 = parseInt(rc6Raw);
            if (_prevRc6.time > 0 && now > _prevRc6.time) {
                const dtMs = now - _prevRc6.time;
                const dRc6 = Math.max(0, currRc6 - _prevRc6.val);
                const idleFrac = Math.min(1.0, Math.max(0.0, dRc6 / dtMs));
                gpuIntel = Math.max(0.0, Math.min(100.0, Math.round((1.0 - idleFrac) * 100.0)));
            }
            _prevRc6 = { val: currRc6, time: now };
        } else {
            // Fallback frequency-based Intel estimation
            _intelFreqFile.reload();
            const freqRaw = (_intelFreqFile.text() || "").trim();
            if (freqRaw && /^\d+$/.test(freqRaw)) {
                const actFreq = parseInt(freqRaw);
                // Min 100MHz, Max 1300MHz
                gpuIntel = Math.max(0.0, Math.min(100.0, Math.round(((actFreq - 100) / 1200.0) * 100.0)));
            }
        }

        // --- 5. Parse Status File (NVIDIA & Serial Port) ---
        _statusFile.reload();
        const statusText = (_statusFile.text() || "").trim();
        if (statusText) {
            const parts = statusText.split("|");
            if (parts.length >= 5) {
                const nvdVal = parseFloat(parts[4]);
                if (!isNaN(nvdVal)) gpuNvidia = Math.max(0, Math.min(100, Math.round(nvdVal)));
            }
            if (parts.length >= 6) {
                const rawSerial = (parts[5] || "").trim();
                if (rawSerial) {
                    serialDevice = rawSerial.replace(/^usb-/, "");
                } else {
                    serialDevice = "Sin conexión";
                }
            }
        }
    }

    // Timer triggered every 1.5 seconds for snappy telemetry
    property var _timer: Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._updateTelemetry()
    }
}

