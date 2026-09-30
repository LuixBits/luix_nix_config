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
            claude_path = Path(directory) / "claude.json"
            codex_path = Path(directory) / "codex.toml"
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
[mcp_servers.example]
command = "example-server"
''')
            before = tomlkit.parse(codex_path.read_text()).unwrap()
            configure(claude_path, codex_path, "/path with spaces/statusline")
            after_claude = json.loads(claude_path.read_text())
            self.assertEqual(after_claude["hooks"], claude["hooks"])
            self.assertEqual(after_claude["model"], claude["model"])
            self.assertEqual(after_claude["statusLine"]["padding"], 1)
            self.assertEqual(after_claude["statusLine"]["command"], "'/path with spaces/statusline'")
            after_codex = tomlkit.parse(codex_path.read_text()).unwrap()
            before["tui"]["status_line"] = CODEX_ITEMS
            self.assertEqual(after_codex, before)
            self.assertIn("# Keep this comment", codex_path.read_text())
            self.assertEqual(codex_path.stat().st_mode & 0o777, 0o600)
            original = (claude_path.read_bytes(), codex_path.read_bytes(), codex_path.stat().st_mtime_ns)
            configure(claude_path, codex_path, "/path with spaces/statusline")
            self.assertEqual(original, (claude_path.read_bytes(), codex_path.read_bytes(), codex_path.stat().st_mtime_ns))

    def test_new_settings_and_legacy_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "store-settings.json"
            original.write_text('{"model":"keep-me"}')
            original.chmod(0o444)
            claude_path, codex_path = root / "claude.json", root / "codex.toml"
            claude_path.symlink_to(original)
            configure(claude_path, codex_path, "/statusline")
            self.assertFalse(claude_path.is_symlink())
            self.assertEqual(original.read_text(), '{"model":"keep-me"}')
            self.assertEqual(tomlkit.parse(codex_path.read_text())["tui"]["status_line"], CODEX_ITEMS)

    def test_invalid_config_leaves_both_files_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            claude_path, codex_path = Path(directory) / "claude.json", Path(directory) / "codex.toml"
            claude_path.write_text('{"model":"keep-me"}')
            codex_path.write_text("[invalid")
            before = (claude_path.read_bytes(), codex_path.read_bytes())
            with self.assertRaises(tomlkit.exceptions.ParseError):
                configure(claude_path, codex_path, "/statusline")
            self.assertEqual(before, (claude_path.read_bytes(), codex_path.read_bytes()))


if __name__ == "__main__":
    unittest.main()
