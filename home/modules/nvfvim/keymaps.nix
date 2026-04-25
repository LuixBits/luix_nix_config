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
    key = "<leader>nj";
    action = "<cmd>Neorg journal today<CR>";
    desc = "Open today's journal";
  }
  {
    mode = "n";
    key = "<leader>ny";
    action = "<cmd>Neorg journal yesterday<CR>";
    desc = "Open yesterday's journal";
  }
  {
    mode = "n";
    key = "<leader>nt";
    action = "<cmd>Neorg journal tomorrow<CR>";
    desc = "Open tomorrow's journal";
  }
  {
    mode = "n";
    key = "<leader>nJ";
    action = "<cmd>Neorg journal toc open<CR>";
    desc = "Open journal index";
  }
  {
    mode = "n";
    key = "<leader>nU";
    action = "<cmd>Neorg journal toc update<CR>";
    desc = "Update journal index";
  }
  {
    mode = "n";
    key = "<leader>nf";
    action = "<cmd>Telescope neorg find_norg_files<CR>";
    desc = "Find notes";
  }
  {
    mode = "n";
    key = "<leader>nl";
    action = "<cmd>Telescope neorg insert_link<CR>";
    desc = "Insert note link";
  }
  {
    mode = "n";
    key = "<leader>nb";
    action = "<cmd>Telescope neorg find_backlinks<CR>";
    desc = "Find note backlinks";
  }
  {
    mode = "n";
    key = "<leader>n/";
    action = "<cmd>lua require('telescope.builtin').live_grep({ search_dirs = { vim.fn.expand('~/notes') } })<CR>";
    desc = "Search notes";
  }
  {
    mode = "n";
    key = "<leader>nc";
    action = "<cmd>Neorg toggle-concealer<CR>";
    desc = "Toggle Neorg concealer";
  }
  {
    mode = "n";
    key = "<leader>nS";
    action = "<cmd>Neorg generate-workspace-summary<CR>";
    desc = "Generate notes summary";
  }
  {
    mode = "n";
    key = "<leader>nM";
    action = "<cmd>Neorg inject-metadata<CR>";
    desc = "Insert note metadata";
  }
  {
    mode = "n";
    key = "<leader>nE";
    action = "<cmd>Neorg export to-file<CR>";
    desc = "Export note";
  }
  {
    mode = "n";
    key = "<leader>nC";
    action = "<cmd>Neorg export to-clipboard<CR>";
    desc = "Copy exported note";
  }
  {
    mode = "n";
    key = "<leader>nT";
    action = "<cmd>Neorg tangle current-file<CR>";
    desc = "Tangle note";
  }
  {
    mode = "n";
    key = "<leader>np";
    action = "<cmd>Neorg presenter start<CR>";
    desc = "Start Neorg presentation";
  }
  {
    mode = "n";
    key = "<leader>oa";
    action = "<cmd>Org agenda<CR>";
    desc = "Open Org agenda";
  }
  {
    mode = "n";
    key = "<leader>oc";
    action = "<cmd>Org capture<CR>";
    desc = "Capture Org item";
  }
  {
    mode = "n";
    key = "<leader>ol";
    action = "<cmd>Org store_link<CR>";
    desc = "Store Org link";
  }
  {
    mode = "n";
    key = "<leader>oi";
    action = "<cmd>edit ~/notes/org/inbox.org<CR>";
    desc = "Open Org inbox";
  }
  {
    mode = "n";
    key = "<leader>ot";
    action = "<cmd>edit ~/notes/org/tasks.org<CR>";
    desc = "Open Org tasks";
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
