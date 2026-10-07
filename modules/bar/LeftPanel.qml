import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../theme"
import "../../services"
import "../../components"

// Panel izquierdo — pentágono:
// Rectángulo delgado, solo la esquina INFERIOR-DERECHA está recortada diagonalmente.
// El resto del panel es rectangular.
//
//   TL ─────────────────── TR
//   |                       |
//   |                        \
//   BL ─────────────── BR'    (BR' = TR - skew en X, BL en Y)
//
//  5 puntos: TL → TR → TR+(0,height-skew) → TR+(−skew,height) → BL

Item {
    id: root

    signal launcherRequested()

    visible: UiConfigService.leftPanel.visible !== false

    readonly property int sk:  Metrics.sideTrapSkew   // Magnitud del recorte diagonal
    readonly property int ph:  Metrics.sideHeight      // Altura del panel

    implicitWidth:  contentRow.implicitWidth + Metrics.innerPadH * 2 + sk
    implicitHeight: ph

    // Pentágono: rectángulo con esquina inferior-derecha recortada
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor:   Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, UiConfigService.leftPanel.bgOpacity !== undefined ? UiConfigService.leftPanel.bgOpacity : 1.0)
            strokeColor: Colors.surfaceBorder
            strokeWidth: UiConfigService.leftPanel.borderWidth !== undefined ? UiConfigService.leftPanel.borderWidth : 1

            startX: 0;        startY: 0
            PathLine { x: root.width;        y: 0 }
            PathLine { x: root.width - root.sk; y: root.ph }
            PathLine { x: 0;                 y: root.ph }
            PathLine { x: 0;                 y: 0 }
        }
    }

    // Contenido
    RowLayout {
        id: contentRow
        anchors.left:            parent.left
        anchors.leftMargin:      Metrics.innerPadH
        anchors.verticalCenter:  parent.verticalCenter
        spacing: Metrics.itemSpacing

        // Indicadores de workspaces
        Row {
            visible: UiConfigService.leftPanel.showWorkspaces !== false
            spacing: 4

            Repeater {
                model: HyprlandService.workspaces
                delegate: Rectangle {
                    id: wsDot
                    required property var  modelData
                    readonly property bool active:  HyprlandService.focusedWorkspaceId === modelData.id
                    readonly property bool occupied: modelData.toplevels &&
                                                     modelData.toplevels.values &&
                                                     modelData.toplevels.values.length > 0

                    width:  active ? 14 : 5
                    height: 3
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: active   ? Colors.text :
                           occupied ? Colors.textMuted : Colors.textDim

                    Behavior on width { NumberAnimation { duration: Metrics.animFast; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation  { duration: Metrics.animFast } }

                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     HyprlandService.focusWorkspace(modelData.id)
                    }
                }
            }
        }

        // Separador
        Rectangle {
            width: 1; height: 10
            color: Colors.textDim
            opacity: 0.5
            visible: (UiConfigService.leftPanel.showWorkspaces !== false) && (UiConfigService.leftPanel.showActiveWindow !== false) && (HyprlandService.windowTitle !== "Desktop" && HyprlandService.windowTitle !== "")
        }

        // Icono + clase de la app activa (envuelto en Item para que MouseArea pueda usar anchors)
        Item {
            implicitWidth:  appRow.implicitWidth
            implicitHeight: appRow.implicitHeight
            visible: UiConfigService.leftPanel.showActiveWindow !== false && HyprlandService.windowTitle !== "Desktop" && HyprlandService.windowTitle !== ""

            RowLayout {
                id: appRow
                anchors.fill: parent
                spacing: 5

                Icon {
                    size:  Metrics.iconSizeSmall
                    name:  HyprlandService.displayIcon
                    color: Colors.textMuted
                }

                Text {
                    text: {
                        let app = HyprlandService.displayAppName;
                        let title = HyprlandService.windowTitle;
                        let c = (app && app !== title) ? app + " · " + title : title;
                        return c.length > 25 ? c.substring(0, 23) + "…" : c;
                    }
                    color:            Colors.textMuted
                    font.pixelSize:   Metrics.textSizeNormal
                    font.family:      Typography.family
                    font.weight:      Typography.weightNormal
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root.launcherRequested()
            }
        }
    }
}
