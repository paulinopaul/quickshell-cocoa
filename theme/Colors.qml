// Paleta Cocoa: Sistema de colores dinámicos unificado.
// Superficies (islas/paneles), bordes, textos y acentos se sincronizan reactivamente
// con el tema seleccionado o el fondo de pantalla en ejecución.

import QtQuick
pragma Singleton

QtObject {
    // ── SUPERFICIES Y FONDOS DINÁMICOS ──────────────────────────────────────────
    // Se adaptan dinámicamente según el tema seleccionado o el wallpaper
    property color background: '#0e1017'
    property color surface: '#161922'
    property color surfaceDark: '#10121a'
    property color surfaceRaised: '#1f2430'
    property color surfaceHover: '#2a3142'
    property color surfaceBorder: '#323a4e'

    // ── TEXTO E ICONOS — DINÁMICOS ──────────────────────────────────────────────
    property color text: "#ffffff"
    property color textMuted: "#b8c0d0"
    property color textDim: "#657088"
    property color accent: "#88c0d0"

    // ── ESTADO FUNCIONAL ────────────────────────────────────────────────────────
    property color stateOk: "#7ab87a"
    property color stateWarn: "#c8a864"
    property color stateError: "#c87070"
}
