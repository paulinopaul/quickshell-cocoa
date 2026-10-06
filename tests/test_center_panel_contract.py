#!/usr/bin/env python3
"""
Contract tests for Cocoa Shell's Central Capsule, Detached Center Flyout,
and Right Panel Wi-Fi Management.
"""

import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CENTER_CAPSULE_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "CenterCapsule.qml")
CENTER_FLYOUT_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "CenterFlyout.qml")
BAR_WINDOW_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "BarWindow.qml")
RIGHT_PANEL_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "RightPanel.qml")
NETWORK_SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "NetworkService.qml")
SYSTEM_SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "SystemService.qml")


class TestCenterPanelContract(unittest.TestCase):
    """Verifies that coupled center capsule, detached flyout, and network contracts hold."""

    @classmethod
    def setUpClass(cls):
        with open(CENTER_CAPSULE_PATH, "r", encoding="utf-8") as f:
            cls.capsule_content = f.read()
        with open(CENTER_FLYOUT_PATH, "r", encoding="utf-8") as f:
            cls.flyout_content = f.read()
        with open(BAR_WINDOW_PATH, "r", encoding="utf-8") as f:
            cls.bar_content = f.read()
        with open(RIGHT_PANEL_PATH, "r", encoding="utf-8") as f:
            cls.right_panel_content = f.read()
        with open(NETWORK_SERVICE_PATH, "r", encoding="utf-8") as f:
            cls.network_service_content = f.read()
        with open(SYSTEM_SERVICE_PATH, "r", encoding="utf-8") as f:
            cls.system_service_content = f.read()

    def test_coupled_capsule_renders_only_telemetry(self):
        """Coupled CenterCapsule must display CPU, RAM, Intel GPU, and NVIDIA GPU."""
        self.assertIn("SystemService.cpuUsage", self.capsule_content)
        self.assertIn("SystemService.ram", self.capsule_content)
        self.assertIn("SystemService.gpuIntel", self.capsule_content)
        self.assertIn("SystemService.gpuNvidia", self.capsule_content)

        # Coupled bar should NOT cycle between modes or contain active window title or marquee
        self.assertNotIn("HyprlandService.windowTitle", self.capsule_content)
        self.assertNotIn("marqueeText", self.capsule_content)

    def test_coupled_capsule_triggers_expansion_on_click(self):
        """CenterCapsule must emit or handle clicked signal to expand."""
        self.assertIn("signal clicked()", self.capsule_content)
        self.assertIn("root.clicked()", self.capsule_content)

    def test_bar_window_has_global_shortcut_for_center_panel(self):
        """BarWindow must bind GlobalShortcut for center panel expansion (Super+P)."""
        self.assertIn("GlobalShortcut", self.bar_content)
        self.assertIn('"center_panel"', self.bar_content)

    def test_detached_flyout_has_rounded_superposed_styling(self):
        """CenterFlyout must declare rounded corners and opaque surface."""
        self.assertTrue(re.search(r"radius:\s*(1[4-9]|2\d)", self.flyout_content))
        self.assertIn("Colors.surface", self.flyout_content)

    def test_detached_flyout_slidable_sections_wheel_and_trackpad(self):
        """CenterFlyout must implement slidable sections responding to wheel/trackpad events."""
        self.assertIn("onWheel", self.flyout_content)
        self.assertIn("currentSection", self.flyout_content)

    def test_detached_flyout_detailed_telemetry(self):
        """Detached flyout must render CPU, RAM, GPUs, Network speed, Network SSID, and Serial device."""
        self.assertIn("SystemService.cpuUsage", self.flyout_content)
        self.assertIn("SystemService.ram", self.flyout_content)
        self.assertIn("SystemService.gpuIntel", self.flyout_content)
        self.assertIn("SystemService.gpuNvidia", self.flyout_content)
        self.assertIn("SystemService.netSpeedString", self.flyout_content)
        self.assertIn("NetworkService.ssid", self.flyout_content)
        self.assertIn("SystemService.serialDevice", self.flyout_content)

    def test_detached_flyout_music_player_section(self):
        """Detached flyout must render music player with cover art, track info, and playback buttons."""
        self.assertIn("MediaService.artUrl", self.flyout_content)
        self.assertIn("MediaService.playPause", self.flyout_content)
        self.assertIn("MediaService.previous", self.flyout_content)
        self.assertIn("MediaService.next", self.flyout_content)

    def test_detached_flyout_agent_information_section(self):
        """Detached flyout must render agent activity and running actions."""
        self.assertIn("AntigravityService", self.flyout_content)

    def test_right_panel_network_click_triggers_network_menu(self):
        """RightPanel network metric must be clickable and emit networkRequested."""
        self.assertIn("signal networkRequested()", self.right_panel_content)
        self.assertIn("root.networkRequested()", self.right_panel_content)

    def test_network_service_exposes_scanning_and_connecting(self):
        """NetworkService must expose scanning methods, network list, and connection method."""
        self.assertIn("property var networks", self.network_service_content)
        self.assertIn("function scanNetworks", self.network_service_content)
        self.assertIn("function connectToNetwork", self.network_service_content)

    def test_system_service_exposes_network_speed_and_serial_device(self):
        """SystemService must expose netSpeedString and serialDevice."""
        self.assertIn("property string netSpeedString", self.system_service_content)
        self.assertIn("property string serialDevice", self.system_service_content)

    def test_bar_window_configures_wayland_keyboard_focus(self):
        """BarWindow must configure WlrLayershell.keyboardFocus to OnDemand for password entry."""
        self.assertIn("WlrLayershell.keyboardFocus", self.bar_content)
        self.assertIn("WlrKeyboardFocus.OnDemand", self.bar_content)

    def test_detached_flyout_superposed_anchoring(self):
        """CenterFlyout must be anchored superposed over the coupled capsule at parent.top with high z-order."""
        self.assertIn("anchors.top: parent.top", self.bar_content)
        self.assertIn("z: 30", self.bar_content)

    def test_trackpad_vs_mousewheel_enforcement(self):
        """CenterFlyout must restrict trackpad gestures unless expanded with Super+P."""
        self.assertIn("property bool expandedWithSuperP", self.flyout_content)
        self.assertIn("expandedWithSuperP: root.centerOpenedViaShortcut", self.bar_content)
        # Contract rule check in wheel handler
        self.assertIn("isTrackpad && !root.expandedWithSuperP", self.flyout_content)

    def test_center_flyout_has_close_requested_contract(self):
        """CenterFlyout must declare closeRequested signal and close button."""
        self.assertIn("signal closeRequested()", self.flyout_content)
        self.assertIn("root.closeRequested()", self.flyout_content)
        self.assertIn("window-close", self.flyout_content)

    def test_cocoa_daemon_locale_independent_wifi(self):
        """cocoa_daemon.sh must detect active Wi-Fi across both Spanish (sí) and English (yes) locales."""
        with open(os.path.join(PROJECT_ROOT, "scripts", "cocoa_daemon.sh"), "r", encoding="utf-8") as f:
            daemon_content = f.read()
        self.assertIn("grep -E '^(sí|yes):'", daemon_content)


if __name__ == "__main__":
    unittest.main()
