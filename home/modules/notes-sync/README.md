# Notes Git sync

This shared Home Manager module saves local note changes, fetches the remote,
rebases onto `origin/main`, and pushes. Its user timer runs every ten minutes.
Neorg's existing Git keymaps use the same helpers. Manual pull also saves
pending supported changes locally before integrating the remote; it does not
push those commits.

## Synced files

- `.gitignore` and `.norg` files, including relative links to existing notes
  inside this repository.
- `**/flashcards/reviews.jsonl`, which contains shared flashcard review history.
- The YouTube compatibility directory links `youtube/shorts` and
  `youtube/videos/<production-id>`. These must be relative links to existing
  directories inside the repository's `youtube/` tree.

Unrelated files still stop automatic commits. Local flashcard workspaces,
`*.flashcards-backup` backups, and `*.norg.*.tmp` files are ignored. The helper
adds those ignore rules to existing clones while preserving personal entries.
It does not remove tracked review history.

## Repair and device rollout

The previous file policy rejected review history and the newer directory links.
The timer could remain enabled while every service run failed before saving or
fetching notes. This was a local file-policy failure; remote access worked.

The fix belongs to this shared module. Each device needs the updated Nix
configuration and its own normal rebuild for its verified host. Restart Neovim
after rebuilding so its Git keymaps use the updated helper paths. Notes and the
updated `.gitignore` travel through the notes repository separately.

Back up unsynced notes on a device before its first repaired sync. The full
sync helper commits supported local changes before fetching and rebasing. If
both devices edited the same lines, or changed a directory differently during
the layout migration, Git can stop for a conflict. Resolve that conflict before
syncing again; do not discard a device's notes to force it to match the remote.

## Inspect operation

```console
systemctl --user status notes-sync.timer notes-sync.service
journalctl --user -u notes-sync.service -n 40 --no-pager
```

An active timer alone does not prove that a push succeeded. With the timer's
non-fatal-network setting, an offline attempt can exit successfully after
saving local changes. A future status widget must record successful fetch,
integration and push events separately.

## Regression checks

`test_notes_sync.py` takes `--sync`, `--push` and `--pull` paths to the three
built helpers. It creates disposable local Git remotes and two device clones;
it never connects to the real notes remote. It checks review history, ignored
local state, portable links, directory-to-link migration, unrelated-file
refusal, two-device edits, conflicts, offline commits and the manual helpers.
