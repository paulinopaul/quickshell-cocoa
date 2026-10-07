import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../../components"

// VisualSettingsView — Personalización visual del sistema:
// Bordes de ventanas, curvatura/redondeo, sombras y estilo de la terminal (Ghostty).

Item {
    id: root

    property int borderSize: UiConfigService.hyprland.borderSize !== undefined ? UiConfigService.hyprland.borderSize : 2
    property int rounding: UiConfigService.hyprland.rounding !== undefined ? UiConfigService.hyprland.rounding : 14
    property bool shadowEnabled: UiConfigService.hyprland.shadowEnabled !== undefined ? UiConfigService.hyprland.shadowEnabled : true
    property int shadowRange: UiConfigService.hyprland.shadowRange !== undefined ? UiConfigService.hyprland.shadowRange : 15
    property int shadowPower: UiConfigService.hyprland.shadowPower !== undefined ? UiConfigService.hyprland.shadowPower : 6

    property string ghosttyTheme: UiConfigService.ghostty.theme || "Onenord"
    property real ghosttyOpacity: UiConfigService.ghostty.backgroundOpacity !== undefined ? UiConfigService.ghostty.backgroundOpacity : 0.95
    property int ghosttyBlur: UiConfigService.ghostty.backgroundBlur !== undefined ? UiConfigService.ghostty.backgroundBlur : 24

    property string feedbackMessage: ""

    Timer {
        id: feedbackTimer
        interval: 3000
        onTriggered: root.feedbackMessage = ""
    }

    function applyHyprland() {
        UiConfigService.saveHyprland(root.borderSize, root.rounding, root.shadowEnabled, root.shadowRange, root.shadowPower);
        root.feedbackMessage = "Bordes y sombras del sistema actualizados.";
        feedbackTimer.restart();
    }

    function applyGhostty() {
        UiConfigService.saveGhostty(root.ghosttyTheme, root.ghosttyOpacity, root.ghosttyBlur);
        root.feedbackMessage = "Configuración visual de Ghostty aplicada.";
        feedbackTimer.restart();
    }

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
                    text: "Apariencia Visual y Ventanas"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: "Configuración de bordes, redondeo, sombras de Hyprland y terminal Ghostty"
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
                color: Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.2)
                border.color: Colors.stateOk
                border.width: 1

                Text {
                    id: fbText
                    anchors.centerIn: parent
                    text: root.feedbackMessage
                    color: Colors.stateOk
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
                contentHeight: visualContentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: visualContentCol
                    width: parent.width - 8
                    spacing: 12

                    // ── SECCIÓN 1: BORDES Y CONTORNO DE VENTANAS ───────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: bordersCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: bordersCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Bordes y Esquinas de Ventana (Hyprland)"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            // Grosor del borde
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Grosor del Borde:"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 6
                                    stepSize: 1
                                    value: root.borderSize
                                    onMoved: {
                                        root.borderSize = Math.round(value);
                                        root.applyHyprland();
                                    }
                                }

                                Text {
                                    text: root.borderSize + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Curvatura / Redondeo
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Redondeo de Esquinas:"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 28
                                    stepSize: 1
                                    value: root.rounding
                                    onMoved: {
                                        root.rounding = Math.round(value);
                                        root.applyHyprland();
                                    }
                                }

                                Text {
                                    text: root.rounding + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }
                        }
                    }

                    // ── SECCIÓN 2: SOMBRAS Y PROFUNDIDAD ───────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: shadowCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: shadowCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Sombras de Ventanas"
                                    color: Colors.text
                                    font.pixelSize: 13
                                    font.weight: Typography.weightBold
                                    Layout.fillWidth: true
                                }

                                // Toggle Switch
                                Rectangle {
                                    implicitWidth: 44
                                    implicitHeight: 22
                                    radius: 11
                                    color: root.shadowEnabled ? Colors.accent : Colors.surfaceDark
                                    border.color: Colors.surfaceBorder
                                    border.width: 1

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        x: root.shadowEnabled ? parent.width - 20 : 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.shadowEnabled ? Colors.background : Colors.textMuted

                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.shadowEnabled = !root.shadowEnabled;
                                            root.applyHyprland();
                                        }
                                    }
                                }
                            }

                            // Rango de sombra
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                opacity: root.shadowEnabled ? 1.0 : 0.4
                                enabled: root.shadowEnabled

                                Text {
                                    text: "Radio de Difuminado:"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 5
                                    to: 40
                                    stepSize: 1
                                    value: root.shadowRange
                                    onMoved: {
                                        root.shadowRange = Math.round(value);
                                        root.applyHyprland();
                                    }
                                }

                                Text {
                                    text: root.shadowRange + " px"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Potencia de render
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                opacity: root.shadowEnabled ? 1.0 : 0.4
                                enabled: root.shadowEnabled

                                Text {
                                    text: "Intensidad (Potencia):"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 1
                                    to: 10
                                    stepSize: 1
                                    value: root.shadowPower
                                    onMoved: {
                                        root.shadowPower = Math.round(value);
                                        root.applyHyprland();
                                    }
                                }

                                Text {
                                    text: root.shadowPower.toString()
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }
                        }
                    }

                    // ── SECCIÓN 3: TERMINAL GHOSTTY ───────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: termCol.implicitHeight + 20
                        radius: 12
                        color: Colors.surfaceRaised
                        border.color: Colors.surfaceBorder
                        border.width: 1

                        ColumnLayout {
                            id: termCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "Personalización de Terminal (Ghostty)"
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Typography.weightBold
                            }

                            // Selector de Temas
                            Text {
                                text: "Tema Visual de la Terminal:"
                                color: Colors.textMuted
                                font.pixelSize: 12
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: UiConfigService.ghosttyThemes

                                    Rectangle {
                                        implicitWidth: themeText.implicitWidth + 14
                                        implicitHeight: 24
                                        radius: 12
                                        color: root.ghosttyTheme === modelData ? Colors.accent : Colors.surfaceDark
                                        border.color: root.ghosttyTheme === modelData ? Colors.accent : Colors.surfaceBorder
                                        border.width: 1

                                        Text {
                                            id: themeText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.ghosttyTheme === modelData ? Colors.background : Colors.textMuted
                                            font.pixelSize: 10
                                            font.weight: root.ghosttyTheme === modelData ? Typography.weightBold : Typography.weightNormal
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.ghosttyTheme = modelData;
                                                root.applyGhostty();
                                            }
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
                                    from: 0.50
                                    to: 1.0
                                    stepSize: 0.05
                                    value: root.ghosttyOpacity
                                    onMoved: {
                                        root.ghosttyOpacity = Math.round(value * 100) / 100;
                                        root.applyGhostty();
                                    }
                                }

                                Text {
                                    text: Math.round(root.ghosttyOpacity * 100) + "%"
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }

                            // Desenfoque / Blur de fondo
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Text {
                                    text: "Desenfoque (Blur):"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 150
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 64
                                    stepSize: 2
                                    value: root.ghosttyBlur
                                    onMoved: {
                                        root.ghosttyBlur = Math.round(value);
                                        root.applyGhostty();
                                    }
                                }

                                Text {
                                    text: root.ghosttyBlur.toString()
                                    color: Colors.accent
                                    font.pixelSize: 12
                                    font.weight: Typography.weightBold
                                    Layout.preferredWidth: 40
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
