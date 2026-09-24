import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services"
import "../../components"

// BarWindow: Ventana de capa superior que contiene los 3 paneles.
//
// Diseño en la pantalla:
//
//  ┌─────────────────────────────────────────────────────┐  ← borde de pantalla
//  │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ CENTER CAPSULE ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
//  │LEFT╲                                           ╱RIGHT│
//  │[ws] ╲══════════════════════════════════════╱ [batt]  │
//  └─────────────────────────────────────────────────────┘
//
// Los tres paneles son Items independientes posicionados absolutamente.
// El centro ocupa TODA la anchura de la pantalla en la parte superior,
// luego se estrecha; los laterales comienzan en la base del sistema.

PanelWindow {
    id: root

    WlrLayershell.namespace: "cocoa-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: Metrics.exclusiveZone

    anchors { top: true; left: true; right: true }

    // Dynamic implicitHeight: expands the Wayland surface if a flyout is open,
    // avoiding clipping. exclusiveZone remains fixed so other windows don't move.
    implicitHeight: Math.max(
        Metrics.exclusiveZone,
        powerMenuVisible ? (powerMenu.y + powerMenu.height + 4) : 0,
        mediaMenuVisible ? (mediaMenu.y + mediaMenu.height + 4) : 0
    )
    
    color: "transparent"   // La ventana en sí es transparente; los paneles son sólidos

    signal launcherRequested()

    // ─── Estado de menús ─────────────────────────────────────────────────────
    property bool powerMenuVisible: false
    property bool mediaMenuVisible: false

    // ─── Panel central (ancho completo arriba, estrecha abajo) ───────────────
    CenterCapsule {
        id: center
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Metrics.barHeight
        onClicked: {
            root.mediaMenuVisible = !root.mediaMenuVisible;
            if (root.mediaMenuVisible) root.powerMenuVisible = false;
        }
    }

    // ─── Panel izquierdo (anclado al tope, toca el borde de pantalla) ──────────
    LeftPanel {
        id: leftPanel
        anchors.left: parent.left
        anchors.top:  parent.top
        onLauncherRequested: root.launcherRequested()
    }

    // ─── Panel derecho (anclado al tope, toca el borde de pantalla) ────────────
    RightPanel {
        id: rightPanel
        anchors.right: parent.right
        anchors.top:   parent.top
        onPowerRequested: {
            root.powerMenuVisible = !root.powerMenuVisible;
            if (root.powerMenuVisible) root.mediaMenuVisible = false;
        }
    }

    // ─── Flyout de Reproductor (centro) ──────────────────────────────────────
    MediaFlyout {
        id: mediaMenu
        visible: root.mediaMenuVisible
        anchors.top: center.bottom
        anchors.horizontalCenter: center.horizontalCenter
    }

    // ─── Flyout de control de energía (derecha) ──────────────────────────────
    Item {
        id: powerMenu
        visible: root.powerMenuVisible
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: rightPanel.bottom
        anchors.topMargin: 0

        width: powerRow.implicitWidth + 24
        height: 30

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4

            ShapePath {
                fillColor: Colors.surfaceRaised
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: powerMenu.width; y: 0 }
                PathLine { x: powerMenu.width - 8; y: powerMenu.height }
                PathLine { x: 8;               y: powerMenu.height }
                PathLine { x: 0;               y: 0 }
            }
        }

        RowLayout {
            id: powerRow
            anchors.centerIn: parent
            spacing: 16

            Repeater {
                model: [
                    { icon: "system-lock-screen",  cmd: "exec hyprlock || loginctl lock-session", col: Colors.textMuted },
                    { icon: "system-suspend",       cmd: "exec systemctl suspend",                col: Colors.stateWarn  },
                    { icon: "system-reboot",        cmd: "exec systemctl reboot",                 col: Colors.textMuted  },
                    { icon: "system-shutdown",      cmd: "exec systemctl poweroff",               col: Colors.stateError }
                ]
                delegate: IconButton {
                    required property var modelData
                    buttonSize: Metrics.iconSizeLarge
                    iconName:   modelData.icon
                    iconColor:  modelData.col
                    onClicked: {
                        root.powerMenuVisible = false;
                        HyprlandService.dispatch(modelData.cmd);
                    }
                }
            }
        }
    }
}
