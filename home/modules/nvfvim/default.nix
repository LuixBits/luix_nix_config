# home-manager module using NVF
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  orgDir = "${notesDir}/org";
  orgmodeSetup = {
    org_agenda_files = [ "${orgDir}/*" ];
    org_default_notes_file = "${orgDir}/refile.org";
    org_todo_keywords = [ "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)" ];
    org_agenda_span = "week";
    org_agenda_start_on_weekday = 1;
    org_agenda_remove_tags = true;
    org_startup_folded = "content";
    org_startup_indented = true;
    org_hide_emphasis_markers = true;
    org_log_done = "time";
    org_log_into_drawer = "LOGBOOK";
    win_split_mode = "float";
    win_border = "rounded";
    org_capture_templates = {
      t = {
        description = "Task";
        target = "${orgDir}/tasks.org";
        headline = "Inbox";
        template = "* TODO %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:";
      };
      n = {
        description = "Note";
        target = "${orgDir}/refile.org";
        headline = "Notes";
        template = "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n%a";
      };
      j = {
        description = "Journal";
        target = "${orgDir}/journal.org";
        datetree = true;
        template = "* %<%H:%M> %?\n%U";
      };
      m = {
        description = "Meeting";
        target = "${orgDir}/projects.org";
        headline = "Meetings";
        template = "* %? :meeting:\nSCHEDULED: %^T\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n** Notes\n** Actions";
      };
    };
    org_agenda_custom_commands = {
      d = {
        description = "Daily dashboard";
        types = [
          {
            type = "agenda";
            org_agenda_overriding_header = "Today";
            org_agenda_span = "day";
          }
          {
            type = "tags_todo";
            match = "+PRIORITY=\"A\"";
            org_agenda_overriding_header = "High priority";
          }
        ];
      };
      w = {
        description = "Week";
        types = [
          {
            type = "agenda";
            org_agenda_overriding_header = "Week";
            org_agenda_span = "week";
            org_agenda_start_on_weekday = 1;
          }
        ];
      };
    };
  };
  keymaps = import ./keymaps.nix;
in {
  # Import NVF’s Home‑Manager module
  imports = [ inputs.nvf.homeManagerModules.default ];

  home.activation.ensureNotesWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    notes_dir="${notesDir}"
    org_dir="${orgDir}"
    journal_dir="$notes_dir/journal"

    ensure_file() {
      file="$1"
      shift

      if [ ! -e "$file" ]; then
        printf '%s\n' "$@" > "$file"
      fi
    }

    run mkdir -p "$notes_dir" "$journal_dir" "$org_dir"

    ensure_file "$notes_dir/index.norg" \
      '* Notes' \
      "" \
      '** Capture' \
      '- {:$notes/inbox:}[Inbox]' \
      '- {:$notes/tasks:}[Tasks]' \
      '- {:$notes/projects:}[Projects]' \
      '- {:$notes/someday:}[Someday]' \
      "" \
      '** Areas' \
      '- {:$notes/work:}[Work notes]' \
      '- {:$notes/japanese:}[Japanese notes]' \
      '- {:$notes/youtube:}[YouTube notes]' \
      "" \
      '** Knowledge' \
      '- {:$notes/references:}[References]' \
      '- {:$notes/areas:}[Areas]'

    ensure_file "$notes_dir/inbox.norg" '* Inbox' ""
    ensure_file "$notes_dir/tasks.norg" '* Tasks' "" '** Next' "" '** Waiting' "" '** Done'
    ensure_file "$notes_dir/projects.norg" '* Projects' "" '** Active' "" '** Later'
    ensure_file "$notes_dir/areas.norg" '* Areas' ""
    ensure_file "$notes_dir/references.norg" '* References' ""
    ensure_file "$notes_dir/someday.norg" '* Someday' ""
    ensure_file "$notes_dir/youtube.norg" '* YouTube notes' ""
    ensure_file "$notes_dir/work.norg" '* Work notes' ""
    ensure_file "$notes_dir/japanese.norg" '* Japanese notes' ""

    ensure_file "$journal_dir/index.norg" '* Journal' ""
    ensure_file "$journal_dir/template.norg" \
      '* Journal' \
      "" \
      '** Notes' \
      '- ' \
      "" \
      '** Tasks' \
      '- ( ) '

    ensure_file "$org_dir/inbox.org" '#+title: Inbox' "" '* Inbox'
    ensure_file "$org_dir/tasks.org" '#+title: Tasks' "" '* Inbox' "" '* Next' "" '* Waiting' "" '* Done'
    ensure_file "$org_dir/projects.org" '#+title: Projects' "" '* Active' "" '* Meetings' "" '* Done'
    ensure_file "$org_dir/journal.org" '#+title: Journal' ""
    ensure_file "$org_dir/refile.org" '#+title: Refile' "" '* Notes' "" '* Inbox'
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

        startPlugins = with pkgs.vimPlugins; [
          orgmode
          zen-mode-nvim
        ];

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

        treesitter.grammars = [ pkgs.tree-sitter-grammars.tree-sitter-org-nvim ];

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
            "<leader>n" = "+Notes";
            "<leader>o" = "+Org";
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

        notes.neorg = {
          enable = true;
          setupOpts = {
            load = {
              "core.defaults" = {};
              "core.concealer" = {};
              "core.dirman" = {
                config = {
                  workspaces = {
                    notes = notesDir;
                  };
                  default_workspace = "notes";
                  index = "index.norg";
                };
              };
              "core.journal" = {
                config = {
                  workspace = "notes";
                  journal_folder = "journal";
                  strategy = "nested";
                  use_template = true;
                };
              };
              "core.summary" = {};
              "core.qol.toc" = {};
              "core.qol.todo_items" = {};
              "core.export" = {};
              "core.export.markdown" = {};
              "core.export.html" = {};
              "core.integrations.telescope" = {};
              "core.text-objects" = {};
              "core.presenter" = {
                config = {
                  zen_mode = "zen-mode";
                };
              };
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
                { icon = " "; desc = "Notes workspace"; key = "n"; action = "Neorg workspace notes"; }
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

        # Example: tiny Lua tweak when Nix doesn't cover a case.
        luaConfigRC.orgmode = ''
          require("orgmode").setup(vim.json.decode([==[${builtins.toJSON orgmodeSetup}]==]))
        '';

        luaConfigRC.example = ''
          vim.api.nvim_create_autocmd("TextYankPost", {
            callback = function()
              vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
            end,
          })

          vim.api.nvim_create_autocmd("FileType", {
            pattern = { "norg", "org", "markdown" },
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
