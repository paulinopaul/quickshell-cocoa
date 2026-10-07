"""Contract tests for Cocoa Settings Dialog (modules/settings/SettingsWindow.qml).

Enforces:
1. Centered layer-shell overlay (WlrLayer.Overlay, no lateral anchors).
2. Explicit bounded dimensions (implicitWidth, implicitHeight).
3. Decoupled surface lifecycle (visible: surfaceActive, enterAnim, exitAnim).
4. Global shortcut integration (GlobalShortcut "settings_dialog").
5. Instantiation in shell.qml root tree.
6. Expanded settings views: Theme, Visual, Panels, Network, Audio, Display, Default Apps, Keybinds, Hyprland.
7. Backend engine contracts: theme_manager, audio_manager, display_manager, default_apps_manager, keybinds_manager, hyprland_config_manager.
"""

import json
import os
import re
import unittest
from pathlib import Path

from scripts.apply_custom_theme import derive_palette_from_accent, parse_hex_color
from scripts.audio_manager import parse_wpctl_status
from scripts.keybinds_manager import categorize_bind, modmask_to_string
from scripts.theme_manager import NAMED_PRESETS, get_all_themes

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SETTINGS_WINDOW_PATH = PROJECT_ROOT / "modules/settings/SettingsWindow.qml"
SETTINGS_TAB_PATH = PROJECT_ROOT / "modules/settings/SettingsTabButton.qml"
NETWORK_VIEW_PATH = PROJECT_ROOT / "modules/settings/NetworkSettingsView.qml"
THEME_VIEW_PATH = PROJECT_ROOT / "modules/settings/ThemeSettingsView.qml"
AUDIO_VIEW_PATH = PROJECT_ROOT / "modules/settings/AudioSettingsView.qml"
DISPLAY_VIEW_PATH = PROJECT_ROOT / "modules/settings/DisplaySettingsView.qml"
APPS_VIEW_PATH = PROJECT_ROOT / "modules/settings/DefaultAppsView.qml"
KEYBINDS_VIEW_PATH = PROJECT_ROOT / "modules/settings/KeybindsView.qml"
HYPRLAND_VIEW_PATH = PROJECT_ROOT / "modules/settings/HyprlandConfigView.qml"
VISUAL_VIEW_PATH = PROJECT_ROOT / "modules/settings/VisualSettingsView.qml"
PANELS_VIEW_PATH = PROJECT_ROOT / "modules/settings/PanelsSettingsView.qml"

# All nine settings views that share the compact skeleton metrics.
SETTINGS_VIEW_PATHS = [
    THEME_VIEW_PATH,
    VISUAL_VIEW_PATH,
    PANELS_VIEW_PATH,
    NETWORK_VIEW_PATH,
    AUDIO_VIEW_PATH,
    DISPLAY_VIEW_PATH,
    APPS_VIEW_PATH,
    KEYBINDS_VIEW_PATH,
    HYPRLAND_VIEW_PATH,
]
QMLDIR_PATH = PROJECT_ROOT / "modules/settings/qmldir"
SHELL_PATH = PROJECT_ROOT / "shell.qml"
RIGHT_PANEL_PATH = PROJECT_ROOT / "modules/bar/RightPanel.qml"


class TestSettingsContract(unittest.TestCase):
    """Structural and behavioral contract validation for Cocoa Settings Dialog."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.assertTrue(SETTINGS_WINDOW_PATH.exists(), f"Missing {SETTINGS_WINDOW_PATH}")
        cls.assertTrue(SETTINGS_TAB_PATH.exists(), f"Missing {SETTINGS_TAB_PATH}")
        cls.assertTrue(NETWORK_VIEW_PATH.exists(), f"Missing {NETWORK_VIEW_PATH}")
        cls.assertTrue(THEME_VIEW_PATH.exists(), f"Missing {THEME_VIEW_PATH}")
        cls.assertTrue(AUDIO_VIEW_PATH.exists(), f"Missing {AUDIO_VIEW_PATH}")
        cls.assertTrue(DISPLAY_VIEW_PATH.exists(), f"Missing {DISPLAY_VIEW_PATH}")
        cls.assertTrue(APPS_VIEW_PATH.exists(), f"Missing {APPS_VIEW_PATH}")
        cls.assertTrue(KEYBINDS_VIEW_PATH.exists(), f"Missing {KEYBINDS_VIEW_PATH}")
        cls.assertTrue(HYPRLAND_VIEW_PATH.exists(), f"Missing {HYPRLAND_VIEW_PATH}")
        cls.assertTrue(VISUAL_VIEW_PATH.exists(), f"Missing {VISUAL_VIEW_PATH}")
        cls.assertTrue(PANELS_VIEW_PATH.exists(), f"Missing {PANELS_VIEW_PATH}")

        cls.settings_window = SETTINGS_WINDOW_PATH.read_text(encoding="utf-8")
        cls.settings_tab = SETTINGS_TAB_PATH.read_text(encoding="utf-8")
        cls.network_view = NETWORK_VIEW_PATH.read_text(encoding="utf-8")
        cls.theme_view = THEME_VIEW_PATH.read_text(encoding="utf-8")
        cls.audio_view = AUDIO_VIEW_PATH.read_text(encoding="utf-8")
        cls.display_view = DISPLAY_VIEW_PATH.read_text(encoding="utf-8")
        cls.apps_view = APPS_VIEW_PATH.read_text(encoding="utf-8")
        cls.keybinds_view = KEYBINDS_VIEW_PATH.read_text(encoding="utf-8")
        cls.hyprland_view = HYPRLAND_VIEW_PATH.read_text(encoding="utf-8")
        cls.qmldir = QMLDIR_PATH.read_text(encoding="utf-8")
        cls.shell_content = SHELL_PATH.read_text(encoding="utf-8")
        cls.right_panel = RIGHT_PANEL_PATH.read_text(encoding="utf-8")

    def test_layer_shell_overlay_and_no_screen_anchors(self) -> None:
        """Settings window must sit on WlrLayer.Overlay and center without screen edge anchors."""
        self.assertIn("WlrLayershell.layer: WlrLayer.Overlay", self.settings_window)
        self.assertIn('WlrLayershell.namespace: "cocoa-settings"', self.settings_window)
        self.assertFalse(
            re.search(r"anchors\s*\{[^}]*(top|bottom|left|right):\s*true", self.settings_window),
            "SettingsWindow must remain unanchored to center automatically on Wayland",
        )

    def test_explicit_surface_dimensions(self) -> None:
        """Settings dialog must declare bounded dimensions."""
        self.assertTrue(re.search(r"implicitWidth:\s*\d+", self.settings_window))
        self.assertTrue(re.search(r"implicitHeight:\s*\d+", self.settings_window))

    def test_settings_window_enlarged_geometry(self) -> None:
        """Settings dialog must expose the enlarged 1000x700 viewport."""
        self.assertRegex(self.settings_window, r"implicitWidth:\s*1000\b")
        self.assertRegex(self.settings_window, r"implicitHeight:\s*700\b")

    def test_all_views_share_compact_margins(self) -> None:
        """Every settings view must use the shared compact outer margin (14)."""
        for path in SETTINGS_VIEW_PATHS:
            content = path.read_text(encoding="utf-8")
            self.assertIn(
                "anchors.margins: 14",
                content,
                f"{path.name} must use the shared outer margin of 14",
            )
            self.assertNotIn(
                "anchors.margins: 20",
                content,
                f"{path.name} must not keep the old cramped outer margin of 20",
            )

    def test_keybinds_add_form_is_collapsible(self) -> None:
        """KeybindsView must expose a collapsible add-bind form, collapsed by default."""
        self.assertIn("property bool addFormExpanded: false", self.keybinds_view)
        self.assertIn("visible: root.addFormExpanded", self.keybinds_view)
        self.assertIn("root.addFormExpanded = !root.addFormExpanded", self.keybinds_view)

    def test_decoupled_surface_lifecycle(self) -> None:
        """Visibility must depend on surfaceActive to allow smooth exit kinematics."""
        self.assertIn("visible: surfaceActive", self.settings_window)
        self.assertIn("property bool isOpen: false", self.settings_window)
        self.assertIn("property bool surfaceActive: false", self.settings_window)
        self.assertIn("enterAnim", self.settings_window)
        self.assertIn("exitAnim", self.settings_window)

    def test_global_shortcut_and_escape_dismiss(self) -> None:
        """Settings window must declare GlobalShortcut settings_dialog and handle Escape key."""
        self.assertIn('name: "settings_dialog"', self.settings_window)
        self.assertIn("Keys.onEscapePressed", self.settings_window)

    def test_shell_root_integration(self) -> None:
        """SettingsWindow must be imported and instantiated in shell.qml."""
        self.assertIn('import "modules/settings"', self.shell_content)
        self.assertIn("SettingsWindow {", self.shell_content)
        self.assertIn("toggleSettings()", self.shell_content)

    def test_right_panel_trigger(self) -> None:
        """RightPanel must expose settingsRequested signal and settings icon button."""
        self.assertIn("signal settingsRequested()", self.right_panel)
        self.assertIn("root.settingsRequested()", self.right_panel)
        self.assertIn('"preferences-system"', self.right_panel)

    def test_qmldir_exports_all_views(self) -> None:
        """qmldir must register all 11 settings items."""
        expected = [
            "SettingsWindow",
            "SettingsTabButton",
            "NetworkSettingsView",
            "ThemeSettingsView",
            "AudioSettingsView",
            "DisplaySettingsView",
            "DefaultAppsView",
            "KeybindsView",
            "VisualSettingsView",
            "PanelsSettingsView",
            "HyprlandConfigView",
        ]
        for item in expected:
            self.assertIn(item, self.qmldir, f"Missing export for {item} in qmldir")

    def test_nine_navigation_tabs_in_window(self) -> None:
        """SettingsWindow must contain all 9 navigation tabs."""
        tabs = ['tabId: "theme"', 'tabId: "visual"', 'tabId: "panels"', 'tabId: "network"', 'tabId: "audio"', 'tabId: "display"', 'tabId: "apps"', 'tabId: "keybinds"', 'tabId: "hyprland"']
        for tab in tabs:
            self.assertIn(tab, self.settings_window, f"Missing tab {tab}")

    def test_theme_view_named_palettes_and_bindings(self) -> None:
        """ThemeSettingsView must support named palettes and wallpaper binding actions."""
        self.assertIn("NeoNord", self.theme_view)
        self.assertIn("Catppuccin Mocha", self.theme_view)
        self.assertIn("ThemeService.bindWallpaper", self.theme_view)
        self.assertIn("ThemeService.createThemeFromWallpaper", self.theme_view)
        self.assertIn("ThemeService.applyNamedTheme", self.theme_view)

    def test_audio_view_contracts(self) -> None:
        """AudioSettingsView must bind to audio_manager.py and handle sinks and sources."""
        self.assertIn("audio_manager.py", self.audio_view)
        self.assertIn("setDefaultDevice", self.audio_view)
        self.assertIn("toggleDeviceMute", self.audio_view)

    def test_display_view_contracts(self) -> None:
        """DisplaySettingsView must bind to display_manager.py and allow resolution apply."""
        self.assertIn("display_manager.py", self.display_view)
        self.assertIn("applyConfig", self.display_view)

    def test_default_apps_contracts(self) -> None:
        """DefaultAppsView must bind to default_apps_manager.py."""
        self.assertIn("default_apps_manager.py", self.apps_view)
        self.assertIn("setDefault", self.apps_view)

    def test_keybinds_contracts(self) -> None:
        """KeybindsView must bind to keybinds_manager.py with live search."""
        self.assertIn("keybinds_manager.py", self.keybinds_view)
        self.assertIn("filteredBinds", self.keybinds_view)

    def test_audio_manager_parser(self) -> None:
        """audio_manager must accurately parse wpctl status output."""
        sample_output = """
Audio
 ├─ Devices:
 │      48. Controller [alsa]
 ├─ Sinks:
 │  *   58. Headset Output   [vol: 0.75]
 │      60. Speakers         [vol: 0.50 MUTED]
 ├─ Sources:
 │  *   59. Internal Mic     [vol: 0.60]
"""
        parsed = parse_wpctl_status(sample_output)
        self.assertEqual(len(parsed["sinks"]), 2)
        self.assertEqual(len(parsed["sources"]), 1)
        self.assertTrue(parsed["sinks"][0]["isDefault"])
        self.assertEqual(parsed["sinks"][0]["volume"], 0.75)
        self.assertTrue(parsed["sinks"][1]["isMuted"])
        self.assertEqual(parsed["sources"][0]["id"], 59)

    def test_keybinds_modifiers_and_categorization(self) -> None:
        """keybinds_manager must format bitmasks and categorize actions."""
        self.assertEqual(modmask_to_string(64), "SUPER")
        self.assertEqual(modmask_to_string(65), "SUPER + SHIFT")
        self.assertEqual(modmask_to_string(68), "SUPER + CTRL")

        cat_term = categorize_bind("exec", "ghostty", "Q")
        self.assertEqual(cat_term, "Lanzadores y Aplicaciones")

        cat_ws = categorize_bind("workspace", "1", "1")
        self.assertEqual(cat_ws, "Navegación de Escritorios")

        cat_win = categorize_bind("killactive", "", "C")
        self.assertEqual(cat_win, "Gestión de Ventanas")

    def test_theme_manager_named_presets(self) -> None:
        """theme_manager must provide core palettes including NeoNord and Catppuccin."""
        themes = get_all_themes()
        self.assertIn("NeoNord", themes)
        self.assertIn("Catppuccin Mocha", themes)
        self.assertIn("Tokyo Night", themes)
        self.assertEqual(themes["NeoNord"]["accent"], "#88c0d0")


if __name__ == "__main__":
    unittest.main()
