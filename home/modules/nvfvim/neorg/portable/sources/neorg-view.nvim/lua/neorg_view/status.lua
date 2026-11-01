local M = {}
local windows = {}

-- A winbar is window chrome: it has no buffer rows and cannot take the cursor.
function M.set(win, label, highlight)
  if not vim.api.nvim_win_is_valid(win) then return end
  local state = windows[win]
  if not state then
    state = { previous = vim.wo[win].winbar }
    windows[win] = state
  end
  state.rendered = '%#' .. highlight .. '# ' .. label:gsub('%%', '%%%%') .. '%*'
  vim.wo[win].winbar = state.rendered
end

function M.clear(win)
  local state = windows[win]
  if not state then return end
  if vim.api.nvim_win_is_valid(win) and vim.wo[win].winbar == state.rendered then
    vim.wo[win].winbar = state.previous
  end
  windows[win] = nil
end

function M.clear_buffer(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do M.clear(win) end
end

function M.prune()
  for win in pairs(windows) do
    if not vim.api.nvim_win_is_valid(win) or vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'norg' then
      M.clear(win)
    end
  end
end

function M.stop()
  for win in pairs(windows) do M.clear(win) end
end

return M
