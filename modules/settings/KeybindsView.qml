import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property var allBinds: []
    property string searchQuery: ""
    property bool isLoading: false

    // ── Estado del formulario de edición ─────────────────────────────────────
    property string formDispatcher: "exec"
    property var pendingEdit: null   // {mods, key} del atajo original al editar
    property bool mutating: false
    property bool chainAddAfterRemove: false
    property var pendingAddArgs: []
    property string mutateBuffer: ""
    property string feedbackMessage: ""
    property bool feedbackOk: true
    // Collapsible "Agregar Atajo" editor; collapsed by default so the binds list keeps the height.
    property bool addFormExpanded: false

    readonly property string _script: Qt.resolvedUrl("../../scripts/keybinds_manager.py").toString().replace("file://", "")
    readonly property var _dispatchers: ["exec", "workspace", "movetoworkspace", "movefocus", "movewindow", "killactive", "togglefloating", "fullscreen", "global"]

    property string _buffer: ""

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

    function comboIndexOf(text) {
        for (let i = 0; i < root._dispatchers.length; i++)
            if (root._dispatchers[i] === text) return i;
        return -1;
    }

    function clearForm() {
        modsField.text = "";
        keyField.text = "";
        dispatcherCombo.currentIndex = 0;
        root.formDispatcher = "exec";
        argField.text = "";
        root.pendingEdit = null;
        addBtnLabel.text = "Agregar Atajo";
    }

    function startEdit(mods, key, dispatcher, arg) {
        modsField.text = mods;
        keyField.text = key;
        let idx = comboIndexOf(dispatcher);
        dispatcherCombo.currentIndex = idx >= 0 ? idx : 0;
        root.formDispatcher = idx >= 0 ? root._dispatchers[idx] : "exec";
        argField.text = arg;
        root.pendingEdit = { mods: mods, key: key };
        addBtnLabel.text = "Guardar Cambios";
        root.addFormExpanded = true;
        setFeedback("Editando " + (mods ? mods + " + " : "") + key, true);
    }

    function runManager(args) {
        root.mutating = true;
        root.mutateBuffer = "";
        mutateProc.command = ["python3", root._script].concat(args);
        mutateProc.running = false;
        mutateProc.running = true;
    }

    function addOrSave() {
        if (root.mutating) return;
        let mods = modsField.text.trim();
        let key = keyField.text.trim();
        let dispatcher = root.formDispatcher;
        let arg = argField.text.trim();
        if (!key) {
            setFeedback("Completa la tecla del atajo", false);
            return;
        }
        if (root.pendingEdit) {
            root.chainAddAfterRemove = true;
            root.pendingAddArgs = ["add", mods, key, dispatcher, arg];
            runManager(["remove", root.pendingEdit.mods, root.pendingEdit.key]);
        } else {
            runManager(["add", mods, key, dispatcher, arg]);
        }
    }

    function removeBind(mods, key) {
        if (root.mutating) return;
        root.chainAddAfterRemove = false;
        runManager(["remove", mods, key]);
    }

    property Process mutateProc: Process {
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data) root.mutateBuffer += data;
            }
        }
        onExited: (exitCode) => {
            // Editar = remove del atajo viejo + add del nuevo (dos llamadas encadenadas)
            if (root.chainAddAfterRemove) {
                root.chainAddAfterRemove = false;
                runManager(root.pendingAddArgs);
                return;
            }
            root.mutating = false;
            let parsed = null;
            try { parsed = JSON.parse(root.mutateBuffer.trim()); } catch (e) {}
            let ok = parsed && parsed.success;
            let msg;
            if (parsed && parsed.error) {
                msg = parsed.error;
            } else if (!ok) {
                msg = "Error al aplicar el atajo";
            } else if (parsed && parsed.removed > 0) {
                msg = "Atajo eliminado";
            } else {
                msg = "Atajo aplicado correctamente";
            }
            setFeedback(msg, !!ok);
            root.clearForm();
            root.refresh();
        }
    }

    property Process loadProc: Process {
        command: ["python3", root._script]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                try {
                    let parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        root.allBinds = parsed;
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
                    if (Array.isArray(parsed)) root.allBinds = parsed;
                } catch (e) {}
                root._buffer = "";
            }
        }
    }

    function refresh() {
        if (isLoading) return;
        isLoading = true;
        _buffer = "";
        loadProc.running = false;
        loadProc.running = true;
    }

    Component.onCompleted: root.refresh()
    onVisibleChanged: if (visible && root.allBinds.length === 0) root.refresh()

    readonly property var filteredBinds: {
        let q = root.searchQuery.trim().toLowerCase();
        if (!q) return allBinds;
        return allBinds.filter(b => {
            let comboMatch = b.combo && b.combo.toLowerCase().includes(q);
            let descMatch = b.description && b.description.toLowerCase().includes(q);
            let catMatch = b.category && b.category.toLowerCase().includes(q);
            let argMatch = b.arg && b.arg.toLowerCase().includes(q);
            return comboMatch || descMatch || catMatch || argMatch;
        });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header & Buscador ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Atajos de Teclado (Keybinds)"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Combinaciones de teclas activas configuradas en Hyprland"
                    color: Colors.textMuted
                    font.pixelSize: 13
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

            // Campo de Búsqueda
            TextField {
                Layout.preferredWidth: 200
                height: 32
                placeholderText: "Buscar atajo..."
                color: Colors.text
                font.pixelSize: 12
                background: Rectangle {
                    radius: 6
                    color: Colors.surfaceRaised
                    border.color: Colors.surfaceHover
                    border.width: 1
                }
                onTextChanged: root.searchQuery = text
            }
        }

        // ── Formulario "Agregar Atajo" ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: addFormCol.implicitHeight + 20
            radius: 8
            color: Colors.surfaceRaised
            border.color: root.pendingEdit ? Colors.accent : Colors.surfaceBorder
            border.width: 1

            ColumnLayout {
                id: addFormCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Agregar Atajo"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.pendingEdit !== null
                        text: "Editando atajo existente"
                        color: Colors.accent
                        font.pixelSize: 11
                        font.weight: Typography.weightMedium
                    }

                    // Chevron toggle: collapsed by default, expands the editor body.
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 24
                        radius: 6
                        color: toggleMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceDark
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.addFormExpanded ? "▾" : "▸"
                            color: Colors.textMuted
                            font.pixelSize: 12
                            font.weight: Typography.weightBold
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addFormExpanded = !root.addFormExpanded
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.addFormExpanded

                    ColumnLayout {
                        spacing: 3
                        Text {
                            text: "Módificador"
                            color: Colors.textMuted
                            font.pixelSize: 11
                        }
                        TextField {
                            id: modsField
                            Layout.preferredWidth: 120
                            height: 30
                            placeholderText: "SUPER SHIFT"
                            color: Colors.text
                            font.pixelSize: 12
                            background: Rectangle {
                                radius: 6
                                color: Colors.surface
                                border.color: Colors.surfaceHover
                                border.width: 1
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 3
                        Text {
                            text: "Tecla"
                            color: Colors.textMuted
                            font.pixelSize: 11
                        }
                        TextField {
                            id: keyField
                            Layout.preferredWidth: 80
                            height: 30
                            placeholderText: "A"
                            color: Colors.text
                            font.pixelSize: 12
                            background: Rectangle {
                                radius: 6
                                color: Colors.surface
                                border.color: Colors.surfaceHover
                                border.width: 1
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 3
                        Text {
                            text: "Disparador"
                            color: Colors.textMuted
                            font.pixelSize: 11
                        }
                        ComboBox {
                            id: dispatcherCombo
                            Layout.preferredWidth: 145
                            model: root._dispatchers
                            onActivated: currentIndex => root.formDispatcher = root._dispatchers[currentIndex]
                            Component.onCompleted: root.formDispatcher = root._dispatchers[currentIndex]
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "Argumento"
                            color: Colors.textMuted
                            font.pixelSize: 11
                        }
                        TextField {
                            id: argField
                            Layout.fillWidth: true
                            height: 30
                            placeholderText: "ghostty / 1 / l ..."
                            color: Colors.text
                            font.pixelSize: 12
                            background: Rectangle {
                                radius: 6
                                color: Colors.surface
                                border.color: Colors.surfaceHover
                                border.width: 1
                            }
                        }
                    }

                    // Botón Agregar / Guardar
                    Rectangle {
                        id: addBtn
                        implicitWidth: addBtnLabel.implicitWidth + 24
                        implicitHeight: 30
                        radius: 6
                        color: mouseAdd.containsMouse ? Colors.accent : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                        border.color: Colors.accent
                        border.width: 1

                        Text {
                            id: addBtnLabel
                            anchors.centerIn: parent
                            text: "Agregar Atajo"
                            color: Colors.accent
                            font.pixelSize: 11
                            font.weight: Typography.weightBold
                        }

                        MouseArea {
                            id: mouseAdd
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addOrSave()
                        }
                    }

                    // Cancelar edición
                    Rectangle {
                        visible: root.pendingEdit !== null
                        implicitWidth: cancelLabel.implicitWidth + 20
                        implicitHeight: 30
                        radius: 6
                        color: Colors.surfaceDark
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Colors.textMuted
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearForm()
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: bindsContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: bindsContentCol
                    width: parent.width
                    spacing: 8

                    Text {
                        visible: root.filteredBinds.length === 0 && !root.isLoading
                        text: "No se encontraron atajos que coincidan con la búsqueda"
                        color: Colors.textDim
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 30
                    }

                    Repeater {
                        model: root.filteredBinds

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 8
                            color: Colors.surface
                            border.color: Colors.surfaceRaised
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                // Keybadge
                                Rectangle {
                                    implicitWidth: comboText.implicitWidth + 18
                                    implicitHeight: 28
                                    radius: 6
                                    color: Colors.surfaceRaised
                                    border.color: Colors.accent
                                    border.width: 1

                                    Text {
                                        id: comboText
                                        anchors.centerIn: parent
                                        text: modelData.combo || ""
                                        color: Colors.accent
                                        font.pixelSize: 11
                                        font.family: Typography.familyMonospace
                                        font.weight: Typography.weightBold
                                    }
                                }

                                // Descripción
                                Text {
                                    text: modelData.description || ""
                                    color: Colors.text
                                    font.pixelSize: 12
                                    font.weight: Typography.weightMedium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Categoría
                                Rectangle {
                                    implicitWidth: catText.implicitWidth + 12
                                    implicitHeight: 22
                                    radius: 4
                                    color: Colors.background

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: modelData.category || "General"
                                        color: Colors.textDim
                                        font.pixelSize: 10
                                    }
                                }

                                // Editar (carga el atajo en el formulario)
                                Rectangle {
                                    implicitWidth: editText.implicitWidth + 16
                                    implicitHeight: 26
                                    radius: 5
                                    color: mouseEdit.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised
                                    border.color: Colors.surfaceBorder
                                    border.width: 1

                                    Text {
                                        id: editText
                                        anchors.centerIn: parent
                                        text: "Editar"
                                        color: Colors.textMuted
                                        font.pixelSize: 10
                                        font.weight: Typography.weightMedium
                                    }

                                    MouseArea {
                                        id: mouseEdit
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.startEdit(modelData.modifiers || "", modelData.key || "", modelData.dispatcher || "", modelData.arg || "")
                                    }
                                }

                                // Eliminar
                                Rectangle {
                                    implicitWidth: delText.implicitWidth + 16
                                    implicitHeight: 26
                                    radius: 5
                                    color: mouseDel.containsMouse ? Colors.stateError : Colors.surfaceRaised
                                    border.color: mouseDel.containsMouse ? Colors.stateError : Colors.surfaceBorder
                                    border.width: 1

                                    Text {
                                        id: delText
                                        anchors.centerIn: parent
                                        text: "Eliminar"
                                        color: mouseDel.containsMouse ? Colors.background : Colors.textMuted
                                        font.pixelSize: 10
                                        font.weight: Typography.weightMedium
                                    }

                                    MouseArea {
                                        id: mouseDel
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeBind(modelData.modifiers || "", modelData.key || "")
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
