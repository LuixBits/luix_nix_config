local M = { cache = {}, options = {} }
local uv = vim.uv or vim.loop
local function canonical(path) return uv.fs_realpath(path) or vim.fs.normalize(path) end
function M.root(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return nil end
  local root = vim.fs.root(name, '.git')
  return root and canonical(root) or nil
end
function M.parse_status(text)
  local data = { changed = 0, ahead = 0, behind = 0, conflict = false }
  for _, line in ipairs(vim.split(text, '\0', { plain = true, trimempty = true })) do
    data.branch = line:match('^# branch.head (.+)') or data.branch
    data.upstream = line:match('^# branch.upstream (.+)') or data.upstream
    local ahead, behind = line:match('^# branch.ab %+(%d+) %-(%d+)')
    if ahead then data.ahead, data.behind = tonumber(ahead), tonumber(behind) end
    if line:match('^[12u?] ') then data.changed = data.changed + 1 end
    if line:match('^u ') then data.conflict = true end
  end
  return data
end
function M.last_push(text)
  for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
    local date, message = line:match('@{([^}]+)}\t(.*)$')
    if date and message:find('update by push', 1, true) then
      return date, message:match('\t([0-9a-f]+)$')
    end
  end
end
function M.parse_service(text)
  local state = text:match('ActiveState=([^\n]+)')
  return state == 'active' or state == 'activating', text:match('Result=exit%-code') ~= nil
end
function M.refresh(root, callback)
  if not root then return end
  local old = M.cache[root] or {}
  M.cache[root] = old
  if old.busy then return end
  old.busy = true
  vim.system({ 'git', '-C', root, 'status', '--porcelain=v2', '--branch', '-z', '--untracked-files=all' }, { text = false }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then old.busy, old.error = false, 'Git unavailable'; if callback then callback() end; return end
      local data = M.parse_status(result.stdout or '')
      old.branch, old.upstream = data.branch, data.upstream
      old.service_running, old.service_failed = false, false
      for key, value in pairs(data) do old[key] = value end
      old.error, old.checked = nil, uv.now()
      local function complete()
        old.busy = false
        if callback then callback() end
      end
      if data.upstream then
        vim.system({ 'git', '-C', root, 'reflog', 'show', '--date=iso-strict', '--format=%gD\t%gs\t%H', '-n', '80', 'refs/remotes/' .. data.upstream }, { text = true }, function(log)
          vim.schedule(function()
            local pushed, push_id
            if log.code == 0 then pushed, push_id = M.last_push(log.stdout or '') end
            -- A later push by the existing timer/helper supersedes an old
            -- failed attempt made in this editor. Compare commit identity:
            -- two valid pushes can be recorded within the same clock second.
            if old.last_push_id and push_id and old.last_push_id ~= push_id then old.last_result = nil end
            old.last_push, old.last_push_id = pushed, push_id
            complete()
          end)
        end)
      else old.last_push, old.last_push_id = nil, nil; complete() end
      local service_root = canonical(M.options.service_root or vim.fn.expand('~/notes'))
      if root == service_root and M.options.service ~= false and vim.fn.executable('systemctl') == 1 then
        vim.system({ 'systemctl', '--user', 'show', M.options.service or 'notes-sync.service', '--property=ActiveState', '--property=Result' }, { text = true }, function(service)
          vim.schedule(function()
            if service.code == 0 then
              old.service_running, old.service_failed = M.parse_service(service.stdout or '')
            end
            if callback then callback() end
          end)
        end)
      end
    end)
  end)
end
function M.get(buf, callback)
  local root = M.root(buf)
  if not root then return { changed = 0, ahead = 0, no_git = true } end
  local data = M.cache[root]
  if not data or (not data.busy and uv.now() - (data.checked or 0) > 1500) then M.refresh(root, callback) end
  return M.cache[root] or { changed = 0, ahead = 0 }
end
function M.label(data, modified)
  local parts = {}
  if modified then parts[#parts + 1] = 'Unsaved' end
  if data.no_git then parts[#parts + 1] = 'Git unavailable'; return table.concat(parts, '  ·  '), 'NeorgViewMuted' end
  local state, group = 'Local clean', 'NeorgViewGood'
  if data.conflict then state, group = 'Conflict', 'NeorgViewError'
  elseif data.running or data.service_running then state, group = 'Syncing…', 'NeorgViewWarn'
  elseif data.error then state, group = 'Git unavailable', 'NeorgViewError'
  elseif data.busy and not data.checked then state, group = 'Checking Git', 'NeorgViewMuted'
  elseif data.last_result == 'unavailable' then state, group = 'Remote unavailable', 'NeorgViewWarn'
  elseif data.last_result == 'failed' or data.service_failed then state, group = 'Sync failed', 'NeorgViewError'
  elseif (data.changed or 0) > 0 or (data.ahead or 0) > 0 then
    local pending = {}
    if (data.changed or 0) > 0 then pending[#pending + 1] = data.changed .. ' changed' end
    if (data.ahead or 0) > 0 then pending[#pending + 1] = data.ahead .. ' ahead' end
    state, group = table.concat(pending, ', '), 'NeorgViewWarn'
  end
  parts[#parts + 1] = state
  if (data.behind or 0) > 0 then parts[#parts + 1] = data.behind .. ' behind' end
  local pushed = 'unknown'
  if data.last_push then
    local day, clock = data.last_push:match('^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d:%d%d)')
    if day then pushed = day == os.date('%Y-%m-%d') and clock or (day .. ' ' .. clock) end
  end
  parts[#parts + 1] = 'Push ' .. pushed
  return table.concat(parts, '  ·  '), modified and 'NeorgViewWarn' or group
end
function M.run(buf, callback)
  local root = M.root(buf)
  if not root then vim.notify('This note is not in a Git repository', vim.log.levels.WARN); return false end
  if vim.bo[buf].modified then vim.notify('Save the note before syncing', vim.log.levels.WARN); return false end
  local command = M.options.command
  if not command and root == canonical(vim.fn.expand('~/notes')) then
    local rhs = vim.fn.maparg('<leader>ngs', 'n')
    local executable = rhs:match('(/nix/store/[%w%-]+/bin/notes%-sync)')
    if executable then command = { executable } end
  end
  if not command then vim.notify('Configure neorg_view sync.command for this workspace', vim.log.levels.WARN); return false end
  local data = M.cache[root] or {}; M.cache[root] = data
  if data.running then return false end
  data.running, data.last_result = true, nil
  if callback then callback() end
  local env = vim.tbl_extend('force', M.options.env or {}, { NOTES_DIR = root })
  local started, problem = pcall(vim.system, command, { cwd = root, env = env, text = true }, function(result)
    vim.schedule(function()
      data.running = false
      local output = ((result.stdout or '') .. '\n' .. (result.stderr or '')):gsub('\27%[[%d;]*m', '')
      if output:find('Could not fetch origin', 1, true) or output:find('Could not push notes', 1, true) then data.last_result = 'unavailable'
      elseif result.code ~= 0 then data.last_result = 'failed'
      else data.last_result = nil end
      data.last_output, data.checked = output, 0
      M.refresh(root, callback)
      if callback then callback() end
    end)
  end)
  if not started then
    data.running, data.last_result, data.last_output = false, 'failed', tostring(problem)
    if callback then callback() end
    return false
  end
  return true
end
return M
