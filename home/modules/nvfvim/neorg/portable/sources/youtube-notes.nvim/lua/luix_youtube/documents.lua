local D = {}

D.modes = {
  { id = "videos", label = "Videos" }, { id = "indexes", label = "All indexes" },
  { id = "scripts", label = "Plans & scripts" }, { id = "all", label = "All documents" },
}
D.statuses = {
  { id = "idea", label = "Idea" }, { id = "planning", label = "Planning" },
  { id = "in-progress", label = "In progress" }, { id = "done", label = "Done" }, { id = "trashed", label = "Trashed" },
}
D.states = {
  { id = "active", label = "Active" }, { id = "idea", label = "Ideas" },
  { id = "done", label = "Released" }, { id = "trashed", label = "Trash" }, { id = "all", label = "All" },
}
local colors = { idea = "Comment", planning = "DiagnosticHint", ["in-progress"] = "DiagnosticInfo", done = "DiagnosticOk", trashed = "DiagnosticWarn" }
local function active(item) return item.status == "planning" or item.status == "in-progress" end
local function in_mode(item, mode)
  return mode == "all" or mode == "videos" and item.kind == "video"
    or mode == "indexes" and (item.kind == "video" or item.kind == "index" or item.kind == "guide" or item.kind == "reference")
    or mode == "scripts" and (item.kind == "plan" or item.kind == "script")
end
-- Every destination occupies one real buffer line. Vim owns movement and search.
function D.build(data, width, state)
  state = state or {}
  local mode, status = state.mode or "videos", state.status or "active"
  local filtered = {}
  for _, item in ipairs((data.documents or {}).items or {}) do
    if in_mode(item, mode) and (status == "all" or status == "active" and active(item) or item.status == status) then
      filtered[#filtered + 1] = item
    end
  end
  local mode_label, status_label = mode, status
  for _, choice in ipairs(D.modes) do if choice.id == mode then mode_label = choice.label end end
  for _, choice in ipairs(D.states) do if choice.id == status then status_label = choice.label end end
  local view = { lines = {}, targets = {}, highlights = {}, agenda = {} }
  local function line(text, target, group)
    local number = #view.lines + 1
    view.lines[number] = text
    if group then view.highlights[#view.highlights + 1] = { row = number - 1, first = 0, last = #text, group = group } end
    if target then
      view.targets[number] = { { first = 0, last = #text, action = target } }
      if target.kind == "document" then
        view.agenda[#view.agenda + 1] = { action = target, cursor = { number, 0 } }
      end
    end
    return number
  end
  line("Video production", nil, "Title")
  line("Show: " .. mode_label .. " · " .. status_label .. " · " .. #filtered .. " shown", nil, "Comment")
  line("Enter open · s status · f filter · m view", nil, "Comment")
  line("c calendar · t today · i index · Backspace back", nil, "Comment")
  line("")
  for _, item in ipairs(filtered) do
    local title = item.projectTitle and item.projectTitle .. " / " .. item.title or item.title
    local label = item.kind == "video" and item.status == "done" and "Released" or item.statusLabel
    local text = title .. " · " .. (label or item.status) .. " · " .. item.channel
    if item.nextDate then text = text .. " · " .. (item.status == "idea" and "Proposed " or "") .. item.nextDate end
    local number = line(text, { kind = "document", id = item.id, note = item.note, document = item }, "LuixYouTubeLink")
    view.highlights[#view.highlights + 1] = { row = number - 1, first = #title + #" · ", last = #title + #" · " + #(label or item.status), group = colors[item.status] }
  end
  if #filtered == 0 then line("No documents with this status.", nil, "Comment") end
  line("")
  line("Open today's journal", { kind = "journal" }, "LuixYouTubeLink")
  line("Choose a journal day", { kind = "calendar" }, "LuixYouTubeLink")
  line("Browse linked indexes", { note = "youtube/index.norg" }, "LuixYouTubeLink")
  view.work_cursor = view.agenda[1] and view.agenda[1].cursor or { 6, 0 }
  view.selected = filtered[1] and filtered[1].id
  for _, choice in ipairs(view.agenda) do
    if choice.action.id == state.selected then view.work_cursor = choice.cursor; view.selected = state.selected; break end
  end
  return view
end

return D
