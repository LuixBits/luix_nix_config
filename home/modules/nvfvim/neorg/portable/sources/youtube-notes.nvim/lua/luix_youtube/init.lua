local M = {}
local options, watcher
local module_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local Documents = dofile(module_dir .. "/documents.lua")
local dashboard = { windows = {}, restore = {}, history = {}, document = { mode = "videos", status = "active" } }
local highlights = vim.api.nvim_create_namespace("luix_youtube.dashboard")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "YouTube" })
end

local function relative_note(buffer)
  local name = vim.api.nvim_buf_get_name(buffer or 0)
  if name:sub(1, #options.notes_root + 1) == options.notes_root .. "/" then
    return name:sub(#options.notes_root + 2)
  end
end

local function remember_origin()
  local relative = relative_note()
  if vim.api.nvim_get_current_buf() ~= dashboard.buf
    and not relative then
    dashboard.previous = vim.api.nvim_get_current_buf()
    dashboard.history = {}
  end
end

local function refresh_notes()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and not vim.bo[buffer].modified and relative_note(buffer) then
      vim.api.nvim_buf_call(buffer, function()
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        if #lines == 1 and lines[1] == "" and vim.fn.filereadable(vim.api.nvim_buf_get_name(buffer)) == 1 then
          -- A newly opened day can be filled by the task exporter after it
          -- opens. checktime alone does not reload an empty new-file buffer.
          vim.cmd("silent! edit")
        else vim.cmd("silent! checktime") end
      end)
    end
  end
end

local function command(args)
  local result = options.backend and vim.deepcopy(options.backend) or { options.node, options.repo_root .. "/scripts/youtube-notes.mjs" }
  vim.list_extend(result, args)
  vim.list_extend(result, { "--notes-root", options.notes_root, "--repo-root", options.repo_root })
  return result
end

local function run(args, callback)
  vim.system(command(args), { text = true, cwd = options.repo_root }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local message = vim.trim(result.stderr or "")
        if message == "" then message = vim.trim(result.stdout or "") end
        notify(message ~= "" and message or "Could not update the notes", vim.log.levels.ERROR)
        return
      end
      local ok, value = pcall(vim.json.decode, result.stdout or "", { luanil = { object = true, array = true } })
      if not ok then notify("Could not read the video information", vim.log.levels.ERROR); return end
      refresh_notes()
      if callback then callback(value) end
    end)
  end)
end

local function remember_page()
  dashboard.history[#dashboard.history + 1] = {
    buffer = vim.api.nvim_get_current_buf(), cursor = vim.api.nvim_win_get_cursor(0),
  }
end

local function edit(relative, back)
  remember_origin()
  if relative_note() == relative then return end
  if not back then remember_page() end
  vim.cmd.edit(vim.fn.fnameescape(options.notes_root .. "/" .. relative))
end

function M.start_watch()
  if options.backend and vim.fn.filereadable(options.notes_root .. "/youtube/.state/catalog.norg") == 0 then return end
  if watcher or vim.env.LUIX_YOUTUBE_NO_WATCH == "1" then return end
  watcher = vim.fn.jobstart(command({ "watch" }), {
    cwd = options.repo_root,
    on_stdout = function(_, lines)
      for _, line in ipairs(lines) do
        local ok, value = pcall(vim.json.decode, line)
        if ok and value.conflicts and #value.conflicts > 0 then
          vim.schedule(function() notify("Your edits were kept; these notes need attention: " .. table.concat(value.conflicts, ", "), vim.log.levels.WARN) end)
        end
      end
      vim.schedule(function() refresh_notes(); M.refresh_dashboard() end)
    end,
    on_stderr = function(_, lines)
      local message = vim.trim(table.concat(lines, "\n"))
      if message ~= "" then vim.schedule(function() notify(message, vim.log.levels.WARN) end) end
    end,
    on_exit = function() watcher = nil end,
  })
  if watcher <= 0 then watcher = nil; notify("Could not start note updates", vim.log.levels.ERROR) end
end

function M.current_target(strict)
  if not dashboard.buf or vim.api.nvim_get_current_buf() ~= dashboard.buf or not dashboard.view then return end
  local position = vim.api.nvim_win_get_cursor(0)
  local targets = dashboard.view.targets[position[1]] or {}
  for _, target in ipairs(targets) do
    if position[2] >= target.first and position[2] < target.last then return target.action end
  end
  if not strict and #targets == 1 then return targets[1].action end
end

function M.open_video(event)
  if event.note then edit(event.note)
  elseif event.production then run({ "video", event.production }, function(value) edit(value.note) end)
  else run({ "list" }, function(events)
    for _, item in ipairs(events) do if item.id == event.id then edit(item.note); return end end
  end) end
end

function M.activate()
  local target = M.current_target()
  if not target then return end
  if target.kind == "calendar" then M.calendar()
  elseif target.kind == "journal" then M.journal()
  elseif target.kind == "document" then dashboard.document.selected = target.id; edit(target.note)
  elseif target.date then M.journal(target.date)
  elseif target and target.note then edit(target.note) end
end

function M.back()
  if dashboard.buf and vim.api.nvim_get_current_buf() == dashboard.buf then
    if dashboard.previous and vim.api.nvim_buf_is_valid(dashboard.previous) then vim.api.nvim_set_current_buf(dashboard.previous)
    else vim.cmd("enew") end
    return
  end
  while #dashboard.history > 0 do
    local previous = table.remove(dashboard.history)
    if vim.api.nvim_buf_is_valid(previous.buffer) and previous.buffer ~= vim.api.nvim_get_current_buf() then
      if previous.buffer == dashboard.buf then M.render(dashboard.data, true)
      else
        vim.api.nvim_set_current_buf(previous.buffer)
        local line = math.min(previous.cursor[1], vim.api.nvim_buf_line_count(previous.buffer))
        local content = vim.api.nvim_buf_get_lines(previous.buffer, line - 1, line, false)[1] or ""
        vim.api.nvim_win_set_cursor(0, { line, math.min(previous.cursor[2], #content) })
      end
      return
    end
  end
  local relative = relative_note() or ""
  if relative:match("^youtube/") and relative ~= "youtube/index.norg" then
    local parent = vim.fn.fnamemodify(relative, ":h")
    if relative:match("/index%.norg$") then parent = vim.fn.fnamemodify(parent, ":h") end
    while parent:match("^youtube") do
      local target = parent .. "/index.norg"
      if vim.fn.filereadable(options.notes_root .. "/" .. target) == 1 then edit(target, true); return end
      parent = vim.fn.fnamemodify(parent, ":h")
    end
  end
  if relative ~= "" and relative ~= "index.norg" then edit("index.norg", true)
  elseif dashboard.previous and vim.api.nvim_buf_is_valid(dashboard.previous) and dashboard.previous ~= vim.api.nvim_get_current_buf() then
    vim.api.nvim_set_current_buf(dashboard.previous)
  else vim.cmd("enew") end
end

function M.render(data, focus, reset)
  if not focus and (not dashboard.buf or vim.api.nvim_get_current_buf() ~= dashboard.buf) then return end
  local saved_view, anchor
  if not reset and vim.api.nvim_get_current_buf() == dashboard.buf then
    saved_view, anchor = vim.fn.winsaveview(), M.current_target()
  end
  if not dashboard.buf or not vim.api.nvim_buf_is_valid(dashboard.buf) then
    dashboard.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(dashboard.buf, "youtube://production")
    vim.bo[dashboard.buf].filetype = "luix_youtube"
    vim.bo[dashboard.buf].bufhidden = "hide"
    vim.bo[dashboard.buf].swapfile = false
    vim.keymap.set("n", "<CR>", M.activate, { buffer = dashboard.buf, desc = "Open document or journal" })
    vim.keymap.set("n", "<BS>", M.back, { buffer = dashboard.buf, desc = "Back" })
    vim.keymap.set("n", "q", M.back, { buffer = dashboard.buf, desc = "Back" })
    vim.keymap.set("n", "c", M.calendar, { buffer = dashboard.buf, desc = "Journal calendar" })
    vim.keymap.set("n", "t", M.journal, { buffer = dashboard.buf, desc = "Today's journal" })
    vim.keymap.set("n", "i", M.index, { buffer = dashboard.buf, desc = "YouTube index" })
    vim.keymap.set("n", "s", M.document_status, { buffer = dashboard.buf, desc = "Change document status" })
    vim.keymap.set("n", "m", M.document_mode, { buffer = dashboard.buf, desc = "Choose document view" })
    vim.keymap.set("n", "f", function()
      vim.ui.select(Documents.states, { prompt = "Filter documents", format_item = function(item) return item.label end }, function(item)
        if item then M.filter_documents(item.id) end
      end)
    end, { buffer = dashboard.buf, desc = "Filter documents" })
    vim.keymap.set("n", "<2-LeftMouse>", function()
      local position = vim.fn.getmousepos()
      if position.winid ~= 0 and vim.api.nvim_win_get_buf(position.winid) == dashboard.buf then
        vim.api.nvim_set_current_win(position.winid)
        vim.api.nvim_win_set_cursor(0, { position.line, math.max(0, position.column - 1) })
        M.activate()
      end
    end, { buffer = dashboard.buf, desc = "Open document" })
  end
  local window = vim.api.nvim_get_current_win()
  local desired = { number = false, relativenumber = false, wrap = true, linebreak = true, cursorline = true, signcolumn = "no", foldcolumn = "0" }
  if not dashboard.windows[window] then
    local saved = {}
    for key in pairs(desired) do saved[key] = vim.wo[window][key] end
    dashboard.windows[window] = saved
  end
  if vim.api.nvim_get_current_buf() ~= dashboard.buf then
    remember_origin()
    vim.api.nvim_set_current_buf(dashboard.buf)
  end
  for key, value in pairs(desired) do vim.wo[window][key] = value end
  dashboard.data = data
  local view = Documents.build(data, vim.api.nvim_win_get_width(window), dashboard.document)
  dashboard.document.selected = view.selected
  dashboard.view = view
  vim.bo[dashboard.buf].readonly = false
  vim.bo[dashboard.buf].modifiable = true
  vim.api.nvim_buf_set_lines(dashboard.buf, 0, -1, false, view.lines)
  vim.bo[dashboard.buf].modifiable = false
  vim.bo[dashboard.buf].readonly = true
  vim.bo[dashboard.buf].modified = false
  vim.api.nvim_buf_clear_namespace(dashboard.buf, highlights, 0, -1)
  for _, hl in ipairs(view.highlights) do
    local last = math.min(hl.last, #view.lines[hl.row + 1])
    if last > hl.first then
      vim.api.nvim_buf_set_extmark(dashboard.buf, highlights, hl.row, hl.first, { end_col = last, hl_group = hl.group })
    end
  end
  if saved_view then
    if anchor and anchor.id then
      for _, choice in ipairs(view.agenda) do
        if choice.action.id == anchor.id then saved_view.lnum = choice.cursor[1]; break end
      end
    end
    saved_view.lnum = math.min(saved_view.lnum, #view.lines)
    vim.fn.winrestview(saved_view)
  else vim.api.nvim_win_set_cursor(window, view.work_cursor) end
end

function M.refresh_dashboard(focus)
  if not focus and (not dashboard.buf or vim.api.nvim_get_current_buf() ~= dashboard.buf) then return end
  run({ "overview" }, function(data) M.render(data, focus) end)
end

function M.filter_documents(status)
  dashboard.document.status = status
  M.render(dashboard.data, true, true)
end

function M.document_mode()
  vim.ui.select(Documents.modes, { prompt = "Show documents", format_item = function(item) return item.label end }, function(item)
    if item then dashboard.document.mode = item.id; dashboard.document.status = "all"; M.render(dashboard.data, true, true) end
  end)
end

function M.document_status(id)
  -- Keymaps pass no document ID; the current row wins over the last selection.
  if type(id) ~= "string" then
    local target = M.current_target()
    id = target and target.kind == "document" and target.id
  end
  if not id then notify("Select a document first"); return end
  run({ "documents" }, function(data)
    local document
    for _, item in ipairs(data.items) do if item.id == id then document = item; break end end
    if not document then notify("This document is no longer available"); return end
    local choices = {}
    for _, state in ipairs(Documents.statuses) do choices[#choices + 1] = state end
    vim.ui.select(choices, {
      prompt = "Status: " .. document.title,
      format_item = function(item) return item.label .. (item.id == document.status and " (current)" or "") end,
    }, function(choice)
      if choice then run({ "document-status", id, choice.id }, function()
        M.refresh_dashboard()
        notify("Document status: " .. choice.label)
      end) end
    end)
  end)
end

local function open_dashboard()
  if vim.api.nvim_get_current_buf() ~= dashboard.buf then dashboard.previous = vim.api.nvim_get_current_buf() end
  dashboard.document = { mode = "videos", status = "active" }
  dashboard.history = {}
  run({ "sync" }, function() M.start_watch(); M.refresh_dashboard(true) end)
end

function M.open() open_dashboard() end

-- Use the same native Neorg entry points as <leader>njc and <leader>njj.
function M.calendar()
  remember_origin()
  remember_page()
  vim.cmd("Neorg journal custom")
end

function M.index()
  local function open() M.start_watch(); edit("youtube/index.norg") end
  if vim.fn.filereadable(options.notes_root .. "/youtube/index.norg") == 1 then open()
  else run({ "sync" }, open) end
end

function M.journal(date)
  if date and not date:match("^%d%d%d%d%-%d%d%-%d%d$") then return end
  remember_origin()
  remember_page()
  vim.cmd(date and ("Neorg journal custom " .. date) or "Neorg journal today")
end

local function task_change(args, message)
  run(args, function() M.refresh_dashboard(); notify(message) end)
end

function M.task_options(id)
  run({ "list" }, function(events)
    local event
    for _, candidate in ipairs(events) do if candidate.id == id then event = candidate; break end end
    if not event then notify("This task is no longer scheduled"); return end
    local choices = {
      { label = "Open video", action = function() M.open_video(event) end },
      { label = event.status == "done" and "Reopen task" or "Mark done", action = function()
        task_change({ "status", id, event.status == "done" and "planned" or "done" }, "Task updated")
      end },
      { label = "Change day", action = function()
        vim.ui.input({ prompt = "New day (YYYY-MM-DD): ", default = event.date }, function(date)
          if date then task_change({ "move", id, date }, "Task moved") end
        end)
      end },
    }
    if not event.production then
      choices[#choices + 1] = { label = "Choose video", action = function()
        run({ "catalog" }, function(productions)
          vim.ui.select(vim.tbl_filter(function(item) return item.channel == event.channel and item.kind == "video" and item.files > 0 and item.status ~= "done" and item.status ~= "trashed" end, productions), {
            prompt = "Choose the prepared video", format_item = function(item) return item.title end,
          }, function(item) if item then task_change({ "assign", id, item.id }, "Video chosen") end end)
        end)
      end }
    end
    vim.ui.select(choices, { prompt = event.title, format_item = function(item) return item.label end }, function(choice)
      if choice then choice.action() end
    end)
  end)
end

function M.next_link(direction)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local current = vim.api.nvim_win_get_cursor(0)[1]
  for offset = 1, #lines do
    local row = (current - 1 + direction * offset) % #lines + 1
    if lines[row]:match("%b{}%[[^%]]+%]") then
      local anchor = row > 1 and lines[row - 1]:match("^::%s+[A-L][1-9]%d*%s*$") and row - 1 or row
      if anchor ~= current then
        vim.api.nvim_win_set_cursor(0, { anchor, 0 })
        return
      end
    end
  end
end

function M.hop()
  local nav = package.loaded['neorg_view.navigation']
  if nav and not nav.focus_link() then return end
  local line = vim.api.nvim_get_current_line()
  local column = vim.api.nvim_win_get_cursor(0)[2] + 1
  if line:match("^::%s+[A-L][1-9]%d*%s*$") then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local content = {}
    for _, part in ipairs(vim.api.nvim_buf_get_lines(0, row, -1, false)) do
      if part:match("^::%s*$") then break end
      content[#content + 1] = part
    end
    line = table.concat(content, " ")
    column = 1
  end
  local selected, fallback
  for first, target, label, last in line:gmatch("()(%b{})%[([^%]]+)%]()") do
    local item = { target = target, caption = label }
    fallback = fallback or item
    if column >= first and column < last then selected = item end
  end
  selected = selected or fallback
  local caption = selected and selected.caption
  if caption == "Change status" then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for index = row - 1, math.max(1, row - 5), -1 do
      local previous = vim.api.nvim_buf_get_lines(0, index - 1, index, false)[1] or ""
      local id = previous:match("^youtube%-document: (.+)$")
      if id then M.document_status(id); return end
    end
  end
  if caption == "Options" then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for index = row - 1, math.max(1, row - 8), -1 do
      local previous = vim.api.nvim_buf_get_lines(0, index - 1, index, false)[1] or ""
      local id = previous:match("^youtube%-task: ([a-z0-9%-]+)$")
      if id then M.task_options(id); return end
      if previous:match("^%*%* ") then break end
    end
  end
  local file = selected and selected.target:match("^%{:[$]/([^:}]+):%}$")
  if file and not file:match("^/") and not file:find("..", 1, true) then
    if not file:match("%.norg$") then file = file .. ".norg" end
    local year, month, day = file:match("^journal/(%d%d%d%d)/(%d%d)/(%d%d)%.norg$")
    if year then M.journal(year .. "-" .. month .. "-" .. day); return end
    if vim.fn.filereadable(options.notes_root .. "/" .. file) == 1 then edit(file); return end
  end
  require("neorg")
  local modules = require("neorg.core.modules")
  if not modules.get_module("core.esupports.hop") then modules.load_module("core.esupports.hop") end
  local before = { buffer = vim.api.nvim_get_current_buf(), cursor = vim.api.nvim_win_get_cursor(0) }
  modules.get_module("core.esupports.hop").hop_link()
  if vim.api.nvim_get_current_buf() ~= before.buffer then dashboard.history[#dashboard.history + 1] = before end
end

function M.setup(config)
  options = vim.tbl_extend("force", {
    notes_root = vim.env.LUIX_NOTES_ROOT or vim.fn.expand("~/notes"), node = vim.fn.exepath("node"),
  }, config or {})
  M.actions = {
    { key = "i", description = "YouTube index", callback = M.index },
    { key = "d", description = "Dashboard", callback = M.open },
  }
  for _, suffix in ipairs({ "", "i", "d", "c", "j", "t", "s", "v", "p", "m", "u", "a", "e", "r", "?" }) do
    pcall(vim.keymap.del, "n", "<leader>ny" .. suffix)
  end
  pcall(vim.keymap.del, "n", "<leader>nY")
  for _, name in ipairs({ "YoutubeToday", "YoutubeSync", "YoutubeSchedule", "YoutubeLibrary", "YoutubePlan", "YoutubeNotes", "YoutubeMenu", "YoutubeMove", "YoutubeStatus", "YoutubeAssign", "YoutubeSource" }) do
    pcall(vim.api.nvim_del_user_command, name)
  end
  vim.api.nvim_create_user_command("Youtube", M.open, {})
  vim.api.nvim_create_user_command("YoutubeIndex", M.index, {})
  vim.api.nvim_create_user_command("YoutubeCalendar", M.calendar, {})
  vim.api.nvim_create_user_command("YoutubeJournal", function() M.journal() end, {})
  for _, action in ipairs(M.actions) do
    vim.keymap.set("n", "<leader>ny" .. action.key, action.callback, { desc = action.description })
  end
  vim.schedule(function()
    local ok, which_key = pcall(require, "which-key")
    if ok then which_key.add({ { "<leader>ny", group = "YouTube" } }) end
  end)
  local group = vim.api.nvim_create_augroup("LuixYouTubeNotes", { clear = true })
  local function link_highlight()
    local color = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
    vim.api.nvim_set_hl(0, "LuixYouTubeLink", { default = true, fg = color.fg, underline = true })
  end
  link_highlight()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = link_highlight })
  vim.api.nvim_create_autocmd("BufWinLeave", { group = group, pattern = "youtube://production", callback = function()
    local window = vim.api.nvim_get_current_win()
    dashboard.restore[window] = dashboard.windows[window]
    dashboard.windows[window] = nil
  end })
  vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = function(args)
    local window = vim.api.nvim_get_current_win()
    if args.buf ~= dashboard.buf and dashboard.restore[window] then
      for key, value in pairs(dashboard.restore[window]) do vim.wo[window][key] = value end
      dashboard.restore[window] = nil
    end
  end })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = group, callback = function()
    if dashboard.buf and vim.api.nvim_get_current_buf() == dashboard.buf then M.render(dashboard.data) end
  end })
  vim.api.nvim_create_autocmd("BufEnter", { group = group, pattern = "*.norg", callback = function(args)
    local relative = relative_note(args.buf)
    if not relative then return end
    local year, month, day = relative:match("^journal/(%d%d%d%d)/(%d%d)/(%d%d)%.norg$")
    vim.bo[args.buf].bufhidden = "hide"
    if relative == "index.norg" or relative:match("^%.indexes/") or relative:match("^youtube/") or year then M.start_watch() end
    vim.keymap.set("n", "<CR>", M.hop, { buffer = args.buf, desc = "Open link" })
    vim.keymap.set("n", "<BS>", M.back, { buffer = args.buf, desc = "Back" })

  end })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
    if watcher then vim.fn.jobstop(watcher); watcher = nil end
  end })
end

return M
