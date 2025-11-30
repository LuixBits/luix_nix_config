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

      #telescope
      {
        mode = "n";
        key = "<leader>ff"; 
        action = "<cmd>Telescope find_files<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>fg"; 
        action = "<cmd>Telescope live_grep<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>fb"; 
        action = "<cmd>Telescope buffers<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>fh"; 
        action = "<cmd>Telescope help_tags<CR>";
        options.silent = true;
      }

      #gitsigns
      {
        mode = "n";
        key = "<leader>hs";
        action = "<cmd>Gitsigns stage_hunk<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>hr";
        action = "<cmd>Gitsigns reset_hunk<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>hp";
        action = "<cmd>Gitsigns preview_hunk<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "<leader>hb";
        action = "<cmd>Gitsigns blame_line<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "]c";
        action = "<cmd>Gitsigns next_hunk<CR>";
        options.silent = true;
      }
      {
        mode = "n";
        key = "[c";
        action = "<cmd>Gitsigns prev_hunk<CR>";
        options.silent = true;
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

      gitsigns.enable = true;
      fugitive.enable = true;

      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "tokyonight";
            icons_enabled = true;
            section_separators = { left = ""; right = ""; };
            component_separators = { left = ""; right = ""; };
          };
        };
      };

      telescope = {
        enable = true;
        extensions."fzf-native" = {
          enable = true;          # enable fzf-native extension
          settings = {
            fuzzy = true;
            override_file_sorter = true;
            override_generic_sorter = true;
            case_mode = "smart_case";
          };
        };

        settings = {
          defaults = {
            layout_config = { prompt_position = "top"; };
            sorting_strategy = "ascending";
          };
          pickers.find_files.hidden = true;
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
