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
    work_dir="$notes_dir/work"
    youtube_dir="$notes_dir/youtube"
    private_dir="$notes_dir/private"
    japanese_dir="$notes_dir/japanese"
    meetings_dir="$notes_dir/meetings"

    run mkdir -p "$notes_dir" "$templates_dir" "$work_dir" "$youtube_dir" "$private_dir" "$japanese_dir" "$journal_dir" "$meetings_dir"
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

          local function read_template(path)
            if vim.fn.filereadable(path) == 1 then
              return vim.fn.readfile(path)
            end

            vim.notify("Missing Neorg template: " .. path, vim.log.levels.WARN)
            return {
              "* {{title}}",
              "",
              "- Created :: {{datetime}}",
              "",
              "** Notes",
              "- ",
            }
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

          local function open_from_template(file, template, vars)
            ensure_dir(vim.fn.fnamemodify(file, ":h"))

            if vim.fn.filereadable(file) == 0 then
              vim.fn.writefile(render(read_template(template), vars), file)
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

          local function note_title(path)
            if vim.fn.filereadable(path) == 1 then
              for _, line in ipairs(vim.fn.readfile(path, "", 40)) do
                local title = line:match("^%*%s+(.+)$")

                if title then
                  return vim.trim(title)
                end
              end
            end

            return vim.fn.fnamemodify(path, ":t:r")
          end

          local function link_for_note(path)
            if path == "" or not path:match("%.norg$") then
              return ""
            end

            local absolute_notes_dir = vim.fn.fnamemodify(notes_dir, ":p")
            local absolute_path = vim.fn.fnamemodify(path, ":p")

            if not vim.startswith(absolute_path, absolute_notes_dir) then
              return ""
            end

            local relative = absolute_path:sub(#absolute_notes_dir + 1):gsub("%.norg$", "")

            return ("{:$notes/%s:}[%s]"):format(relative, note_title(absolute_path))
          end

          local note_types = {
            { label = "Work notes", folder = "work", template = "work.norg" },
            { label = "YouTube notes", folder = "youtube", template = "youtube.norg" },
            { label = "Private notes", folder = "private", template = "private.norg" },
            { label = "Japanese notes", folder = "japanese", template = "japanese.norg" },
          }

          local function note_vars(title)
            return {
              title = title,
              date = os.date("%Y-%m-%d"),
              datetime = os.date("%Y-%m-%d %H:%M"),
              parent = link_for_note(vim.api.nvim_buf_get_name(0)),
            }
          end

          local function create_note(kind)
            ask_title(kind.label .. " title: ", function(title)
              local file = join(notes_dir, kind.folder, slugify(title) .. ".norg")
              open_from_template(file, join(notes_dir, "templates", kind.template), note_vars(title))
            end)
          end

          local function clean_relative_path(input)
            local path = vim.trim(input or ""):gsub("\\", "/")
            path = path:gsub("^/+", ""):gsub("/+$", "")

            if path == "" then
              return nil
            end

            if path:find("..", 1, true) then
              vim.notify("Use a path inside ~/notes, without '..'", vim.log.levels.WARN)
              return nil
            end

            return path
          end

          local function title_from_path(path)
            local title = vim.fn.fnamemodify(path, ":t:r")
            title = title:gsub("[-_]+", " ")
            title = title:gsub("(%a)([%w']*)", function(first, rest)
              return first:upper() .. rest
            end)

            return title
          end

          _G.neorg_notes.new_note = function()
            vim.ui.select(note_types, {
              prompt = "Note type:",
              format_item = function(item)
                return item.label
              end,
            }, function(kind)
              if kind then
                create_note(kind)
              end
            end)
          end

          _G.neorg_notes.new_work_note = function()
            create_note(note_types[1])
          end

          _G.neorg_notes.new_youtube_note = function()
            create_note(note_types[2])
          end

          _G.neorg_notes.new_private_note = function()
            create_note(note_types[3])
          end

          _G.neorg_notes.new_japanese_note = function()
            create_note(note_types[4])
          end

          _G.neorg_notes.new_meeting = function()
            ask_title("Meeting title: ", function(title)
              local file = join(notes_dir, "meetings", os.date("%Y-%m-%d-") .. slugify(title) .. ".norg")
              open_from_template(file, join(notes_dir, "templates", "meeting.norg"), {
                title = title,
                date = os.date("%Y-%m-%d"),
                datetime = os.date("%Y-%m-%d %H:%M"),
                parent = link_for_note(vim.api.nvim_buf_get_name(0)),
              })
            end)
          end

          _G.neorg_notes.new_folder = function()
            vim.ui.input({ prompt = "Folder under ~/notes: " }, function(input)
              local folder = clean_relative_path(input)

              if not folder then
                return
              end

              local dir = join(notes_dir, folder)
              local index = join(dir, "index.norg")
              ensure_dir(dir)

              if vim.fn.filereadable(index) == 0 then
                vim.fn.writefile({
                  "* " .. title_from_path(folder),
                  "",
                  "** Notes",
                  "- ",
                }, index)
              end

              vim.cmd.edit(vim.fn.fnameescape(index))
            end)
          end

          _G.neorg_notes.move_current_note = function()
            local current = vim.api.nvim_buf_get_name(0)

            if current == "" or not current:match("%.norg$") then
              vim.notify("Open a .norg note before moving it", vim.log.levels.WARN)
              return
            end

            local absolute_notes_dir = vim.fn.fnamemodify(notes_dir, ":p")
            local absolute_current = vim.fn.fnamemodify(current, ":p")

            if not vim.startswith(absolute_current, absolute_notes_dir) then
              vim.notify("Can only move notes inside ~/notes", vim.log.levels.WARN)
              return
            end

            if vim.bo.modified then
              vim.cmd.write()
            end

            local current_relative = absolute_current:sub(#absolute_notes_dir + 1)
            vim.ui.input({ prompt = "Move note to: ", default = current_relative }, function(input)
              local target_relative = clean_relative_path(input)

              if not target_relative then
                return
              end

              if not target_relative:match("%.norg$") then
                target_relative = target_relative .. ".norg"
              end

              local target = join(notes_dir, target_relative)

              if vim.fn.filereadable(target) == 1 then
                vim.notify("Target already exists: " .. target, vim.log.levels.WARN)
                return
              end

              ensure_dir(vim.fn.fnamemodify(target, ":h"))

              local ok, err = os.rename(absolute_current, target)

              if not ok then
                vim.notify("Could not move note: " .. tostring(err), vim.log.levels.ERROR)
                return
              end

              vim.cmd.edit(vim.fn.fnameescape(target))
              vim.notify("Moved note to " .. target_relative, vim.log.levels.INFO)
            end)
          end

          _G.neorg_notes.open_flashcards = function()
            vim.cmd.edit(vim.fn.fnameescape(join(notes_dir, "japanese", "flashcards.norg")))
          end

          _G.neorg_notes.export_flashcards = function()
            local source = join(notes_dir, "japanese", "flashcards.norg")
            local output = join(notes_dir, "japanese", "flashcards.tsv")

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
          vim.api.nvim_create_user_command("NeorgNewWorkNote", _G.neorg_notes.new_work_note, {})
          vim.api.nvim_create_user_command("NeorgNewYoutubeNote", _G.neorg_notes.new_youtube_note, {})
          vim.api.nvim_create_user_command("NeorgNewPrivateNote", _G.neorg_notes.new_private_note, {})
          vim.api.nvim_create_user_command("NeorgNewJapaneseNote", _G.neorg_notes.new_japanese_note, {})
          vim.api.nvim_create_user_command("NeorgNewMeeting", _G.neorg_notes.new_meeting, {})
          vim.api.nvim_create_user_command("NeorgNewFolder", _G.neorg_notes.new_folder, {})
          vim.api.nvim_create_user_command("NeorgMoveNote", _G.neorg_notes.move_current_note, {})
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
