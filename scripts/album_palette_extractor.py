#!/usr/bin/env python3
"""Album Palette Extractor for Cocoa Shell.

Extracts the 3 predominant colors from album art (local path or remote URL)
using PIL median-cut quantization, with local disk caching and defensive fallbacks.
Outputs JSON: {"colors": ["#hex1", "#hex2", "#hex3"]}
"""

import hashlib
import json
import os
import sys
import urllib.request
from io import BytesIO
from typing import List, Optional
from PIL import Image

try:
    from scripts.cocoa_ipc import ipc_path
except ImportError:  # standalone execution (scripts/ is sys.path[0])
    from cocoa_ipc import ipc_path

DEFAULT_PALETTE: List[str] = ["#1db954", "#1ed760", "#0f381e"]
DEFAULT_CACHE_DIR = ipc_path("cocoa_palette_cache")


def _to_hex(r: int, g: int, b: int) -> str:
    """Formats RGB integers to #rrggbb lowercase string."""
    return f"#{max(0, min(255, r)):02x}{max(0, min(255, g)):02x}{max(0, min(255, b)):02x}"


def extract_palette(
    source: Optional[str],
    cache_dir: str = DEFAULT_CACHE_DIR
) -> List[str]:
    """Extracts 3 predominant colors from an image source (path or URL).

    Args:
        source: Local file path or http/https URL.
        cache_dir: Directory where JSON palette caches are stored.

    Returns:
        List of 3 hex color strings.
    """
    if not source or not isinstance(source, str) or not source.strip():
        return list(DEFAULT_PALETTE)

    clean_source = source.strip()

    # 1. Check disk cache
    os.makedirs(cache_dir, exist_ok=True)
    source_hash = hashlib.md5(clean_source.encode("utf-8")).hexdigest()
    cache_file = os.path.join(cache_dir, f"{source_hash}.json")

    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                cached_colors = data.get("colors")
                if isinstance(cached_colors, list) and len(cached_colors) == 3:
                    return cached_colors
        except Exception:
            pass  # Fall through to re-extraction

    # 2. Acquire image buffer
    img_bytes: Optional[bytes] = None
    try:
        if clean_source.startswith("http://") or clean_source.startswith("https://"):
            req = urllib.request.Request(
                clean_source,
                headers={"User-Agent": "Mozilla/5.0 (compatible; CocoaShell/1.0)"}
            )
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                img_bytes = resp.read()
        elif clean_source.startswith("file://"):
            local_path = clean_source[7:]
            with open(local_path, "rb") as f:
                img_bytes = f.read()
        else:
            if os.path.exists(clean_source):
                with open(clean_source, "rb") as f:
                    img_bytes = f.read()
            else:
                return list(DEFAULT_PALETTE)
    except Exception:
        return list(DEFAULT_PALETTE)

    if not img_bytes:
        return list(DEFAULT_PALETTE)

    # 3. Process image with PIL
    try:
        img = Image.open(BytesIO(img_bytes)).convert("RGB")
        # Resize to 48x48 for sub-millisecond quantization
        img = img.resize((48, 48), Image.Resampling.BILINEAR)

        # Median-cut quantization to 3 colors
        quantized = img.quantize(colors=3, method=Image.Quantize.MEDIANCUT)
        raw_palette = quantized.getpalette()
        if not raw_palette or len(raw_palette) < 9:
            return list(DEFAULT_PALETTE)

        extracted: List[str] = []
        for i in range(0, 9, 3):
            hex_c = _to_hex(raw_palette[i], raw_palette[i + 1], raw_palette[i + 2])
            extracted.append(hex_c)

        # Ensure we have exactly 3 colors
        while len(extracted) < 3:
            extracted.append(DEFAULT_PALETTE[len(extracted)])

        # Save to disk cache
        try:
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump({"colors": extracted}, f)
        except Exception:
            pass

        return extracted
    except Exception:
        return list(DEFAULT_PALETTE)


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else ""
    palette = extract_palette(src)
    print(json.dumps({"colors": palette}))
