import QtQuick
import "../../theme"

// WallpaperCard — Tarjeta de previsualización de fondo de pantalla en modo carrusel.
//
// Estilo Cocoa opaco:
// - color: Colors.surface, radius: 14.
// - Borde reactivo: 2px Colors.accent para activo, 1px Colors.surfaceRaised para inactivo.
// - Transiciones fluidas de escala (1.05 / 0.92) y opacidad (1.0 / 0.55).
// - Carga de imagen asíncrona de alto rendimiento (sourceSize acotado a 320x180, PreserveAspectCrop).

Rectangle {
    id: root

    property string filePath: ""
    property string fileName: ""
    property bool isCurrent: false

    signal clicked()
    signal doubleClicked()

    width: 320
    height: 180
    radius: 14
    color: Colors.surface
    border.width: isCurrent ? 2 : 1
    border.color: isCurrent ? Colors.accent : Colors.surfaceRaised
    clip: true

    scale: isCurrent ? 1.05 : 0.92
    opacity: isCurrent ? 1.0 : 0.55

    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutQuad
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 180
        }
    }

    Image {
        id: image
        anchors.fill: parent
        anchors.margins: root.border.width
        asynchronous: true
        sourceSize.width: 320
        sourceSize.height: 180
        fillMode: Image.PreserveAspectCrop
        clip: true
        source: root.filePath ? ("file://" + root.filePath) : ""
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
    }
}
