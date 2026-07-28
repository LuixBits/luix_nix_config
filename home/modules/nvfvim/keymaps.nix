[
  {
    mode = "n";
    key = "<leader>w";
    action = ":w<CR>";
    desc = "Save file";
    silent = false;
  }
  {
    mode = "n";
    key = "<leader>q";
    action = ":q<CR>";
    desc = "Quit window";
    silent = false;
  }
  {
    mode = "n";
    key = "<Esc>";
    action = "<cmd>nohlsearch<CR>";
    desc = "Clear search highlight";
  }
  {
    mode = "n";
    key = "<leader>fa";
    action = "<cmd>lua require('telescope.builtin').find_files({ hidden = true, no_ignore = true, no_ignore_parent = true })<CR>";
    desc = "Find all files including ignored";
  }
  {
    mode = "n";
    key = "<leader>fw";
    action = "<cmd>lua require('telescope.builtin').grep_string()<CR>";
    desc = "Find word under cursor";
  }
  {
    mode = "n";
    key = "<leader>fk";
    action = "<cmd>Telescope keymaps<CR>";
    desc = "Find keymaps";
  }
  {
    mode = "n";
    key = "<leader>hc";
    action = "<cmd>lua vim.cmd.edit(vim.fn.stdpath('config') .. '/CHEATSHEET.md')<CR>";
    desc = "Open Neovim cheat sheet";
  }
  {
    mode = "n";
    key = "<leader>ei";
    action = "<cmd>lua require('nvim-tree.api').filter.git.ignored.toggle()<CR>";
    desc = "Toggle ignored files";
  }
  {
    mode = "n";
    key = "<leader>eh";
    action = "<cmd>lua require('nvim-tree.api').filter.dotfiles.toggle()<CR>";
    desc = "Toggle dotfiles";
  }
  {
    mode = "n";
    key = "<leader>ec";
    action = "<cmd>lua require('nvim-tree.api').tree.collapse_all()<CR>";
    desc = "Collapse file explorer";
  }
]
