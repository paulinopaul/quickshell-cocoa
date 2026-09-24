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

    // FileView: observa el archivo y notifica cuando cambia
    property var _fileView: FileView {
        path:         root._themePath
        watchChanges: true

        onTextChanged: root._applyTheme(text)
    }

    // Aplica el JSON al singleton Colors
    function _applyTheme(jsonText: string): void {
        if (!jsonText || jsonText.trim() === "")
            return;

        let theme;
        try {
            theme = JSON.parse(jsonText);
        } catch (e) {
            // Ignoramos errores de parseo transitorios mientras el archivo se escribe
            return;
        }

        // Solo actualiza los tokens DINÁMICOS — nunca toca surface/background
        if (theme.text      !== undefined) Colors.text      = Qt.color(theme.text);
        if (theme.textMuted !== undefined) Colors.textMuted = Qt.color(theme.textMuted);
        if (theme.textDim   !== undefined) Colors.textDim   = Qt.color(theme.textDim);
        if (theme.accent    !== undefined) Colors.accent    = Qt.color(theme.accent);

        console.info("ThemeService: Colores actualizados -> accent:", theme.accent);
    }
}
