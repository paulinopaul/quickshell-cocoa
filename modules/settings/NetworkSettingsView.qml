import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property string selectedSsid: ""
    property string selectedSecurity: ""
    property string passwordInput: ""

    Component.onCompleted: {
        NetworkService.scanNetworks();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ── Header & Estado Principal ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Red e Internet"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: NetworkService.isConnected
                          ? (NetworkService.isWifi ? ("Conectado a Wi-Fi (" + NetworkService.ssid + ")") : "Conexión Cableada (Ethernet)")
                          : "Sin conexión a internet"
                    color: NetworkService.isConnected ? Colors.stateOk : Colors.textMuted
                    font.pixelSize: 13
                }
            }

            // Botón de Escanear Redes
            Rectangle {
                implicitWidth: scanRow.implicitWidth + 20
                implicitHeight: 34
                radius: 8
                color: scanMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised
                border.color: Colors.surfaceRaised
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: scanRow
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        size: 14
                        name: "system-reboot"
                        color: NetworkService.isScanning ? Colors.accent : Colors.text

                        SequentialAnimation on rotation {
                            loops: Animation.Infinite
                            running: NetworkService.isScanning
                            NumberAnimation { from: 0; to: 360; duration: 1000; easing.type: Easing.Linear }
                        }
                    }

                    Text {
                        text: NetworkService.isScanning ? "Buscando..." : "Escanear"
                        color: Colors.text
                        font.pixelSize: 12
                        font.weight: Typography.weightMedium
                    }
                }

                MouseArea {
                    id: scanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.scanNetworks()
                }
            }
        }

        // ── Tarjeta de Estado Activo & Desconectar ──────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: 12
            color: Colors.surface
            border.color: Colors.surfaceRaised
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Icon {
                    size: 20
                    name: NetworkService.isConnected ? (NetworkService.isWifi ? "network-wireless" : "network-wired") : "network-offline"
                    color: NetworkService.isConnected ? Colors.stateOk : Colors.textDim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: NetworkService.isConnected ? (NetworkService.isWifi ? NetworkService.ssid : "Ethernet LAN") : "Desconectado"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightMedium
                    }

                    Text {
                        text: NetworkService.isConnected ? "Activo y en línea" : "Haga clic en una red para conectarse"
                        color: Colors.textDim
                        font.pixelSize: 11
                    }
                }

                // Botón Desconectar (visible si está conectado a Wi-Fi)
                Rectangle {
                    visible: NetworkService.isConnected && NetworkService.isWifi
                    implicitWidth: 92
                    implicitHeight: 28
                    radius: 6
                    color: disconMouse.containsMouse ? Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.25)
                                                     : Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.12)
                    border.color: Colors.stateError
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: NetworkService.isDisconnecting ? "Cortando..." : "Desconectar"
                        color: Colors.stateError
                        font.pixelSize: 11
                        font.weight: Typography.weightMedium
                    }

                    MouseArea {
                        id: disconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.disconnectFromNetwork(NetworkService.ssid)
                    }
                }
            }
        }

        // ── Banner de Estado (Conectando / Error / Éxito) ──────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bannerText.implicitHeight + 14
            radius: 8
            visible: NetworkService.isConnecting || NetworkService.isDisconnecting || NetworkService.connectionError !== "" || NetworkService.connectionSuccess !== ""
            color: (NetworkService.isConnecting || NetworkService.isDisconnecting) ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                 : NetworkService.connectionError !== "" ? Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.15)
                 : Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.15)
            border.color: (NetworkService.isConnecting || NetworkService.isDisconnecting) ? Colors.accent
                        : NetworkService.connectionError !== "" ? Colors.stateError
                        : Colors.stateOk
            border.width: 1

            Text {
                id: bannerText
                anchors.centerIn: parent
                text: NetworkService.isConnecting ? ("Conectando a " + root.selectedSsid + "...")
                    : NetworkService.isDisconnecting ? "Desconectando conexión de red..."
                    : NetworkService.connectionError !== "" ? NetworkService.connectionError
                    : NetworkService.connectionSuccess
                color: (NetworkService.isConnecting || NetworkService.isDisconnecting) ? Colors.accent
                     : NetworkService.connectionError !== "" ? Colors.stateError
                     : Colors.stateOk
                font.pixelSize: 12
                font.weight: Typography.weightMedium
            }
        }

        // ── Subtítulo de Lista de Redes ───────────────────────────────────────
        Text {
            text: "Redes Wi-Fi Disponibles"
            color: Colors.textMuted
            font.pixelSize: 12
            font.weight: Typography.weightBold
            Layout.topMargin: 4
        }

        // ── Lista de Redes Wi-Fi Disponibles ──────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: flickable
                anchors.fill: parent
                contentHeight: netListCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: netListCol
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: NetworkService.isScanning && NetworkService.networks.length === 0
                        text: "Escaneando puntos de acceso cercanos..."
                        color: Colors.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 30
                    }

                    Text {
                        visible: !NetworkService.isScanning && NetworkService.networks.length === 0
                        text: "No se encontraron redes Wi-Fi disponibles"
                        color: Colors.textDim
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 30
                    }

                    Repeater {
                        model: NetworkService.networks

                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 4

                            // Fila de la Red
                            Rectangle {
                                Layout.fillWidth: true
                                height: 42
                                radius: 8
                                color: modelData.inUse ? Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.12)
                                     : root.selectedSsid === modelData.ssid ? Colors.surfaceRaised
                                     : itemArea.containsMouse ? Qt.rgba(Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.15)
                                     : Colors.surface

                                border.color: root.selectedSsid === modelData.ssid ? Colors.accent : Colors.surfaceRaised
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Icon {
                                        size: 16
                                        name: "network-wireless"
                                        color: modelData.inUse ? Colors.stateOk
                                             : modelData.signal > 60 ? Colors.text
                                             : modelData.signal > 30 ? Colors.textMuted
                                             : Colors.textDim
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.ssid || "Red Oculta"
                                            color: modelData.inUse ? Colors.stateOk : Colors.text
                                            font.pixelSize: 12
                                            font.weight: modelData.inUse ? Typography.weightBold : Typography.weightNormal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.inUse ? "Conectada actualmente"
                                                 : (modelData.security ? (modelData.security + " • " + modelData.signal + "%") : ("Red Abierta • " + modelData.signal + "%"))
                                            color: modelData.inUse ? Colors.stateOk : Colors.textDim
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Icono de Candado
                                    Icon {
                                        visible: modelData.security !== "" && !modelData.inUse
                                        size: 13
                                        name: "lock"
                                        color: Colors.textDim
                                    }

                                    // Indicador de Conectado
                                    Text {
                                        visible: modelData.inUse
                                        text: "✓ Conectado"
                                        color: Colors.stateOk
                                        font.pixelSize: 11
                                        font.weight: Typography.weightBold
                                    }
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.inUse) return;
                                        if (root.selectedSsid === modelData.ssid) {
                                            root.selectedSsid = "";
                                        } else {
                                            root.selectedSsid = modelData.ssid;
                                            root.selectedSecurity = modelData.security || "";
                                            root.passwordInput = "";
                                            NetworkService.connectionError = "";
                                            NetworkService.connectionSuccess = "";
                                            if (!modelData.security) {
                                                NetworkService.connectToNetwork(modelData.ssid, "");
                                            }
                                        }
                                    }
                                }
                            }

                            // Formulario de Contraseña expandible
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: pwdLayout.implicitHeight + 16
                                radius: 8
                                color: Colors.surface
                                border.color: Colors.accent
                                border.width: 1
                                visible: root.selectedSsid === modelData.ssid && modelData.security !== ""

                                ColumnLayout {
                                    id: pwdLayout
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Text {
                                        text: "Introduce la contraseña para " + modelData.ssid + ":"
                                        color: Colors.text
                                        font.pixelSize: 11
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        TextField {
                                            id: pwdField
                                            Layout.fillWidth: true
                                            height: 32
                                            echoMode: TextInput.Password
                                            placeholderText: "Contraseña de red..."
                                            color: Colors.text
                                            font.pixelSize: 12
                                            focus: root.selectedSsid === modelData.ssid

                                            background: Rectangle {
                                                radius: 6
                                                color: Colors.background
                                                border.color: pwdField.activeFocus ? Colors.accent : Colors.surfaceRaised
                                                border.width: 1
                                            }

                                            onTextChanged: root.passwordInput = text
                                            onAccepted: {
                                                if (text.trim() !== "") {
                                                    NetworkService.connectToNetwork(modelData.ssid, text.trim());
                                                }
                                            }
                                        }

                                        // Botón Conectar
                                        Rectangle {
                                            implicitWidth: 80
                                            implicitHeight: 32
                                            radius: 6
                                            color: connectMouse.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Conectar"
                                                color: Colors.background
                                                font.pixelSize: 11
                                                font.weight: Typography.weightBold
                                            }

                                            MouseArea {
                                                id: connectMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.passwordInput.trim() !== "") {
                                                        NetworkService.connectToNetwork(modelData.ssid, root.passwordInput.trim());
                                                    }
                                                }
                                            }
                                        }

                                        // Botón Cancelar
                                        Rectangle {
                                            implicitWidth: 70
                                            implicitHeight: 32
                                            radius: 6
                                            color: cancelMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancelar"
                                                color: Colors.textMuted
                                                font.pixelSize: 11
                                            }

                                            MouseArea {
                                                id: cancelMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedSsid = ""
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
