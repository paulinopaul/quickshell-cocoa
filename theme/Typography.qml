pragma Singleton
import QtQuick

QtObject {
    readonly property string family:           "sans-serif"
    readonly property string familyMonospace:  "monospace"

    readonly property int weightLight:   Font.Light
    readonly property int weightNormal:  Font.Normal
    readonly property int weightMedium:  Font.Medium
    readonly property int weightBold:    Font.Bold
}
