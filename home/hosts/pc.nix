{ pkgs, ... }:
{
  home.username = "luix";
  home.homeDirectory = "/home/luix";

  imports = [
    ../common.nix
    ../modules/spatial-input-development
    ../modules/simracing
    ../modules/prismlauncher
  ];

  luix.spatialInputDevelopment.enable = true;
  luix.simracing.enable = true;

  # Native Wayland corrupts Firefox's chrome texture cache on this GPU,
  # hiding tab titles, URL text, and bookmark labels. XWayland renders it correctly.
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "0";

  home.packages = with pkgs; [
    protonup-qt
  ];
}
