import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../../components"

// SettingsWindow — Centro de control y configuración completo para Cocoa Shell.
//
// Protocolo & Arquitectura:
// - WlrLayershell.layer: WlrLayer.Overlay (por encima de todas las ventanas).
// - Centrado automático en Wayland al no declarar anclajes laterales.
// - Ciclo de vida desacoplado: visible: surfaceActive, enterAnim (OutBack) y exitAnim (InQuad).
// - GlobalShortcut: "settings_dialog" (Super + I).
// - Pestañas: Tema, Apariencia Visual, Elementos de Cocoa, Red, Audio, Pantalla, Aplicaciones Predeterminadas, Atajos de Teclado, Hyprland y Sistema.
// - Cierre: Botón X, tecla Escape o clic en backdrop.

PanelWindow {
    id: root

    property bool isOpen: false
    property bool surfaceActive: false
    property string activeTab: "theme" // "theme" | "visual" | "panels" | "network" | "audio" | "display" | "apps" | "keybinds" | "hyprland"

    WlrLayershell.namespace: "cocoa-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Sin anclajes = centrado absoluto en pantalla
    implicitWidth: 1000
    implicitHeight: 700
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: surfaceActive

    GlobalShortcut {
        name: "settings_dialog"
        onPressed: root.toggle()
    }

    function open() {
        exitAnim.stop();
        surfaceActive = true;
        isOpen = true;
        enterAnim.restart();
        mainCard.forceActiveFocus();
    }

    function close() {
        if (!isOpen && !surfaceActive) return;
        isOpen = false;
        exitAnim.restart();
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    // ── Animaciones cinemáticas ───────────────────────────────────────────────
    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: mainCard; property: "scale"; from: 0.93; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        NumberAnimation { target: mainCard; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: mainCard; property: "scale"; from: 1.0; to: 0.95; duration: 160; easing.type: Easing.InQuad }
        NumberAnimation { target: mainCard; property: "opacity"; from: 1.0; to: 0.0; duration: 160; easing.type: Easing.InQuad }
        onFinished: {
            root.surfaceActive = false;
        }
    }

    // ── Tarjeta Principal del Diálogo ─────────────────────────────────────────
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: 20
        color: Colors.surface
        border.color: Colors.surfaceBorder
        border.width: 1

        focus: true
        Keys.onEscapePressed: root.close()

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Barra Lateral de Navegación ───────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                topLeftRadius: 20
                bottomLeftRadius: 20
                topRightRadius: 0
                bottomRightRadius: 0
                color: Colors.surfaceDark

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Colors.surfaceBorder
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Cabecera Cocoa
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 28; height: 28; radius: 7
                            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                            border.color: Colors.accent
                            border.width: 1

                            Icon {
                                anchors.centerIn: parent
                                size: 16
                                name: "preferences-system"
                                color: Colors.accent
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "Cocoa"
                                color: Colors.text
                                font.pixelSize: 14
                                font.weight: Typography.weightBold
                            }
                            Text {
                                text: "Configuración"
                                color: Colors.textDim
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // Botones de Categorías
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "theme"
                            label: "Tema y Color"
                            iconName: "preferences-desktop-theme"
                            isActive: root.activeTab === "theme"
                            onClicked: root.activeTab = "theme"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "visual"
                            label: "Apariencia Visual"
                            iconName: "applications-graphics"
                            isActive: root.activeTab === "visual"
                            onClicked: root.activeTab = "visual"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "panels"
                            label: "Elementos de Cocoa"
                            iconName: "preferences-system"
                            isActive: root.activeTab === "panels"
                            onClicked: root.activeTab = "panels"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "network"
                            label: "Red e Internet"
                            iconName: "network-wireless"
                            isActive: root.activeTab === "network"
                            onClicked: root.activeTab = "network"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "audio"
                            label: "Sonido y Audio"
                            iconName: "audio-volume-high"
                            isActive: root.activeTab === "audio"
                            onClicked: root.activeTab = "audio"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "display"
                            label: "Pantalla y Monitor"
                            iconName: "display-brightness-symbolic"
                            isActive: root.activeTab === "display"
                            onClicked: root.activeTab = "display"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "apps"
                            label: "Programas por Defecto"
                            iconName: "application-x-executable"
                            isActive: root.activeTab === "apps"
                            onClicked: root.activeTab = "apps"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "keybinds"
                            label: "Atajos de Teclado"
                            iconName: "system-search"
                            isActive: root.activeTab === "keybinds"
                            onClicked: root.activeTab = "keybinds"
                        }

                        SettingsTabButton {
                            Layout.fillWidth: true
                            tabId: "hyprland"
                            label: "Hyprland y Sistema"
                            iconName: "input-keyboard"
                            isActive: root.activeTab === "hyprland"
                            onClicked: root.activeTab = "hyprland"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Atajo de cierre / información al pie
                    Text {
                        text: "Super+I • Esc para cerrar"
                        color: Colors.textDim
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // ── Contenedor de Contenido Derecho ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topRightRadius: 20
                bottomRightRadius: 20
                topLeftRadius: 0
                bottomLeftRadius: 0
                color: Colors.surface

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Barra Superior con Botón de Cierre
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Layout.leftMargin: 16
                        Layout.rightMargin: 14

                        Item { Layout.fillWidth: true }

                        IconButton {
                            buttonSize: 26
                            iconName: "close"
                            iconColor: Colors.textMuted
                            onClicked: root.close()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // Vistas Apiladas
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ThemeSettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "theme"
                        }

                        VisualSettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "visual"
                        }

                        PanelsSettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "panels"
                        }

                        NetworkSettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "network"
                        }

                        AudioSettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "audio"
                        }

                        DisplaySettingsView {
                            anchors.fill: parent
                            visible: root.activeTab === "display"
                        }

                        DefaultAppsView {
                            anchors.fill: parent
                            visible: root.activeTab === "apps"
                        }

                        KeybindsView {
                            anchors.fill: parent
                            visible: root.activeTab === "keybinds"
                        }

                        HyprlandConfigView {
                            anchors.fill: parent
                            visible: root.activeTab === "hyprland"
                        }
                    }
                }
            }
        }
    }
}
