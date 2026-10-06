import QtQuick
import "../theme"

// Barra de progreso mínima, horizontal.
Item {
    id: root

    property real  value:    0.0
    property color barColor: Colors.textDim
    property int   barHeight: 3

    implicitWidth:  50
    implicitHeight: barHeight

    Rectangle {
        anchors.fill: parent
        color:        Colors.surfaceRaised
        radius:       root.barHeight / 2
    }

    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        radius:         root.barHeight / 2
        color:          root.barColor
        width: Math.max(0, Math.min(parent.width,
               parent.width * Math.max(0.0, Math.min(1.0, root.value))))

        Behavior on width {
            NumberAnimation { duration: Metrics.animFast; easing.type: Easing.OutQuad }
        }
    }
}
