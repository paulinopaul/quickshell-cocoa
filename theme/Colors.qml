// Paleta Cocoa: dos secciones claramente separadas.
//  FIJO     → readonly. Los paneles nunca cambian de color.
//  DINÁMICO → writable.  ThemeService los actualiza según el wallpaper.
// El sistema de theming SOLO modifica text / textMuted / textDim / accent.
// Las superficies (surface, surfaceRaised, surfaceHover) son invariantes.

import QtQuick
pragma Singleton

QtObject {
    // ── SUPERFICIES — NUNCA CAMBIAN ──────────────────────────────────────────
    readonly property color background: '#0a0a0a'
    readonly property color surface: '#0a0a0a' // Color del panel — fijo
    readonly property color surfaceRaised: '#0a0a0a'
    readonly property color surfaceHover: '#0a0a0a'
    // ── TEXTO E ICONOS — DINÁMICOS (ThemeService los actualiza) ──────────────
    // Valores por defecto: blanco neutro (funciona sobre cualquier wallpaper oscuro/claro).
    property color text: "#ffffff"
    property color textMuted: "#b8b8b8"
    property color textDim: "#606060"
    property color accent: "#d0d0d0"
    // ── ESTADO FUNCIONAL — SEMI-DINÁMICO ─────────────────────────────────────
    // Derivados del accent cuando ThemeService los calcula, o fijos si no.
    property color stateOk: "#7ab87a"
    property color stateWarn: "#c8a864"
    property color stateError: "#c87070"
}
