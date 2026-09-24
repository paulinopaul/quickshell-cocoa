pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

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
    readonly property string windowTitle: activeToplevel ? (activeToplevel.title || "Desktop") : "Desktop"
    readonly property string windowClass: {
        if (!activeToplevel) return "desktop";
        if (activeToplevel.lastIpcObject && activeToplevel.lastIpcObject.class) {
            return activeToplevel.lastIpcObject.class;
        }
        if (activeToplevel.lastIpcObject && activeToplevel.lastIpcObject.initialClass) {
            return activeToplevel.lastIpcObject.initialClass;
        }
        return "application-x-executable";
    }

    // Maps window classes to icon names or unicode symbols
    function iconForClass(cls: string): string {
        if (!cls) return "application-x-executable";
        const c = cls.toLowerCase();
        if (c.includes("firefox")) return "firefox";
        if (c.includes("chrome") || c.includes("chromium")) return "google-chrome";
        if (c.includes("code") || c.includes("vsc")) return "visual-studio-code";
        if (c.includes("term") || c.includes("kitty") || c.includes("alacritty") || c.includes("foot")) return "utilities-terminal";
        if (c.includes("thunar") || c.includes("nemo") || c.includes("nautilus") || c.includes("dolphin")) return "system-file-manager";
        if (c.includes("spotify")) return "spotify";
        if (c.includes("discord") || c.includes("vesktop") || c.includes("webcord")) return "discord";
        if (c.includes("steam")) return "steam";
        if (c.includes("obs")) return "obs";
        if (c.includes("gimp")) return "gimp";
        if (c.includes("inkscape")) return "inkscape";
        if (c.includes("vlc") || c.includes("mpv")) return "multimedia-video-player";
        return "application-x-executable";
    }

    function focusWorkspace(wsId: int): void {
        Hyprland.dispatch(`workspace ${wsId}`);
    }

    function dispatch(cmd: string): void {
        Hyprland.dispatch(cmd);
    }
}
