import QtQuick
import Quickshell
import "modules/bar"
import "modules/launcher"
import "modules/notifications"
import "modules/wallpaper"
import "services"

ShellRoot {
    id: root

    // ThemeService y NotificationService deben estar activos desde el inicio
    readonly property var _theme: ThemeService
    readonly property var _notif: NotificationService
    readonly property var _wallpaper: WallpaperService

    // Barra superior
    BarWindow {
        id: bar
        onLauncherRequested: launcher.toggle()
    }

    // PopUp de Notificaciones emergentes
    NotificationPopup {}

    LauncherWindow {
        id: launcher
    }

    WallpaperTransitionWindow {
        id: wallpaperTransition
    }

    WallpaperWindow {
        id: wallpaperSelector
        transitionWindow: wallpaperTransition
    }

    function toggleLauncher() {
        launcher.toggle();
    }
}
