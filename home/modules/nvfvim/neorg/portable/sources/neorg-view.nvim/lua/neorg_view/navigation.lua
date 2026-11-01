local M = {}
local cache, selected, mappings = {}, {}, {}
local api = vim.api

-- Cache parser work by changedtick; cursor movement only selects existing ranges.
function M.links(buf)
  local tick = api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return cache[buf].links end
  local links = {}
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'norg')
  if ok and parser then
    local parsed, trees = pcall(parser.parse, parser)
    if parsed and trees[1] then
      local function walk(node)
        if node:type() == 'link' then
          local row, col, last, stop = node:range()
          links[#links + 1] = { row = row, col = col, last = last, stop = stop }
          return
        end
        for child in node:iter_children() do walk(child) end
      end
      walk(trees[1]:root())
    end
  end
  cache[buf] = { tick = tick, links = links }
  return links
end

function M.cell(buf, items)
  local cursor = api.nvim_win_get_cursor(0)
  local line, win = cursor[1] - 1, api.nvim_get_current_win()
  for _, item in ipairs(items) do
    if item.ordered and line >= item.first and line <= item.last then
      for row, source in pairs(item.row_sources) do
        if line >= source.first and line <= source.last then
          local saved = selected[win]
          local col = 1
          if saved and saved.buf == buf and saved.first == item.first and saved.line == line
            and saved.tick == api.nvim_buf_get_changedtick(buf) then col = saved.col
          else
            for c = 1, item.columns do
              local start = item.sources[row .. ':' .. c]
              if start and start <= line then col = c end
            end
          end
          return item, row, col
        end
      end
    end
  end
end

-- Concealed metadata and managed markers must never consume reading motions.
local function hidden(view, buf, line)
  return (view.hidden_rows[buf] or {})[line]
end

function M.ensure_visible(view)
  if view.stopped or not view.enabled or not api.nvim_get_mode().mode:match('^n') then return end
  local buf, cursor = api.nvim_get_current_buf(), api.nvim_win_get_cursor(0)
  if not hidden(view, buf, cursor[1]) then return end
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local target = cursor[1]
  while target <= #lines and (hidden(view, buf, target) or lines[target]:match('^%s*$')) do target = target + 1 end
  if target > #lines then
    target = cursor[1]
    while target > 0 and (hidden(view, buf, target) or lines[target]:match('^%s*$')) do target = target - 1 end
  end
  if target > 0 and target <= #lines then api.nvim_win_set_cursor(0, { target, 0 }) end
end

local function vertical(key, count, view)
  local buf, start = api.nvim_get_current_buf(), api.nvim_win_get_cursor(0)
  for _ = 1, count do
    local before = api.nvim_win_get_cursor(0)
    repeat
      local previous = api.nvim_win_get_cursor(0)
      vim.cmd.normal({ args = { key }, bang = true })
      local current = api.nvim_win_get_cursor(0)
      if current[1] == previous[1] then
        api.nvim_win_set_cursor(0, before)
        M.ensure_visible(view)
        return
      end
    until not hidden(view, buf, api.nvim_win_get_cursor(0)[1])
  end
  -- If starting in a hidden header, land on text rather than its spacer line.
  if hidden(view, buf, start[1]) then
    local line = api.nvim_win_get_cursor(0)[1]
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    while line < #lines and (hidden(view, buf, line) or lines[line]:match('^%s*$')) do line = line + 1 end
    api.nvim_win_set_cursor(0, { line, 0 })
  end
end

function M.move(key, view)
  if view.stopped or not view.enabled then return key end
  local buf = api.nvim_get_current_buf()
  local items = require('neorg_view.tables').parse(buf)
  local item, row, col = M.cell(buf, items)
  if not item then
    if (key == 'j' or key == 'k') and next(view.hidden_rows[buf] or {}) then
      vertical(key, vim.v.count1, view)
      return ''
    end
    return key
  end
  local count = vim.v.count1
  if key == 'h' then col = math.max(1, col - count)
  elseif key == 'l' then col = math.min(item.columns, col + count)
  elseif key == 'j' then row = row + count
  elseif key == 'k' then row = row - count end
  local line
  if row < 1 then line = math.max(0, item.first - 1)
  elseif row > item.rows then line = math.min(api.nvim_buf_line_count(buf) - 1, item.last + 1)
  else line = item.row_sources[row].first end
  selected[api.nvim_get_current_win()] = { buf = buf, first = item.first, line = line,
    col = col, tick = api.nvim_buf_get_changedtick(buf) }
  api.nvim_win_set_cursor(0, { line + 1, 0 })
  vim.schedule(function() if api.nvim_buf_is_valid(buf) then view.render(buf) end end)
  return ''
end

-- Move from a rendered cell to its real contents before opening/editing it.
function M.focus_cell()
  local view = package.loaded.neorg_view
  if not view or view.stopped or not view.enabled then return end
  local buf = api.nvim_get_current_buf()
  local item, row, col = M.cell(buf, require('neorg_view.tables').parse(buf))
  if not item then return end
  local start = item.sources[row .. ':' .. col]
  if not start then return false end
  local line = api.nvim_buf_get_lines(buf, start, start + 1, false)[1]
  local offset = line:find(':', (line:find('[A-L]%d+') or 1) + 2, true)
  if line:match('^%s*::') then start, offset = start + 1, 0 end
  api.nvim_win_set_cursor(0, { start + 1, offset or 0 })
  return true
end

function M.focus_link()
  if M.focus_cell() == false then return false end
  local buf, cursor = api.nvim_get_current_buf(), api.nvim_win_get_cursor(0)
  local row, col, candidates = cursor[1] - 1, cursor[2], {}
  for _, link in ipairs(M.links(buf)) do
    if row >= link.row and row <= link.last then
      candidates[#candidates + 1] = link
      if (row > link.row or col >= link.col) and (row < link.last or col < link.stop) then
        api.nvim_win_set_cursor(0, { link.row + 1, link.col }); return true
      end
    end
  end
  if #candidates == 1 then
    api.nvim_win_set_cursor(0, { candidates[1].row + 1, candidates[1].col }); return true
  end
  return false
end

function M.open()
  if not M.focus_link() then return end
  local ok, modules = pcall(require, 'neorg.core.modules')
  if not ok then return end
  if not modules.get_module('core.esupports.hop') then modules.load_module('core.esupports.hop') end
  local hop = modules.get_module('core.esupports.hop')
  if hop then hop.hop_link() end
end

function M.next_link(direction)
  local links, cursor = M.links(api.nvim_get_current_buf()), api.nvim_win_get_cursor(0)
  if #links == 0 then return end
  local index
  for i, link in ipairs(links) do
    local before = link.row < cursor[1] - 1 or (link.row == cursor[1] - 1 and link.col < cursor[2])
    local after = link.row > cursor[1] - 1 or (link.row == cursor[1] - 1 and link.col > cursor[2])
    if direction < 0 and before then index = i
    elseif direction > 0 and after then index = i; break end
  end
  index = index or (direction > 0 and 1 or #links)
  index = (index - 1 + direction * (vim.v.count1 - 1)) % #links + 1
  api.nvim_win_set_cursor(0, { links[index].row + 1, links[index].col })
end

function M.highlight(buf, ns)
  for _, link in ipairs(M.links(buf)) do
    api.nvim_buf_set_extmark(buf, ns, link.row, link.col, {
      end_row = link.last, end_col = link.stop, hl_group = 'NeorgViewLink', priority = 210,
    })
  end
end

local function map(buf, key, action, opts)
  if not key then return end
  mappings[buf] = mappings[buf] or {}
  if mappings[buf][key] then return end
  local previous = api.nvim_buf_call(buf, function() return vim.fn.maparg(key, 'n', false, true) end)
  vim.keymap.set('n', key, action, vim.tbl_extend('force', { buffer = buf }, opts or {}))
  local installed = api.nvim_buf_call(buf, function() return vim.fn.maparg(key, 'n', false, true) end)
  mappings[buf][key] = { previous = previous, installed = installed }
end

function M.attach(buf, view, opts)
  if opts.mappings == false then return end
  local keys = vim.tbl_extend('force', {
    left = 'h', down = 'j', up = 'k', right = 'l', edit = 'i', open = '<CR>',
    back = '<BS>', next_link = ']l', previous_link = '[l', toggle = '<leader>nr',
  }, opts.keys or {})
  for action, key in pairs({ left = 'h', down = 'j', up = 'k', right = 'l' }) do
    if keys[action] then map(buf, keys[action], function()
      local count = vim.v.count
      if M.move(key, view) ~= '' then vim.cmd.normal({ args = { (count > 0 and tostring(count) or '') .. key }, bang = true }) end
    end, { desc = 'Note table: ' .. key }) end
  end
  map(buf, keys.edit, "<Cmd>lua require('neorg_view.navigation').focus_cell()<CR>i", { desc = 'Edit note cell' })
  map(buf, keys.open, M.open, { desc = 'Open note link' })
  map(buf, keys.back, '<C-o>', { desc = 'Previous note' })
  map(buf, keys.next_link, function() M.next_link(1) end, { desc = 'Next note link' })
  map(buf, keys.previous_link, function() M.next_link(-1) end, { desc = 'Previous note link' })
  map(buf, keys.toggle, view.toggle, { desc = 'Toggle note presentation' })
end

function M.stop()
  for buf, keys in pairs(mappings) do
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_call(buf, function()
        for key, saved in pairs(keys) do
          local current = vim.fn.maparg(key, 'n', false, true)
          if current.callback == saved.installed.callback and current.rhs == saved.installed.rhs
            and current.desc == saved.installed.desc then
            pcall(vim.keymap.del, 'n', key, { buffer = buf })
            if saved.previous.buffer == 1 then vim.fn.mapset('n', false, saved.previous) end
          end
        end
      end)
    end
  end
  mappings, selected, cache = {}, {}, {}
end
return M
