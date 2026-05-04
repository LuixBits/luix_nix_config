{ notesDir }:
[
  {
    mode = "n";
    key = "<leader>nn";
    action = "<Plug>(neorg.dirman.new-note)";
    desc = "Create note";
  }
  {
    mode = "n";
    key = "<leader>ni";
    action = "<cmd>Neorg index<CR>";
    desc = "Open notes index";
  }
  {
    mode = "n";
    key = "<leader>nr";
    action = "<cmd>Neorg toggle-concealer<CR>";
    desc = "Toggle render";
  }
  {
    mode = "n";
    key = "<leader>nf";
    action = "<cmd>lua require('telescope.builtin').find_files({ cwd = vim.fn.expand('${notesDir}') })<CR>";
    desc = "Find notes";
  }
]
