import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property var sinks: []
    property var sources: []
    property bool isLoading: false

    readonly property string _script: Qt.resolvedUrl("../../scripts/audio_manager.py").toString().replace("file://", "")

    property string _buffer: ""

    property Process loadProc: Process {
        command: ["python3", root._script, "list"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.sinks || parsed.sources) {
                        if (parsed.sinks) root.sinks = parsed.sinks;
                        if (parsed.sources) root.sources = parsed.sources;
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
                    if (parsed.sinks) root.sinks = parsed.sinks;
                    if (parsed.sources) root.sources = parsed.sources;
                } catch (e) {}
                root._buffer = "";
            }
        }
    }

    property Process actionProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
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

    onVisibleChanged: if (visible && root.sinks.length === 0) root.refresh()

    function setDefaultDevice(id) {
        actionProc.command = ["python3", root._script, "set-default", id.toString()];
        actionProc.running = true;
    }

    function setDeviceVolume(id, vol) {
        actionProc.command = ["python3", root._script, "set-volume", id.toString(), vol.toString()];
        actionProc.running = true;
    }

    function toggleDeviceMute(id) {
        actionProc.command = ["python3", root._script, "toggle-mute", id.toString()];
        actionProc.running = true;
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
                    text: "Sonido y Dispositivos de Audio"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Control de enrutamiento PipeWire: salida y captura de micrófono"
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: audioContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: audioContentCol
                    width: parent.width
                    spacing: 12

                    // ── SECCIÓN 1: SALIDA DE AUDIO ─────────────────────────────
                    Text {
                        text: "Dispositivos de Salida (Altavoces y Auriculares)"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.sinks

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitHeight: 64
                                radius: 10
                                color: modelData.isDefault
                                       ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                                       : Colors.surface
                                border.color: modelData.isDefault ? Colors.accent : Colors.surfaceRaised
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Icon {
                                        size: 20
                                        name: modelData.isMuted ? "audio-volume-muted" : "audio-volume-high"
                                        color: modelData.isDefault ? Colors.accent : Colors.textMuted
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.name || "Salida de audio"
                                            color: Colors.text
                                            font.pixelSize: 12
                                            font.weight: modelData.isDefault ? Typography.weightBold : Typography.weightNormal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.isDefault ? ("Activo como predeterminado • Vol: " + Math.round(modelData.volume * 100) + "%") : "Haz clic para seleccionar"
                                            color: modelData.isDefault ? Colors.accent : Colors.textDim
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Botón Mute
                                    Rectangle {
                                        implicitWidth: 64
                                        implicitHeight: 28
                                        radius: 6
                                        color: muteMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isMuted ? "Silenciado" : "Silenciar"
                                            color: modelData.isMuted ? Colors.stateError : Colors.textMuted
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            id: muteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleDeviceMute(modelData.id)
                                        }
                                    }

                                    // Badge / Selector
                                    Rectangle {
                                        implicitWidth: 84
                                        implicitHeight: 28
                                        radius: 6
                                        color: modelData.isDefault ? Colors.accent : Colors.surfaceRaised

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isDefault ? "✓ Activo" : "Seleccionar"
                                            color: modelData.isDefault ? Colors.background : Colors.textMuted
                                            font.pixelSize: 11
                                            font.weight: Typography.weightMedium
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefaultDevice(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // ── SECCIÓN 2: ENTRADA DE AUDIO (MICRÓFONOS) ────────────────
                    Text {
                        text: "Dispositivos de Entrada (Micrófonos)"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.sources

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitHeight: 64
                                radius: 10
                                color: modelData.isDefault
                                       ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                                       : Colors.surface
                                border.color: modelData.isDefault ? Colors.accent : Colors.surfaceRaised
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Icon {
                                        size: 20
                                        name: modelData.isMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
                                        color: modelData.isDefault ? Colors.accent : Colors.textMuted
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.name || "Micrófono"
                                            color: Colors.text
                                            font.pixelSize: 12
                                            font.weight: modelData.isDefault ? Typography.weightBold : Typography.weightNormal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.isDefault ? ("Micrófono activo • Nivel: " + Math.round(modelData.volume * 100) + "%") : "Haz clic para seleccionar"
                                            color: modelData.isDefault ? Colors.accent : Colors.textDim
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Botón Mute Mic
                                    Rectangle {
                                        implicitWidth: 64
                                        implicitHeight: 28
                                        radius: 6
                                        color: micMuteMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isMuted ? "Silenciado" : "Silenciar"
                                            color: modelData.isMuted ? Colors.stateError : Colors.textMuted
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            id: micMuteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleDeviceMute(modelData.id)
                                        }
                                    }

                                    // Badge / Selector
                                    Rectangle {
                                        implicitWidth: 84
                                        implicitHeight: 28
                                        radius: 6
                                        color: modelData.isDefault ? Colors.accent : Colors.surfaceRaised

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isDefault ? "✓ Activo" : "Seleccionar"
                                            color: modelData.isDefault ? Colors.background : Colors.textMuted
                                            font.pixelSize: 11
                                            font.weight: Typography.weightMedium
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setDefaultDevice(modelData.id)
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
