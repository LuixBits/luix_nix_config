# Neorg View

A Neovim plugin for Neorg notes with highlighted links, Vim table navigation,
section styling and an optional Git sync header. The `.norg` file remains ordinary text.
Tested with Luix's installed Neovim 0.12.4 and Neorg configuration on NixOS.

## Use

Add this checkout to `runtimepath`, then call:

```lua
require('neorg_view').setup()
```

For the existing NVF setup, symlink `integration/nvf.lua` into
`~/.config/nvf/plugin/luix-neorg-view.lua`. The shim resolves its own location;
it has no machine-specific source path. Restart Neovim. This local integration
does not require a NixOS rebuild. To remove it, delete that symlink and restart.
Keep the source checkout while the link is installed.

`<leader>nr` switches between the reading view and source in the same window,
coordinating with Neorg's concealer. Insert mode exposes source for editing.
Saving, undo and links remain normal Neovim operations. Existing notes home,
YouTube, journal and calendar mappings stay in their current configuration.

Commands: `:NeorgViewToggle`, `:NeorgViewSync`, `:NeorgViewInfo`.
`:lua require('neorg_view').stop()` removes this layer and restores its window
options; restarting without the shim removes its commands and mappings too.

## Native tables

Use Neorg's named single cells (A1 through L256):

```norg
: A1 : Task
: B1 : State
: A2 : Table layout
: B2 : Done
```

Ranged cells are supported too:

```norg
:: C2
A longer next step can span source lines.
::
```

The first row is the header. Columns wrap to the available window width;
very narrow views become stacked records. Unicode display width is measured
in terminal cells. Keep cells in row order: A1, B1, A2, B2. Unsupported,
duplicate, sparse-row or out-of-order cells remain visible as source.
A table shared across two windows uses the narrower width.

## Navigation

Indexes work best as ordinary lists, with one link per source line:

```norg
- {:$/work/index:}[Work]
- {:$/private/index:}[Private]
```

Move normally with `hjkl`, `/`, counts and Vim's jump list. Enter opens the
link anywhere on a line containing a single link. For multiple links, place
the cursor on the one you want. `]l` and `[l` visit actual parsed links,
including multiple links on one line. Links inside code blocks are excluded.
Links use the `NeorgViewLink` highlight group, with an underline and the
colorscheme's information color. Tab keeps its existing meaning.

Inside a rendered table, `h/l` select columns and `j/k` select rows. Counts
work; moving beyond the first or last row leaves the table. The selected
cell is highlighted. Enter follows its link; `i` opens its source for editing.
Normal movement and editing resume outside tables. Source mode, visual mode
and operator motions act on the original text. Empty cells can be selected;
add their declaration in source mode to edit them.

The YouTube bridge can retain its Enter/Backspace handlers for task actions
and history. It calls `require('neorg_view.navigation').focus_link()` before
handling a link. The reusable plugin has no dependency on that bridge.
Standalone Enter uses Neorg's hop module; Backspace uses Vim's jump list.

Override any normal-mode binding, or set it to `false`:

```lua
require('neorg_view').setup({
  sync = false,
  keys = { next_link = ']l', previous_link = '[l', back = '<BS>' },
  -- mappings = false, -- leave every key to your configuration
})
```

Mappings are local to Norg buffers. `stop()` restores prior buffer mappings
that this plugin replaced, without removing mappings installed later.
Repeated `setup()` calls are supported. Parsing is cached by buffer changedtick.
The implementation lives in `lua/neorg_view/`; no personal notes or NixOS
configuration are needed to distribute it.

## What the sync header proves

Git status appears in the window's winbar. It cannot take the cursor or add
steps to `j/k`. Reading-mode motion skips concealed metadata and managed
markers; opening a note starts on visible text. Source mode keeps ordinary
line-by-line editing. The previous winbar is restored when leaving the note,
toggling to source, or stopping the plugin.

- `Checking Git` is shown until the first local metadata read completes. A failed
  metadata read reports Git unavailable rather than local clean.
- `Unsaved` refers to the current buffer. Git cannot see that text yet.
- `N changed` and `N ahead` come from the local Git working tree and upstream.
- `Local clean` means local tracked/untracked note state is clean. It does not
  certify that the remote is reachable or that a second device has pulled.
- `Syncing…` observes a run started here, or the existing notes-sync oneshot
  service while it is active/activating.
- `Push HH:MM:SS` is a recorded upstream-ref update **by push**, read from Git's
  reflog. Commit times, fetch times and a successful service exit are not used.
  If the reflog has no such event, the value is `unknown`. A no-op successful
  push need not update the ref and therefore need not change this timestamp.
- An observed unavailable/failed attempt leaves that timestamp intact.
  Attempt results live in the editor session; the upstream reflog persists.
  A new push observed from the existing helper clears an earlier failed attempt.
  Its commit identity distinguishes two pushes within the same clock second.

Git metadata reads are asynchronous. Rendering does not run a network request.
`NeorgViewSync` calls the existing notes-sync helper rather than adding a second
Git writer. It refuses to sync an unsaved current note. Other unsaved buffers
also remain unsaved and are outside any Git push.

For `~/notes`, the helper is discovered from the existing `<leader>ngs` mapping
and service state is observed. For any other repository, supply its command
and environment explicitly. The recording workspace uses a disposable local
bare remote; it never tests failure against the real notes remote.

```lua
require('neorg_view').setup({
  poll_interval = 2000,
  mappings = true,
  sync = {
    command = { '/path/to/existing/notes-sync' },
    service = false,
    env = { NOTES_REMOTE = '/path/to/local-test.git', NOTES_BRANCH = 'main' },
  },
})
```

`NOTES_DIR` is always set to the current note's repository root. Use `sync =
false` to hide the header. No credentials, raw helper output or long repository
paths appear in it.

## Journal dates in the native calendar

Use `setup({ journal = true })` to highlight dates with existing journal files
in Neorg's monthly calendar. The local integration shim enables this option.
The plugin reads `core.journal`'s workspace, folder and date strategy, so
personal notes and every project share the same calendar. It creates no
journal files or new picker. Today and range-selection styling take priority.
Set the `NeorgViewJournalDay` highlight group to change marked dates' appearance.

Native movement, selection and open callbacks remain Neorg's. Disabling the
option or calling `stop()` restores the original view. The extension requires
Neorg's `core.journal`, `core.dirman` and monthly calendar modules.

## Verification

Requirements: Neovim 0.12 (tested on 0.12.4), the Norg Tree-sitter parser,
and Neorg for opening links. The pure table and navigation suites run without
a personal Neovim configuration:

```console
make test
```

With an installed Neorg configuration and the existing sync helper:

```console
make test-integration
```

The suite checks native parsing, wrapping, Unicode, unchanged source, undo,
reading/source toggle, real helper pushes to a local bare remote, a zero-exit
offline attempt and a real two-clone conflict. Optional environment variable
`NEORG_VIEW_SYNC_COMMAND` selects the existing helper for another machine.
No source-repository commit or external push is performed by these tests.

The overnight production's capture and acceptance evidence is kept with its
private video workspace. This checkout contains the reusable implementation.

## Distribution

`make bundle` creates `dist/neorg-view.nvim.tar.gz` containing the Lua modules,
help, integration shim, tests and MIT license. It excludes Git history and
local artifacts. Extract it and add the folder to `runtimepath`, or use it as
a local plugin directory in your plugin manager. Nothing is published by the
build target.
