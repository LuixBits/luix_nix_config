local source = assert(vim.env.LUIX_YOUTUBE_SOURCE_ROOT)
local repo = assert(vim.env.LUIX_YOUTUBE_TEST_REPO)
local notes = assert(vim.env.LUIX_YOUTUBE_TEST_NOTES)
local plugin = vim.env.LUIX_YOUTUBE_PLUGIN_ROOT or source .. "/nvim/youtube-notes"
local function check(condition, message) assert(condition, message) end
local function wait(predicate, message) check(vim.wait(10000, predicate, 20), message) end
local function text() return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") end
local function key(value) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "xt", false) end
local function read_plan() return vim.json.decode(table.concat(vim.fn.readfile(repo .. "/config/youtube-plan.json"), "\n")) end
local function read_documents() return vim.json.decode(table.concat(vim.fn.readfile(repo .. "/config/youtube-documents.json"), "\n")) end
local function at(relative) return vim.api.nvim_buf_get_name(0) == notes .. "/" .. relative end

local function follow(caption)
    for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      local column = line:find("[" .. caption .. "]", 1, true)
      if column then vim.api.nvim_win_set_cursor(0, { row, column - 1 }); key("<CR>"); return end
    end
    error("Missing link: " .. caption)
  end

local ok, err = pcall(function()
  local Documents = dofile(plugin .. "/lua/luix_youtube/documents.lua")
  local data = { today = "2026-10-29", documents = { items = {} } }
  for n = 1, 20 do
    data.documents.items[n] = { id = "video-" .. n, title = "A long searchable title 選択 " .. n,
      channel = "LuixBits", kind = "video", status = "planning", statusLabel = "Planning", note = "video-" .. n .. ".norg" }
  end
  for _, width in ipairs({ 40, 80, 120 }) do
    local view = Documents.build(data, width, {})
    check(#view.agenda == 20, "A document did not occupy exactly one row")
    check(not table.concat(view.lines, "\n"):find("│", 1, true), "Navigation still uses a table")
    for _, item in ipairs(data.documents.items) do
      check(table.concat(view.lines, "\n"):find(item.title, 1, true), "A title was truncated and cannot be searched")
    end
  end
  -- The adapter must delegate to the native command. The configured smoke test
  -- exercises the actual Neorg picker and its date callback separately.
  local native_calls = {}
  vim.api.nvim_create_user_command("Neorg", function(command)
    native_calls[#native_calls + 1] = command.args
    local date = command.args:match("^journal custom (%d%d%d%d%-%d%d%-%d%d)$")
    if command.args == "journal today" then date = "2026-10-29" end
    if date then vim.cmd.edit(vim.fn.fnameescape(notes .. "/journal/" .. date:gsub("-", "/") .. ".norg")) end
  end, { nargs = "+" })

  local groups = {}
  package.preload["which-key"] = function() return { add = function(items) groups = items end } end
  vim.g.mapleader = " "
  local M = dofile(plugin .. "/lua/luix_youtube/init.lua")
  M.setup({ repo_root = repo, notes_root = notes })
  wait(function() return #groups > 0 end, "YouTube which-key group was not registered")
  check(groups[1].group == "YouTube", "Wrong key group label")
  for _, suffix in ipairs({ "i", "d" }) do check(vim.fn.maparg(" ny" .. suffix, "n") ~= "", "Missing main shortcut") end
  for _, suffix in ipairs({ "c", "j", "t", "s", "v", "p", "m", "u", "a", "e", "r", "?" }) do check(vim.fn.maparg(" ny" .. suffix, "n") == "", "An old extra shortcut is still advertised") end
  check(vim.fn.maparg(" ny", "n") == "", "The group prefix is ambiguous")

  local previous = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(previous, 0, -1, false, { "An unsaved note that must stay intact." })
  vim.wo.number, vim.wo.relativenumber = true, true
  M.open()
  wait(function() return vim.bo.filetype == "luix_youtube" end, "Dashboard did not open")
  check(not vim.bo.modifiable and vim.bo.readonly, "Dashboard is editable")
  check(text():find("Video production", 1, true) and text():find("Browse linked indexes", 1, true), "Document overview is not visible on the dashboard")
  check(text():find("Active · 1 shown", 1, true) and not text():find("One short", 1, true), "Released work leaked into the active overview")
  check(M.current_target().kind == "document" and M.current_target().id == "sample", "Dashboard did not select a video index")
  local tag_choice = "in-progress"
  vim.ui.select = function(items, _, callback)
    for _, item in ipairs(items) do if item.id == tag_choice then callback(item); return end end
    error("Missing document action: " .. tag_choice)
  end
  key("s")
  wait(function() local target = M.current_target(); return target and target.document and target.document.status == "in-progress" end, "Document status did not update")
  check(read_documents().items.sample.status == "in-progress" and read_plan().events[1].status == "planned", "Document status changed calendar tasks")
  M.filter_documents("done")
  check(M.current_target().id == "one-short", "Released filter did not show the old video")
  M.filter_documents("in-progress")
  check(M.current_target().id == "sample", "Status filter lost the video index")
  tag_choice = "trashed"
  key("s")
  wait(function() return read_documents().items.sample.status == "trashed" and text():find("No documents with this status.", 1, true) end, "Trashed tag was not applied")
  M.filter_documents("trashed")
  check(M.current_target().id == "sample" and vim.fn.filereadable(notes .. "/youtube/LuixBits/projects/sample/index.norg") == 1, "Trashed deleted or hid the actual file")
  tag_choice = "planning"
  key("s")
  wait(function() return read_documents().items.sample.status == "planning" and text():find("No documents with this status.", 1, true) end, "Trashed document could not be restored")
  M.filter_documents("all")
  tag_choice = "scripts"
  M.document_mode()
  check(text():find("Show: Plans & scripts", 1, true), "Plans and scripts mode did not open")
  local child = M.current_target()
  check(child.document.kind == "script" or child.document.kind == "plan", "Source documents are missing from the manager")
  tag_choice = "done"
  key("s")
  wait(function() local target = M.current_target(); return target and target.document and target.document.status == "done" end, "Individual document tag did not update")
  check(read_documents().items[child.id].status == "done" and read_documents().items.sample.status == "planning", "Individual tag overwrote its parent video")
  tag_choice = "indexes"
  M.document_mode()
  check(text():find("Show: All indexes", 1, true), "All index files are not available")
  tag_choice = "videos"
  M.document_mode()
  local dashboard = vim.api.nvim_get_current_buf()
  for _, motion in ipairs({ "h", "j", "k", "l", "<Tab>", "/", "<Right>", "<Down>" }) do
    local mapping = vim.fn.maparg(motion, "n", false, true)
    check(not mapping.buffer or mapping.buffer == 0, "Dashboard hijacks " .. motion)
  end
  M.render(data, true, true)
  local start = vim.api.nvim_win_get_cursor(0)
  key("10j")
  check(vim.api.nvim_win_get_cursor(0)[1] == start[1] + 10, "10j is not ten ordinary lines")
  key("3l")
  check(vim.api.nvim_win_get_cursor(0)[2] == 3, "l jumps to dashboard controls")
  local position = vim.api.nvim_win_get_cursor(0)
  M.render(data)
  check(vim.deep_equal(position, vim.api.nvim_win_get_cursor(0)), "Background refresh moved the cursor")
  key("gg/A long searchable title 選択 20<CR>")
  check(M.current_target().id == "video-20", "Native search cannot reach the last document")
  M.calendar()
  check(native_calls[#native_calls] == "journal custom", "Calendar did not use the normal journal picker")
  M.journal()
  check(native_calls[#native_calls] == "journal today", "Today did not use the normal journal")
  M.back()
  check(vim.bo.filetype == "luix_youtube", "Journal did not return to dashboard")
  M.journal("2026-10-29")
  wait(function() return at("journal/2026/10/29.norg") end, "Task journal did not open")
  check(text():find("Plan and narration", 1, true) and text():find("[Options]", 1, true), "Journal entry lacks clear choices")

  M.open_video({ production = "sample" })
  wait(function() return at("youtube/LuixBits/projects/sample/index.norg") end, "Video workspace did not open")
  check(text():find("* Plan", 1, true) and text():find("* Narration", 1, true), "Video content is split between pages")
  check(text():find("This command finds the setting.", 1, true), "Narration is missing from the video page")
  local video = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(video, -1, -1, false, { "My unsaved video feedback." })
  M.back()
  wait(function() return at("journal/2026/10/29.norg") end, "Video did not return to its journal")
  M.back()
  wait(function() return vim.bo.filetype == "luix_youtube" end, "Journal did not return to dashboard")
  key("<BS>")
  check(vim.api.nvim_get_current_buf() == previous, "Dashboard lost the original buffer")
  check(vim.wo.number and vim.wo.relativenumber, "Window options were not restored")
  check(vim.bo.modified and text() == "An unsaved note that must stay intact.", "Unsaved original notes were changed")
  check(vim.bo[video].modified and table.concat(vim.api.nvim_buf_get_lines(video, 0, -1, false), "\n"):find("My unsaved video feedback.", 1, true), "Video feedback was lost")


  key(" nyi")
  wait(function() return at("youtube/index.norg") end, "YouTube index shortcut did not open the linked index")
  check(not text():find(": A1 : Video", 1, true), "Index still uses tables for navigation")
  for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:find("[A useful plan]", 1, true) then
      vim.api.nvim_win_set_cursor(0, { row, 0 }); key("<CR>"); break
    end
  end
  check(at("youtube/LuixBits/projects/sample/index.norg"), "Enter at the start of a link line did not open its video")
  M.back()
  check(at("youtube/index.norg"), "Video did not return to the table index")
  follow("Notes home")
  check(at("index.norg") and text():find("** Areas", 1, true), "Notes home did not open")
  follow("Work")
  check(at("work/index.norg"), "Work subindex did not open")
  follow("Space note")
  check(at("work/Space note.norg"), "Content note with spaces did not open")
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Unsaved work feedback." })
  M.back()
  check(at("work/index.norg"), "Content note did not return to its index")
  M.back()
  check(at("index.norg"), "Subindex did not return to notes home")
  M.back()
  check(at("youtube/index.norg"), "Notes home did not return to YouTube index")
  M.back()
  check(vim.api.nvim_get_current_buf() == previous, "Index shortcut lost its original buffer")

  M.render(data, true)
  key("i")
  check(at("youtube/index.norg"), "Dashboard did not open the library overview")

  follow("Reference (0)")
  check(at("youtube/reference/index.norg"), "Reference index did not open")
  follow("LuixBits: Linux, NixOS, Neovim, AI and projects")
  check(at("youtube/LuixBits/index.norg"), "Channel index did not open")
  follow("Projects")
  check(at("youtube/LuixBits/projects/index.norg"), "Topic index did not open")
  follow("A useful plan")
  check(at("youtube/LuixBits/projects/sample/index.norg"), "Topic did not open its video")
  check(text():find("My unsaved video feedback.", 1, true), "Browsing lost unsaved video feedback")
  M.back()
  check(at("youtube/LuixBits/projects/index.norg"), "Back did not return to the topic")
  M.back()
  check(at("youtube/LuixBits/index.norg"), "Back did not return to the channel")
  M.back()
  check(at("youtube/reference/index.norg"), "Back did not return to reference")
  M.back()
  check(at("youtube/index.norg"), "Back did not return to the overview")
  M.back()
  check(vim.bo.filetype == "luix_youtube" and #vim.api.nvim_list_wins() == 1, "Browsing did not stay within one window")

  local choice = "Change day"
  vim.ui.select = function(items, _, callback)
    for _, item in ipairs(items) do if item.label == choice then callback(item); return end end
    error("Requested task option not found")
  end
  vim.ui.input = function(_, callback) callback("2026-11-03") end
  local function options_link()
    for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      local column = line:find("[Options]", 1, true)
      if column then vim.api.nvim_win_set_cursor(0, { row, column - 1 }); key("<CR>"); return end
    end
    error("Options link missing")
  end
  M.journal("2026-10-29")
  wait(function() return at("journal/2026/10/29.norg") end, "Journal did not reopen")
  options_link()
  wait(function() return read_plan().events[1].date == "2026-11-03" end, "Journal Options did not move task")
  M.journal("2026-11-03")
  wait(function() return at("journal/2026/11/03.norg") and text():find("[Options]", 1, true) end, "Moved task did not reach the normal journal")
  choice = "Mark done"
  options_link()
  wait(function() return read_plan().events[1].status == "done" end, "Journal Options did not complete task")
  wait(function() return text():find("LuixBits · Done", 1, true) end, "Journal did not refresh after task completion")
  print("YOUTUBE_DASHBOARD_TEST_OK")
end)
if not ok then print(tostring(err)); vim.cmd("cquit 1") end
vim.cmd("qa!")
