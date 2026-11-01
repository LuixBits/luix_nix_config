local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.rtp:prepend(root)
local api = vim.api
local view = require('neorg_view')
local function key(s) api.nvim_feedkeys(api.nvim_replace_termcodes(s,true,false,true),'xt',false) end
local checks=0
local function check(value,message) assert(value,message); checks=checks+1 end
local ok,err=xpcall(function()
  local lines={'@document.meta','title: Notes','authors: Test','categories: notes','@end','',
    '@comment','luix-youtube:begin','@end','* Notes','','- {:$/private/index:}[Private]',
    '- {:$/work/index:}[Work]','@comment','luix-youtube:end','@end','* Personal notes'}
  local buf=api.nvim_create_buf(true,false)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_lines(buf,0,-1,false,lines)
  vim.bo[buf].filetype='norg'; vim.bo[buf].modified=false
  vim.wo.winbar='Existing header'
  view.setup({poll_interval=60000,sync={service=false}})
  view.render(buf)
  check(vim.wo.winbar:find('Git unavailable',1,true),'Git status belongs to the non-focusable winbar')
  check(api.nvim_win_get_cursor(0)[1]==10,'opening a note lands on visible content')
  for _,mark in ipairs(api.nvim_buf_get_extmarks(buf,view.namespace,0,-1,{details=true})) do
    check(not mark[4].virt_lines,'Git status adds no virtual lines to the note')
  end
  api.nvim_win_set_cursor(0,{1,0}); key('j')
  check(api.nvim_win_get_cursor(0)[1]==10,'one j leaves the entire metadata/marker header')
  api.nvim_win_set_cursor(0,{13,0}); key('j')
  check(api.nvim_win_get_cursor(0)[1]==17,'one j skips a managed footer')
  key('k')
  check(api.nvim_win_get_cursor(0)[1]==13,'one k skips the same footer in reverse')
  api.nvim_win_set_cursor(0,{12,0}); key('2j')
  check(api.nvim_win_get_cursor(0)[1]==17,'counts count visible lines')
  key('2k')
  check(api.nvim_win_get_cursor(0)[1]==12,'reverse counts count visible lines')
  api.nvim_win_set_cursor(0,{10,0}); key('10k')
  check(not view.hidden_rows[buf][api.nvim_win_get_cursor(0)[1]],'top boundary never strands the cursor in hidden text')
  check(vim.deep_equal(lines,api.nvim_buf_get_lines(buf,0,-1,false)) and not vim.bo[buf].modified,'reading motions never edit the note')
  view.toggle()
  check(vim.wo.winbar=='Existing header','source mode restores previous winbar')
  api.nvim_win_set_cursor(0,{1,0}); key('j')
  check(api.nvim_win_get_cursor(0)[1]==2,'source mode retains ordinary metadata-line movement')
  view.toggle()
  vim.cmd.enew()
  vim.wait(50,function() return not vim.wo.winbar:find('Git unavailable',1,true) end)
  check(not vim.wo.winbar:find('Git unavailable',1,true),'leaving Norg removes its status header')
  api.nvim_set_current_buf(buf)
  local previous = vim.wo.winbar
  view.render(buf)
  view.stop()
  check(vim.wo.winbar==previous,'stop restores previous winbar')
  view.setup({poll_interval=60000,sync=false}); view.render(buf)
  check(vim.wo.winbar==previous,'sync=false leaves winbar alone')
end,debug.traceback)
view.stop()
if not ok then print(err); vim.cmd('cquit 1') end
print('Reading checks passed: '..checks)
vim.cmd('qa!')
