#!/usr/bin/env python3
"""
Contract tests for Cocoa Wallpaper Selector in Carousel Mode.

Verifies:
1. Natural sorting algorithm and directory scanning in scripts/wallpaper_lister.py.
2. WallpaperWindow.qml architectural contract (Overlay layer, surfaceActive decoupling,
   explicit 840x340 dimensions, GlobalShortcut, key event handlers, horizontal carousel).
3. WallpaperCard.qml performance & rendering contract (asynchronous: true, sourceSize,
   surface styling, scale/opacity transitions).
4. Hyprland configuration contains quickshell:wallpaper_selector global binding.
5. shell.qml imports modules/wallpaper and instantiates WallpaperWindow.
6. WallpaperService.qml singleton and services/qmldir registration.
"""

import os
import re
import sys
import unittest
import tempfile
import shutil

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(PROJECT_ROOT, "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import wallpaper_lister

WINDOW_PATH = os.path.join(PROJECT_ROOT, "modules", "wallpaper", "WallpaperWindow.qml")
CARD_PATH = os.path.join(PROJECT_ROOT, "modules", "wallpaper", "WallpaperCard.qml")
SHELL_PATH = os.path.join(PROJECT_ROOT, "shell.qml")
SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "WallpaperService.qml")
QMLDIR_PATH = os.path.join(PROJECT_ROOT, "services", "qmldir")
HYPR_CONF_PATH = os.path.expanduser("~/.config/hypr/hyprland.conf")


class TestWallpaperSelectorContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(WINDOW_PATH, "r", encoding="utf-8") as f:
            cls.window_content = f.read()

        with open(CARD_PATH, "r", encoding="utf-8") as f:
            cls.card_content = f.read()

        with open(SHELL_PATH, "r", encoding="utf-8") as f:
            cls.shell_content = f.read()

        with open(SERVICE_PATH, "r", encoding="utf-8") as f:
            cls.service_content = f.read()

        with open(QMLDIR_PATH, "r", encoding="utf-8") as f:
            cls.qmldir_content = f.read()

        if os.path.exists(HYPR_CONF_PATH):
            with open(HYPR_CONF_PATH, "r", encoding="utf-8") as f:
                cls.hypr_content = f.read()
        else:
            cls.hypr_content = ""

    def test_natural_sorting_order(self):
        """Must naturally sort filenames so w1 < w2 < ... < w10 < w11."""
        files = [
            "w10.jpg",
            "w2.jpg",
            "w1.jpg",
            "w12.png",
            "w11.jpg",
            "w3.jpg",
            "w9.jpg",
        ]
        sorted_files = sorted(files, key=wallpaper_lister.natural_sort_key)
        expected = [
            "w1.jpg",
            "w2.jpg",
            "w3.jpg",
            "w9.jpg",
            "w10.jpg",
            "w11.jpg",
            "w12.png",
        ]
        self.assertEqual(sorted_files, expected)

    def test_wallpaper_lister_scans_and_filters_directory(self):
        """list_wallpapers must scan directory, filter non-images and apply natural sort."""
        temp_dir = tempfile.mkdtemp(prefix="cocoa_wall_test_")
        try:
            # Create dummy files
            test_filenames = [
                "w10.png",
                "notes.txt",
                "w2.jpg",
                "w1.jpeg",
                ".hidden.png",
                "w3.webp",
                "w4.bmp",
                "script.sh",
            ]
            for fname in test_filenames:
                with open(os.path.join(temp_dir, fname), "w") as f:
                    f.write("test")

            results = wallpaper_lister.list_wallpapers(temp_dir)
            names = [r["name"] for r in results]

            expected_names = ["w1.jpeg", "w2.jpg", "w3.webp", "w4.bmp", "w10.png"]
            self.assertEqual(names, expected_names)

            for r in results:
                self.assertTrue(os.path.isabs(r["path"]))
                self.assertTrue(os.path.exists(r["path"]))
        finally:
            shutil.rmtree(temp_dir)

    def test_wallpaper_window_wayland_contract(self):
        """WallpaperWindow must configure Overlay layer, keyboard focus, and explicit dimensions."""
        self.assertIn('WlrLayershell.namespace: "cocoa-wallpaper-selector"', self.window_content)
        self.assertIn("WlrLayershell.layer: WlrLayer.Overlay", self.window_content)
        self.assertTrue(
            re.search(
                r"WlrLayershell\.keyboardFocus:\s*isOpen\s*\?\s*WlrKeyboardFocus\.Exclusive\s*:\s*WlrKeyboardFocus\.None",
                self.window_content,
            )
        )
        self.assertTrue(re.search(r"implicitWidth:\s*840", self.window_content))
        self.assertTrue(re.search(r"implicitHeight:\s*340", self.window_content))
        self.assertIn("exclusionMode: ExclusionMode.Ignore", self.window_content)

    def test_wallpaper_window_surface_lifecycle_and_animations(self):
        """visible must be decoupled via surfaceActive with OutBack enter and InCubic exit."""
        self.assertTrue(
            re.search(r"visible:\s*surfaceActive", self.window_content),
            "visible must be tied to surfaceActive",
        )
        self.assertIn("Easing.OutBack", self.window_content)
        self.assertIn("Easing.InCubic", self.window_content)
        self.assertIn("enterAnim", self.window_content)
        self.assertIn("exitAnim", self.window_content)

    def test_wallpaper_window_global_shortcut_and_key_navigation(self):
        """WallpaperWindow must define GlobalShortcut and key handlers."""
        self.assertIn("GlobalShortcut", self.window_content)
        self.assertIn('"wallpaper_selector"', self.window_content)

        # Key navigation handlers: Space, Right, Left, Return/Enter, Escape
        self.assertTrue("onSpacePressed" in self.window_content or "Key_Space" in self.window_content)
        self.assertTrue("onRightPressed" in self.window_content or "Key_Right" in self.window_content)
        self.assertTrue("onLeftPressed" in self.window_content or "Key_Left" in self.window_content)
        self.assertTrue(
            "onReturnPressed" in self.window_content
            or "onEnterPressed" in self.window_content
            or "Key_Return" in self.window_content
        )
        self.assertTrue("onEscapePressed" in self.window_content or "Key_Escape" in self.window_content)

    def test_wallpaper_window_carousel_and_card_container(self):
        """WallpaperWindow must contain radius 16 container, horizontal ListView and strictly enforced range."""
        self.assertTrue(re.search(r"radius:\s*16", self.window_content))
        self.assertIn("Colors.surfaceRaised", self.window_content)
        self.assertIn("ListView.Horizontal", self.window_content)
        self.assertIn("ListView.StrictlyEnforceRange", self.window_content)
        self.assertIn("Navegar", self.window_content)
        self.assertIn("Aplicar", self.window_content)
        self.assertIn("Cancelar", self.window_content)

    def test_wallpaper_card_performance_and_styling(self):
        """WallpaperCard must load asynchronously with bounded sourceSize and Cocoa styling."""
        self.assertIn("asynchronous: true", self.card_content)
        self.assertTrue(re.search(r"sourceSize\.width:\s*320", self.card_content))
        self.assertTrue(re.search(r"sourceSize\.height:\s*180", self.card_content))
        self.assertIn("Image.PreserveAspectCrop", self.card_content)
        self.assertIn("clip: true", self.card_content)
        self.assertIn("Colors.surface", self.card_content)
        self.assertIn("Colors.accent", self.card_content)
        self.assertIn("Colors.surfaceRaised", self.card_content)
        self.assertTrue(re.search(r"radius:\s*14", self.card_content))
        self.assertIn("isCurrent", self.card_content)

    def test_hyprland_shortcut_configured(self):
        """Hyprland config must bind SUPER, space to quickshell:wallpaper_selector."""
        self.assertTrue(
            re.search(
                r"bind\s*=\s*SUPER\s*,\s*space\s*,\s*global\s*,\s*quickshell:wallpaper_selector",
                self.hypr_content,
            ),
            "hyprland.conf must contain bind = SUPER, space, global, quickshell:wallpaper_selector",
        )

    def test_shell_root_instantiates_wallpaper_window(self):
        """shell.qml must import modules/wallpaper and instantiate WallpaperWindow."""
        self.assertIn('"modules/wallpaper"', self.shell_content)
        self.assertIn("WallpaperWindow", self.shell_content)
        self.assertIn("id: wallpaperSelector", self.shell_content)

    def test_wallpaper_service_contract_and_qmldir(self):
        """WallpaperService must be registered in qmldir and manage reactive properties."""
        self.assertIn("singleton WallpaperService 1.0 WallpaperService.qml", self.qmldir_content)
        self.assertIn("property var wallpapers", self.service_content)
        self.assertIn("property string currentPath", self.service_content)
        self.assertIn("property int currentIndex", self.service_content)
        self.assertIn("property bool isApplying", self.service_content)
        self.assertIn("current_wallpaper.txt", self.service_content)
        self.assertIn("function refresh", self.service_content)
        self.assertIn("function applyWallpaper", self.service_content)


if __name__ == "__main__":
    unittest.main()
