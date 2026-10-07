import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property var monitors: []
    property int selectedMonIndex: 0
    property string selectedRes: "1920x1080"
    property real selectedHz: 144.0
    property real selectedScale: 1.0
    property bool isLoading: false
    property string statusMessage: ""

    readonly property string _script: Qt.resolvedUrl("../../scripts/display_manager.py").toString().replace("file://", "")

    property string _buffer: ""

    property Process loadProc: Process {
        command: ["python3", root._script, "list"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.monitors = parsed;
                        let m = parsed[root.selectedMonIndex] || parsed[0];
                        root.selectedRes = m.width + "x" + m.height;
                        root.selectedHz = m.refreshRate;
                        root.selectedScale = m.scale;
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
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.monitors = parsed;
                        let m = parsed[root.selectedMonIndex] || parsed[0];
                        root.selectedRes = m.width + "x" + m.height;
                        root.selectedHz = m.refreshRate;
                        root.selectedScale = m.scale;
                    }
                } catch (e) {}
                root._buffer = "";
            }
        }
    }

    property Process applyProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root.statusMessage = "Resolución y escala aplicadas en Hyprland.";
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

    function applyConfig() {
        if (root.monitors.length === 0) return;
        let m = root.monitors[root.selectedMonIndex] || root.monitors[0];
        let parts = root.selectedRes.split("x");
        let w = parseInt(parts[0]) || 1920;
        let h = parseInt(parts[1]) || 1080;

        applyProc.command = [
            "python3", root._script, "set",
            m.name, w.toString(), h.toString(), root.selectedHz.toString(), root.selectedScale.toString()
        ];
        applyProc.running = true;
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
                    text: "Pantalla y Monitores"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Configuración de resolución, tasa de refresco y escalado de Hyprland"
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
                    Text { text: root.isLoading ? "Cargando..." : "Detectar"; color: Colors.text; font.pixelSize: 11; font.weight: Typography.weightMedium }
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
            implicitHeight: 34
            radius: 8
            visible: root.statusMessage !== ""
            color: Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.15)
            border.color: Colors.stateOk
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.statusMessage
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
                contentHeight: displayContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: displayContentCol
                    width: parent.width
                    spacing: 12

                    // Monitor Card
                    Repeater {
                        model: root.monitors

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 70
                            radius: 10
                            color: root.selectedMonIndex === index
                                   ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                                   : Colors.surface
                            border.color: root.selectedMonIndex === index ? Colors.accent : Colors.surfaceRaised
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Icon {
                                    size: 24
                                    name: "display-brightness-symbolic"
                                    color: Colors.accent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: (modelData.name || "Monitor") + " — " + (modelData.description || "Pantalla principal")
                                        color: Colors.text
                                        font.pixelSize: 13
                                        font.weight: Typography.weightBold
                                    }

                                    Text {
                                        text: "Actual: " + modelData.width + "x" + modelData.height + " @ " + modelData.refreshRate + "Hz • Escala: " + modelData.scale + "x"
                                        color: Colors.textMuted
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // Selector de Resolución
                    Text {
                        text: "Resolución de Pantalla"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: ["1920x1080", "1600x900", "1366x768", "1280x720"]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                implicitWidth: 100
                                implicitHeight: 34
                                radius: 8
                                color: root.selectedRes === modelData
                                       ? Colors.accent
                                       : resMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.selectedRes === modelData ? Colors.background : Colors.text
                                    font.pixelSize: 11
                                    font.weight: root.selectedRes === modelData ? Typography.weightBold : Typography.weightNormal
                                }

                                MouseArea {
                                    id: resMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedRes = modelData
                                }
                            }
                        }
                    }

                    // Selector de Tasa de Refresco
                    Text {
                        text: "Tasa de Refresco (Hz)"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [144.0, 120.0, 75.0, 60.0]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                implicitWidth: 80
                                implicitHeight: 34
                                radius: 8
                                color: Math.round(root.selectedHz) === Math.round(modelData)
                                       ? Colors.accent
                                       : hzMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + " Hz"
                                    color: Math.round(root.selectedHz) === Math.round(modelData) ? Colors.background : Colors.text
                                    font.pixelSize: 11
                                    font.weight: Math.round(root.selectedHz) === Math.round(modelData) ? Typography.weightBold : Typography.weightNormal
                                }

                                MouseArea {
                                    id: hzMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedHz = modelData
                                }
                            }
                        }
                    }

                    // Selector de Escalado
                    Text {
                        text: "Escalado de Interfaz (Scale)"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { label: "1.0x (100%)", val: 1.0 },
                                { label: "1.25x (125%)", val: 1.25 },
                                { label: "1.5x (150%)", val: 1.5 },
                                { label: "2.0x (200%)", val: 2.0 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                implicitWidth: 95
                                implicitHeight: 34
                                radius: 8
                                color: root.selectedScale === modelData.val
                                       ? Colors.accent
                                       : scMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: root.selectedScale === modelData.val ? Colors.background : Colors.text
                                    font.pixelSize: 11
                                    font.weight: root.selectedScale === modelData.val ? Typography.weightBold : Typography.weightNormal
                                }

                                MouseArea {
                                    id: scMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedScale = modelData.val
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // Botón Aplicar
                    Rectangle {
                        implicitWidth: 180
                        implicitHeight: 38
                        radius: 8
                        color: applyBtnMouse.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Aplicar y Guardar"
                            color: Colors.background
                            font.pixelSize: 12
                            font.weight: Typography.weightBold
                        }

                        MouseArea {
                            id: applyBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyConfig()
                        }
                    }
                }
            }
        }
    }
}
