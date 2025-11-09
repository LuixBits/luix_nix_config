{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  home.username = "luix";
  home.homeDirectory = "/home/luix";
  home.stateVersion = "25.05";

  imports = [
    ../modules/base.nix
    ../modules/applications.nix
    ../modules/cli.nix
    ../modules/media.nix
    ../modules/programming.nix
    ../modules/kitty.nix
    ../modules/nixvim.nix
    ../modules/buildandpush.nix
    ../modules/zsh.nix
    ../modules/docker.nix

  ];

  xdg.enable = true;
  fonts.fontconfig.enable = true;

  # ensure ~/.nix-profile points at the managed Home Manager profile so packages resolve
  home.file.".nix-profile" = {
    source = config.home.path;
    force = true;
  };
}
