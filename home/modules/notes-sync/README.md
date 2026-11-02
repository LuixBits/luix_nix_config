# Notes Git sync

This shared Home Manager module saves local note changes, fetches the remote,
rebases onto `origin/main`, and pushes. Its user timer runs every ten minutes.
Neorg's existing Git keymaps use the same helpers. Manual pull also saves
pending changes locally before integrating the remote; it does not
push those commits.

## Synced files

The complete Git working tree is synced: notes, Markdown, JSON, images,
attachments, scripts, logs, and other files. Additions, edits, moves and
deletions all propagate between devices. Git stores symlinks as links without
following or uploading their targets; dangling links do not block cleanup.

Normal Git ignore rules determine which new files stay local. Local flashcard
workspaces, `*.flashcards-backup` backups, and `*.norg.*.tmp` files are ignored.
The helper adds those ignore rules to existing clones while preserving personal
entries. Already tracked files, including review history, remain synced.

## Repair and device rollout

The previous file-type allowlist rejected attachments and other non-note files.
The timer could remain enabled while every service run failed before saving or
fetching notes. Sync now uses the repository's ignore rules instead of an
extension allowlist.

The fix belongs to this shared module. Each device needs the updated Nix
configuration and its own normal rebuild for its verified host. Restart Neovim
after rebuilding so its Git keymaps use the updated helper paths. Notes and the
updated `.gitignore` travel through the notes repository separately.

Back up unsynced notes on a device before its first repaired sync. The full
sync helper commits local changes before fetching and rebasing. If
both devices edited the same lines, or changed a directory differently during
the layout migration, Git can stop for a conflict. Resolve that conflict before
syncing again; do not discard a device's notes to force it to match the remote.

For cleanup on a PC, first sync this device, then sync the PC to receive the
combined state. Move and delete files on the PC, sync it again, then sync this
device to receive the cleaned-up tree. Avoid editing the same files on both
devices during cleanup. Ignored local files remain local and are not removed
by a remote cleanup.

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
local state, links, directory-to-link migration, mixed file types, a PC cleanup
round trip with moves and deletions, conflicts, offline commits and the manual
helpers.
