local project = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(project)
local tables = require('neorg_view.tables')
local sync = require('neorg_view.sync')
local view = require('neorg_view')
local passed, failed = 0, 0
local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, 'p')
local function equal(actual, expected, message)
  assert(vim.deep_equal(actual, expected), (message or 'mismatch') .. '\nactual: ' .. vim.inspect(actual) .. '\nexpected: ' .. vim.inspect(expected))
end
local function case(name, run)
  local ok, err = xpcall(run, debug.traceback)
  if ok then passed = passed + 1; print('ok ' .. name)
  else failed = failed + 1; print('FAIL ' .. name .. '\n' .. err) end
end
local function note(text)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n', { plain = true }))
  vim.bo[buf].filetype = 'norg'
  return buf
end
local text = '* Work\n\n: A1 : Task\n: B1 : State\n: C1 : Next step\n: A2 : Zürich 日本語\n: B2 : Done\n: C2 : Check long content at a narrower window width.\n'
local function flat(chunks)
  local parts = {}; for _, chunk in ipairs(chunks) do parts[#parts + 1] = chunk[1] end
  return table.concat(parts)
end
case('native cells and Unicode retain their source values', function()
  local items, warnings = tables.parse(note(text))
  equal(#items, 1); equal(warnings, {})
  equal(items[1].cells['2:1'], 'Zürich 日本語')
end)
case('native ranged cells are supported', function()
  local items = tables.parse(note(': A1 : Heading\n:: A2\nFirst line.\nSecond line.\n::\n'))
  equal(#items, 1); assert(items[1].cells['2:1']:find('Second line.', 1, true))
end)
case('duplicate or unsupported coordinates keep raw source visible', function()
  local items, warnings = tables.parse(note(': A1 : Header\n: A1 : Duplicate\n'))
  equal(#items, 0); assert(#warnings > 0)
  items, warnings = tables.parse(note(': Z999 : Too large\n'))
  equal(#items, 0); assert(#warnings > 0)
  items, warnings = tables.parse(note(': A1 : Header\n: B1 :\n'))
  equal(#items, 0); assert(#warnings > 0)
end)
case('table syntax inside a code block stays code', function()
  equal(#tables.parse(note('@code norg\n: A1 : Example\n: B1 : Code\n@end\n')), 0)
end)
case('long cells and Unicode fit wide, narrow and stacked layouts', function()
  local item = tables.parse(note(text))[1]
  for _, width in ipairs({ 110, 60, 35, 18, 8 }) do
    for _, line in ipairs(tables.layout(item, width)) do assert(vim.fn.strwidth(flat(line)) <= width, 'Overflow at width ' .. width) end
  end
  local header = flat(tables.layout(item, 46)[2])
  assert(header:find('State', 1, true), 'A narrow grid must retain its status heading')
  local s = 'Long words abcdefghijklmnopqrstuvwxyz 日本語 Zürich é'
  equal(table.concat(tables.wrap(s, 8), ''):gsub('%s', ''), s:gsub('%s', ''))
end)
case('empty cells retain a stable rectangular layout', function()
  local item = { columns = 3, rows = 3, cells = { ['1:1'] = 'Task', ['1:2'] = 'State', ['1:3'] = 'Next', ['2:1'] = 'One', ['3:1'] = 'Two' } }
  for _, line in ipairs(tables.layout(item, 60)) do assert(vim.fn.strwidth(flat(line)) <= 60) end
end)
case('linked index rows show captions and retain separate source anchors', function()
  local source = ': A1 : Video\n: B1 : Status\n: A2 : {:$/youtube/one/index:}[First video]\n: B2 : Planning\n: A3 : {:$/youtube/two/index:}[Second video]\n: B3 : Done\n'
  local buf = note(source)
  local item = tables.parse(buf)[1]
  assert(item.linked)
  equal(item.row_sources[2].first, 2)
  equal(item.row_sources[3].first, 4)
  for _, width in ipairs({ 100, 50, 18 }) do
    local lines, ranges = tables.layout(item, width)
    assert(ranges[2] and ranges[3])
    local rendered = {}
    for _, line in ipairs(lines) do
      assert(vim.fn.strwidth(flat(line)) <= width)
      rendered[#rendered + 1] = flat(line)
    end
    assert(not table.concat(rendered, '\n'):find('{:$/', 1, true), 'Raw link syntax leaked into the table')
  end
  view.setup({ sync = false, poll_interval = 60000 })
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  view.render(buf)
  local anchors, selected = {}, false
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.namespace, 0, -1, { details = true })) do
    if mark[4].virt_text then
      anchors[mark[2]] = true
      for _, chunk in ipairs(mark[4].virt_text) do
        if chunk[2] == 'NeorgViewSelected' then selected = true end
      end
    end
  end
  assert(anchors[2] and anchors[4], 'Each link row needs a visible source anchor')
  assert(selected, 'Selected link row has no visible highlight')
  equal(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'), source)
end)
case('out-of-order linked cells keep the whole-table fallback', function()
  local item = tables.parse(note(': A1 : Video\n: A2 : {:$/one:}[One]\n: B1 : State\n: B2 : Done\n'))[1]
  assert(not item.linked)
end)
case('compact columns preserve dates and headers beside long video titles', function()
  local item = tables.parse(note(': A1 : Video\n: B1 : Date\n: C1 : Narration\n: A2 : A long video title that needs to wrap within a narrow notes window\n: B2 : 2026-11-03\n: C2 : 6 chapters\n'))[1]
  local rendered = {}
  for _, line in ipairs(tables.layout(item, 75)) do rendered[#rendered + 1] = flat(line) end
  local visible = table.concat(rendered, '\n')
  assert(visible:find('2026-11-03', 1, true), 'Date split across lines')
  assert(visible:find('Narration', 1, true), 'Column heading split across lines')
end)
case('view decoration leaves source text and modified flag untouched', function()
  local buf = note(text)
  vim.bo[buf].modified = false
  local original = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  view.setup({ sync = false, poll_interval = 60000 })
  view.render(buf)
  equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), original)
  equal(vim.bo[buf].modified, false)
  local marks = vim.api.nvim_buf_get_extmarks(buf, view.namespace, 0, -1, { details = true })
  local visible_anchor = false
  for _, mark in ipairs(marks) do
    if mark[4].virt_lines and not mark[4].conceal_lines then visible_anchor = true end
  end
  assert(visible_anchor, 'Virtual table must have a visible anchor')
end)
case('source toggle clears and restores the reading view', function()
  local buf = vim.api.nvim_get_current_buf()
  view.toggle(); equal(#vim.api.nvim_buf_get_extmarks(buf, view.namespace, 0, -1, {}), 0)
  view.toggle(); assert(#vim.api.nvim_buf_get_extmarks(buf, view.namespace, 0, -1, {}) > 0)
end)
case('generated index markers stay out of the reading view without hiding personal comments', function()
  local buf = note('@comment\nluix-youtube:begin\n@end\n* Notes\n@comment\nMy own comment\n@end\n@comment\nluix-youtube:end\n@end\n')
  local original = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  view.render(buf)
  local hidden = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.namespace, 0, -1, { details = true })) do
    if mark[4].conceal_lines then hidden[mark[2]] = true end
  end
  assert(hidden[0] and hidden[7] and not hidden[4])
  equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), original)
end)
case('rendering does not consume edit undo history', function()
  local path = scratch .. '/undo.norg'
  vim.fn.writefile(vim.split(text, '\n', { plain = true }), path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  local original = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.api.nvim_buf_set_lines(0, 5, 6, false, { ': A2 : Edited cell' })
  view.render(0)
  vim.cmd('undo')
  equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), original)
end)
case('Git status handles pending commits, conflicts and NUL-delimited paths', function()
  local data = sync.parse_status('# branch.head main\0# branch.upstream origin/main\0# branch.ab +2 -1\0? file with spaces.norg\0u UU N... 100644 100644 100644 100644 abc def ghi conflict.norg\0')
  equal(data.changed, 2); equal(data.ahead, 2); equal(data.behind, 1); equal(data.conflict, true)
end)
case('only a real push reflog entry provides a push timestamp', function()
  local log = 'refs/remotes/origin/main@{2026-10-30T02:00:00+01:00}\tfetch origin: fast-forward\nrefs/remotes/origin/main@{2026-10-30T01:00:00+01:00}\tupdate by push\n'
  equal(sync.last_push(log), '2026-10-30T01:00:00+01:00')
  equal(sync.last_push('fetch only\n'), nil)
end)
case('oneshot activating state is running, and success exit does not prove a push', function()
  local running, failed = sync.parse_service('ActiveState=activating\nResult=success\n')
  equal(running, true); equal(failed, false)
  running, failed = sync.parse_service('ActiveState=inactive\nResult=success\n')
  equal(running, false); equal(failed, false)
  equal(sync.last_push(''), nil)
end)
case('initial and failed metadata reads never claim local clean', function()
  local label = sync.label({ busy = true }, false)
  assert(label:find('Checking Git', 1, true)); assert(not label:find('Local clean', 1, true))
  label = sync.label({ error = 'Git unavailable', changed = 0 }, false)
  assert(label:find('Git unavailable', 1, true)); assert(not label:find('Local clean', 1, true))
end)
case('labels distinguish unsaved text, ahead commits and unknown history', function()
  local label = sync.label({ changed = 0, ahead = 2 }, true)
  assert(label:find('Unsaved', 1, true)); assert(label:find('2 ahead', 1, true)); assert(label:find('unknown', 1, true))
end)
local function command(args)
  local r = vim.system(args, { text = true }):wait()
  assert(r.code == 0, table.concat(args, ' ') .. '\n' .. (r.stderr or ''))
  return r.stdout or ''
end
local function git(root, ...)
  local args = { 'git', '-C', root }; vim.list_extend(args, { ... }); return command(args)
end
local repo, remote, helper, buf, confirmed_push
case('existing helper performs a real fixture push and UI observes it', function()
  helper = vim.env.NEORG_VIEW_SYNC_COMMAND or vim.fn.maparg('<leader>ngs', 'n'):match('(/nix/store/[%w%-]+/bin/notes%-sync)')
  assert(helper and vim.fn.executable(helper) == 1, 'Configured notes-sync helper unavailable')
  repo, remote = scratch .. '/notes', scratch .. '/remote.git'
  vim.fn.mkdir(repo, 'p')
  command({ 'git', 'init', '--bare', '--initial-branch=main', remote })
  git(repo, 'init', '-b', 'main')
  git(repo, 'config', 'user.name', 'Neorg view test'); git(repo, 'config', 'user.email', 'test@example.invalid'); git(repo, 'config', 'commit.gpgsign', 'false')
  git(repo, 'remote', 'add', 'origin', remote)
  vim.fn.writefile({ '* Original note' }, repo .. '/index.norg')
  vim.cmd('edit ' .. vim.fn.fnameescape(repo .. '/index.norg')); buf = vim.api.nvim_get_current_buf()
  sync.options = { service = false, command = { helper }, env = { NOTES_REMOTE = remote, NOTES_BRANCH = 'main', NOTES_LOCK_FILE = scratch .. '/sync.lock', NOTES_SYNC_NON_FATAL_NETWORK = '1' } }
  assert(sync.run(buf))
  assert(vim.wait(10000, function() local d = sync.cache[repo]; return d and not d.running and not d.busy and d.last_push ~= nil end, 20), 'Push did not become confirmed')
  confirmed_push = sync.cache[repo].last_push
  equal(git(repo, 'rev-parse', 'HEAD'), git(remote, 'rev-parse', 'main'))
end)
case('offline success exit leaves push time unchanged and local commit intact', function()
  assert(helper and confirmed_push, 'Previous real push required')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '* Local revision' }); vim.cmd('write')
  sync.options.env.NOTES_REMOTE = scratch .. '/unavailable.git'
  assert(sync.run(buf))
  assert(vim.wait(10000, function() local d = sync.cache[repo]; return d and not d.running and not d.busy and d.last_result == 'unavailable' end, 20), 'Unavailable attempt not detected')
  equal(sync.cache[repo].last_push, confirmed_push)
  equal(sync.cache[repo].ahead, 1)
  assert(git(repo, 'show', 'HEAD:index.norg'):find('Local revision', 1, true))
  local previous_push = sync.cache[repo].last_push_id
  assert(previous_push, 'Confirmed push must include its commit identity')
  -- Simulate the existing timer running its real helper outside this UI.
  local external = vim.system({ helper }, { cwd = repo, text = true, env = {
    NOTES_DIR = repo, NOTES_REMOTE = remote, NOTES_BRANCH = 'main',
    NOTES_LOCK_FILE = scratch .. '/sync.lock', NOTES_SYNC_NON_FATAL_NETWORK = '1',
  } }):wait()
  equal(external.code, 0)
  sync.refresh(repo)
  assert(vim.wait(10000, function() local d = sync.cache[repo]; return not d.busy and d.last_push_id ~= previous_push end, 20), 'External push was not observed')
  equal(sync.cache[repo].last_result, nil)
  equal(sync.cache[repo].ahead, 0)
  -- Keep a genuine local edit for the following two-clone conflict case.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '* Local revision again' }); vim.cmd('write')
  git(repo, 'add', 'index.norg'); git(repo, 'commit', '-m', 'Local fixture revision after recovery')
end)
case('a real two-clone conflict preserves both versions', function()
  assert(confirmed_push, 'Previous fixture required')
  local other = scratch .. '/other'
  command({ 'git', 'clone', remote, other })
  git(other, 'config', 'user.name', 'Other device'); git(other, 'config', 'user.email', 'other@example.invalid'); git(other, 'config', 'commit.gpgsign', 'false')
  vim.fn.writefile({ '* Other revision' }, other .. '/index.norg')
  git(other, 'add', 'index.norg'); git(other, 'commit', '-m', 'Other fixture revision'); git(other, 'push')
  sync.options.env.NOTES_REMOTE = remote
  assert(sync.run(buf))
  assert(vim.wait(10000, function() local d = sync.cache[repo]; return d and not d.running and not d.busy and d.conflict end, 20), 'Conflict not visible')
  assert(git(repo, 'show', 'ORIG_HEAD:index.norg'):find('Local revision', 1, true))
  assert(git(remote, 'show', 'main:index.norg'):find('Other revision', 1, true))
  git(repo, 'rebase', '--abort')
end)
case('unsaved notes are not silently committed', function()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].modified = true
  equal(sync.run(buf), false)
  vim.bo[buf].modified = false
end)
view.stop()
vim.fn.delete(scratch, 'rf')
print(string.format('Neorg view: %d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cquit 1') else vim.cmd('qa!') end
