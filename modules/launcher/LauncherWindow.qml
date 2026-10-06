import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../../components"

// LauncherWindow: Lanzador modal anclado a la parte inferior central.
// Emerge desde abajo con rebote elástico (OutBack) y se oculta con salto de anticipación
// y deslizamiento hacia abajo (jump & dive), desmapeando Wayland al terminar.

PanelWindow {
    id: root

    property bool isOpen: false
    property bool surfaceActive: false
    property int  selectedIndex: 0
    property string searchQuery: ""
    property bool mouseInside: false
    readonly property var filteredApps: AppService.search(searchQuery)

    WlrLayershell.namespace: "cocoa-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Anclado en la parte inferior central (centrado automático en Wayland)
    anchors { bottom: true }
    margins { bottom: 12 }

    implicitWidth: 520
    implicitHeight: 480
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // La superficie solo existe en Wayland mientras esté activa o en animación de salida
    visible: surfaceActive

    function open(): void {
        searchQuery = "";
        selectedIndex = 0;
        mouseInside = false;
        closeTimer.stop();
        exitAnim.stop();

        surfaceActive = true;
        isOpen = true;

        enterAnim.restart();
        searchInput.forceActiveFocus();
    }

    function close(): void {
        if (!isOpen && !surfaceActive) return;

        closeTimer.stop();
        mouseInside = false;
        isOpen = false; // Libera inmediatamente el foco de teclado de Wayland

        enterAnim.stop();
        exitAnim.restart();
    }

    function toggle(): void {
        if (isOpen) close();
        else open();
    }

    // Integración atajo global de Hyprland (SUPER + SPACE / SUPER + R)
    GlobalShortcut {
        name: "launcher"
        onPressed: root.toggle()
    }

    // Temporizador de estabilidad para cierre por salida de ratón
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: root.close()
    }

    // Animación de entrada: deslizamiento desde abajo con rebote OutBack
    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: card
            property: "y"
            from: root.implicitHeight + 40
            to: 20
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.35
        }
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
        }
    }

    // Animación de salida: Salto de anticipación hacia arriba (jump) y caída rápida (dive)
    SequentialAnimation {
        id: exitAnim

        // 1. Salto hacia arriba (jump)
        NumberAnimation {
            target: card
            property: "y"
            to: 4
            duration: 75
            easing.type: Easing.OutQuad
        }

        // 2. Caída acelerada hacia abajo (dive)
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "y"
                to: root.implicitHeight + 40
                duration: 190
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0.0
                duration: 190
            }
        }

        // 3. Desmapeo total de la superficie Wayland
        ScriptAction {
            script: {
                root.surfaceActive = false;
                root.searchQuery = "";
                root.selectedIndex = 0;
            }
        }
    }

    // Tarjeta del modal con margen superior para el salto de anticipación
    Rectangle {
        id: card
        x: 0
        y: 20
        width: parent.width
        height: parent.height - 20
        radius: 12
        color: Colors.surfaceRaised
        border.color: Colors.surface
        border.width: 1
        clip: true

        // Rastreo de presencia del cursor sobre la zona
        MouseArea {
            id: hoverTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: {
                root.mouseInside = true;
                closeTimer.stop();
            }

            onExited: {
                if (root.mouseInside && root.isOpen) {
                    closeTimer.restart();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Barra de búsqueda
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 8
                color: Colors.surface
                border.color: searchInput.activeFocus ? Colors.accent : Colors.textDim
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
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
                spacing: 4
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
