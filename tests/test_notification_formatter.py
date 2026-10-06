"""Unit tests for Notification Formatter and Sanitizer.

Enforces strict input validation, defensive sanitization, and deterministic
formatting for the Cocoa desktop notification system according to:
`{programa}:{mensaje}{hora}`
"""

import unittest
from datetime import datetime
from typing import Optional


class TestNotificationFormatter(unittest.TestCase):
    """Test suite covering notification sanitization, truncation, and layout."""

    def setUp(self) -> None:
        # Import target function inside test to enforce test-first workflow
        from scripts.notification_sanitizer import format_notification, sanitize_text
        self.format_notification = format_notification
        self.sanitize_text = sanitize_text

    def test_standard_notification_formatting(self) -> None:
        """Standard notification correctly formats {programa}:{mensaje}{hora}."""
        result = self.format_notification(
            app_name="Firefox",
            summary="Descarga completada",
            body="cocoa.tar.gz guardado",
            timestamp="12:05"
        )
        self.assertEqual(result, "Firefox:Descarga completada - cocoa.tar.gz guardado 12:05")

    def test_summary_only_formatting(self) -> None:
        """Notification with only summary."""
        result = self.format_notification(
            app_name="Discord",
            summary="Nuevo mensaje de Alice",
            body="",
            timestamp="14:30"
        )
        self.assertEqual(result, "Discord:Nuevo mensaje de Alice 14:30")

    def test_body_only_formatting(self) -> None:
        """Notification with empty summary but non-empty body."""
        result = self.format_notification(
            app_name="Terminal",
            summary="",
            body="Build finalizado con éxito",
            timestamp="09:15"
        )
        self.assertEqual(result, "Terminal:Build finalizado con éxito 09:15")

    def test_html_markup_stripping(self) -> None:
        """HTML tags in summary and body are completely stripped."""
        result = self.format_notification(
            app_name="Thunderbird",
            summary="<b>Correo Importante</b>",
            body="Reunión en <i>Google Meet</i> <a href='https://meet.google.com'>aquí</a>",
            timestamp="10:00"
        )
        self.assertEqual(result, "Thunderbird:Correo Importante - Reunión en Google Meet aquí 10:00")

    def test_newline_and_whitespace_sanitization(self) -> None:
        """Newlines, carriage returns, and tabs are collapsed into single spaces."""
        result = self.format_notification(
            app_name="Slack  \n\t",
            summary="Mensaje\ncon\r\nsaltos   de\tlínea",
            body="Detalle adicional  \n\n aquí",
            timestamp="11:45"
        )
        self.assertEqual(result, "Slack:Mensaje con saltos de línea - Detalle adicional aquí 11:45")

    def test_empty_app_name_fallback(self) -> None:
        """Empty or None app name falls back to desktop_entry or 'Sistema'."""
        result_with_desktop = self.format_notification(
            app_name="",
            summary="Alerta de batería",
            body="15% restante",
            timestamp="16:20",
            desktop_entry="org.freedesktop.upower"
        )
        self.assertEqual(result_with_desktop, "org.freedesktop.upower:Alerta de batería - 15% restante 16:20")

        result_fallback = self.format_notification(
            app_name=None,
            summary="Actualizaciones listas",
            body="",
            timestamp="16:20",
            desktop_entry=None
        )
        self.assertEqual(result_fallback, "Sistema:Actualizaciones listas 16:20")

    def test_completely_empty_notification(self) -> None:
        """Empty notification produces safe non-crashing fallback."""
        result = self.format_notification(
            app_name="",
            summary="",
            body="",
            timestamp="00:00"
        )
        self.assertEqual(result, "Sistema:Notificación 00:00")

    def test_summary_equals_app_name_deduplication(self) -> None:
        """When summary merely repeats app_name, it is deduplicated to avoid redundancy."""
        result = self.format_notification(
            app_name="Spotify",
            summary="Spotify",
            body="Playing track",
            timestamp="18:00"
        )
        self.assertEqual(result, "Spotify:Playing track 18:00")

    def test_truncation_limits_prevent_overflow(self) -> None:
        """Excessively long text is truncated cleanly with an ellipsis."""
        long_body = "A" * 200
        result = self.format_notification(
            app_name="Telegram",
            summary="Mensaje largo",
            body=long_body,
            timestamp="20:00",
            max_msg_length=50
        )
        # Should truncate message component cleanly
        self.assertTrue(result.startswith("Telegram:Mensaje largo - AAAAA"))
        self.assertTrue(result.endswith("… 20:00"))
        self.assertLessEqual(len(result), 85)

    def test_auto_timestamp_generation(self) -> None:
        """When timestamp is None, current local time HH:MM is generated."""
        now_str = datetime.now().strftime("%H:%M")
        result = self.format_notification(
            app_name="TestApp",
            summary="Ping",
            body="",
            timestamp=None
        )
        self.assertTrue(result.endswith(now_str))


if __name__ == "__main__":
    unittest.main()
