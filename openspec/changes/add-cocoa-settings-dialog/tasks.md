# Tasks: Cocoa Settings Dialog Implementation

## Work Units

### Unit 1: Backend Services & Helper Scripts
- [x] 1.1 Extend `scripts/wifi_manager.py` with a `disconnect` subcommand via `nmcli`.
- [x] 1.2 Extend `services/NetworkService.qml` with `disconnectNetwork()` method and Process runner.
- [x] 1.3 Create `scripts/apply_custom_theme.py` (or `.sh`) to calculate harmonious tokens (`textMuted`, `textDim`), write `current_theme.json`, and update Hyprland active border via `hyprctl`.
- [x] 1.4 Extend `services/ThemeService.qml` with `applyCustomTheme(accentHex)` and `syncWithWallpaper()`.

### Unit 2: Settings UI Components (`modules/settings/`)
- [x] 2.1 Create `modules/settings/qmldir` declaring exported types.
- [x] 2.2 Implement `modules/settings/SettingsTabButton.qml` for category navigation with active accent indicators and hover animations.
- [x] 2.3 Implement `modules/settings/NetworkSettingsView.qml` with connection card, live scanner, scrollable Wi-Fi list, inline password prompt, and disconnect option.
- [x] 2.4 Implement `modules/settings/ThemeSettingsView.qml` with Mode Switcher (Adaptive vs Custom), wallpaper thumbnail preview, curated color swatches, hex input field, and live component preview.
- [x] 2.5 Implement `modules/settings/SettingsWindow.qml` with `PanelWindow`, `WlrLayer.Overlay`, centered layout, backdrop dismissal, `GlobalShortcut`, and enter/exit animations.

### Unit 3: Shell & Compositor Integration
- [x] 3.1 Register `SettingsWindow` in `shell.qml` under `ShellRoot`.
- [x] 3.2 Add settings launcher icon in Cocoa Bar (`modules/bar/RightPanel.qml`).
- [x] 3.3 Add `bind = SUPER, I, global, quickshell:settings_dialog` in `hyprland.conf`.

### Unit 4: Contract Testing & Verification
- [x] 4.1 Implement `tests/test_settings_contract.py` validating QML property contracts, syntax integrity, and backend script operations.
- [x] 4.2 Run complete test suite (`python3 -m unittest discover tests`) ensuring zero regressions across all tests.

### Unit 5: Documentation & OpenSpec Verification
- [ ] 5.1 Document the new Settings Dialog in Cocoa `README.md`.
- [ ] 5.2 Generate `openspec/changes/add-cocoa-settings-dialog/verify-report.md`.
- [ ] 5.3 Update planning files (`task_plan.md`, `findings.md`, `progress.md`).
