"""Contract tests for Cocoa's central UI configuration service (UiConfigService).

Enforces:
1. UiConfigService is registered as a singleton in services/qmldir so that every
   QML consumer (bar panels, flyout, settings views) resolves it at runtime.
2. The right panel widget toggles (showBrightness, showSettings, showPower) are
   declared in the service, persisted in ui_config.json, and consumed by
   RightPanel.qml, replacing the dead showClock key.
3. CenterCapsule.qml gates the album-art neon flow on centerCapsule.showMedia.
4. CenterFlyout.qml inherits the center capsule background opacity and border width.
5. PanelsSettingsView.qml exposes the three new right-panel toggles.
6. visual_config_manager.py still handles get, set-hyprland, set-ghostty, set-panel.
"""

import json
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SERVICES_QMLDIR = PROJECT_ROOT / "services" / "qmldir"
UI_CONFIG_SERVICE_PATH = PROJECT_ROOT / "services" / "UiConfigService.qml"
CENTER_CAPSULE_PATH = PROJECT_ROOT / "modules" / "bar" / "CenterCapsule.qml"
RIGHT_PANEL_PATH = PROJECT_ROOT / "modules" / "bar" / "RightPanel.qml"
CENTER_FLYOUT_PATH = PROJECT_ROOT / "modules" / "bar" / "CenterFlyout.qml"
PANELS_SETTINGS_VIEW_PATH = PROJECT_ROOT / "modules" / "settings" / "PanelsSettingsView.qml"
UI_CONFIG_PATH = PROJECT_ROOT / "theme" / "ui_config.json"
VISUAL_CONFIG_MANAGER_PATH = PROJECT_ROOT / "scripts" / "visual_config_manager.py"


class TestUiConfigServiceContract(unittest.TestCase):
    """Structural contract validation for UiConfigService registration and consumers."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.qmldir = SERVICES_QMLDIR.read_text(encoding="utf-8")
        cls.service = UI_CONFIG_SERVICE_PATH.read_text(encoding="utf-8")
        cls.capsule = CENTER_CAPSULE_PATH.read_text(encoding="utf-8")
        cls.right_panel = RIGHT_PANEL_PATH.read_text(encoding="utf-8")
        cls.flyout = CENTER_FLYOUT_PATH.read_text(encoding="utf-8")
        cls.panels_view = PANELS_SETTINGS_VIEW_PATH.read_text(encoding="utf-8")
        cls.ui_config = json.loads(UI_CONFIG_PATH.read_text(encoding="utf-8"))
        cls.manager = VISUAL_CONFIG_MANAGER_PATH.read_text(encoding="utf-8")

    def test_qmldir_registers_ui_config_service(self) -> None:
        """services/qmldir must register UiConfigService as a singleton type."""
        self.assertIn("UiConfigService", self.qmldir)
        self.assertIn("singleton UiConfigService", self.qmldir)

    def test_service_declares_right_panel_toggles_without_show_clock(self) -> None:
        """UiConfigService must declare the three right panel toggles and drop showClock."""
        self.assertIn('"showBrightness": true', self.service)
        self.assertIn('"showSettings": true', self.service)
        self.assertIn('"showPower": true', self.service)
        self.assertNotIn("showClock", self.service)

    def test_service_exposes_configuration_methods(self) -> None:
        """UiConfigService must expose its public mutation API."""
        self.assertIn("function saveHyprland", self.service)
        self.assertIn("function saveGhostty", self.service)
        self.assertIn("function setPanelProperty", self.service)
        self.assertIn("function togglePanelProperty", self.service)

    def test_center_capsule_gates_album_art_on_show_media(self) -> None:
        """CenterCapsule must gate the album-art neon source on centerCapsule.showMedia."""
        self.assertIn("centerCapsule.showMedia", self.capsule)

    def test_right_panel_consumes_new_toggles(self) -> None:
        """RightPanel must consume each new toggle via the !== false pattern."""
        for key in ("showBrightness", "showSettings", "showPower"):
            self.assertIn(
                f"rightPanel.{key} !== false",
                self.right_panel,
                f"Missing {key} consumption in RightPanel.qml",
            )

    def test_center_flyout_inherits_capsule_background_and_border(self) -> None:
        """CenterFlyout must inherit the center capsule bgOpacity and borderWidth."""
        self.assertIn("centerCapsule.bgOpacity", self.flyout)
        self.assertIn("centerCapsule.borderWidth", self.flyout)

    def test_panels_settings_view_exposes_new_toggles(self) -> None:
        """PanelsSettingsView must expose toggles for the three new right panel keys."""
        for key in ("showBrightness", "showSettings", "showPower"):
            self.assertIn(
                f'togglePanelProperty("right", "{key}")',
                self.panels_view,
                f"Missing toggle for {key} in PanelsSettingsView.qml",
            )

    def test_ui_config_json_right_panel_has_new_keys(self) -> None:
        """ui_config.json panels.right must carry the three keys and no showClock."""
        right = self.ui_config["panels"]["right"]
        for key in ("showBrightness", "showSettings", "showPower"):
            self.assertTrue(right[key], f"panels.right.{key} must default to true")
        self.assertNotIn("showClock", right)

    def test_visual_config_manager_cli_commands(self) -> None:
        """visual_config_manager.py must still handle the CLI subcommands."""
        for cmd in ("get", "set-hyprland", "set-ghostty", "set-panel"):
            self.assertIn(
                f'"{cmd}"',
                self.manager,
                f"visual_config_manager.py must handle {cmd}",
            )


if __name__ == "__main__":
    unittest.main()