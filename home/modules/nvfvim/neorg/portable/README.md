# Shared notes plugins

Every host imports this module through the shared Neorg configuration. Nix
builds `neorg-view.nvim`, `youtube-notes.nvim` and the Node runtime from the
source snapshots in this directory. The configuration commit pins the plugin
code; `flake.lock` pins its dependencies. No source checkout, npm install,
manual plugin link or runtime download is needed on a device.

The sources remain proper plugin directories with modules, documentation,
licenses and tests. `sources.json` records their hashes. After reviewing an
upstream change, use `update-sources.py --neorg-view PATH --youtube-repository
PATH` to refresh both snapshots, then review and test the resulting diff.
`python update-sources.py --check` detects changes outside that refresh.

## Notes and editable state

The normal notes repository carries journal days, plans, narration and four
hidden Norg data files under `youtube/.state/`: `plan.norg`, `documents.norg`,
`catalog.norg` and `ownership.norg`. They contain JSON code blocks and use the
existing notes sync policy. The first two own dates and document tags. The
catalog stores source metadata and word counts, without duplicating narration
or storing machine paths. Ownership hashes protect edited generated content.

The Remotion checkout remains the authoring source for plans and narration.
Its exporter publishes those notes and refreshes the catalog. After the
one-time `export-workspace` migration, that checkout reads dates and tags from
the notes repository too. Its old `config/youtube-*.json` files are legacy seed
files; changes belong in journal Options, the dashboard or the shared CLI.
A laptop can perform those actions using only its synced notes. Conflicting
edits across devices still use the existing Git conflict handling.

## Rollout

Commit and distribute this configuration, then rebuild each machine using its
verified host. Home Manager installs the same plugins with that user's notes
path and backs up the two known legacy local plugin links during activation.
Restart Neovim and sync notes with `<leader>ngs`. The data files must have
arrived before the dashboard opens. There is no separate Home Manager switch.

Use `<leader>nyi` for the YouTube index, `<leader>nyd` for the dashboard,
`<leader>njj` for today's normal journal and `<leader>njc` for its calendar.
Inside the dashboard, movement and search are native Vim operations; `s`
changes status, `f` filters, `m` changes the document view, `c` opens the normal
calendar and `t` opens today's journal.

## Validation

The package tests cover rendering and navigation, two-device workspace edits,
shared journal updates, edited-content conflicts and preservation of personal
notes. A clean editor startup must load both plugins from `/nix/store`, with
no project checkout in `runtimepath`. Cross-host evaluation must resolve the
correct home paths for `pc`, `l` and `framework`.
