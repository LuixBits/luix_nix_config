{ config, pkgs, ... }:
{
  # -------- basics --------
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_GB.UTF-8";
  networking.networkmanager.enable = true;
  networking.firewall.checkReversePath = false;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };

  # --- Updates & maintenance ---
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "/etc/nixos#${config.networking.hostName}";
    dates = "daily";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 20d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      atopile = prev.writeShellScriptBin "atopile" ''
        echo "Atopile placeholder; real package not available on this channel."
      '';
    })
  ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" ];
      features = {
        buildkit = true;
      };
    };
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "exfat" ];

  # Display manager (SDDM) + X11 stack for the greeter
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "ch"; variant = ""; };
  services.displayManager.sddm = {
    enable = true;
    settings = {
      General = {
        InputMethod = "";
      };
    };
  };
  services.displayManager.defaultSession = "niri";
  console.keyMap = "sg";

  services.printing.enable = true;

  # default Shell
  environment.shells = with pkgs; [ fish ];

  users.users.luix = {
    isNormalUser = true;
    description = "luix";
    extraGroups = [
      "networkmanager"
      "wheel"
      "vboxusers"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.fish;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.symbols-only
    nerd-fonts.bigblue-terminal
    nerd-fonts.heavy-data
    nerd-fonts.hurmit
    roboto
  ];

  # Program toggles
  programs.bazecor.enable = true;
  programs.fish.enable = true; # keep NixOS aware that fish is the login shell
  programs.xwayland.enable = true;
  programs.niri.enable = true; # Niri session in the display manager

  nixpkgs.config.allowUnfree = true;

  # --- Hardware & firmware ---
  services.fwupd.enable = true;
  services.fstrim.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Graphics (25.11 uses hardware.graphics.*)
  hardware.graphics = {
    enable = true;
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
    auto-optimise-store = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    # Use niri's recommended portal preference order (niri-portals.conf).
    configPackages = [ pkgs.niri ];
  };

  # Needed for the Secret portal (Flatpak apps) and recommended by niri docs.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    exfatprogs
    usbutils
    wireguard-tools
    xwayland-satellite
  ];

  system.stateVersion = "25.11";
}
