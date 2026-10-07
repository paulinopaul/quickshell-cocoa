# Proposal: Cocoa Standalone Settings Dialog

## Objective
Introduce a dedicated, elevated standalone settings dialog (`SettingsWindow.qml`) for the Cocoa desktop shell running on Hyprland (Quickshell Qt6/QML). The dialog enables immediate, GUI-driven configuration of system and shell preferences—specifically Network and Theming—without requiring terminal commands or manual text editor edits.

## Context & Motivation
Currently, configuring Cocoa and Hyprland aesthetics or network connections requires external tools or terminal invocations:
- Wi-Fi networks must be managed via the right-panel flyout or raw `nmcli`.
- Theming is either tied strictly to the wallpaper extractor or requires manual modifications to `current_theme.json` and `theme.conf`.
- There is no central, elevated dialog where users can toggle between wallpaper-adaptive dynamic theming and custom accent colors, inspect network states, or configure shell behavior in a single unified view.

## Scope
1. **Window Architecture & Kinematics**:
   - Standalone overlay dialog (`PanelWindow` using `WlrLayer.Overlay`) centered on screen.
   - Smooth entrance and exit animations with deferred Wayland unmapping (`surfaceActive` pattern).
   - Dismissal via `Escape` key, header close button, or clicking outside (backdrop).
   - Global shortcut registration (`quickshell:settings_dialog`) and Hyprland keybinding (`SUPER, I`).
   - Integrated launch button or trigger in Cocoa Bar.

2. **Network Settings Module (`NetworkSettingsView.qml`)**:
   - Real-time connection status (Ethernet / Wi-Fi SSID / Disconnected).
   - Interactive Wi-Fi scanner with live signal strength and security indicators.
   - Direct connection flow with password prompt and error/success messaging.
   - Disconnect / reconnect actions.

3. **Theme Settings Module (`ThemeSettingsView.qml`)**:
   - Dual-mode theming architecture:
     - **Adaptive Mode (Wallpaper)**: Dynamically extracts palette from active wallpaper via `extract_colors.py` and `apply_wallpaper_theme.sh`. Displays active wallpaper thumbnail and extracted color tokens (`accent`, `textMuted`, `textDim`).
     - **Custom Mode (Manual Accent)**: Curated palette of elegant accent colors (Amber, Cyan, Emerald, Rose, Sunset, Violet, Monochrome) plus custom hex input. Immediately persists to `current_theme.json` and synchronizes Hyprland borders.
   - Instant live preview card showing UI components styled with the chosen accent.

4. **Verification & Testing**:
   - Python unit tests and contract validation tests covering QML interfaces, properties, and backend scripts.
   - Documentation in Cocoa `README.md` and planning files.
