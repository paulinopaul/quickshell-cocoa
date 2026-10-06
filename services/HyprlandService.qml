pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    // Reactive properties from Hyprland IPC
    readonly property var workspaces: {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        return list.slice().sort((a, b) => a.id - b.id);
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int focusedWorkspaceId: focusedWorkspace ? focusedWorkspace.id : 1

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel
    property string windowClass: "desktop"
    
    readonly property string windowTitle: {
        if (windowClass === "desktop") return "Desktop";
        return activeToplevel && activeToplevel.title ? activeToplevel.title : "Desktop";
    }

    function updateWindowClass() {
        if (focusedWorkspace && focusedWorkspace.toplevels && focusedWorkspace.toplevels.values && focusedWorkspace.toplevels.values.length === 0) {
            windowClass = "desktop";
            return;
        }
        if (!activeToplevel) { windowClass = "desktop"; return; }
        if (activeToplevel.lastIpcObject && activeToplevel.lastIpcObject.class) {
            { windowClass = activeToplevel.lastIpcObject.class; return; }
        }
        if (activeToplevel.lastIpcObject && activeToplevel.lastIpcObject.initialClass) {
            { windowClass = activeToplevel.lastIpcObject.initialClass; return; }
        }
        { windowClass = "application-x-executable"; return; }
    }

    // ── Búsqueda de app info desde DesktopEntries ─────────────────────────────
    // Estrategia: exact match por ID > partial match por ID > partial match por name
    readonly property var activeAppInfo: {
        const cls = windowClass.toLowerCase();
        if (cls === "desktop" || cls === "application-x-executable") return null;

        const apps = AppService.allApps;
        if (!apps) return null;

        // 1. Exact ID match (case-insensitive) — p.ej. "Alacritty" == "alacritty"
        let match = apps.find(a => a.id && a.id.toLowerCase().replace(".desktop","") === cls);
        // 2. Partial ID match
        if (!match) match = apps.find(a => a.id && a.id.toLowerCase().includes(cls));
        // 3. Partial name match
        if (!match) match = apps.find(a => a.name && a.name.toLowerCase().includes(cls));
        return match || null;
    }

    // ── Resolución de ícono ──────────────────────────────────────────────────
    readonly property string displayIcon: {
        // Ícono absoluto desde el sistema de iconos del tema
        if (activeAppInfo && activeAppInfo.icon) {
            return activeAppInfo.icon;
        }
        return iconForClass(windowClass);
    }

    // ── Nombre visible de la app ─────────────────────────────────────────────
    readonly property string displayAppName: {
        const cls = windowClass.toLowerCase();

        if (cls === "desktop" || cls === "application-x-executable") return "";

        // Para Terminales (Ghostty, Alacritty): mostrar CWD como prefijo
        if (cls.includes("alacritty") || cls.includes("ghostty")) {
            return root.alacrittyCwd !== "" ? root.alacrittyCwd : "Terminal";
        }

        if (activeAppInfo && activeAppInfo.name) {
            return activeAppInfo.name;
        }

        if (windowClass && windowClass !== "application-x-executable" && windowClass !== "desktop") {
            return windowClass.charAt(0).toUpperCase() + windowClass.slice(1);
        }

        return windowClass;
    }

    // ── Mapa de íconos por clase de ventana (fallback sin DesktopEntries) ────
    function iconForClass(cls: string): string {
        if (!cls) return "application-x-executable";
        const c = cls.toLowerCase();
        if (c.includes("firefox"))                                          return "firefox";
        if (c.includes("chrome") || c.includes("chromium"))                return "google-chrome";
        if (c.includes("code") || c.includes("vsc"))                       return "visual-studio-code";
        // Ghostty & Alacritty: usar íconos SVG directos del tema Papirus
        if (c.includes("ghostty"))                                          return "/usr/share/icons/Papirus/32x32/apps/com.mitchellh.ghostty.svg";
        if (c.includes("alacritty"))                                        return "/usr/share/icons/Papirus/32x32/apps/Alacritty.svg";
        if (c.includes("term") || c.includes("kitty") || c.includes("foot")) return "utilities-terminal";
        if (c.includes("thunar") || c.includes("nemo") || c.includes("nautilus") || c.includes("dolphin")) return "system-file-manager";
        if (c.includes("spotify"))                                          return "spotify";
        if (c.includes("discord") || c.includes("vesktop") || c.includes("webcord")) return "discord";
        if (c.includes("steam"))                                            return "steam";
        if (c.includes("obs"))                                              return "obs";
        if (c.includes("gimp"))                                             return "gimp";
        if (c.includes("inkscape"))                                         return "inkscape";
        if (c.includes("vlc") || c.includes("mpv"))                        return "multimedia-video-player";
        return "application-x-executable";
    }

    // ── CWD de Alacritty ─────────────────────────────────────────────────────
    // Usa FileView polling en lugar de Process para evitar problemas de API de stdout
    property string alacrittyCwd: ""
    property string _cwdPid: ""

    // Escribe el PID objetivo a un archivo tmp para que FileView lo lea
    property Timer cwdTrigger: Timer {
        interval: 800
        repeat:   false
        onTriggered: {
            // Leer /proc/<pid>/cwd via readlink desde shell, escribir resultado a /tmp/cocoa_cwd.txt
            cwdProc.running = true;
        }
    }

    // Acumulador de stdout del proceso CWD
    property string _cwdOutput: ""

    property Process cwdProc: Process {
        id: cwdProc
        command: {
            const pid = (root.activeToplevel && root.activeToplevel.lastIpcObject)
                        ? String(root.activeToplevel.lastIpcObject.pid)
                        : "";
            if (!pid) return ["true"];
            return ["bash", "-c",
                "PID=" + pid + "; CHILD=$(pgrep -P \"$PID\" 2>/dev/null | head -n1); " +
                "TARGET=${CHILD:-$PID}; " +
                "readlink /proc/\"$TARGET\"/cwd 2>/dev/null || echo ''"];
        }
        running: false

        onExited: {
            // stdout es array de chunks — mismo patrón que BrightnessService.qml
            let raw = stdout ? stdout.join("") : "";
            let path = raw.trim();
            root._cwdOutput = "";
            if (path) {
                path = path.replace("/home/paul", "~");
                root.alacrittyCwd = path;
            } else {
                root.alacrittyCwd = "";
            }
        }
    }

    onActiveToplevelChanged: {
        updateWindowClass();
        const clsLower = windowClass.toLowerCase();
        if (clsLower.includes("alacritty") || clsLower.includes("ghostty")) {
            root._cwdOutput = "";
            cwdTrigger.restart();
        } else {
            root.alacrittyCwd = "";
        }
    }

    // Actualizar CWD periódicamente mientras una terminal (Ghostty o Alacritty) esté activa
    property Timer cwdRefresh: Timer {
        interval: 3000
        repeat:   true
        running:  root.windowClass.toLowerCase().includes("alacritty") || root.windowClass.toLowerCase().includes("ghostty")
        onTriggered: {
            if (!cwdProc.running) {
                root._cwdOutput = "";
                cwdProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        Hyprland.focusedWorkspaceChanged.connect(updateWindowClass);
        updateWindowClass();
    }

    function focusWorkspace(wsId: int): void {
        Hyprland.dispatch(`workspace ${wsId}`);
    }

    function dispatch(cmd: string): void {
        Hyprland.dispatch(cmd);
    }
}
