import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services"
import "../../components"

// NotificationPopup: PopUp para notificaciones entrantes.
// Ubicado debajo de la barra central, con estilo opaco idéntico a las ventanas desplegables
// (Colors.surface y borde Colors.surfaceRaised).
// - Reproducción Spotify: Degradado de 3 paradas basado en los colores predominantes del álbum
//   y formateo estricto "{álbum} - {artista}".
// - Terminales: Glifos ASCII personalizados para agentes IA (▲, ✻, ✳, ⯌, ❯_, >_).
// - Aplicaciones estándar: Icono vectorial nativo y color de marca.

PanelWindow {
    id: root

    WlrLayershell.namespace: "cocoa-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    // Anclado en la parte superior central, debajo de la barra central
    anchors { top: true }
    margins { top: Metrics.barHeight + 6 }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // La superficie solo se mapea cuando hay notificación activa y el panel no está desacoplado
    visible: NotificationService.hasActiveNotification && !NotificationService.centralPanelDetached

    implicitWidth: card.width
    implicitHeight: card.height

    Rectangle {
        id: card
        width: Math.min(Math.max(contentRow.implicitWidth + 24, 180), 450)
        height: 34
        radius: 12

        // Estilo opaco idéntico a la ventana desplegable
        color: Colors.surface
        border.color: Colors.surfaceRaised
        border.width: 1
        clip: true

        // Animación suave de entrada y salida
        opacity: root.visible ? 1.0 : 0.0
        scale: root.visible ? 1.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        // Degradado horizontal interno: 3 paradas para paleta de álbum de Spotify o degradado de marca/agente
        Rectangle {
            id: internalGradient
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            clip: true

            readonly property color baseColor: NotificationService.gradientColor
            readonly property bool isSpotify: NotificationService.isSpotifyTrack
            readonly property var palette: NotificationService.albumPalette

            readonly property color c1: (isSpotify && palette && palette.length >= 3) ? palette[0] : baseColor
            readonly property color c2: (isSpotify && palette && palette.length >= 3) ? palette[1] : baseColor
            readonly property color c3: (isSpotify && palette && palette.length >= 3) ? palette[2] : baseColor

            gradient: Gradient {
                orientation: Gradient.Horizontal

                // Parada 1: primer color predominante
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(internalGradient.c1.r, internalGradient.c1.g, internalGradient.c1.b, internalGradient.isSpotify ? 0.40 : 0.35)
                }
                // Parada 2: segundo color predominante
                GradientStop {
                    position: 0.45
                    color: Qt.rgba(internalGradient.c2.r, internalGradient.c2.g, internalGradient.c2.b, internalGradient.isSpotify ? 0.22 : 0.08)
                }
                // Parada 3: tercer color predominante
                GradientStop {
                    position: 0.80
                    color: Qt.rgba(internalGradient.c3.r, internalGradient.c3.g, internalGradient.c3.b, internalGradient.isSpotify ? 0.10 : 0.0)
                }
                // Parada 4: disipación total a transparente sobre fondo opaco
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationService.dismissCurrent()
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            readonly property bool hasValidAppIcon: (NotificationService.currentIcon !== "" &&
                (Quickshell.hasThemeIcon(NotificationService.currentIcon) || NotificationService.currentIcon.startsWith("/"))) ||
                NotificationService.isSpotifyTrack

            // Glifo ASCII para agentes de terminal (▲, ✻, ✳, ⯌, ❯_, >_)
            Text {
                id: agentAsciiIcon
                text: NotificationService.asciiIcon
                color: NotificationService.gradientColor
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
                font.weight: Typography.weightBold
                visible: NotificationService.isAgentOrTerminal && NotificationService.asciiIcon !== ""
                Layout.alignment: Qt.AlignVCenter
            }

            // Icono únicamente del programa origen para aplicaciones estándar y Spotify
            Icon {
                id: appIcon
                size: 16
                name: NotificationService.isSpotifyTrack ? "spotify" : NotificationService.currentIcon
                color: Colors.text
                visible: !NotificationService.isAgentOrTerminal && contentRow.hasValidAppIcon
                Layout.alignment: Qt.AlignVCenter
            }

            // Muestra: "{album} - {artista}" en Spotify, o "{programa}:{mensaje} {hora}" en otras apps
            Text {
                id: notificationLabel
                text: NotificationService.formattedText
                color: Colors.text
                font.pixelSize: Metrics.textSizeNormal - 1
                font.family: Typography.family
                elide: Text.ElideRight
                Layout.maximumWidth: 380
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
