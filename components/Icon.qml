import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import "../theme"

// Icono vectorial monocromático, 24x24 base, escalado dinámico.
// NO usa emojis. La propiedad `color` hereda del contexto del padre.
// Para iconos de aplicaciones del sistema, usa IconImage si el tema lo provee.

Item {
    id: root

    property string name: ""
    property int    size: Metrics.iconSizeMedium
    property color  color: Colors.textMuted

    width:  size
    height: size

    // ── Rutas vectoriales (formato PathSvg, 24x24 viewport) ─────────────────

    readonly property var _strokePaths: ({
        "cpu":
            "M9 2H15V4H19V8H21V16H19V20H15V22H9V20H5V16H3V8H5V4H9V2Z M9 9H15V15H9Z",
        "ram":
            "M2 8H22V16H2V8Z M5 11H7V13H5V11Z M10 11H12V13H10V11Z M15 11H17V13H15V11Z M6 16V18 M10 16V18 M14 16V18 M18 16V18",
        "drive-harddisk":
            "M2 6H22V18H2V6Z M6 10H8V14H6V10Z M14 10H18V14H14V10Z",
        "battery":
            "M17 7H3A2 2 0 0 0 1 9V15A2 2 0 0 0 3 17H17A2 2 0 0 0 19 15V9A2 2 0 0 0 17 7Z M23 11V13",
        "battery-charging":
            "M17 7H3A2 2 0 0 0 1 9V15A2 2 0 0 0 3 17H17A2 2 0 0 0 19 15V9A2 2 0 0 0 17 7Z M23 11V13 M12 10L9 13H12L9 16",
        "audio-input-microphone":
            "M12 2A3 3 0 0 1 15 5V11A3 3 0 0 1 9 11V5A3 3 0 0 1 12 2Z M5 10V12A7 7 0 0 0 19 12V10 M12 19V22 M8 22H16",
        "microphone-sensitivity-muted":
            "M2 2L22 22 M10.5 10.5A3 3 0 0 0 15 11V5A3 3 0 0 0 9 5V9 M5 10V12A7 7 0 0 0 12.7 18.9 M18.5 12A6.9 6.9 0 0 1 19 12V12 M12 19V22 M8 22H16",
        "audio-volume-high":
            "M11 5L6 9H2V15H6L11 19V5Z M19.07 4.93A10 10 0 0 1 19.07 19.07 M15.54 8.46A5 5 0 0 1 15.54 15.54",
        "audio-volume-muted":
            "M11 5L6 9H2V15H6L11 19V5Z M23 9L17 15 M17 9L23 15",
        "system-shutdown":
            "M18.36 6.64A9 9 0 1 1 5.64 6.64 M12 2V12",
        "system-lock-screen":
            "M7 11V7A5 5 0 0 1 17 7V11 M3 11H21V21H3V11Z",
        "system-suspend":
            "M21 12.79A9 9 0 1 1 11.21 3A7 7 0 0 0 21 12.79Z",
        "system-reboot":
            "M23 4V10H17 M1 20V14H7 M3.51 9A9 9 0 0 1 18.36 6.64L23 10M1 14L5.64 18.36A9 9 0 0 0 20.49 15",
        "system-search":
            "M11 19A8 8 0 1 0 11 3A8 8 0 0 0 11 19Z M21 21L16.65 16.65",
        "app-window":
            "M3 3H21V21H3V3Z M3 9H21 M9 21V9",
        "application-x-executable":
            "M3 3H21V21H3V3Z M3 9H21 M9 21V9"
    })

    readonly property var _fillPaths: ({
        "media-playback-start":  "M5 3L19 12L5 21Z",
        "media-playback-pause":  "M6 4H10V20H6Z M14 4H18V20H14Z",
        "media-skip-backward":   "M6 6H8V18H6Z M18 18L9 12L18 6Z",
        "media-skip-forward":    "M16 6H18V18H16Z M6 18L15 12L6 6Z"
    })

    readonly property string _sPath: _strokePaths[name] || ""
    readonly property string _fPath: _fillPaths[name]   || ""
    readonly property bool   _isVec: _sPath !== "" || _fPath !== ""
    readonly property bool   _hasTheme: !_isVec && name !== "" && Quickshell.hasThemeIcon(name)

    // Vectores propios (Shapes 24×24, escalado por transform)
    Item {
        anchors.centerIn: parent
        width: 24; height: 24
        transform: Scale { xScale: root.size / 24.0; yScale: root.size / 24.0; origin.x: 12; origin.y: 12 }
        visible: root._isVec

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4
            visible: root._sPath !== ""

            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.8
                fillColor:   "transparent"
                capStyle:    ShapePath.RoundCap
                joinStyle:   ShapePath.RoundJoin
                PathSvg { path: root._sPath }
            }
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4
            visible: root._fPath !== ""

            ShapePath {
                strokeColor: "transparent"
                fillColor:   root.color
                PathSvg { path: root._fPath }
            }
        }
    }

    // Iconos de tema del sistema (para apps instaladas)
    IconImage {
        anchors.fill: parent
        visible: root._hasTheme && status === Image.Ready
        source:  root._hasTheme ? Quickshell.iconPath(root.name) : ""
    }

    // Fallback: glifo "ventana" si no hay ni vector ni icono de tema
    Item {
        anchors.centerIn: parent
        width: 24; height: 24
        transform: Scale { xScale: root.size / 24.0; yScale: root.size / 24.0; origin.x: 12; origin.y: 12 }
        visible: !root._isVec && !root._hasTheme

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4

            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.8
                fillColor:   "transparent"
                capStyle:    ShapePath.RoundCap
                joinStyle:   ShapePath.RoundJoin
                PathSvg { path: "M3 3H21V21H3V3Z M3 9H21 M9 21V9" }
            }
        }
    }
}
