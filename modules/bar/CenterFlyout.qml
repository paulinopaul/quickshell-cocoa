import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls

Item {
    id: root

    property int currentSection: 0
    readonly property int totalSections: 3
    property real scrollAccumulator: 0
    property bool expandedWithSuperP: false
    property real lastSwitchTime: 0

    signal closeRequested()

    implicitWidth: 540
    implicitHeight: 220

    // Animación suave de entrada y salida
    transformOrigin: Item.Top
    scale: visible ? 1 : 0.92
    opacity: visible ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    // Fondo del flyout redondeado (Superpuesto)
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, UiConfigService.centerCapsule.bgOpacity !== undefined ? UiConfigService.centerCapsule.bgOpacity : 1.0)
        border.color: Colors.surfaceRaised
        border.width: UiConfigService.centerCapsule.borderWidth !== undefined ? UiConfigService.centerCapsule.borderWidth : 1
        clip: true

        // Sutil fondo dinámico cuando la sección de música está activa
        Image {
            id: bgArt
            anchors.fill: parent
            source: (root.currentSection === 1 && MediaService.hasMedia) ? (MediaService.artUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors.fill: bgRect
            source: bgArt
            blurEnabled: true
            blur: 1.0
            blurMax: 80
            saturation: 1.2
            opacity: 0.20
            visible: root.currentSection === 1 && MediaService.hasMedia && MediaService.artUrl !== ""
        }
    }

    // Captura de rueda del ratón (hover) y gestos de trackpad (si expandido con Super+P)
    // Regla: "con la rueda del mouse mientras el raton este sobrepuesto,
    //         o con el trackpad si se ah expandido con super+p unicamente."
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        z: 0

        onWheel: (wheel) => {
            const now = Date.now();
            if (now - root.lastSwitchTime < 240) return; // Cooldown para sincronizar con la animación de deslizamiento

            // Detección de trackpad: deltas de alta resolución, fractional o scroll horizontal
            const hasPixelDelta = wheel.pixelDelta && (wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0);
            const isHighResAngle = Math.abs(wheel.angleDelta.y) > 0 && Math.abs(wheel.angleDelta.y) < 120;
            const isHorizontalScroll = Math.abs(wheel.angleDelta.x) > 0;
            const isTrackpad = hasPixelDelta || isHighResAngle || isHorizontalScroll;

            // Restricción: Si es trackpad y NO fue expandido con Super+P, se ignora.
            if (isTrackpad && !root.expandedWithSuperP) {
                return;
            }

            let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            if (hasPixelDelta) {
                delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.pixelDelta.x;
            }

            root.scrollAccumulator += delta;
            const threshold = isTrackpad ? 60 : 40;

            if (root.scrollAccumulator <= -threshold) {
                root.scrollAccumulator = 0;
                root.lastSwitchTime = now;
                root.currentSection = (root.currentSection + 1) % root.totalSections;
            } else if (root.scrollAccumulator >= threshold) {
                root.scrollAccumulator = 0;
                root.lastSwitchTime = now;
                root.currentSection = (root.currentSection - 1 + root.totalSections) % root.totalSections;
            }
        }
    }

    // Contenedor UI principal
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        z: 1

        // ── Cabecera de Apartados (Pestañas interactivas + Cerrar) ────────────
        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 8

                Repeater {
                    model: [
                        { title: "Telemetría", icon: "cpu" },
                        { title: "Música",     icon: "multimedia-audio-player" },
                        { title: "Agentes",    icon: "hub" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: tabRow.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: root.currentSection === index ? Colors.surfaceRaised : "transparent"
                        border.color: root.currentSection === index ? Colors.accent : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 6

                            Icon {
                                size: Metrics.iconSizeSmall
                                name: modelData.icon
                                color: root.currentSection === index ? Colors.text : Colors.textDim
                            }

                            Text {
                                text: modelData.title
                                color: root.currentSection === index ? Colors.text : Colors.textDim
                                font.pixelSize: 11
                                font.family: Typography.family
                                font.weight: root.currentSection === index ? Typography.weightBold : Typography.weightNormal
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentSection = index
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                buttonSize: 22
                iconName: "window-close"
                iconColor: Colors.textDim
                onClicked: root.closeRequested()
            }
        }

        // ── Carrusel Deslizable de Apartados ──────────────────────────────────
        Item {
            id: sliderViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Item {
                id: sliderContent
                width: sliderViewport.width * root.totalSections
                height: sliderViewport.height
                x: -root.currentSection * sliderViewport.width

                Behavior on x {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }

                // =============================================================
                // APARTADO 0: TELEMETRÍA DETALLADA
                // =============================================================
                Item {
                    x: 0
                    width: sliderViewport.width
                    height: sliderViewport.height

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16

                        // Columna 1: CPU, RAM y Gráficas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: 12
                            border.color: Colors.surfaceRaised
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                // CPU
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon { size: Metrics.iconSizeSmall; name: "cpu"; color: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.textMuted }
                                    Text { text: "CPU"; color: Colors.textMuted; font.pixelSize: 11; font.family: Typography.familyMonospace }
                                    Item { Layout.fillWidth: true }
                                    Text { text: SystemService.cpuUsage + "%"; color: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.text; font.pixelSize: 11; font.family: Typography.familyMonospace; font.weight: Typography.weightBold }
                                    Meter { value: SystemService.cpuUsage / 100; implicitWidth: 60; barHeight: 3; barColor: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.accent }
                                }

                                // RAM
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon { size: Metrics.iconSizeSmall; name: "ram"; color: SystemService.ramUsage > 85 ? Colors.stateError : Colors.textMuted }
                                    Text { text: "RAM"; color: Colors.textMuted; font.pixelSize: 11; font.family: Typography.familyMonospace }
                                    Item { Layout.fillWidth: true }
                                    Text { text: SystemService.ramUsedGb + "G / " + SystemService.ramTotalGb + "G (" + SystemService.ramUsage + "%)"; color: SystemService.ramUsage > 85 ? Colors.stateError : Colors.text; font.pixelSize: 10; font.family: Typography.familyMonospace; font.weight: Typography.weightBold }
                                    Meter { value: SystemService.ramUsage / 100; implicitWidth: 60; barHeight: 3; barColor: SystemService.ramUsage > 85 ? Colors.stateError : Colors.accent }
                                }

                                // GPU Intel
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon { size: Metrics.iconSizeSmall; name: "video-display"; color: Colors.textMuted }
                                    Text { text: "Intel Xe"; color: Colors.textMuted; font.pixelSize: 11; font.family: Typography.familyMonospace }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(SystemService.gpuIntel) + "%"; color: Colors.text; font.pixelSize: 11; font.family: Typography.familyMonospace; font.weight: Typography.weightBold }
                                    Meter { value: SystemService.gpuIntel / 100; implicitWidth: 60; barHeight: 3; barColor: Colors.accent }
                                }

                                // GPU NVIDIA
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon { size: Metrics.iconSizeSmall; name: "video-display"; color: Colors.textMuted }
                                    Text { text: "RTX 3050"; color: Colors.textMuted; font.pixelSize: 11; font.family: Typography.familyMonospace }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(SystemService.gpuNvidia) + "%"; color: Colors.text; font.pixelSize: 11; font.family: Typography.familyMonospace; font.weight: Typography.weightBold }
                                    Meter { value: SystemService.gpuNvidia / 100; implicitWidth: 60; barHeight: 3; barColor: Colors.stateWarn }
                                }
                            }
                        }

                        // Columna 2: Red, Velocidad y Puerto Serial
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: 12
                            border.color: Colors.surfaceRaised
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Red Conectada
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon {
                                        size: Metrics.iconSizeSmall
                                        name: NetworkService.isConnected ? (NetworkService.isWifi ? "network-wireless" : "network-wired") : "network-offline"
                                        color: NetworkService.isConnected ? Colors.stateOk : Colors.stateError
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Red Conectada"; color: Colors.textDim; font.pixelSize: 10 }
                                        Text {
                                            text: NetworkService.isConnected ? (NetworkService.ssid || "Conectado") : "Desconectado"
                                            color: Colors.text; font.pixelSize: 12; font.weight: Typography.weightBold
                                            elide: Text.ElideRight; Layout.maximumWidth: 190
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                                // Velocidad de Internet
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon { size: Metrics.iconSizeSmall; name: "drive-harddisk"; color: Colors.accent }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Velocidad de Internet"; color: Colors.textDim; font.pixelSize: 10 }
                                        Text {
                                            text: SystemService.netSpeedString
                                            color: Colors.text; font.pixelSize: 11; font.family: Typography.familyMonospace; font.weight: Typography.weightBold
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Colors.surfaceRaised }

                                // Puerto Serial Conectado
                                RowLayout {
                                    Layout.fillWidth: true
                                    Icon {
                                        size: Metrics.iconSizeSmall
                                        name: "hub"
                                        color: SystemService.serialDevice !== "Sin conexión" ? Colors.stateOk : Colors.textDim
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Puerto Serial"; color: Colors.textDim; font.pixelSize: 10 }
                                        Text {
                                            text: SystemService.serialDevice
                                            color: SystemService.serialDevice !== "Sin conexión" ? Colors.stateOk : Colors.textMuted
                                            font.pixelSize: 11; font.family: Typography.familyMonospace; font.weight: Typography.weightBold
                                            elide: Text.ElideRight; Layout.maximumWidth: 190
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // APARTADO 1: REPRODUCTOR DE MÚSICA
                // =============================================================
                Item {
                    x: sliderViewport.width
                    width: sliderViewport.width
                    height: sliderViewport.height

                    RowLayout {
                        anchors.fill: parent
                        spacing: 18

                        // Portada del Álbum
                        Rectangle {
                            width: 110
                            height: 110
                            radius: 12
                            color: Colors.background
                            border.color: Colors.surfaceRaised
                            border.width: 1
                            clip: true
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: MediaService.artUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                visible: MediaService.artUrl !== ""
                            }

                            Icon {
                                anchors.centerIn: parent
                                size: 48
                                name: "multimedia-audio-player"
                                color: Colors.textDim
                                visible: MediaService.artUrl === ""
                            }
                        }

                        // Metadatos y Controles
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: MediaService.hasMedia ? (MediaService.rawTitle || "Desconocido") : "Sin reproducción"
                                    color: Colors.text
                                    font.pixelSize: 16
                                    font.weight: Typography.weightBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: MediaService.hasMedia ? (MediaService.rawArtist || "Desconocido") : "Inicia un reproductor multimedia"
                                    color: Colors.textMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Barra de progreso
                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Colors.background

                                Rectangle {
                                    width: parent.width * MediaService.progress
                                    height: parent.height
                                    radius: 2
                                    color: Colors.accent
                                    Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                                }
                            }

                            // Botones de Reproducción
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 24

                                IconButton {
                                    buttonSize: 28
                                    iconName: "media-skip-backward"
                                    iconColor: Colors.text
                                    onClicked: MediaService.previous()
                                }

                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: Colors.surfaceRaised
                                    border.color: Colors.accent
                                    border.width: 1

                                    Icon {
                                        anchors.centerIn: parent
                                        size: 20
                                        name: MediaService.isPlaying ? "media-playback-pause" : "media-playback-start"
                                        color: Colors.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MediaService.playPause()
                                    }
                                }

                                IconButton {
                                    buttonSize: 28
                                    iconName: "media-skip-forward"
                                    iconColor: Colors.text
                                    onClicked: MediaService.next()
                                }
                            }
                        }
                    }
                }

                // =============================================================
                // APARTADO 2: INFORMACIÓN DE LOS AGENTES
                // =============================================================
                Item {
                    x: sliderViewport.width * 2
                    width: sliderViewport.width
                    height: sliderViewport.height

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Cabecera del agente y estado actual
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: AntigravityService.awaitingApproval ? Qt.rgba(Colors.stateError.r, Colors.stateError.g, Colors.stateError.b, 0.2)
                                     : AntigravityService.isWorking        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                                     : AntigravityService.isThinking       ? Qt.rgba(Colors.stateWarn.r, Colors.stateWarn.g, Colors.stateWarn.b, 0.2)
                                     : Qt.rgba(Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.2)

                                Icon {
                                    anchors.centerIn: parent
                                    size: 14
                                    name: AntigravityService.awaitingApproval ? "dialog-question"
                                         : AntigravityService.isThinking       ? "system-search"
                                         : AntigravityService.isWorking        ? "system-run"
                                         : "hub"
                                    color: AntigravityService.awaitingApproval ? Colors.stateError
                                         : AntigravityService.isWorking        ? Colors.accent
                                         : AntigravityService.isThinking       ? Colors.stateWarn
                                         : Colors.textMuted
                                }
                            }

                            Text {
                                text: "Antigravity Agent · " + (
                                    AntigravityService.awaitingApproval ? "APROBACIÓN REQUERIDA" :
                                    AntigravityService.isThinking       ? "PROCESANDO" :
                                    AntigravityService.isWorking        ? "EJECUTANDO ACCIÓN" : "EN REPOSO"
                                )
                                color: AntigravityService.awaitingApproval ? Colors.stateError : Colors.text
                                font.pixelSize: 12
                                font.family: Typography.familyMonospace
                                font.weight: Typography.weightBold
                                Layout.fillWidth: true
                            }
                        }

                        // Acción actual
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            color: Colors.background
                            radius: 8
                            border.color: Colors.surfaceRaised
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: AntigravityService.action || "Listo para nuevas tareas"
                                    color: Colors.text
                                    font.pixelSize: 12
                                    font.weight: Typography.weightMedium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Herramienta / Comando activo o Historial reciente
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: 8
                            border.color: Colors.surfaceRaised
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                Text {
                                    text: AntigravityService.tool ? ("Herramienta: " + AntigravityService.tool) : "Actividades recientes:"
                                    color: Colors.textDim
                                    font.pixelSize: 10
                                    font.family: Typography.familyMonospace
                                }

                                Repeater {
                                    model: {
                                        let h = AntigravityService.history || [];
                                        return h.slice(-2).reverse();
                                    }

                                    delegate: RowLayout {
                                        required property string modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text { text: "›"; color: Colors.accent; font.pixelSize: 11; font.family: Typography.familyMonospace }
                                        Text {
                                            text: modelData
                                            color: Colors.textMuted
                                            font.pixelSize: 10
                                            font.family: Typography.familyMonospace
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true; visible: (AntigravityService.history || []).length === 0 }
                            }
                        }
                    }
                }
            }
        }

        // ── Indicador de Paginación (Puntos) ──────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: root.totalSections
                delegate: Rectangle {
                    required property int index
                    width: index === root.currentSection ? 16 : 6
                    height: 4
                    radius: 2
                    color: index === root.currentSection ? Colors.accent : Colors.surfaceRaised

                    Behavior on width { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentSection = index
                    }
                }
            }
        }
    }
}
