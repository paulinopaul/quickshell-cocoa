"""Unit tests for Hyprlock Spotify metadata sanitizer and formatter.

Enforces:
1. Strict exclusivity: Only Spotify is queried; returns empty string if paused, stopped, or closed.
2. HTML/Pango escaping: Characters like &, <, > are converted to XML entities.
3. Safe truncation: Excessively long titles or artists are clamped to prevent visual overflow.
4. Pango markup formatting: Embeds Spotify icon () and stylized spans.
"""

import sys
import os
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(PROJECT_ROOT, "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

try:
    from hyprlock_spotify import format_spotify_status
except ImportError:
    format_spotify_status = None


class TestHyprlockSpotifySanitizer(unittest.TestCase):
    """Test suite for format_spotify_status."""

    def setUp(self) -> None:
        if format_spotify_status is None:
            self.fail("Could not import format_spotify_status from scripts.hyprlock_spotify")

    def test_spotify_not_playing_returns_empty(self) -> None:
        """Any status other than 'Playing' must produce an empty string."""
        self.assertEqual(format_spotify_status("Paused", "Queen", "Bohemian Rhapsody"), "")
        self.assertEqual(format_spotify_status("Stopped", "Queen", "Bohemian Rhapsody"), "")
        self.assertEqual(format_spotify_status("", "Queen", "Bohemian Rhapsody"), "")
        self.assertEqual(format_spotify_status(None, "Queen", "Bohemian Rhapsody"), "")

    def test_spotify_playing_returns_formatted_pango(self) -> None:
        """When playing, output must contain the Spotify glyph and formatted metadata."""
        out = format_spotify_status("Playing", "Daft Punk", "Get Lucky")
        self.assertIn("", out)
        self.assertIn("Get Lucky", out)
        self.assertIn("Daft Punk", out)
        self.assertTrue(out.startswith("<span"))

    def test_html_escaping(self) -> None:
        """Special characters that break Pango markup must be escaped safely."""
        out = format_spotify_status("Playing", "AC/DC & Friends", "Highway <to> Hell")
        self.assertIn("&amp;", out)
        self.assertIn("&lt;to&gt;", out)
        self.assertNotIn("Highway <to>", out)

    def test_safe_truncation_limits(self) -> None:
        """Long titles must be truncated cleanly with an ellipsis."""
        long_title = "A" * 60
        out = format_spotify_status("Playing", "Artist", long_title)
        self.assertIn("...", out)
        self.assertNotIn("A" * 60, out)

    def test_missing_artist_fallback(self) -> None:
        """Missing or empty artist should handle gracefully without crashing."""
        out = format_spotify_status("Playing", "", "Solo Track")
        self.assertIn("Solo Track", out)
        self.assertIn("", out)


if __name__ == "__main__":
    unittest.main()
