# home-manager module using NVF
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  keymaps = import ./keymaps.nix;
in {
  # Import NVF’s Home‑Manager module
  imports = [
    inputs.nvf.homeManagerModules.default
    ./neorg.nix
  ];

  programs.nvf = {
    enable = true;
    defaultEditor = true;
    enableManpages = true;
    settings = {
      vim = {
        viAlias = true;
        vimAlias = true;

        globals.mapleader = " ";

        options = {
          # general settings
          clipboard = "unnamedplus";
          mouse = "a";
          splitbelow = true;
          splitright = true;
          timeoutlen = 500;
          termguicolors = true;
          hidden = true;
          confirm = true;
          completeopt = "menuone,noselect";
          updatetime = 300;

          # tab settings
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = true;
          shiftround = true;
          autoindent = true;
          smartindent = true;

          # line numbers
          number = true;
          relativenumber = true;
          wrap = false;
          cursorline = true;
          signcolumn = "yes";
          scrolloff = 8;
          sidescrolloff = 5;

          # search
          ignorecase = true;
          smartcase = true;
          incsearch = true;
          hlsearch = true;

          # swap
          swapfile = false;
          backup = false;
          writebackup = false;
          undofile = true;

          # text stuff
          list = true;
          listchars = "tab:→\\ ,trail:°,extends:›,precedes:‹";
          conceallevel = 2;
          concealcursor = "nc";

          # fold your laundry
          foldmethod = "indent";
          foldlevel = 99;
          foldenable = false;
        };

        inherit keymaps;

        # Languages (LSP servers). NVF exposes many language modules; enable those
        # corresponding to your setup. For Vue, add a custom LSP under vim.lsp.servers.
        languages = {
          enableTreesitter = true;
          typescript.enable = true; # TypeScript/JavaScript
          css.enable = true;
          json.enable = true;
          lua.enable = true;
          markdown.enable = true;
          nix.enable = true; # nixd language server
        };

        visuals = {
          indent-blankline = {
            enable = true;
            setupOpts = {
              indent = {
                char = "▏";
                tab_char = "▏";
              };
              scope = {
                enabled = true;
                show_start = true;
                show_end = false;
              };
            };
          };
          nvim-web-devicons.enable = true;
        };

        binds.whichKey = {
          enable = true;
          register = {
            "<leader>e" = "+Explorer";
            "<leader>l" = "+Git";
            "<leader>x" = "+Diagnostics";
          };
        };

        autocomplete.blink-cmp = {
          enable = true;
          friendly-snippets.enable = true;
          setupOpts = {
            keymap.preset = "super-tab";
            completion.documentation.auto_show_delay_ms = 150;
          };
        };

        autopairs.nvim-autopairs.enable = true;
        comments.comment-nvim.enable = true;
        utility.surround.enable = true;
        notes.todo-comments.enable = true;

        filetree.nvimTree = {
          enable = true;
          setupOpts = {
            view = {
              width = 35;
              side = "left";
            };

            renderer = {
              group_empty = true;
              indent_markers.enable = true;
            };

            filters = {
              dotfiles = false;
              git_ignored = true;
            };

            git.enable = true;

            update_focused_file = {
              enable = true;
              update_root = true;
            };
          };
        };

        statusline.lualine = {
          enable = true;
          theme = "tokyonight";
          sectionSeparator = { left = ""; right = ""; };
          componentSeparator = { left = ""; right = ""; };
        };

        telescope = {
          enable = true;
          extensions = [
            {
              name = "fzf";
              packages = [ pkgs.vimPlugins.telescope-fzf-native-nvim ];
              setup = {
                fzf = {
                  fuzzy = true;
                  override_file_sorter = true;
                  override_generic_sorter = true;
                  case_mode = "smart_case";
                };
              };
            }
          ];
          setupOpts = {
            defaults = {
              layout_config.horizontal.prompt_position = "top";
              sorting_strategy = "ascending";
            };
            pickers.find_files.hidden = true;
          };
        };

        git.gitsigns = {
          enable = true;
          setupOpts = {
            attach_to_untracked = true;
            current_line_blame = true;
            current_line_blame_opts = {
              delay = 0;
              virt_text_pos = "eol";
            };
          };
        };

        terminal.toggleterm = {
          enable = true;
          lazygit = {
            enable = true;
            mappings.open = "<leader>lg";
          };
        };

        dashboard.dashboard-nvim = {
          enable = true;
          setupOpts = {
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
                { icon = " "; desc = "Quit"; key = "q"; action = "qa"; }
              ];
              footer = [ "Tip: press ? for which-key" ];
            };
          };
        };

        theme = {
          enable = true;
          name = "tokyonight";
          style = "moon";
        };

        luaConfigRC.example = ''
          vim.api.nvim_create_autocmd("TextYankPost", {
            callback = function()
              vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
            end,
          })

          vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
              vim.opt_local.wrap = true
              vim.opt_local.linebreak = true
              vim.opt_local.spell = true
            end,
          })
        '';
      };
    };
  };
}
