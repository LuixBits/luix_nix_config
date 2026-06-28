# neorg-template-engine.nvim

Small folder-based template engine for Neorg notes.

## Installation

Install the plugin like any other Neovim Lua plugin. It only needs to be on
Neovim's runtimepath before calling `require("neorg_template_engine")`.

With `lazy.nvim` from a local checkout:

```lua
{
  dir = "~/path/to/neorg-template-engine.nvim",
  dependencies = { "nvim-neorg/neorg" },
  config = function()
    require("neorg_template_engine").setup({
      notes_dir = "~/notes",
      templates_dir = "~/notes/templates",
      workspace = "notes",
      author = vim.env.USER,
    })
  end,
}
```

With Neovim's built-in package loading, place the plugin directory here:

```text
~/.local/share/nvim/site/pack/plugins/start/neorg-template-engine.nvim/
```

Then configure it from your normal `init.lua`:

```lua
require("neorg_template_engine").setup({
  notes_dir = "~/notes",
  templates_dir = "~/notes/templates",
  workspace = "notes",
  author = vim.env.USER,
})
```

The `workspace` value must match your Neorg `core.dirman` workspace name:

```lua
require("neorg").setup({
  load = {
    ["core.defaults"] = {},
    ["core.dirman"] = {
      config = {
        workspaces = {
          notes = "~/notes",
        },
        default_workspace = "notes",
      },
    },
  },
})
```

## Setup

```lua
require("neorg_template_engine").setup({
  notes_dir = "~/notes",
  templates_dir = "~/notes/templates",
  workspace = "notes",
  author = vim.env.USER,
})
```

`workspace` must match the name of the Neorg `core.dirman` workspace where new
notes should be created.

## Keymaps

```lua
vim.keymap.set("n", "<leader>nn", "<Plug>(neorg-template-engine.new-note)", { desc = "Create note here" })
vim.keymap.set("n", "<leader>nt", "<Plug>(neorg-template-engine.insert-template)", { desc = "Insert note template" })
vim.keymap.set("n", "<leader>nT", "<Plug>(neorg-template-engine.edit-templates)", { desc = "Edit note templates" })
```

Commands are also available:

```vim
:NeorgTemplateNew
:NeorgTemplateInsert
:NeorgTemplateEdit
```

## Module Layout

The main plugin file is:

```text
lua/neorg_template_engine/init.lua
```

That is normal Neovim plugin structure. It does not replace your personal
`init.lua`; it is only the entry point for the `neorg_template_engine` Lua
module. Neovim loads it when you call:

```lua
require("neorg_template_engine")
```

## Templates

Any `.norg` file below `templates_dir` is offered in the picker. Nested
templates are supported:

```text
~/notes/templates/meeting.norg
~/notes/templates/work/documentation.norg
```

The picker labels become:

```text
meeting
work/documentation
```

Supported placeholders:

```text
{AUTHOR}     author from setup(), or $USER
{TODAY}      current date as YYYY-MM-DD
{NOW}        current date and time as YYYY-MM-DD HH:MM
{FILENAME}   current buffer filename
{CURSOR}     final cursor position after insertion
```

Input placeholders ask for a value when the template is inserted:

```text
{TITLE_INPUT}
{PROJECT_INPUT}
{STORY_INPUT}
{TOPIC_INPUT}
```

You can define your own prompt placeholders by using uppercase names ending in
`_INPUT`:

```norg
* {CLIENT_INPUT} Research
  Client: {CLIENT}
  Topic: {TOPIC_INPUT}
  Date: {TODAY}

** Notes
  {CURSOR}
```

In that example, the engine asks for `CLIENT` and `TOPIC`. The entered value for
`{CLIENT_INPUT}` is inserted there, and the same value can be reused later with
`{CLIENT}`.
