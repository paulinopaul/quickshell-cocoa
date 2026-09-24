import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../theme"
import "../../services"
import "../../components"

// Panel derecho — pentágono espejo del izquierdo:
// Solo la esquina INFERIOR-IZQUIERDA está recortada diagonalmente.
//
//   TL ─────────────────── TR
//   |                       |
//  /                        |
// BL'─────────────── BR      (BL' = TL + skew en X, BR en Y)
//
//  5 puntos: TL → TR → BR → BL+(skew,0) → TL+(0,height-skew) → TL

Item {
    id: root

    signal powerRequested()

    readonly property int sk: Metrics.sideTrapSkew
    readonly property int ph: Metrics.sideHeight

    implicitWidth:  contentRow.implicitWidth + Metrics.innerPadH * 2 + sk
    implicitHeight: ph

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor:   Colors.surface
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0;         startY: 0
            PathLine { x: root.width;   y: 0 }
            PathLine { x: root.width;   y: root.ph }
            PathLine { x: root.sk;      y: root.ph }
            PathLine { x: 0;            y: 0 }
        }
    }

    RowLayout {
        id: contentRow
        anchors.right:           parent.right
        anchors.rightMargin:     Metrics.innerPadH
        anchors.verticalCenter:  parent.verticalCenter
        spacing: Metrics.itemSpacing

        // Batería
        RowLayout {
            visible: SystemService.hasBattery
            spacing: 4

            Icon {
                size:  Metrics.iconSizeSmall
                name:  SystemService.isCharging ? "battery-charging" : "battery"
                color: SystemService.batteryPercent <= 20 ? Colors.stateError : Colors.textMuted
            }

            Text {
                text:           `${SystemService.batteryPercent}%`
                color:          SystemService.batteryPercent <= 20 ? Colors.stateError : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family:    Typography.familyMonospace
                font.weight:    Typography.weightNormal
            }
        }

        Rectangle { visible: SystemService.hasBattery; width: 1; height: 9; color: Colors.textDim; opacity: 0.5 }

        // Micrófono
        Item {
            implicitWidth:  Metrics.iconSizeMedium + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            Icon {
                anchors.centerIn: parent
                size:  Metrics.iconSizeSmall
                name:  AudioService.micMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
                color: AudioService.micMuted ? Colors.stateError : Colors.textMuted
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    AudioService.toggleMicMute()
            }
        }

        // Volumen
        Item {
            implicitWidth:  audioRow.implicitWidth + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            RowLayout {
                id: audioRow
                anchors.centerIn: parent
                spacing: 4

                Icon {
                    size:  Metrics.iconSizeSmall
                    name:  AudioService.muted ? "audio-volume-muted" : "audio-volume-high"
                    color: AudioService.muted ? Colors.stateError : Colors.textMuted
                }

                Text {
                    text:           AudioService.muted ? "—" : `${Math.round(AudioService.volume * 100)}%`
                    color:          Colors.textMuted
                    font.pixelSize: Metrics.textSizeNormal
                    font.family:    Typography.familyMonospace
                    font.weight:    Typography.weightNormal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    AudioService.toggleMute()
                onWheel: wheel => {
                    AudioService.stepVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                }
            }
        }

        Rectangle { width: 1; height: 9; color: Colors.textDim; opacity: 0.5 }

        // Botón de apagado
        Item {
            implicitWidth:  Metrics.iconSizeMedium + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            Icon {
                anchors.centerIn: parent
                size:  Metrics.iconSizeSmall
                name:  "system-shutdown"
                color: pwArea.containsMouse ? Colors.stateError : Colors.textDim
            }

            MouseArea {
                id: pwArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root.powerRequested()
            }
        }
    }
}
