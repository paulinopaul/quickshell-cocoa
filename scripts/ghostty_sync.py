#!/usr/bin/env python3
"""
ghostty_sync.py — Single fail-soft funnel that keeps Ghostty in lockstep with
the Cocoa system palette.

Every palette change (named preset, manual hex, auto-from-wallpaper) lands in
`theme/current_theme.json`; this script is the only place that translates that
file into the REAL ghostty state:

  1. Named theme (`terminalTheme` in the JSON)  -> ghostty `theme = <name>`.
  2. Dynamic palette (no `terminalTheme`)        -> derives a 16-color ANSI
     ramp, writes `~/.config/ghostty/themes/Cocoa Dynamic`, then sets
     `theme = Cocoa Dynamic`.
  3. Either way it keeps `background-opacity` / `background-blur` in sync from
     `theme/ui_config.json` and rewrites `~/.config/ghostty/active_theme.sh`
     (GHOSTTY_THEME export + OSC 10/11/4 color sequences for shells).

It never touches `ui_config.json` ghostty.theme — the settings UI owns that.

Fail-soft contract: missing/unparseable current_theme.json exits 0 silently;
any write failure prints a warning to stderr and still exits 0, so the palette
funnel is never blocked by ghostty sync problems.

--dry-run prints the exact plan JSON without writing anything; --config-dir /
--themes-dir / --theme-json / --ui-config redirect the write targets so tests
stay hermetic.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

COCOA_DIR = Path(__file__).resolve().parent.parent
THEME_JSON = COCOA_DIR / "theme/current_theme.json"
UI_CONFIG_JSON = COCOA_DIR / "theme/ui_config.json"
DEFAULT_GHOSTTY_DIR = Path.home() / ".config/ghostty"

DYNAMIC_THEME_NAME = "Cocoa Dynamic"
FALLBACK_BACKGROUND = "#0e1017"
FALLBACK_FOREGROUND = "#eceff4"
FALLBACK_ACCENT = "#88c0d0"
FALLBACK_OPACITY = 0.95
FALLBACK_BLUR = 24

# ---------------------------------------------------------------------------
# Color helpers — simple shade math
# ---------------------------------------------------------------------------


def parse_hex(color: str) -> Tuple[int, int, int]:
    """Parses '#rgb'/'#rrggbb' into a (r, g, b) tuple (0-255)."""
    cleaned = color.strip().lstrip("#")
    if len(cleaned) == 3:
        cleaned = "".join(c * 2 for c in cleaned)
    if len(cleaned) != 6:
        raise ValueError(f"Color hexadecimal inválido: '{color}'")
    return (int(cleaned[0:2], 16), int(cleaned[2:4], 16), int(cleaned[4:6], 16))


def _clamp255(value: float) -> int:
    return max(0, min(255, int(round(value))))


def rgb_to_hex(rgb: Tuple[int, int, int]) -> str:
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"


def mix(color_a: str, color_b: str, t: float) -> str:
    """Linear blend between two hex colors; t=0 -> color_a, t=1 -> color_b."""
    a = parse_hex(color_a)
    b = parse_hex(color_b)
    return rgb_to_hex(tuple(_clamp255(a[i] + (b[i] - a[i]) * t) for i in range(3)))


def shade(color: str, t: float) -> str:
    """Mixes a color toward black by factor t (shade math)."""
    return mix(color, "#000000", t)


def tint(color: str, t: float) -> str:
    """Mixes a color toward white by factor t (shade math)."""
    return mix(color, "#ffffff", t)


def derive_ansi_palette(theme: Dict[str, Any]) -> List[str]:
    """Builds the 16-color ANSI ramp from the palette tokens (shade math).

    Ordering follows the standard terminal scheme (black, red, green, yellow,
    blue, magenta, cyan, white, then bright variants). The ramp is accent-led:
    the accent becomes the "green" member and its shade/tint variants fill the
    other chromatic slots, while the neutral slots lean on the theme surface
    tokens (dark shades from background/surfaceDark, bright shades from
    text/surfaceRaised) so the ramp stays legible on the theme background.
    """
    accent = theme.get("accent", FALLBACK_ACCENT)
    background = theme.get("background", FALLBACK_BACKGROUND)
    text = theme.get("text", FALLBACK_FOREGROUND)
    surface_dark = theme.get("surfaceDark", background)
    surface_raised = theme.get("surfaceRaised", mix(text, background, 0.5))

    red = shade(accent, 0.60)
    green = accent
    yellow = tint(accent, 0.35)
    blue = shade(accent, 0.35)
    magenta = tint(accent, 0.55)
    cyan = tint(accent, 0.20)
    white = text

    return [
        background,          # 0  black
        red,                 # 1  red
        green,               # 2  green
        yellow,              # 3  yellow
        blue,                # 4  blue
        magenta,             # 5  magenta
        cyan,                # 6  cyan
        white,               # 7  white
        surface_dark,        # 8  bright black
        tint(red, 0.30),     # 9  bright red
        tint(accent, 0.25),  # 10 bright green
        tint(yellow, 0.40),  # 11 bright yellow
        tint(blue, 0.35),    # 12 bright blue
        tint(magenta, 0.30), # 13 bright magenta
        tint(cyan, 0.45),    # 14 bright cyan
        surface_raised,      # 15 bright white
    ]


def resolved_colors(theme: Dict[str, Any]) -> Dict[str, str]:
    """Flat color set used by the theme file and the active_theme.sh script."""
    accent = theme.get("accent", FALLBACK_ACCENT)
    background = theme.get("background", FALLBACK_BACKGROUND)
    foreground = theme.get("text", FALLBACK_FOREGROUND)
    return {
        "background": background,
        "foreground": foreground,
        "selection_background": accent,
        "selection_foreground": foreground,
        "cursor_color": accent,
        "cursor_text": background,
    }


# ---------------------------------------------------------------------------
# Renderers for the ghostty artifacts
# ---------------------------------------------------------------------------


def render_theme_file(colors: Dict[str, str], palette: List[str]) -> str:
    """Renders a ghostty theme file (palette first, ghostty's usual layout)."""
    lines = [f"palette = {i}={palette[i]}" for i in range(16)]
    lines.append(f"background = {colors['background']}")
    lines.append(f"foreground = {colors['foreground']}")
    lines.append(f"cursor-color = {colors['cursor_color']}")
    lines.append(f"cursor-text = {colors['cursor_text']}")
    lines.append(f"selection-background = {colors['selection_background']}")
    lines.append(f"selection-foreground = {colors['selection_foreground']}")
    return "\n".join(lines) + "\n"


def render_active_theme_script(theme_name: str, colors: Dict[str, str], palette: List[str]) -> str:
    """Renders active_theme.sh: GHOSTTY_THEME export + OSC 10/11/4 sequences.

    Compatible with sh, zsh and fish `source` (all interpret \\033/\\007 in
    printf format strings). OSC 10 = foreground, OSC 11 = background,
    OSC 4;N = palette entry N.
    """
    lines = [
        "#!/bin/sh",
        "# Generated by ghostty_sync.py — do not edit.",
        f'export GHOSTTY_THEME="{theme_name}"',
        f'printf "\\033]10;{colors["foreground"]}\\007"',
        f'printf "\\033]11;{colors["background"]}\\007"',
    ]
    for i, color in enumerate(palette):
        lines.append(f'printf "\\033]4;{i};{color}\\007"')
    return "\n".join(lines) + "\n"


def sync_ghostty_settings(config_path: Path, theme: str, opacity: float, blur: int) -> bool:
    """Updates the theme/opacity/blur lines in a ghostty config file.

    Mirrors visual_config_manager.sync_ghostty_settings line-for-line (same
    regex behavior); parameterized by path so tests stay hermetic. Keep the
    two functions in lockstep if either changes.
    """
    if not config_path.exists():
        return False

    try:
        content = config_path.read_text(encoding="utf-8")

        # theme = ...
        if re.search(r"^theme\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^theme\s*=.*$", f"theme = {theme}", content, flags=re.MULTILINE)
        else:
            content = f"theme = {theme}\n" + content

        # background-opacity = ...
        if re.search(r"^background-opacity\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^background-opacity\s*=.*$", f"background-opacity = {opacity:.2f}", content, flags=re.MULTILINE)
        else:
            content += f"\nbackground-opacity = {opacity:.2f}"

        # background-blur = ...
        if re.search(r"^background-blur\s*=.*$", content, flags=re.MULTILINE):
            content = re.sub(r"^background-blur\s*=.*$", f"background-blur = {blur}", content, flags=re.MULTILINE)
        else:
            content += f"\nbackground-blur = {blur}"

        config_path.write_text(content, encoding="utf-8")
        return True
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Loaders / planning
# ---------------------------------------------------------------------------


def load_theme(theme_json: Path) -> Optional[Dict[str, Any]]:
    """Returns the parsed theme dict, or None when missing/unparseable."""
    if not theme_json.exists():
        return None
    try:
        data = json.loads(theme_json.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def load_opacity_blur(ui_config: Path) -> Tuple[float, int]:
    opacity = FALLBACK_OPACITY
    blur = FALLBACK_BLUR
    if not ui_config.exists():
        return opacity, blur
    try:
        cfg = json.loads(ui_config.read_text(encoding="utf-8"))
        ghostty_cfg = cfg.get("ghostty", {}) if isinstance(cfg, dict) else {}
        opacity = float(ghostty_cfg.get("backgroundOpacity", opacity))
        blur = int(ghostty_cfg.get("backgroundBlur", blur))
    except Exception:
        pass
    return opacity, blur


def resolve_plan(
    theme: Dict[str, Any],
    ghostty_dir: Path,
    themes_dir: Path,
    ui_config: Path,
) -> Dict[str, Any]:
    """Computes every artifact ghostty_sync would write (pure, test-friendly)."""
    opacity, blur = load_opacity_blur(ui_config)
    colors = resolved_colors(theme)
    palette = derive_ansi_palette(theme)

    terminal_theme = theme.get("terminalTheme")
    if isinstance(terminal_theme, str) and terminal_theme.strip():
        theme_name = terminal_theme.strip()
        write_theme_file = False
    else:
        theme_name = DYNAMIC_THEME_NAME
        write_theme_file = True

    return {
        "theme": theme_name,
        "opacity": opacity,
        "blur": blur,
        "write_theme_file": write_theme_file,
        "theme_file": str(themes_dir / DYNAMIC_THEME_NAME) if write_theme_file else None,
        "config_file": str(ghostty_dir / "config"),
        "active_theme_script": str(ghostty_dir / "active_theme.sh"),
        **colors,
        "palette": palette,
    }


def apply_plan(plan: Dict[str, Any], ghostty_dir: Path, themes_dir: Path) -> None:
    """Writes the real ghostty artifacts; every step is fail-soft."""
    try:
        ghostty_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"ghostty_sync: no se pudo crear {ghostty_dir}: {e}", file=sys.stderr)

    if plan["write_theme_file"]:
        try:
            themes_dir.mkdir(parents=True, exist_ok=True)
            (themes_dir / DYNAMIC_THEME_NAME).write_text(
                render_theme_file(plan, plan["palette"]), encoding="utf-8"
            )
        except Exception as e:
            print(f"ghostty_sync: no se pudo escribir el tema dinámico: {e}", file=sys.stderr)

    try:
        sync_ghostty_settings(
            ghostty_dir / "config", plan["theme"], plan["opacity"], plan["blur"]
        )
    except Exception as e:
        print(f"ghostty_sync: no se pudo sincronizar la config: {e}", file=sys.stderr)

    try:
        (ghostty_dir / "active_theme.sh").write_text(
            render_active_theme_script(plan["theme"], plan, plan["palette"]),
            encoding="utf-8",
        )
    except Exception as e:
        print(f"ghostty_sync: no se pudo escribir active_theme.sh: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Sync Ghostty with the Cocoa system palette.")
    parser.add_argument("--dry-run", action="store_true", help="Print the plan JSON without writing anything.")
    parser.add_argument("--config-dir", type=Path, default=DEFAULT_GHOSTTY_DIR, help="Ghostty config directory (default: ~/.config/ghostty).")
    parser.add_argument("--themes-dir", type=Path, default=None, help="Ghostty themes directory (default: <config-dir>/themes).")
    parser.add_argument("--theme-json", type=Path, default=THEME_JSON, help="Path to current_theme.json (default: cocoa theme dir).")
    parser.add_argument("--ui-config", type=Path, default=UI_CONFIG_JSON, help="Path to ui_config.json (default: cocoa theme dir).")
    args = parser.parse_args(argv)

    theme = load_theme(args.theme_json)
    if theme is None:
        # Missing/unparseable -> exit 0 silently (fail-soft contract).
        return 0

    themes_dir = args.themes_dir if args.themes_dir is not None else Path(args.config_dir) / "themes"
    plan = resolve_plan(theme, args.config_dir, themes_dir, args.ui_config)

    if args.dry_run:
        print(json.dumps(plan, indent=2))
        return 0

    apply_plan(plan, args.config_dir, themes_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())