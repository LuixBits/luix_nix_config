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
    key = "<leader>nm";
    action = "<cmd>PasteImage<CR>";
    desc = "Paste media image";
  }
  {
    mode = "n";
    key = "<leader>njj";
    action = "<cmd>Neorg journal today<CR>";
    desc = "Journal: today";
  }
  {
    mode = "n";
    key = "<leader>njy";
    action = "<cmd>Neorg journal yesterday<CR>";
    desc = "Journal: yesterday";
  }
  {
    mode = "n";
    key = "<leader>njt";
    action = "<cmd>Neorg journal tomorrow<CR>";
    desc = "Journal: tomorrow";
  }
  {
    mode = "n";
    key = "<leader>njc";
    action = "<cmd>Neorg journal custom<CR>";
    desc = "Journal: pick date (calendar)";
  }
  {
    mode = "n";
    key = "<leader>njo";
    action = "<cmd>lua LuixJournalOverview.update_and_open()<CR>";
    desc = "Journal: overview page";
  }
  {
    mode = "n";
    key = "<leader>nt";
    action = "<Plug>(neorg-template-engine.insert-template)";
    desc = "Insert note template";
  }
  {
    mode = "n";
    key = "<leader>ne";
    action = "<Plug>(neorg-template-engine.edit-templates)";
    desc = "Edit note templates";
  }
]
