#!/usr/bin/env python3
"""Spotify Metadata Provider for Hyprlock.

Exclusively queries Spotify (ignoring all other MPRIS players).
Returns Pango Markup formatted string only when playback status is 'Playing'.
If paused, stopped, or closed, prints nothing (empty string).
"""

import html
import subprocess
import sys


def format_spotify_status(status: str | None, artist: str | None, title: str | None) -> str:
    """Format Spotify playback status into sanitized Pango markup.

    Args:
        status: Player status ("Playing", "Paused", etc.).
        artist: Track artist.
        title: Track title.

    Returns:
        Formatted Pango markup string if playing, otherwise empty string.
    """
    if not status or status.strip() != "Playing":
        return ""

    raw_title = (title or "").strip()
    raw_artist = (artist or "").strip()

    if not raw_title and not raw_artist:
        return ""

    # Truncamiento defensivo
    max_title_len = 32
    max_artist_len = 24

    if len(raw_title) > max_title_len:
        raw_title = raw_title[: max_title_len - 3] + "..."
    if len(raw_artist) > max_artist_len:
        raw_artist = raw_artist[: max_artist_len - 3] + "..."

    safe_title = html.escape(raw_title)
    safe_artist = html.escape(raw_artist)

    # Glifo Spotify de JetBrainsMono Nerd Font (\uf1bc = )
    spotify_icon = '<span foreground="#1db954"></span>'

    if safe_artist:
        return f'{spotify_icon}  <span foreground="#e0e6f0" weight="bold">{safe_title}</span>  <span foreground="#7f99cc">•  {safe_artist}</span>'
    return f'{spotify_icon}  <span foreground="#e0e6f0" weight="bold">{safe_title}</span>'


def get_spotify_playback() -> str:
    """Query playerctl specifically for Spotify."""
    try:
        # Consulta de estado exclusiva a Spotify con timeout estricto
        status_proc = subprocess.run(
            ["playerctl", "-p", "spotify", "status"],
            capture_output=True,
            text=True,
            timeout=1.0,
            check=False,
        )
        if status_proc.returncode != 0:
            return ""

        status = status_proc.stdout.strip()
        if status != "Playing":
            return ""

        # Consulta de metadatos
        meta_proc = subprocess.run(
            ["playerctl", "-p", "spotify", "metadata", "--format", "{{ artist }}|{{ title }}"],
            capture_output=True,
            text=True,
            timeout=1.0,
            check=False,
        )
        if meta_proc.returncode != 0 or not meta_proc.stdout:
            return ""

        parts = meta_proc.stdout.strip().split("|", 1)
        artist = parts[0] if len(parts) > 0 else ""
        title = parts[1] if len(parts) > 1 else ""

        return format_spotify_status(status, artist, title)
    except Exception:
        # Fail-safe absoluto: nunca emitir trazas de error en hyprlock
        return ""


if __name__ == "__main__":
    output = get_spotify_playback()
    if output:
        sys.stdout.write(output + "\n")
    sys.exit(0)
