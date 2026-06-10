# neorg-template-engine.nvim

Small folder-based template engine for Neorg notes.

## Setup

```lua
require("neorg_template_engine").setup({
  notes_dir = "~/notes",
  templates_dir = "~/notes/templates",
  author = vim.env.USER,
})
```

## Keymaps

```lua
vim.keymap.set("n", "<leader>nn", "<Plug>(neorg-template-engine.new-note)", { desc = "Create note here" })
vim.keymap.set("n", "<leader>nt", "<Plug>(neorg-template-engine.insert-template)", { desc = "Insert note template" })
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
{TITLE_INPUT}
{PROJECT_INPUT}
{STORY_INPUT}
{TOPIC_INPUT}
{AUTHOR}
{TODAY}
{NOW}
{FILENAME}
{CURSOR}
```
