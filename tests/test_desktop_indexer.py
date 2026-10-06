#!/usr/bin/env python3
"""
Unit tests for Desktop Entry (.desktop) parsing and launcher query filtering.
Enforces Rule 12 (TDD Mandate) and Rule 13 (Edge Cases).
"""

import re
import unittest
from typing import Dict, List, Optional


def parse_desktop_entry(raw_content: str) -> Optional[Dict[str, str]]:
    """
    Parses a Linux .desktop file content and returns structured metadata.
    Returns None if entry is Hidden or NoDisplay=true.
    """
    if not raw_content:
        return None

    in_desktop_entry = False
    name: Optional[str] = None
    exec_cmd: Optional[str] = None
    icon: Optional[str] = None
    no_display = False
    hidden = False
    entry_type = "Application"

    for line in raw_content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_desktop_entry = line == "[Desktop Entry]"
            continue

        if not in_desktop_entry:
            continue

        parts = line.split("=", 1)
        if len(parts) != 2:
            continue

        key, val = parts[0].strip(), parts[1].strip()

        if key == "Name":
            name = val
        elif key == "Exec":
            # Strip field codes like %u, %F, %U, %i, %c, %k
            clean_exec = re.sub(r"%[a-zA-Z]", "", val).strip()
            exec_cmd = clean_exec
        elif key == "Icon":
            icon = val
        elif key == "NoDisplay" and val.lower() == "true":
            no_display = True
        elif key == "Hidden" and val.lower() == "true":
            hidden = True
        elif key == "Type":
            entry_type = val

    if no_display or hidden or entry_type != "Application" or not name or not exec_cmd:
        return None

    return {
        "name": name,
        "exec": exec_cmd,
        "icon": icon or "application-x-executable",
    }


def filter_applications(
    apps: List[Dict[str, str]],
    query: str
) -> List[Dict[str, str]]:
    """
    Performs case-insensitive substring search matching on name or exec command.
    """
    q = (query or "").strip().lower()
    if not q:
        return apps

    return [
        app for app in apps
        if q in app.get("name", "").lower() or q in app.get("exec", "").lower()
    ]


class TestDesktopIndexer(unittest.TestCase):
    """Rigorous tests for desktop entry parsing and query matching."""

    def test_standard_desktop_file(self):
        sample = """
        [Desktop Entry]
        Type=Application
        Name=Firefox Web Browser
        Exec=firefox %u
        Icon=firefox
        Terminal=false
        """
        parsed = parse_desktop_entry(sample)
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["name"], "Firefox Web Browser")
        self.assertEqual(parsed["exec"], "firefox")
        self.assertEqual(parsed["icon"], "firefox")

    def test_ghostty_desktop_entry(self):
        sample = """
        [Desktop Entry]
        Version=1.0
        Name=Ghostty
        Type=Application
        Exec=/usr/bin/ghostty --gtk-single-instance=true
        Icon=com.mitchellh.ghostty
        StartupWMClass=com.mitchellh.ghostty
        Terminal=false
        """
        parsed = parse_desktop_entry(sample)
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["name"], "Ghostty")
        self.assertEqual(parsed["exec"], "/usr/bin/ghostty --gtk-single-instance=true")
        self.assertEqual(parsed["icon"], "com.mitchellh.ghostty")

    def test_nodisplay_filtered_out(self):
        sample = """
        [Desktop Entry]
        Type=Application
        Name=Internal Helper
        Exec=/usr/bin/helper
        NoDisplay=true
        """
        self.assertIsNone(parse_desktop_entry(sample))

    def test_missing_exec_or_name(self):
        sample_no_exec = "[Desktop Entry]\nType=Application\nName=Broken"
        sample_no_name = "[Desktop Entry]\nType=Application\nExec=broken"
        self.assertIsNone(parse_desktop_entry(sample_no_exec))
        self.assertIsNone(parse_desktop_entry(sample_no_name))

    def test_filter_applications_matching(self):
        apps = [
            {"name": "Alacritty", "exec": "alacritty", "icon": "Alacritty"},
            {"name": "Firefox", "exec": "firefox", "icon": "firefox"},
            {"name": "Thunar", "exec": "thunar", "icon": "thunar"},
        ]
        res_f = filter_applications(apps, "fire")
        self.assertEqual(len(res_f), 1)
        self.assertEqual(res_f[0]["name"], "Firefox")

        res_empty = filter_applications(apps, "")
        self.assertEqual(len(res_empty), 3)

        res_none = filter_applications(apps, "nonexistent")
        self.assertEqual(len(res_none), 0)


if __name__ == "__main__":
    unittest.main()
