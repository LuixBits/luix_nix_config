-- Decorate Neorg's existing monthly calendar with dates that have journal files.
-- The native view retains all date selection, movement, and open callbacks.
local M = {}
local monthly, original, wrapper, group

function M.path(date, config, root)
  local strategy = config.strategy or '%Y/%m/%d.norg'
  if type(strategy) == 'function' then strategy = strategy(date) end
  strategy = ({ nested = '%Y/%m/%d.norg', flat = '%Y-%m-%d.norg' })[strategy] or strategy
  local time = os.time({ year = date.year, month = date.month, day = date.day, hour = 12 })
  return tostring(root) .. '/' .. (config.journal_folder or 'journal') .. '/' .. os.date(strategy, time)
end

function M.install()
  if wrapper or not package.loaded['neorg.core.modules'] then return end
  local modules = require('neorg.core.modules')
  monthly = modules.get_module('core.ui.calendar.views.monthly')
  if not monthly or not monthly.setup then return end
  original = monthly.setup
  wrapper = function(ui, mode, date, options)
    local config = modules.get_module_config('core.journal')
    local dirman = modules.get_module('core.dirman')
    if not config or not dirman then return original(ui, mode, date, options) end
    local workspace = config.workspace or dirman.get_current_workspace()[1]
    local root = dirman.get_workspace(workspace)
    if not root then return original(ui, mode, date, options) end
    -- Copy the mode so selecting a range and other extensions keep their state.
    local decorated = setmetatable({}, { __index = mode, __newindex = mode })
    local previous = mode.get_day_highlight
    rawset(decorated, 'get_day_highlight', function(_, day, default)
      local selected = previous and previous(mode, day, default) or default
      if selected then return selected end
      local stat = vim.uv.fs_stat(M.path(day, config, root))
      if stat and stat.type == 'file' then return 'NeorgViewJournalDay' end
    end)
    return original(ui, decorated, date, options)
  end
  monthly.setup = wrapper
end

function M.stop()
  if monthly and monthly.setup == wrapper then monthly.setup = original end
  monthly, original, wrapper = nil, nil, nil
  if group then pcall(vim.api.nvim_del_augroup_by_id, group); group = nil end
end

function M.setup(enabled)
  M.stop()
  if not enabled then return end
  local function highlight()
    local color = vim.api.nvim_get_hl(0, { name = 'DiagnosticInfo', link = false })
    vim.api.nvim_set_hl(0, 'NeorgViewJournalDay', { default = true, fg = color.fg, bold = true, underline = true })
  end
  highlight()
  group = vim.api.nvim_create_augroup('NeorgViewJournal', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlight })
  vim.api.nvim_create_autocmd('User', { group = group, pattern = 'NeorgStarted', callback = M.install })
  vim.api.nvim_create_autocmd('FileType', { group = group, pattern = 'norg', callback = function() vim.schedule(M.install) end })
  M.install()
end
return M
