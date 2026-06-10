{
  config,
  ...
}: let
  notesDir = "${config.home.homeDirectory}/notes";
in {
  imports = [
    ./neorg-presentations.nix
    ./neorg-templates.nix
  ];

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
  };
}
