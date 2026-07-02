{
  config,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
  notesGitCommands = config.luix.notesSync.commands;
in {
  imports = [
    ./media
    ./presentations
    ./templates
    ./flashcards
  ];

  programs.nvf.settings.vim = {
    globals.maplocalleader = ",";

    keymaps = (import ./keymaps.nix { inherit notesDir; }) ++ [
      {
        mode = "n";
        key = "<leader>ngs";
        action = "<cmd>lua LuixNotesGit.run(${builtins.toJSON notesGitCommands.sync})<CR>";
        desc = "Sync notes";
      }
      {
        mode = "n";
        key = "<leader>ngp";
        action = "<cmd>lua LuixNotesGit.run(${builtins.toJSON notesGitCommands.push})<CR>";
        desc = "Push notes";
      }
      {
        mode = "n";
        key = "<leader>ngP";
        action = "<cmd>lua LuixNotesGit.run(${builtins.toJSON notesGitCommands.pull})<CR>";
        desc = "Pull notes";
      }
      {
        mode = "n";
        key = "<leader>ngg";
        action = "<cmd>lua LuixNotesGit.lazygit(${builtins.toJSON notesGitCommands.sync})<CR>";
        desc = "Notes LazyGit";
      }
    ];

    binds.whichKey.register."<leader>n" = "+Notes";
    binds.whichKey.register."<leader>ng" = "+Notes Git";

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

    luaConfigRC.neorg-notes-git = ''
      local notes_dir = vim.fn.expand(${builtins.toJSON notesDir})

      local function notes_terminal(cmd)
        local Terminal = require("toggleterm.terminal").Terminal
        Terminal:new({
          cmd = cmd,
          dir = notes_dir,
          direction = "float",
          close_on_exit = false,
          hidden = true,
        }):toggle()
      end

      local function notes_has_git()
        local stat = vim.uv and vim.uv.fs_stat or vim.loop.fs_stat
        return stat(notes_dir .. "/.git") ~= nil
      end

      LuixNotesGit = {
        run = notes_terminal,
        lazygit = function(sync_cmd)
          if vim.fn.executable("lazygit") == 0 then
            vim.notify("lazygit is not installed", vim.log.levels.ERROR)
            return
          end

          if notes_has_git() then
            notes_terminal("lazygit")
          else
            notes_terminal(sync_cmd .. " && lazygit")
          end
        end,
      }
    '';
  };
}
