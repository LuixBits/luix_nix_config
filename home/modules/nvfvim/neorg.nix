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

    keymaps = import ./neorg-keymaps.nix;

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
