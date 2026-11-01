local M = {}
local cache = {}
-- Virtual rows need cell width independent of the current window wrapping.
local display = vim.fn.strwidth
local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

-- Use parser nodes so cell-looking text inside code blocks stays code.
function M.parse(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return cache[buf].items, cache[buf].warnings end
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'norg')
  if not ok or not parser then return {}, { 'Norg parser unavailable' } end
  local parsed, trees = pcall(parser.parse, parser)
  if not parsed or not trees[1] then return {}, { 'Norg parse failed' } end
  local result, warnings = {}, {}
  local function walk(node)
    if node:type() ~= 'table' then
      for child in node:iter_children() do walk(child) end
      return
    end
    local first, _, last, endcol = node:range()
    local item = { first = first, last = endcol == 0 and last - 1 or last,
      cells = {}, sources = {}, row_sources = {}, rows = 0, columns = 0 }
    local valid = not node:has_error()
    for child in node:iter_children() do
      if child:type() == 'single_table_cell' or child:type() == 'multi_table_cell' then
        local title = child:field('title')[1]
        local address = title and trim(vim.treesitter.get_node_text(title, buf)) or ''
        local col, row = address:match('^([A-Z])([1-9]%d*)$')
        row = tonumber(row)
        col = col and col:byte() - string.byte('A') + 1
        if not row or row > 256 or col > 12 then valid = false; break end
        local key = row .. ':' .. col
        if item.cells[key] ~= nil then valid = false; break end
        local content = child:field('content')[1]
        item.cells[key] = content and trim(vim.treesitter.get_node_text(content, buf)) or ''
        local start, _, finish, finishcol = child:range()
        finish = finishcol == 0 and finish - 1 or finish
        item.sources[key] = start
        local source = item.row_sources[row] or { first = start, last = finish }
        source.first, source.last = math.min(source.first, start), math.max(source.last, finish)
        item.row_sources[row] = source
        item.rows = math.max(item.rows, row)
        item.columns = math.max(item.columns, col)
      end
    end
    if valid and item.rows > 0 and item.columns > 0 then
      -- Index tables keep each row's cells together, with one link in column A.
      -- Preserve a real source anchor for every row so Enter can follow it.
      item.linked = false
      local ordered, previous = true, -1
      for row = 1, item.rows do
        local source = item.row_sources[row]
        if not source or source.first ~= item.sources[row .. ':1'] or source.first <= previous then
          ordered = false; break
        end
        previous = source.last
        if row > 1 and (item.cells[row .. ':1'] or ''):match('%b{}%[[^%]]+%]') then item.linked = true end
      end
      item.ordered = ordered
      item.linked = item.linked and ordered
      result[#result + 1] = item
    else
      warnings[#warnings + 1] = 'Keep source visible: use unique A1-L256 cell addresses'
    end
  end
  walk(trees[1]:root())
  cache[buf] = { tick = tick, items = result, warnings = warnings }
  return result, warnings
end

function M.wrap(text, width)
  width = math.max(2, width)
  local out = {}
  for _, paragraph in ipairs(vim.split(text:gsub('\t', '    '), '\n', { plain = true })) do
    local line = ''
    for i = 0, vim.fn.strchars(paragraph) - 1 do
      local char = vim.fn.strcharpart(paragraph, i, 1)
      if display(line .. char) > width and line ~= '' then
        local cut = line:match('^.*()%s')
        if cut and cut > 1 then
          out[#out + 1] = trim(line:sub(1, cut - 1))
          line = line:sub(cut + 1):gsub('^%s+', '') .. char
        else
          out[#out + 1] = line
          line = char
        end
      else line = line .. char end
      while display(line) > width do
        local piece, count = '', 0
        while count < vim.fn.strchars(line) do
          local char = vim.fn.strcharpart(line, count, 1)
          if display(piece .. char) > width then break end
          piece, count = piece .. char, count + 1
        end
        if count == 0 then break end
        out[#out + 1] = piece
        line = vim.fn.strcharpart(line, count)
      end
    end
    out[#out + 1] = line
  end
  return out
end

local function cell(item, row, col)
  return ((item.cells[row .. ':' .. col] or ''):gsub('%b{}%[([^%]]+)%]', '%1'))
end
local function padded(text, width) return text .. string.rep(' ', math.max(0, width - display(text))) end

-- Return highlighted virtual lines. No buffer text is changed by layout.
function M.layout(item, available, selection)
  available = math.max(8, math.floor(available))
  local lines, ranges = {}, {}
  local function add(text, group) lines[#lines + 1] = { { text, group or 'NeorgViewCell' } } end
  local minimum, minimum_total = {}, 0
  for col = 1, item.columns do
    minimum[col] = math.max(8, math.min(16, display(cell(item, 1, col))))
    minimum_total = minimum_total + minimum[col]
  end
  if available < minimum_total + item.columns * 3 + 1 then
    for row = 2, item.rows do
      local first = #lines + 1
      add('┌' .. string.rep('─', available - 2) .. '┐', 'NeorgViewBorder')
      for col = 1, item.columns do
        local label = cell(item, 1, col)
        for _, line in ipairs(M.wrap(label .. ': ' .. cell(item, row, col), available - 4)) do
          local group = (item.cells[row .. ':' .. col] or ''):match('%b{}%[') and 'NeorgViewLink' or 'NeorgViewCell'
          if selection and selection.row == row and selection.col == col then group = 'NeorgViewSelected' end
          add('│ ' .. padded(line, available - 4) .. ' │', group)
        end
      end
      add('└' .. string.rep('─', available - 2) .. '┘', 'NeorgViewBorder')
      ranges[row] = { first = first, last = #lines }
    end
    return lines, ranges
  end
  local widths, wanted = {}, {}
  local budget = available - item.columns * 3 - 1
  for col = 1, item.columns do
    widths[col], wanted[col] = minimum[col], minimum[col]
    for row = 1, item.rows do
      for _, part in ipairs(vim.split(cell(item, row, col), '\n', { plain = true })) do
        wanted[col] = math.max(wanted[col], math.min(52, display(part)))
      end
    end
  end
  local remaining = budget - minimum_total
  -- Dates and small state/count columns should fit before a long title grows.
  for col = 1, item.columns do
    if wanted[col] <= 16 then
      local extra = math.min(remaining, wanted[col] - widths[col])
      widths[col], remaining = widths[col] + extra, remaining - extra
    end
  end
  while remaining > 0 do
    local best, need = nil, 0
    for col = 1, item.columns do
      if wanted[col] - widths[col] > need then best, need = col, wanted[col] - widths[col] end
    end
    if not best then break end
    widths[best], remaining = widths[best] + 1, remaining - 1
  end
  local function border(left, joint, right)
    local parts = {}
    for _, width in ipairs(widths) do parts[#parts + 1] = string.rep('─', width + 2) end
    add(left .. table.concat(parts, joint) .. right, 'NeorgViewBorder')
  end
  border('┌', '┬', '┐')
  for row = 1, item.rows do
    local first = row == 1 and 1 or #lines + 1
    local columns, height = {}, 1
    for col = 1, item.columns do
      columns[col] = M.wrap(cell(item, row, col), widths[col])
      height = math.max(height, #columns[col])
    end
    for line = 1, height do
      local chunks = { { '│', 'NeorgViewBorder' } }
      for col = 1, item.columns do
        local text = columns[col][line] or ''
        local group = row == 1 and 'NeorgViewHeader' or 'NeorgViewCell'
        if row > 1 and col == 2 then
          local state = cell(item, row, col):lower()
          if state == 'done' then group = 'NeorgViewGood'
          elseif state == 'in progress' then group = 'NeorgViewWarn' end
        end
        if (item.cells[row .. ':' .. col] or ''):match('%b{}%[') then group = 'NeorgViewLink' end
        if selection and selection.row == row and selection.col == col then group = 'NeorgViewSelected' end
        chunks[#chunks + 1] = { ' ' .. padded(text, widths[col]) .. ' ', group }
        chunks[#chunks + 1] = { '│', 'NeorgViewBorder' }
      end
      lines[#lines + 1] = chunks
    end
    if row == 1 and item.rows > 1 then border('├', '┼', '┤') end
    ranges[row] = { first = first, last = #lines }
  end
  border('└', '┴', '┘')
  ranges[item.rows].last = #lines
  return lines, ranges
end

return M
