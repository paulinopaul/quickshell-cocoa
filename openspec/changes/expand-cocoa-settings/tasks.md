# Implementation Tasks: Extended Settings Dialog & Theming

- [x] 1. Backend Scripts
  - [x] 1.1 Implement `scripts/theme_manager.py` with 9 named presets, wallpaper binding database (`theme/wallpaper_themes.json`), and Hyprland border sync.
  - [x] 1.2 Implement `scripts/audio_manager.py` for PipeWire sink and source discovery, default switching, and volume/mute control.
  - [x] 1.3 Implement `scripts/display_manager.py` for reading monitors and applying modes via `hyprctl keyword monitor`.
  - [x] 1.4 Implement `scripts/default_apps_manager.py` for terminal and xdg-mime configuration.
  - [x] 1.5 Implement `scripts/keybinds_manager.py` for decoding and annotating Hyprland shortcuts.
  - [x] 1.6 Update `scripts/set_wallpaper.sh` to trigger `theme_manager.py apply-for-wallpaper`.

- [x] 2. QML Frontend Modules
  - [x] 2.1 Update `services/ThemeService.qml` with wallpaper binding methods.
  - [x] 2.2 Implement `modules/settings/ThemeSettingsView.qml` with named palette cards and wallpaper binding action.
  - [x] 2.3 Implement `modules/settings/AudioSettingsView.qml` with PipeWire sink/source cards.
  - [x] 2.4 Implement `modules/settings/DisplaySettingsView.qml` with resolution, refresh rate, and scale selectors.
  - [x] 2.5 Implement `modules/settings/DefaultAppsView.qml` with detected application selectors.
  - [x] 2.6 Implement `modules/settings/KeybindsView.qml` with searchable shortcut cards.
  - [x] 2.7 Update `modules/settings/SettingsWindow.qml` with 6 navigation tabs.
  - [x] 2.8 Update `modules/settings/qmldir` to export all settings components.

- [x] 3. Verification & Testing
  - [x] 3.1 Unit and contract test suite in `tests/test_settings_contract.py` (154 tests passing).
  - [x] 3.2 QML linting via `qmllint` (0 errors).
  - [x] 3.3 Live compositor runtime test via `hyprctl dispatch global quickshell:settings_dialog`.
