{ pkgs, inputs, lib, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  programs.nixvim = { 
    enable = true; 
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    globals.mapleader = " ";

    opts = {
      #general settings
      clipboard = "unnamedplus";
      mouse = "a";
      splitbelow = true;
      splitright = true;
      timeoutlen = 500;
      termguicolors = true;
      completeopt = "menuone,noselect";
      updatetime = 300;

      #tab settings
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      expandtab = true;
      shiftround = true;
      autoindent = true;
      smartindent = true;

      #linenumbers
      number = true;
      relativenumber = true;
      wrap = false;
      cursorline = true;
      signcolumn = "yes";
      scrolloff = 8;
      sidescrolloff = 5;

      #search
      ignorecase = true;
      smartcase = true;
      incsearch = true;
      hlsearch = true;

      #swap
      swapfile = false;
      backup = false;
      writebackup = false;
      undofile = true;

      # text stuff
      list = true;
      listchars = {
        tab = "→ ";
        trail = "°";
        extends = "›";
        precedes = "‹";
      };

      #fold your laundry
      foldmethod = "indent";
      foldlevel = 99;
      foldenable = false;

    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options.silent = false;
      }
      {
        mode = "n";
        key = "<leader>q";
        action = ":q<CR>";
        options.silent = false;
      }
    ];

    plugins = {
      lsp = {
        enable = true;
        servers = {
          vue_ls.enable   = true;
          ts_ls.enable   = true;
          cssls.enable   = true;
          jsonls.enable  = true;
          lua_ls.enable  = true;
          nixd.enable    = true;
        };
      };
      dashboard = {
        enable = true;
        settings = {
          theme = "doom";
          config = {
            header = [
              "┌───────────────────────────┐"
              "│   Welcome back, luix!     │"
              "└───────────────────────────┘"
            ];
            center = [
              { icon = " "; desc = "Find file"; key = "f"; action = "Telescope find_files"; }
              { icon = " "; desc = "Live grep"; key = "g"; action = "Telescope live_grep"; }
              { icon = " "; desc = "File tree"; key = "e"; action = "NvimTreeToggle"; }
              { icon = " "; desc = "Quit";     key = "q"; action = "qa"; }
            ];
            footer = [ "Tip: press ? for which-key" ];
          };
        };
      };
      web-devicons.enable = true;
    };

    colorschemes.tokyonight = {
      enable = true;
      settings.style = "moon"; # options: "moon", "storm", "night", "day"
    };
  };
}
