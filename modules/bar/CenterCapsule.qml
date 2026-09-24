// Cápsula central — hexágono / trapecio:
// Ancha en la parte superior (toca el borde de pantalla, ancho completo).
// Ambas esquinas inferiores recortadas diagonalmente hacia adentro.
//  TL ───────────────────────── TR   ← toca el borde de pantalla, ancho total
//  |                             |
//  |                             |
//   \                           /    ← corte diagonal en ambas esquinas inferiores
//    BL ─────────────────── BR       ← base más estrecha
// El scroll del ratón cambia entre 3 modos: media / sistema / ventana activa.

import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root

    property int currentMode: 0
    readonly property int totalModes: 3
    readonly property int sk: Metrics.centerTrapSkewBottom
    readonly property int ch: Metrics.barHeight

    signal clicked()

    implicitHeight: ch

    // Trapecio central
    Shape {
        id: bgShape

        property int trapWidth: 485
        property int centerX: root.width / 2
        property int startX_pos: centerX - (trapWidth / 2)
        property int endX_pos: centerX + (trapWidth / 2)

        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: Colors.surface
            strokeColor: "transparent"
            strokeWidth: 0
            startX: bgShape.startX_pos
            startY: 0

            PathLine {
                x: bgShape.endX_pos
                y: 0
            }

            PathLine {
                x: bgShape.endX_pos - root.sk
                y: root.ch
            }

            PathLine {
                x: bgShape.startX_pos + root.sk
                y: root.ch
            }

            PathLine {
                x: bgShape.startX_pos
                y: 0
            }

        }

    }

    // Cambio de modo con scroll
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => {
            root.currentMode = ev.angleDelta.y > 0 ? (root.currentMode - 1 + root.totalModes) % root.totalModes : (root.currentMode + 1) % root.totalModes;
        }
    }

    // Click para expandir/colapsar reproductor
    TapHandler {
        onTapped: root.clicked()
    }

    // Auto-switch a media cuando empieza reproducción
    Connections {
        function onIsPlayingChanged() {
            if (MediaService.isPlaying && root.currentMode !== 0)
                root.currentMode = 0;

        }

        target: MediaService
    }

    // ── MODO 0: Reproductor de medios ────────────────────────────────────────
    RowLayout {
        visible: root.currentMode === 0
        anchors.centerIn: parent
        spacing: Metrics.itemSpacing + 2

        IconButton {
            buttonSize: Metrics.iconSizeLarge
            iconName: "media-skip-backward"
            iconColor: Colors.textDim
            onClicked: MediaService.previous()
        }

        IconButton {
            buttonSize: Metrics.iconSizeLarge + 2
            iconName: MediaService.isPlaying ? "media-playback-pause" : "media-playback-start"
            iconColor: Colors.text
            onClicked: MediaService.playPause()
        }

        IconButton {
            buttonSize: Metrics.iconSizeLarge
            iconName: "media-skip-forward"
            iconColor: Colors.textDim
            onClicked: MediaService.next()
        }

        Rectangle {
            width: 1
            height: 11
            color: Colors.textDim
            opacity: 0.5
        }

        Text {
            text: MediaService.hasMedia ? MediaService.displayTitle : "Sin medios"
            color: MediaService.hasMedia ? Colors.text : Colors.textDim
            font.pixelSize: Metrics.textSizeNormal
            font.family: Typography.family
            font.weight: Typography.weightNormal
            elide: Text.ElideRight
            maximumLineCount: 1
        }

    }

    // ── MODO 1: Telemetría de sistema ─────────────────────────────────────────
    RowLayout {
        visible: root.currentMode === 1
        anchors.centerIn: parent
        spacing: Metrics.itemSpacing + 4

        RowLayout {
            spacing: 5

            Icon {
                size: Metrics.iconSizeSmall
                name: "cpu"
                color: Colors.textMuted
            }

            Text {
                text: `CPU  ${SystemService.cpuUsage}%`
                color: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
            }

            Meter {
                value: SystemService.cpuUsage / 100
                barHeight: 2
                implicitWidth: 32
                barColor: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.textDim
            }

        }

        Rectangle {
            width: 1
            height: 9
            color: Colors.textDim
            opacity: 0.4
        }

        RowLayout {
            spacing: 5

            Icon {
                size: Metrics.iconSizeSmall
                name: "ram"
                color: Colors.textMuted
            }

            Text {
                text: `RAM  ${SystemService.ramUsedGb}G`
                color: SystemService.ramUsage > 85 ? Colors.stateError : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
            }

            Meter {
                value: SystemService.ramUsage / 100
                barHeight: 2
                implicitWidth: 32
                barColor: SystemService.ramUsage > 85 ? Colors.stateError : Colors.textDim
            }

        }

    }

    // ── MODO 2: Contexto de ventana activa ────────────────────────────────────
    RowLayout {
        visible: root.currentMode === 2
        anchors.centerIn: parent
        spacing: Metrics.itemSpacing

        Icon {
            size: Metrics.iconSizeMedium
            name: HyprlandService.iconForClass(HyprlandService.windowClass)
            color: Colors.textMuted
        }

        Text {
            text: HyprlandService.windowTitle
            color: Colors.text
            font.pixelSize: Metrics.textSizeNormal
            font.family: Typography.family
            font.weight: Typography.weightNormal
            elide: Text.ElideRight
            maximumLineCount: 1
        }

    }

    // Indicadores de modo (base del panel)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 5

        Repeater {
            model: root.totalModes

            delegate: Rectangle {
                required property int index

                width: index === root.currentMode ? 11 : 4
                height: 2
                radius: 1
                color: index === root.currentMode ? Colors.text : Colors.textDim

                Behavior on width {
                    NumberAnimation {
                        duration: Metrics.animFast
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Metrics.animFast
                    }

                }

            }

        }

    }

}
