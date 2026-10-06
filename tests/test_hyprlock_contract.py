"""Contract tests for Hyprlock Minimalist Screen Blur and Unlock Transition.

Enforces:
1. Dynamic background uses live screen capture (path = screenshot) with GPU blur passes.
2. Password input field is hidden when empty (fade_on_empty = true) until user types.
3. Animations block defines fadeOut transition for smooth blur dissipation upon unlock.
4. Minimalist labels display time ($TIME) and localized date.
"""

import os
import re
import unittest

HYPRLOCK_CONF_PATH = os.path.expanduser("~/.config/hypr/hyprlock.conf")


class TestHyprlockContract(unittest.TestCase):
    """Behavioral and structural contract validation for hyprlock.conf."""

    @classmethod
    def setUpClass(cls) -> None:
        if not os.path.exists(HYPRLOCK_CONF_PATH):
            raise FileNotFoundError(f"Missing {HYPRLOCK_CONF_PATH}")
        with open(HYPRLOCK_CONF_PATH, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_background_uses_live_screenshot_with_blur(self) -> None:
        """Background must capture live desktop and apply multi-pass blur."""
        self.assertTrue(
            re.search(r"path\s*=\s*screenshot", self.content),
            "hyprlock background must declare 'path = screenshot' for live desktop blur",
        )
        blur_match = re.search(r"blur_passes\s*=\s*(\d+)", self.content)
        self.assertIsNotNone(blur_match, "Must declare blur_passes")
        self.assertGreaterEqual(
            int(blur_match.group(1)),
            3,
            "blur_passes must be at least 3 for smooth Gaussian dispersion",
        )

    def test_input_field_hidden_when_empty(self) -> None:
        """Input field must declare fade_on_empty = true to remain hidden until keypress."""
        self.assertTrue(
            re.search(r"fade_on_empty\s*=\s*true", self.content),
            "input-field must declare 'fade_on_empty = true'",
        )

    def test_fade_out_animation_declared_and_slow(self) -> None:
        """Animations block must configure slow cinematic fadeOut (speed >= 7)."""
        self.assertIn("animations", self.content)
        match = re.search(r"animation\s*=\s*fadeOut,\s*1,\s*(\d+)", self.content)
        self.assertIsNotNone(match, "hyprlock must declare animation = fadeOut, 1, <speed>")
        speed = int(match.group(1))
        self.assertGreaterEqual(
            speed,
            7,
            f"fadeOut animation speed must be >= 7 for slow cinematic dissipation, got {speed}",
        )

    def test_spotify_widget_declared_in_config(self) -> None:
        """Hyprlock must include a dynamic label running hyprlock_spotify.py."""
        self.assertTrue(
            re.search(r"hyprlock_spotify\.py", self.content),
            "hyprlock.conf must declare a label invoking hyprlock_spotify.py",
        )

    def test_date_and_time_labels_present(self) -> None:
        """Time and date labels must be configured cleanly."""
        self.assertIn("$TIME", self.content, "Must display $TIME label")
        self.assertTrue(
            re.search(r"date", self.content),
            "Must declare date command label for calendar date",
        )


if __name__ == "__main__":
    unittest.main()

