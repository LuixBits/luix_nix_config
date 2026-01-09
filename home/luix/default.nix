{ config, pkgs, lib, ... }:
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
    ../modules/buildandpush.nix
    ../modules/zsh.nix
    ../modules/docker.nix
    ../modules/flatpak.nix
    ../modules/music_client.nix
    # Neovim variants
    ../modules/nixvim.nix
    # ../modules/nvfvim.nix
    # ../modules/nixcats.nix

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
