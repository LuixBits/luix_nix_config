{
  config,
  lib,
  pkgs,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  indexTemplate = pkgs.writeText "neorg-index-template.norg" ''
    * Notes

  '';
in {
  home.activation.ensureNeorgWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    notes_dir="${notesDir}"

    run mkdir -p "$notes_dir"

    if [ ! -e "$notes_dir/index.norg" ]; then
      run install -Dm644 "${indexTemplate}" "$notes_dir/index.norg"
    fi
  '';

  programs.nvf.settings.vim = {
    globals.maplocalleader = ",";

    keymaps = import ./neorg-keymaps.nix { inherit notesDir; };

    binds.whichKey.register."<leader>n" = "+Notes";

    notes.neorg = {
      enable = true;
      treesitter.enable = true;
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
            };
          };
        };
      };
    };

    luaConfigRC.neorg-workflow = ''
      _G.neorg_notes = _G.neorg_notes or {}

      local notes_dir = vim.fn.expand("${notesDir}")

      local function join(...)
        return table.concat({ ... }, "/")
      end

      local function ensure_dir(path)
        vim.fn.mkdir(path, "p")
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

      local function slug_segment(segment)
        local slug = vim.trim(segment or ""):lower()
        slug = slug:gsub("%.norg$", "")
        slug = slug:gsub("%s+", "-")
        slug = slug:gsub("[^%w%-_]", "")
        slug = slug:gsub("%-+", "-")
        slug = slug:gsub("^%-", ""):gsub("%-$", "")

        return slug
      end

      local function split_path(path)
        local segments = {}

        for segment in path:gmatch("[^/]+") do
          local slug = slug_segment(segment)

          if slug ~= "" then
            table.insert(segments, slug)
          end
        end

        return segments
      end

      local function normalise_note_path(input)
        local path = clean_relative_path(input)

        if not path then
          return nil
        end

        local segments = split_path(path)

        if #segments == 0 then
          return nil
        end

        return table.concat(segments, "/") .. ".norg"
      end

      local function normalise_folder_path(input)
        local path = clean_relative_path(input)

        if not path then
          return nil
        end

        local segments = split_path(path)

        if #segments == 0 then
          return nil
        end

        return table.concat(segments, "/")
      end

      local function title_from_path(path)
        local title = vim.fn.fnamemodify(path, ":t:r")
        title = title:gsub("[-_]+", " ")
        title = title:gsub("(%a)([%w']*)", function(first, rest)
          return first:upper() .. rest
        end)

        return title
      end

      local function seed_note(file, title)
        if vim.fn.filereadable(file) == 0 then
          vim.fn.writefile({
            "* " .. title,
            "",
          }, file)
        end
      end

      _G.neorg_notes.new_note = function()
        vim.ui.input({ prompt = "Note path/title: " }, function(input)
          local relative = normalise_note_path(input)

          if not relative then
            return
          end

          local file = join(notes_dir, relative)
          ensure_dir(vim.fn.fnamemodify(file, ":h"))
          seed_note(file, title_from_path(relative))
          vim.cmd.edit(vim.fn.fnameescape(file))
        end)
      end

      _G.neorg_notes.new_folder = function()
        vim.ui.input({ prompt = "Folder under ~/notes: " }, function(input)
          local folder = normalise_folder_path(input)

          if not folder then
            return
          end

          local dir = join(notes_dir, folder)
          local index = join(dir, "index.norg")
          ensure_dir(dir)
          seed_note(index, title_from_path(folder))
          vim.cmd.edit(vim.fn.fnameescape(index))
        end)
      end

      _G.neorg_notes.toggle_render = function()
        if vim.wo.conceallevel > 0 then
          vim.wo.conceallevel = 0
          vim.notify("Rendered view off", vim.log.levels.INFO)
        else
          vim.wo.conceallevel = 2
          vim.notify("Rendered view on", vim.log.levels.INFO)
        end
      end

      vim.api.nvim_create_user_command("NeorgNewNote", _G.neorg_notes.new_note, {})
      vim.api.nvim_create_user_command("NeorgNewFolder", _G.neorg_notes.new_folder, {})
      vim.api.nvim_create_user_command("NeorgToggleRender", _G.neorg_notes.toggle_render, {})
    '';

    luaConfigRC.neorg-filetype = ''
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "norg",
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.spell = true
        end,
      })
    '';
  };
}
