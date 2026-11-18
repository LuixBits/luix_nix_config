"""Prepare the user's Obsidian checkout. Obsidian Git handles ongoing sync."""

import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time


REMOTE = "git@github.com:LuixBits/notes.git"
BRANCH = "obsidian"
KNOWN_REMOTES = {
    url + suffix
    for owner in ("luixbits", "devluixos")
    for repo in ("notes", "obsidian_sync")
    for url in (
        f"git@github.com:{owner}/{repo}",
        f"ssh://git@github.com/{owner}/{repo}",
        f"https://github.com/{owner}/{repo}",
    )
    for suffix in ("", ".git")
}


class NeedsAttention(Exception):
    pass


def git(directory, *args, check=True):
    return subprocess.run(
        ["git", "-C", str(directory), *args], check=check, text=True,
        stdout=subprocess.PIPE,
    )


def prepare(vault):
    if not vault.exists() or (vault.is_dir() and not any(vault.iterdir())):
        # A failed first fetch leaves the destination available for the next run.
        with tempfile.TemporaryDirectory(dir=vault.parent) as temporary:
            clone = Path(temporary) / "vault"
            git(vault.parent, "clone", "--single-branch", "--branch", BRANCH, REMOTE, str(clone))
            os.rename(clone, vault)
        return

    if not (vault / ".git").exists():
        raise NeedsAttention(f"{vault} already contains files and is not a Git checkout.")
    origin = git(vault, "config", "--get", "remote.origin.url", check=False).stdout.strip()
    push_urls = git(vault, "config", "--get-all", "remote.origin.pushurl", check=False).stdout.splitlines()
    if origin.lower() not in KNOWN_REMOTES or any(url.lower() not in KNOWN_REMOTES for url in push_urls):
        raise NeedsAttention(f"{vault} has a different Git remote. Check its origin before adopting it.")
    branch = git(vault, "branch", "--show-current").stdout.strip()
    tracking = git(vault, "for-each-ref", "--format=%(upstream:short)", f"refs/heads/{BRANCH}").stdout.strip()
    if origin == REMOTE and not push_urls and branch == BRANCH and tracking == f"origin/{BRANCH}":
        return
    if branch not in ("main", BRANCH):
        raise NeedsAttention(f"Finish work on the current branch in {vault} before adopting it.")
    gitdir = Path(git(vault, "rev-parse", "--absolute-git-dir").stdout.strip())
    for marker in ("MERGE_HEAD", "rebase-apply", "rebase-merge", "CHERRY_PICK_HEAD", "REVERT_HEAD", "sequencer"):
        if (gitdir / marker).exists():
            raise NeedsAttention(f"Finish the Git operation in {vault}, then restart obsidian-vault.service.")
    git(vault, "fetch", "--no-tags", REMOTE, f"refs/heads/{BRANCH}")
    target = git(vault, "rev-parse", "FETCH_HEAD").stdout.strip()
    if git(vault, "merge-base", "--is-ancestor", "HEAD", target, check=False).returncode:
        raise NeedsAttention(f"{vault} has local commits outside the published vault. Reconcile them first.")
    if branch != BRANCH:
        result = git(vault, "switch", "--no-overwrite-ignore", "--no-track", "-c", BRANCH, target, check=False)
    else:
        result = git(vault, "merge", "--ff-only", "--no-overwrite-ignore", target, check=False)
    if result.returncode:
        raise NeedsAttention(f"Git could not carry local work into the vault. Review git status in {vault}.")
    git(vault, "remote", "set-url", "origin", REMOTE)
    if push_urls:
        git(vault, "config", "--unset-all", "remote.origin.pushurl")
    git(vault, "remote", "set-branches", "origin", BRANCH)
    git(vault, "update-ref", f"refs/remotes/origin/{BRANCH}", target)
    git(vault, "branch", f"--set-upstream-to=origin/{BRANCH}", BRANCH)
    git(vault, "remote", "set-head", "origin", BRANCH)


def register(vault):
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    profile = config_home / "obsidian"
    profile.mkdir(parents=True, exist_ok=True)
    settings = profile / "obsidian.json"
    previous = settings.read_bytes() if settings.exists() else None
    data = json.loads(previous) if previous is not None else {}
    vaults = data.setdefault("vaults", {})
    if any(entry.get("path") == str(vault) for entry in vaults.values()):
        return
    # An open app owns its global registry and may save it when it closes.
    lock = profile / "SingletonLock"
    if lock.is_symlink():
        host, _, pid = os.readlink(lock).rpartition("-")
        if host == socket.gethostname() and pid.isdigit():
            try:
                os.kill(int(pid), 0)
            except ProcessLookupError:
                pass
            else:
                raise RuntimeError("Close Obsidian once to register the vault. Setup will retry.")
    vaults[secrets.token_hex(8)] = {"path": str(vault), "ts": time.time_ns() // 1_000_000, "open": True}
    with tempfile.NamedTemporaryFile(dir=profile, mode="w", delete=False) as f:
        tmp = Path(f.name)
        json.dump(data, f)
    try:
        if (settings.read_bytes() if settings.exists() else None) != previous:
            raise RuntimeError("Obsidian updated its registry. Setup will retry.")
        os.replace(tmp, settings)
    finally:
        tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    os.environ.setdefault("GIT_TERMINAL_PROMPT", "0")
    os.environ.setdefault("GIT_SSH_COMMAND", "ssh -o BatchMode=yes -o ConnectTimeout=15")
    vault = Path.home() / "obsidian_sync"
    try:
        prepare(vault)
        register(vault)
    except NeedsAttention as error:
        print(error, file=sys.stderr)
        sys.exit(3)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
    print(f"Obsidian vault ready at {vault}")
