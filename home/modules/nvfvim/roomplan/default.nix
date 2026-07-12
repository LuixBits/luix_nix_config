{ ... }:
{
  programs.nvf.settings.vim = {
    # Temporary development wiring: load the mutable local checkout directly.
    luaConfigRC.roomplan = ''
      local roomplan_path = vim.fn.expand("~/projects/neovim-plugins/roomplan.nvim")
      vim.opt.runtimepath:prepend(roomplan_path)
      require("roomplan").setup({})
    '';

    keymaps = import ./keymaps.nix;
    binds.whichKey.register."<leader>r" = "+RoomPlan";
  };
}
