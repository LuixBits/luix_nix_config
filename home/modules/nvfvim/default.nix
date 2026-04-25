# home-manager module using NVF
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  keymaps = import ./keymaps.nix;
in {
  # Import NVF’s Home‑Manager module
  imports = [ inputs.nvf.homeManagerModules.default ];

  home.activation.ensureNotesWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    notes_dir="${notesDir}"
    journal_dir="$notes_dir/journal"
    templates_dir="$notes_dir/templates"
    meetings_dir="$notes_dir/meetings"
    flashcards_dir="$notes_dir/flashcards"

    ensure_file() {
      file="$1"
      shift

      if [ ! -e "$file" ]; then
        printf '%s\n' "$@" > "$file"
      fi
    }

    run mkdir -p "$notes_dir" "$journal_dir" "$templates_dir" "$meetings_dir" "$flashcards_dir"

    ensure_file "$notes_dir/index.norg" \
      '* Notes' \
      "" \
      '** Capture' \
      '- {:$notes/inbox:}[Inbox]' \
      '- {:$notes/tasks:}[Tasks]' \
      '- {:$notes/projects:}[Projects]' \
      '- {:$notes/someday:}[Someday]' \
      '- {:$notes/journal/index:}[Journal]' \
      '- {:$notes/meetings/index:}[Meetings]' \
      "" \
      '** Areas' \
      '- {:$notes/work:}[Work notes]' \
      '- {:$notes/japanese:}[Japanese notes]' \
      '- {:$notes/flashcards/japanese:}[Japanese flashcards]' \
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
    ensure_file "$notes_dir/japanese.norg" \
      '* Japanese notes' \
      "" \
      '** Vocabulary' \
      '- {:$notes/flashcards/japanese:}[Japanese flashcards]' \
      "" \
      '** Grammar' \
      '- '

    ensure_file "$journal_dir/index.norg" '* Journal' ""
    ensure_file "$journal_dir/template.norg" \
      '* Daily note' \
      "" \
      '** Focus' \
      '- ' \
      "" \
      '** Notes' \
      '- ' \
      "" \
      '** Tasks' \
      '- ( ) ' \
      "" \
      '** Japanese' \
      '- '

    ensure_file "$templates_dir/note.norg" \
      '* {{title}}' \
      "" \
      '- Created :: {{datetime}}' \
      "" \
      '** Notes' \
      '- '

    ensure_file "$templates_dir/daily.norg" \
      '* {{date}}' \
      "" \
      '** Focus' \
      '- ' \
      "" \
      '** Notes' \
      '- ' \
      "" \
      '** Tasks' \
      '- ( ) ' \
      "" \
      '** Japanese' \
      '- '

    ensure_file "$templates_dir/meeting.norg" \
      '* {{title}}' \
      "" \
      '- Date :: {{date}}' \
      "" \
      '** Attendees' \
      '- ' \
      "" \
      '** Notes' \
      '- ' \
      "" \
      '** Decisions' \
      '- ' \
      "" \
      '** Actions' \
      '- ( ) '

    ensure_file "$meetings_dir/index.norg" \
      '* Meetings' \
      "" \
      '- New meetings are created with `<leader>nG`.'

    ensure_file "$flashcards_dir/japanese.norg" \
      '* Japanese flashcards' \
      "" \
      '** Format' \
      '- term | reading | meaning | example sentence' \
      "" \
      '** Cards' \
      '- 日本語 :: にほんご :: Japanese language :: 日本語を勉強しています。'
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

        luaConfigRC.neorg-tools = ''
          _G.neorg_notes = _G.neorg_notes or {}

          local notes_dir = vim.fn.expand("${notesDir}")

          local function join(...)
            return table.concat({ ... }, "/")
          end

          local function ensure_dir(path)
            vim.fn.mkdir(path, "p")
          end

          local function slugify(input)
            local slug = vim.trim(input or ""):lower()
            slug = slug:gsub("%s+", "-")
            slug = slug:gsub("[^%w%-_]", "")
            slug = slug:gsub("%-+", "-")
            slug = slug:gsub("^%-", ""):gsub("%-$", "")

            if slug == "" then
              slug = os.date("%Y-%m-%d-%H%M%S")
            end

            return slug
          end

          local function read_template(path, fallback)
            if vim.fn.filereadable(path) == 1 then
              return vim.fn.readfile(path)
            end

            return fallback
          end

          local function render(lines, vars)
            local rendered = {}

            for _, line in ipairs(lines) do
              for key, value in pairs(vars) do
                line = line:gsub("{{" .. key .. "}}", function()
                  return value
                end)
              end
              table.insert(rendered, line)
            end

            return rendered
          end

          local function open_from_template(file, template, fallback, vars)
            ensure_dir(vim.fn.fnamemodify(file, ":h"))

            if vim.fn.filereadable(file) == 0 then
              vim.fn.writefile(render(read_template(template, fallback), vars), file)
            end

            vim.cmd.edit(vim.fn.fnameescape(file))
          end

          local function ask_title(prompt, callback)
            vim.ui.input({ prompt = prompt }, function(input)
              local title = vim.trim(input or "")

              if title == "" then
                return
              end

              callback(title)
            end)
          end

          _G.neorg_notes.new_note = function()
            ask_title("Note title: ", function(title)
              local file = join(notes_dir, slugify(title) .. ".norg")
              open_from_template(file, join(notes_dir, "templates", "note.norg"), {
                "* {{title}}",
                "",
                "- Created :: {{datetime}}",
                "",
                "** Notes",
                "- ",
              }, {
                title = title,
                date = os.date("%Y-%m-%d"),
                datetime = os.date("%Y-%m-%d %H:%M"),
              })
            end)
          end

          _G.neorg_notes.new_meeting = function()
            ask_title("Meeting title: ", function(title)
              local file = join(notes_dir, "meetings", os.date("%Y-%m-%d-") .. slugify(title) .. ".norg")
              open_from_template(file, join(notes_dir, "templates", "meeting.norg"), {
                "* {{title}}",
                "",
                "- Date :: {{date}}",
                "",
                "** Attendees",
                "- ",
                "",
                "** Notes",
                "- ",
                "",
                "** Decisions",
                "- ",
                "",
                "** Actions",
                "- ( ) ",
              }, {
                title = title,
                date = os.date("%Y-%m-%d"),
                datetime = os.date("%Y-%m-%d %H:%M"),
              })
            end)
          end

          _G.neorg_notes.open_flashcards = function()
            vim.cmd.edit(vim.fn.fnameescape(join(notes_dir, "flashcards", "japanese.norg")))
          end

          _G.neorg_notes.export_flashcards = function()
            local source = join(notes_dir, "flashcards", "japanese.norg")
            local output = join(notes_dir, "flashcards", "japanese.tsv")

            if vim.fn.filereadable(source) == 0 then
              vim.notify("No flashcard source found at " .. source, vim.log.levels.WARN)
              return
            end

            local function clean(value)
              return tostring(value or ""):gsub("\t", " "):gsub("\r", " "):gsub("\n", " ")
            end

            local rows = { "Expression\tReading\tMeaning\tSentence\tTags" }

            for _, line in ipairs(vim.fn.readfile(source)) do
              local body = line:match("^%s*-%s+(.+)$")

              if body and body:find("::", 1, true) then
                local fields = vim.split(body, "%s*::%s*", { trimempty = false })

                if #fields >= 3 then
                  while #fields < 4 do
                    table.insert(fields, "")
                  end

                  table.insert(rows, table.concat({
                    clean(fields[1]),
                    clean(fields[2]),
                    clean(fields[3]),
                    clean(fields[4]),
                    "japanese neorg",
                  }, "\t"))
                end
              end
            end

            ensure_dir(vim.fn.fnamemodify(output, ":h"))
            vim.fn.writefile(rows, output)
            vim.notify(("Exported %d flashcards to %s"):format(#rows - 1, output), vim.log.levels.INFO)
          end

          vim.api.nvim_create_user_command("NeorgNewNote", _G.neorg_notes.new_note, {})
          vim.api.nvim_create_user_command("NeorgNewMeeting", _G.neorg_notes.new_meeting, {})
          vim.api.nvim_create_user_command("NeorgFlashcards", _G.neorg_notes.open_flashcards, {})
          vim.api.nvim_create_user_command("NeorgExportFlashcards", _G.neorg_notes.export_flashcards, {})
        '';

        luaConfigRC.example = ''
          vim.api.nvim_create_autocmd("TextYankPost", {
            callback = function()
              vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
            end,
          })

          vim.api.nvim_create_autocmd("FileType", {
            pattern = { "norg", "markdown" },
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
