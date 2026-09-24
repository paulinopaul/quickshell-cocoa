import QtQuick
pragma Singleton

QtObject {
    // Alto de paneles laterales (más delgados)
    // Diagonal en esquina interior-baja
    // Diagonal de las esquinas inferiores

    // ── Sistema de barra ─────────────────────────────────────────────────────
    // El barHeight es la altura del panel CENTRAL (el más alto).
    // Los paneles laterales son más delgados (sideHeight < barHeight).
    readonly property int barHeight: 30
    // Alto del panel central (toca el borde)
    readonly property int sideHeight: 20
    // ── Geometría trapezoidal ─────────────────────────────────────────────────
    // sideTrapSkew: px que se recorta en la esquina inferior-interna del panel lateral.
    // Solo afecta UNA esquina (la que da al centro), no toda la cara.
    readonly property int sideTrapSkew: 15
    // centerTrapSkewBottom: px que se estrecha la cápsula central en cada lado de la base.
    readonly property int centerTrapSkewBottom: 15
    // ── Espaciado de exclusiveZone ───────────────────────────────────────────
    // La exclusiveZone reserva espacio = barHeight (el panel más alto define el espacio).
    readonly property int exclusiveZone: barHeight
    // ── Animaciones ──────────────────────────────────────────────────────────
    readonly property int animFast: 110
    readonly property int animNormal: 200
    // ── Tipografía ───────────────────────────────────────────────────────────
    readonly property int textSizeSmall: 10
    readonly property int textSizeNormal: 11
    readonly property int textSizeMedium: 12
    // ── Iconos ───────────────────────────────────────────────────────────────
    readonly property int iconSizeSmall: 11
    readonly property int iconSizeMedium: 13
    readonly property int iconSizeLarge: 16
    // ── Padding interno ──────────────────────────────────────────────────────
    readonly property int innerPadH: 12
    // Horizontal
    readonly property int innerPadV: 4
    // Vertical
    readonly property int itemSpacing: 7
}
