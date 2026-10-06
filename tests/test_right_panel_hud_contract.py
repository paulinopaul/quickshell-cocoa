"""Contract tests for RightPanel Dynamic HUD and Vector Iconography.

Enforces:
1. Native monochromatic vector paths for network in components/Icon.qml
   (network-wireless, network-wired, network-offline).
2. Brightness metric presentation and scroll interaction in modules/bar/RightPanel.qml.
3. Lightweight dynamic HUD transformation switching between standard metrics and
   the active volume/brightness adjustment bar with auto-revert timer.
"""

import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_PATH = os.path.join(PROJECT_ROOT, "components", "Icon.qml")
RIGHT_PANEL_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "RightPanel.qml")


class TestRightPanelHudContract(unittest.TestCase):
    """Structural and behavioral contract validation for RightPanel HUD and Icons."""

    @classmethod
    def setUpClass(cls) -> None:
        if not os.path.exists(ICON_PATH):
            raise FileNotFoundError(f"Missing {ICON_PATH}")
        with open(ICON_PATH, "r", encoding="utf-8") as f:
            cls.icon_content = f.read()

        if not os.path.exists(RIGHT_PANEL_PATH):
            raise FileNotFoundError(f"Missing {RIGHT_PANEL_PATH}")
        with open(RIGHT_PANEL_PATH, "r", encoding="utf-8") as f:
            cls.panel_content = f.read()

    def test_icon_vectors_include_network(self) -> None:
        """Icon.qml must include native vector SVG paths for network services."""
        self.assertIn('"network-wireless":', self.icon_content)
        self.assertIn('"network-wired":', self.icon_content)
        self.assertIn('"network-offline":', self.icon_content)

    def test_brightness_metric_in_right_panel(self) -> None:
        """RightPanel must display brightness percentage and support wheel interaction."""
        self.assertIn("BrightnessService", self.panel_content)
        self.assertTrue(
            "BrightnessService.brightness" in self.panel_content,
            "RightPanel must bind to BrightnessService.brightness",
        )
        self.assertTrue(
            re.search(r"BrightnessService\.setBrightness", self.panel_content),
            "RightPanel must support wheel-based brightness adjustments",
        )

    def test_dynamic_hud_transformation_in_right_panel(self) -> None:
        """RightPanel must implement dynamic HUD mode switching with an auto-revert timer."""
        self.assertIn("hudActive", self.panel_content)
        self.assertIn("hudTimer", self.panel_content)
        self.assertTrue(
            "volumeChangedExplicitly" in self.panel_content,
            "RightPanel must connect to VolumeService.volumeChangedExplicitly",
        )
        self.assertTrue(
            "brightnessChangedExplicitly" in self.panel_content,
            "RightPanel must connect to BrightnessService.brightnessChangedExplicitly",
        )
        self.assertTrue(
            "Meter" in self.panel_content,
            "RightPanel must render a lightweight Meter in HUD mode",
        )

    def test_brightness_service_optimistic_update(self) -> None:
        """BrightnessService must perform optimistic state update without blocking on process output."""
        service_path = os.path.join(PROJECT_ROOT, "services", "BrightnessService.qml")
        with open(service_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("function setBrightness", content)
        self.assertTrue(
            re.search(r"root\.brightness\s*=\s*pct", content),
            "setBrightness must optimistically update root.brightness immediately",
        )

    def test_volume_service_optimistic_update(self) -> None:
        """VolumeService must perform optimistic state update without waiting for daemon cycle."""
        service_path = os.path.join(PROJECT_ROOT, "services", "VolumeService.qml")
        with open(service_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("function setVolume", content)
        self.assertTrue(
            re.search(r"root\.volume\s*=\s*pct", content),
            "setVolume must optimistically update root.volume immediately",
        )


if __name__ == "__main__":
    unittest.main()

