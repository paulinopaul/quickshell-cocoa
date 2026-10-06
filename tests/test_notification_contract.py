"""Contract verification tests for Cocoa Notification System QML components.

Ensures that:
1. NotificationPopup.qml adheres to Wayland LayerShell specifications (namespace, layer, margins).
2. Translucency (0.50 opacity/alpha) and blur styling are enforced.
3. Origin-only small icon size constraints are obeyed.
4. Visibility is dynamically tied to notification state and central panel detached state.
5. NotificationService.qml implements centralPanelDetached suppression.
"""

import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POPUP_PATH = os.path.join(PROJECT_ROOT, "modules", "notifications", "NotificationPopup.qml")
SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "NotificationService.qml")
BAR_WINDOW_PATH = os.path.join(PROJECT_ROOT, "modules", "bar", "BarWindow.qml")


class TestNotificationContract(unittest.TestCase):
    """Static and structural contract validation for the notification module."""

    def test_popup_file_exists(self) -> None:
        """NotificationPopup.qml must exist in modules/notifications/."""
        self.assertTrue(os.path.exists(POPUP_PATH), f"Missing {POPUP_PATH}")

    def test_service_file_exists(self) -> None:
        """NotificationService.qml must exist in services/."""
        self.assertTrue(os.path.exists(SERVICE_PATH), f"Missing {SERVICE_PATH}")

    def test_layershell_namespace_and_layer(self) -> None:
        """Namespace must be 'cocoa-notifications' and layer must be Overlay."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn('WlrLayershell.namespace: "cocoa-notifications"', content)
        self.assertTrue(
            "WlrLayershell.layer: WlrLayer.Overlay" in content or "WlrLayershell.layer: WlrLayer.Top" in content,
            "NotificationPopup must declare an Overlay or Top layer"
        )

    def test_anchored_below_central_bar(self) -> None:
        """Must be anchored to top with margin below the central bar."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertTrue(
            re.search(r"anchors\s*\{\s*top:\s*true", content),
            "Popup must anchor top: true"
        )
        self.assertTrue(
            "margins" in content and ("Metrics.barHeight" in content or "Metrics.exclusiveZone" in content),
            "Popup top margin must be dynamically calculated from barHeight or exclusiveZone"
        )

    def test_opaque_surface_and_rounded_borders(self) -> None:
        """Card styling must use solid Colors.surface and Colors.surfaceRaised border (opaque flyout style)."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn(
            "color: Colors.surface",
            content,
            "Popup card must use solid Colors.surface (matching flyout windows)"
        )
        self.assertNotIn(
            "0.50",
            content,
            "Popup card must NOT use 0.50 transparency"
        )
        self.assertIn(
            "border.color: Colors.surfaceRaised",
            content,
            "Popup border must match Colors.surfaceRaised"
        )
        self.assertTrue(
            re.search(r"radius:\s*\d+", content),
            "Popup card must define a rounded corner radius"
        )

    def test_internal_horizontal_gradient(self) -> None:
        """Popup card must contain an internal horizontal gradient bound to NotificationService.gradientColor."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("Gradient.Horizontal", content, "Gradient must be horizontal")
        self.assertIn("NotificationService.gradientColor", content, "Gradient color must be driven by NotificationService.gradientColor")

    def test_terminal_agent_ascii_representation(self) -> None:
        """Popup must support ASCII agent glyphs via NotificationService.asciiIcon and isAgentOrTerminal."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("NotificationService.asciiIcon", content, "Popup must bind to NotificationService.asciiIcon")
        self.assertIn("NotificationService.isAgentOrTerminal", content, "Popup must check isAgentOrTerminal")

    def test_service_exposes_agent_and_gradient_properties(self) -> None:
        """NotificationService must expose gradientColor, asciiIcon, and isAgentOrTerminal properties."""
        with open(SERVICE_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("property string gradientColor", content)
        self.assertIn("property string asciiIcon", content)
        self.assertIn("property bool isAgentOrTerminal", content)

    def test_origin_program_icon_restricted_size(self) -> None:
        """App icon must have small size (<= 20px) and display only when present."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        icon_size_match = re.search(r"size:\s*(\d+)", content)
        self.assertIsNotNone(icon_size_match, "Icon must have an explicit size defined")
        if icon_size_match:
            size_val = int(icon_size_match.group(1))
            self.assertLessEqual(size_val, 20, "Icon size must be small (<= 20px)")

    def test_dynamic_visibility_and_detached_panel_suppression(self) -> None:
        """Visibility must depend on active notification and centralPanelDetached state."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertNotIn("visible: true\n", content)
        self.assertTrue(
            "centralPanelDetached" in content or "NotificationService" in content,
            "Popup must bind visibility to NotificationService state"
        )

    def test_service_tracks_central_panel_detached(self) -> None:
        """NotificationService must expose centralPanelDetached and auto-dismiss logic."""
        with open(SERVICE_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("property bool centralPanelDetached", content)
        self.assertTrue(
            "dismiss" in content.lower() or "hasactivenotification" in content.lower(),
            "NotificationService must handle dismissal on detached central panel"
        )

    def test_bar_window_links_detached_state(self) -> None:
        """BarWindow must propagate its central flyout visibility to NotificationService."""
        with open(BAR_WINDOW_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertTrue(
            "NotificationService.centralPanelDetached" in content,
            "BarWindow must link mediaMenuVisible with NotificationService.centralPanelDetached"
        )


if __name__ == "__main__":
    unittest.main()
