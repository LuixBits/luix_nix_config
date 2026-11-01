local project = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(project)
local tables = require('neorg_view.tables')
local count = 0
local function check(value, message) assert(value, message); count = count + 1 end
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  '* Plan', '', ': A1 : Task', ': B1 : State', ': C1 : Next step',
  ': A2 : Zürich 日本語', ': B2 : Done', ': C2 : A long sentence that must wrap without losing the words.', '' })
local parsed, warnings = tables.parse(buf)
check(#parsed == 1 and #warnings == 0, 'one native table')
check(parsed[1].cells['2:1'] == 'Zürich 日本語', 'Unicode source preserved')
local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
for _, width in ipairs({ 110, 60, 35, 18, 8 }) do
  local lines = tables.layout(parsed[1], width)
  check(#lines > 2, 'table has visible lines')
  for _, chunks in ipairs(lines) do
    local text = ''
    for _, chunk in ipairs(chunks) do text = text .. chunk[1] end
    check(vim.fn.strwidth(text) <= width, 'line exceeds width ' .. width .. ': ' .. text)
  end
end
check(vim.deep_equal(before, vim.api.nvim_buf_get_lines(buf, 0, -1, false)), 'layout never changes source')
local wrapped = tables.wrap('Some long text with 日本語 and Zürich', 12)
check(table.concat(wrapped, ''):gsub('%s', '') == 'Somelongtextwith日本語andZürich', 'wrapping preserves text')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '@code norg', ': A1 : Example', ': B1 : Code', '@end', '' })
check(#tables.parse(buf) == 0, 'table-looking code stays code')
print('Table checks passed: ' .. count)
vim.cmd('qa!')
