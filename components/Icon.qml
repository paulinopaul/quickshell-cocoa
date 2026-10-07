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
        "display-brightness-symbolic":
            "M12 4V2 M12 22V20 M4 12H2 M22 12H20 M6.34 6.34L4.93 4.93 M19.07 19.07L17.66 17.66 M6.34 17.66L4.93 19.07 M19.07 4.93L17.66 6.34 M16 12A4 4 0 1 1 8 12 4 4 0 0 1 16 12Z",
        "network-wireless":
            "M12 20H12.01 M2 8.82A15 15 0 0 1 22 8.82 M5 12.86A10 10 0 0 1 19 12.86 M8.5 16.43A5 5 0 0 1 15.5 16.43",
        "network-wired":
            "M2 7H22V17H2V7Z M7 17V20 M17 17V20 M9 7V4 M15 7V4",
        "network-offline":
            "M1 1L23 23 M16.72 11.06A10.94 10.94 0 0 1 19 12.86 M5 12.86A10.94 10.94 0 0 1 10.17 10.47 M10.71 5.05A15 15 0 0 1 22 8.82 M2 8.82A15 15 0 0 1 6.7 5.94 M8.5 16.43A5 5 0 0 1 15.5 16.43 M12 20H12.01",
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
            "M3 3H21V21H3V3Z M3 9H21 M9 21V9",
        "hub":
            "M12 2L4 20H8L12 10L16 20H20L12 2Z M6 17H18",
        "dialog-question":
            "M12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22Z M12 17V17.5 M12 7C10.35 7 9 8.35 9 10C9 10.55 9.45 11 10 11C10.55 11 11 10.55 11 10C11 9.45 11.45 9 12 9C12.55 9 13 9.45 13 10C13 10.83 11.83 11.5 11 12.5V14",
        "window-close":
            "M18 6L6 18 M6 6L18 18",
        "close":
            "M18 6L6 18 M6 6L18 18",
        "preferences-system":
            "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1Z",
        "preferences-desktop-theme":
            "M12 2C6.49 2 2 6.49 2 12c0 4.41 3.59 8 8 8 .55 0 1-.45 1-1 0-.25-.09-.47-.24-.65-.15-.17-.26-.4-.26-.65 0-.55.45-1 1-1h1.5c4.14 0 7.5-3.36 7.5-7.5C20.5 5.56 16.68 2 12 2ZM6.5 11.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5Zm3-4C8.67 7.5 8 6.83 8 6s.67-1.5 1.5-1.5S11 5.17 11 6s-.67 1.5-1.5 1.5Zm5 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5Zm3 4c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5Z",
        "lock":
            "M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z M7 11V7a5 5 0 0 1 10 0v4",
        "check":
            "M20 6L9 17L4 12"
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
    readonly property bool   _isAbsPath: name.startsWith("/")
    readonly property bool   _hasTheme: !_isVec && !_isAbsPath && name !== "" && Quickshell.hasThemeIcon(name)

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
    Image {
        anchors.fill: parent
        visible: root._isAbsPath && status === Image.Ready
        source: root._isAbsPath ? ("file://" + root.name) : ""
        sourceSize: Qt.size(root.size, root.size)
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }

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
        visible: !root._isVec && !root._hasTheme && !root._isAbsPath

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
