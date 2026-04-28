{ notesDir }:
[
  {
    mode = "n";
    key = "<leader>nn";
    action = "<cmd>Neorg workspace notes<CR>";
    desc = "Open notes workspace";
  }
  {
    mode = "n";
    key = "<leader>ni";
    action = "<cmd>Neorg index<CR>";
    desc = "Open notes index";
  }
  {
    mode = "n";
    key = "<leader>na";
    action = "<cmd>NeorgNewNote<CR>";
    desc = "Create note";
  }
  {
    mode = "n";
    key = "<leader>nD";
    action = "<cmd>NeorgNewFolder<CR>";
    desc = "Create notes folder";
  }
  {
    mode = "n";
    key = "<leader>nr";
    action = "<cmd>NeorgToggleRender<CR>";
    desc = "Toggle rendered view";
  }
  {
    mode = "n";
    key = "<leader>ne";
    action = "<cmd>NeorgNotesTree<CR>";
    desc = "Toggle notes explorer";
  }
  {
    mode = "n";
    key = "<leader>nE";
    action = "<cmd>NvimTreeFindFile<CR>";
    desc = "Reveal note in explorer";
  }
  {
    mode = "n";
    key = "<leader>nw";
    action = "<cmd>wincmd w<CR>";
    desc = "Switch note/tree window";
  }
  {
    mode = "n";
    key = "<leader>nf";
    action = "<cmd>lua require('telescope.builtin').find_files({ cwd = vim.fn.expand('${notesDir}') })<CR>";
    desc = "Find notes";
  }
  {
    mode = "n";
    key = "<leader>ng";
    action = "<cmd>lua require('telescope.builtin').live_grep({ search_dirs = { vim.fn.expand('${notesDir}') } })<CR>";
    desc = "Search notes";
  }
]
