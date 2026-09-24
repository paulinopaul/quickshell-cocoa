#!/usr/bin/env python3
"""
Unit tests for MPRIS media metadata sanitizer and fallback formatting.
Enforces Rule 12 (TDD Mandate) and Rule 13 (Edge Cases & Boundaries).
"""

import unittest
from typing import List, Optional, Union


def sanitize_mpris_metadata(
    title: Optional[str],
    artists: Optional[Union[List[str], str]],
    max_length: int = 32
) -> str:
    """
    Sanitizes track title and artist list into a formatted, truncated display string.
    Returns fallback string if no valid metadata is supplied.
    """
    clean_title = (title or "").strip()
    
    if isinstance(artists, list):
        clean_artists = ", ".join(filter(None, [a.strip() for a in artists]))
    elif isinstance(artists, str):
        clean_artists = artists.strip()
    else:
        clean_artists = ""

    if not clean_title and not clean_artists:
        return "No Media Playing"

    if clean_title and clean_artists:
        full_text = f"{clean_artists} - {clean_title}"
    else:
        full_text = clean_title or clean_artists

    if len(full_text) > max_length:
        return full_text[: max_length - 3] + "..."
    return full_text


def format_duration(seconds: float) -> str:
    """Formats playback seconds into MM:SS format with bounds check."""
    if seconds < 0 or seconds != seconds:  # NaN check
        return "00:00"
    total_sec = int(seconds)
    minutes = total_sec // 60
    rem_sec = total_sec % 60
    return f"{minutes:02d}:{rem_sec:02d}"


class TestMprisSanitizer(unittest.TestCase):
    """Test suite covering normal and boundary conditions for media display."""

    def test_both_artist_and_title(self):
        res = sanitize_mpris_metadata("Starboy", ["The Weeknd", "Daft Punk"], max_length=50)
        self.assertEqual(res, "The Weeknd, Daft Punk - Starboy")

    def test_truncation_with_ellipsis(self):
        res = sanitize_mpris_metadata(
            "An Extremely Long Song Title That Exceeds Normal Limits",
            ["Famous Artist"],
            max_length=25
        )
        self.assertEqual(len(res), 25)
        self.assertTrue(res.endswith("..."))

    def test_missing_artist(self):
        res = sanitize_mpris_metadata("Standalone Track", None, max_length=40)
        self.assertEqual(res, "Standalone Track")

    def test_missing_title(self):
        res = sanitize_mpris_metadata(None, ["Artist Only"], max_length=40)
        self.assertEqual(res, "Artist Only")

    def test_completely_empty_metadata(self):
        res = sanitize_mpris_metadata(None, None)
        self.assertEqual(res, "No Media Playing")
        res_empty = sanitize_mpris_metadata("   ", ["", "  "])
        self.assertEqual(res_empty, "No Media Playing")

    def test_duration_formatting(self):
        self.assertEqual(format_duration(0), "00:00")
        self.assertEqual(format_duration(65), "01:05")
        self.assertEqual(format_duration(3600), "60:00")
        self.assertEqual(format_duration(-10), "00:00")


if __name__ == "__main__":
    unittest.main()
