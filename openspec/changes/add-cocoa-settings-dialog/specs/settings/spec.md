# Specification: Cocoa Settings Dialog & Configuration Center

## 1. Overview
The Cocoa Settings Dialog provides a centralized graphical interface for configuring system and desktop shell parameters on Hyprland, specifically targeting Network and Theme settings. It functions as a floating overlay above all windows with zero disruption to active applications.

## 2. Functional Requirements

### 2.1 Window Lifecycle & Overlay Kinematics
- **FR-1.1**: The settings dialog SHALL be implemented as a Quickshell `PanelWindow` on `WlrLayer.Overlay` without lateral anchors, ensuring perfect center positioning on the primary Wayland output.
- **FR-1.2**: The window SHALL implement decoupled lifecycle management (`visible: surfaceActive` and `property bool isOpen`). On open, `surfaceActive` becomes true and `isOpen` triggers entrance animation (`Easing.OutBack`). On close, keyboard focus is immediately released, and `surfaceActive` becomes false only after the exit animation completes (`Easing.InCubic`).
- **FR-1.3**: The dialog SHALL be dismissable via:
  1. Header close button (`IconButton`).
  2. Keyboard `Escape` key.
  3. Clicking on the translucent background backdrop outside the dialog card.
- **FR-1.4**: The dialog SHALL expose a `GlobalShortcut` named `settings_dialog` allowing Hyprland compositor keybind integration (`bind = SUPER, I, global, quickshell:settings_dialog`).

### 2.2 Navigation Architecture
- **FR-2.1**: The dialog card SHALL be partitioned into a two-column layout:
  1. **Left Navigation Sidebar** (~180px width) containing navigation tabs:
     - 🌐 **Red** (`network-wireless` icon)
     - 🎨 **Tema** (`color-management` or `preferences-desktop-theme` icon)
  2. **Right Content Area** containing the active view.
- **FR-2.2**: Active navigation tab SHALL highlight with `Colors.accent` and have smooth hover states (`Colors.surfaceHover`).

### 2.3 Network Configuration View (`NetworkSettingsView.qml`)
- **FR-3.1**: Display current network state:
  - If connected to Wi-Fi: display SSID, signal strength, and IP status.
  - If connected to Ethernet: display "Conexión Cableada (LAN)".
  - If disconnected: display "Sin conexión a la red".
- **FR-3.2**: Provide a manual "Escanear Redes" button with an animated rotation while `NetworkService.isScanning` is true.
- **FR-3.3**: Display a scrollable list of available Wi-Fi access points:
  - Access point name (SSID).
  - Security indicator (lock icon if secured, none if open).
  - Signal strength metric (visual indicator).
  - "Conectar" or "Conectado" state.
- **FR-3.4**: When selecting a secured network, show an inline password field with "Conectar" and "Cancelar" actions.
- **FR-3.5**: Display connection progress spinner and distinct banner messages for success and error.
- **FR-3.6**: Provide a "Desconectar" button when actively connected to a network.

### 2.4 Theme & Appearance Configuration View (`ThemeSettingsView.qml`)
- **FR-4.1**: Provide a Theme Mode Selector:
  - **Modo Adaptativo (Fondo de Pantalla)**: Colors automatically extract from the current wallpaper.
  - **Modo Personalizado**: User defines an accent color that overrides automatic extraction.
- **FR-4.2**: In Adaptive Mode:
  - Show the path and thumbnail preview of the currently loaded wallpaper (`WallpaperService.currentPath`).
  - Display extracted color tokens: Primary Accent, Text Muted, Text Dim.
  - Provide a "Re-sincronizar con fondo" button that invokes `apply_wallpaper_theme.sh` asynchronously.
- **FR-4.3**: In Custom Mode:
  - Display a grid of curated preset color swatches:
    - Cocoa Gold (`#d4af37`)
    - Cyber Cyan (`#38bdf8`)
    - Emerald Green (`#10b981`)
    - Rose Quartz (`#f43f5e`)
    - Sunset Amber (`#f59e0b`)
    - Neon Violet (`#8b5cf6`)
    - Electric Indigo (`#6366f1`)
    - Glacier Slate (`#94a3b8`)
  - Provide a Hex code input field allowing arbitrary `#RRGGBB` colors.
  - Applying a custom accent color writes directly to `current_theme.json` and invokes `hyprctl keyword general:col.active_border` to keep the compositor border in sync.
- **FR-4.4**: Display a live UI preview card showing how the selected theme accent renders on Cocoa UI components (buttons, badges, highlights).

## 3. Non-Functional Requirements
- **NFR-1**: Responsive, 60fps animations with zero UI thread blocking.
- **NFR-2**: Direct process execution without uncontrolled subshell spawns.
- **NFR-3**: Persistence: custom theme choices persist in `current_theme.json` across shell restarts.
- **NFR-4**: Consistent aesthetic matching Cocoa's dark minimalist design language (`#0a0a0a` solid panels, subtle 1px border `surfaceRaised`, dynamic accents).
