#!/usr/bin/env python3
"""Contract tests for the Hyprland keybinds & configs editor (Cocoa Settings).

Enforces:
1. keybinds_manager keeps its read-only `list` handler (default, byte-compatible JSON)
   and gains `add`/`remove` that write/delete managed bind lines in hyprland.conf.
2. Modifier normalization (comma/plus/space separated -> Hyprland space form).
3. hyprland_config_manager `get`/`set`/`autostart` round-trip against a temp
   hyprland.conf via --config (tests never touch the real config nor hyprctl).
4. KeybindsView exposes the add-form selectors and per-row edit/remove affordances.
5. HyprlandConfigView references the manager script and every curated key.
"""

import contextlib
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from scripts import hyprland_config_manager, keybinds_manager
from scripts.hyprland_config_manager import get_values, manage_autostart, set_value
from scripts.keybinds_manager import add_bind, normalize_modifiers, remove_bind

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KEYBINDS_VIEW_PATH = PROJECT_ROOT / "modules/settings/KeybindsView.qml"
HYPRLAND_VIEW_PATH = PROJECT_ROOT / "modules/settings/HyprlandConfigView.qml"

SAMPLE_CONF = """# --- Autostart ---
# exec-once = swaync (deshabilitado)
exec-once = ~/.config/hypr/scripts/start_shell.sh

# --- Keybindings ---
bind = SUPER, Q, exec, $terminal
bind = SUPER, C, killactive

# --- Input ---
input {
    kb_layout = latam
}

# --- General ---
general {
    border_size = 2
    gaps_in = 5
    gaps_out = 15
}

# --- Misceláneos ---
misc {
    focus_on_activate = true
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

# --- Movimiento ---
bind = SUPER, left, movefocus, l

# Demonio de telemetría para Cocoa Shell
exec-once = ~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh
"""


def _fake_hyprctl_ok(*args, **kwargs):
    proc = MagicMock()
    proc.returncode = 0
    proc.stdout = ""
    proc.stderr = ""
    return proc


def _hyprctl_unavailable(*args, **kwargs):
    raise FileNotFoundError("hyprctl not available in tests")


def _fake_hyprctl_env(base_dir: Path) -> dict:
    """PATH env where 'hyprctl' resolves to a no-op stub — CLI child processes
    must never talk to the real compositor, with or without hyprctl installed."""
    bin_dir = base_dir / "bin"
    bin_dir.mkdir(exist_ok=True)
    stub = bin_dir / "hyprctl"
    stub.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    stub.chmod(0o755)
    env = dict(os.environ)
    env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
    return env


class TestKeybindsManagerEditing(unittest.TestCase):
    """keybinds_manager add/remove against a temp hyprland.conf (hyprctl mocked out)."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.conf = Path(self._tmp.name) / "hyprland.conf"
        self.conf.write_text(SAMPLE_CONF, encoding="utf-8")

    def test_list_handler_is_the_default_and_exists(self) -> None:
        """No subcommand (or explicit 'list') must print the read-only binds JSON."""
        self.assertTrue(callable(keybinds_manager.main))
        self.assertTrue(callable(keybinds_manager.get_formatted_binds))
        for argv in ([], ["list"]):
            buf = io.StringIO()
            with patch("scripts.keybinds_manager.get_formatted_binds", return_value=[]):
                with contextlib.redirect_stdout(buf):
                    keybinds_manager.main(argv)
            parsed = json.loads(buf.getvalue())
            self.assertIsInstance(parsed, list, f"main({argv}) must print a JSON list")

    def test_managed_section_marker_contract(self) -> None:
        self.assertEqual(keybinds_manager.MANAGED_SECTION_MARKER, "# --- Keybindings gestionados por Cocoa ---")

    def test_normalize_modifiers(self) -> None:
        self.assertEqual(normalize_modifiers("SUPER"), "SUPER")
        self.assertEqual(normalize_modifiers("SUPER SHIFT"), "SUPER SHIFT")
        self.assertEqual(normalize_modifiers("SUPER,SHIFT"), "SUPER SHIFT")
        self.assertEqual(normalize_modifiers("ctrl+alt"), "CTRL ALT")
        self.assertEqual(normalize_modifiers(" SUPER , shift "), "SUPER SHIFT")
        self.assertEqual(normalize_modifiers(""), "")
        self.assertEqual(normalize_modifiers(None), "")

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_add_bind_writes_managed_section(self, mock_run) -> None:
        result = add_bind("SUPER,SHIFT", "A", "exec", "ghostty", str(self.conf))
        self.assertTrue(result["success"])
        content = self.conf.read_text(encoding="utf-8")
        self.assertIn("# --- Keybindings gestionados por Cocoa ---", content)
        self.assertIn("bind = SUPER SHIFT, A, exec, ghostty", content)
        # Section is created after the existing keybind area (last bind before it)
        marker_pos = content.index("# --- Keybindings gestionados por Cocoa ---")
        self.assertGreater(marker_pos, content.index("bind = SUPER, left, movefocus, l"))
        # Live apply attempted exactly once with hyprctl bind
        self.assertEqual(mock_run.call_count, 1)
        live_args = mock_run.call_args[0][0]
        self.assertEqual(live_args[0], "hyprctl")
        self.assertEqual(live_args[1], "bind")
        self.assertTrue(result["applied"])

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_add_bind_empty_modifiers_and_duplicate(self, mock_run) -> None:
        first = add_bind("", "Print", "exec", "flameshot", str(self.conf))
        self.assertTrue(first["success"])
        content = self.conf.read_text(encoding="utf-8")
        self.assertIn("bind = , Print, exec, flameshot", content)
        # Exact same line again -> duplicate, no second copy
        second = add_bind("", "Print", "exec", "flameshot", str(self.conf))
        self.assertTrue(second["success"])
        self.assertTrue(second["duplicate"])
        self.assertEqual(self.conf.read_text(encoding="utf-8").count("bind = , Print, exec, flameshot"), 1)

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_hyprctl_unavailable)
    def test_add_bind_survives_missing_hyprctl(self, mock_run) -> None:
        result = add_bind("SUPER", "J", "exec", "kitty", str(self.conf))
        self.assertTrue(result["success"])
        self.assertFalse(result["applied"])
        self.assertIn("hyprctl", result["warning"])
        self.assertIn("bind = SUPER, J, exec, kitty", self.conf.read_text(encoding="utf-8"))

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_remove_bind_deletes_only_matching_managed_line(self, mock_run) -> None:
        add_bind("SUPER SHIFT", "A", "exec", "ghostty", str(self.conf))
        add_bind("CTRL ALT", "b", "workspace", "2", str(self.conf))
        result = remove_bind("SUPER SHIFT", "A", str(self.conf))
        self.assertTrue(result["success"])
        self.assertEqual(result["removed"], 1)
        content = self.conf.read_text(encoding="utf-8")
        self.assertNotIn("bind = SUPER SHIFT, A", content)
        # The other managed line and all unmanaged lines survive
        self.assertIn("bind = CTRL ALT, b, workspace, 2", content)
        self.assertIn("bind = SUPER, Q, exec, $terminal", content)
        # Live unbind attempted
        unbind_call = mock_run.call_args[0][0]
        self.assertEqual(unbind_call[:2], ["hyprctl", "unbind"])

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_remove_unmanaged_bind_reports_zero_but_still_live_unbinds(self, mock_run) -> None:
        result = remove_bind("SUPER", "C", str(self.conf))
        self.assertTrue(result["success"])
        self.assertEqual(result["removed"], 0)
        self.assertIn("bind = SUPER, C, killactive", self.conf.read_text(encoding="utf-8"))
        self.assertEqual(mock_run.call_args[0][0][:2], ["hyprctl", "unbind"])

    @patch("scripts.keybinds_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_add_requires_key_and_dispatcher(self, mock_run) -> None:
        result = add_bind("SUPER", "", "exec", "ghostty", str(self.conf))
        self.assertFalse(result["success"])
        self.assertIn("error", result)
        mock_run.assert_not_called()

    def test_config_path_flag_parsing(self) -> None:
        path, rest = keybinds_manager._parse_common_args(["add", "SUPER", "A", "exec", "x", "--config", "/tmp/x.conf"])
        self.assertEqual(path, "/tmp/x.conf")
        self.assertEqual(rest, ["add", "SUPER", "A", "exec", "x"])

    def test_cli_add_and_remove_via_config_flag(self) -> None:
        """End-to-end CLI: python3 keybinds_manager.py add|remove --config <tmp>.
        The child stubs hyprctl via PATH, so no compositor is involved."""
        env = _fake_hyprctl_env(Path(self._tmp.name))
        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "scripts/keybinds_manager.py"),
             "add", "SUPER,SHIFT", "B", "exec", "kitty", "--config", str(self.conf)],
            capture_output=True, text=True, timeout=15, env=env)
        # The child stubs hyprctl; it must exit 0 with JSON either way.
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertTrue(payload["success"])
        self.assertIn("bind = SUPER SHIFT, B, exec, kitty", self.conf.read_text(encoding="utf-8"))

        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "scripts/keybinds_manager.py"),
             "remove", "SUPER SHIFT", "B", "--config", str(self.conf)],
            capture_output=True, text=True, timeout=15, env=env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(json.loads(proc.stdout)["success"])
        self.assertNotIn("bind = SUPER SHIFT, B", self.conf.read_text(encoding="utf-8"))


class TestHyprlandConfigManager(unittest.TestCase):
    """hyprland_config_manager get/set/autostart against a temp hyprland.conf."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.conf = Path(self._tmp.name) / "hyprland.conf"
        self.conf.write_text(SAMPLE_CONF, encoding="utf-8")

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_hyprctl_unavailable)
    def test_get_parses_temp_config_when_hyprctl_unavailable(self, mock_run) -> None:
        values = get_values(str(self.conf))
        self.assertEqual(values["gaps_in"], 5)
        self.assertEqual(values["gaps_out"], 15)
        self.assertEqual(values["kb_layout"], "latam")
        self.assertTrue(values["focus_on_activate"])
        self.assertTrue(values["disable_hyprland_logo"])
        self.assertTrue(values["disable_splash_rendering"])
        self.assertEqual(
            values["autostart"],
            ["~/.config/hypr/scripts/start_shell.sh",
             "~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh"],
        )
        # Commented-out exec-once must not be listed
        self.assertNotIn("swaync", " ".join(values["autostart"]))
        self.assertEqual(values["source"], "conf")

    def test_get_prefers_hyprctl_getoption_when_available(self) -> None:
        def fake_getoption(cmd, *args, **kwargs):
            option = cmd[2]
            data = {
                "general:gaps_in": {"option": "general:gaps_in", "custom": "9 9 9 9", "set": True},
                "general:gaps_out": {"option": "general:gaps_out", "custom": "20 20 20 20", "set": True},
                "input:kb_layout": {"option": "input:kb_layout", "int": 0, "str": "us"},
                "misc:focus_on_activate": {"option": "misc:focus_on_activate", "int": 1},
                "misc:disable_hyprland_logo": {"option": "misc:disable_hyprland_logo", "int": 0},
                "misc:disable_splash_rendering": {"option": "misc:disable_splash_rendering", "int": 1},
            }[option]
            proc = MagicMock()
            proc.returncode = 0
            proc.stdout = json.dumps(data)
            return proc

        with patch("scripts.hyprland_config_manager.subprocess.run", side_effect=fake_getoption):
            values = get_values(str(self.conf))
        self.assertEqual(values["gaps_in"], 9)      # parsed from custom: "9 9 9 9"
        self.assertEqual(values["gaps_out"], 20)
        self.assertEqual(values["kb_layout"], "us")
        self.assertTrue(values["focus_on_activate"])
        self.assertFalse(values["disable_hyprland_logo"])
        self.assertTrue(values["disable_splash_rendering"])
        self.assertEqual(values["source"], "hyprctl")
        # autostart always comes from the conf
        self.assertEqual(len(values["autostart"]), 2)

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_set_gaps_writes_and_reads_back(self, mock_run) -> None:
        result = set_value("gaps_in", "9", str(self.conf))
        self.assertTrue(result["success"])
        self.assertEqual(result["value"], 9)
        self.assertTrue(result["applied"])
        self.assertRegex(self.conf.read_text(encoding="utf-8"), r"gaps_in = 9")
        with patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_hyprctl_unavailable):
            values = get_values(str(self.conf))
        self.assertEqual(values["gaps_in"], 9)
        # hyprctl keyword invoked with the right option
        call = mock_run.call_args[0][0]
        self.assertEqual(call[:3], ["hyprctl", "keyword", "general:gaps_in"])
        self.assertEqual(call[3], "9")

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_set_kb_layout_writes_and_reads_back(self, mock_run) -> None:
        result = set_value("kb_layout", "us", str(self.conf))
        self.assertTrue(result["success"])
        self.assertEqual(result["value"], "us")
        self.assertIn("kb_layout = us", self.conf.read_text(encoding="utf-8"))
        with patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_hyprctl_unavailable):
            self.assertEqual(get_values(str(self.conf))["kb_layout"], "us")
        # input { ... } structure is preserved (no whole-file rewrite)
        self.assertIn("input {", self.conf.read_text(encoding="utf-8"))
        self.assertIn("general {", self.conf.read_text(encoding="utf-8"))

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_set_misc_flag_writes_and_reads_back(self, mock_run) -> None:
        result = set_value("focus_on_activate", "false", str(self.conf))
        self.assertTrue(result["success"])
        self.assertFalse(result["value"])
        self.assertIn("focus_on_activate = false", self.conf.read_text(encoding="utf-8"))
        with patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_hyprctl_unavailable):
            self.assertFalse(get_values(str(self.conf))["focus_on_activate"])

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_hyprctl_unavailable)
    def test_set_creates_missing_key_inside_section(self, mock_run) -> None:
        """A conf missing the key gets it inserted in the owning section."""
        partial = "general {\n    gaps_in = 5\n}\n"
        self.conf.write_text(partial, encoding="utf-8")
        result = set_value("gaps_out", "12", str(self.conf))
        self.assertTrue(result["success"])
        content = self.conf.read_text(encoding="utf-8")
        self.assertIn("gaps_out = 12", content)
        # must live inside general { ... }
        general_block = re.search(r"general \{.*?\}", content, re.DOTALL).group(0)
        self.assertIn("gaps_out = 12", general_block)

    @patch("scripts.hyprland_config_manager.subprocess.run", side_effect=_fake_hyprctl_ok)
    def test_set_rejects_unknown_key_and_bad_values(self, mock_run) -> None:
        self.assertFalse(set_value("border_size", "3", str(self.conf))["success"])
        self.assertFalse(set_value("gaps_in", "wide", str(self.conf))["success"])
        self.assertFalse(set_value("focus_on_activate", "maybe", str(self.conf))["success"])
        mock_run.assert_not_called()  # invalid values never reach hyprctl

    def test_autostart_add_dedupe_and_remove(self) -> None:
        added = manage_autostart("add", "waybar", str(self.conf))
        self.assertTrue(added["success"])
        self.assertFalse(added["duplicate"])
        dup = manage_autostart("add", "waybar", str(self.conf))
        self.assertTrue(dup["duplicate"])
        content = self.conf.read_text(encoding="utf-8")
        self.assertEqual(content.count("exec-once = waybar"), 1)
        # Original entries survive
        self.assertIn("exec-once = ~/.config/hypr/scripts/start_shell.sh", content)
        removed = manage_autostart("remove", "waybar", str(self.conf))
        self.assertTrue(removed["success"])
        self.assertEqual(removed["removed"], 1)
        content = self.conf.read_text(encoding="utf-8")
        self.assertNotIn("exec-once = waybar", content)
        self.assertIn("exec-once = ~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh", content)

    def test_autostart_rejects_empty_and_unknown_action(self) -> None:
        self.assertFalse(manage_autostart("add", "", str(self.conf))["success"])
        self.assertFalse(manage_autostart("restart", "waybar", str(self.conf))["success"])

    def test_config_path_flag_parsing(self) -> None:
        path, rest = hyprland_config_manager._parse_common_args(["get", "--config", "/tmp/y.conf"])
        self.assertEqual(path, "/tmp/y.conf")
        self.assertEqual(rest, ["get"])

    def test_cli_get_with_config_flag_reads_autostart_from_temp_file(self) -> None:
        """End-to-end CLI get --config: autostart is always conf-sourced (deterministic)."""
        env = _fake_hyprctl_env(Path(self._tmp.name))
        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "scripts/hyprland_config_manager.py"),
             "get", "--config", str(self.conf)],
            capture_output=True, text=True, timeout=15, env=env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(
            payload["autostart"],
            ["~/.config/hypr/scripts/start_shell.sh",
             "~/.config/quickshell/cocoa/scripts/cocoa_daemon.sh"],
        )
        for key in ("gaps_in", "gaps_out", "kb_layout", "focus_on_activate",
                    "disable_hyprland_logo", "disable_splash_rendering"):
            self.assertIn(key, payload)
        self.assertIsInstance(payload["gaps_in"], int)
        self.assertIsInstance(payload["focus_on_activate"], bool)

    def test_cli_unknown_command_fails_gracefully(self) -> None:
        proc = subprocess.run(
            ["python3", str(PROJECT_ROOT / "scripts/hyprland_config_manager.py"), "frobnicate"],
            capture_output=True, text=True, timeout=15)
        self.assertEqual(proc.returncode, 1)
        payload = json.loads(proc.stdout)
        self.assertFalse(payload["success"])
        self.assertIn("error", payload)


class TestSettingsViewsEditorContract(unittest.TestCase):
    """KeybindsView + HyprlandConfigView expose the editor UI (string checks)."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.assertTrue(KEYBINDS_VIEW_PATH.exists(), f"Missing {KEYBINDS_VIEW_PATH}")
        cls.assertTrue(HYPRLAND_VIEW_PATH.exists(), f"Missing {HYPRLAND_VIEW_PATH}")
        cls.keybinds_view = KEYBINDS_VIEW_PATH.read_text(encoding="utf-8")
        cls.hyprland_view = HYPRLAND_VIEW_PATH.read_text(encoding="utf-8")

    def test_keybinds_view_add_form_labels_and_selectors(self) -> None:
        """The add-form row must expose every labeled field and the dispatcher selector."""
        for label in ("Agregar Atajo", "Módificador", "Tecla", "Disparador", "Argumento"):
            self.assertIn(label, self.keybinds_view, f"Missing '{label}' in KeybindsView")
        # Dispatcher combo options
        for dispatcher in ("exec", "workspace", "movetoworkspace", "movefocus",
                           "movewindow", "killactive", "togglefloating", "fullscreen", "global"):
            self.assertIn(f'"{dispatcher}"', self.keybinds_view, f"Missing dispatcher {dispatcher}")

    def test_keybinds_view_row_edit_and_remove_affordances(self) -> None:
        self.assertIn("Editar", self.keybinds_view)
        self.assertIn("Eliminar", self.keybinds_view)
        # Mutations go through the manager script and refresh afterwards
        self.assertIn("keybinds_manager.py", self.keybinds_view)
        self.assertIn('"add"', self.keybinds_view)
        self.assertIn('"remove"', self.keybinds_view)
        self.assertIn("root.refresh()", self.keybinds_view)
        # Editable rows keep read-only list + search intact
        self.assertIn("filteredBinds", self.keybinds_view)
        self.assertIn("Buscar atajo...", self.keybinds_view)

    def test_keybinds_view_has_feedback_pill(self) -> None:
        self.assertIn("feedbackMessage", self.keybinds_view)
        self.assertIn("stateOk", self.keybinds_view)

    def test_hyprland_view_references_manager_and_curated_keys(self) -> None:
        self.assertIn("hyprland_config_manager.py", self.hyprland_view)
        for key in ("gaps_in", "gaps_out", "kb_layout", "focus_on_activate",
                    "disable_hyprland_logo", "disable_splash_rendering", "autostart"):
            self.assertIn(key, self.hyprland_view, f"Missing curated key {key}")

    def test_hyprland_view_controls_and_reload(self) -> None:
        # Slider ranges for gaps and the kb_layout field
        self.assertRegex(self.hyprland_view, r"from:\s*0\s*\n\s*to:\s*30")  # gaps_in 0-30
        self.assertRegex(self.hyprland_view, r"from:\s*0\s*\n\s*to:\s*60")  # gaps_out 0-60
        self.assertIn("placeholderText: \"latam\"", self.hyprland_view)
        # Reload on visible + feedback pill
        self.assertIn("onVisibleChanged", self.hyprland_view)
        self.assertIn("reload()", self.hyprland_view)
        self.assertIn("feedbackMessage", self.hyprland_view)
        self.assertIn("Agregar", self.hyprland_view)
        self.assertIn("Eliminar", self.hyprland_view)


if __name__ == "__main__":
    unittest.main()
