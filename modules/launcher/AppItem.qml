import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

Rectangle {
    id: root

    property var  app: null
    property bool isSelected: false

    signal launched()

    height: 44
    radius: 6
    color: isSelected
           ? Colors.surfaceHover
           : (mouseArea.containsMouse ? Colors.surfaceRaised : "transparent")

    Behavior on color { ColorAnimation { duration: Metrics.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Icon {
            size: 24
            name: root.app ? (root.app.icon || "application-x-executable") : "application-x-executable"
            color: Colors.textMuted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.app ? (root.app.name || "Unknown") : ""
                color: root.isSelected ? Colors.text : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.family
                font.weight: Typography.weightMedium
                elide: Text.ElideRight
            }

            Text {
                text: root.app ? (root.app.comment || root.app.id || "") : ""
                color: Colors.textDim
                font.pixelSize: Metrics.textSizeSmall
                font.family: Typography.family
                font.weight: Typography.weightNormal
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.launched()
    }
}
