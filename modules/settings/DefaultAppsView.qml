import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property var currentDefaults: ({ "terminal": "ghostty", "browser": "firefox", "fileManager": "dolphin", "editor": "code" })
    property var candidates: ({ "terminal": [], "browser": [], "fileManager": [], "editor": [] })
    property bool isLoading: false
    property string statusMsg: ""

    readonly property string _script: Qt.resolvedUrl("../../scripts/default_apps_manager.py").toString().replace("file://", "")

    property string _buffer: ""

    property Process loadProc: Process {
        command: ["python3", root._script, "get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.current) {
                        root.currentDefaults = parsed.current;
                        if (parsed.candidates) root.candidates = parsed.candidates;
                        return;
                    }
                } catch (e) {}
                root._buffer += data;
            }
        }
        onExited: (exitCode) => {
            root.isLoading = false;
            if (root._buffer && root._buffer.trim() !== "") {
                try {
                    let parsed = JSON.parse(root._buffer.trim());
                    if (parsed.current) root.currentDefaults = parsed.current;
                    if (parsed.candidates) root.candidates = parsed.candidates;
                } catch (e) {}
                root._buffer = "";
            }
        }
    }

    property Process setProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.statusMsg = "Aplicación predeterminada actualizada correctamente.";
            root.refresh();
        }
    }

    function refresh() {
        if (isLoading) return;
        isLoading = true;
        _buffer = "";
        loadProc.running = false;
        loadProc.running = true;
    }

    onVisibleChanged: if (visible) root.refresh()

    function setDefault(category, app) {
        statusMsg = "";
        setProc.command = ["python3", root._script, "set", category, app];
        setProc.running = true;
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Aplicaciones Predeterminadas"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Configuración de terminal, navegador web, gestor de archivos y editor"
                    color: Colors.textMuted
                    font.pixelSize: 13
                }
            }

            Rectangle {
                implicitWidth: 100
                implicitHeight: 32
                radius: 8
                color: refreshMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised
                border.color: Colors.surfaceHover
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { size: 13; name: "system-reboot"; color: root.isLoading ? Colors.accent : Colors.text }
                    Text { text: root.isLoading ? "Cargando..." : "Actualizar"; color: Colors.text; font.pixelSize: 11; font.weight: Typography.weightMedium }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }

        // Status banner
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 8
            visible: root.statusMsg !== ""
            color: Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.15)
            border.color: Colors.stateOk
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.statusMsg
                color: Colors.stateOk
                font.pixelSize: 11
                font.weight: Typography.weightMedium
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: appsContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: appsContentCol
                    width: parent.width
                    spacing: 12

                    // 1. TERMINAL
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: termCol.implicitHeight + 20
                        radius: 10
                        color: Colors.surface
                        border.color: Colors.surfaceRaised
                        border.width: 1

                        ColumnLayout {
                            id: termCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Icon { size: 18; name: "application-x-executable"; color: Colors.accent }
                                Text { text: "Terminal del Sistema ($terminal)"; color: Colors.text; font.pixelSize: 13; font.weight: Typography.weightBold; Layout.fillWidth: true }
                                Text { text: "Actual: " + root.currentDefaults.terminal; color: Colors.accent; font.pixelSize: 11; font.weight: Typography.weightMedium }
                            }

                            Text { text: "Candidatos detectados en el sistema:"; color: Colors.textMuted; font.pixelSize: 11 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.candidates.terminal || []

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: termCandidateText.implicitWidth + 24
                                        implicitHeight: 30
                                        radius: 6
                                        color: root.currentDefaults.terminal === modelData ? Colors.accent : cMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            id: termCandidateText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.currentDefaults.terminal === modelData ? Colors.background : Colors.text
                                            font.pixelSize: 11
                                            font.weight: root.currentDefaults.terminal === modelData ? Typography.weightBold : Typography.weightNormal
                                        }

                                        MouseArea {
                                            id: cMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefault("terminal", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. NAVEGADOR WEB
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: brCol.implicitHeight + 20
                        radius: 10
                        color: Colors.surface
                        border.color: Colors.surfaceRaised
                        border.width: 1

                        ColumnLayout {
                            id: brCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Icon { size: 18; name: "network-wireless"; color: Colors.accent }
                                Text { text: "Navegador Web Predeterminado (HTTP/HTTPS)"; color: Colors.text; font.pixelSize: 13; font.weight: Typography.weightBold; Layout.fillWidth: true }
                                Text { text: "Actual: " + root.currentDefaults.browser; color: Colors.accent; font.pixelSize: 11; font.weight: Typography.weightMedium }
                            }

                            Text { text: "Candidatos detectados en el sistema:"; color: Colors.textMuted; font.pixelSize: 11 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.candidates.browser || []

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: brCandidateText.implicitWidth + 24
                                        implicitHeight: 30
                                        radius: 6
                                        color: root.currentDefaults.browser === modelData ? Colors.accent : bMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            id: brCandidateText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.currentDefaults.browser === modelData ? Colors.background : Colors.text
                                            font.pixelSize: 11
                                            font.weight: root.currentDefaults.browser === modelData ? Typography.weightBold : Typography.weightNormal
                                        }

                                        MouseArea {
                                            id: bMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefault("browser", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. GESTOR DE ARCHIVOS
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: fmCol.implicitHeight + 20
                        radius: 10
                        color: Colors.surface
                        border.color: Colors.surfaceRaised
                        border.width: 1

                        ColumnLayout {
                            id: fmCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Icon { size: 18; name: "app-window"; color: Colors.accent }
                                Text { text: "Gestor de Archivos (Carpetas)"; color: Colors.text; font.pixelSize: 13; font.weight: Typography.weightBold; Layout.fillWidth: true }
                                Text { text: "Actual: " + root.currentDefaults.fileManager; color: Colors.accent; font.pixelSize: 11; font.weight: Typography.weightMedium }
                            }

                            Text { text: "Candidatos detectados en el sistema:"; color: Colors.textMuted; font.pixelSize: 11 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.candidates.fileManager || []

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: fmCandidateText.implicitWidth + 24
                                        implicitHeight: 30
                                        radius: 6
                                        color: root.currentDefaults.fileManager.includes(modelData) ? Colors.accent : fmMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            id: fmCandidateText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.currentDefaults.fileManager.includes(modelData) ? Colors.background : Colors.text
                                            font.pixelSize: 11
                                            font.weight: root.currentDefaults.fileManager.includes(modelData) ? Typography.weightBold : Typography.weightNormal
                                        }

                                        MouseArea {
                                            id: fmMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefault("fileManager", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 4. EDITOR DE CÓDIGO
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: edCol.implicitHeight + 20
                        radius: 10
                        color: Colors.surface
                        border.color: Colors.surfaceRaised
                        border.width: 1

                        ColumnLayout {
                            id: edCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Icon { size: 18; name: "hub"; color: Colors.accent }
                                Text { text: "Editor de Texto / Código"; color: Colors.text; font.pixelSize: 13; font.weight: Typography.weightBold; Layout.fillWidth: true }
                                Text { text: "Actual: " + root.currentDefaults.editor; color: Colors.accent; font.pixelSize: 11; font.weight: Typography.weightMedium }
                            }

                            Text { text: "Candidatos detectados en el sistema:"; color: Colors.textMuted; font.pixelSize: 11 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.candidates.editor || []

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: edCandidateText.implicitWidth + 24
                                        implicitHeight: 30
                                        radius: 6
                                        color: root.currentDefaults.editor === modelData ? Colors.accent : edMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            id: edCandidateText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.currentDefaults.editor === modelData ? Colors.background : Colors.text
                                            font.pixelSize: 11
                                            font.weight: root.currentDefaults.editor === modelData ? Typography.weightBold : Typography.weightNormal
                                        }

                                        MouseArea {
                                            id: edMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefault("editor", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
