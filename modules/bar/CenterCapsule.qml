import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property int currentMode: 0
    readonly property int totalModes: 4
    readonly property int sk: Metrics.centerTrapSkewBottom
    readonly property int ch: Metrics.barHeight

    signal clicked()

    visible: UiConfigService.centerCapsule.visible !== false

    implicitHeight: ch

    // 1. Trapecio central principal (Fondo)
    Shape {
        id: bgShape
        property int trapWidth: 485
        property int centerX: root.width / 2
        property int startX_pos: centerX - (trapWidth / 2)
        property int endX_pos: centerX + (trapWidth / 2)

        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, UiConfigService.centerCapsule.bgOpacity !== undefined ? UiConfigService.centerCapsule.bgOpacity : 1.0)
            strokeColor: Colors.surfaceBorder
            strokeWidth: UiConfigService.centerCapsule.borderWidth !== undefined ? UiConfigService.centerCapsule.borderWidth : 1
            startX: bgShape.startX_pos; startY: 0
            PathLine { x: bgShape.endX_pos; y: 0 }
            PathLine { x: bgShape.endX_pos - root.sk; y: root.ch }
            PathLine { x: bgShape.startX_pos + root.sk; y: root.ch }
            PathLine { x: bgShape.startX_pos; y: 0 }
        }
    }

    // 2. Línea Neon (Gradiente en la base)
    Item {
        id: neonContainer
        width: bgShape.trapWidth
        height: root.ch
        anchors.horizontalCenter: parent.horizontalCenter
        visible: UiConfigService.centerCapsule.showNeon !== false
        
        // 2.1 Color base (Flujo de colores optimizado con caché)
        Item {
            id: colorSourceContainer
            anchors.fill: parent
            visible: false
            layer.enabled: true
            
            // --- ESTADO IDLE: Degradado rotativo ---
            Item {
                id: themeGradientSource
                anchors.fill: parent
                visible: !MediaService.hasMedia || MediaService.artUrl === ""
                
                LinearGradient {
                    width: parent.width * 2
                    height: parent.height
                    start: Qt.point(0, 0)
                    end: Qt.point(width, 0)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Colors.accent }
                        GradientStop { position: 0.16; color: Colors.stateWarn }
                        GradientStop { position: 0.33; color: Colors.stateError }
                        GradientStop { position: 0.5; color: Colors.accent } // Bucle
                        GradientStop { position: 0.66; color: Colors.stateWarn }
                        GradientStop { position: 0.83; color: Colors.stateError }
                        GradientStop { position: 1.0; color: Colors.accent }
                    }
                    
                    // IMPORTANTE PARA RENDIMIENTO: Caché de textura ANTES de moverla
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; saturation: 2.5 }
                    
                    SequentialAnimation on x {
                        loops: Animation.Infinite; running: neonContainer.visible && themeGradientSource.visible
                        NumberAnimation { from: 0; to: -bgShape.trapWidth; duration: 8000; easing.type: Easing.Linear }
                    }
                }
            }

            // --- ESTADO MEDIA: Degradado con la portada del álbum ---
            Item {
                id: albumGradientSource
                anchors.fill: parent
                visible: (UiConfigService.centerCapsule.showMedia !== false) && MediaService.hasMedia && MediaService.artUrl !== ""
                
                Row {
                    height: parent.height
                    
                    SequentialAnimation on x {
                        loops: Animation.Infinite; running: neonContainer.visible && albumGradientSource.visible
                        NumberAnimation { from: 0; to: -(bgShape.trapWidth * 2); duration: 25000; easing.type: Easing.Linear }
                    }
                    
                    Image { 
                        width: bgShape.trapWidth; height: parent.height; source: MediaService.artUrl || ""; fillMode: Image.Stretch 
                        layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; saturation: 2.5 }
                    }
                    Image { 
                        width: bgShape.trapWidth; height: parent.height; source: MediaService.artUrl || ""; fillMode: Image.Stretch; mirror: true 
                        layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; saturation: 2.5 }
                    }
                    Image { 
                        width: bgShape.trapWidth; height: parent.height; source: MediaService.artUrl || ""; fillMode: Image.Stretch 
                        layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; saturation: 2.5 }
                    }
                }
            }
        }

        // 2.2 Barra completa en la base menor
        Item {
            id: movingMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            
            Rectangle {
                id: glowingSegment
                x: root.sk
                y: root.ch - 1
                width: bgShape.trapWidth - (2 * root.sk)
                height: 1
                color: "black" // Alpha 1 para mascarilla
            }
        }

        // 2.3 Resultado Final (Línea de color)
        OpacityMask {
            anchors.fill: parent
            source: colorSourceContainer
            maskSource: movingMask
            // NOTA: Se eliminó el MultiEffect de capa final por costo de CPU extremo (60fps blur)
        }
    }

    // 3. Área de Interacción (Click para expandir el panel desacoplado)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // 4. Telemetría Exclusiva (CPU, RAM, GPU Intel, GPU NVIDIA)
    RowLayout {
        anchors.centerIn: parent
        spacing: Metrics.itemSpacing + 4

        // CPU
        RowLayout {
            visible: UiConfigService.centerCapsule.showCpu !== false
            spacing: 5
            Icon { size: Metrics.iconSizeSmall; name: "cpu"; color: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.textMuted }
            Text {
                text: "CPU " + SystemService.cpuUsage + "%"
                color: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.text
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
                font.weight: Typography.weightMedium
            }
            Meter {
                value: SystemService.cpuUsage / 100
                barHeight: 2
                implicitWidth: 28
                barColor: SystemService.cpuUsage > 80 ? Colors.stateError : Colors.textDim
            }
        }

        Rectangle {
            width: 1; height: 9; color: Colors.textDim; opacity: 0.4
            visible: (UiConfigService.centerCapsule.showCpu !== false) && (UiConfigService.centerCapsule.showRam !== false)
        }

        // RAM
        RowLayout {
            visible: UiConfigService.centerCapsule.showRam !== false
            spacing: 5
            Icon { size: Metrics.iconSizeSmall; name: "ram"; color: SystemService.ramUsage > 85 ? Colors.stateError : Colors.textMuted }
            Text {
                text: "RAM " + SystemService.ramUsedGb + "G"
                color: SystemService.ramUsage > 85 ? Colors.stateError : Colors.text
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
                font.weight: Typography.weightMedium
            }
            Meter {
                value: SystemService.ramUsage / 100
                barHeight: 2
                implicitWidth: 28
                barColor: SystemService.ramUsage > 85 ? Colors.stateError : Colors.textDim
            }
        }

        Rectangle {
            width: 1; height: 9; color: Colors.textDim; opacity: 0.4
            visible: (UiConfigService.centerCapsule.showRam !== false) && (UiConfigService.centerCapsule.showGpu !== false)
        }

        // GPU Intel
        RowLayout {
            visible: UiConfigService.centerCapsule.showGpu !== false
            spacing: 4
            Text {
                text: "INT " + Math.round(SystemService.gpuIntel) + "%"
                color: SystemService.gpuIntel > 80 ? Colors.accent : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
                font.weight: Typography.weightMedium
            }
        }

        Rectangle {
            width: 1; height: 9; color: Colors.textDim; opacity: 0.4
            visible: UiConfigService.centerCapsule.showGpu !== false
        }

        // GPU NVIDIA
        RowLayout {
            visible: UiConfigService.centerCapsule.showGpu !== false
            spacing: 4
            Text {
                text: "NVD " + Math.round(SystemService.gpuNvidia) + "%"
                color: SystemService.gpuNvidia > 80 ? Colors.stateWarn : Colors.textMuted
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
                font.weight: Typography.weightMedium
            }
        }
    }


    // ── Indicador persistente de Antigravity ──────────────────────────────────
    // Punto de estado visible en cualquier modo — nunca cambia el modo activo.
    Item {
        id: agyIndicator
        visible: AntigravityService.isActive
        width:  10
        height: 10

        // Esquina superior derecha del trapecio, desplazado del borde inclinado
        anchors.right:       parent.right
        anchors.top:         parent.top
        anchors.rightMargin: root.sk + 18
        anchors.topMargin:   5

        // Halo exterior pulsante (ring)
        Rectangle {
            anchors.centerIn: parent
            width:   10; height: 10; radius: 5
            color:   "transparent"
            border.width: 1.5
            border.color: AntigravityService.awaitingApproval ? Colors.stateError
                        : AntigravityService.isWorking        ? Colors.accent
                        : Colors.stateWarn
            opacity: 0

            Behavior on border.color { ColorAnimation { duration: 300 } }

            SequentialAnimation on opacity {
                loops:   Animation.Infinite
                running: AntigravityService.isActive
                NumberAnimation { to: 0.9; duration: 700; easing.type: Easing.OutCubic }
                NumberAnimation { to: 0.0; duration: 700; easing.type: Easing.InCubic }
            }
        }

        // Punto central sólido
        Rectangle {
            anchors.centerIn: parent
            width:   5; height: 5; radius: 3
            color: AntigravityService.awaitingApproval ? Colors.stateError
                 : AntigravityService.isWorking        ? Colors.accent
                 : Colors.stateWarn

            Behavior on color { ColorAnimation { duration: 300 } }

            SequentialAnimation on opacity {
                loops:   Animation.Infinite
                running: AntigravityService.isActive
                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
            }
        }
    }

}