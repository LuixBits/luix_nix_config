local M = {}

local uv = vim.uv or vim.loop
local state = {
  author = "",
  notes_dir = "",
  templates_dir = "",
}

local function normalize_path(path)
  return vim.fs.normalize(vim.fn.expand(path))
end

local function join_path(...)
  return table.concat({ ... }, "/")
end

local function relative_note_path(dir, name)
  local root = normalize_path(state.notes_dir)
  dir = normalize_path(dir)

  if dir == root then
    return name
  end

  if vim.startswith(dir, root .. "/") then
    return dir:sub(#root + 2) .. "/" .. name
  end

  return name
end

local function display_title(name)
  local title = vim.fn.fnamemodify(name or "", ":t:r")
  title = title:gsub("[_-]+", " ")
  if title == "" then
    return "Untitled"
  end
  return title
end

local function current_note_title()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    return "Untitled"
  end
  return display_title(current_file)
end

local function target_dir()
  if vim.bo.filetype == "NvimTree" then
    local ok, api = pcall(require, "nvim-tree.api")
    if ok then
      local node = api.tree.get_node_under_cursor()
      if node and node.absolute_path then
        if node.type == "directory" then
          return node.absolute_path
        end
        return vim.fn.fnamemodify(node.absolute_path, ":h")
      end
    end
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file ~= "" then
    local current_dir = normalize_path(vim.fn.fnamemodify(current_file, ":h"))
    local notes_dir = normalize_path(state.notes_dir)
    if current_dir == notes_dir or vim.startswith(current_dir, notes_dir .. "/") then
      return current_dir
    end
  end

  return state.notes_dir
end

local function move_to_note_window()
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
    if vim.bo.filetype == "NvimTree" then
      vim.cmd("vsplit")
    end
  end
end

local function scan_templates(dir, prefix, items)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return
  end

  while true do
    local name, item_type = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local path = join_path(dir, name)
    local label = prefix == "" and name or join_path(prefix, name)

    if item_type == "directory" then
      scan_templates(path, label, items)
    elseif item_type == "file" and name:match("%.norg$") then
      table.insert(items, {
        label = label:gsub("%.norg$", ""),
        path = path,
      })
    end
  end
end

local function available_templates(include_blank)
  local items = {}
  scan_templates(state.templates_dir, "", items)

  table.sort(items, function(left, right)
    return left.label < right.label
  end)

  if include_blank then
    table.insert(items, 1, { label = "Blank note" })
  end

  return items
end

local function choose_template(include_blank, callback)
  local items = available_templates(include_blank)
  if #items == 0 then
    vim.notify("No Neorg templates found in " .. state.templates_dir, vim.log.levels.WARN)
    callback(nil)
    return
  end

  vim.ui.select(items, {
    prompt = "Note template:",
    format_item = function(item)
      return item.label
    end,
  }, callback)
end

local function find_cursor_marker(text, marker)
  local start_index = text:find(marker, 1, true)
  if not start_index then
    return nil, nil, text
  end

  local before = text:sub(1, start_index - 1)
  local after = text:sub(start_index + #marker)
  local line = 0

  for _ in before:gmatch("\n") do
    line = line + 1
  end

  local column = #(before:match("([^\n]*)$") or "")
  return line, column, before .. after
end

local function expand_template(content, fields)
  local cursor_marker = "__NEORG_TEMPLATE_CURSOR__"
  local today = os.date("%Y-%m-%d")
  local function replacement(value)
    return tostring(value or ""):gsub("%%", "%%%%")
  end
  local values = {
    AUTHOR = state.author ~= "" and state.author or (vim.env.USER or ""),
    FILENAME = vim.fn.expand("%:t"),
    NOW = os.date("%Y-%m-%d %H:%M"),
    PROJECT = fields.project,
    PROJECT_INPUT = fields.project,
    STORY = fields.story,
    STORY_INPUT = fields.story,
    TITLE = fields.title,
    TITLE_INPUT = fields.title,
    TOPIC = fields.topic,
    TOPIC_INPUT = fields.topic,
    TODAY = today,
  }

  content = content:gsub("{CURSOR}", cursor_marker, 1)
  content = content:gsub("{CURSOR}", "")

  for key, value in pairs(values) do
    content = content:gsub("{" .. key .. "}", replacement(value))
  end

  local cursor_line, cursor_column
  cursor_line, cursor_column, content = find_cursor_marker(content, cursor_marker)
  return content, cursor_line, cursor_column
end

local function collect_template_fields(content, defaults, callback)
  local fields = {
    project = "",
    story = "",
    title = defaults.title,
    topic = defaults.title,
  }

  local prompts = {
    {
      token = "{TITLE_INPUT}",
      field = "title",
      prompt = "Template title: ",
      default = defaults.title,
    },
    {
      token = "{PROJECT_INPUT}",
      field = "project",
      prompt = "Project name: ",
      default = "",
    },
    {
      token = "{STORY_INPUT}",
      field = "story",
      prompt = "Story number: ",
      default = "",
    },
    {
      token = "{TOPIC_INPUT}",
      field = "topic",
      prompt = "Topic: ",
      default = defaults.title,
    },
  }

  local needed = {}
  for _, spec in ipairs(prompts) do
    if content:find(spec.token, 1, true) then
      table.insert(needed, spec)
    end
  end

  local function ask(index)
    local spec = needed[index]
    if not spec then
      callback(fields)
      return
    end

    vim.ui.input({ prompt = spec.prompt, default = spec.default }, function(input)
      if input == nil then
        return
      end

      fields[spec.field] = vim.trim(input)
      ask(index + 1)
    end)
  end

  ask(1)
end

local function split_lines(content)
  return vim.split(content, "\n", { plain = true })
end

local function place_cursor(start_row, start_col, lines, cursor_line, cursor_column)
  if not cursor_line then
    cursor_line = #lines - 1
    cursor_column = #(lines[#lines] or "")
  end

  local target_row = start_row + cursor_line
  local target_col = cursor_column

  if cursor_line == 0 then
    target_col = start_col + cursor_column
  end

  vim.api.nvim_win_set_cursor(0, { target_row + 1, target_col })
end

local function apply_template(template, opts)
  if not template or not template.path then
    return
  end

  local ok, raw_lines = pcall(vim.fn.readfile, template.path)
  if not ok then
    vim.notify("Could not read template: " .. template.path, vim.log.levels.ERROR)
    return
  end

  local content = table.concat(raw_lines, "\n")
  local default_title = opts.title or current_note_title()

  collect_template_fields(content, { title = default_title }, function(fields)
    if fields.title == "" then
      fields.title = default_title
    end
    if fields.topic == "" then
      fields.topic = fields.title
    end

    local expanded, cursor_line, cursor_column = expand_template(content, fields)
    local lines = split_lines(expanded)

    if opts.replace then
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      place_cursor(0, 0, lines, cursor_line, cursor_column)
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local start_row = cursor[1] - 1
    local start_col = cursor[2]
    vim.api.nvim_buf_set_text(0, start_row, start_col, start_row, start_col, lines)
    place_cursor(start_row, start_col, lines, cursor_line, cursor_column)
  end)
end

function M.new_note_here()
  local dir = target_dir()

  vim.ui.input({ prompt = "New note: " }, function(input)
    input = vim.trim(input or "")
    if input == "" then
      return
    end

    choose_template(true, function(template)
      local dirman = require("neorg").modules.get_module("core.dirman")
      if not dirman then
        vim.notify("Neorg dirman is not loaded", vim.log.levels.ERROR)
        return
      end

      local path = relative_note_path(dir, input)
      move_to_note_window()
      dirman.create_file(path, "notes")

      if template and template.path then
        vim.schedule(function()
          apply_template(template, {
            replace = true,
            title = display_title(input),
          })
        end)
      end
    end)
  end)
end

function M.insert_template()
  choose_template(false, function(template)
    apply_template(template, {
      replace = false,
      title = current_note_title(),
    })
  end)
end

function M.edit_templates()
  vim.cmd.edit(vim.fn.fnameescape(state.templates_dir))
end

function M.setup(opts)
  opts = opts or {}
  state.author = opts.author or ""
  state.notes_dir = normalize_path(opts.notes_dir or "~/notes")
  state.templates_dir = normalize_path(opts.templates_dir or (state.notes_dir .. "/templates"))

  vim.fn.mkdir(state.notes_dir, "p")
  vim.fn.mkdir(state.templates_dir, "p")

  vim.keymap.set("n", "<Plug>(neorg-template-engine.new-note)", M.new_note_here)
  vim.keymap.set("n", "<Plug>(neorg-template-engine.insert-template)", M.insert_template)
  vim.keymap.set("n", "<Plug>(neorg-template-engine.edit-templates)", M.edit_templates)

  vim.api.nvim_create_user_command("NeorgTemplateNew", M.new_note_here, {})
  vim.api.nvim_create_user_command("NeorgTemplateInsert", M.insert_template, {})
  vim.api.nvim_create_user_command("NeorgTemplateEdit", M.edit_templates, {})
end

return M
