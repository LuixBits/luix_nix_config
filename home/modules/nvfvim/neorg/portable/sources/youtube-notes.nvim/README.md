# YouTube Notes

A Neovim plugin for a shared Norg video workspace. It provides an ordinary
list dashboard, document tags, journal task actions and back navigation.
Dates open through Neorg's existing journal and calendar. It preserves
unsaved buffers and refuses to overwrite edited generated sections.

Add this directory to runtimepath and configure the plugin explicitly:

```lua
require('luix_youtube').setup({
  notes_root = vim.fn.expand('~/notes'),
  repo_root = vim.fn.expand('~/notes'),
  backend = { '/path/to/youtube-notes' },
})
```

Nix supplies the backend executable with a fixed Node runtime. The editor
never loads code from the notes repository. The workspace's hidden Norg data
files hold mutable dates, tags, catalog metadata and ownership hashes.
The authoring checkout is needed only to export new plans and narration.

Use `:Youtube` and `:YoutubeIndex`. `:YoutubeCalendar` and `:YoutubeJournal`
are aliases for the normal Neorg journal commands. In the dashboard, `hjkl`,
counts and search retain their Vim behavior; Enter opens, Backspace returns,
`s` changes status, `f` filters and `m` changes the document view.

Run `make test` with Node and Neovim installed. The authoring repository's
curated production-data check is excluded from this portable distribution;
all fixture-based behavior checks run here.
