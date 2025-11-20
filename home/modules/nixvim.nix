{ inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    globals.mapleader = " ";

    opts = {
      number = true;
      relativenumber = true;
      wrap = false;
      clipboard = "unnamedplus";
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options.silent = true;
      }
    ];
  };
}
