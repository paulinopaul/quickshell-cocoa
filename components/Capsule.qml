import "../theme"
import QtQuick

Rectangle {
    id: root

    property bool interactive: true
    property bool active: false
    property color baseColor: Colors.surface
    property color activeColor: Colors.surfaceActive
    property color hoverColor: Colors.surfaceHover
    property color baseBorderColor: Colors.border
    property color activeBorderColor: Colors.borderActive

    signal clicked()
    signal rightClicked()
    signal wheelScrolled(int angleDelta)

    height: Metrics.capsuleHeight
    radius: Metrics.capsuleRadius
    color: active ? activeColor : (mouseArea.containsMouse && interactive ? hoverColor : baseColor)
    border.color: active ? activeBorderColor : baseBorderColor
    border.width: Metrics.borderWidth

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onWheel: (wheel) => {
            root.wheelScrolled(wheel.angleDelta.y);
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Metrics.animFast
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: Metrics.animFast
        }

    }

}
