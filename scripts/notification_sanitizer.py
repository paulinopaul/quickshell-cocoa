#!/usr/bin/env python3
"""Notification Sanitizer and Formatter for Cocoa Desktop Shell.

Enforces defensive string cleaning, HTML stripping, length bounds,
and deterministic formatting following the contract:
`{programa}:{mensaje}{hora}` -> `{programa}:{mensaje} {hora}`
"""

import html
import re
import sys
from datetime import datetime
from typing import Optional

# Precompiled regex for performance and safety
TAG_RE: re.Pattern[str] = re.compile(r"<[^>]+>")
WHITESPACE_RE: re.Pattern[str] = re.compile(r"\s+")


def sanitize_text(text: Optional[str]) -> str:
    """Sanitizes text by removing HTML tags, unescaping entities, and collapsing whitespace.

    Args:
        text: Raw text string (may be None or empty).

    Returns:
        Clean, single-line sanitized string.
    """
    if not text:
        return ""

    assert isinstance(text, str), f"Expected str, got {type(text).__name__}"

    # Strip HTML tags
    cleaned = TAG_RE.sub(" ", text)

    # Unescape HTML entities (&amp; -> &, &lt; -> <, etc.)
    cleaned = html.unescape(cleaned)

    # Collapse all whitespace, tabs, and newlines into single spaces
    cleaned = WHITESPACE_RE.sub(" ", cleaned).strip()

    return cleaned


def format_notification(
    app_name: Optional[str],
    summary: Optional[str],
    body: Optional[str],
    timestamp: Optional[str] = None,
    desktop_entry: Optional[str] = None,
    max_msg_length: int = 70
) -> str:
    """Formats notification components into strict `{programa}:{mensaje} {hora}`.

    Args:
        app_name: Name of emitting application.
        summary: Short notification summary/title.
        body: Extended notification body.
        timestamp: Optional formatted time string (e.g., '12:05'). If None, uses local time.
        desktop_entry: Optional desktop file identifier for fallback naming.
        max_msg_length: Maximum allowed length for the message portion before ellipsis.

    Returns:
        Formatted notification text line.
    """
    # 1. Resolve and sanitize application name
    clean_app = sanitize_text(app_name)
    if not clean_app:
        clean_desktop = sanitize_text(desktop_entry)
        clean_app = clean_desktop if clean_desktop else "Sistema"

    # 2. Resolve and sanitize message parts
    clean_summary = sanitize_text(summary)
    clean_body = sanitize_text(body)

    # Deduplicate if summary is merely the application name
    if clean_summary.lower() == clean_app.lower():
        clean_summary = ""

    # Combine summary and body
    if clean_summary and clean_body:
        raw_msg = f"{clean_summary} - {clean_body}"
    elif clean_summary:
        raw_msg = clean_summary
    elif clean_body:
        raw_msg = clean_body
    else:
        raw_msg = "Notificación"

    # Truncate message if it exceeds safety bounds
    if len(raw_msg) > max_msg_length:
        clean_msg = raw_msg[:max_msg_length].rstrip() + "…"
    else:
        clean_msg = raw_msg

    # 3. Resolve timestamp (HH:mm)
    if timestamp:
        clean_time = sanitize_text(timestamp)
    else:
        clean_time = datetime.now().strftime("%H:%M")

    return f"{clean_app}:{clean_msg} {clean_time}"


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: notification_sanitizer.py <app> <summary> [body] [timestamp]")
        sys.exit(1)

    app_arg = sys.argv[1]
    summary_arg = sys.argv[2]
    body_arg = sys.argv[3] if len(sys.argv) > 3 else ""
    time_arg = sys.argv[4] if len(sys.argv) > 4 else None

    print(format_notification(app_arg, summary_arg, body_arg, time_arg))
