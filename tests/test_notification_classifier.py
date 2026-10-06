"""Unit tests for Notification Classifier (Hito 10).

Validates:
1. Detection of terminal emulators and shells.
2. AI Agent detection (Antigravity, Claude, ChatGPT, Aider, Cursor).
3. Mapping to characteristic ASCII glyphs and color palettes.
4. Desktop application brand color mapping (Spotify, Discord, Firefox, etc.).
5. Edge cases: empty/null inputs, case insensitivity, generic terminals.
"""

import unittest
from typing import Dict, Any


class TestNotificationClassifier(unittest.TestCase):
    """Test suite covering notification app and AI agent classification."""

    def setUp(self) -> None:
        from scripts.notification_classifier import classify_notification
        self.classify = classify_notification

    def test_antigravity_agent_in_terminal(self) -> None:
        """Terminal notification containing Antigravity or agy signature."""
        res = self.classify(
            app_name="kitty",
            summary="Antigravity",
            body="Task completed successfully",
            desktop_entry="kitty"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "▲")
        self.assertEqual(res["color"], "#8a63d2")
        self.assertEqual(res["agent_name"], "Antigravity")

    def test_gemini_keyword_detection(self) -> None:
        """Notification with gemini keyword identifies as Antigravity/Gemini agent."""
        res = self.classify(
            app_name="alacritty",
            summary="Gemini CLI",
            body="Review required"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "▲")
        self.assertEqual(res["color"], "#8a63d2")

    def test_claude_agent_detection(self) -> None:
        """Terminal notification containing Claude or Anthropic signature."""
        res = self.classify(
            app_name="foot",
            summary="Claude Code",
            body="Anthropic API response received"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "✻")
        self.assertEqual(res["color"], "#d97757")
        self.assertEqual(res["agent_name"], "Claude")

    def test_chatgpt_openai_agent_detection(self) -> None:
        """Notification mentioning ChatGPT or OpenAI."""
        res = self.classify(
            app_name="wezterm",
            summary="ChatGPT",
            body="Code generation finished via OpenAI"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "✳")
        self.assertEqual(res["color"], "#10a37f")
        self.assertEqual(res["agent_name"], "ChatGPT")

    def test_aider_agent_detection(self) -> None:
        """Notification from Aider coding agent."""
        res = self.classify(
            app_name="bash",
            summary="aider",
            body="Commit created: added unit tests"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "⯌")
        self.assertEqual(res["color"], "#3b82f6")
        self.assertEqual(res["agent_name"], "Aider")

    def test_cursor_agent_detection(self) -> None:
        """Notification from Cursor terminal/editor."""
        res = self.classify(
            app_name="cursor",
            summary="Cursor AI",
            body="Indexing finished"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "❯_")
        self.assertEqual(res["color"], "#00b4d8")
        self.assertEqual(res["agent_name"], "Cursor")

    def test_generic_terminal_without_agent(self) -> None:
        """Terminal notification without any AI agent keywords."""
        res = self.classify(
            app_name="kitty",
            summary="Make finished",
            body="Built target all in 4.2s"
        )
        self.assertTrue(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], ">_")
        self.assertEqual(res["color"], "#22c55e")
        self.assertEqual(res["agent_name"], "Terminal")

    def test_desktop_spotify_brand_color(self) -> None:
        """Spotify notification gets green brand color and standard icon flag."""
        res = self.classify(
            app_name="Spotify",
            summary="Dua Lipa",
            body="Levitating"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["ascii_icon"], "")
        self.assertEqual(res["color"], "#1db954")
        self.assertIsNone(res["agent_name"])

    def test_desktop_discord_brand_color(self) -> None:
        """Discord notification gets blurple brand color."""
        res = self.classify(
            app_name="Discord",
            summary="New message",
            body="Channel #general"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#5865f2")

    def test_desktop_firefox_brand_color(self) -> None:
        """Firefox notification gets orange brand color."""
        res = self.classify(
            app_name="Firefox",
            summary="Download Complete",
            body="cocoa.iso"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#ff7139")

    def test_desktop_telegram_brand_color(self) -> None:
        """Telegram notification gets blue brand color."""
        res = self.classify(
            app_name="Telegram Desktop",
            summary="Bob",
            body="Hello there!"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#24a1de")

    def test_desktop_steam_brand_color(self) -> None:
        """Steam notification gets slate navy brand color."""
        res = self.classify(
            app_name="Steam",
            summary="Friend Online",
            body="Alice is now online"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#2a475e")

    def test_default_fallback_brand_color(self) -> None:
        """Unknown application gets default accent color."""
        res = self.classify(
            app_name="UnknownApp",
            summary="Some alert",
            body="Something happened"
        )
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#7f99cc")
        self.assertEqual(res["ascii_icon"], "")

    def test_empty_and_none_inputs_safe_fallback(self) -> None:
        """Empty or None inputs return safe fallback without crashing."""
        res = self.classify(None, None, None, None)
        self.assertFalse(res["is_agent_or_terminal"])
        self.assertEqual(res["color"], "#7f99cc")
        self.assertEqual(res["ascii_icon"], "")
        self.assertIsNone(res["agent_name"])


if __name__ == "__main__":
    unittest.main()
