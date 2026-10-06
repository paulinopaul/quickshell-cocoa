import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property string selectedSsid: ""
    property string selectedSecurity: ""
    property string passwordInput: ""

    implicitWidth: 320
    implicitHeight: Math.min(420, contentCol.implicitHeight + 24)

    // Animación de entrada y salida
    transformOrigin: Item.TopRight
    scale: visible ? 1 : 0.9
    opacity: visible ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

    onVisibleChanged: {
        if (visible) {
            root.selectedSsid = "";
            root.passwordInput = "";
            NetworkService.scanNetworks();
        }
    }

    // Fondo del desplegable
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Colors.surface
        border.color: Colors.surfaceRaised
        border.width: 1
        clip: true
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Cabecera ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Icon {
                size: Metrics.iconSizeSmall
                name: "network-wireless"
                color: Colors.accent
            }

            Text {
                text: "Redes Wi-Fi"
                color: Colors.text
                font.pixelSize: 13
                font.weight: Typography.weightBold
                Layout.fillWidth: true
            }

            // Botón de refrescar / escanear
            IconButton {
                buttonSize: Metrics.iconSizeSmall + 4
                iconName: "system-reboot"
                iconColor: NetworkService.isScanning ? Colors.accent : Colors.textMuted
                onClicked: NetworkService.scanNetworks()

                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    running: NetworkService.isScanning
                    NumberAnimation { from: 0; to: 360; duration: 1000; easing.type: Easing.Linear }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

        // ── Mensaje de estado (Conectando / Error / Éxito) ─────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusText.implicitHeight + 12
            radius: 8
            visible: NetworkService.isConnecting || NetworkService.connectionError !== "" || NetworkService.connectionSuccess !== ""
            color: NetworkService.isConnecting ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                 : NetworkService.connectionError !== "" ? Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.15)
                 : Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.15)

            Text {
                id: statusText
                anchors.centerIn: parent
                text: NetworkService.isConnecting ? ("Conectando a " + root.selectedSsid + "...")
                    : NetworkService.connectionError !== "" ? NetworkService.connectionError
                    : NetworkService.connectionSuccess
                color: NetworkService.isConnecting ? Colors.accent
                     : NetworkService.connectionError !== "" ? Colors.stateError
                     : Colors.stateOk
                font.pixelSize: 11
                font.family: Typography.family
                elide: Text.ElideRight
            }
        }

        // ── Lista de Redes ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(260, networksListCol.implicitHeight)
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: networksListCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: networksListCol
                    width: parent.width
                    spacing: 4

                    // Estado: Buscando redes
                    Text {
                        visible: NetworkService.isScanning && NetworkService.networks.length === 0
                        text: "Buscando redes cercanas..."
                        color: Colors.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }

                    // Estado: Sin redes
                    Text {
                        visible: !NetworkService.isScanning && NetworkService.networks.length === 0
                        text: "No se encontraron redes Wi-Fi"
                        color: Colors.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }

                    // Elementos de la lista
                    Repeater {
                        model: NetworkService.networks

                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 4

                            // Tarjeta de la Red
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                color: modelData.inUse ? Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.12)
                                     : root.selectedSsid === modelData.ssid ? Colors.surfaceRaised
                                     : itemArea.containsMouse ? Qt.rgba(Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.2)
                                     : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Icon {
                                        size: Metrics.iconSizeSmall
                                        name: "network-wireless"
                                        color: modelData.inUse ? Colors.stateOk
                                             : modelData.signal > 60 ? Colors.text
                                             : modelData.signal > 30 ? Colors.textMuted
                                             : Colors.textDim
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.ssid || "Red Desconocida"
                                            color: modelData.inUse ? Colors.stateOk : Colors.text
                                            font.pixelSize: 12
                                            font.weight: modelData.inUse ? Typography.weightBold : Typography.weightNormal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.inUse ? "Conectado"
                                                 : modelData.security ? modelData.security
                                                 : "Red Abierta"
                                            color: modelData.inUse ? Colors.stateOk : Colors.textDim
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Icono de candado para redes con contraseña
                                    Icon {
                                        visible: modelData.security !== "" && !modelData.inUse
                                        size: 12
                                        name: "system-lock-screen"
                                        color: Colors.textDim
                                    }

                                    // Indicador de conectado
                                    Text {
                                        visible: modelData.inUse
                                        text: "✓"
                                        color: Colors.stateOk
                                        font.pixelSize: 12
                                        font.weight: Typography.weightBold
                                    }
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.inUse) return; // Ya está conectado
                                        if (root.selectedSsid === modelData.ssid) {
                                            root.selectedSsid = "";
                                        } else {
                                            root.selectedSsid = modelData.ssid;
                                            root.selectedSecurity = modelData.security || "";
                                            root.passwordInput = "";
                                            NetworkService.connectionError = "";
                                            NetworkService.connectionSuccess = "";
                                            // Si es red abierta, conectar directamente
                                            if (!modelData.security) {
                                                NetworkService.connectToNetwork(modelData.ssid, "");
                                            }
                                        }
                                    }
                                }
                            }

                            // Formulario de Contraseña Desplegable para la red seleccionada
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: pwdCol.implicitHeight + 16
                                radius: 8
                                color: Colors.background
                                border.color: Colors.surfaceRaised
                                border.width: 1
                                visible: root.selectedSsid === modelData.ssid && modelData.security !== ""

                                ColumnLayout {
                                    id: pwdCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Text {
                                        text: "Ingresa la contraseña para " + modelData.ssid + ":"
                                        color: Colors.textMuted
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: 6
                                        color: Colors.surface
                                        border.color: pwdInput.activeFocus ? Colors.accent : Colors.surfaceRaised
                                        border.width: 1

                                        TextInput {
                                            id: pwdInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: Colors.text
                                            echoMode: TextInput.Password
                                            font.pixelSize: 12
                                            font.family: Typography.family
                                            focus: root.selectedSsid === modelData.ssid
                                            text: root.passwordInput
                                            onTextChanged: {
                                                if (root.passwordInput !== text) root.passwordInput = text;
                                            }
                                            onAccepted: {
                                                NetworkService.connectToNetwork(modelData.ssid, root.passwordInput);
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignRight
                                        spacing: 8

                                        // Botón Cancelar
                                        Rectangle {
                                            width: 65; height: 24; radius: 6
                                            color: "transparent"
                                            border.color: Colors.surfaceRaised
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancelar"
                                                color: Colors.textMuted
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.selectedSsid = "";
                                                    root.passwordInput = "";
                                                }
                                            }
                                        }

                                        // Botón Conectar
                                        Rectangle {
                                            width: 70; height: 24; radius: 6
                                            color: Colors.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Conectar"
                                                color: Colors.background
                                                font.pixelSize: 11
                                                font.weight: Typography.weightBold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    NetworkService.connectToNetwork(modelData.ssid, root.passwordInput);
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
    }
}
