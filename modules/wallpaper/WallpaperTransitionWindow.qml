import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../services"

// WallpaperTransitionWindow — Cinematic wallpaper transition window.
//
// Protocol:
// - WlrLayershell.namespace: "cocoa-wallpaper-transition"
// - WlrLayershell.layer: WlrLayer.Bottom (sits right above hyprpaper layer 0, below regular windows)
// - anchors: top, bottom, left, right (fullscreen)
// - exclusionMode: ExclusionMode.Ignore
// - color: "transparent"
// - visible: isTransitioning
//
// Effects:
// - Old Wallpaper Exit: Split into left and right halves with progressive blur and lateral displacement.
// - New Wallpaper Reveal: Diagonal wipe from corner to corner using MultiEffect and rotated mask.

PanelWindow {
    id: root

    WlrLayershell.namespace: "cocoa-wallpaper-transition"
    WlrLayershell.layer: WlrLayer.Bottom
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: isTransitioning

    property string oldWallpaper: ""
    property string newWallpaper: ""
    property real animProgress: 0.0
    property bool isTransitioning: false

    // Old Wallpaper (Unified base with progressive blur and gentle scale — zero center rupture)
    Image {
        id: oldImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
        visible: false
        source: root.oldWallpaper ? ("file://" + root.oldWallpaper) : ""
    }

    MultiEffect {
        id: oldEffect
        anchors.fill: parent
        source: oldImg
        blurEnabled: true
        blurMax: 48
        blur: root.animProgress
        opacity: Math.max(0.0, 1.0 - root.animProgress)
        scale: 1.0 + (root.animProgress * 0.03)
    }

    // New Wallpaper Reveal (corner-to-corner diagonal wipe)
    Item {
        id: maskItem
        anchors.fill: parent
        layer.enabled: true
        visible: false

        Item {
            id: rotContainer
            x: maskItem.width / 2
            y: maskItem.height / 2
            rotation: Math.atan2(maskItem.height, maskItem.width) * 180 / Math.PI

            Rectangle {
                id: wipeRect
                readonly property real d: Math.hypot(maskItem.width, maskItem.height)
                readonly property real cutPos: -d / 2 + root.animProgress * (d + 40)
                x: cutPos - (d * 1.5)
                y: -d
                width: d * 1.5
                height: d * 2
                color: "white"
            }
        }
    }

    Image {
        id: newImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(parent.width, parent.height)
        visible: false
        source: root.newWallpaper ? ("file://" + root.newWallpaper) : ""
    }

    MultiEffect {
        id: newEffect
        anchors.fill: parent
        source: newImg
        maskEnabled: true
        maskSource: maskItem
    }

    // Transition Animation (1.5 seconds smooth corner-to-corner) & Safety Timer
    NumberAnimation {
        id: transitionAnim
        target: root
        property: "animProgress"
        from: 0.0
        to: 1.0
        duration: 1500
        easing.type: Easing.InOutCubic

        onFinished: {
            WallpaperService.applyWallpaper(root.newWallpaper);
            safetyTimer.restart();
        }
    }

    Timer {
        id: safetyTimer
        interval: 140
        repeat: false
        onTriggered: {
            root.isTransitioning = false;
        }
    }

    function startTransition(oldPath, newPath) {
        oldWallpaper = oldPath;
        newWallpaper = newPath;
        animProgress = 0.0;
        isTransitioning = true;
        transitionAnim.restart();
    }
}
