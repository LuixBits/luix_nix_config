{
  inputs,
  pkgs,
  ...
}:
{
  programs.nvf.settings.vim = {
    extraPlugins.roomplan = {
      package = inputs.roomplan.packages.${pkgs.stdenv.hostPlatform.system}.default;
      setup = "require('roomplan').setup({})";
    };

    keymaps = import ./keymaps.nix;
    binds.whichKey.register."<leader>r" = "+RoomPlan";
  };
}
