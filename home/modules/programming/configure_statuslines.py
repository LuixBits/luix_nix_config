"""Merge managed UI preferences while preserving CLI and Herdr settings."""

import json
import os
from pathlib import Path
import shlex
import sys
import tempfile

import tomlkit


CODEX_ITEMS = [
    "model-with-reasoning",
    # Codex 0.158 exposes this only when Enterprise cost data is available.
    "estimated-thread-cost",
    "total-input-tokens",
    "total-output-tokens",
    "context-remaining",
    "five-hour-limit",
    "weekly-limit",
    "current-dir",
    "git-branch",
    "permissions",
]


def write_atomic(path, text):
    if path.exists() and not path.is_symlink() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    # Replace a legacy store symlink rather than trying to write through it.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            file.write(text)
            file.flush()
            os.chmod(temporary, 0o600)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def configure(claude_path, codex_path, kimi_path, claude_command, kimi_command):
    claude = json.loads(claude_path.read_text()) if claude_path.exists() else {}
    codex = tomlkit.parse(codex_path.read_text()) if codex_path.exists() else tomlkit.document()
    kimi = tomlkit.parse(kimi_path.read_text()) if kimi_path.exists() else tomlkit.document()
    # Parse and serialize all three before writing any, so malformed settings
    # cannot silently get replaced with defaults.
    claude["statusLine"] = {
        **(claude.get("statusLine") or {}),
        "type": "command",
        "command": shlex.quote(claude_command),
    }
    if "tui" not in codex:
        codex["tui"] = tomlkit.table()
    codex["tui"]["status_line"] = CODEX_ITEMS
    # Put a readable, terminal-friendly shortcut first so question prompts
    # advertise it. Keep Codex's built-in alternatives available as well.
    keymap = codex["tui"].setdefault("keymap", tomlkit.table())
    chat = keymap.setdefault("chat", tomlkit.table())
    chat["edit_queued_message"] = ["alt-q", "shift-left", "alt-up"]
    if "status_line" not in kimi:
        kimi["status_line"] = tomlkit.table()
    kimi["status_line"]["command"] = shlex.quote(kimi_command)
    claude_text = json.dumps(claude, indent=2, ensure_ascii=False) + "\n"
    codex_text = tomlkit.dumps(codex)
    kimi_text = tomlkit.dumps(kimi)
    write_atomic(claude_path, claude_text)
    write_atomic(codex_path, codex_text)
    write_atomic(kimi_path, kimi_text)


if __name__ == "__main__":
    configure(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4], sys.argv[5])
