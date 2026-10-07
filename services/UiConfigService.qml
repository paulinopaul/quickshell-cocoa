pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// UiConfigService — Centralized reactive service for visual appearance,
// Hyprland decorations, Ghostty styling, and Cocoa top bar element configurations.

QtObject {
    id: root

    readonly property string _configPath: Qt.resolvedUrl("../theme/ui_config.json").toString().replace("file://", "")
    readonly property string _script: Qt.resolvedUrl("../scripts/visual_config_manager.py").toString().replace("file://", "")

    // Hyprland decorations
    property var hyprland: ({
        "borderSize": 2,
        "rounding": 14,
        "shadowEnabled": true,
        "shadowRange": 15,
        "shadowPower": 6
    })

    // Ghostty terminal styling
    property var ghostty: ({
        "theme": "Onenord",
        "backgroundOpacity": 0.95,
        "backgroundBlur": 24
    })

    // Top Bar Panels configuration
    property var leftPanel: ({
        "visible": true,
        "bgOpacity": 0.95,
        "borderWidth": 1,
        "showWorkspaces": true,
        "showActiveWindow": true
    })

    property var centerCapsule: ({
        "visible": true,
        "bgOpacity": 0.95,
        "borderWidth": 1,
        "showMedia": true,
        "showCpu": true,
        "showRam": true,
        "showGpu": true,
        "showNeon": true
    })

    property var rightPanel: ({
        "visible": true,
        "bgOpacity": 0.95,
        "borderWidth": 1,
        "showBattery": true,
        "showNetwork": true,
        "showMic": true,
        "showVolume": true,
        "showBrightness": true,
        "showSettings": true,
        "showPower": true
    })

    property var ghosttyThemes: [
        "Onenord",
        "Catppuccin Mocha",
        "Catppuccin Macchiato",
        "TokyoNight Night",
        "Gruvbox Dark",
        "Rose Pine",
        "Nord",
        "Dracula",
        "Cyberpunk",
        "Everforest Dark Hard",
        "Kanagawa Wave",
        "Monokai Pro"
    ]

    property Process actionProc: Process {
        command: []
        running: false
        onExited: (exitCode) => {
            root._fileView.reload();
        }
    }

    property var _fileView: FileView {
        path: root._configPath
        watchChanges: true
        onTextChanged: root._parseConfig(text())
    }

    Component.onCompleted: {
        root._fileView.reload();
        root._parseConfig(root._fileView.text());
    }

    function _parseConfig(rawText) {
        if (!rawText || rawText.trim() === "") return;
        try {
            let data = JSON.parse(rawText.trim());
            if (data.hyprland) root.hyprland = Object.assign({}, root.hyprland, data.hyprland);
            if (data.ghostty) root.ghostty = Object.assign({}, root.ghostty, data.ghostty);
            if (data.panels) {
                if (data.panels.left) root.leftPanel = Object.assign({}, root.leftPanel, data.panels.left);
                if (data.panels.center) root.centerCapsule = Object.assign({}, root.centerCapsule, data.panels.center);
                if (data.panels.right) root.rightPanel = Object.assign({}, root.rightPanel, data.panels.right);
            }
        } catch (e) {}
    }

    function saveHyprland(borderSize, rounding, shadowEnabled, shadowRange, shadowPower) {
        actionProc.command = [
            "python3", root._script, "set-hyprland",
            borderSize.toString(),
            rounding.toString(),
            shadowEnabled ? "true" : "false",
            shadowRange.toString(),
            shadowPower.toString()
        ];
        actionProc.running = true;
    }

    function saveGhostty(theme, opacity, blur) {
        actionProc.command = [
            "python3", root._script, "set-ghostty",
            theme,
            opacity.toString(),
            blur.toString()
        ];
        actionProc.running = true;
    }

    function setPanelProperty(panelId, key, value) {
        actionProc.command = [
            "python3", root._script, "set-panel",
            panelId,
            key,
            value.toString()
        ];
        actionProc.running = true;
    }

    function togglePanelProperty(panelId, key) {
        let current = false;
        if (panelId === "left") current = !!root.leftPanel[key];
        else if (panelId === "center") current = !!root.centerCapsule[key];
        else if (panelId === "right") current = !!root.rightPanel[key];

        setPanelProperty(panelId, key, !current);
    }
}
