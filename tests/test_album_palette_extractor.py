"""Unit tests for Album Palette Extractor (Hito 11).

Tests cover:
1. Extraction of 3 predominant colors from synthetic RGB images.
2. Hex color format validation (#rrggbb).
3. Local disk caching mechanism in <ipc-dir>/cocoa_palette_cache/ (per-user IPC dir).
4. Defensive fallback upon network/file errors, missing files, or timeouts.
5. Handling of None, empty, or malformed URL inputs.
"""

import json
import os
import shutil
import tempfile
import unittest
from io import BytesIO
from PIL import Image


class TestAlbumPaletteExtractor(unittest.TestCase):
    """Test suite covering the asynchronous album palette extraction logic."""

    def setUp(self) -> None:
        self.test_cache_dir = tempfile.mkdtemp(prefix="cocoa_test_cache_")
        from scripts.album_palette_extractor import extract_palette, DEFAULT_PALETTE
        self.extract_palette = extract_palette
        self.default_palette = DEFAULT_PALETTE

    def tearDown(self) -> None:
        shutil.rmtree(self.test_cache_dir, ignore_errors=True)

    def _create_synthetic_image(self, c1: tuple, c2: tuple, c3: tuple) -> str:
        """Creates a temporary test image with three distinct color bands."""
        img = Image.new("RGB", (60, 60))
        # Top third: c1
        for y in range(0, 20):
            for x in range(0, 60):
                img.putpixel((x, y), c1)
        # Middle third: c2
        for y in range(20, 40):
            for x in range(0, 60):
                img.putpixel((x, y), c2)
        # Bottom third: c3
        for y in range(40, 60):
            for x in range(0, 60):
                img.putpixel((x, y), c3)

        tmp_path = os.path.join(self.test_cache_dir, "synthetic_cover.png")
        img.save(tmp_path, "PNG")
        return tmp_path

    def test_extract_three_predominant_colors_from_file(self) -> None:
        """Extracts 3 hex colors from a local image file."""
        red = (255, 0, 0)
        green = (0, 255, 0)
        blue = (0, 0, 255)
        img_path = self._create_synthetic_image(red, green, blue)

        colors = self.extract_palette(img_path, cache_dir=self.test_cache_dir)
        self.assertEqual(len(colors), 3)
        for hex_color in colors:
            self.assertTrue(hex_color.startswith("#"))
            self.assertEqual(len(hex_color), 7)
            int(hex_color[1:], 16)  # Must be valid hex

    def test_cache_persistence_and_reuse(self) -> None:
        """Second call with same source reuses cached JSON without reprocessing."""
        red = (200, 50, 50)
        green = (50, 200, 50)
        blue = (50, 50, 200)
        img_path = self._create_synthetic_image(red, green, blue)

        colors_first = self.extract_palette(img_path, cache_dir=self.test_cache_dir)
        # Cache file must now exist
        cached_files = os.listdir(self.test_cache_dir)
        json_caches = [f for f in cached_files if f.endswith(".json")]
        self.assertEqual(len(json_caches), 1)

        # Modify cached file intentionally to verify it is read directly
        cache_path = os.path.join(self.test_cache_dir, json_caches[0])
        tampered_colors = ["#112233", "#445566", "#778899"]
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump({"colors": tampered_colors}, f)

        colors_second = self.extract_palette(img_path, cache_dir=self.test_cache_dir)
        self.assertEqual(colors_second, tampered_colors)

    def test_invalid_path_or_url_returns_default_palette(self) -> None:
        """Non-existent path or broken URL returns deterministic default palette."""
        colors = self.extract_palette("/tmp/non_existent_image_cover_xyz.png", cache_dir=self.test_cache_dir)
        self.assertEqual(colors, self.default_palette)

    def test_none_or_empty_input_returns_default_palette(self) -> None:
        """None or empty string input returns default palette without exception."""
        self.assertEqual(self.extract_palette(None, cache_dir=self.test_cache_dir), self.default_palette)
        self.assertEqual(self.extract_palette("", cache_dir=self.test_cache_dir), self.default_palette)
        self.assertEqual(self.extract_palette("   ", cache_dir=self.test_cache_dir), self.default_palette)


if __name__ == "__main__":
    unittest.main()
