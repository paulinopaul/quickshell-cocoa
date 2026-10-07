import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../../components"

// PanelsSettingsView — Configuración granular de cada elemento visual de Cocoa:
// Panel Izquierdo, Isla Dinámica (Centro) y Panel Derecho, todos con opciones
// idénticas de estilo visual (opacidad, borde, visibilidad) y selector de qué mostrar y qué no.

Item {
    id: root

    property string selectedPanel: "center" // "left" | "center" | "right"

    readonly property var currentConfig: {
        if (selectedPanel === "left") return UiConfigService.leftPanel;
        if (selectedPanel === "center") return UiConfigService.centerCapsule;
        return UiConfigService.rightPanel;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Encabezado ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: "Elementos de Cocoa y Barra Superior"
                color: Colors.text
                font.pixelSize: 18
                font.weight: Typography.weightBold
            }

            Text {
                text: "Personaliza la apariencia de cada isla y selecciona exactamente qué widgets mostrar"
                color: Colors.textMuted
                font.pixelSize: 12
            }
        }

        // ── Selector de Panel / Elemento ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: leftBtnText.implicitWidth + 24
                implicitHeight: 32
                radius: 16
                color: root.selectedPanel === "left" ? Colors.accent : Colors.surfaceRaised
                border.color: root.selectedPanel === "left" ? Colors.accent : Colors.surfaceBorder
                border.width: 1

                Text {
                    id: leftBtnText
                    anchors.centerIn: parent
                    text: "Panel Izquierdo"
                    color: root.selectedPanel === "left" ? Colors.background : Colors.textMuted
                    font.pixelSize: 11
                    font.weight: root.selectedPanel === "left" ? Typography.weightBold : Typography.weightNormal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedPanel = "left"
                }
            }

            Rectangle {
                implicitWidth: centerBtnText.implicitWidth + 24
                implicitHeight: 32
                radius: 16
                color: root.selectedPanel === "center" ? Colors.accent : Colors.surfaceRaised
                border.color: root.selectedPanel === "center" ? Colors.accent : Colors.surfaceBorder
                border.width: 1

                Text {
                    id: centerBtnText
                    anchors.centerIn: parent
                    text: "Isla Dinámica (Centro)"
                    color: root.selectedPanel === "center" ? Colors.background : Colors.textMuted
                    font.pixelSize: 11
                    font.weight: root.selectedPanel === "center" ? Typography.weightBold : Typography.weightNormal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedPanel = "center"
                }
            }

            Rectangle {
                implicitWidth: rightBtnText.implicitWidth + 24
                implicitHeight: 32
                radius: 16
                color: root.selectedPanel === "right" ? Colors.accent : Colors.surfaceRaised
                border.color: root.selectedPanel === "right" ? Colors.accent : Colors.surfaceBorder
                border.width: 1

                Text {
                    id: rightBtnText
                    anchors.centerIn: parent
                    text: "Panel Derecho"
                    color: root.selectedPanel === "right" ? Colors.background : Colors.textMuted
                    font.pixelSize: 11
                    font.weight: root.selectedPanel === "right" ? Typography.weightBold : Typography.weightNormal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedPanel = "right"
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                anchors.fill: parent
                contentHeight: panelDetailsCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: panelDetailsCol
                    width: parent.width - 8
                    spacing: 12

                    // ── SECCIÓN 1: ESTILO VISUAL DEL ELEMENTO (IDÉNTICO PARA TODOS)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: visualCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: visualCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Apariencia Visual del Elemento"
                                    color: Colors.text
                                    font.pixelSize: 13
                                    font.weight: Typography.weightBold
                                    Layout.fillWidth: true
                                }

                                // Switch de Visibilidad General
                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: (root.currentConfig.visible !== false) ? "Visible" : "Oculto"
                                        color: (root.currentConfig.visible !== false) ? Colors.accent : Colors.textDim
                                        font.pixelSize: 11
                                        font.weight: Typography.weightMedium
                                    }

                                    Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 22
                                        radius: 11
                                        color: (root.currentConfig.visible !== false) ? Colors.accent : Colors.surfaceDark
                                        border.color: Colors.surfaceBorder
                                        border.width: 1

                                        Rectangle {
                                            width: 18; height: 18; radius: 9
                                            x: (root.currentConfig.visible !== false) ? parent.width - 20 : 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: (root.currentConfig.visible !== false) ? Colors.background : Colors.textMuted
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: UiConfigService.togglePanelProperty(root.selectedPanel, "visible")
                                        }
                                    }
                                }
                            }

                            // Opacidad de fondo
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Opacidad de Fondo:"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0.20
                                    to: 1.0
                                    stepSize: 0.05
                                    value: root.currentConfig.bgOpacity !== undefined ? root.currentConfig.bgOpacity : 0.95
                                    onMoved: {
                                        let val = Math.round(value * 100) / 100;
                                        UiConfigService.setPanelProperty(root.selectedPanel, "bgOpacity", val);
                                    }
                                }

                                Text {
                                    text: Math.round((root.currentConfig.bgOpacity !== undefined ? root.currentConfig.bgOpacity : 0.95) * 100) + "%"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Grosor del Borde
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Grosor de Contorno:"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 4
                                    stepSize: 1
                                    value: root.currentConfig.borderWidth !== undefined ? root.currentConfig.borderWidth : 1
                                    onMoved: {
                                        let val = Math.round(value);
                                        UiConfigService.setPanelProperty(root.selectedPanel, "borderWidth", val);
                                    }
                                }

                                Text {
                                    text: (root.currentConfig.borderWidth !== undefined ? root.currentConfig.borderWidth : 1) + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }
                        }
                    }

                    // ── SECCIÓN 2: SELECTOR DE QUÉ MOSTRAR Y QUÉ NO ───────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: widgetsCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: widgetsCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Contenido y Widgets a Mostrar"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            // ── Panel Izquierdo ──
                            ColumnLayout {
                                visible: root.selectedPanel === "left"
                                Layout.fillWidth: true
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Indicadores de Espacios de Trabajo (Workspaces)"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showWorkspaces !== false
                                        onToggled: UiConfigService.togglePanelProperty("left", "showWorkspaces")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Título y Nombre de la Aplicación Activa"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showActiveWindow !== false
                                        onToggled: UiConfigService.togglePanelProperty("left", "showActiveWindow")
                                    }
                                }
                            }

                            // ── Isla Dinámica (Centro) ──
                            ColumnLayout {
                                visible: root.selectedPanel === "center"
                                Layout.fillWidth: true
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Modo Multimedia y Portadas de Álbum (Spotify)"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showMedia !== false
                                        onToggled: UiConfigService.togglePanelProperty("center", "showMedia")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Métricas de CPU y Carga"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showCpu !== false
                                        onToggled: UiConfigService.togglePanelProperty("center", "showCpu")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Métricas de Memoria RAM"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showRam !== false
                                        onToggled: UiConfigService.togglePanelProperty("center", "showRam")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Métricas de GPU (Intel / NVIDIA)"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showGpu !== false
                                        onToggled: UiConfigService.togglePanelProperty("center", "showGpu")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Línea de Resplandor Neon Inferior"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showNeon !== false
                                        onToggled: UiConfigService.togglePanelProperty("center", "showNeon")
                                    }
                                }
                            }

                            // ── Panel Derecho ──
                            ColumnLayout {
                                visible: root.selectedPanel === "right"
                                Layout.fillWidth: true
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Estado y Nivel de Batería"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showBattery !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showBattery")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Widget de Red (Wi-Fi / Ethernet)"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showNetwork !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showNetwork")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Estado de Micrófono y Mute Rápido"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showMic !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showMic")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Control y Nivel de Volumen de Audio"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showVolume !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showVolume")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Brillo"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showBrightness !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showBrightness")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Botón de Configuración"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showSettings !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showSettings")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Botón de Apagado"; color: Colors.text; font.pixelSize: 12; Layout.fillWidth: true }
                                    Switch {
                                        checked: root.currentConfig.showPower !== false
                                        onToggled: UiConfigService.togglePanelProperty("right", "showPower")
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
