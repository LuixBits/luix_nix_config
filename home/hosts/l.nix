{ config, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  home.username = "luix";
  home.homeDirectory = "/home/luix";
  home.stateVersion = "25.11";

  imports = [
    ../modules/applications
    ../modules/cli
    ../modules/programming
    ../modules/herdr
    ../modules/kitty
    ../modules/buildandpush
    ../modules/notes-sync
    ../modules/fish
    ../modules/docker
    ../modules/godot
    ../modules/vpn
    ../modules/audio
    ../modules/niri
    ../modules/japanese-input
    ../modules/qutebrowser
    ../modules/kdenlive
    ../modules/teams
    ../modules/prismlauncher
    ../modules/nvfvim
    ../modules/flatpak
  ];

  luix.godot.enable = true;

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

  home.activation.cleanupBrokenNvimConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    nvim_dir="${config.xdg.configHome}/nvim"
    if { [ -L "$nvim_dir" ] && [ ! -d "$nvim_dir" ]; } || { [ -e "$nvim_dir" ] && [ ! -d "$nvim_dir" ]; }; then
      backup_ext="''${HOME_MANAGER_BACKUP_EXT:-hm-back}"
      backup_path="$nvim_dir.$backup_ext"
      if [ -e "$backup_path" ]; then
        backup_path="$backup_path.$(date +%s)"
      fi
      run mv "$nvim_dir" "$backup_path"
    fi
  '';

  xdg.enable = true;
  fonts.fontconfig.enable = true;

  # ensure ~/.nix-profile points at the managed Home Manager profile so packages resolve
  home.file.".nix-profile" = {
    source = config.home.path;
    force = true;
  };
}
