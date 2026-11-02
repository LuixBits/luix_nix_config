#!/usr/bin/env python3
"""Exercise built notes-sync helpers against disposable local Git remotes."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


COMMANDS = {}


class NotesSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="notes-sync-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.notes = self.root / "device one"
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null",
                        GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
        self.run_command(["git", "init", "--bare", "--initial-branch=main", self.remote])
        self.notes.mkdir()
        self.git(self.notes, "init", "-b", "main")
        self.configure(self.notes)
        self.write("index.norg", "* Notes\n")
        self.write(".gitignore", ".local-private/\n")
        self.commit(self.notes, "Initial notes")
        self.git(self.notes, "remote", "add", "origin", str(self.remote))
        self.git(self.notes, "push", "-u", "origin", "main")

    def run_command(self, args, cwd=None, env=None, check=True):
        result = subprocess.run([str(arg) for arg in args], cwd=cwd,
                                env=self.env if env is None else env,
                                text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=30)
        if check and result.returncode:
            self.fail(f"Command failed ({result.returncode}): {args}\n{result.stdout}")
        return result

    def git(self, repo, *args, check=True):
        return self.run_command(["git", "-C", repo, *args], check=check)

    def configure(self, repo):
        self.git(repo, "config", "user.name", "Notes sync test")
        self.git(repo, "config", "user.email", "notes-sync@example.invalid")
        self.git(repo, "config", "commit.gpgsign", "false")

    def write(self, relative, content, repo=None):
        path = (self.notes if repo is None else repo) / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def commit(self, repo, message):
        self.git(repo, "add", "-A")
        self.git(repo, "commit", "-m", message)

    def clone(self):
        repo = self.root / "device two"
        self.run_command(["git", "clone", self.remote, repo])
        self.configure(repo)
        return repo

    def sync(self, repo=None, command="sync", check=True, **overrides):
        repo = self.notes if repo is None else repo
        env = dict(self.env, NOTES_DIR=str(repo), NOTES_REMOTE=str(self.remote),
                   NOTES_BRANCH="main", NOTES_LOCK_FILE=str(self.root / "sync.lock"),
                   NOTES_SYNC_NON_FATAL_NETWORK="0", NOTES_SYNC_SKIP_UNINITIALIZED="0")
        env.update(overrides)
        return self.run_command([COMMANDS[command]], env=env, check=check)

    def head(self, repo=None):
        return self.git(self.notes if repo is None else repo, "rev-parse", "HEAD").stdout.strip()

    def tracked(self, repo=None):
        return set(self.git(self.notes if repo is None else repo,
                            "ls-files").stdout.splitlines())

    def assert_synced(self):
        self.assertEqual(self.head(), self.git(self.remote, "rev-parse", "main").stdout.strip())
        self.assertEqual(self.git(self.notes, "status", "--porcelain").stdout, "")

    def test_notes_review_history_and_local_state(self):
        self.write("japanese/flashcards/reviews.jsonl", '{"card":"hello","rating":3}\n')
        self.write("japanese/flashcards/cards.norg", "* Hello\n")
        self.write("japanese/flashcards/.flashcards-workspace.json", "{}\n")
        self.write("japanese/flashcards/cards.norg.flashcards-backup", "old\n")
        self.write("japanese/flashcards/cards.norg.123.tmp", "scratch\n")
        self.sync()
        self.assert_synced()
        self.assertIn("japanese/flashcards/reviews.jsonl", self.tracked())
        self.assertNotIn("japanese/flashcards/.flashcards-workspace.json", self.tracked())
        self.assertNotIn("japanese/flashcards/cards.norg.flashcards-backup", self.tracked())
        self.assertNotIn("japanese/flashcards/cards.norg.123.tmp", self.tracked())
        self.assertTrue((self.notes / ".gitignore").read_text().startswith(".local-private/\n"))
        head = self.head()
        self.sync()
        self.assertEqual(head, self.head(), "A second idle sync must not create a commit")
        other = self.clone()
        self.assertEqual((other / "japanese/flashcards/reviews.jsonl").read_text(),
                         '{"card":"hello","rating":3}\n')

    def test_relative_aliases_survive_clone_and_deletion(self):
        self.write("youtube/LuixBits/nixos/example/index.norg", "* Example\n")
        self.write("youtube/LuixBits/shorts/older-notes/example.norg", "* Short\n")
        (self.notes / "youtube/videos").mkdir()
        (self.notes / "youtube/videos/example").symlink_to("../LuixBits/nixos/example")
        (self.notes / "youtube/shorts").symlink_to("LuixBits/shorts/older-notes")
        (self.notes / "youtube/example.norg").symlink_to("LuixBits/nixos/example/index.norg")
        self.sync()
        other = self.clone()
        self.assertTrue((other / "youtube/videos/example/index.norg").is_file())
        self.assertTrue((other / "youtube/shorts/example.norg").is_file())
        self.assertEqual((other / "youtube/example.norg").read_text(), "* Example\n")
        (self.notes / "youtube/videos/example").unlink()
        (self.notes / "youtube/example.norg").unlink()
        self.sync()
        self.assertNotIn("youtube/videos/example", self.tracked())
        self.assertNotIn("youtube/example.norg", self.tracked())
        self.assert_synced()

    def test_tracked_directory_can_become_alias(self):
        old = self.write("youtube/shorts/old.norg", "* Old note\n")
        self.commit(self.notes, "Old layout")
        self.git(self.notes, "push")
        self.write("youtube/LuixBits/shorts/older-notes/old.norg", old.read_text())
        old.unlink()
        old.parent.rmdir()
        old.parent.symlink_to("LuixBits/shorts/older-notes")
        self.sync()
        self.assert_synced()
        self.assertIn("youtube/shorts", self.tracked())
        self.assertNotIn("youtube/shorts/old.norg", self.tracked())
        self.assertEqual((self.clone() / "youtube/shorts/old.norg").read_text(), "* Old note\n")

    def test_all_file_types_sync_including_staged_and_ignored_files(self):
        for staged in (False, True):
            with self.subTest(staged=staged):
                prefix = "staged" if staged else "unstaged"
                paths = {
                    f"{prefix}/report.md": "# Report\n",
                    f"{prefix}/data.json": "{}\n",
                    f"{prefix}/build.log": "Build complete\n",
                    f"{prefix}/script.sh": "#!/bin/sh\nexit 0\n",
                    f"{prefix}/README": "Notes attachment\n",
                }
                for path, content in paths.items():
                    self.write(path, content)
                image = self.notes / prefix / "image.png"
                image.write_bytes(b"\x89PNG\r\n\x1a\n\x00\xff")
                self.write(".local-private/ignored.json", "private local state\n")
                if staged:
                    self.git(self.notes, "add", prefix)
                self.sync()
                self.assert_synced()
                for path, content in paths.items():
                    self.assertEqual(self.git(self.remote, "show", f"main:{path}").stdout,
                                     content)
                exported = self.root / f"{prefix}-export"
                self.run_command(["git", "clone", self.remote, exported])
                self.assertEqual((exported / prefix / "image.png").read_bytes(),
                                 image.read_bytes())
                self.assertNotIn(".local-private/ignored.json", self.tracked())

    def test_symlinks_sync_without_following_targets(self):
        external = self.root / "external"
        external.mkdir()
        (external / "private.txt").write_text("Outside repository\n")
        targets = {"absolute": str(external), "relative": "../external",
                   "dangling": "missing", "loop": "."}
        for name, target in targets.items():
            (self.notes / name).symlink_to(target)
        self.sync()
        other = self.clone()
        for name, target in targets.items():
            self.assertEqual(os.readlink(other / name), target)
            self.assertIn(name, self.tracked(other))
        self.assertFalse(any(path.endswith("private.txt") for path in self.tracked()))
        self.assert_synced()

    def test_pc_cleanup_round_trip_with_mixed_files(self):
        self.sync()
        pc = self.clone()
        self.write("from-pc.md", "# PC note\n", repo=pc)
        self.sync(pc)
        self.write("inbox/report.md", "# Laptop report\n")
        self.write("inbox/data.json", '{"keep": true}\n')
        self.write("inbox/build.log", "Disposable output\n")
        attachment = self.notes / "inbox/image.png"
        attachment.write_bytes(b"\x89PNG\x00\xff")
        self.sync()
        self.assertEqual((self.notes / "from-pc.md").read_text(), "# PC note\n")
        self.sync(pc)
        (pc / "organized").mkdir()
        for name in ("report.md", "data.json", "image.png"):
            (pc / "inbox" / name).rename(pc / "organized" / name)
        (pc / "inbox/build.log").unlink()
        (pc / "inbox").rmdir()
        (pc / "from-pc.md").unlink()
        self.sync(pc)
        self.sync()
        self.assertFalse((self.notes / "inbox").exists())
        self.assertFalse((self.notes / "from-pc.md").exists())
        self.assertEqual((self.notes / "organized/report.md").read_text(), "# Laptop report\n")
        self.assertEqual((self.notes / "organized/data.json").read_text(), '{"keep": true}\n')
        self.assertEqual((self.notes / "organized/image.png").read_bytes(), b"\x89PNG\x00\xff")
        self.assertEqual(self.head(), self.head(pc))
        self.assert_synced()
        head = self.head()
        self.sync()
        self.assertEqual(head, self.head(), "Cleaned-up files must not reappear")

    def test_two_devices_keep_local_and_remote_notes(self):
        self.sync()
        other = self.clone()
        self.write("remote-note.norg", "* From device one\n")
        self.sync()
        self.write("local-note.norg", "* From device two\n", repo=other)
        self.sync(other)
        self.sync()
        for repo in (self.notes, other):
            self.assertEqual((repo / "remote-note.norg").read_text(), "* From device one\n")
            self.assertEqual((repo / "local-note.norg").read_text(), "* From device two\n")
        self.assert_synced()

    def test_conflict_stops_without_overwriting_either_version(self):
        self.sync()
        other = self.clone()
        self.write("index.norg", "* Device one revision\n")
        self.sync()
        remote_head = self.head()
        self.write("index.norg", "* Device two revision\n", repo=other)
        result = self.sync(other, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CONFLICT", result.stdout)
        self.assertEqual(self.git(self.remote, "rev-parse", "main").stdout.strip(), remote_head)
        self.assertEqual(self.git(other, "show", "ORIG_HEAD:index.norg").stdout,
                         "* Device two revision\n")
        repeated = self.sync(other, check=False)
        self.assertNotEqual(repeated.returncode, 0)
        self.assertIn("already in progress", repeated.stdout)

    def test_offline_sync_keeps_local_commit(self):
        self.write("offline.norg", "* Keep this\n")
        result = self.sync(check=False, NOTES_REMOTE=str(self.root / "missing-remote.git"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git(self.notes, "show", "HEAD:offline.norg").stdout, "* Keep this\n")
        self.assertEqual(self.git(self.notes, "status", "--porcelain").stdout, "")
        self.sync()
        self.assert_synced()

    def test_manual_push_and_pull_share_policy(self):
        self.sync()
        other = self.clone()
        self.write("japanese/flashcards/reviews.jsonl", '{"card":"one"}\n')
        self.write("attachments/report.md", "# Shared report\n")
        self.sync(command="push")
        self.sync(other, command="pull")
        self.assertEqual((other / "japanese/flashcards/reviews.jsonl").read_text(),
                         '{"card":"one"}\n')
        self.assertEqual((other / "attachments/report.md").read_text(), "# Shared report\n")

    def test_first_pull_preserves_an_older_devices_unsynced_notes(self):
        other = self.clone()
        self.write("local-note.norg", "* Keep the other device's note\n", repo=other)
        self.write("japanese/flashcards/.flashcards-workspace.json", "{}\n", repo=other)
        self.write("remote-note.norg", "* Updated remote\n")
        self.sync()
        self.sync(other, command="pull")
        self.assertEqual((other / "local-note.norg").read_text(),
                         "* Keep the other device's note\n")
        self.assertEqual((other / "remote-note.norg").read_text(), "* Updated remote\n")
        self.assertEqual(self.git(other, "status", "--porcelain").stdout, "")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("sync", "push", "pull"):
        parser.add_argument(f"--{name}", required=True)
    args, remaining = parser.parse_known_args()
    COMMANDS.update(vars(args))
    unittest.main(argv=[__file__, *remaining])
