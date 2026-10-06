#!/usr/bin/env python3
"""
Unit tests for Hyprpaper v0.8+ block syntax generator and persistence validator.
Enforces Rule 12 (TDD Mandate) and Rule 13 (Edge Cases & Boundaries).
"""

import unittest
from typing import List


def generate_hyprpaper_conf(wallpaper_path: str, monitors: List[str]) -> str:
    """
    Generates configuration string strictly conforming to Hyprlang v0.8+ block syntax.
    Enforces non-empty paths and fallback monitor specification.
    """
    if not wallpaper_path or not wallpaper_path.strip():
        raise ValueError("Wallpaper path cannot be empty.")
    
    clean_path = wallpaper_path.strip()
    active_monitors = [m.strip() for m in monitors if m and m.strip()]
    if not active_monitors:
        active_monitors = ["eDP-1"]

    lines = [f"preload = {clean_path}", ""]
    for mon in active_monitors:
        lines.append("wallpaper {")
        lines.append(f"    monitor = {mon}")
        lines.append(f"    path = {clean_path}")
        lines.append("}")
        lines.append("")
    lines.append("splash = false")
    lines.append("ipc = on")
    lines.append("")
    return "\n".join(lines)


class TestWallpaperManager(unittest.TestCase):
    def test_single_monitor_generation(self) -> None:
        conf = generate_hyprpaper_conf("/home/paul/Pictures/Wallpapers/w12.png", ["eDP-1"])
        self.assertIn("preload = /home/paul/Pictures/Wallpapers/w12.png", conf)
        self.assertIn("wallpaper {", conf)
        self.assertIn("monitor = eDP-1", conf)
        self.assertIn("path = /home/paul/Pictures/Wallpapers/w12.png", conf)
        self.assertIn("ipc = on", conf)
        # Ensure deprecated single-line syntax is NOT generated
        self.assertNotIn("wallpaper = eDP-1,", conf)

    def test_multi_monitor_generation(self) -> None:
        conf = generate_hyprpaper_conf("/path/img.png", ["eDP-1", "HDMI-A-1"])
        self.assertEqual(conf.count("wallpaper {"), 2)
        self.assertIn("monitor = eDP-1", conf)
        self.assertIn("monitor = HDMI-A-1", conf)

    def test_empty_monitors_fallback(self) -> None:
        conf = generate_hyprpaper_conf("/path/img.png", [])
        self.assertIn("monitor = eDP-1", conf)

    def test_whitespace_and_empty_entries_in_monitors(self) -> None:
        conf = generate_hyprpaper_conf("/path/img.png", ["  ", "eDP-1", ""])
        self.assertEqual(conf.count("wallpaper {"), 1)
        self.assertIn("monitor = eDP-1", conf)

    def test_empty_path_raises_value_error(self) -> None:
        with self.assertRaises(ValueError):
            generate_hyprpaper_conf("", ["eDP-1"])
        with self.assertRaises(ValueError):
            generate_hyprpaper_conf("   ", ["eDP-1"])


if __name__ == "__main__":
    unittest.main()
