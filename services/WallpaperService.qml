pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// WallpaperService — Gestión reactiva de la galería de wallpapers y aplicación asíncrona.
//
// Integra:
// - scripts/wallpaper_lister.py ejecutado mediante Quickshell Process (cero bloqueo del hilo UI).
// - FileView observando <ipc-dir>/cocoa_wallpapers.json con watchChanges
//   (<ipc-dir>: $XDG_RUNTIME_DIR o /tmp/cocoa-$UID, fail-soft a /tmp legacy).
// - FileView observando theme/current_wallpaper.txt para sincronizar el fondo activo.
// - Process lanzando scripts/set_wallpaper.sh de forma asíncrona.

QtObject {
    id: root

    property var wallpapers: []
    property string currentPath: ""
    property int currentIndex: -1
    property bool isApplying: false

    readonly property string _currentWallpaperFile: Qt.resolvedUrl("../theme/current_wallpaper.txt").toString().replace("file://", "")
    readonly property string _scriptPath: Qt.resolvedUrl("../scripts/wallpaper_lister.py").toString().replace("file://", "")
    readonly property string _setWallpaperScript: Qt.resolvedUrl("../scripts/set_wallpaper.sh").toString().replace("file://", "")
    readonly property string _jsonCacheName: "cocoa_wallpapers.json"
    // Per-user IPC directory (scripts/wallpaper_lister.py via cocoa_ipc.py
    // resolves the same; fail-soft default is legacy /tmp).
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
    readonly property string _jsonCachePath: root._ipcDir + "/" + root._jsonCacheName

    // Observa el archivo de wallpaper actual
    property var currentWallpaperView: FileView {
        path: root._currentWallpaperFile
        watchChanges: true
        onTextChanged: root._syncCurrentWallpaper()
    }

    // Observa la caché JSON generada por el script lister
    property var jsonCacheView: FileView {
        path: root._jsonCachePath
        watchChanges: true
        onTextChanged: root._loadCachedJson()
    }

    // Proceso asíncrono para escanear y generar la lista
    property Process listerProc: Process {
        command: ["python3", root._scriptPath, "--json"]
        running: false
        onExited: (exitCode) => {
            root._loadCachedJson();
        }
    }

    // Proceso asíncrono para aplicar el wallpaper seleccionado
    property Process applyProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.isApplying = false;
            root._syncCurrentWallpaper();
        }
    }

    function _loadCachedJson() {
        jsonCacheView.reload();
        let raw = jsonCacheView.text() || "";
        if (!raw || !raw.trim()) return;
        try {
            let data = JSON.parse(raw);
            if (Array.isArray(data)) {
                root.wallpapers = data;
                root._updateCurrentIndex();
            }
        } catch (e) {
            // Ignorar errores transitorios de parseo mientras se escribe el archivo
        }
    }

    function _syncCurrentWallpaper() {
        currentWallpaperView.reload();
        let raw = currentWallpaperView.text() || "";
        let p = raw.trim();
        if (p !== "") {
            root.currentPath = p;
            root._updateCurrentIndex();
        }
    }

    function _updateCurrentIndex() {
        if (!root.wallpapers || root.wallpapers.length === 0) {
            root.currentIndex = -1;
            return;
        }
        for (let i = 0; i < root.wallpapers.length; i++) {
            if (root.wallpapers[i].path === root.currentPath) {
                root.currentIndex = i;
                return;
            }
        }
        root.currentIndex = -1;
    }

    function refresh() {
        if (listerProc.running) return;
        listerProc.running = true;
    }

    function applyWallpaper(path) {
        if (!path || root.isApplying) return;
        root.isApplying = true;
        root.currentPath = path;
        root._updateCurrentIndex();
        applyProc.command = ["bash", root._setWallpaperScript, path];
        applyProc.running = true;
    }

    Component.onCompleted: {
        root._syncCurrentWallpaper();
        root._loadCachedJson();
        root.refresh();
    }
}
