import QtQuick
import "../theme"

// Botón de icono mínimo: sin background, solo el icono con hover de color.
// No usa rectángulos de fondo ni bordes.

Item {
    id: root

    property string iconName:  ""
    property color  iconColor: Colors.textMuted
    property int    buttonSize: Metrics.iconSizeLarge

    signal clicked()

    width:  buttonSize
    height: buttonSize

    Icon {
        anchors.centerIn: parent
        name:  root.iconName
        size:  Math.max(10, root.buttonSize - 2)
        color: area.containsMouse
               ? Qt.lighter(root.iconColor, 1.3)
               : root.iconColor

        Behavior on color { ColorAnimation { duration: Metrics.animFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
