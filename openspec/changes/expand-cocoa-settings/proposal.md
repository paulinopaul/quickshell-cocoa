# Change Proposal: Comprehensive Cocoa Settings Expansion & Wallpaper-Theme Binding

## Why
Cocoa Desktop Shell previously offered foundational settings for Network and Theme customization. Power users in Wayland/Hyprland need a centralized, elevated configuration hub to control hardware devices (PipeWire audio sinks and sources, display resolutions and scaling), default application associations, and a searchable keybindings viewer without needing terminal or manual dotfile editing. Furthermore, system colors must support both global named palettes (e.g., NeoNord, Catppuccin, Tokyo Night) and contextual wallpaper-theme bindings (associating a wallpaper with a specific palette, or extracting colors on the fly) so changing wallpapers automatically synchronizes all system accents.

## What Changes
1. **Wallpaper-Theme Engine (`theme_manager.py`)**:
   - Curated global palettes: NeoNord, Catppuccin Mocha, Tokyo Night, Gruvbox Retro, Rose Pine, Cyberpunk Neon, Emerald Forest, Sunset Glow, Cocoa Classic.
   - Persistent mapping storage in `theme/wallpaper_themes.json`.
   - Dynamic extraction fallback with KMeans/quantization when no mapping exists.
   - Integration with `scripts/set_wallpaper.sh` to trigger `theme_manager.py apply-for-wallpaper "$WALL"` on wallpaper switches.
   - Active Hyprland border color synchronization.
2. **Audio Management (`audio_manager.py`, `AudioSettingsView.qml`)**:
   - PipeWire `wpctl` inspection for audio sinks (output) and sources (input).
   - Real-time default device selection, volume adjustment, and mute toggles.
3. **Display Management (`display_manager.py`, `DisplaySettingsView.qml`)**:
   - Real-time `hyprctl monitors -j` parsing for resolutions, refresh rates, and scaling factors.
   - Non-blocking live application via `hyprctl keyword monitor` and persistent writing to `~/.config/hypr/hyprland.conf`.
4. **Default Applications (`default_apps_manager.py`, `DefaultAppsView.qml`)**:
   - Terminal emulator selector ($terminal variable in `hyprland.conf`).
   - XDG default applications configuration (`xdg-mime default`) for web browsers, file managers, and code editors.
5. **Keybindings Viewer (`keybinds_manager.py`, `KeybindsView.qml`)**:
   - Active Hyprland bindings parser via `hyprctl binds -j`.
   - Modmask decoding (SUPER, SHIFT, CTRL, ALT) and fuzzy search filtering by description, key combo, or dispatcher.
6. **Unified Settings Dialog (`SettingsWindow.qml`)**:
   - Tab navigation for: Tema, Red, Audio, Pantalla, Aplicaciones, Atajos.

## Verification
- Comprehensive automated Python unit and contract tests in `tests/test_settings_contract.py`.
- QML linting via `qmllint`.
- Wayland live reload and IPC shortcut triggering (`hyprctl dispatch global quickshell:settings_dialog`).
