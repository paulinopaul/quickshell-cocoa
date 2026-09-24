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

    // Telemetry: CPU & RAM
    property real cpuUsage: 0.0
    property real ramUsage: 0.0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0

    // Internal state for CPU delta calculation
    property var _prevCpu: ({ total: 0, idle: 0 })

    // /proc/stat file reader
    property var _statFile: FileView {
        path: "/proc/stat"
    }

    // /proc/meminfo file reader
    property var _memFile: FileView {
        path: "/proc/meminfo"
    }

    function _updateTelemetry(): void {
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
    }

    // Timer triggered every 2 seconds
    property var _timer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._updateTelemetry()
    }
}
