# home-manager module using NVF
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  keymaps = import ./keymaps.nix;
in
{
  # Import NVF’s Home‑Manager module
  imports = [
    inputs.nvf.homeManagerModules.default
    ./languages.nix
    ./ide.nix
    ./quality.nix
    ./debugging.nix
    ./testing.nix
    ./neorg
    ./roomplan
    ./sentry
  ];

  # Keep the generated cheat sheet beside NVF's generated configuration so it
  # can be opened from any project with <leader>hc.
  xdg.configFile."nvf/CHEATSHEET.md".source = ./CHEATSHEET.md;

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

        startPlugins = [
          pkgs.vimPlugins.kanagawa-nvim
        ];

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
            "<leader>d" = "+Debug";
            "<leader>e" = "+Explorer";
            "<leader>f" = "+Find";
            "<leader>g" = "+Git";
            "<leader>h" = "+Help";
            "<leader>j" = "+Structure";
            "<leader>l" = "+Code";
            "<leader>o" = "+Outline";
            "<leader>t" = "+Tests";
            "<leader>x" = "+Diagnostics";
            "<leader>xt" = "+TODOs";
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
        notes.todo-comments.mappings = {
          quickFix = "<leader>xtq";
          telescope = "<leader>xtf";
          trouble = "<leader>xtt";
        };

        filetree.nvimTree = {
          enable = true;
          mappings = {
            toggle = "<leader>ee";
            refresh = "<leader>er";
            findFile = "<leader>ef";
            focus = "<leader>eo";
          };
          setupOpts = {
            view = {
              width = 35;
              side = "left";
            };

            renderer = {
              # Do not collapse single-child directories into one visual row.
              group_empty = false;
              indent_markers.enable = true;
            };

            filters = {
              dotfiles = false;
              # Show ignored files by default. They can still be toggled with
              # <leader>ei or I while the tree is focused.
              git_ignored = false;
            };

            git.enable = true;
            diagnostics.enable = true;

            update_focused_file = {
              enable = true;
              # Keep the tree rooted at the project instead of silently moving
              # its root to whichever file was focused last.
              update_root = false;
            };
          };
        };

        statusline.lualine = {
          enable = true;
          theme = "auto";
          sectionSeparator = {
            left = "";
            right = "";
          };
          componentSeparator = {
            left = "";
            right = "";
          };
        };

        telescope = {
          enable = true;
          mappings = {
            findProjects = null;
            findFiles = "<leader>ff";
            liveGrep = "<leader>fg";
            buffers = "<leader>fb";
            helpTags = "<leader>fh";
            open = null;
            resume = "<leader>fr";

            gitFiles = null;
            gitCommits = null;
            gitBufferCommits = null;
            gitBranches = null;
            gitStatus = null;
            gitStash = null;

            lspDocumentSymbols = null;
            lspWorkspaceSymbols = null;
            lspReferences = null;
            lspImplementations = null;
            lspDefinitions = null;
            lspTypeDefinitions = null;
            diagnostics = null;
            treesitter = null;
          };
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
          mappings = {
            nextHunk = "<leader>gn";
            previousHunk = "<leader>gp";
            stageHunk = "<leader>gs";
            undoStageHunk = "<leader>gu";
            resetHunk = "<leader>gr";
            stageBuffer = "<leader>ga";
            resetBuffer = "<leader>gx";
            previewHunk = "<leader>gh";
            blameLine = "<leader>gb";
            toggleBlame = "<leader>gl";
            diffThis = "<leader>gd";
            diffProject = "<leader>gw";
            toggleDeleted = "<leader>ge";
          };
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
            mappings.open = "<leader>gg";
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
                {
                  icon = " ";
                  desc = "Find file";
                  key = "f";
                  action = "Telescope find_files";
                }
                {
                  icon = " ";
                  desc = "Live grep";
                  key = "g";
                  action = "Telescope live_grep";
                }
                {
                  icon = " ";
                  desc = "File tree";
                  key = "e";
                  action = "NvimTreeToggle";
                }
                {
                  icon = " ";
                  desc = "Quit";
                  key = "q";
                  action = "qa";
                }
              ];
              footer = [ "Tip: press ? for which-key" ];
            };
          };
        };

        theme.enable = false;

        luaConfigRC.kanagawa = inputs.nvf.lib.nvim.dag.entryBefore [ "pluginConfigs" "lazyConfigs" ] ''
          require("kanagawa").setup({
            compile = false,
            undercurl = true,
            commentStyle = { italic = true },
            functionStyle = {},
            keywordStyle = { italic = false },
            statementStyle = { bold = true },
            typeStyle = {},
            transparent = false,
            dimInactive = false,
            terminalColors = true,
            theme = "wave",
            background = {
              dark = "wave",
              light = "lotus",
            },
          })

          vim.cmd.colorscheme("kanagawa-wave")
        '';

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
