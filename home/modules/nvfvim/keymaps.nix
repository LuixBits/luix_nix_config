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
    action = "<cmd>lua vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath('config') .. '/CHEATSHEET.md'))<CR>";
    desc = "Open Neovim cheat sheet";
  }
  {
    mode = "n";
    key = "<C-h>";
    action = "<C-w>h";
    desc = "Focus window left";
  }
  {
    mode = "n";
    key = "<C-j>";
    action = "<C-w>j";
    desc = "Focus window below";
  }
  {
    mode = "n";
    key = "<C-k>";
    action = "<C-w>k";
    desc = "Focus window above";
  }
  {
    mode = "n";
    key = "<C-l>";
    action = "<C-w>l";
    desc = "Focus window right";
  }
  {
    mode = [
      "n"
      "t"
    ];
    key = "<C-t>";
    action = ''
      function()
        if vim.bo.buftype == "terminal" and vim.b.toggle_number then
          local terminal = require("toggleterm.terminal").get(vim.b.toggle_number, true)
          if terminal then
            terminal:toggle()
            return
          end
        end

        vim.cmd((vim.v.count > 0 and vim.v.count or "") .. "ToggleTerm")
      end
    '';
    lua = true;
    desc = "Hide or show terminal";
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
