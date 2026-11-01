local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.rtp:prepend(root)
local view = require('neorg_view')
local nav = require('neorg_view.navigation')
local tables = require('neorg_view.tables')
local api = vim.api
local passed = 0
local function check(value, message) assert(value, message); passed = passed + 1 end
local function key(value)
  api.nvim_feedkeys(api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
local function note(lines)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'norg'
  return buf
end
local ok, err = xpcall(function()
  local buf = note({ '* Example', '', ': A1 : Name', ': B1 : Details',
    ':: A2', '{:$/first:}[First]', '::', ': B2 : Zürich 日本語',
    ': A3 : Third', ': B3 : {:$/second:}[Second]', '', '* After' })
  local source = api.nvim_buf_get_lines(buf,0,-1,false)
  vim.bo[buf].modified = false
  local original = function() end
  vim.keymap.set('n','h',original,{ buffer=buf, desc='Existing mapping' })
  view.setup({sync=false, poll_interval=60000})
  api.nvim_win_set_cursor(0,{5,0})
  key('l')
  local _, row, col = nav.cell(buf,tables.parse(buf))
  check(row==2 and col==2,'l selects the second cell')
  view.render(buf)
  local selected=false
  for _,m in ipairs(api.nvim_buf_get_extmarks(buf,view.namespace,0,-1,{details=true})) do
    for _,chunk in ipairs(m[4].virt_text or {}) do
      if chunk[1]:find('Zürich',1,true) and chunk[2]=='NeorgViewSelected' then selected=true end
    end
  end
  check(selected,'selected cell has visible highlight')
  key('j')
  _,row,col=nav.cell(buf,tables.parse(buf))
  check(row==3 and col==2 and api.nvim_win_get_cursor(0)[1]==9,'j moves one rendered row and retains column: '..vim.inspect({row,col,api.nvim_win_get_cursor(0)}))
  check(nav.focus_link() and api.nvim_win_get_cursor(0)[1]==10,'Enter focuses the selected column link')
  key('k')
  _,row,col=nav.cell(buf,tables.parse(buf))
  check(row==2 and col==2,'k crosses a ranged cell as one row')
  key('h')
  check(nav.focus_link() and api.nvim_win_get_cursor(0)[1]==6,'first ranged cell link is reachable')
  key('2j')
  check(api.nvim_win_get_cursor(0)[1]==11,'counted row movement exits the table')
  key('j')
  check(api.nvim_win_get_cursor(0)[1]==12,'j outside a table is normal Vim movement')
  check(vim.deep_equal(source,api.nvim_buf_get_lines(buf,0,-1,false)) and not vim.bo[buf].modified,'navigation never modifies source')
  api.nvim_win_set_cursor(0,{5,0}); key('l'); key('iX<Esc>')
  check(api.nvim_buf_get_lines(buf,7,8,false)[1]:find('X',1,true),'insert edits the selected real cell')
  view.stop()
  check(vim.fn.maparg('h','n',false,true).callback==original,'stop restores prior buffer mapping')
  check(vim.fn.maparg('l','n')=='','stop removes its own mappings')
  buf=note({'- {:$/a:}[Alpha]','- {:$/b:}[Beta]','@code norg','{:$/fake:}[Code sample]','@end'})
  view.setup({sync=false, poll_interval=60000})
  check(#nav.links(buf)==2,'parser excludes links inside code blocks')
  api.nvim_win_set_cursor(0,{1,0})
  check(nav.focus_link() and api.nvim_win_get_cursor(0)[2]==2,'link opens from anywhere on its single-link line')
  key(']l'); check(api.nvim_win_get_cursor(0)[1]==2,'next link uses ]l')
  key('[l'); check(api.nvim_win_get_cursor(0)[1]==1,'previous link uses [l')
  check(vim.fn.maparg('<Tab>','n',false,true).buffer~=1,'Tab is not captured')
  view.render(buf)
  local highlighted=0
  for _,m in ipairs(api.nvim_buf_get_extmarks(buf,view.namespace,0,-1,{details=true})) do
    if m[4].hl_group=='NeorgViewLink' then highlighted=highlighted+1 end
  end
  check(highlighted==2,'all actual links are visibly highlighted')
  vim.cmd('colorscheme default')
  check(vim.api.nvim_get_hl(0,{name='NeorgViewLink',link=false}).underline,'link highlighting survives colorscheme changes')
  check(vim.api.nvim_get_hl(0,{name='NeorgViewSelected'}).link=='Visual','table selection survives colorscheme changes')
  view.setup({sync=false,mappings=false,poll_interval=60000})
  check(vim.fn.maparg('j','n')=='','mapping opt-out works after repeated setup')
  view.stop()
end,debug.traceback)
view.stop()
if not ok then print(err); vim.cmd('cquit 1') end
print('Navigation checks passed: '..passed)
vim.cmd('qa!')
