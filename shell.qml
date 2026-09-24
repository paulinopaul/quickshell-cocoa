import QtQuick
import Quickshell
import "modules/bar"
import "modules/launcher"
import "services"

ShellRoot {
    id: root

    // ThemeService debe estar activo desde el inicio para leer current_theme.json
    // y actualizar Colors antes de que los paneles terminen de renderizar.
    // La propiedad no se usa directamente; acceder a ThemeService lo instancia.
    readonly property var _theme: ThemeService

    // Barra superior
    BarWindow {
        id: bar
        onLauncherRequested: launcher.toggle()
    }

    // Lanzador de aplicaciones integrado
    LauncherWindow {
        id: launcher
    }

    function toggleLauncher(): void {
        launcher.toggle();
    }
}
