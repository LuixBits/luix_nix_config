import json
from pathlib import Path
import tempfile
import unittest

import tomlkit

from claude_statusline import render
from configure_statuslines import CODEX_ITEMS, configure


class StatuslineTests(unittest.TestCase):
    def test_claude_context_and_session_cost_have_distinct_labels(self):
        output = render({
            "model": {"display_name": "Opus"},
            "effort": {"level": "max"},
            "workspace": {"current_dir": "/projects/example"},
            "context_window": {
                "total_input_tokens": 150_000,
                "total_output_tokens": 2_400,
                "used_percentage": 76.2,
            },
            "cost": {"total_cost_usd": 3.456, "total_duration_ms": 3_780_000},
            "rate_limits": {"five_hour": {"used_percentage": 0}, "seven_day": {"used_percentage": 32}},
        })
        self.assertIn("Opus (max) | example", output)
        self.assertIn("ctx in 150.0k / out 2.4k (76% used)", output)
        self.assertIn("API est $3.46 | 1h03m", output)
        self.assertIn("5h 0% used / 7d 32% used", output)

    def test_missing_usage_is_not_reported_as_zero_cost(self):
        self.assertIn("API est —", render({"context_window": None, "cost": None}))
        self.assertIn("API est $0.00", render({"cost": {"total_cost_usd": 0}}))
        self.assertNotIn("5h", render({}))
        self.assertNotIn("\x1b", render({"model": {"display_name": "Opus\x1b[31m"}}))

    def test_merge_preserves_hooks_models_comments_and_tui_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            claude_path = root / "claude.json"
            codex_path = root / "codex.toml"
            kimi_path = root / "kimi.toml"
            claude = {"model": "keep-me", "hooks": {"SessionStart": [{"hooks": []}]}, "statusLine": {"padding": 1}}
            claude_path.write_text(json.dumps(claude))
            codex_path.write_text('''# Keep this comment
model = "keep-me"
[tui]
status_line = [
  "current-dir",
]
status_line_use_colors = true
[tui.model_availability_nux]
"keep-me" = 2
[tui.keymap.chat]
edit_queued_message = "f8"
interrupt_turn = "f12"
[tui.keymap.global]
open_transcript = "ctrl-t"
[mcp_servers.example]
command = "example-server"
''')
            kimi_path.write_text('''# Keep the Kimi comment
theme = "dark"
[status_line]
items = ["model", "cwd"]
[notifications]
enabled = false
''')
            before = tomlkit.parse(codex_path.read_text()).unwrap()
            before_kimi = tomlkit.parse(kimi_path.read_text()).unwrap()
            configure(claude_path, codex_path, kimi_path, "/path with spaces/statusline", "/path with spaces/kimi")
            after_claude = json.loads(claude_path.read_text())
            self.assertEqual(after_claude["hooks"], claude["hooks"])
            self.assertEqual(after_claude["model"], claude["model"])
            self.assertEqual(after_claude["statusLine"]["padding"], 1)
            self.assertEqual(after_claude["statusLine"]["command"], "'/path with spaces/statusline'")
            after_codex = tomlkit.parse(codex_path.read_text()).unwrap()
            before["tui"]["status_line"] = CODEX_ITEMS
            before["tui"]["keymap"]["chat"]["edit_queued_message"] = ["alt-q", "shift-left", "alt-up"]
            self.assertEqual(after_codex, before)
            before_kimi["status_line"]["command"] = "'/path with spaces/kimi'"
            self.assertEqual(tomlkit.parse(kimi_path.read_text()).unwrap(), before_kimi)
            self.assertIn("# Keep this comment", codex_path.read_text())
            self.assertIn("# Keep the Kimi comment", kimi_path.read_text())
            for path in (claude_path, codex_path, kimi_path):
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            paths = (claude_path, codex_path, kimi_path)
            original = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in paths}
            configure(claude_path, codex_path, kimi_path, "/path with spaces/statusline", "/path with spaces/kimi")
            for path in paths:
                self.assertEqual(original[path], (path.read_bytes(), path.stat().st_mtime_ns))

    def test_new_settings_and_legacy_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "store-settings.json"
            original.write_text('{"model":"keep-me"}')
            original.chmod(0o444)
            claude_path, codex_path, kimi_path = root / "claude.json", root / "codex.toml", root / "kimi.toml"
            claude_path.symlink_to(original)
            configure(claude_path, codex_path, kimi_path, "/statusline", "/kimi-statusline")
            self.assertFalse(claude_path.is_symlink())
            self.assertEqual(original.read_text(), '{"model":"keep-me"}')
            self.assertEqual(tomlkit.parse(codex_path.read_text())["tui"]["status_line"], CODEX_ITEMS)
            self.assertEqual(tomlkit.parse(codex_path.read_text())["tui"]["keymap"]["chat"]["edit_queued_message"],
                             ["alt-q", "shift-left", "alt-up"])
            self.assertEqual(tomlkit.parse(kimi_path.read_text())["status_line"]["command"], "/kimi-statusline")

    def test_invalid_config_leaves_all_files_untouched(self):
        for invalid in ("codex", "kimi"):
            with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                claude_path, codex_path, kimi_path = root / "claude.json", root / "codex.toml", root / "kimi.toml"
                claude_path.write_text('{"model":"keep-me"}')
                codex_path.write_text("[invalid" if invalid == "codex" else "model = \"keep-me\"\n")
                kimi_path.write_text("[invalid" if invalid == "kimi" else "theme = \"dark\"\n")
                paths = (claude_path, codex_path, kimi_path)
                before = tuple(path.read_bytes() for path in paths)
                with self.assertRaises(tomlkit.exceptions.ParseError):
                    configure(claude_path, codex_path, kimi_path, "/statusline", "/kimi-statusline")
                self.assertEqual(before, tuple(path.read_bytes() for path in paths))


if __name__ == "__main__":
    unittest.main()
