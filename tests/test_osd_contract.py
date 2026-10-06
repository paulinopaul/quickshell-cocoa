#!/usr/bin/env python3
"""
Unit and static contract tests for Cocoa OSD Window (modules/osd/OsdWindow.qml).
Enforces Rule 12 (TDD Mandate) and architectural requirements for click-through
and proper Wayland layer-shell surface lifecycle.
"""

import os
import re
import unittest
from pathlib import Path


class TestOsdWindowContract(unittest.TestCase):
    """Verifies that OsdWindow complies with the non-intrusive HUD architecture."""

    @classmethod
    def setUpClass(cls):
        cls.repo_root = Path(__file__).resolve().parent.parent
        cls.osd_file = cls.repo_root / "modules" / "osd" / "OsdWindow.qml"
        if not cls.osd_file.exists():
            raise FileNotFoundError(f"OSD file not found: {cls.osd_file}")
        with open(cls.osd_file, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_empty_mask_region_present(self):
        """Rule: mask must be set to Region {} to guarantee 100% click-through."""
        pattern = r"mask\s*:\s*Region\s*\{"
        self.assertRegex(
            self.content,
            pattern,
            "OsdWindow.qml must define 'mask: Region {}' for complete pointer click-through.",
        )

    def test_namespace_declared(self):
        """Rule: WlrLayershell.namespace must be explicitly defined as 'cocoa-osd'."""
        pattern = r'WlrLayershell\.namespace\s*:\s*"cocoa-osd"'
        self.assertRegex(
            self.content,
            pattern,
            'OsdWindow.qml must specify WlrLayershell.namespace: "cocoa-osd"',
        )

    def test_no_hardcoded_visible_true(self):
        """Rule: visible must not be statically hardcoded to true."""
        lines = self.content.splitlines()
        for idx, line in enumerate(lines, start=1):
            stripped = line.strip()
            # Check top-level window property visible: true
            if re.match(r"^visible\s*:\s*true\b", stripped):
                self.fail(
                    f"Line {idx} in OsdWindow.qml has static 'visible: true'. "
                    "Visibility must be dynamically bound to osdVisible and animation state."
                )

    def test_dynamic_visibility_binding(self):
        """Rule: visible property must bind to osdVisible or animation opacity."""
        pattern = r"visible\s*:\s*.*osdVisible"
        self.assertRegex(
            self.content,
            pattern,
            "OsdWindow.qml must dynamically tie 'visible' to osdVisible.",
        )

    def test_no_blocking_mouse_areas(self):
        """Rule: An OSD HUD is non-interactive; it must not contain MouseAreas."""
        # Find any MouseArea in OsdWindow
        mouse_areas = re.findall(r"\bMouseArea\b", self.content)
        self.assertEqual(
            len(mouse_areas),
            0,
            f"OsdWindow.qml must not contain MouseArea components; found {len(mouse_areas)}.",
        )


if __name__ == "__main__":
    unittest.main()
