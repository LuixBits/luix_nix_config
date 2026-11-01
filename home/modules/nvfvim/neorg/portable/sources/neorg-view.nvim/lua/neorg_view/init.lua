local M = { enabled = true, buffers = {}, window_options = {}, hidden_rows = {} }
local tables = require('neorg_view.tables')
local sync = require('neorg_view.sync')
local navigation = require('neorg_view.navigation')
local status = require('neorg_view.status')
local journal = require('neorg_view.journal')
local ns = vim.api.nvim_create_namespace('neorg-view')
M.namespace = ns
local options, timer, group
local function visible_width(buf)
  local width
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_is_valid(win) then
      if not M.window_options[win] then
        M.window_options[win] = { conceallevel = vim.wo[win].conceallevel, concealcursor = vim.wo[win].concealcursor }
      end
      local info = vim.fn.getwininfo(win)[1]
      local current = vim.api.nvim_win_get_width(win) - (info and info.textoff or 0)
      width = width and math.min(width, current) or current
      vim.wo[win].conceallevel = math.max(2, vim.wo[win].conceallevel)
      vim.wo[win].concealcursor = 'nc'
    end
  end
  return width and math.max(8, width - 1) or nil
end
local function mark(buf, row, opts)
  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, opts)
  if opts.conceal_lines ~= nil then
    for hidden = row, opts.end_row or row do M.hidden_rows[buf][hidden + 1] = true end
  end
end
local function render_all()
  if M.stopped then return end
  status.prune()
  for buf in pairs(M.buffers) do if vim.api.nvim_buf_is_valid(buf) then M.render(buf) else M.buffers[buf] = nil end end
end
function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  M.hidden_rows[buf] = {}
  if M.stopped or not M.enabled or vim.bo[buf].filetype ~= 'norg' then status.clear_buffer(buf); return end
  local mode = vim.api.nvim_get_mode().mode
  if buf == vim.api.nvim_get_current_buf() and not mode:match('^n') then status.clear_buffer(buf); return end
  local width = visible_width(buf)
  if not width then return end
  local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if text[1] and text[1]:match('^@document%.meta%s*$') then
    for i = 2, math.min(#text, 50) do
      if text[i]:match('^@end%s*$') then
        mark(buf, 0, { end_row = i - 1, end_col = -1, conceal_lines = '', strict = false })
        break
      end
    end
  end
  if options.sync ~= false then
    local data = sync.get(buf, function() if not M.stopped then render_all() end end)
    local label, highlight = sync.label(data, vim.bo[buf].modified)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do status.set(win, label, highlight) end
  else status.clear_buffer(buf) end
  local parsed, warnings = tables.parse(buf)
  vim.b[buf].neorg_view_warnings = warnings
  vim.b[buf].neorg_view_linked_tables = false
  for _, item in ipairs(parsed) do
    if item.ordered then
      vim.b[buf].neorg_view_linked_tables = true
      local active, selected_row, selected_col
      if buf == vim.api.nvim_get_current_buf() then active, selected_row, selected_col = navigation.cell(buf, parsed) end
      local selection = active == item and { row = selected_row, col = selected_col } or nil
      local lines, ranges = tables.layout(item, width, selection)
      for row = 1, item.rows do
        local source, range = item.row_sources[row], ranges[row]
        if range then
          local rendered = vim.list_slice(lines, range.first, range.last)
          mark(buf, source.first, { end_col = #(text[source.first + 1] or ''), conceal = '',
            virt_text = rendered[1], virt_text_pos = 'overlay',
            virt_lines = vim.list_slice(rendered, 2), priority = 200 })
          if source.last > source.first then
            mark(buf, source.first + 1, { end_row = source.last, end_col = -1,
              conceal_lines = '', strict = false, priority = 200 })
          end
        else
          -- A stacked table repeats its headings within each record.
          mark(buf, source.first, { end_row = source.last, end_col = -1,
            conceal_lines = '', strict = false, priority = 200 })
        end
      end
    end
  end
  navigation.highlight(buf, ns)
  for i, line in ipairs(text) do
    if line == '@comment' and (text[i + 1] == 'luix-youtube:begin' or text[i + 1] == 'luix-youtube:end') and text[i + 2] == '@end' then
      mark(buf, i - 1, { end_row = i + 1, end_col = -1, conceal_lines = '', strict = false })
    end
    if line:match('^%*%* ') then
      mark(buf, i - 1, { line_hl_group = 'NeorgViewSection', priority = 90 })
    end
  end
  if buf == vim.api.nvim_get_current_buf() then navigation.ensure_visible(M) end
end
function M.refresh() render_all() end
function M.toggle()
  M.enabled = not M.enabled
  pcall(vim.cmd, 'Neorg toggle-concealer')
  render_all()
end
function M.stop()
  M.stopped = true
  navigation.stop()
  status.stop()
  journal.stop()
  M.hidden_rows = {}
  if timer then timer:stop(); timer:close(); timer = nil end
  if group then pcall(vim.api.nvim_del_augroup_by_id, group); group = nil end
  for buf in pairs(M.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
  end
  for win, saved in pairs(M.window_options) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].conceallevel, vim.wo[win].concealcursor = saved.conceallevel, saved.concealcursor
    end
  end
  M.window_options = {}
end
function M.setup(opts)
  M.stop(); M.stopped = false
  options = vim.tbl_deep_extend('force', { mappings = true, poll_interval = 2000 }, opts or {})
  M.enabled = options.enabled ~= false
  sync.options = type(options.sync) == 'table' and options.sync or {}
  local function highlights()
    for name, target in pairs({ NeorgViewBorder = 'Comment', NeorgViewHeader = 'Title', NeorgViewCell = 'Normal',
    NeorgViewGood = 'DiagnosticOk', NeorgViewWarn = 'DiagnosticWarn', NeorgViewError = 'DiagnosticError',
    NeorgViewMuted = 'Comment', NeorgViewSection = 'CursorLine', NeorgViewSelected = 'Visual' }) do
    vim.api.nvim_set_hl(0, name, { default = true, link = target })
  end
    local info = vim.api.nvim_get_hl(0, { name = 'DiagnosticInfo', link = false })
    vim.api.nvim_set_hl(0, 'NeorgViewLink', { default = true, fg = info.fg, underline = true, bold = true })
  end
  highlights()
  journal.setup(options.journal == true)
  group = vim.api.nvim_create_augroup('NeorgView', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
  local function attach(buf)
    if vim.bo[buf].filetype ~= 'norg' then return end
    M.buffers[buf] = true
    navigation.attach(buf, M, options)
    vim.schedule(function() if not M.stopped then M.render(buf) end end)
  end
  vim.api.nvim_create_autocmd('FileType', { group = group, pattern = 'norg', callback = function(e) attach(e.buf) end })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter', 'BufWritePost', 'ModeChanged', 'CursorHold', 'CursorMoved' }, {
    group = group, callback = function(e)
      if e.event == 'BufEnter' then status.prune() end
      if e.event == 'CursorMoved' and not vim.b[e.buf].neorg_view_linked_tables then
        navigation.ensure_visible(M); return
      end
      if M.buffers[e.buf] then vim.schedule(function() if not M.stopped then M.render(e.buf) end end) end
    end })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized', 'WinEnter' }, { group = group, callback = function() vim.schedule(render_all) end })
  vim.api.nvim_create_autocmd('BufWinLeave', { group = group, callback = function(e)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) == e.buf then status.clear(win) end
  end })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.stop })
  vim.api.nvim_create_user_command('NeorgViewToggle', M.toggle, { force = true })
  vim.api.nvim_create_user_command('NeorgViewSync', function() sync.run(vim.api.nvim_get_current_buf(), render_all) end, { force = true })
  vim.api.nvim_create_user_command('NeorgViewInfo', function()
    print(vim.inspect({ enabled = M.enabled, sync = sync.get(vim.api.nvim_get_current_buf()), warnings = vim.b.neorg_view_warnings }))
  end, { force = true })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_is_loaded(buf) then attach(buf) end end
  timer = vim.uv.new_timer()
  timer:start(options.poll_interval, options.poll_interval, vim.schedule_wrap(function() if not M.stopped then render_all() end end))
  return M
end
return M
