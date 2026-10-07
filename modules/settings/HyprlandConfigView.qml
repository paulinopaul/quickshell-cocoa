import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../components"

// HyprlandConfigView — Editor de la configuración principal de Hyprland:
// gaps, distribución de teclado, flags de miscelánea y aplicaciones al inicio (autostart).
// Aplica en vivo vía hyprctl y persiste en hyprland.conf usando hyprland_config_manager.py.

Item {
    id: root

    property int gapsIn: 5
    property int gapsOut: 15
    property string kbLayout: "latam"
    property bool focusOnActivate: true
    property bool disableLogo: true
    property bool disableSplash: true
    property var autostart: []

    property bool isLoading: false
    property bool mutating: false
    property bool feedbackOk: true
    property string feedbackMessage: ""
    property string _loadBuffer: ""
    property string _mutateBuffer: ""
    property bool _reloadAfterMutate: false

    readonly property string _script: Qt.resolvedUrl("../../scripts/hyprland_config_manager.py").toString().replace("file://", "")

    Timer {
        id: feedbackTimer
        interval: 3000
        onTriggered: root.feedbackMessage = ""
    }

    function setFeedback(msg, ok) {
        root.feedbackMessage = msg;
        root.feedbackOk = ok !== false;
        feedbackTimer.restart();
    }

    function reload() {
        if (root.isLoading) return;
        root.isLoading = true;
        root._loadBuffer = "";
        loadProc.running = false;
        loadProc.running = true;
    }

    function runSet(args, label, reloadAfter) {
        if (root.mutating) return;
        root.mutating = true;
        root._mutateBuffer = "";
        root._reloadAfterMutate = reloadAfter === true;
        mutateProc.command = ["python3", root._script].concat(args);
        mutateProc.running = false;
        mutateProc.running = true;
        if (label) setFeedback(label, true);
    }

    Process {
        id: loadProc
        running: false
        stdout: SplitParser {
            onRead: data => { if (data) root._loadBuffer += data; }
        }
        onExited: (exitCode) => {
            root.isLoading = false;
            let parsed = null;
            try { parsed = JSON.parse(root._loadBuffer.trim()); } catch (e) {}
            if (parsed && parsed.gaps_in !== undefined && parsed.gaps_out !== undefined) {
                root.gapsIn = parsed.gaps_in;
                root.gapsOut = parsed.gaps_out;
                root.kbLayout = parsed.kb_layout || "latam";
                root.focusOnActivate = !!parsed.focus_on_activate;
                root.disableLogo = !!parsed.disable_hyprland_logo;
                root.disableSplash = !!parsed.disable_splash_rendering;
                root.autostart = parsed.autostart || [];
            } else {
                setFeedback("No se pudo cargar la configuración de Hyprland", false);
            }
        }
    }

    Process {
        id: mutateProc
        running: false
        stdout: SplitParser {
            onRead: data => { if (data) root._mutateBuffer += data; }
        }
        onExited: (exitCode) => {
            root.mutating = false;
            let parsed = null;
            try { parsed = JSON.parse(root._mutateBuffer.trim()); } catch (e) {}
            let ok = parsed && parsed.success;
            let msg = parsed && parsed.error ? parsed.error : (ok ? "Configuración aplicada" : "Error al aplicar la configuración");
            setFeedback(msg, !!ok);
            if (root._reloadAfterMutate) {
                root._reloadAfterMutate = false;
                root.reload();
            }
        }
    }

    Component.onCompleted: root.reload()
    onVisibleChanged: if (visible) root.reload()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Encabezado ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Hyprland y Sistema"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Espaciado, teclado, comportamiento y aplicaciones al inicio de Hyprland"
                    color: Colors.textMuted
                    font.pixelSize: 12
                }
            }

            // Feedback Pill
            Rectangle {
                visible: root.feedbackMessage !== ""
                implicitHeight: 22
                implicitWidth: fbText.implicitWidth + 16
                radius: 11
                color: Qt.rgba(
                    root.feedbackOk ? Colors.stateOk.r : Colors.stateError.r,
                    root.feedbackOk ? Colors.stateOk.g : Colors.stateError.g,
                    root.feedbackOk ? Colors.stateOk.b : Colors.stateError.b,
                    0.2)
                border.color: root.feedbackOk ? Colors.stateOk : Colors.stateError
                border.width: 1

                Text {
                    id: fbText
                    anchors.centerIn: parent
                    text: root.feedbackMessage
                    color: root.feedbackOk ? Colors.stateOk : Colors.stateError
                    font.pixelSize: 11
                    font.weight: Typography.weightMedium
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                anchors.fill: parent
                contentHeight: hyprContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: hyprContentCol
                    width: parent.width - 8
                    spacing: 12

                    // ── SECCIÓN 1: ESPACIADO ENTRE VENTANAS (GAPS) ──────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: gapsCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: gapsCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Espaciado entre Ventanas (Gaps)"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            // Gaps internos
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Gaps Internos (gaps_in):"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 170
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 30
                                    stepSize: 1
                                    value: root.gapsIn
                                    onMoved: {
                                        let val = Math.round(value);
                                        root.gapsIn = val;
                                        root.runSet(["set", "gaps_in", val.toString()], "Gaps internos actualizados");
                                    }
                                }

                                Text {
                                    text: root.gapsIn + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 44
                                }
                            }

                            // Gaps externos
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Gaps Externos (gaps_out):"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 170
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 60
                                    stepSize: 1
                                    value: root.gapsOut
                                    onMoved: {
                                        let val = Math.round(value);
                                        root.gapsOut = val;
                                        root.runSet(["set", "gaps_out", val.toString()], "Gaps externos actualizados");
                                    }
                                }

                                Text {
                                    text: root.gapsOut + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 44
                                }
                            }
                        }
                    }

                    // ── SECCIÓN 2: TECLADO Y ENTRADA ─────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: kbCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: kbCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Teclado y Entrada"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Distribución (kb_layout):"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 170
                                }

                                TextField {
                                    id: kbField
                                    Layout.preferredWidth: 180
                                    height: 32
                                    placeholderText: "latam"
                                    text: root.kbLayout
                                    color: Colors.text
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        radius: 6
                                        color: Colors.surface
                                        border.color: Colors.surfaceHover
                                        border.width: 1
                                    }
                                    onEditingFinished: {
                                        let val = text.trim();
                                        if (!val) { setFeedback("La distribución no puede estar vacía", false); return; }
                                        root.kbLayout = val;
                                        root.runSet(["set", "kb_layout", val], "Distribución de teclado actualizada");
                                    }
                                }

                                Rectangle {
                                    implicitWidth: kbBtnText.implicitWidth + 20
                                    implicitHeight: 30
                                    radius: 6
                                    color: mouseKb.containsMouse ? Colors.accent : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                                    border.color: Colors.accent
                                    border.width: 1

                                    Text {
                                        id: kbBtnText
                                        anchors.centerIn: parent
                                        text: "Aplicar"
                                        color: Colors.accent
                                        font.pixelSize: 11
                                        font.weight: Typography.weightBold
                                    }

                                    MouseArea {
                                        id: mouseKb
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let val = kbField.text.trim();
                                            if (!val) { setFeedback("La distribución no puede estar vacía", false); return; }
                                            root.kbLayout = val;
                                            root.runSet(["set", "kb_layout", val], "Distribución de teclado actualizada");
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    // ── SECCIÓN 3: COMPORTAMIENTO (MISCELLANEOUS) ────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: miscCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: miscCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Comportamiento (Misceláneos)"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Cambiar foco al activar una ventana (focus_on_activate):"
                                    color: Colors.text
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Switch {
                                    checked: root.focusOnActivate
                                    onToggled: {
                                        root.focusOnActivate = checked;
                                        root.runSet(["set", "focus_on_activate", checked ? "true" : "false"], "Preferencia actualizada");
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Ocultar el logo de Hyprland (disable_hyprland_logo):"
                                    color: Colors.text
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Switch {
                                    checked: root.disableLogo
                                    onToggled: {
                                        root.disableLogo = checked;
                                        root.runSet(["set", "disable_hyprland_logo", checked ? "true" : "false"], "Preferencia actualizada");
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Ocultar la pantalla de inicio (disable_splash_rendering):"
                                    color: Colors.text
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Switch {
                                    checked: root.disableSplash
                                    onToggled: {
                                        root.disableSplash = checked;
                                        root.runSet(["set", "disable_splash_rendering", checked ? "true" : "false"], "Preferencia actualizada");
                                    }
                                }
                            }
                        }
                    }

                    // ── SECCIÓN 4: APLICACIONES AL INICIO (AUTOSTART) ────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: autoCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: autoCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Aplicaciones al Inicio (Autostart — exec-once)"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            // Fila de alta
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TextField {
                                    id: autostartField
                                    Layout.fillWidth: true
                                    height: 32
                                    placeholderText: "Comando a ejecutar al iniciar (ej. waybar)"
                                    color: Colors.text
                                    font.pixelSize: 12
                                    background: Rectangle {
                                        radius: 6
                                        color: Colors.surface
                                        border.color: Colors.surfaceHover
                                        border.width: 1
                                    }
                                    onEditingFinished: root.addAutostart()
                                }

                                Rectangle {
                                    implicitWidth: addAutoText.implicitWidth + 20
                                    implicitHeight: 30
                                    radius: 6
                                    color: mouseAddAuto.containsMouse ? Colors.accent : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                                    border.color: Colors.accent
                                    border.width: 1

                                    Text {
                                        id: addAutoText
                                        anchors.centerIn: parent
                                        text: "Agregar"
                                        color: Colors.accent
                                        font.pixelSize: 11
                                        font.weight: Typography.weightBold
                                    }

                                    MouseArea {
                                        id: mouseAddAuto
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addAutostart()
                                    }
                                }
                            }

                            Text {
                                visible: root.autostart.length === 0
                                text: "No hay comandos de inicio configurados"
                                color: Colors.textDim
                                font.pixelSize: 11
                            }

                            Repeater {
                                model: root.autostart

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: autoRowText.implicitHeight + 18
                                    radius: 6
                                    color: Colors.surface
                                    border.color: Colors.surfaceBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        Text {
                                            id: autoRowText
                                            text: modelData
                                            color: Colors.text
                                            font.pixelSize: 11
                                            font.family: Typography.familyMonospace
                                            Layout.fillWidth: true
                                            elide: Text.ElideMiddle
                                        }

                                        Rectangle {
                                            implicitWidth: delAutoText.implicitWidth + 16
                                            implicitHeight: 24
                                            radius: 5
                                            color: mouseDelAuto.containsMouse ? Colors.stateError : Colors.surfaceRaised
                                            border.color: mouseDelAuto.containsMouse ? Colors.stateError : Colors.surfaceBorder
                                            border.width: 1

                                            Text {
                                                id: delAutoText
                                                anchors.centerIn: parent
                                                text: "Eliminar"
                                                color: mouseDelAuto.containsMouse ? Colors.background : Colors.textMuted
                                                font.pixelSize: 10
                                                font.weight: Typography.weightMedium
                                            }

                                            MouseArea {
                                                id: mouseDelAuto
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.runSet(["autostart", "remove", modelData], "Comando eliminado del inicio", true)
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

    function addAutostart() {
        let val = autostartField.text.trim();
        if (!val) { setFeedback("Escribe un comando para agregar", false); return; }
        autostartField.text = "";
        root.runSet(["autostart", "add", val], "Comando agregado al inicio", true);
    }
}
