{ config, ... }:
{
  home.username = "luix";
  home.homeDirectory = "/home/luix";

  imports = [
    ../common.nix
    ../modules/japanese-input
    ../modules/teams
    ../modules/prismlauncher
  ];

  programs.graphify.projectRoots = [
    "${config.home.homeDirectory}/projects/spatial-input"
    "${config.home.homeDirectory}/projects/luix-bits-game"
    "${config.home.homeDirectory}/projects/luixbits-roomplanner.nvim"
    "${config.home.homeDirectory}/projects/luixbits-neorg-flashcards.nvim"
    "${config.home.homeDirectory}/projects/motion_canvas_luix"
    "${config.home.homeDirectory}/projects/LuixBitsVoice"
    "${config.home.homeDirectory}/projects/LuixBitsRemotion"
    "${config.home.homeDirectory}/projects/shorts-poc"
    "${config.home.homeDirectory}/luix_nix_config"
  ];
}
