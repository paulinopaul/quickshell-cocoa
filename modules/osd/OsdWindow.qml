import "../../components"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    
    WlrLayershell.namespace: "cocoa-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    // Máscara vacía: garantiza 100% click-through (la ventana nunca intercepta eventos de ratón o toques táctiles)
    mask: Region {}

    // Anclado en la parte inferior central
    anchors {
        bottom: true
        left: true; right: true
    }
    
    color: "transparent"
    implicitHeight: Metrics.barHeight + 40
    exclusionMode: ExclusionMode.Ignore // HUD flotante, no desplaza ventanas del layout

    // La superficie solo se mapea en Wayland cuando está activa o durante la transición
    visible: root.osdVisible || (contentCard && contentCard.opacity > 0)
    
    property bool osdVisible: false
    property string activeIcon: ""
    property real activeValue: 0.0
    property string activeText: ""
    
    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: root.osdVisible = false
    }

    property bool isBrightness: false
    Connections {
        target: VolumeService
        function onVolumeChangedExplicitly() {
            root.isBrightness = false;
            if (VolumeService.isMuted) {
                root.activeIcon = "audio-volume-muted";
                root.activeValue = 0;
                root.activeText = "Muted";
            } else {
                root.activeIcon = VolumeService.volume > 0.6 ? "audio-volume-high" : (VolumeService.volume > 0.3 ? "audio-volume-medium" : "audio-volume-low");
                root.activeValue = VolumeService.volume;
                root.activeText = Math.round(VolumeService.volume * 100) + "%";
            }
            root.osdVisible = true;
            hideTimer.restart();
        }
        function onMicToggled() {
            root.isBrightness = false;
            root.activeIcon = VolumeService.isMicMuted ? "audio-input-microphone-muted" : "audio-input-microphone";
            root.activeValue = VolumeService.isMicMuted ? 0.0 : 1.0;
            root.activeText = VolumeService.isMicMuted ? "Mic Muted" : "Mic On";
            root.osdVisible = true;
            hideTimer.restart();
        }
    }

    Connections {
        target: BrightnessService
        function onBrightnessChangedExplicitly() {
            root.isBrightness = true;
            root.activeIcon = "display-brightness-symbolic";
            root.activeValue = BrightnessService.brightness;
            root.activeText = Math.round(BrightnessService.brightness * 100) + "%";
            root.osdVisible = true;
            hideTimer.restart();
        }
    }

    Item {
        id: contentCard
        width: 300
        height: Metrics.barHeight
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        
        // Animación de entrada/salida (como si emergiera del bisel inferior)
        anchors.bottomMargin: osdVisible ? 0 : -Metrics.barHeight
        opacity: osdVisible ? 1 : 0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Shape {
            id: bgShape
            property int trapWidth: 300
            property int sk: Metrics.centerTrapSkewBottom
            
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            // Trapecio invertido (ancho abajo, corto arriba)
            ShapePath {
                fillColor: Colors.surface
                strokeColor: "transparent"
                strokeWidth: 0
                startX: bgShape.sk; startY: 0
                PathLine { x: bgShape.trapWidth - bgShape.sk; y: 0 }
                PathLine { x: bgShape.trapWidth; y: bgShape.height }
                PathLine { x: 0; y: bgShape.height }
                PathLine { x: bgShape.sk; y: 0 }
            }
        }
        
        // Línea Neón en el borde superior (Base menor)
        Rectangle {
            width: bgShape.trapWidth - (2 * Metrics.centerTrapSkewBottom)
            height: 1
            x: Metrics.centerTrapSkewBottom
            y: 0
            color: Colors.accent
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 12
                saturation: 2.0
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 15

            Icon {
                name: root.activeIcon
                size: Metrics.iconSizeLarge
                color: Colors.text
            }

            Meter {
                Layout.fillWidth: true
                value: root.activeValue
                barHeight: 6
                barColor: Colors.accent
            }
            
            Text {
                text: root.activeText
                color: Colors.text
                font.pixelSize: Metrics.textSizeNormal
                font.family: Typography.familyMonospace
            }
        }
    }
}
