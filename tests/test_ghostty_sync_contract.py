"""Contract tests for the Ghostty <-> Cocoa palette sync (ghostty_sync.py).

Enforces:
1. ghostty_sync.py is the single fail-soft funnel: missing/unparseable
   current_theme.json exits 0 silently, and every write path targets the
   overridable --config-dir / --themes-dir so tests never touch the real
   ~/.config/ghostty config or themes.
2. Named themes (terminalTheme in current_theme.json) rewrite only the real
   ghostty config theme line (same regex behavior as
   visual_config_manager.sync_ghostty_settings) and keep opacity/blur in sync.
3. Dynamic palettes (no terminalTheme) produce a 16-color "Cocoa Dynamic"
   ghostty theme file plus config and active_theme.sh (OSC 10/11/4 sequences).
4. --dry-run prints the exact plan JSON without writing anything.
5. UiConfigService.qml ghosttyThemes holds only valid title-case installed
   names (no lowercase kebab tokens like catppuccin-mocha), matching
   visual_config_manager.get_ghostty_themes().
6. theme_manager.py presets each carry a terminalTheme matching the intended
   ghostty theme mapping.
"""

import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.theme_manager import NAMED_PRESETS
from scripts.visual_config_manager import get_ghostty_themes

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GHOSTTY_SYNC = PROJECT_ROOT / "scripts/ghostty_sync.py"
UI_CONFIG_SERVICE_PATH = PROJECT_ROOT / "services/UiConfigService.qml"
THEME_MANAGER_PATH = PROJECT_ROOT / "scripts/theme_manager.py"

EXPECTED_GHOSTTY_THEMES = [
    "Onenord",
    "Catppuccin Mocha",
    "Catppuccin Macchiato",
    "TokyoNight Night",
    "Gruvbox Dark",
    "Rose Pine",
    "Nord",
    "Dracula",
    "Cyberpunk",
    "Everforest Dark Hard",
    "Kanagawa Wave",
    "Monokai Pro",
]

EXPECTED_TERMINAL_THEMES = {
    "NeoNord": "Onenord",
    "Catppuccin Mocha": "Catppuccin Mocha",
    "Tokyo Night": "TokyoNight Night",
    "Gruvbox Retro": "Gruvbox Dark",
    "Rose Pine": "Rose Pine",
    "Cyberpunk Neon": "Cyberpunk",
    "Emerald Forest": "Everforest Dark Hard",
    "Sunset Glow": "Kanagawa Wave",
    "Cocoa Classic": "Monokai Pro",
}

KABAB_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

SAMPLE_NAMED_THEME = {
    "mode": "NeoNord",
    "name": "NeoNord",
    "terminalTheme": "Onenord",
    "accent": "#88c0d0",
    "surface": "#242933",
    "surfaceDark": "#1e222a",
    "surfaceRaised": "#2e3440",
    "surfaceBorder": "#434c5e",
    "surfaceHover": "#3b4252",
    "background": "#191c22",
    "text": "#eceff4",
    "textMuted": "#81a1c1",
    "textDim": "#4c566a",
}

SAMPLE_DYNAMIC_THEME = {
    "mode": "auto",
    "surface": "#1f2419",
    "surfaceDark": "#151810",
    "surfaceRaised": "#2a3021",
    "surfaceBorder": "#404930",
    "surfaceHover": "#353c29",
    "background": "#0f120c",
    "text": "#ffffff",
    "textMuted": "#adc686",
    "textDim": "#737f60",
    "accent": "#d1e7ae",
}

SAMPLE_GHOSTTY_CONFIG = """#Configuración Visual
# ── Theme ─────────────────────────────────────────────────────────────
theme = Onenord
background-opacity = 0.95
background-opacity-cells = true
background-blur = 24

# ── Font ──────────────────────────────────────────────────────────────
font-family = "Cascadia Code"
"""


def run_ghostty_sync(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["python3", str(GHOSTTY_SYNC), *args],
        capture_output=True,
        text=True,
        timeout=15,
    )


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload), encoding="utf-8")


def extract_qml_theme_list() -> list:
    """Parses the ghosttyThemes array out of UiConfigService.qml."""
    content = UI_CONFIG_SERVICE_PATH.read_text(encoding="utf-8")
    match = re.search(r"ghosttyThemes:\s*\[(.*?)\]", content, flags=re.DOTALL)
    assert match, "ghosttyThemes array not found in UiConfigService.qml"
    return re.findall(r'"([^"]+)"', match.group(1))


class TestGhosttySyncContract(unittest.TestCase):
    """End-to-end contract validation for the ghostty sync funnel."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.ghostty_dir = self.tmp / "ghostty"
        self.themes_dir = self.ghostty_dir / "themes"
        # Hermetic ui_config: the suite must not read the live
        # theme/ui_config.json (user state; opacity/blur vary per machine).
        self.ui_config = self.tmp / "ui_config.json"
        write_json(self.ui_config, {"ghostty": {"backgroundOpacity": 0.95, "backgroundBlur": 24}})

    def _run(self, theme_payload: dict, *extra: str) -> subprocess.CompletedProcess:
        theme_json = self.tmp / "current_theme.json"
        write_json(theme_json, theme_payload)
        return run_ghostty_sync(
            "--theme-json", str(theme_json),
            "--config-dir", str(self.ghostty_dir),
            "--ui-config", str(self.ui_config),
            *extra,
        )

    def test_missing_theme_json_exits_zero_silently(self) -> None:
        """A missing current_theme.json must exit 0 without output or writes."""
        missing = self.tmp / "does_not_exist.json"
        proc = run_ghostty_sync(
            "--theme-json", str(missing),
            "--config-dir", str(self.ghostty_dir),
            "--dry-run",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertFalse(self.ghostty_dir.exists())

    def test_unparseable_theme_json_exits_zero_silently(self) -> None:
        corrupt = self.tmp / "current_theme.json"
        corrupt.write_text("{ not json !!!", encoding="utf-8")
        proc = run_ghostty_sync(
            "--theme-json", str(corrupt),
            "--config-dir", str(self.ghostty_dir),
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertFalse(self.ghostty_dir.exists())

    def test_named_theme_dry_run_plan(self) -> None:
        """terminalTheme must resolve to the named theme with no theme file."""
        proc = self._run(SAMPLE_NAMED_THEME, "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plan = json.loads(proc.stdout)
        self.assertEqual(plan["theme"], "Onenord")
        self.assertFalse(plan["write_theme_file"])
        self.assertIsNone(plan["theme_file"])
        self.assertEqual(plan["opacity"], 0.95)
        self.assertEqual(plan["blur"], 24)
        self.assertEqual(len(plan["palette"]), 16)
        self.assertEqual(plan["background"], "#191c22")
        self.assertEqual(plan["foreground"], "#eceff4")

    def test_named_theme_writes_config_and_script(self) -> None:
        """Named theme must replace the config theme line once and keep
        opacity/blur, without writing any dynamic theme file."""
        config = self.ghostty_dir / "config"
        self.ghostty_dir.mkdir(parents=True, exist_ok=True)
        config.write_text(SAMPLE_GHOSTTY_CONFIG, encoding="utf-8")

        proc = self._run(SAMPLE_NAMED_THEME)
        self.assertEqual(proc.returncode, 0, proc.stderr)

        content = config.read_text(encoding="utf-8")
        self.assertEqual(content.count("theme = Onenord"), 1)
        self.assertIn("background-opacity = 0.95", content)
        self.assertIn("background-blur = 24", content)
        self.assertIn("background-opacity-cells = true", content)  # untouched
        self.assertFalse((self.themes_dir / "Cocoa Dynamic").exists())

        script = (self.ghostty_dir / "active_theme.sh").read_text(encoding="utf-8")
        self.assertIn('export GHOSTTY_THEME="Onenord"', script)
        self.assertIn('printf "\\033]10;#eceff4\\007"', script)
        self.assertIn('printf "\\033]11;#191c22\\007"', script)
        self.assertEqual(script.count('\\033]4;'), 16)

    def test_dynamic_palette_writes_16_color_theme_file(self) -> None:
        """Auto palettes must materialize a 'Cocoa Dynamic' theme file with the
        full 16-color ramp plus base colors, and point the config at it."""
        config = self.ghostty_dir / "config"
        self.ghostty_dir.mkdir(parents=True, exist_ok=True)
        config.write_text(SAMPLE_GHOSTTY_CONFIG, encoding="utf-8")

        proc = self._run(SAMPLE_DYNAMIC_THEME)
        self.assertEqual(proc.returncode, 0, proc.stderr)

        theme_file = self.themes_dir / "Cocoa Dynamic"
        self.assertTrue(theme_file.exists())
        lines = theme_file.read_text(encoding="utf-8").splitlines()
        palette_lines = [ln for ln in lines if ln.startswith("palette = ")]
        self.assertEqual(len(palette_lines), 16)
        self.assertTrue(all(re.match(r"^palette = \d+=#[0-9a-f]{6}$", ln) for ln in palette_lines))
        self.assertIn("background = #0f120c", lines)
        self.assertIn("foreground = #ffffff", lines)
        self.assertIn("cursor-color = #d1e7ae", lines)
        self.assertIn("selection-background = #d1e7ae", lines)

        content = config.read_text(encoding="utf-8")
        self.assertEqual(content.count("theme = Cocoa Dynamic"), 1)
        self.assertIn("background-opacity = 0.95", content)
        self.assertIn("background-blur = 24", content)

        script = (self.ghostty_dir / "active_theme.sh").read_text(encoding="utf-8")
        self.assertIn('export GHOSTTY_THEME="Cocoa Dynamic"', script)
        self.assertIn('printf "\\033]10;#ffffff\\007"', script)
        self.assertIn('printf "\\033]11;#0f120c\\007"', script)
        self.assertEqual(script.count('\\033]4;'), 16)

    def test_dynamic_palette_dry_run_writes_nothing(self) -> None:
        """Dry-run must report the dynamic plan without creating any file."""
        proc = self._run(SAMPLE_DYNAMIC_THEME, "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plan = json.loads(proc.stdout)
        self.assertEqual(plan["theme"], "Cocoa Dynamic")
        self.assertTrue(plan["write_theme_file"])
        self.assertEqual(len(plan["palette"]), 16)
        self.assertFalse(self.ghostty_dir.exists(), "dry-run must not create the config dir")

    def test_missing_config_is_fail_soft(self) -> None:
        """Missing ghostty config must not abort: exit 0, theme file + script
        still written, config untouched."""
        proc = self._run(SAMPLE_DYNAMIC_THEME)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue((self.themes_dir / "Cocoa Dynamic").exists())
        self.assertTrue((self.ghostty_dir / "active_theme.sh").exists())
        self.assertFalse((self.ghostty_dir / "config").exists())

    def test_named_theme_wins_over_mode_auto(self) -> None:
        """terminalTheme takes precedence even when the theme was applied as
        an auto/mapped palette."""
        hybrid = dict(SAMPLE_DYNAMIC_THEME)
        hybrid["terminalTheme"] = "TokyoNight Night"
        proc = self._run(hybrid, "--dry-run")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        plan = json.loads(proc.stdout)
        self.assertEqual(plan["theme"], "TokyoNight Night")
        self.assertFalse(plan["write_theme_file"])

    def test_ui_config_service_theme_list_is_title_case(self) -> None:
        """UiConfigService ghosttyThemes must be valid installed title-case
        names — no lowercase kebab tokens like catppuccin-mocha."""
        themes = extract_qml_theme_list()
        self.assertEqual(themes, EXPECTED_GHOSTTY_THEMES)
        for name in themes:
            self.assertNotRegex(name, KABAB_RE, f"kebab-case theme token: {name}")
            self.assertRegex(name, r"^[A-Z]", f"non-title-case theme token: {name}")
        self.assertNotIn("catppuccin-mocha", themes)
        self.assertNotIn("Solarized Dark", themes)

    def test_visual_config_manager_theme_list_matches_qml(self) -> None:
        """get_ghostty_themes() must match the QML chips list exactly."""
        self.assertEqual(get_ghostty_themes(), EXPECTED_GHOSTTY_THEMES)
        self.assertEqual(get_ghostty_themes(), extract_qml_theme_list())

    @unittest.skipUnless(Path("/usr/share/ghostty/themes").is_dir(), "ghostty themes dir not installed")
    def test_theme_list_exists_in_installed_themes_dir(self) -> None:
        """Every advertised theme must resolve to an installed ghostty theme file."""
        installed = Path("/usr/share/ghostty/themes")
        missing = [t for t in EXPECTED_GHOSTTY_THEMES if not (installed / t).is_file()]
        self.assertEqual(missing, [], f"missing in /usr/share/ghostty/themes: {missing}")

    def test_named_presets_have_matching_terminal_themes(self) -> None:
        """Every NAMED_PRESET entry must carry its intended terminalTheme."""
        self.assertEqual(set(EXPECTED_TERMINAL_THEMES), set(NAMED_PRESETS))
        for preset_name, terminal_theme in EXPECTED_TERMINAL_THEMES.items():
            self.assertEqual(
                NAMED_PRESETS[preset_name]["terminalTheme"],
                terminal_theme,
                f"{preset_name} must map to {terminal_theme}",
            )
        # The key must be present in the source so apply_theme_by_name persists it
        source = THEME_MANAGER_PATH.read_text(encoding="utf-8")
        self.assertIn('"terminalTheme"', source)


if __name__ == "__main__":
    unittest.main()