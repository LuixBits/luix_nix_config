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
    key = "<leader>ff";
    action = "<cmd>Telescope find_files<CR>";
    desc = "Find files";
  }
  {
    mode = "n";
    key = "<leader>fg";
    action = "<cmd>Telescope live_grep<CR>";
    desc = "Live grep";
  }
  {
    mode = "n";
    key = "<leader>fb";
    action = "<cmd>Telescope buffers<CR>";
    desc = "Find buffers";
  }
  {
    mode = "n";
    key = "<leader>fh";
    action = "<cmd>Telescope help_tags<CR>";
    desc = "Find help";
  }
  {
    mode = "n";
    key = "<leader>lp";
    action = "<cmd>lua require('gitsigns').preview_hunk()<CR>";
    desc = "Preview git hunk";
  }
  {
    mode = "n";
    key = "<leader>ee";
    action = "<cmd>NvimTreeToggle<CR>";
    desc = "Toggle file explorer";
  }
  {
    mode = "n";
    key = "<leader>ef";
    action = "<cmd>NvimTreeFindFile<CR>";
    desc = "Find current file in tree";
  }
  {
    mode = "n";
    key = "<leader>xx";
    action = "<cmd>Telescope diagnostics<CR>";
    desc = "Workspace diagnostics";
  }
  {
    mode = "n";
    key = "<leader>xd";
    action = "<cmd>lua vim.diagnostic.open_float()<CR>";
    desc = "Line diagnostic";
  }
]
