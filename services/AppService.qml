pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property var allApps: {
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        return apps.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();
        if (!q) return allApps;

        return allApps.filter(app => {
            const nameMatch = app.name && app.name.toLowerCase().includes(q);
            const commentMatch = app.comment && app.comment.toLowerCase().includes(q);
            const idMatch = app.id && app.id.toLowerCase().includes(q);
            return nameMatch || commentMatch || idMatch;
        });
    }

    function launch(app: var): void {
        if (!app) return;
        if (typeof app.execute === "function") {
            app.execute();
        } else if (app.command && app.command.length > 0) {
            Hyprland.dispatch(`exec ${app.command.join(" ")}`);
        }
    }
}
