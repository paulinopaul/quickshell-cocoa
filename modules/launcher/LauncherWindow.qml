import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../../components"

PanelWindow {
    id: root

    property bool isOpen: false
    property int  selectedIndex: 0
    property string searchQuery: ""
    readonly property var filteredApps: AppService.search(searchQuery)

    WlrLayershell.namespace: "cocoa-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }

    color: "transparent"
    visible: isOpen

    function open(): void {
        searchQuery = "";
        selectedIndex = 0;
        isOpen = true;
        searchInput.forceActiveFocus();
    }

    function close(): void {
        isOpen = false;
        searchQuery = "";
        selectedIndex = 0;
    }

    function toggle(): void {
        if (isOpen) close();
        else open();
    }

    // Integración atajo global de Hyprland (SUPER + SPACE)
    GlobalShortcut {
        name: "launcher"
        onPressed: root.toggle()
    }

    // Fondo backdrop: click cierra el launcher
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Modal central
    Rectangle {
        id: card
        width: 500
        height: 460
        anchors.centerIn: parent
        radius: 8
        color: Colors.surfaceRaised

        // Absorbe clicks internos para que no disparen el cierre
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Barra de búsqueda
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: Colors.surface
                border.color: searchInput.activeFocus ? Colors.accent : Colors.textDim
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Icon {
                        size: Metrics.iconSizeSmall
                        name: "system-search"
                        color: Colors.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Colors.text
                        font.pixelSize: Metrics.textSizeNormal
                        font.family: Typography.family
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Buscar aplicación…"
                            color: Colors.textDim
                            font: searchInput.font
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                            root.selectedIndex = 0;
                        }

                        Keys.onDownPressed: {
                            if (root.filteredApps.length > 0) {
                                root.selectedIndex = Math.min(root.filteredApps.length - 1,
                                                              root.selectedIndex + 1);
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }

                        Keys.onUpPressed: {
                            if (root.filteredApps.length > 0) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.filteredApps.length > root.selectedIndex) {
                                const app = root.filteredApps[root.selectedIndex];
                                root.close();
                                AppService.launch(app);
                            }
                        }

                        Keys.onEscapePressed: root.close()
                    }
                }
            }

            // Lista de resultados
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: root.filteredApps

                delegate: AppItem {
                    required property var modelData
                    required property int index

                    width: listView.width
                    app: modelData
                    isSelected: index === root.selectedIndex

                    onLaunched: {
                        root.close();
                        AppService.launch(modelData);
                    }
                }

                // Estado vacío
                Text {
                    anchors.centerIn: parent
                    visible: root.filteredApps.length === 0
                    text: "Sin resultados"
                    color: Colors.textDim
                    font.pixelSize: Metrics.textSizeNormal
                    font.family: Typography.family
                }
            }
        }
    }
}
