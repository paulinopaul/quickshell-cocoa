import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property string activeMode: ThemeService.mode || "auto" // "auto" | named theme | "custom"
    property string customHexInput: Colors.accent.toString()
    property string selectedPreset: Colors.accent.toString()
    property string selectedNamedTheme: "NeoNord"
    property string feedbackMessage: ""

    readonly property var namedThemes: [
        { name: "NeoNord", hex: "#88c0d0", desc: "Nord Frost" },
        { name: "Catppuccin Mocha", hex: "#cba6f7", desc: "Pastel Mauve" },
        { name: "Tokyo Night", hex: "#7aa2f7", desc: "Neon Blue" },
        { name: "Gruvbox Retro", hex: "#d79921", desc: "Warm Gold" },
        { name: "Rose Pine", hex: "#eb6f92", desc: "Pine Rose" },
        { name: "Cyberpunk Neon", hex: "#00f0ff", desc: "Electric Cyan" },
        { name: "Emerald Forest", hex: "#10b981", desc: "Vibrant Green" },
        { name: "Sunset Glow", hex: "#f59e0b", desc: "Twilight Orange" },
        { name: "Cocoa Classic", hex: "#d4af37", desc: "Signature Gold" }
    ]

    readonly property string currentWallpaperMappedTheme: {
        let path = WallpaperService.currentPath || "";
        let db = ThemeService.database || {};
        let mappings = db.mappings || {};
        if (mappings[path]) {
            return mappings[path].themeName || "Personalizado";
        }
        // Tracked mapping keys are portable (`~`-relative, no hardcoded user);
        // fall back to the portable form of the absolute runtime path.
        let portable = path.replace(/^\/home\/[^\/]+/, "~");
        if (mappings[portable]) {
            return mappings[portable].themeName || "Personalizado";
        }
        return "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Tema y Paleta de Colores"
                    color: Colors.text
                    font.pixelSize: 18
                    font.weight: Typography.weightBold
                }

                Text {
                    text: root.currentWallpaperMappedTheme !== ""
                          ? ("Fondo actual vinculado al tema: " + root.currentWallpaperMappedTheme)
                          : "Selecciona una paleta global o vincula un tema a cada fondo de pantalla"
                    color: root.currentWallpaperMappedTheme !== "" ? Colors.accent : Colors.textMuted
                    font.pixelSize: 13
                }
            }

            // Selector Segmentado de Modo
            Rectangle {
                implicitWidth: 260
                implicitHeight: 32
                radius: 16
                color: Colors.surfaceRaised
                border.color: Colors.surfaceBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Opción Paletas Globales
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: root.activeMode !== "auto" ? Colors.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Paletas Globales"
                            color: root.activeMode !== "auto" ? Colors.background : Colors.textMuted
                            font.pixelSize: 11
                            font.weight: root.activeMode !== "auto" ? Typography.weightBold : Typography.weightNormal
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeMode = root.selectedNamedTheme;
                                ThemeService.applyNamedTheme(root.selectedNamedTheme);
                            }
                        }
                    }

                    // Opción Dinámico Wallpaper
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: root.activeMode === "auto" ? Colors.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Dinámico"
                            color: root.activeMode === "auto" ? Colors.background : Colors.textMuted
                            font.pixelSize: 11
                            font.weight: root.activeMode === "auto" ? Typography.weightBold : Typography.weightNormal
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeMode = "auto";
                                ThemeService.syncWithWallpaper();
                            }
                        }
                    }
                }
            }
        }

        // Pill de Feedback
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: visible ? 22 : 0
            implicitWidth: feedbackText.implicitWidth + 18
            radius: 11
            visible: root.feedbackMessage !== ""
            color: Qt.rgba(Colors.stateOk.r, Colors.stateOk.g, Colors.stateOk.b, 0.15)
            border.color: Colors.stateOk
            border.width: 1

            Text {
                id: feedbackText
                anchors.centerIn: parent
                text: root.feedbackMessage
                color: Colors.stateOk
                font.pixelSize: 11
                font.weight: Typography.weightMedium
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: themeScrollCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: themeScrollCol
                    width: parent.width
                    spacing: 12

                    // ── SECCIÓN 1: PALETAS DE COLOR DEL SISTEMA ───────────────
                    Text {
                        text: "Paletas del Sistema (NeoNord, Catppuccin, Tokyo Night, etc.)"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    // Grid de Temas Predefinidos
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: root.namedThemes

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: (root.selectedNamedTheme === modelData.name || Colors.accent.toString().toLowerCase() === modelData.hex.toLowerCase())
                                       ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
                                       : Colors.surface
                                border.color: (root.selectedNamedTheme === modelData.name || Colors.accent.toString().toLowerCase() === modelData.hex.toLowerCase())
                                              ? Colors.accent : Colors.surfaceRaised
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Rectangle {
                                        width: 24; height: 24; radius: 12
                                        color: modelData.hex
                                        border.color: Colors.text; border.width: 1
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.name
                                            color: Colors.text
                                            font.pixelSize: 11
                                            font.weight: Typography.weightBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.desc + " (" + modelData.hex + ")"
                                            color: Colors.textDim
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedNamedTheme = modelData.name;
                                        root.activeMode = modelData.name;
                                        ThemeService.applyNamedTheme(modelData.name);
                                        root.feedbackMessage = "Tema " + modelData.name + " aplicado en todo el sistema y Hyprland.";
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // ── SECCIÓN 2: VINCULACIÓN FONDO DE PANTALLA <-> TEMA ──────
                    Text {
                        text: "Asignación de Tema a Fondos de Pantalla"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: wallBindingCol.implicitHeight + 20
                        radius: 10
                        color: Colors.surface
                        border.color: Colors.surfaceRaised
                        border.width: 1

                        ColumnLayout {
                            id: wallBindingCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                // Miniatura del fondo actual
                                Rectangle {
                                    implicitWidth: 140
                                    implicitHeight: 78
                                    radius: 6
                                    clip: true
                                    color: Colors.background
                                    border.color: Colors.surfaceRaised
                                    border.width: 1

                                    Image {
                                        anchors.fill: parent
                                        source: WallpaperService.currentPath ? ("file://" + WallpaperService.currentPath) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: WallpaperService.currentPath
                                              ? WallpaperService.currentPath.split("/").pop()
                                              : "Fondo actual de pantalla"
                                        color: Colors.text
                                        font.pixelSize: 12
                                        font.weight: Typography.weightBold
                                    }

                                    Text {
                                        text: root.currentWallpaperMappedTheme !== ""
                                              ? ("✓ Este wallpaper tiene asignado el tema: " + root.currentWallpaperMappedTheme)
                                              : "Este fondo no tiene tema fijo (usa extracción de colores automática)."
                                        color: root.currentWallpaperMappedTheme !== "" ? Colors.accent : Colors.textMuted
                                        font.pixelSize: 11
                                    }

                                    RowLayout {
                                        Layout.topMargin: 4
                                        spacing: 8

                                        // Botón: Asignar tema actual a este fondo
                                        Rectangle {
                                            implicitWidth: 190
                                            implicitHeight: 28
                                            radius: 6
                                            color: bindMouse.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Asignar tema " + root.selectedNamedTheme + " a este fondo"
                                                color: Colors.background
                                                font.pixelSize: 10
                                                font.weight: Typography.weightBold
                                            }

                                            MouseArea {
                                                id: bindMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (WallpaperService.currentPath) {
                                                        ThemeService.bindWallpaper(WallpaperService.currentPath, root.selectedNamedTheme);
                                                        root.feedbackMessage = "¡Fondo vinculado a " + root.selectedNamedTheme + "! Al volver a este wallpaper se aplicará este tema.";
                                                    }
                                                }
                                            }
                                        }

                                        // Botón: Crear tema a partir de este fondo
                                        Rectangle {
                                            implicitWidth: 170
                                            implicitHeight: 28
                                            radius: 6
                                            color: createMouse.containsMouse ? Colors.surfaceHover : Colors.surfaceRaised

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Crear tema en base a este fondo"
                                                color: Colors.text
                                                font.pixelSize: 10
                                                font.weight: Typography.weightMedium
                                            }

                                            MouseArea {
                                                id: createMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (WallpaperService.currentPath) {
                                                        ThemeService.createThemeFromWallpaper(WallpaperService.currentPath, "");
                                                        root.feedbackMessage = "Paleta extraída y guardada como tema asociado al fondo.";
                                                    }
                                                }
                                            }
                                        }

                                        // Desvincular si tiene asignación
                                        Rectangle {
                                            visible: root.currentWallpaperMappedTheme !== ""
                                            implicitWidth: 90
                                            implicitHeight: 28
                                            radius: 6
                                            color: unbindMouse.containsMouse ? Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.2) : Colors.surfaceRaised

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Desvincular"
                                                color: Colors.stateError
                                                font.pixelSize: 10
                                            }

                                            MouseArea {
                                                id: unbindMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ThemeService.unbindWallpaper(WallpaperService.currentPath);
                                                    root.feedbackMessage = "Fondo desvinculado. Ahora usará extracción dinámica.";
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                    // ── SECCIÓN 3: COLOR HEX MANUAL Y PREVIEW EN VIVO ──────────
                    Text {
                        text: "Acento Personalizado (Hexadecimal) y Vista Previa"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Typography.weightBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        TextField {
                            id: hexField
                            Layout.preferredWidth: 130
                            height: 32
                            text: root.customHexInput
                            color: Colors.text
                            font.pixelSize: 12
                            placeholderText: "#RRGGBB"

                            background: Rectangle {
                                radius: 6
                                color: Colors.background
                                border.color: hexField.activeFocus ? Colors.accent : Colors.surfaceRaised
                                border.width: 1
                            }

                            onTextChanged: root.customHexInput = text
                            onAccepted: {
                                if (text.trim() !== "") {
                                    ThemeService.applyCustomTheme(text.trim());
                                    root.feedbackMessage = "Acento personalizado " + text.trim() + " aplicado.";
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 80
                            implicitHeight: 32
                            radius: 6
                            color: applyHexMouse.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Aplicar"
                                color: Colors.background
                                font.pixelSize: 11
                                font.weight: Typography.weightBold
                            }

                            MouseArea {
                                id: applyHexMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.customHexInput.trim() !== "") {
                                        ThemeService.applyCustomTheme(root.customHexInput.trim());
                                        root.feedbackMessage = "Acento personalizado aplicado.";
                                    }
                                }
                            }
                        }

                        // Componentes de muestra
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 6
                            color: Colors.surfaceRaised

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 10

                                Rectangle {
                                    implicitWidth: 70; implicitHeight: 24; radius: 4; color: Colors.accent
                                    Text { anchors.centerIn: parent; text: "Botón"; color: Colors.background; font.pixelSize: 10; font.weight: Typography.weightBold }
                                }
                                Rectangle {
                                    implicitWidth: 90; implicitHeight: 20; radius: 10
                                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                                    border.color: Colors.accent; border.width: 1
                                    Text { anchors.centerIn: parent; text: "Tag Activo"; color: Colors.accent; font.pixelSize: 9; font.weight: Typography.weightBold }
                                }
                                Text {
                                    text: "Accent: " + Colors.accent.toString()
                                    color: Colors.textMuted
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
