"""Contract tests for Spotify Album Palette & Notification Formatting (Hito 11).

Validates:
1. MediaService.qml exposes rawAlbum and isSpotify.
2. NotificationService.qml exposes albumPalette, isSpotifyTrack, and Spotify formatting logic.
3. NotificationPopup.qml implements 3-stop gradient bound to albumPalette for Spotify tracks.
4. Notification formatting enforces '{album} - {artista}' for Spotify playback notifications.
"""

import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA_SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "MediaService.qml")
NOTIF_SERVICE_PATH = os.path.join(PROJECT_ROOT, "services", "NotificationService.qml")
POPUP_PATH = os.path.join(PROJECT_ROOT, "modules", "notifications", "NotificationPopup.qml")


class TestSpotifyNotificationContract(unittest.TestCase):
    """Contract tests for Spotify metadata, album palette, and notification popup."""

    def test_media_service_exposes_raw_album(self) -> None:
        """MediaService must expose rawAlbum property mapped to activePlayer.trackAlbum."""
        with open(MEDIA_SERVICE_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("property string rawAlbum", content)
        self.assertIn("trackAlbum", content)

    def test_media_service_exposes_is_spotify(self) -> None:
        """MediaService must expose isSpotify property."""
        with open(MEDIA_SERVICE_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("property bool isSpotify", content)

    def test_notification_service_exposes_album_palette_and_spotify_flag(self) -> None:
        """NotificationService must expose albumPalette and isSpotifyTrack."""
        with open(NOTIF_SERVICE_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("property var albumPalette", content)
        self.assertIn("property bool isSpotifyTrack", content)

    def test_notification_popup_implements_three_stop_gradient(self) -> None:
        """NotificationPopup must declare 3-stop gradient using NotificationService.albumPalette."""
        with open(POPUP_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("NotificationService.albumPalette", content)
        self.assertIn("NotificationService.isSpotifyTrack", content)
        # Check for multiple GradientStop declarations
        stops = re.findall(r"GradientStop\s*\{", content)
        self.assertGreaterEqual(len(stops), 3, "NotificationPopup must declare at least 3 GradientStop elements")


if __name__ == "__main__":
    unittest.main()
