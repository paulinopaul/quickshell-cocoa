import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

Item {
    id: root

    property string tabId: ""
    property string label: ""
    property string iconName: ""
    property bool   isActive: false

    signal clicked()

    implicitWidth: 160
    implicitHeight: 40

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 10
        color: root.isActive
               ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
               : mouseArea.containsMouse
                 ? Colors.surfaceHover
                 : "transparent"

        border.color: root.isActive ? Colors.accent : "transparent"
        border.width: root.isActive ? 1 : 0

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Icon {
                size: 16
                name: root.iconName
                color: root.isActive ? Colors.accent : (mouseArea.containsMouse ? Colors.text : Colors.textMuted)
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                text: root.label
                color: root.isActive ? Colors.accent : (mouseArea.containsMouse ? Colors.text : Colors.textMuted)
                font.pixelSize: 13
                font.weight: root.isActive ? Typography.weightBold : Typography.weightNormal
                Layout.fillWidth: true
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
