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
    signal networkRequested()

    readonly property int sk: Metrics.sideTrapSkew
    readonly property int ph: Metrics.sideHeight

    // Estado del HUD Ligero Dinámico
    property bool   hudActive: false
    property string hudType:   "volume"
    property real   hudValue:  0.0
    property string hudIcon:   "audio-volume-high"
    property string hudText:   "0%"

    Timer {
        id: hudTimer
        interval: 1800
        repeat: false
        onTriggered: root.hudActive = false
    }

    Connections {
        target: VolumeService
        // Escucha la señal volumeChangedExplicitly
        function onVolumeChangedExplicitly() {
            root.hudType = "volume";
            root.hudValue = VolumeService.volume;
            root.hudIcon = VolumeService.isMuted ? "audio-volume-muted" : "audio-volume-high";
            root.hudText = VolumeService.isMuted ? "MUTE" : `${Math.round(VolumeService.volume * 100)}%`;
            root.hudActive = true;
            hudTimer.restart();
        }
    }

    Connections {
        target: BrightnessService
        // Escucha la señal brightnessChangedExplicitly
        function onBrightnessChangedExplicitly() {
            root.hudType = "brightness";
            root.hudValue = BrightnessService.brightness;
            root.hudIcon = "display-brightness-symbolic";
            root.hudText = `${Math.round(BrightnessService.brightness * 100)}%`;
            root.hudActive = true;
            hudTimer.restart();
        }
    }

    implicitWidth:  (root.hudActive ? hudContainer.implicitWidth : contentRow.implicitWidth) + Metrics.innerPadH * 2 + sk
    implicitHeight: ph

    Behavior on implicitWidth {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

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

    // HUD Ligero Dinámico (reemplaza temporalmente las métricas al variar volumen/brillo)
    Item {
        id: hudContainer
        anchors.right:           parent.right
        anchors.rightMargin:     Metrics.innerPadH
        anchors.verticalCenter:  parent.verticalCenter
        implicitWidth:           hudRow.implicitWidth
        implicitHeight:          hudRow.implicitHeight
        opacity:                 root.hudActive ? 1.0 : 0.0
        visible:                 opacity > 0
        enabled:                 root.hudActive

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        RowLayout {
            id: hudRow
            anchors.fill: parent
            spacing: 8

            Icon {
                size:  Metrics.iconSizeSmall
                name:  root.hudIcon
                color: root.hudIcon.includes("muted") ? Colors.stateError : Colors.text
            }

            Meter {
                value:         root.hudValue
                implicitWidth: 90
                barHeight:     4
                barColor:      Colors.accent
            }

            Text {
                text:           root.hudText
                color:          Colors.text
                font.pixelSize: Metrics.textSizeNormal
                font.family:    Typography.familyMonospace
                font.weight:    Typography.weightMedium
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onWheel: wheel => {
                let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                if (root.hudType === "volume") {
                    VolumeService.setVolume(VolumeService.volume + delta);
                } else if (root.hudType === "brightness") {
                    BrightnessService.setBrightness(BrightnessService.brightness + delta);
                }
                hudTimer.restart();
            }
            onClicked: {
                if (root.hudType === "volume") {
                    VolumeService.toggleMute();
                    hudTimer.restart();
                }
            }
        }
    }

    // Métricas estándar del panel superior
    RowLayout {
        id: contentRow
        anchors.right:           parent.right
        anchors.rightMargin:     Metrics.innerPadH
        anchors.verticalCenter:  parent.verticalCenter
        spacing: Metrics.itemSpacing
        opacity: root.hudActive ? 0.0 : 1.0
        visible: opacity > 0
        enabled: !root.hudActive

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

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

        // Red (Wi-Fi / LAN) - Click para desplegar selector de redes
        Item {
            implicitWidth: netRow.implicitWidth + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            RowLayout {
                id: netRow
                anchors.centerIn: parent
                spacing: 4

                Icon {
                    size:  Metrics.iconSizeSmall
                    name:  NetworkService.isConnected ? (NetworkService.isWifi ? "network-wireless" : "network-wired") : "network-offline"
                    color: NetworkService.isConnected ? Colors.textMuted : Colors.stateError
                }

                Text {
                    text:           NetworkService.displayString
                    color:          NetworkService.isConnected ? Colors.textMuted : Colors.stateError
                    font.pixelSize: Metrics.textSizeNormal
                    font.family:    Typography.familyMonospace
                    font.weight:    Typography.weightNormal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root.networkRequested()
            }
        }


        Rectangle { width: 1; height: 9; color: Colors.textDim; opacity: 0.5 }

        // Micrófono
        Item {
            implicitWidth:  Metrics.iconSizeMedium + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            Icon {
                anchors.centerIn: parent
                size:  Metrics.iconSizeSmall
                name:  VolumeService.isMicMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
                color: VolumeService.isMicMuted ? Colors.stateError : Colors.textMuted
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    VolumeService.toggleMicMute()
            }
        }

        Rectangle { width: 1; height: 9; color: Colors.textDim; opacity: 0.5 }

        // Brillo
        Item {
            implicitWidth:  brightRow.implicitWidth + 4
            implicitHeight: Metrics.iconSizeMedium + 4

            RowLayout {
                id: brightRow
                anchors.centerIn: parent
                spacing: 4

                Icon {
                    size:  Metrics.iconSizeSmall
                    name:  "display-brightness-symbolic"
                    color: Colors.textMuted
                }

                Text {
                    text:           `${Math.round(BrightnessService.brightness * 100)}%`
                    color:          Colors.textMuted
                    font.pixelSize: Metrics.textSizeNormal
                    font.family:    Typography.familyMonospace
                    font.weight:    Typography.weightNormal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onWheel: wheel => {
                    BrightnessService.setBrightness(BrightnessService.brightness + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                }
            }
        }

        Rectangle { width: 1; height: 9; color: Colors.textDim; opacity: 0.5 }

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
                    name:  VolumeService.isMuted ? "audio-volume-muted" : "audio-volume-high"
                    color: VolumeService.isMuted ? Colors.stateError : Colors.textMuted
                }

                Text {
                    text:           VolumeService.isMuted ? "—" : `${Math.round(VolumeService.volume * 100)}%`
                    color:          Colors.textMuted
                    font.pixelSize: Metrics.textSizeNormal
                    font.family:    Typography.familyMonospace
                    font.weight:    Typography.weightNormal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    VolumeService.toggleMute()
                onWheel: wheel => {
                    VolumeService.setVolume(VolumeService.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
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
