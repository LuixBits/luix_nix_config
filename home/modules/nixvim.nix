{ pkgs, inputs, ... }:
{
  imports = [ 
    inputs.nixvim.homeManagerModules.nixvim 
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
    };

    extraPlugins = [ pkgs.vimPlugins.snacks-nvim ];

    extraConfigLua = ''
      require("lazy").setup({
        {
          "folke/snacks.nvim",
          priority = 1000,
          lazy = false, --load immediatly
          opts = {
            dashboard = { enable = true },
          }
        }
      })
    '';
  };
}
