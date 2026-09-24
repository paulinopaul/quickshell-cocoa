import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// Menú desplegable para controlar medios
Item {
    id: root

    // Altura del flyout
    implicitHeight: mainLayout.implicitHeight + 24
    implicitWidth: 380

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: Colors.surfaceRaised
            strokeColor: "transparent"
            strokeWidth: 0
            // Un trapecio invertido o simplemente un rectángulo redondeado
            startX: 0
            startY: 0

            PathLine {
                x: root.width
                y: 0
            }

            PathLine {
                x: root.width - 12
                y: root.height
            }

            PathLine {
                x: 12
                y: root.height
            }

            PathLine {
                x: 0
                y: 0
            }

        }

    }

    ColumnLayout {
        id: mainLayout

        anchors.centerIn: parent
        spacing: 12

        // Art & Info
        RowLayout {
            spacing: 16

            // Album Art
            Rectangle {
                width: 64
                height: 64
                radius: 8
                color: Colors.background
                clip: true

                Image {
                    anchors.fill: parent
                    source: MediaService.artUrl ? MediaService.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: MediaService.artUrl !== ""
                }

                Icon {
                    anchors.centerIn: parent
                    size: 32
                    name: "multimedia-audio-player"
                    color: Colors.textDim
                    visible: MediaService.artUrl === ""
                }

            }

            // Info (Title / Artist)
            ColumnLayout {
                spacing: 4
                Layout.preferredWidth: 160

                Text {
                    text: MediaService.hasMedia ? MediaService.rawTitle || "Desconocido" : "Sin reproducción"
                    color: Colors.text
                    font.pixelSize: Metrics.textSizeMedium
                    font.family: Typography.family
                    font.weight: Typography.weightBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: MediaService.hasMedia ? MediaService.rawArtist || "Desconocido" : ""
                    color: Colors.textMuted
                    font.pixelSize: Metrics.textSizeNormal
                    font.family: Typography.family
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: MediaService.hasMedia
                }

            }

        }

        // Barra de progreso estática
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Colors.background

            Rectangle {
                width: parent.width * MediaService.progress
                height: parent.height
                radius: 2
                color: Colors.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Metrics.animNormal
                    }

                }

            }

        }

        // Controles grandes
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            IconButton {
                buttonSize: Metrics.iconSizeLarge + 2
                iconName: "media-skip-backward"
                iconColor: Colors.text
                onClicked: MediaService.previous()
            }

            IconButton {
                buttonSize: Metrics.iconSizeLarge + 8
                iconName: MediaService.isPlaying ? "media-playback-pause" : "media-playback-start"
                iconColor: Colors.text
                onClicked: MediaService.playPause()
            }

            IconButton {
                buttonSize: Metrics.iconSizeLarge + 2
                iconName: "media-skip-forward"
                iconColor: Colors.text
                onClicked: MediaService.next()
            }

        }

    }

}
