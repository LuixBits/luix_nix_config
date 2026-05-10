{
  config,
  lib,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
in {
  home.activation.ensureNeorgWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${notesDir}"
  '';

  programs.nvf.settings.vim = {
    globals.maplocalleader = ",";

    keymaps = import ./neorg-keymaps.nix { inherit notesDir; };

    binds.whichKey.register."<leader>n" = "+Notes";

    notes.neorg = {
      enable = true;
      treesitter.enable = true;
      setupOpts.load = {
        "core.defaults" = {};
        "core.concealer" = {};
        "core.integrations.telescope" = {};
        "core.dirman" = {
          config = {
            workspaces.notes = notesDir;
            default_workspace = "notes";
            index = "index.norg";
          };
        };
      };
    };

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

    luaConfigRC.neorg-new-note = ''
      local notes_dir = vim.fn.expand("${notesDir}")

      local function relative_note_path(dir, name)
        local root = vim.fs.normalize(notes_dir)
        dir = vim.fs.normalize(dir)

        if dir == root then
          return name
        end

        if vim.startswith(dir, root .. "/") then
          return dir:sub(#root + 2) .. "/" .. name
        end

        return name
      end

      local function target_dir()
        if vim.bo.filetype == "NvimTree" then
          local ok, api = pcall(require, "nvim-tree.api")
          if ok then
            local node = api.tree.get_node_under_cursor()
            if node and node.absolute_path then
              if node.type == "directory" then
                return node.absolute_path
              end
              return vim.fn.fnamemodify(node.absolute_path, ":h")
            end
          end
        end

        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file ~= "" then
          local current_dir = vim.fn.fnamemodify(current_file, ":h")
          if current_dir:sub(1, #notes_dir) == notes_dir then
            return current_dir
          end
        end

        return notes_dir
      end

      local function move_to_note_window()
        if vim.bo.filetype == "NvimTree" then
          vim.cmd("wincmd l")
          if vim.bo.filetype == "NvimTree" then
            vim.cmd("vsplit")
          end
        end
      end

      function NeorgNewNoteHere()
        local dir = target_dir()

        vim.ui.input({ prompt = "New note: " }, function(input)
          input = vim.trim(input or "")
          if input == "" then
            return
          end

          local dirman = require("neorg").modules.get_module("core.dirman")
          if not dirman then
            vim.notify("Neorg dirman is not loaded", vim.log.levels.ERROR)
            return
          end

          local path = relative_note_path(dir, input)
          move_to_note_window()
          dirman.create_file(path, "notes")
        end)
      end
    '';
  };
}
