{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  nixcatsPackages = inputs.self.packages.${system};
  nixcatsPackage =
    if nixcatsPackages ? nvimLuix then nixcatsPackages.nvimLuix else nixcatsPackages.default;
in
{
  programs.neovim = {
    enable = true;
    package = nixcatsPackage;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
