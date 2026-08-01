{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  home.username = "luix";
  home.homeDirectory = "/home/luix";
  home.stateVersion = "25.11";

  imports = [
    ../modules/applications
    ../modules/cli
    ../modules/programming
    ../modules/spatial-input-development
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
    ../modules/qutebrowser
    ../modules/kdenlive
    ../modules/prismlauncher
    ../modules/nvfvim
    ../modules/flatpak
  ];

  luix.godot.enable = true;
  luix.spatialInputDevelopment.enable = true;

  # Native Wayland corrupts Firefox's chrome texture cache on this GPU,
  # hiding tab titles, URL text, and bookmark labels. XWayland renders it correctly.
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "0";

  home.packages = with pkgs; [
    protonup-qt
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
