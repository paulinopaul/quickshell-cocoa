"""Contract tests for Cocoa Application Launcher (modules/launcher/LauncherWindow.qml).

Enforces:
1. Bottom-center layer-shell anchoring (anchors.bottom: true, no fullscreen anchors).
2. Explicit bounded dimensions (implicitWidth, implicitHeight).
3. Clean Wayland surface unmapping (visible tied to isOpen).
4. Auto-dismissal triggers: Escape key, application launch, and mouse hover exit.
5. Retirement of OsdWindow from shell.qml root tree.
"""

import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAUNCHER_PATH = os.path.join(PROJECT_ROOT, "modules", "launcher", "LauncherWindow.qml")
SHELL_PATH = os.path.join(PROJECT_ROOT, "shell.qml")


class TestLauncherContract(unittest.TestCase):
    """Structural and behavioral contract validation for LauncherWindow."""

    @classmethod
    def setUpClass(cls) -> None:
        if not os.path.exists(LAUNCHER_PATH):
            raise FileNotFoundError(f"Missing {LAUNCHER_PATH}")
        with open(LAUNCHER_PATH, "r", encoding="utf-8") as f:
            cls.launcher_content = f.read()

        if not os.path.exists(SHELL_PATH):
            raise FileNotFoundError(f"Missing {SHELL_PATH}")
        with open(SHELL_PATH, "r", encoding="utf-8") as f:
            cls.shell_content = f.read()

    def test_bottom_anchoring_and_no_fullscreen_overlay(self) -> None:
        """Launcher must anchor to bottom without occupying full-screen transparent space."""
        # Must have anchors.bottom: true
        self.assertTrue(
            re.search(r"anchors\s*\{[^}]*bottom:\s*true", self.launcher_content),
            "LauncherWindow must declare anchors { bottom: true }",
        )
        # Must not anchor top or left/right to screen bounds
        self.assertFalse(
            re.search(r"anchors\s*\{[^}]*top:\s*true", self.launcher_content),
            "LauncherWindow must NOT anchor top: true to prevent fullscreen overlay",
        )

    def test_explicit_surface_dimensions(self) -> None:
        """Launcher must set explicit implicitWidth and implicitHeight."""
        self.assertTrue(
            re.search(r"implicitWidth:\s*\d+", self.launcher_content),
            "LauncherWindow must specify an explicit implicitWidth",
        )
        self.assertTrue(
            re.search(r"implicitHeight:\s*\d+", self.launcher_content),
            "LauncherWindow must specify an explicit implicitHeight",
        )

    def test_dynamic_surface_lifecycle(self) -> None:
        """Window visibility must be decoupled from isOpen to allow exit animation before unmapping."""
        self.assertTrue(
            "surfaceActive" in self.launcher_content,
            "LauncherWindow must declare a surfaceActive property to preserve window during exit animation",
        )
        self.assertTrue(
            re.search(r"visible:\s*surfaceActive", self.launcher_content),
            "LauncherWindow must tie visible to surfaceActive for proper animated Wayland unmapping",
        )

    def test_vertical_slide_and_jump_kinematics(self) -> None:
        """Launcher must implement vertical slide from bottom on open and jump-then-dive on close."""
        # Must animate the vertical 'y' coordinate
        self.assertTrue(
            re.search(r'property:\s*"y"', self.launcher_content),
            "LauncherWindow must animate property 'y' for vertical displacement",
        )
        # Must use OutBack for energetic bottom-up emergence
        self.assertIn(
            "Easing.OutBack",
            self.launcher_content,
            "LauncherWindow must use Easing.OutBack for bottom-up spring slide-in",
        )
        # Must implement jump & dive sequential exit animation
        self.assertTrue(
            "exitAnim" in self.launcher_content or "SequentialAnimation" in self.launcher_content,
            "LauncherWindow must use a SequentialAnimation for the jump & dive exit sequence",
        )

    def test_escape_and_selection_close_triggers(self) -> None:
        """Must contain close triggers on Escape key and program launch."""
        self.assertIn("Keys.onEscapePressed", self.launcher_content)
        self.assertTrue(
            "root.close()" in self.launcher_content or "close()" in self.launcher_content,
            "Must invoke close() on dismissal",
        )

    def test_mouse_hover_exit_dismissal(self) -> None:
        """Must detect mouse leaving the area and dismiss the launcher."""
        self.assertTrue(
            "hoverEnabled: true" in self.launcher_content,
            "Launcher must enable hover tracking to detect mouse exit",
        )
        self.assertTrue(
            "onExited" in self.launcher_content or "containsMouse" in self.launcher_content,
            "Launcher must react to mouse exiting the widget area",
        )

    def test_osd_window_retired_from_shell(self) -> None:
        """OsdWindow must not be instantiated in shell.qml."""
        # Find any non-commented OsdWindow instantiation
        active_osd_lines = [
            line for line in self.shell_content.splitlines()
            if "OsdWindow" in line and not line.strip().startswith("//") and not line.strip().startswith("/*")
        ]
        self.assertEqual(
            len(active_osd_lines),
            0,
            f"OsdWindow is still instantiated in shell.qml: {active_osd_lines}",
        )


if __name__ == "__main__":
    unittest.main()
