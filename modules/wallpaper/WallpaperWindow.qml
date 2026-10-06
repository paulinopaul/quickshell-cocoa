import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"

// WallpaperWindow — Selector de fondos de pantalla flotante en modo carrusel.
//
// Protocolo:
// - WlrLayershell.namespace: "cocoa-wallpaper-selector"
// - WlrLayershell.layer: WlrLayer.Overlay
// - WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
// - Dimensiones explícitas: 840x340 centrado en pantalla (Wayland sin anclajes laterales).
// - Ciclo de vida desacoplado: visible: surfaceActive, enterAnim (OutBack) y exitAnim (jump & dive con InCubic).
// - GlobalShortcut: "wallpaper_selector".
// - Navegación de teclado: Space / Right (avanzar), Left (retroceder), Return / Enter (aplicar), Escape (cerrar).

PanelWindow {
    id: root

    property bool isOpen: false
    property bool surfaceActive: false
    property var transitionWindow: null

    WlrLayershell.namespace: "cocoa-wallpaper-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    implicitWidth: 840
    implicitHeight: 340
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: surfaceActive

    GlobalShortcut {
        name: "wallpaper_selector"
        onPressed: root.toggle()
    }

    function open() {
        WallpaperService.refresh();
        exitAnim.stop();
        surfaceActive = true;
        isOpen = true;
        enterAnim.restart();
        card.forceActiveFocus();

        if (WallpaperService.currentIndex >= 0 && WallpaperService.currentIndex < WallpaperService.wallpapers.length) {
            carouselView.currentIndex = WallpaperService.currentIndex;
            carouselView.positionViewAtIndex(WallpaperService.currentIndex, ListView.Center);
        } else if (WallpaperService.wallpapers.length > 0) {
            carouselView.currentIndex = 0;
            carouselView.positionViewAtIndex(0, ListView.Center);
        }
    }

    function close() {
        if (!isOpen && !surfaceActive) return;
        isOpen = false;
        enterAnim.stop();
        exitAnim.restart();
    }

    function toggle() {
        if (isOpen) close();
        else open();
    }

    function advance() {
        if (!WallpaperService.wallpapers || WallpaperService.wallpapers.length === 0) return;
        let next = (carouselView.currentIndex + 1) % WallpaperService.wallpapers.length;
        carouselView.currentIndex = next;
    }

    function goBack() {
        if (!WallpaperService.wallpapers || WallpaperService.wallpapers.length === 0) return;
        let prev = (carouselView.currentIndex - 1 + WallpaperService.wallpapers.length) % WallpaperService.wallpapers.length;
        carouselView.currentIndex = prev;
    }

    function applyAndClose() {
        if (!WallpaperService.wallpapers || WallpaperService.wallpapers.length === 0) {
            root.close();
            return;
        }
        let item = WallpaperService.wallpapers[carouselView.currentIndex];
        if (item && item.path) {
            let oldPath = WallpaperService.currentPath;
            let newPath = item.path;
            if (root.transitionWindow && oldPath !== newPath) {
                root.transitionWindow.startTransition(oldPath, newPath);
            } else {
                WallpaperService.applyWallpaper(newPath);
            }
        }
        root.close();
    }

    // Animación de entrada: deslizamiento con rebote OutBack
    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: card
            property: "y"
            from: root.implicitHeight + 40
            to: 20
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.35
        }
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
        }
    }

    // Animación de salida: Salto hacia arriba (jump) y caída acelerada (dive)
    SequentialAnimation {
        id: exitAnim

        // 1. Salto hacia arriba (jump)
        NumberAnimation {
            target: card
            property: "y"
            to: 4
            duration: 75
            easing.type: Easing.OutQuad
        }

        // 2. Caída acelerada hacia abajo (dive)
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "y"
                to: root.implicitHeight + 40
                duration: 190
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0.0
                duration: 190
            }
        }

        // 3. Desmapeo total de la superficie Wayland
        ScriptAction {
            script: {
                root.surfaceActive = false;
            }
        }
    }

    // Tarjeta del contenedor central
    Rectangle {
        id: card
        x: 0
        y: 20
        width: parent.width
        height: parent.height - 20
        radius: 16
        color: Colors.surfaceRaised
        border.color: Colors.surface
        border.width: 1
        clip: true

        focus: true

        // Atajos de teclado dedicados y genéricos sobre el Item enfocado
        Keys.onSpacePressed: root.advance()
        Keys.onRightPressed: root.advance()
        Keys.onLeftPressed: root.goBack()
        Keys.onReturnPressed: root.applyAndClose()
        Keys.onEnterPressed: root.applyAndClose()
        Keys.onEscapePressed: root.close()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Right) {
                root.advance();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.goBack();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applyAndClose();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Header: Title "Wallpapers", current file name, index indicator
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 12

                Text {
                    text: "Wallpapers"
                    color: Colors.text
                    font.pixelSize: 14
                    font.family: Typography.family
                    font.bold: true
                }

                Rectangle {
                    width: 1
                    height: 14
                    color: Colors.surface
                }

                Text {
                    id: currentFileNameText
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: (carouselView.currentIndex >= 0 && WallpaperService.wallpapers.length > carouselView.currentIndex)
                          ? WallpaperService.wallpapers[carouselView.currentIndex].name
                          : ""
                    color: Colors.textMuted
                    font.pixelSize: Metrics.textSizeNormal
                    font.family: Typography.family
                }

                Text {
                    id: indexIndicatorText
                    text: WallpaperService.wallpapers.length > 0
                          ? `${carouselView.currentIndex + 1} / ${WallpaperService.wallpapers.length}`
                          : "0 / 0"
                    color: Colors.textDim
                    font.pixelSize: Metrics.textSizeSmall
                    font.family: Typography.family
                }
            }

            // Carrusel: Horizontal ListView with centered highlight
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: carouselView
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 16
                    clip: false

                    model: WallpaperService.wallpapers

                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width - 320) / 2
                    preferredHighlightEnd: (width + 320) / 2
                    highlightMoveDuration: 250
                    snapMode: ListView.SnapToItem

                    delegate: WallpaperCard {
                        id: cardDelegate
                        required property var modelData
                        required property int index

                        filePath: modelData ? (modelData.path || "") : ""
                        fileName: modelData ? (modelData.name || "") : ""
                        isCurrent: index === carouselView.currentIndex

                        onClicked: {
                            carouselView.currentIndex = index;
                        }

                        onDoubleClicked: {
                            carouselView.currentIndex = index;
                            root.applyAndClose();
                        }
                    }
                }
            }

            // Footer: Guía de navegación
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                Item { Layout.fillWidth: true }

                Text {
                    text: "[Space / ← →] Navegar • [Enter] Aplicar • [Esc] Cancelar"
                    color: Colors.textDim
                    font.pixelSize: Metrics.textSizeSmall
                    font.family: Typography.family
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
