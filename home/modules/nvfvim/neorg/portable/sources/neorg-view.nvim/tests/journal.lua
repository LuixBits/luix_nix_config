vim.opt.rtp:prepend(vim.fn.getcwd())
local journal = require('neorg_view.journal')
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/journal/2026/11', 'p')
vim.fn.writefile({ '* A personal day' }, root .. '/journal/2026/11/03.norg')
vim.fn.writefile({ '* 2026-11-04', '** YouTube', '*** Star Citizen' }, root .. '/journal/2026/11/04.norg')
local mode_seen, calls = nil, 0
local setup = function(_, mode) mode_seen = mode; calls = calls + 1 end
local monthly = { setup = setup }
local config = { strategy = 'nested', journal_folder = 'journal' }
package.loaded['neorg.core.modules'] = {
  get_module_config = function() return config end,
  get_module = function(name)
    if name == 'core.ui.calendar.views.monthly' then return monthly end
    if name == 'core.dirman' then return {
      get_current_workspace = function() return { 'notes', root } end,
      get_workspace = function() return root end,
    } end
  end,
}
local function day(n) return { year = 2026, month = 11, day = n } end
local mode = { on_select = function(self) self.selected = true end }
journal.setup(true)
journal.install()
monthly.setup({}, mode, day(1), {})
assert(calls == 1, 'Repeated installation wrapped the view twice')
assert(mode_seen:get_day_highlight(day(3)) == 'NeorgViewJournalDay', 'Personal entries are missing')
assert(mode_seen:get_day_highlight(day(4)) == 'NeorgViewJournalDay', 'Star Citizen is not in the same calendar')
assert(mode_seen:get_day_highlight(day(5)) == nil, 'Empty dates are marked')
assert(mode_seen:get_day_highlight(day(4), '@text.todo') == '@text.todo', 'Today highlight was overridden')
mode_seen:on_select()
assert(mode.selected, 'Native selection state was lost')
mode.get_day_highlight = function() return 'Visual' end
monthly.setup({}, mode, day(1), {})
assert(mode_seen:get_day_highlight(day(4)) == 'Visual', 'Range selection was overridden')
assert(journal.path(day(4), { strategy = 'flat' }, root) == root .. '/journal/2026-11-04.norg')
assert(journal.path(day(4), { strategy = function() return '%Y/%m-%d.norg' end }, root) == root .. '/journal/2026/11-04.norg')
journal.stop()
assert(monthly.setup == setup, 'Stopping the plugin did not restore Neorg')
journal.setup(false)
assert(monthly.setup == setup, 'Disabled calendar extension changed Neorg')
vim.fn.delete(root, 'rf')
print('journal: 11 checks passed')
vim.cmd('qa!')
