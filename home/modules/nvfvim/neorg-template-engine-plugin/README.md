# neorg-template-engine.nvim

Small folder-based template engine for Neorg notes.

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
