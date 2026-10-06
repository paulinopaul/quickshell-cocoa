#!/usr/bin/env python3
"""
Contract tests for Cocoa Wallpaper Transition Window.

Verifies:
1. Wayland layershell configuration in modules/wallpaper/WallpaperTransitionWindow.qml:
   - WlrLayershell.namespace: "cocoa-wallpaper-transition"
   - WlrLayershell.layer: WlrLayer.Bottom (sits right above hyprpaper layer 0)
   - Fullscreen anchors (top, bottom, left, right)
   - ExclusionMode.Ignore, transparent color, dynamic visibility via isTransitioning.
2. Old wallpaper split & progressive blur exit animation (oldLeft, oldRight, clip: true,
   MultiEffect blur, horizontal separation).
3. New wallpaper reveal diagonal wipe effect (rotated maskItem with Math.atan2 and Math.hypot,
   MultiEffect with maskEnabled: true and maskSource).
4. Transition animation contract: NumberAnimation with duration ~650ms, Easing.InOutCubic,
   startTransition() method, safety timer (~140ms), and WallpaperService.applyWallpaper dispatch.
5. WallpaperWindow.qml integration: transitionWindow property and conditional trigger in applyAndClose().
6. shell.qml wiring: WallpaperTransitionWindow instance and selector binding.
7. modules/wallpaper/qmldir registration for WallpaperTransitionWindow 1.0.
"""

import os
import re
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSITION_FILE = PROJECT_ROOT / "modules" / "wallpaper" / "WallpaperTransitionWindow.qml"
WINDOW_FILE = PROJECT_ROOT / "modules" / "wallpaper" / "WallpaperWindow.qml"
QMLDIR_FILE = PROJECT_ROOT / "modules" / "wallpaper" / "qmldir"
SHELL_FILE = PROJECT_ROOT / "shell.qml"


class TestWallpaperTransitionContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not TRANSITION_FILE.exists():
            raise FileNotFoundError(f"Transition file not found: {TRANSITION_FILE}")
        with open(TRANSITION_FILE, "r", encoding="utf-8") as f:
            cls.transition_content = f.read()

        with open(WINDOW_FILE, "r", encoding="utf-8") as f:
            cls.window_content = f.read()

        with open(QMLDIR_FILE, "r", encoding="utf-8") as f:
            cls.qmldir_content = f.read()

        with open(SHELL_FILE, "r", encoding="utf-8") as f:
            cls.shell_content = f.read()

    def test_layershell_and_fullscreen_contract(self):
        """Must configure WlrLayer.Bottom, cocoa-wallpaper-transition namespace and fullscreen anchors."""
        self.assertIn('WlrLayershell.namespace: "cocoa-wallpaper-transition"', self.transition_content)
        self.assertIn("WlrLayershell.layer: WlrLayer.Bottom", self.transition_content)
        self.assertIn("exclusionMode: ExclusionMode.Ignore", self.transition_content)
        self.assertIn('color: "transparent"', self.transition_content)
        self.assertIn("visible: isTransitioning", self.transition_content)

        # Fullscreen anchors
        self.assertTrue(
            re.search(r"anchors\s*\{[^}]*top:\s*true", self.transition_content),
            "Must anchor to top",
        )
        self.assertTrue(
            re.search(r"anchors\s*\{[^}]*bottom:\s*true", self.transition_content),
            "Must anchor to bottom",
        )
        self.assertTrue(
            re.search(r"anchors\s*\{[^}]*left:\s*true", self.transition_content),
            "Must anchor to left",
        )
        self.assertTrue(
            re.search(r"anchors\s*\{[^}]*right:\s*true", self.transition_content),
            "Must anchor to right",
        )

    def test_transition_properties(self):
        """Must define transition state properties."""
        self.assertIn("property string oldWallpaper:", self.transition_content)
        self.assertIn("property string newWallpaper:", self.transition_content)
        self.assertIn("property real animProgress:", self.transition_content)
        self.assertIn("property bool isTransitioning:", self.transition_content)

    def test_old_wallpaper_progressive_blur_base(self):
        """Must define unified old wallpaper base with progressive blur and opacity fade."""
        self.assertIn("id: oldImg", self.transition_content)
        self.assertIn("id: oldEffect", self.transition_content)

        # Blur and fade in MultiEffect
        self.assertIn("blurEnabled: true", self.transition_content)
        self.assertIn("blurMax: 48", self.transition_content)
        self.assertTrue(
            re.search(r"blur:\s*(root\.)?animProgress", self.transition_content),
            "MultiEffect blur must follow animProgress",
        )
        self.assertTrue(
            re.search(r"opacity:\s*Math\.max\(0\.0,\s*1\.0\s*-\s*(root\.)?animProgress\)", self.transition_content),
            "MultiEffect opacity must fade out with animProgress",
        )

    def test_new_wallpaper_diagonal_reveal(self):
        """Must define maskItem with Math.atan2 rotation and MultiEffect masked reveal."""
        self.assertIn("id: maskItem", self.transition_content)
        self.assertTrue(
            re.search(r"id:\s*maskItem[\s\S]*?layer\.enabled:\s*true", self.transition_content),
            "maskItem must have layer.enabled: true",
        )
        self.assertTrue(
            re.search(r"id:\s*maskItem[\s\S]*?visible:\s*false", self.transition_content),
            "maskItem must have visible: false",
        )

        # Diagonal rotation calculation
        self.assertIn("Math.atan2", self.transition_content)
        self.assertIn("Math.hypot", self.transition_content)

        # MultiEffect masked reveal
        self.assertTrue(
            re.search(r"maskEnabled:\s*true", self.transition_content),
            "MultiEffect must enable maskEnabled",
        )
        self.assertTrue(
            re.search(r"maskSource:\s*maskItem", self.transition_content),
            "MultiEffect maskSource must be maskItem",
        )

    def test_transition_animation_and_timing(self):
        """Transition animation must run for 1500ms (1.5s) with InOutCubic easing and trigger safety timer."""
        self.assertIn("id: transitionAnim", self.transition_content)
        self.assertTrue(
            re.search(r"duration:\s*1500", self.transition_content),
            "Transition animation must have duration 1500ms (1.5s)",
        )
        self.assertIn("Easing.InOutCubic", self.transition_content)
        self.assertIn("WallpaperService.applyWallpaper", self.transition_content)

        # Safety timer
        self.assertTrue(
            re.search(r"interval:\s*140", self.transition_content),
            "Safety timer interval must be 140ms",
        )
        self.assertTrue(
            re.search(r"root\.isTransitioning\s*=\s*false", self.transition_content),
            "Safety timer must reset isTransitioning to false",
        )

        # startTransition signature without TypeScript annotations
        self.assertIn("function startTransition(oldPath, newPath)", self.transition_content)
        self.assertNotIn("function startTransition(oldPath: string", self.transition_content)
        self.assertNotIn("): void", self.transition_content)

    def test_wallpaper_window_transition_integration(self):
        """WallpaperWindow.qml must have transitionWindow property and invoke it in applyAndClose."""
        self.assertTrue(
            re.search(r"property\s+var\s+transitionWindow:\s*null", self.window_content),
            "WallpaperWindow must declare transitionWindow property",
        )
        self.assertIn("startTransition", self.window_content)
        self.assertTrue(
            re.search(
                r"(root\.)?transitionWindow\s*&&\s*oldPath\s*!==\s*newPath",
                self.window_content,
            ),
            "applyAndClose must check transitionWindow and path difference",
        )

    def test_shell_root_instantiates_and_wires_transition_window(self):
        """shell.qml must instantiate WallpaperTransitionWindow and wire it to wallpaperSelector."""
        self.assertIn("WallpaperTransitionWindow", self.shell_content)
        self.assertIn("id: wallpaperTransition", self.shell_content)
        self.assertTrue(
            re.search(r"transitionWindow:\s*wallpaperTransition", self.shell_content),
            "wallpaperSelector must have transitionWindow wired to wallpaperTransition",
        )

    def test_qmldir_registration(self):
        """modules/wallpaper/qmldir must register WallpaperTransitionWindow 1.0."""
        self.assertIn(
            "WallpaperTransitionWindow 1.0 WallpaperTransitionWindow.qml",
            self.qmldir_content,
        )


if __name__ == "__main__":
    unittest.main()
