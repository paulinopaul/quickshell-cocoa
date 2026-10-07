# Technical Design: Cocoa Settings Dialog & Configuration Center

## 1. Architecture Overview

The Settings Dialog is structured around a decoupled, layered architecture consistent with Cocoa's design principles:

```
┌──────────────────────────────────────────────────────────────┐
│                    Hyprland Compositor                       │
│  Keybinding: SUPER+I -> global, quickshell:settings_dialog   │
└──────────────────────────────┬───────────────────────────────┘
                               │ GlobalShortcut
┌──────────────────────────────▼───────────────────────────────┐
│              ShellRoot (shell.qml)                           │
│        SettingsWindow { id: settingsDialog }                 │
└──────────────────────────────┬───────────────────────────────┘
                               │
       ┌───────────────────────┴───────────────────────┐
       ▼                                               ▼
┌─────────────────────────────┐         ┌─────────────────────────────┐
│   SettingsWindow.qml        │         │   RightPanel.qml (Bar)      │
│   - PanelWindow (Overlay)   │◄────────┤   Settings button trigger   │
│   - Backdrop click dismiss  │         └─────────────────────────────┘
│   - Sidebar Navigation Tabs │
└──────────────┬──────────────┘
               │
       ┌───────┴────────────────────────┐
       ▼                                ▼
┌───────────────────────────┐    ┌───────────────────────────┐
│  NetworkSettingsView.qml  │    │  ThemeSettingsView.qml    │
│  - NetworkService calls   │    │  - ThemeService calls     │
│  - Wi-Fi AP list & pass   │    │  - Mode: Auto vs Custom   │
│  - Disconnect / Connect   │    │  - Palette swatches & hex │
└──────────────┬────────────┘    └──────────────┬────────────┘
               │                                │
               ▼                                ▼
┌───────────────────────────┐    ┌───────────────────────────┐
│  NetworkService.qml       │    │  ThemeService.qml         │
│  scripts/wifi_manager.py  │    │  scripts/set_wallpaper.sh │
│  (scan, connect, discon)  │    │  theme/current_theme.json │
└───────────────────────────┘    └───────────────────────────┘
```

## 2. Component Specifications

### 2.1 `modules/settings/SettingsWindow.qml`
- **Class**: `PanelWindow`
- **Layer**: `WlrLayer.Overlay`
- **Namespace**: `cocoa-settings`
- **Geometry**: Center-anchored, `implicitWidth: 720`, `implicitHeight: 520`
- **Properties**:
  - `property bool isOpen: false`
  - `property bool surfaceActive: false`
  - `property string currentTab: "theme"` // "network" | "theme"
- **Kinematics**:
  - `enterAnim`: Scale from 0.92 to 1.0, opacity from 0 to 1, duration 220ms with `Easing.OutBack`.
  - `exitAnim`: Scale from 1.0 to 0.95, opacity from 1 to 0, duration 160ms with `Easing.InQuad`. On completed: `surfaceActive = false`.

### 2.2 `modules/settings/NetworkSettingsView.qml`
- Sub-component rendering the network management controls.
- Employs `NetworkService` bindings for scan results and connection feedback.
- Features:
  - Header with current network state, IP or disconnected notice.
  - Refresh button with continuous rotation animation while scanning.
  - Scrollable `ListView` of visible SSIDs with signal level and lock glyphs.
  - Expandable inline connection card when an AP is clicked:
    - Password `TextField` (masked with `*`, echoMode: Password).
    - "Conectar" button triggering `NetworkService.connectToNetwork()`.
    - Dismissable banner for errors or success notifications.
    - "Desconectar" button if active SSID is currently connected.

### 2.3 `modules/settings/ThemeSettingsView.qml`
- Sub-component rendering theme configuration.
- Features:
  - Mode Segmented Switch:
    - [ Modos: Adaptativo al Fondo | Personalizado ]
  - In Adaptive Mode:
    - Active wallpaper preview rectangle (`Image` with `source: WallpaperService.currentPath`).
    - File basename label.
    - Swatch preview of current extracted colors (`accent`, `textMuted`, `textDim`).
    - "Re-sincronizar tema" action triggering `apply_wallpaper_theme.sh`.
  - In Custom Mode:
    - Color swatch selector with 8 curated dark-mode friendly presets.
    - Hexadecimal text input (`#RRGGBB`) with regex validation.
    - Live component preview widget (shows sample action button, chip tag, active workspace dot).
    - "Guardar y Aplicar" action calling `ThemeService.applyCustomTheme(color)`.

### 2.4 Service Enhancements
1. **`NetworkService.qml`**:
   - Add `disconnectFromNetwork()` method.
   - Extend `wifi_manager.py` with `disconnect` subcommand:
     `nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1)` or `nmcli con down id <ssid>`.
2. **`ThemeService.qml`**:
   - Add `applyCustomTheme(accentHex)` method:
     Computes safe `textMuted` and `textDim` using HSL lightness math, writes to `current_theme.json`, and updates Hyprland border color via IPC.
   - Add `syncWithWallpaper()` method: invokes `scripts/apply_wallpaper_theme.sh` asynchronously.

## 3. Keyboard and Mouse Interaction
- `Escape`: Closes the settings dialog immediately.
- `Click outside` (Backdrop): Dismisses dialog.
- Focus: Sets keyboard focus to active view or password input on demand without locking out the compositor when closed.
