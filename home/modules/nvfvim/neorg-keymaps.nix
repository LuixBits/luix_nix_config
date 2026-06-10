{ notesDir }:
[
  {
    mode = "n";
    key = "<leader>nn";
    action = "<Plug>(neorg-template-engine.new-note)";
    desc = "Create note here";
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
  {
    mode = "n";
    key = "<leader>nl";
    action = "<Plug>(neorg.telescope.insert_file_link)";
    desc = "Insert note link";
  }
  {
    mode = "n";
    key = "<leader>nt";
    action = "<Plug>(neorg-template-engine.insert-template)";
    desc = "Insert note template";
  }
]
