#!/usr/bin/env python3
"""Notification Classifier for Cocoa Desktop Shell.

Determines application branding, terminal agent status, and associated
ASCII glyphs and hex gradient colors according to:
- Terminal emulators: kitty, alacritty, foot, konsole, wezterm, etc.
- AI Agents: Antigravity (▲), Claude (✻), ChatGPT (✳), Aider (⯌), Cursor (❯_), Terminal (>_)
- Desktop apps: Spotify, Discord, Firefox, Telegram, Steam, Fallback
"""

import re
import sys
from typing import Any, Dict, List, Optional, Tuple

TERMINAL_IDENTIFIERS: List[str] = [
    "kitty",
    "alacritty",
    "foot",
    "konsole",
    "wezterm",
    "gnome-terminal",
    "xterm",
    "bash",
    "zsh",
    "fish",
    "terminal",
    "urxvt",
    "st",
    "tilix",
]

# Agent configurations: (name, keywords, ascii_icon, color)
AGENT_SPECS: List[Tuple[str, List[str], str, str]] = [
    ("Antigravity", ["antigravity", "agy", "gemini"], "▲", "#8a63d2"),
    ("Claude", ["claude", "anthropic"], "✻", "#d97757"),
    ("ChatGPT", ["chatgpt", "openai", "gpt"], "✳", "#10a37f"),
    ("Aider", ["aider"], "⯌", "#3b82f6"),
    ("Cursor", ["cursor"], "❯_", "#00b4d8"),
]

# Desktop application brand colors
DESKTOP_BRAND_COLORS: Dict[str, str] = {
    "spotify": "#1db954",
    "discord": "#5865f2",
    "firefox": "#ff7139",
    "telegram": "#24a1de",
    "steam": "#2a475e",
}

DEFAULT_ACCENT_COLOR = "#7f99cc"
GENERIC_TERMINAL_ICON = ">_"
GENERIC_TERMINAL_COLOR = "#22c55e"


def classify_notification(
    app_name: Optional[str] = None,
    summary: Optional[str] = None,
    body: Optional[str] = None,
    desktop_entry: Optional[str] = None
) -> Dict[str, Any]:
    """Classifies a notification to determine terminal/agent status, ASCII icon, and color.

    Args:
        app_name: Originating application name.
        summary: Notification summary line.
        body: Notification body text.
        desktop_entry: Optional desktop file entry ID.

    Returns:
        Dict containing:
            - is_agent_or_terminal: bool
            - agent_name: Optional[str]
            - ascii_icon: str
            - color: str
    """
    app_str = (app_name or "").lower().strip()
    desktop_str = (desktop_entry or "").lower().strip()
    summary_str = (summary or "").lower().strip()
    body_str = (body or "").lower().strip()

    combined_context = f"{app_str} {desktop_str} {summary_str} {body_str}".strip()

    def _matches_terminal(text: str) -> bool:
        if not text:
            return False
        for term in TERMINAL_IDENTIFIERS:
            if len(term) <= 3:
                if re.search(rf"\b{re.escape(term)}\b", text):
                    return True
            else:
                if term in text:
                    return True
        return False

    # 1. Check if originating from a terminal emulator or shell
    is_terminal = _matches_terminal(app_str) or _matches_terminal(desktop_str)

    # 2. Check for AI Agent signatures
    for agent_name, keywords, ascii_icon, color in AGENT_SPECS:
        for kw in keywords:
            # Check for exact word or substring in combined context
            pattern = rf"\b{re.escape(kw)}\b" if len(kw) <= 3 else re.escape(kw)
            if re.search(pattern, combined_context):
                return {
                    "is_agent_or_terminal": True,
                    "agent_name": agent_name,
                    "ascii_icon": ascii_icon,
                    "color": color,
                }

    # 3. If originating from terminal without specific agent detected
    if is_terminal:
        return {
            "is_agent_or_terminal": True,
            "agent_name": "Terminal",
            "ascii_icon": GENERIC_TERMINAL_ICON,
            "color": GENERIC_TERMINAL_COLOR,
        }

    # 4. Standard Desktop Applications
    for brand_key, brand_color in DESKTOP_BRAND_COLORS.items():
        if brand_key in app_str or brand_key in desktop_str:
            return {
                "is_agent_or_terminal": False,
                "agent_name": None,
                "ascii_icon": "",
                "color": brand_color,
            }

    # 5. Fallback for generic desktop apps
    return {
        "is_agent_or_terminal": False,
        "agent_name": None,
        "ascii_icon": "",
        "color": DEFAULT_ACCENT_COLOR,
    }


if __name__ == "__main__":
    app = sys.argv[1] if len(sys.argv) > 1 else ""
    sum_text = sys.argv[2] if len(sys.argv) > 2 else ""
    body_text = sys.argv[3] if len(sys.argv) > 3 else ""
    desk = sys.argv[4] if len(sys.argv) > 4 else ""
    result = classify_notification(app, sum_text, body_text, desk)
    print(f"Agent/Terminal: {result['is_agent_or_terminal']}")
    print(f"Agent Name: {result['agent_name']}")
    print(f"ASCII Icon: {result['ascii_icon']}")
    print(f"Color: {result['color']}")
