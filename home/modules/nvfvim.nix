# home-manager module using NVF
{ inputs, pkgs, ... }: {
  # Import NVF’s Home‑Manager module
  imports = [ inputs.nvf.homeManagerModules.default ];

  programs.nvf = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Set leader key globally via luaConfigRC.globalsScript
    vim.luaConfigRC.globalsScript = ''
      vim.g.mapleader = ' '
    '';

    # General options (clipboard, splits, indentation, numbers, search, etc.).
    vim.luaConfigRC.optionsScript = ''
      local opt = vim.opt
      -- General
      opt.clipboard = 'unnamedplus'
      opt.mouse     = 'a'
      opt.splitbelow  = true
      opt.splitright  = true
      opt.timeoutlen  = 500
      opt.termguicolors = true
      opt.completeopt = 'menuone,noselect'
      opt.updatetime  = 300
      -- Tabs & indentation
      opt.tabstop     = 2
      opt.shiftwidth  = 2
      opt.softtabstop = 2
      opt.expandtab   = true
      opt.shiftround  = true
      opt.autoindent  = true
      opt.smartindent = true
      -- Line numbers and UI
      opt.number       = true
      opt.relativenumber = true
      opt.wrap         = false
      opt.cursorline   = true
      opt.signcolumn   = 'yes'
      opt.scrolloff    = 8
      opt.sidescrolloff = 5
      -- Search
      opt.ignorecase   = true
      opt.smartcase    = true
      opt.incsearch    = true
      opt.hlsearch     = true
      -- Swap and undo
      opt.swapfile    = false
      opt.backup      = false
      opt.writebackup = false
      opt.undofile    = true
      -- List characters
      opt.list      = true
      opt.listchars = { tab = '→ ', trail = '°', extends = '›', precedes = '‹' }
      -- Folding
      opt.foldmethod = 'indent'
      opt.foldlevel  = 99
      opt.foldenable = false
    '';

    # Key mappings
    vim.maps = {
      normal = {
        "<leader>w" = { action = ":w<CR>", opts = { silent = false } };
        "<leader>q" = { action = ":q<CR>", opts = { silent = false } };
        "<leader>ff" = { action = "<cmd>Telescope find_files<CR>", opts = { silent = true } };
        "<leader>fg" = { action = "<cmd>Telescope live_grep<CR>", opts = { silent = true } };
        "<leader>fb" = { action = "<cmd>Telescope buffers<CR>", opts = { silent = true } };
        "<leader>fh" = { action = "<cmd>Telescope help_tags<CR>", opts = { silent = true } };
        "<leader>lp" = { action = "<cmd>lua require('gitsigns').preview_hunk()<CR>", opts = { silent = true } };
        "<leader>lg" = { action = "<cmd>LazyGit<CR>", opts = { silent = true } };
      };
    };

    # Languages (LSP servers).  NVF exposes many language modules; enable those
    # corresponding to your original config.  Some language names differ; for
    # example TS stands for TypeScript, Vue LS uses volar or vtsls.
    vim.languages = {
      vue.enable  = true;    # enable Vue language server (volar)
      ts.enable   = true;    # TypeScript/JavaScript
      css.enable  = true;
      json.enable = true;
      lua.enable  = true;
      nix.enable  = true;    # nixd language server
    };

    # Plugins and visuals
    visuals = {
      indent-blankline.enable = true;
      nvim-web-devicons.enable = true;
    };

    statusline.lualine = {
      enable = true;
      theme = "tokyonight";  # set lualine theme to match tokyonight
    };

    # Telescope with fzf-native extension
    telescope = {
      enable = true;
      fzf-native = {
        enable = true;
        fuzzy  = true;
        overrideFileSorter = true;
        overrideGenericSorter = true;
        caseMode = "smart_case";
      };
      layout = {
        promptPosition = "top";
        sortingStrategy = "ascending";
      };
      find-files.hidden = true;
    };

    # Git integrations
    git.gitsigns.enable = true;
    git.gitsigns.currentLineBlame = {
      enable  = true;
      delay   = 0;
      position = "eol";
    };
    tools.lazygit.enable = true; # provide LazyGit integration

    # Dashboard (use alpha-nvim).  NVF exposes a dashboard module but we can
    # customise alpha’s dashboard via a Lua script using luaConfigRC.
    dashboard.alpha.enable = true;
    vim.luaConfigRC.extraConfigLua = ''
      local dashboard = require('alpha.themes.dashboard')
      dashboard.section.header.val = {
        '┌───────────────────────────┐',
        '│   Welcome back, luix!     │',
        '└───────────────────────────┘',
      }
      dashboard.section.buttons.val = {
        dashboard.button('f', '  Find file',  ':Telescope find_files<CR>'),
        dashboard.button('g', '  Live grep',  ':Telescope live_grep<CR>'),
        dashboard.button('e', '  File tree',  ':NvimTreeToggle<CR>'),
        dashboard.button('q', '  Quit',      ':qa<CR>'),
      }
      dashboard.section.footer.val = { 'Tip: press ? for which-key' }
      require('alpha').setup(dashboard.config)
    '';

    # Colour scheme
    theme = {
      enable = true;
      name   = "tokyonight";
      style  = "moon";
    };
  };
}

