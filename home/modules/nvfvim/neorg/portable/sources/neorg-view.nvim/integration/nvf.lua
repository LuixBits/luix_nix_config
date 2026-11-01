-- A local plugin shim: symlink this file into stdpath("config")/plugin/.
-- Resolve the symlink so the source checkout can live at any short path.
local file = vim.uv.fs_realpath(debug.getinfo(1, 'S').source:sub(2))
if not file then return end
local root = vim.fs.dirname(vim.fs.dirname(file))
vim.opt.runtimepath:prepend(root)
require('neorg_view').setup({ journal = true })
