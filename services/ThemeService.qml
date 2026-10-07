pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// ThemeService — Observa current_theme.json y actualiza los tokens de color
// dinámicos de Colors.qml cuando el usuario cambia el wallpaper.
//
// Flujo:
//   set_wallpaper.sh <img> → extract_colors.py → current_theme.json
//                                                      ↓ (cambio de archivo)
//                                                  ThemeService
//                                                      ↓ (actualiza)
//                                             Colors.text / textMuted / accent
//
// Los tokens surface / surfaceRaised / background de Colors son readonly
// y NUNCA son tocados por este servicio.

QtObject {
    id: root

    // Ruta al archivo de tema (sin el prefijo file://)
    readonly property string _themePath: Qt.resolvedUrl("../theme/current_theme.json").toString().replace("file://", "")
    readonly property string _dbPath: Qt.resolvedUrl("../theme/wallpaper_themes.json").toString().replace("file://", "")
    readonly property string _applyScript: Qt.resolvedUrl("../scripts/apply_custom_theme.py").toString().replace("file://", "")
    readonly property string _themeManagerScript: Qt.resolvedUrl("../scripts/theme_manager.py").toString().replace("file://", "")
    readonly property string _ghosttySyncScript: Qt.resolvedUrl("../scripts/ghostty_sync.py").toString().replace("file://", "")

    property string mode: "auto"
    property bool isApplying: false
    property var database: ({ "mappings": {}, "customThemes": {}, "activeTheme": "Auto" })

    property Process applyThemeProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.isApplying = false;
            root._dbFileView.reload();
            root._runGhosttySync();
        }
    }

    // Fail-soft ghostty sync after every palette apply. The bool guard
    // coalesces overlapping applies so the sync is never double-spawned.
    property bool _ghosttySyncing: false

    property Process ghosttySyncProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root._ghosttySyncing = false;
        }
    }

    function _runGhosttySync(): void {
        if (root._ghosttySyncing) return;
        root._ghosttySyncing = true;
        ghosttySyncProc.command = ["python3", root._ghosttySyncScript];
        ghosttySyncProc.running = true;
    }

    // FileView: observa current_theme.json
    property var _fileView: FileView {
        path:         root._themePath
        watchChanges: true

        onTextChanged: root._applyTheme(text)
    }

    // FileView: observa wallpaper_themes.json
    property var _dbFileView: FileView {
        id: dbView
        path:         root._dbPath
        watchChanges: true

        onTextChanged: root._loadDb(text)
    }

    Component.onCompleted: {
        root._dbFileView.reload();
        root._loadDb(root._dbFileView.text());
    }

    function _loadDb(jsonText: string): void {
        if (!jsonText || jsonText.trim() === "") return;
        try {
            root.database = JSON.parse(jsonText);
        } catch (e) {}
    }

    // Aplica el JSON al singleton Colors
    function _applyTheme(jsonText: string): void {
        if (!jsonText || jsonText.trim() === "")
            return;

        let theme;
        try {
            theme = JSON.parse(jsonText);
        } catch (e) {
            return;
        }

        if (theme.mode !== undefined) {
            root.mode = theme.mode;
        }

        // Actualiza tokens dinámicos de superficie, bordes, texto y acentos
        if (theme.surface       !== undefined) Colors.surface       = Qt.color(theme.surface);
        if (theme.surfaceDark   !== undefined) Colors.surfaceDark   = Qt.color(theme.surfaceDark);
        if (theme.surfaceRaised !== undefined) Colors.surfaceRaised = Qt.color(theme.surfaceRaised);
        if (theme.surfaceHover  !== undefined) Colors.surfaceHover  = Qt.color(theme.surfaceHover);
        if (theme.surfaceBorder !== undefined) Colors.surfaceBorder = Qt.color(theme.surfaceBorder);
        if (theme.background    !== undefined) Colors.background    = Qt.color(theme.background);

        if (theme.text          !== undefined) Colors.text          = Qt.color(theme.text);
        if (theme.textMuted     !== undefined) Colors.textMuted     = Qt.color(theme.textMuted);
        if (theme.textDim       !== undefined) Colors.textDim       = Qt.color(theme.textDim);
        if (theme.accent        !== undefined) Colors.accent        = Qt.color(theme.accent);

        console.info("ThemeService: Colores actualizados -> mode:", root.mode, "accent:", theme.accent, "surface:", theme.surface);
    }

    function applyCustomTheme(hexColor: string): void {
        if (root.isApplying || !hexColor) return;
        root.isApplying = true;
        applyThemeProc.command = ["python3", root._applyScript, hexColor.trim()];
        applyThemeProc.running = true;
    }

    function applyNamedTheme(themeName: string): void {
        if (root.isApplying || !themeName) return;
        root.isApplying = true;
        applyThemeProc.command = ["python3", root._themeManagerScript, "apply", themeName.trim()];
        applyThemeProc.running = true;
    }

    function bindWallpaper(wallpaperPath: string, themeNameOrHex: string): void {
        if (root.isApplying || !wallpaperPath || !themeNameOrHex) return;
        root.isApplying = true;
        applyThemeProc.command = ["python3", root._themeManagerScript, "bind", wallpaperPath.trim(), themeNameOrHex.trim()];
        applyThemeProc.running = true;
    }

    function unbindWallpaper(wallpaperPath: string): void {
        if (root.isApplying || !wallpaperPath) return;
        root.isApplying = true;
        applyThemeProc.command = ["python3", root._themeManagerScript, "unbind", wallpaperPath.trim()];
        applyThemeProc.running = true;
    }

    function createThemeFromWallpaper(wallpaperPath: string, customName: string): void {
        if (root.isApplying || !wallpaperPath) return;
        root.isApplying = true;
        let args = ["python3", root._themeManagerScript, "create-from-wall", wallpaperPath.trim()];
        if (customName && customName.trim() !== "") {
            args.push(customName.trim());
        }
        applyThemeProc.command = args;
        applyThemeProc.running = true;
    }

    function syncWithWallpaper(): void {
        if (root.isApplying) return;
        root.isApplying = true;
        applyThemeProc.command = ["python3", root._applyScript, "--sync-wallpaper"];
        applyThemeProc.running = true;
    }
}
