{ config, pkgs, ... }:
{
  home.username = "luix";
  home.homeDirectory = "/home/luix";
  home.stateVersion = "25.05";

  imports = [
    ./packages.nix
  ];

  xdg.enable = true;
  fonts.fontconfig.enable = true;
}
