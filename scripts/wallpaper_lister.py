#!/usr/bin/env python3
"""
scripts/wallpaper_lister.py — Scans wallpaper directory and generates sorted JSON list.

Features:
- Scans ~/Pictures/Wallpapers (with fallback to ~/Pictures/wallpapers).
- Supports image formats: .jpg, .jpeg, .png, .webp, .bmp.
- Natural sort order (e.g. w1.jpg, w2.jpg, ..., w10.jpg).
- Outputs JSON array of objects: [{"path": "/abs/path", "name": "filename"}].
- Writes to /tmp/cocoa_wallpapers.json and prints to stdout with --json.
"""

import os
import sys
import json
import re
import argparse

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
DEFAULT_CACHE_FILE = "/tmp/cocoa_wallpapers.json"


def natural_sort_key(s: str):
    """Generates chunks for natural sorting (e.g., w1 < w2 < w10)."""
    return [int(token) if token.isdigit() else token.lower() for token in re.split(r"(\d+)", s)]


def get_default_wallpapers_dir() -> str:
    candidates = [
        os.path.expanduser("~/Pictures/Wallpapers"),
        os.path.expanduser("~/Pictures/wallpapers"),
    ]
    for path in candidates:
        if os.path.isdir(path):
            return path
    return candidates[0]


def list_wallpapers(target_dir: str = None):
    if not target_dir:
        target_dir = get_default_wallpapers_dir()

    if not os.path.isdir(target_dir):
        return []

    try:
        entries = os.listdir(target_dir)
    except OSError:
        return []

    valid_files = [
        f for f in entries
        if not f.startswith(".")
        and os.path.splitext(f)[1].lower() in SUPPORTED_EXTENSIONS
        and os.path.isfile(os.path.join(target_dir, f))
    ]

    valid_files.sort(key=natural_sort_key)

    result = []
    for f in valid_files:
        abs_path = os.path.abspath(os.path.join(target_dir, f))
        result.append({
            "path": abs_path,
            "name": f,
        })
    return result


def main():
    parser = argparse.ArgumentParser(description="Cocoa Wallpaper Lister")
    parser.add_argument("--json", action="store_true", help="Print JSON array to stdout")
    parser.add_argument("--dir", type=str, default=None, help="Target directory to scan")
    parser.add_argument("--output", type=str, default=DEFAULT_CACHE_FILE, help="Path to cache file")

    args = parser.parse_args()

    wallpapers = list_wallpapers(args.dir)
    json_text = json.dumps(wallpapers, indent=2)

    # Persist to cache file
    if args.output:
        try:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(json_text)
        except OSError as e:
            sys.stderr.write(f"Warning: could not write cache file {args.output}: {e}\n")

    if args.json:
        print(json_text)


if __name__ == "__main__":
    main()
