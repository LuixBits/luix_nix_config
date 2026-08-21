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

  # Keep the concise quick reference with NVF's generated configuration so it
  # is always available from any project through <leader>hc.
  xdg.configFile."nvf/CHEATSHEET.md".text = ''
    # Neovim quick reference

    `Leader` is Space. Press Space and pause to see the available groups.
    Use `<leader>fk` to search every active keymap.

    ## Find and navigate

    | Key | Action |
    | --- | --- |
    | `<leader>ff` | Find a file by name |
    | `<leader>fg` | Find text inside project files |
    | `<leader>fw` | Find the word under the cursor |
    | `<leader>fb` | Find an open buffer |
    | `<leader>fs` | Find functions, classes, and other symbols in this file |
    | `<leader>oo` | Open or focus the code outline |
    | `gO` | List symbols in the current file |
    | `<leader>jfj` / `<leader>jfk` | Next / previous function |
    | `<leader>jcj` / `<leader>jck` | Next / previous class |

    ## Code intelligence

    These keys are available when a language server is attached.

    | Key | Action |
    | --- | --- |
    | `gd` | Go to definition |
    | `gD` | Go to declaration |
    | `grr` | Find references and usages |
    | `gri` | Find implementations |
    | `grt` | Go to type definition |
    | `grn` | Rename symbol |
    | `gra` | Code action |
    | `K` | Show documentation |
    | `Ctrl-o` / `Ctrl-i` | Go backward / forward through jumps |

    ## Files and windows

    | Key | Action |
    | --- | --- |
    | `<leader>ee` | Toggle the file explorer |
    | `<leader>ef` | Reveal the current file in the explorer |
    | `<leader>eo` | Focus the open file explorer |
    | `Ctrl-h/j/k/l` | Focus the window left/down/up/right |
    | `<leader>w` | Save |
    | `<leader>q` | Close the current window |
    | `Ctrl-t` | Show or hide the terminal |

    In file trees and other tool windows, use `j`/`k` to move, Enter to open,
    `h`/`l` to close/open tree nodes, and `q` to close the tool window.

    ## Editing code structures

    | Key | Action |
    | --- | --- |
    | `vaf` / `vif` | Select around / inside a function |
    | `vac` / `vic` | Select around / inside a class |
    | `daf` | Delete a function |
    | `cif` | Change a function body |
    | `gcc` | Toggle a line comment |
    | `gc` plus a motion | Toggle comments over that motion |

    ## Flashcards

    | Key | Action |
    | --- | --- |
    | `<leader>nc` | Open the Flashcards hub: Overview, Cards, and Stats |

    In the hub, use `1`/`2`/`3` or `Tab` to change page, `j`/`k` to move,
    and Enter for the selected action. Press `?` for the complete local key
    list. During review, use Space or Enter to reveal, `h` for a hint,
    `1`/`2`/`3` to rate, `u` to undo, and `q` to close.

    ## Problems, formatting, and tests

    | Key | Action |
    | --- | --- |
    | `<leader>xx` / `<leader>xb` | All / current-file problems |
    | `<leader>xj` / `<leader>xk` | Next / previous problem |
    | `<leader>xd` | Explain the problem on this line |
    | `<leader>lf` / `<leader>ll` | Format / lint the current file |
    | `<leader>tn` / `<leader>tf` | Test nearest / current file |
    | `<leader>ta` | Test the complete suite for the current language |
    | `<leader>ts` / `<leader>to` | Test explorer / latest test output |
    | `<leader>tt` | Test run history and status |
    | `<leader>db` / `<leader>dc` | Toggle breakpoint / start or continue debugging |

    Press `<leader>hc` to return to this page.
  '';

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
            keymap = {
              preset = "super-tab";
              # Lists move in the same direction everywhere: down with j and
              # up with k. Ctrl is needed here because plain j/k insert text.
              "<C-j>" = [
                "select_next"
                "fallback"
              ];
              "<C-k>" = [
                "select_prev"
                "fallback"
              ];
            };
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
            on_attach = lib.generators.mkLuaInline ''
              function(bufnr)
                local api = require("nvim-tree.api")
                api.config.mappings.default_on_attach(bufnr)

                local function opts(desc)
                  return {
                    buffer = bufnr,
                    desc = "File explorer: " .. desc,
                    noremap = true,
                    silent = true,
                    nowait = true,
                  }
                end

                vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close folder"))
                vim.keymap.set("n", "l", api.node.open.edit, opts("Open folder or file"))
                vim.keymap.set("n", "<C-h>", "<C-w>h", opts("Focus window left"))
                vim.keymap.set("n", "<C-j>", "<C-w>j", opts("Focus window below"))
                vim.keymap.set("n", "<C-k>", "<C-w>k", opts("Focus window above"))
                vim.keymap.set("n", "<C-l>", "<C-w>l", opts("Focus window right"))
              end
            '';

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
              exclude = [ ];
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
              mappings = {
                i = {
                  "<C-j>" = lib.generators.mkLuaInline "require('telescope.actions').move_selection_next";
                  "<C-k>" = lib.generators.mkLuaInline "require('telescope.actions').move_selection_previous";
                  "<Esc>" = lib.generators.mkLuaInline "require('telescope.actions').close";
                };
                n = {
                  "q" = lib.generators.mkLuaInline "require('telescope.actions').close";
                  "<Esc>" = lib.generators.mkLuaInline "require('telescope.actions').close";
                };
              };
            };
            pickers.find_files.hidden = true;
          };
        };

        # Neorg exposes telescope.nvim through pack/start, so requiring
        # Telescope can otherwise bypass NVF's lazy setup and its mappings.
        luaConfigRC.telescope-configured = inputs.nvf.lib.nvim.dag.entryAfter [ "lazyConfigs" ] ''
          require("lz.n").trigger_load("telescope")
        '';

        git.gitsigns = {
          enable = true;
          mappings = {
            nextHunk = "<leader>gj";
            previousHunk = "<leader>gk";
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
          # Defined as a regular mapping in keymaps.nix so it works on the
          # first press even when ToggleTerm was loaded through LazyGit.
          mappings.open = null;
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
              footer = [ "Tip: press Space and pause for key hints" ];
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
