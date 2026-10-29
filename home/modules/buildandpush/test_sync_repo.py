"""Exercise the real Git sync in disposable repositories; never run NixOS activation."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("sync-repo.sh").resolve()


class SyncRepoTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="buildall-test-")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.remote = root / "origin.git"
        self.local = root / "local"
        self.peer = root / "peer"
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        self.git(root, "init", "--bare", "--initial-branch=master", str(self.remote))
        self.git(root, "clone", str(self.remote), str(self.local))
        self.identity(self.local)
        (self.local / "config.nix").write_text(
            "programs.codex = {\n  enable = true;\n  package = oldPackage;\n};\n"
        )
        (self.local / "notes.txt").write_text("base\n")
        self.commit(self.local, "Base")
        self.git(self.local, "push", "-u", "origin", "master")
        self.git(root, "clone", str(self.remote), str(self.peer))
        self.identity(self.peer)

    def git(self, repo, *args, check=True, text=True):
        return subprocess.run(
            ["git", "-C", str(repo), *args],
            env=self.env, check=check, capture_output=True, text=text,
        )

    def identity(self, repo):
        self.git(repo, "config", "user.name", "Buildall Test")
        self.git(repo, "config", "user.email", "buildall@example.invalid")

    def commit(self, repo, message):
        self.git(repo, "add", "-A")
        self.git(repo, "commit", "-m", message)

    def advance_remote(self, path="remote.txt", content="remote\n"):
        (self.peer / path).write_text(content)
        self.commit(self.peer, "Remote change")
        self.git(self.peer, "push")

    def sync(self):
        return subprocess.run(
            ["bash", "-c", 'set -euo pipefail; '
             'info() { echo "INFO: $*"; }; '
             'warn() { echo "WARN: $*"; }; '
             'error() { echo "ERROR: $*" >&2; }; '
             'source "$1"; sync_flake_repo "$2"', "test", str(SCRIPT), str(self.local)],
            env=self.env, capture_output=True, text=True,
        )

    def backups(self):
        return self.git(self.local, "for-each-ref", "--format=%(refname)",
                        "refs/buildall-backups").stdout.splitlines()

    def worktree_backup(self):
        return next(ref for ref in self.backups() if ref.endswith("/worktree"))

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_staged_patch_context_change_merges_and_original_index_is_recoverable(self):
        config = self.local / "config.nix"
        config.write_text(config.read_text().replace(
            "  package = oldPackage;", "  package = oldPackage;\n  context = localGuidance;"
        ))
        self.git(self.local, "add", "config.nix")
        original_index = self.git(self.local, "diff", "--cached", "--binary").stdout
        self.advance_remote("config.nix", (self.peer / "config.nix").read_text().replace(
            "enable = true", "enable = false"
        ))
        result = self.sync()
        self.assert_ok(result)
        self.assertIn("enable = false;\n  package = oldPackage;\n  context = localGuidance;", config.read_text())
        self.assertEqual(self.git(self.local, "diff", "--name-only", "--diff-filter=U").stdout, "")
        backup = self.worktree_backup()
        recovery = Path(self.temp.name) / "recovered"
        self.git(self.local, "worktree", "add", "--detach", str(recovery), backup + "^1")
        self.git(recovery, "stash", "apply", "--index", backup)
        self.assertEqual(self.git(recovery, "diff", "--cached", "--binary").stdout, original_index)

    def test_mixed_edits_untracked_deletions_binary_and_existing_stash_survive(self):
        (self.local / "notes.txt").write_text("older saved work\n")
        self.git(self.local, "stash", "push", "-m", "Existing user stash")
        old_stash = self.git(self.local, "rev-parse", "stash@{0}").stdout.strip()
        config = self.local / "config.nix"
        config.write_text(config.read_text().replace("true", "false"))
        self.git(self.local, "add", "config.nix")
        config.write_text(config.read_text() + "# unstaged note\n")
        (self.local / "notes.txt").unlink()
        (self.local / "local.bin").write_bytes(b"\x00\xffuntracked\n")
        (self.local / "new.nix").write_text("# staged addition\n")
        self.git(self.local, "add", "new.nix")
        expected_config = config.read_text()
        self.advance_remote()
        self.assert_ok(self.sync())
        self.assertEqual(config.read_text(), expected_config)
        self.assertFalse((self.local / "notes.txt").exists())
        self.assertEqual((self.local / "local.bin").read_bytes(), b"\x00\xffuntracked\n")
        self.assertEqual((self.local / "new.nix").read_text(), "# staged addition\n")
        self.assertIn(old_stash, self.git(self.local, "stash", "list", "--format=%H").stdout)
        backup = self.worktree_backup()
        self.assertEqual(self.git(self.local, "show", backup + "^3:local.bin", text=False).stdout,
                         b"\x00\xffuntracked\n")

    def test_real_content_conflict_keeps_remote_and_backup_and_can_be_resolved_once(self):
        (self.local / "notes.txt").write_text("local choice\n")
        self.git(self.local, "add", "notes.txt")
        self.advance_remote("notes.txt", "remote choice\n")
        result = self.sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("notes.txt", self.git(self.local, "diff", "--name-only", "--diff-filter=U").stdout)
        self.assertEqual(self.git(self.local, "rev-parse", "HEAD").stdout,
                         self.git(self.local, "rev-parse", "origin/master").stdout)
        backup = self.worktree_backup()
        self.assertEqual(self.git(self.local, "show", backup + ":notes.txt").stdout, "local choice\n")
        existing_backups = self.backups()
        self.assertNotEqual(self.sync().returncode, 0)
        self.assertEqual(self.backups(), existing_backups)
        (self.local / "notes.txt").write_text("local and remote choices\n")
        self.git(self.local, "add", "notes.txt")
        self.assert_ok(self.sync())
        self.assertEqual((self.local / "notes.txt").read_text(), "local and remote choices\n")

    def test_rebase_conflict_restores_head_index_unstaged_and_untracked_files(self):
        (self.local / "notes.txt").write_text("local committed choice\n")
        self.commit(self.local, "Local commit")
        head = self.git(self.local, "rev-parse", "HEAD").stdout
        config = self.local / "config.nix"
        config.write_text(config.read_text() + "# staged\n")
        self.git(self.local, "add", "config.nix")
        config.write_text(config.read_text() + "# unstaged\n")
        (self.local / "untracked.txt").write_text("keep me\n")
        index = self.git(self.local, "diff", "--cached", "--binary").stdout
        unstaged = self.git(self.local, "diff", "--binary").stdout
        self.advance_remote("notes.txt", "remote committed choice\n")
        result = self.sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git(self.local, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.local, "diff", "--cached", "--binary").stdout, index)
        self.assertEqual(self.git(self.local, "diff", "--binary").stdout, unstaged)
        self.assertEqual((self.local / "untracked.txt").read_text(), "keep me\n")
        self.assertFalse((self.local / ".git/rebase-merge").exists())
        self.assertTrue(self.worktree_backup())

    def test_untracked_collision_stops_before_stashing(self):
        (self.local / "new.txt").write_text("untracked local\n")
        head = self.git(self.local, "rev-parse", "HEAD").stdout
        self.advance_remote("new.txt", "tracked remote\n")
        self.assertNotEqual(self.sync().returncode, 0)
        self.assertEqual((self.local / "new.txt").read_text(), "untracked local\n")
        self.assertEqual(self.git(self.local, "show", "origin/master:new.txt").stdout, "tracked remote\n")
        self.assertEqual(self.git(self.local, "rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git(self.local, "stash", "list").stdout, "")

    def test_ignored_file_is_not_overwritten_or_stashed(self):
        (self.local / ".git/info/exclude").write_text("private.txt\n")
        (self.local / "private.txt").write_text("private local data\n")
        self.advance_remote("private.txt", "remote data\n")
        self.assertNotEqual(self.sync().returncode, 0)
        self.assertEqual((self.local / "private.txt").read_text(), "private local data\n")
        self.assertEqual(self.git(self.local, "stash", "list").stdout, "")

    def test_untracked_directory_is_not_replaced_by_remote_file(self):
        (self.local / "incoming").mkdir()
        (self.local / "incoming/note.txt").write_text("local note\n")
        self.advance_remote("incoming", "remote file\n")
        self.assertNotEqual(self.sync().returncode, 0)
        self.assertEqual((self.local / "incoming/note.txt").read_text(), "local note\n")
        self.assertEqual(self.git(self.local, "stash", "list").stdout, "")

    def test_fetch_failure_does_not_stash_or_modify_local_files(self):
        (self.local / "notes.txt").write_text("unsaved\n")
        self.git(self.local, "add", "notes.txt")
        self.git(self.local, "remote", "set-url", "origin", str(Path(self.temp.name) / "missing.git"))
        before = self.git(self.local, "status", "--porcelain").stdout
        self.assertNotEqual(self.sync().returncode, 0)
        self.assertEqual(self.git(self.local, "status", "--porcelain").stdout, before)
        self.assertEqual(self.backups(), [])
        self.assertEqual(self.git(self.local, "stash", "list").stdout, "")

    def test_no_incoming_commits_preserves_staging_split(self):
        (self.local / "notes.txt").write_text("staged\n")
        self.git(self.local, "add", "notes.txt")
        (self.local / "notes.txt").write_text("staged\nunstaged\n")
        index = self.git(self.local, "diff", "--cached", "--binary").stdout
        unstaged = self.git(self.local, "diff", "--binary").stdout
        self.assert_ok(self.sync())
        self.assertEqual(self.git(self.local, "diff", "--cached", "--binary").stdout, index)
        self.assertEqual(self.git(self.local, "diff", "--binary").stdout, unstaged)

    def test_local_commit_is_rebased_with_dirty_changes_preserved(self):
        (self.local / "committed.txt").write_text("local commit\n")
        self.commit(self.local, "Local commit")
        original_head = self.git(self.local, "rev-parse", "HEAD").stdout.strip()
        (self.local / "notes.txt").write_text("dirty\n")
        self.advance_remote()
        self.assert_ok(self.sync())
        self.assertEqual((self.local / "committed.txt").read_text(), "local commit\n")
        self.assertEqual((self.local / "remote.txt").read_text(), "remote\n")
        self.assertEqual((self.local / "notes.txt").read_text(), "dirty\n")
        head_backup = next(ref for ref in self.backups() if ref.endswith("/head"))
        self.assertEqual(self.git(self.local, "rev-parse", head_backup).stdout.strip(), original_head)
        self.assert_ok(self.git(self.local, "merge-base", "--is-ancestor", "origin/master", "HEAD", check=False))


if __name__ == "__main__":
    unittest.main()
