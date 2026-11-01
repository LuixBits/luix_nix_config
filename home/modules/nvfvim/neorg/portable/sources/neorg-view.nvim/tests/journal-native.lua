local ok, err = xpcall(function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. '/journal/2026/11', 'p')
  vim.fn.writefile({ '* Personal journal', 'Keep this text.' }, root .. '/journal/2026/11/03.norg')
  vim.fn.writefile({ '* 2026-11-04', '** YouTube', '*** Star Citizen episode' }, root .. '/journal/2026/11/04.norg')
  local old = package.loaded.neorg_view
  if old then old.stop() end
  for name in pairs(package.loaded) do if name:match('^neorg_view') then package.loaded[name] = nil end end
  vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h'))
  require('neorg_view').setup({ sync = false, journal = true })
  vim.cmd.edit(root .. '/journal/2026/11/03.norg')
  vim.wait(100)
  local modules = require('neorg.core.modules')
  local dirman = assert(modules.get_module('core.dirman'))
  dirman.add_workspace('journal-test', root)
  dirman.set_workspace('journal-test')
  modules.get_module_config('core.journal').workspace = 'journal-test'
  require('neorg_view.journal').install()
  local calendar = assert(modules.get_module('core.ui.calendar'))
  local native_picker = calendar.select_date
  calendar.select_date = function(options)
    options.date = { year = 2026, month = 11, day = 3 }
    return native_picker(options)
  end
  local function key(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
    vim.wait(100)
  end
  -- The user's normal journal calendar key opens the decorated native view.
  vim.cmd('Neorg journal custom')
  assert(vim.api.nvim_buf_get_name(0):find('calendar'), 'Normal journal key did not open Neorg calendar')
  local ns = assert(vim.api.nvim_get_namespaces()['neorg/calendar/logical'])
  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  local marked = vim.inspect(marks)
  assert(marked:find('NeorgViewJournalDay'), 'Journal dates were not highlighted in the native calendar')
  key('l<CR>')
  assert(vim.api.nvim_buf_get_name(0) == root .. '/journal/2026/11/04.norg', 'Native date selection did not open the shared SC journal day')
  assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('Star Citizen episode'))
  vim.cmd('Neorg journal custom')
  assert(vim.api.nvim_buf_get_name(0):find('calendar'), 'Dashboard calendar uses a different view')
  key('<CR>')
  assert(vim.api.nvim_buf_get_name(0) == root .. '/journal/2026/11/03.norg', 'Dashboard calendar did not open the normal journal')
  assert(vim.fn.readfile(root .. '/journal/2026/11/03.norg')[2] == 'Keep this text.')
  vim.fn.delete(root, 'rf')
  print('NATIVE_JOURNAL_SMOKE_OK')
end, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') end
vim.cmd('qa!')
